# Installation Test for resource_tools

This directory contains tests that verify resource_tools works correctly when installed as an external package.

## How it works

The installation test uses CMake fixtures to:

1. **Setup Fixture** (`install_resource_tools`): Installs resource_tools to `${CMAKE_BINARY_DIR}/install_test`
2. **Test** (`test_installed_resource_tools`): Configures, builds, and runs a test project against the installed version
3. **Cleanup Fixture** (`cleanup_resource_tools`): Removes the installation directory

## Running the installation test

```bash
# From the resource_tools build directory
ctest -R install_resource_tools

# Or run all tests (which will include the installation test)
ctest
```

## Test Project Structure

- `test_project/`: Contains a minimal CMake project that uses resource_tools
- `InstallTest.cmake.in`: CMake script template that handles the external project testing
- `CMakeLists.txt`: Sets up the test using fixtures

## What gets tested

- Installation of all required files (headers, CMake modules, templates)
- `find_package(resource_tools)` works correctly
- `embed_resources()` function is available and working
- Generated headers and functions work correctly
- Both utility functions and resource access functions work

This ensures resource_tools is ready to be extracted to its own repository and used as an external dependency.