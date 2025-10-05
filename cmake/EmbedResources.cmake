# EmbedResources.cmake
# Cross-platform resource embedding for CMake projects

include_guard(GLOBAL)

# Store the directory of this file when it's first loaded
# This ensures template paths work correctly regardless of where embed_resources is called from
get_filename_component(_RESOURCE_TOOLS_CMAKE_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
set(RESOURCE_TOOLS_TEMPLATE_DIR "${_RESOURCE_TOOLS_CMAKE_DIR}/templates" CACHE INTERNAL "")

#[=======================================================================[.rst:
EmbedResources
--------------

Cross-platform resource embedding for CMake projects.

Commands
^^^^^^^^

.. command:: embed_resources

  Embed binary resources into a target::

    embed_resources(TARGET <target_name>
                   RESOURCES <file1> [<file2> ...]
                   [RESOURCE_DIR <directory>]
                   [HEADER_OUTPUT_DIR <directory>]
                   [NAMESPACE <namespace>])

#]=======================================================================]

function(embed_resources)
    set(options "")
    set(oneValueArgs TARGET RESOURCE_DIR HEADER_OUTPUT_DIR NAMESPACE)
    set(multiValueArgs RESOURCES)

    cmake_parse_arguments(ER "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ER_TARGET)
        message(FATAL_ERROR "embed_resources: TARGET is required")
    endif()

    if(NOT ER_RESOURCES)
        message(FATAL_ERROR "embed_resources: RESOURCES is required")
    endif()

    if(NOT ER_RESOURCE_DIR)
        set(ER_RESOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()

    if(NOT ER_HEADER_OUTPUT_DIR)
        set(ER_HEADER_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/include")
    endif()

    if(NOT ER_NAMESPACE)
        set(ER_NAMESPACE "resources")
    endif()

    set(LIBRARY_NAME "${ER_TARGET}-data")

    # Ensure output directory exists
    file(MAKE_DIRECTORY "${ER_HEADER_OUTPUT_DIR}/${ER_NAMESPACE}")

    if(WIN32)
        _embed_resources_windows(
            TARGET ${ER_TARGET}
            LIBRARY_NAME ${LIBRARY_NAME}
            RESOURCES ${ER_RESOURCES}
            RESOURCE_DIR ${ER_RESOURCE_DIR}
            HEADER_OUTPUT_DIR ${ER_HEADER_OUTPUT_DIR}
            NAMESPACE ${ER_NAMESPACE}
        )
    else()
        _embed_resources_unix(
            TARGET ${ER_TARGET}
            LIBRARY_NAME ${LIBRARY_NAME}
            RESOURCES ${ER_RESOURCES}
            RESOURCE_DIR ${ER_RESOURCE_DIR}
            HEADER_OUTPUT_DIR ${ER_HEADER_OUTPUT_DIR}
            NAMESPACE ${ER_NAMESPACE}
        )
    endif()

endfunction()

# Windows implementation using RC files
function(_embed_resources_windows)
    set(options "")
    set(oneValueArgs TARGET LIBRARY_NAME RESOURCE_DIR HEADER_OUTPUT_DIR NAMESPACE)
    set(multiValueArgs RESOURCES)

    cmake_parse_arguments(ER "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    enable_language(RC)

    set(RC_FILE "${CMAKE_CURRENT_BINARY_DIR}/${ER_TARGET}_resources.rc")
    set(RESOURCE_H "${ER_HEADER_OUTPUT_DIR}/${ER_NAMESPACE}/resource_ids.h")
    set(ACCESSOR_H "${ER_HEADER_OUTPUT_DIR}/${ER_NAMESPACE}/embedded_data.h")

    # Generate resource data for templates
    set(RESOURCE_ENTRIES "")
    set(RESOURCE_ID_DEFINITIONS "")
    set(ACCESSOR_FUNCTIONS "")
    set(BINARY_SYMBOLS "")

    set(ID_COUNTER 1)
    foreach(ResourceFile IN LISTS ER_RESOURCES)
        get_filename_component(ResourceName ${ResourceFile} NAME)
        string(REGEX REPLACE "[^a-zA-Z0-9]" "_" ResourceId ${ResourceName})
        string(TOUPPER ${ResourceId} ResourceIdUpper)

        # Create a more readable function name
        get_filename_component(BaseName ${ResourceFile} NAME_WE)
        get_filename_component(Extension ${ResourceFile} EXT)
        string(REPLACE "." "" Extension ${Extension})

        # Convert to proper camelCase
        # Split basename by underscores and hyphens, then capitalize each part
        string(REPLACE "_" ";" BaseParts ${BaseName})
        set(CamelBaseName "")
        foreach(Part IN LISTS BaseParts)
            if(Part)
                # Also split by hyphens
                string(REPLACE "-" ";" HyphenParts ${Part})
                foreach(HyphenPart IN LISTS HyphenParts)
                    if(HyphenPart)
                        string(SUBSTRING ${HyphenPart} 0 1 FirstChar)
                        string(TOUPPER ${FirstChar} FirstChar)
                        string(SUBSTRING ${HyphenPart} 1 -1 RestChars)
                        string(TOLOWER ${RestChars} RestChars)
                        string(APPEND CamelBaseName "${FirstChar}${RestChars}")
                    endif()
                endforeach()
            endif()
        endforeach()

        # Handle extension
        string(TOUPPER ${Extension} UpperExtension)
        set(FunctionName "${CamelBaseName}${UpperExtension}")

        # Generate binary symbol name for cross-platform compatibility
        string(REGEX REPLACE "\\." "_" BinarySymbol ${ResourceName})
        string(REGEX REPLACE "[^a-zA-Z0-9_]" "_" BinarySymbol ${BinarySymbol})
        set(BinarySymbolName "_binary_${BinarySymbol}_start")

        # Resource ID definition
        string(APPEND RESOURCE_ID_DEFINITIONS "#define k${ResourceIdUpper} ${ID_COUNTER}\n")

        # RC file entry
        string(APPEND RESOURCE_ENTRIES "k${ResourceIdUpper} RCDATA \"${ER_RESOURCE_DIR}/${ResourceFile}\"\n")

        # Accessor functions with better names
        string(APPEND ACCESSOR_FUNCTIONS "inline auto get${FunctionName}Data() -> const uint8_t* {\n")
        string(APPEND ACCESSOR_FUNCTIONS "    HRSRC hResource = FindResource(nullptr, MAKEINTRESOURCE(k${ResourceIdUpper}), RT_RCDATA);\n")
        string(APPEND ACCESSOR_FUNCTIONS "    if (hResource == nullptr) { return nullptr; }\n")
        string(APPEND ACCESSOR_FUNCTIONS "    HGLOBAL hMemory = LoadResource(nullptr, hResource);\n")
        string(APPEND ACCESSOR_FUNCTIONS "    if (hMemory == nullptr) { return nullptr; }\n")
        string(APPEND ACCESSOR_FUNCTIONS "    return static_cast<const uint8_t*>(LockResource(hMemory));\n")
        string(APPEND ACCESSOR_FUNCTIONS "}\n\n")

        string(APPEND ACCESSOR_FUNCTIONS "inline auto get${FunctionName}Size() -> uint32_t {\n")
        string(APPEND ACCESSOR_FUNCTIONS "    HRSRC hResource = FindResource(nullptr, MAKEINTRESOURCE(k${ResourceIdUpper}), RT_RCDATA);\n")
        string(APPEND ACCESSOR_FUNCTIONS "    if (hResource == nullptr) { return 0; }\n")
        string(APPEND ACCESSOR_FUNCTIONS "    return SizeofResource(nullptr, hResource);\n")
        string(APPEND ACCESSOR_FUNCTIONS "}\n\n")

        # Binary symbol compatibility
        string(APPEND BINARY_SYMBOLS "inline const uint8_t* const ${BinarySymbolName}_ptr = get${FunctionName}Data();\n")
        string(APPEND BINARY_SYMBOLS "#define ${BinarySymbolName} (*${BinarySymbolName}_ptr)\n\n")

        math(EXPR ID_COUNTER "${ID_COUNTER} + 1")
    endforeach()

    # Configure templates
    set(NAMESPACE ${ER_NAMESPACE})
    string(TOUPPER ${ER_NAMESPACE} NAMESPACE_UPPER)

    configure_file(
        "${RESOURCE_TOOLS_TEMPLATE_DIR}/resource_ids.h.in"
        "${RESOURCE_H}"
        @ONLY
    )

    configure_file(
        "${RESOURCE_TOOLS_TEMPLATE_DIR}/resources.rc.in"
        "${RC_FILE}"
        @ONLY
    )

    configure_file(
        "${RESOURCE_TOOLS_TEMPLATE_DIR}/embedded_data_windows.h.in"
        "${ACCESSOR_H}"
        @ONLY
    )

    # Create the library
    add_library(${ER_LIBRARY_NAME} OBJECT ${RC_FILE})

    # Set RC file include directories - both target property and source property for compatibility
    set_target_properties(${ER_LIBRARY_NAME} PROPERTIES
        LINKER_LANGUAGE RC
        INCLUDE_DIRECTORIES "${ER_HEADER_OUTPUT_DIR}")

    set_source_files_properties(${RC_FILE} PROPERTIES
        INCLUDE_DIRECTORIES "${ER_HEADER_OUTPUT_DIR}")

    # Make the generated headers available
    target_include_directories(${ER_LIBRARY_NAME} PUBLIC
        $<BUILD_INTERFACE:${ER_HEADER_OUTPUT_DIR}>)

endfunction()

# Unix implementation using object files
function(_embed_resources_unix)
    set(options "")
    set(oneValueArgs TARGET LIBRARY_NAME RESOURCE_DIR HEADER_OUTPUT_DIR NAMESPACE)
    set(multiValueArgs RESOURCES)

    cmake_parse_arguments(ER "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(ACCESSOR_H "${ER_HEADER_OUTPUT_DIR}/${ER_NAMESPACE}/embedded_data.h")

    set(DataObjectFiles "")
    set(EXTERN_DECLARATIONS "")
    set(ACCESSOR_FUNCTIONS "")

    foreach(ResourceFile IN LISTS ER_RESOURCES)
        get_filename_component(ResourceName ${ResourceFile} NAME)
        string(REGEX REPLACE "[^a-zA-Z0-9]" "_" ResourceId ${ResourceName})

        # Create a more readable function name
        get_filename_component(BaseName ${ResourceFile} NAME_WE)
        get_filename_component(Extension ${ResourceFile} EXT)
        string(REPLACE "." "" Extension ${Extension})

        # Convert to proper camelCase
        # Split basename by underscores and hyphens, then capitalize each part
        string(REPLACE "_" ";" BaseParts ${BaseName})
        set(CamelBaseName "")
        foreach(Part IN LISTS BaseParts)
            if(Part)
                # Also split by hyphens
                string(REPLACE "-" ";" HyphenParts ${Part})
                foreach(HyphenPart IN LISTS HyphenParts)
                    if(HyphenPart)
                        string(SUBSTRING ${HyphenPart} 0 1 FirstChar)
                        string(TOUPPER ${FirstChar} FirstChar)
                        string(SUBSTRING ${HyphenPart} 1 -1 RestChars)
                        string(TOLOWER ${RestChars} RestChars)
                        string(APPEND CamelBaseName "${FirstChar}${RestChars}")
                    endif()
                endforeach()
            endif()
        endforeach()

        # Handle extension
        string(TOUPPER ${Extension} UpperExtension)
        set(FunctionName "${CamelBaseName}${UpperExtension}")

        set(FullResourcePath "${ER_RESOURCE_DIR}/${ResourceFile}")
        set(OutFile "${CMAKE_CURRENT_BINARY_DIR}/${ResourceName}.o")

        # Generate binary symbol name
        string(REGEX REPLACE "\\." "_" BinarySymbol ${ResourceName})
        string(REGEX REPLACE "[^a-zA-Z0-9_]" "_" BinarySymbol ${BinarySymbol})

        # Symbol name for C linkage (with underscore prefix)
        set(BinarySymbolName "_binary_${BinarySymbol}")

        # Platform-specific linker commands
        if(APPLE)
            # macOS: assembler ALWAYS adds underscore prefix to symbols
            # So assembly declares "binary_*" which becomes "_binary_*" in object file
            # C++ declares "binary_*" with extern "C", compiler looks for "_binary_*"
            set(AsmSymbolName "binary_${BinarySymbol}")
            # macOS: Generate assembly file and assemble it
            set(AsmFile "${CMAKE_CURRENT_BINARY_DIR}/${ResourceName}.s")
            add_custom_command(
                OUTPUT ${OutFile}
                MAIN_DEPENDENCY ${FullResourcePath}
                COMMAND ${CMAKE_COMMAND} -E echo ".section __DATA,__const" > ${AsmFile}
                COMMAND ${CMAKE_COMMAND} -E echo ".globl ${AsmSymbolName}_start" >> ${AsmFile}
                COMMAND ${CMAKE_COMMAND} -E echo "${AsmSymbolName}_start:" >> ${AsmFile}
                COMMAND ${CMAKE_COMMAND} -E echo ".incbin \"${ResourceFile}\"" >> ${AsmFile}
                COMMAND ${CMAKE_COMMAND} -E echo ".globl ${AsmSymbolName}_end" >> ${AsmFile}
                COMMAND ${CMAKE_COMMAND} -E echo "${AsmSymbolName}_end:" >> ${AsmFile}
                COMMAND as -o ${OutFile} ${AsmFile}
                DEPENDS ${FullResourcePath}
                WORKING_DIRECTORY ${ER_RESOURCE_DIR}
            )
        else()
            # Linux/Unix uses GNU ld
            add_custom_command(
                OUTPUT ${OutFile}
                MAIN_DEPENDENCY ${FullResourcePath}
                COMMAND "${CMAKE_LINKER}" --relocatable --format binary --output=${OutFile} ${ResourceName}
                COMMAND objcopy --add-section .note.GNU-stack=/dev/null --set-section-flags .note.GNU-stack=noload ${OutFile}
                DEPENDS ${FullResourcePath}
                WORKING_DIRECTORY ${ER_RESOURCE_DIR}
            )
        endif()
        list(APPEND DataObjectFiles ${OutFile})

        # External symbol declarations
        # macOS: Header declares without underscore, assembler/compiler adds it
        # Linux: Header declares with underscore to match GNU ld output
        if(APPLE)
            set(HeaderSymbolName "binary_${BinarySymbol}")
        else()
            set(HeaderSymbolName "${BinarySymbolName}")
        endif()

        string(APPEND EXTERN_DECLARATIONS "extern \"C\" const uint8_t ${HeaderSymbolName}_start;\n")
        string(APPEND EXTERN_DECLARATIONS "extern \"C\" const uint8_t ${HeaderSymbolName}_end;\n\n")

        # Accessor functions with better names
        string(APPEND ACCESSOR_FUNCTIONS "inline auto get${FunctionName}Size() -> uint32_t {\n")
        string(APPEND ACCESSOR_FUNCTIONS "    return static_cast<uint32_t>(&${HeaderSymbolName}_end - &${HeaderSymbolName}_start);\n")
        string(APPEND ACCESSOR_FUNCTIONS "}\n\n")

        string(APPEND ACCESSOR_FUNCTIONS "inline auto get${FunctionName}Data() -> const uint8_t* {\n")
        string(APPEND ACCESSOR_FUNCTIONS "    return &${HeaderSymbolName}_start;\n")
        string(APPEND ACCESSOR_FUNCTIONS "}\n\n")
    endforeach()

    # Configure template
    string(TOUPPER ${ER_NAMESPACE} NAMESPACE_UPPER)

    configure_file(
        "${RESOURCE_TOOLS_TEMPLATE_DIR}/embedded_data_unix.h.in"
        "${ACCESSOR_H}"
        @ONLY
    )

    # Create the library
    add_library(${ER_LIBRARY_NAME} STATIC)
    target_sources(${ER_LIBRARY_NAME} PRIVATE ${DataObjectFiles})
    set_target_properties(${ER_LIBRARY_NAME} PROPERTIES LINKER_LANGUAGE CXX)

    # Make the generated headers available
    target_include_directories(${ER_LIBRARY_NAME} PUBLIC
        $<BUILD_INTERFACE:${ER_HEADER_OUTPUT_DIR}>)

endfunction()