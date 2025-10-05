# Use our embed_resources function to create embedded test data
embed_resources(
    TARGET resource_tools_test
    RESOURCES test_file.txt binary_data.bin
    RESOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/data
    NAMESPACE test_resources
)

add_executable(resource_tools_test resource_tools_test.cpp)

# Include the resource_tools library
target_link_libraries(resource_tools_test PRIVATE resource_tools)

# Link the embedded data
target_link_libraries(resource_tools_test PRIVATE resource_tools_test-data)

# Add GoogleTest (fetched by parent CMakeLists.txt)
target_link_libraries(resource_tools_test PRIVATE GTest::gtest GTest::gtest_main)

# Link math library on Unix systems (required by GoogleTest)
if(UNIX AND NOT APPLE)
    target_link_libraries(resource_tools_test PRIVATE m)
endif()

# Register the test
include(GoogleTest)
gtest_discover_tests(resource_tools_test)