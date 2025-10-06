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
    auto result = test_resources::getTestFileTXTSafe();

    ASSERT_TRUE(result);
    EXPECT_GT(result.size, 0u);

    // Verify the content
    std::string content(reinterpret_cast<const char*>(result.data), result.size);
    EXPECT_EQ(content, "Hello, Resource Tools!");
}

TEST_F(ResourceToolsTest, BinaryResourceAccess) {
    // Test accessing the embedded binary file
    auto result = test_resources::getBinaryDataBINSafe();

    ASSERT_TRUE(result);
    EXPECT_GT(result.size, 0u);

    // Verify the content
    std::string content(reinterpret_cast<const char*>(result.data), result.size);
    EXPECT_EQ(content, "TESTBINARY");
}

TEST_F(ResourceToolsTest, ResourceSizeUtility) {
    // Test the safe resource access
    auto result = test_resources::getTestFileTXTSafe();

    ASSERT_TRUE(result);
    EXPECT_EQ(result.error, resource_tools::ResourceError::Success);
    EXPECT_NE(result.data, nullptr);
    EXPECT_GT(result.size, 0u);
}

TEST_F(ResourceToolsTest, ResourceSizesAreCorrect) {
    // Verify our test files have expected sizes
    auto txt_result = test_resources::getTestFileTXTSafe();
    auto bin_result = test_resources::getBinaryDataBINSafe();

    ASSERT_TRUE(txt_result);
    ASSERT_TRUE(bin_result);

    EXPECT_EQ(txt_result.size, 22u); // "Hello, Resource Tools!" = 22 chars
    EXPECT_EQ(bin_result.size, 10u); // "TESTBINARY" = 10 chars
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