# Use our embed_resources function to create embedded test data
embed_resources(
    TARGET resource_tools_test
    RESOURCES test_file.txt binary_data.bin
    RESOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/data
    NAMESPACE test_resources
)

# Edge case resources - test boundary conditions
# Note: Unicode filenames excluded on Windows due to RC compiler limitations
set(EDGE_CASE_RESOURCES
    empty_file.dat
    large_file.bin
    "test file with spaces.txt"
    archive.tar.gz
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.txt
)

if(NOT WIN32)
    list(APPEND EDGE_CASE_RESOURCES "файл.txt")
endif()

embed_resources(
    TARGET edge_case_test
    RESOURCES ${EDGE_CASE_RESOURCES}
    RESOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/data
    NAMESPACE edge_case_resources
)

add_executable(resource_tools_test
    resource_tools_test.cpp
    error_handling_test.cpp
    boundary_conditions_test.cpp
)

# Include the resource_tools library
target_link_libraries(resource_tools_test PRIVATE resource_tools)

# Link the embedded data
target_link_libraries(resource_tools_test PRIVATE
    resource_tools_test-data
    edge_case_test-data
)

# Add GoogleTest (fetched by parent CMakeLists.txt)
target_link_libraries(resource_tools_test PRIVATE GTest::gtest GTest::gtest_main)

# Link math library on Unix systems (required by GoogleTest)
if(UNIX AND NOT APPLE)
    target_link_libraries(resource_tools_test PRIVATE m)
endif()

# Register the test
include(GoogleTest)
gtest_discover_tests(resource_tools_test)