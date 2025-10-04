# This directory contains the installation test
# It will be configured as an external project during testing

# Create a CMake script to configure and build the installation test
set(INSTALL_TEST_DIR "${CMAKE_BINARY_DIR}/install_test")
set(INSTALL_TEST_BUILD_DIR "${CMAKE_BINARY_DIR}/install_test_build")

# Configure the external test project
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/InstallTest.cmake.in"
    "${CMAKE_BINARY_DIR}/InstallTest.cmake"
    @ONLY
)

# Add test that configures and builds the external project
add_test(NAME test_installed_resource_tools
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_BINARY_DIR}/InstallTest.cmake
)

# This test requires the installation fixture
set_tests_properties(test_installed_resource_tools PROPERTIES
    FIXTURES_REQUIRED install_fixture
)