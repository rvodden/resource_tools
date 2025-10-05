cmake_minimum_required(VERSION 3.20)

project(resource_tools
    VERSION 0.1.1
    DESCRIPTION "Cross-platform resource embedding library"
    LANGUAGES CXX)

# Header-only library for resource utilities
add_library(resource_tools INTERFACE)
add_library(resource_tools::resource_tools ALIAS resource_tools)

target_include_directories(resource_tools
    INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_compile_features(resource_tools INTERFACE cxx_std_20)

# Make the EmbedResources.cmake module available
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(EmbedResources)

# Add tests if this is the main project or if testing is explicitly enabled
if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME OR RESOURCE_TOOLS_BUILD_TESTS OR BUILD_TESTING)
    # Fetch GoogleTest for testing
    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.15.2
        DOWNLOAD_EXTRACT_TIMESTAMP false
    )
    # For Windows: Prevent overriding the parent project's compiler/linker settings
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)

    enable_testing()
    add_subdirectory(test)

    # Add installation tests using fixtures
    set(INSTALL_TEST_DIR "${CMAKE_BINARY_DIR}/install_test")

    # Fixture to install resource_tools to test directory
    add_test(NAME install_resource_tools
        COMMAND ${CMAKE_COMMAND} --install ${CMAKE_BINARY_DIR} --prefix ${INSTALL_TEST_DIR} --component resource_tools
    )
    set_tests_properties(install_resource_tools PROPERTIES
        FIXTURES_SETUP install_fixture
    )

    # Fixture to clean up installation
    add_test(NAME cleanup_resource_tools
        COMMAND ${CMAKE_COMMAND} -E remove_directory ${INSTALL_TEST_DIR}
    )
    set_tests_properties(cleanup_resource_tools PROPERTIES
        FIXTURES_CLEANUP install_fixture
    )

    # Add the installed test
    add_subdirectory(test_installed)
endif()

# Export the module path for consumers
set(resource_tools_CMAKE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cmake" CACHE INTERNAL "")

# Installation support
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Install the library
install(TARGETS resource_tools
    EXPORT resource_toolsTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    COMPONENT resource_tools
)

# Install headers
install(DIRECTORY include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    COMPONENT resource_tools
)

# Install CMake modules
install(FILES cmake/EmbedResources.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/resource_tools
    COMPONENT resource_tools
)

install(DIRECTORY cmake/templates/
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/resource_tools/templates
    COMPONENT resource_tools
)

# Install targets file
install(EXPORT resource_toolsTargets
    FILE resource_toolsTargets.cmake
    NAMESPACE resource_tools::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/resource_tools
    COMPONENT resource_tools
)

# Create config file
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/resource_toolsConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/resource_toolsConfig.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/resource_tools
)

# Create version file
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/resource_toolsConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

# Install config files
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/resource_toolsConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/resource_toolsConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/resource_tools
    COMPONENT resource_tools
)