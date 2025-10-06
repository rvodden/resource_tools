# Use our embed_resources function to create embedded test data
embed_resources(
    TARGET resource_tools_test
    RESOURCES test_file.txt binary_data.bin
    RESOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/data
    NAMESPACE test_resources
)

# Generate platform-appropriate long filename test file
# Windows: MAX_PATH = 260, leave room for path prefix (~200 char filename)
# Unix: Much longer limits (typically 255 for filename)
if(WIN32)
    # Windows: Use 180 character filename (safe for MAX_PATH with typical paths)
    string(REPEAT "a" 176 LONG_NAME_BASE)
    set(LONG_FILENAME "${LONG_NAME_BASE}.txt")
else()
    # Unix: Use 251 character filename (255 - ".txt")
    string(REPEAT "a" 247 LONG_NAME_BASE)
    set(LONG_FILENAME "${LONG_NAME_BASE}.txt")
endif()

# Create the long filename test file if it doesn't exist
set(LONG_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/data/${LONG_FILENAME}")
if(NOT EXISTS "${LONG_FILE_PATH}")
    file(WRITE "${LONG_FILE_PATH}" "long filename\n")
    message(STATUS "Created long filename test file: ${LONG_FILENAME}")
endif()

# Edge case resources - test boundary conditions
# Note: Unicode filenames excluded on Windows due to RC compiler limitations
# Note: empty_file.dat removed - empty files are not supported
set(EDGE_CASE_RESOURCES
    large_file.bin
    "test file with spaces.txt"
    archive.tar.gz
    "${LONG_FILENAME}"
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