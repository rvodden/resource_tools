#include <gtest/gtest.h>
#include <resource_tools/embedded_resource.h>
#include <test_resources/embedded_data.h>
#include <cstring>

class ResourceToolsTest : public ::testing::Test {
protected:
    void SetUp() override {}
    void TearDown() override {}
};

TEST_F(ResourceToolsTest, TestFileResourceAccess) {
    // Test accessing the embedded text file
    auto* data = test_resources::getTestFileTXTData();
    auto size = test_resources::getTestFileTXTSize();

    ASSERT_NE(data, nullptr);
    EXPECT_GT(size, 0u);

    // Verify the content
    std::string content(reinterpret_cast<const char*>(data), size);
    EXPECT_EQ(content, "Hello, Resource Tools!");
}

TEST_F(ResourceToolsTest, BinaryResourceAccess) {
    // Test accessing the embedded binary file
    auto* data = test_resources::getBinaryDataBINData();
    auto size = test_resources::getBinaryDataBINSize();

    ASSERT_NE(data, nullptr);
    EXPECT_GT(size, 0u);

    // Verify the content
    std::string content(reinterpret_cast<const char*>(data), size);
    EXPECT_EQ(content, "TESTBINARY");
}

TEST_F(ResourceToolsTest, ResourceSizeUtility) {
    // Test the utility functions from embedded_resource.h
    auto* start_data = test_resources::getTestFileTXTData();
    auto size = test_resources::getTestFileTXTSize();

    // Test getResourceData utility (should return same pointer)
    auto* util_data = resource_tools::getResourceData(start_data);
    EXPECT_EQ(start_data, util_data);

#ifndef _WIN32
    // On Unix systems, we can test the size calculation utility
    // Note: We can't easily test this on Windows without access to end pointers
#ifdef __APPLE__
    auto calculated_size = resource_tools::getResourceSize(&test_resources::binary_test_file_txt_start, &test_resources::binary_test_file_txt_end);
#else
    auto calculated_size = resource_tools::getResourceSize(&test_resources::_binary_test_file_txt_start, &test_resources::_binary_test_file_txt_end);
#endif
    EXPECT_EQ(calculated_size, size);
#endif
}

TEST_F(ResourceToolsTest, ResourceSizesAreCorrect) {
    // Verify our test files have expected sizes
    auto txt_size = test_resources::getTestFileTXTSize();
    auto bin_size = test_resources::getBinaryDataBINSize();

    EXPECT_EQ(txt_size, 22u); // "Hello, Resource Tools!" = 22 chars
    EXPECT_EQ(bin_size, 10u); // "TESTBINARY" = 10 chars
}

#ifndef _WIN32
// Test cross-platform binary symbol access (Unix-style symbols)
TEST_F(ResourceToolsTest, BinarySymbolAccess) {
    // Test that we can access the binary symbols directly
#ifdef __APPLE__
    std::string txt_content(reinterpret_cast<const char*>(&test_resources::binary_test_file_txt_start), 22);
    EXPECT_EQ(txt_content, "Hello, Resource Tools!");

    std::string bin_content(reinterpret_cast<const char*>(&test_resources::binary_binary_data_bin_start), 10);
    EXPECT_EQ(bin_content, "TESTBINARY");
#else
    std::string txt_content(reinterpret_cast<const char*>(&test_resources::_binary_test_file_txt_start), 22);
    EXPECT_EQ(txt_content, "Hello, Resource Tools!");

    std::string bin_content(reinterpret_cast<const char*>(&test_resources::_binary_binary_data_bin_start), 10);
    EXPECT_EQ(bin_content, "TESTBINARY");
#endif
}
#endif