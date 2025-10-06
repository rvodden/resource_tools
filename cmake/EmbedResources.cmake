# EmbedResources.cmake
# Cross-platform resource embedding for CMake projects

include_guard(GLOBAL)

# Store the directory of this file when it's first loaded
# This ensures template paths work correctly regardless of where embed_resources is called from
get_filename_component(_RESOURCE_TOOLS_CMAKE_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
set(RESOURCE_TOOLS_TEMPLATE_DIR "${_RESOURCE_TOOLS_CMAKE_DIR}/templates" CACHE INTERNAL "")

# Helper macro to convert a filename to camelCase identifier
# Input: InputBaseName - the base filename (without extension)
# Output: Sets CamelBaseName in parent scope
macro(_convert_to_camel_case InputBaseName)
    # Sanitize basename: replace spaces and other invalid chars with underscores
    string(REGEX REPLACE "[^a-zA-Z0-9_-]" "_" _SanitizedBaseName "${InputBaseName}")

    # Convert to proper camelCase
    # Split basename by underscores and hyphens, then capitalize each part
    string(REPLACE "_" ";" _BaseParts ${_SanitizedBaseName})
    set(CamelBaseName "")
    foreach(_Part IN LISTS _BaseParts)
        if(_Part)
            # Also split by hyphens
            string(REPLACE "-" ";" _HyphenParts ${_Part})
            foreach(_HyphenPart IN LISTS _HyphenParts)
                if(_HyphenPart)
                    string(SUBSTRING ${_HyphenPart} 0 1 _FirstChar)
                    string(TOUPPER ${_FirstChar} _FirstChar)
                    string(SUBSTRING ${_HyphenPart} 1 -1 _RestChars)
                    string(TOLOWER ${_RestChars} _RestChars)
                    string(APPEND CamelBaseName "${_FirstChar}${_RestChars}")
                endif()
            endforeach()
        endif()
    endforeach()
endmacro()

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

    # ============================================================================
    # INPUT VALIDATION
    # ============================================================================

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

    # VALIDATE NAMESPACE - must be valid C++ identifier
    if(NOT ER_NAMESPACE MATCHES "^[a-zA-Z_][a-zA-Z0-9_]*$")
        message(FATAL_ERROR
            "embed_resources: Invalid namespace '${ER_NAMESPACE}'\n"
            "  Namespace must be a valid C++ identifier (letters, numbers, underscores)\n"
            "  Must start with letter or underscore\n"
            "  Examples: 'my_resources', 'gameAssets', 'res_v2'")
    endif()

    # VALIDATE RESOURCE_DIR exists
    if(NOT EXISTS "${ER_RESOURCE_DIR}")
        message(FATAL_ERROR
            "embed_resources: RESOURCE_DIR does not exist: ${ER_RESOURCE_DIR}\n"
            "  Check that the directory path is correct")
    endif()

    if(NOT IS_DIRECTORY "${ER_RESOURCE_DIR}")
        message(FATAL_ERROR
            "embed_resources: RESOURCE_DIR is not a directory: ${ER_RESOURCE_DIR}\n"
            "  Must be a directory containing resource files")
    endif()

    # VALIDATE RESOURCES - check files exist and paths are safe
    set(MISSING_FILES "")
    set(INVALID_PATHS "")
    foreach(ResourceFile IN LISTS ER_RESOURCES)
        # Check for directory traversal attempts
        if(ResourceFile MATCHES "\\.\\.")
            list(APPEND INVALID_PATHS "  - ${ResourceFile} (contains '..' - potential security issue)")
        endif()

        # Check for absolute paths
        if(IS_ABSOLUTE "${ResourceFile}")
            list(APPEND INVALID_PATHS "  - ${ResourceFile} (absolute path - must be relative to RESOURCE_DIR)")
        endif()

        # Check file exists
        set(FullPath "${ER_RESOURCE_DIR}/${ResourceFile}")
        if(NOT EXISTS "${FullPath}")
            list(APPEND MISSING_FILES "  - ${ResourceFile} (expected at: ${FullPath})")
        elseif(IS_DIRECTORY "${FullPath}")
            list(APPEND MISSING_FILES "  - ${ResourceFile} (is a directory, not a file)")
        endif()
    endforeach()

    if(INVALID_PATHS)
        list(JOIN INVALID_PATHS "\n" INVALID_LIST)
        message(FATAL_ERROR
            "embed_resources: Invalid resource paths detected:\n${INVALID_LIST}\n"
            "  Security: Paths must be relative to RESOURCE_DIR and not contain '..'")
    endif()

    if(MISSING_FILES)
        list(JOIN MISSING_FILES "\n" MISSING_LIST)
        message(FATAL_ERROR
            "embed_resources: Missing or invalid resource files:\n${MISSING_LIST}\n"
            "  RESOURCE_DIR: ${ER_RESOURCE_DIR}\n"
            "  Check that files exist and paths are correct")
    endif()

    # CHECK FOR DUPLICATE SYMBOLS
    set(SYMBOL_NAMES "")
    set(FUNCTION_NAMES "")
    foreach(ResourceFile IN LISTS ER_RESOURCES)
        # Generate symbol name using same logic as templates
        get_filename_component(ResourceName ${ResourceFile} NAME)
        string(REGEX REPLACE "[^a-zA-Z0-9]" "_" BinarySymbol ${ResourceName})

        # Generate function name
        get_filename_component(BaseName ${ResourceFile} NAME_WE)
        get_filename_component(Extension ${ResourceFile} EXT)
        string(REPLACE "." "" Extension ${Extension})
        string(REPLACE "_" ";" BaseParts ${BaseName})
        set(CamelBaseName "")
        foreach(Part IN LISTS BaseParts)
            if(Part)
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
        string(TOUPPER ${Extension} UpperExtension)
        set(FunctionName "${CamelBaseName}${UpperExtension}")

        # Check for duplicates
        if("${BinarySymbol}" IN_LIST SYMBOL_NAMES)
            message(FATAL_ERROR
                "embed_resources: Duplicate symbol name '${BinarySymbol}'\n"
                "  Files: ${ResourceFile} and another file create the same symbol\n"
                "  Rename one of the files to avoid collision")
        endif()

        if("${FunctionName}" IN_LIST FUNCTION_NAMES)
            message(FATAL_ERROR
                "embed_resources: Duplicate function name 'get${FunctionName}Data/Size()'\n"
                "  Files create identical accessor function names\n"
                "  Rename one of the files to avoid collision")
        endif()

        list(APPEND SYMBOL_NAMES "${BinarySymbol}")
        list(APPEND FUNCTION_NAMES "${FunctionName}")
    endforeach()

    # ============================================================================
    # VERBOSE/DIAGNOSTIC OUTPUT
    # ============================================================================

    if(RESOURCE_TOOLS_VERBOSE OR CMAKE_VERBOSE_MAKEFILE)
        message(STATUS "embed_resources configuration:")
        message(STATUS "  Target: ${ER_TARGET}")
        message(STATUS "  Library: ${ER_TARGET}-data")
        message(STATUS "  Namespace: ${ER_NAMESPACE}")
        message(STATUS "  Resource dir: ${ER_RESOURCE_DIR}")
        message(STATUS "  Header output: ${ER_HEADER_OUTPUT_DIR}/${ER_NAMESPACE}")
        list(LENGTH ER_RESOURCES RESOURCE_COUNT)
        message(STATUS "  Resources (${RESOURCE_COUNT} files):")
        foreach(res IN LISTS ER_RESOURCES)
            file(SIZE "${ER_RESOURCE_DIR}/${res}" fsize)
            math(EXPR fsize_kb "${fsize} / 1024")
            if(fsize_kb GREATER 0)
                message(STATUS "    - ${res} (${fsize_kb} KB)")
            else()
                message(STATUS "    - ${res} (${fsize} bytes)")
            endif()
        endforeach()
    endif()

    set(LIBRARY_NAME "${ER_TARGET}-data")

    # Ensure output directory exists
    file(MAKE_DIRECTORY "${ER_HEADER_OUTPUT_DIR}/${ER_NAMESPACE}")

    # ============================================================================
    # GENERATE MANIFEST FILE FOR DEBUGGING
    # ============================================================================

    set(MANIFEST_FILE "${CMAKE_CURRENT_BINARY_DIR}/${ER_TARGET}_resources.manifest")
    file(WRITE "${MANIFEST_FILE}" "# Resource Embedding Manifest\n")
    file(APPEND "${MANIFEST_FILE}" "# Generated by resource_tools\n\n")
    file(APPEND "${MANIFEST_FILE}" "Target: ${ER_TARGET}\n")
    file(APPEND "${MANIFEST_FILE}" "Library: ${LIBRARY_NAME}\n")
    file(APPEND "${MANIFEST_FILE}" "Namespace: ${ER_NAMESPACE}\n")
    file(APPEND "${MANIFEST_FILE}" "Resource Directory: ${ER_RESOURCE_DIR}\n")
    file(APPEND "${MANIFEST_FILE}" "Header Output: ${ER_HEADER_OUTPUT_DIR}/${ER_NAMESPACE}\n")
    file(APPEND "${MANIFEST_FILE}" "Platform: ${CMAKE_SYSTEM_NAME}\n")
    file(APPEND "${MANIFEST_FILE}" "\n# Resources:\n\n")

    foreach(ResourceFile IN LISTS ER_RESOURCES)
        get_filename_component(ResourceName ${ResourceFile} NAME)
        string(REGEX REPLACE "[^a-zA-Z0-9]" "_" BinarySymbol ${ResourceName})

        get_filename_component(BaseName ${ResourceFile} NAME_WE)
        get_filename_component(Extension ${ResourceFile} EXT)
        string(REPLACE "." "" Extension ${Extension})

        # Sanitize basename: replace spaces and other invalid chars with underscores
        string(REGEX REPLACE "[^a-zA-Z0-9_-]" "_" BaseName "${BaseName}")

        string(REPLACE "_" ";" BaseParts ${BaseName})
        set(CamelBaseName "")
        foreach(Part IN LISTS BaseParts)
            if(Part)
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
        string(TOUPPER ${Extension} UpperExtension)
        set(FunctionName "${CamelBaseName}${UpperExtension}")

        file(SIZE "${ER_RESOURCE_DIR}/${ResourceFile}" FileSize)
        file(APPEND "${MANIFEST_FILE}" "Resource: ${ResourceFile}\n")
        file(APPEND "${MANIFEST_FILE}" "  Path: ${ER_RESOURCE_DIR}/${ResourceFile}\n")
        file(APPEND "${MANIFEST_FILE}" "  Size: ${FileSize} bytes\n")
        file(APPEND "${MANIFEST_FILE}" "  Symbol: ${BinarySymbol}\n")
        file(APPEND "${MANIFEST_FILE}" "  Functions:\n")
        file(APPEND "${MANIFEST_FILE}" "    - ${ER_NAMESPACE}::get${FunctionName}() -> resource_tools::ResourceResult\n")
        file(APPEND "${MANIFEST_FILE}" "\n")
    endforeach()

    # Add custom target to display manifest
    add_custom_target(${ER_TARGET}-manifest
        COMMAND ${CMAKE_COMMAND} -E echo "=== Resource Manifest: ${MANIFEST_FILE} ==="
        COMMAND ${CMAKE_COMMAND} -E cat "${MANIFEST_FILE}"
        VERBATIM
        COMMENT "Displaying resource manifest for ${ER_TARGET}"
    )

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
    set(ACCESSOR_FUNCTIONS "")
    set(BINARY_SYMBOLS "")

    # Generate unique base ID for this target to avoid duplicate resource IDs
    # Use deterministic hash of target name to get unique ID range per target
    string(MD5 TARGET_HASH "${ER_TARGET}")
    string(SUBSTRING "${TARGET_HASH}" 0 2 HASH_BYTE)
    # Convert to decimal: 0x00-0xFF = 0-255, multiply by 1000 for range separation
    math(EXPR ID_BASE "0x${HASH_BYTE} * 1000 + 100")
    set(ID_COUNTER ${ID_BASE})
    foreach(ResourceFile IN LISTS ER_RESOURCES)
        get_filename_component(ResourceName ${ResourceFile} NAME)
        string(REGEX REPLACE "[^a-zA-Z0-9]" "_" ResourceId ${ResourceName})
        string(TOUPPER ${ResourceId} ResourceIdUpper)

        # Create a more readable function name
        get_filename_component(BaseName ${ResourceFile} NAME_WE)
        get_filename_component(Extension ${ResourceFile} EXT)
        string(REPLACE "." "" Extension ${Extension})

        # Convert to proper camelCase
        _convert_to_camel_case("${BaseName}")

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

        # Safe accessor functions (Windows)
        string(APPEND ACCESSOR_FUNCTIONS "inline auto get${FunctionName}() -> resource_tools::ResourceResult {\n")
        string(APPEND ACCESSOR_FUNCTIONS "    HRSRC hResource = FindResource(nullptr, MAKEINTRESOURCE(k${ResourceIdUpper}), RT_RCDATA);\n")
        string(APPEND ACCESSOR_FUNCTIONS "    if (hResource == nullptr) {\n")
        string(APPEND ACCESSOR_FUNCTIONS "        return {nullptr, 0, resource_tools::ResourceError::NotFound};\n")
        string(APPEND ACCESSOR_FUNCTIONS "    }\n")
        string(APPEND ACCESSOR_FUNCTIONS "    HGLOBAL hMemory = LoadResource(nullptr, hResource);\n")
        string(APPEND ACCESSOR_FUNCTIONS "    if (hMemory == nullptr) {\n")
        string(APPEND ACCESSOR_FUNCTIONS "        return {nullptr, 0, resource_tools::ResourceError::NotFound};\n")
        string(APPEND ACCESSOR_FUNCTIONS "    }\n")
        string(APPEND ACCESSOR_FUNCTIONS "    auto* data = static_cast<const uint8_t*>(LockResource(hMemory));\n")
        string(APPEND ACCESSOR_FUNCTIONS "    DWORD size = SizeofResource(nullptr, hResource);\n")
        string(APPEND ACCESSOR_FUNCTIONS "    return {data, static_cast<size_t>(size), resource_tools::ResourceError::Success};\n")
        string(APPEND ACCESSOR_FUNCTIONS "}\n\n")

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
    set(ACCESSOR_FUNCTIONS "")

    foreach(ResourceFile IN LISTS ER_RESOURCES)
        get_filename_component(ResourceName ${ResourceFile} NAME)
        string(REGEX REPLACE "[^a-zA-Z0-9]" "_" ResourceId ${ResourceName})

        # Create a more readable function name
        get_filename_component(BaseName ${ResourceFile} NAME_WE)
        get_filename_component(Extension ${ResourceFile} EXT)
        string(REPLACE "." "" Extension ${Extension})

        # Convert to proper camelCase
        _convert_to_camel_case("${BaseName}")

        # Handle extension
        string(TOUPPER ${Extension} UpperExtension)
        set(FunctionName "${CamelBaseName}${UpperExtension}")

        set(FullResourcePath "${ER_RESOURCE_DIR}/${ResourceFile}")

        # Check if file is empty
        file(SIZE "${FullResourcePath}" FileSize)
        if(FileSize EQUAL 0)
            message(FATAL_ERROR "Cannot embed empty file: ${ResourceFile}\nEmbedding empty files is not supported as it serves no practical purpose.")
        endif()

        # Use hash for output filenames to avoid path length issues with very long resource names
        # This is needed for both macOS (linker archive limits) and to avoid filesystem limits
        string(MD5 ResourceHash "${ResourceFile}")
        set(OutFile "${CMAKE_CURRENT_BINARY_DIR}/res_${ResourceHash}.o")

        # Generate binary symbol name
        string(REGEX REPLACE "\\." "_" BinarySymbol ${ResourceName})
        string(REGEX REPLACE "[^a-zA-Z0-9_]" "_" BinarySymbol ${BinarySymbol})

        # Symbol name for C linkage (with underscore prefix)
        set(BinarySymbolName "_binary_${BinarySymbol}")

        # Platform-specific linker commands
        if(APPLE)
            # macOS: The toolchain adds underscore prefix automatically
            # C++ extern "C" "_binary_*" -> compiler looks for "__binary_*"
            # Assembly declares "_binary_*" -> assembler produces "__binary_*"
            # So both C++ and assembly use the SAME name with single underscore
            set(AsmSymbolName "${BinarySymbolName}")
            # macOS: Generate assembly file and assemble it
            set(AsmFile "${CMAKE_CURRENT_BINARY_DIR}/res_${ResourceHash}.s")
            # Create a CMake script to generate the assembly file with ABSOLUTE path to resource
            # macOS assembler syntax: use .global (not .globl) and ensure proper symbol visibility
            set(GenScript "${CMAKE_CURRENT_BINARY_DIR}/res_${ResourceHash}_gen.cmake")
            file(WRITE ${GenScript} "file(WRITE \"${AsmFile}\" \".section __DATA,__const\\n.global ${AsmSymbolName}_start\\n${AsmSymbolName}_start:\\n.incbin \\\"${FullResourcePath}\\\"\\n.global ${AsmSymbolName}_end\\n${AsmSymbolName}_end:\\n\")")
            add_custom_command(
                OUTPUT ${OutFile}
                MAIN_DEPENDENCY ${FullResourcePath}
                COMMAND ${CMAKE_COMMAND} -P ${GenScript}
                COMMAND as -o ${OutFile} ${AsmFile}
                DEPENDS ${FullResourcePath}
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
        # macOS: Assembly declares _binary_*, compiler adds another _ -> header needs binary_* (no underscore)
        # Linux: GNU ld generates _binary_*, no compiler prefix -> header needs _binary_* (with underscore)
        if(APPLE)
            set(HeaderSymbolName "binary_${BinarySymbol}")
        else()
            set(HeaderSymbolName "${BinarySymbolName}")
        endif()

        string(APPEND EXTERN_DECLARATIONS "extern \"C\" const uint8_t ${HeaderSymbolName}_start;\n")
        string(APPEND EXTERN_DECLARATIONS "extern \"C\" const uint8_t ${HeaderSymbolName}_end;\n\n")

        # Safe accessor functions (Unix)
        string(APPEND ACCESSOR_FUNCTIONS "inline auto get${FunctionName}() -> resource_tools::ResourceResult {\n")
        string(APPEND ACCESSOR_FUNCTIONS "    return resource_tools::getResource(&${HeaderSymbolName}_start, &${HeaderSymbolName}_end);\n")
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