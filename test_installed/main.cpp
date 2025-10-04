#include <iostream>
#include <string>
#include <resource_tools/embedded_resource.h>
#include <test_ns/embedded_data.h>

#ifdef GTEST_FOUND
#include <gtest/gtest.h>

TEST(InstalledResourceToolsTest, SampleTextFile) {
    auto* data = test_ns::getSampleTXTData();
    auto size = test_ns::getSampleTXTSize();

    ASSERT_NE(data, nullptr);
    EXPECT_GT(size, 0u);

    std::string content(reinterpret_cast<const char*>(data), size);
    EXPECT_EQ(content, "This is a test file for the installed resource_tools library!");
}

TEST(InstalledResourceToolsTest, TestImage) {
    auto* data = test_ns::getTestImagePNGData();
    auto size = test_ns::getTestImagePNGSize();

    ASSERT_NE(data, nullptr);
    EXPECT_GT(size, 0u);

    // Just verify we can read the placeholder data
    std::string content(reinterpret_cast<const char*>(data), size);
    EXPECT_EQ(content, "PNG_PLACEHOLDER_DATA");
}

TEST(InstalledResourceToolsTest, UtilityFunctions) {
    auto* data = test_ns::getSampleTXTData();
    auto size = test_ns::getSampleTXTSize();

    // Test the utility functions from embedded_resource.h
    auto* util_data = resource_tools::getResourceData(data);
    EXPECT_EQ(data, util_data);

#ifndef _WIN32
    // On Unix systems, we can test the size calculation utility
    extern "C" const uint8_t _binary_sample_txt_start;
    extern "C" const uint8_t _binary_sample_txt_end;

    auto calculated_size = resource_tools::getResourceSize(&_binary_sample_txt_start, &_binary_sample_txt_end);
    EXPECT_EQ(calculated_size, size);
#endif
}

int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}

#else

// Simple test without GoogleTest
int main() {
    std::cout << "Testing installed resource_tools library...\n";

    // Test sample.txt
    auto* sample_data = test_ns::getSampleTXTData();
    auto sample_size = test_ns::getSampleTXTSize();

    if (sample_data == nullptr) {
        std::cerr << "ERROR: getSampleTXTData() returned nullptr\n";
        return 1;
    }

    if (sample_size == 0) {
        std::cerr << "ERROR: getSampleTXTSize() returned 0\n";
        return 1;
    }

    std::string sample_content(reinterpret_cast<const char*>(sample_data), sample_size);
    std::cout << "Sample content: " << sample_content << "\n";
    std::cout << "Sample size: " << sample_size << " bytes\n";

    if (sample_content != "This is a test file for the installed resource_tools library!") {
        std::cerr << "ERROR: Sample content doesn't match expected value\n";
        return 1;
    }

    // Test test_image.png
    auto* image_data = test_ns::getTestImagePNGData();
    auto image_size = test_ns::getTestImagePNGSize();

    if (image_data == nullptr) {
        std::cerr << "ERROR: getTestImagePNGData() returned nullptr\n";
        return 1;
    }

    if (image_size == 0) {
        std::cerr << "ERROR: getTestImagePNGSize() returned 0\n";
        return 1;
    }

    std::string image_content(reinterpret_cast<const char*>(image_data), image_size);
    std::cout << "Image content: " << image_content << "\n";
    std::cout << "Image size: " << image_size << " bytes\n";

    if (image_content != "PNG_PLACEHOLDER_DATA") {
        std::cerr << "ERROR: Image content doesn't match expected value\n";
        return 1;
    }

    // Test utility functions
    auto* util_data = resource_tools::getResourceData(sample_data);
    if (util_data != sample_data) {
        std::cerr << "ERROR: getResourceData() returned different pointer\n";
        return 1;
    }

    std::cout << "SUCCESS: All tests passed!\n";
    std::cout << "Installed resource_tools library is working correctly.\n";
    return 0;
}

#endif