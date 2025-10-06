#include <gtest/gtest.h>
#include <resource_tools/embedded_resource.h>
#include <edge_case_resources/embedded_data.h>
#include <thread>
#include <vector>
#include <atomic>

class BoundaryConditionsTest : public ::testing::Test {
protected:
    void SetUp() override {}
    void TearDown() override {}
};

// ============================================================================
// EMPTY FILE TESTS
// ============================================================================

TEST_F(BoundaryConditionsTest, EmptyFileHasZeroSize) {
    auto result = edge_case_resources::getEmptyFileDATSafe();

    ASSERT_TRUE(result);
    EXPECT_EQ(result.size, 0u);
    EXPECT_NE(result.data, nullptr);  // Pointer should still be valid
}

TEST_F(BoundaryConditionsTest, EmptyFileDataPointerIsValid) {
    auto result = edge_case_resources::getEmptyFileDATSafe();

    ASSERT_TRUE(result);
    // Even empty files should have valid (non-null) data pointer
    EXPECT_NE(result.data, nullptr);
}

TEST_F(BoundaryConditionsTest, EmptyFileLegacyAPIWorks) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma warning(push)
#pragma warning(disable : 4996)

    auto* data = edge_case_resources::getEmptyFileDATData();
    auto size = edge_case_resources::getEmptyFileDATSize();

    EXPECT_NE(data, nullptr);
    EXPECT_EQ(size, 0u);

#pragma warning(pop)
#pragma clang diagnostic pop
#pragma GCC diagnostic pop
}

// ============================================================================
// LARGE FILE TESTS (5MB)
// ============================================================================

TEST_F(BoundaryConditionsTest, LargeFileCorrectSize) {
    auto result = edge_case_resources::getLargeFileBINSafe();

    ASSERT_TRUE(result);
    EXPECT_EQ(result.size, 5u * 1024u * 1024u);  // 5MB
}

TEST_F(BoundaryConditionsTest, LargeFileUsingSizeT) {
    auto result = edge_case_resources::getLargeFileBINSafe();

    ASSERT_TRUE(result);

    // Verify size_t can handle large files without overflow
    size_t expected_size = 5 * 1024 * 1024;
    EXPECT_EQ(result.size, expected_size);
}

TEST_F(BoundaryConditionsTest, LargeFileDataIntegrity) {
    auto result = edge_case_resources::getLargeFileBINSafe();

    ASSERT_TRUE(result);
    ASSERT_GT(result.size, 0u);

    // Check first and last bytes (dd fills with zeros)
    EXPECT_EQ(result.data[0], 0);
    EXPECT_EQ(result.data[result.size - 1], 0);
}

TEST_F(BoundaryConditionsTest, LargeFileNoUint32Overflow) {
    auto result = edge_case_resources::getLargeFileBINSafe();

    ASSERT_TRUE(result);

    // Verify size fits in uint32_t (5MB does, but we're testing the mechanism)
    EXPECT_LT(result.size, static_cast<size_t>(UINT32_MAX));
}

// ============================================================================
// SPECIAL CHARACTER FILENAME TESTS
// ============================================================================

TEST_F(BoundaryConditionsTest, FilenameWithSpacesWorks) {
    auto result = edge_case_resources::getTestFileWithSpacesTXTSafe();

    ASSERT_TRUE(result);
    EXPECT_GT(result.size, 0u);

    std::string content(reinterpret_cast<const char*>(result.data), result.size);
    EXPECT_EQ(content, "spaces in name\n");
}

TEST_F(BoundaryConditionsTest, FilenameWithSpacesGeneratesValidSymbol) {
    // Spaces should be converted to underscores in symbol names
    auto result = edge_case_resources::getTestFileWithSpacesTXTSafe();

    ASSERT_TRUE(result);
    // If this compiles and runs, the symbol generation worked correctly
    SUCCEED();
}

#ifndef _WIN32
// Windows RC compiler doesn't support Unicode filenames
TEST_F(BoundaryConditionsTest, UnicodeFilenameWorks) {
    // Unicode chars get sanitized to underscores, leaving just extension
    auto result = edge_case_resources::getTXTSafe();

    ASSERT_TRUE(result);
    EXPECT_GT(result.size, 0u);

    std::string content(reinterpret_cast<const char*>(result.data), result.size);
    EXPECT_EQ(content, "unicode test\n");
}
#endif

// ============================================================================
// MULTIPLE DOTS IN FILENAME TESTS
// ============================================================================

TEST_F(BoundaryConditionsTest, MultipleDotsInFilename) {
    auto result = edge_case_resources::getArchiveTARGZSafe();

    ASSERT_TRUE(result);
    EXPECT_GT(result.size, 0u);

    std::string content(reinterpret_cast<const char*>(result.data), result.size);
    EXPECT_EQ(content, "multiple dots\n");
}

TEST_F(BoundaryConditionsTest, MultipleDotsGenerateUniqueSymbol) {
    // archive.tar.gz should generate getArchiveTARGZ* functions
    // and not collide with archive_tar.gz or similar
    auto result = edge_case_resources::getArchiveTARGZSafe();

    ASSERT_TRUE(result);
    // If this compiles, symbol generation handled multiple dots correctly
    SUCCEED();
}

// ============================================================================
// VERY LONG FILENAME TESTS
// ============================================================================

// Platform-specific long filename function names
// Windows: 176 'a's, Unix: 247 'a's
#ifdef _WIN32
#define LONG_FILENAME_FUNC getAaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaTXTSafe
#else
#define LONG_FILENAME_FUNC getAaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaTXTSafe
#endif

TEST_F(BoundaryConditionsTest, VeryLongFilenameWorks) {
    auto result = edge_case_resources::LONG_FILENAME_FUNC();

    ASSERT_TRUE(result);
    EXPECT_GT(result.size, 0u);
}

TEST_F(BoundaryConditionsTest, VeryLongFilenameGeneratesValidIdentifier) {
    // Long filename should be converted to valid C++ identifier
    auto result = edge_case_resources::LONG_FILENAME_FUNC();

    ASSERT_TRUE(result);
    std::string content(reinterpret_cast<const char*>(result.data), result.size);
    EXPECT_EQ(content, "long filename\n");
}

// ============================================================================
// CONCURRENT ACCESS TESTS
// ============================================================================

TEST_F(BoundaryConditionsTest, ConcurrentReadsSameResource) {
    constexpr int num_threads = 10;
    constexpr int reads_per_thread = 1000;
    std::atomic<int> success_count{0};
    std::atomic<int> failure_count{0};

    std::vector<std::thread> threads;
    threads.reserve(num_threads);

    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back([&]() {
            for (int j = 0; j < reads_per_thread; ++j) {
                auto result = edge_case_resources::getLargeFileBINSafe();

                if (result && result.size == 5 * 1024 * 1024) {
                    success_count++;
                } else {
                    failure_count++;
                }
            }
        });
    }

    for (auto& thread : threads) {
        thread.join();
    }

    EXPECT_EQ(success_count.load(), num_threads * reads_per_thread);
    EXPECT_EQ(failure_count.load(), 0);
}

TEST_F(BoundaryConditionsTest, ConcurrentReadsDifferentResources) {
#ifdef _WIN32
    constexpr int num_threads = 6;  // Skip unicode threads on Windows
#else
    constexpr int num_threads = 8;
#endif
    std::atomic<int> total_success{0};
    std::vector<std::thread> threads;

    // Thread 1-2: Read empty file
    for (int i = 0; i < 2; ++i) {
        threads.emplace_back([&]() {
            for (int j = 0; j < 500; ++j) {
                auto result = edge_case_resources::getEmptyFileDATSafe();
                if (result && result.size == 0) {
                    total_success++;
                }
            }
        });
    }

    // Thread 3-4: Read file with spaces
    for (int i = 0; i < 2; ++i) {
        threads.emplace_back([&]() {
            for (int j = 0; j < 500; ++j) {
                auto result = edge_case_resources::getTestFileWithSpacesTXTSafe();
                if (result && result.size > 0) {
                    total_success++;
                }
            }
        });
    }

#ifndef _WIN32
    // Thread 5-6: Read unicode file (sanitized to getTXTSafe())
    // Skipped on Windows due to RC compiler limitations
    for (int i = 0; i < 2; ++i) {
        threads.emplace_back([&]() {
            for (int j = 0; j < 500; ++j) {
                auto result = edge_case_resources::getTXTSafe();
                if (result && result.size > 0) {
                    total_success++;
                }
            }
        });
    }
#endif

    // Thread 7-8: Read archive file
    for (int i = 0; i < 2; ++i) {
        threads.emplace_back([&]() {
            for (int j = 0; j < 500; ++j) {
                auto result = edge_case_resources::getArchiveTARGZSafe();
                if (result && result.size > 0) {
                    total_success++;
                }
            }
        });
    }

    for (auto& thread : threads) {
        thread.join();
    }

    EXPECT_EQ(total_success.load(), num_threads * 500);
}

TEST_F(BoundaryConditionsTest, ConcurrentAccessDataIntegrity) {
    constexpr int num_threads = 4;
    std::atomic<bool> data_corrupted{false};
    std::vector<std::thread> threads;

    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back([&]() {
            for (int j = 0; j < 100; ++j) {
                auto result = edge_case_resources::getTestFileWithSpacesTXTSafe();

                if (result) {
                    std::string content(reinterpret_cast<const char*>(result.data), result.size);
                    if (content != "spaces in name\n") {
                        data_corrupted = true;
                    }
                }
            }
        });
    }

    for (auto& thread : threads) {
        thread.join();
    }

    EXPECT_FALSE(data_corrupted.load()) << "Data corruption detected during concurrent access";
}

// ============================================================================
// NULL POINTER BEHAVIOR CONSISTENCY TESTS
// ============================================================================

TEST_F(BoundaryConditionsTest, NullPointerBehaviorIsConsistent) {
    // Test that all error paths return consistent nullptr behavior

    const uint8_t* valid_ptr = reinterpret_cast<const uint8_t*>(0x1000);

    auto result1 = resource_tools::getResourceSafe(nullptr, valid_ptr);
    auto result2 = resource_tools::getResourceSafe(valid_ptr, nullptr);
    auto result3 = resource_tools::getResourceSafe(nullptr, nullptr);

    // All should fail with NullPointer error
    EXPECT_FALSE(result1);
    EXPECT_FALSE(result2);
    EXPECT_FALSE(result3);

    EXPECT_EQ(result1.error, resource_tools::ResourceError::NullPointer);
    EXPECT_EQ(result2.error, resource_tools::ResourceError::NullPointer);
    EXPECT_EQ(result3.error, resource_tools::ResourceError::NullPointer);

    // All should have nullptr data
    EXPECT_EQ(result1.data, nullptr);
    EXPECT_EQ(result2.data, nullptr);
    EXPECT_EQ(result3.data, nullptr);

    // All should have zero size
    EXPECT_EQ(result1.size, 0u);
    EXPECT_EQ(result2.size, 0u);
    EXPECT_EQ(result3.size, 0u);
}

TEST_F(BoundaryConditionsTest, InvalidSizeBehaviorIsConsistent) {
    const uint8_t data[] = "test";
    const uint8_t* start = data + 4;
    const uint8_t* end = data;  // end < start

    auto result = resource_tools::getResourceSafe(start, end);

    EXPECT_FALSE(result);
    EXPECT_EQ(result.error, resource_tools::ResourceError::InvalidSize);
    EXPECT_EQ(result.data, nullptr);
    EXPECT_EQ(result.size, 0u);
}