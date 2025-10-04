cmake_minimum_required(VERSION 3.20)
project(test_installed_resource_tools)

# This project tests the installed version of resource_tools
find_package(resource_tools REQUIRED CONFIG)

# Test data files
set(TEST_DATA_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

# Use resource_tools to embed test resources
embed_resources(
    TARGET test_app
    RESOURCES sample.txt test_image.png
    RESOURCE_DIR ${TEST_DATA_DIR}
    NAMESPACE test_ns
)

# Create test executable
add_executable(test_app main.cpp)

# Link with embedded resources and resource_tools
target_link_libraries(test_app PRIVATE test_app-data resource_tools::resource_tools)

# Try to find GoogleTest
find_package(GTest QUIET)
if(GTest_FOUND)
    target_link_libraries(test_app PRIVATE GTest::gtest GTest::gtest_main)
    target_compile_definitions(test_app PRIVATE GTEST_FOUND)
    message(STATUS "Using GoogleTest for installation tests")

    # Link math library on Unix systems (required by GoogleTest)
    if(UNIX AND NOT APPLE)
        target_link_libraries(test_app PRIVATE m)
    endif()
else()
    message(STATUS "GoogleTest not found, using simple test framework")
endif()