#ifndef RESOURCE_TOOLS_EMBEDDED_RESOURCE_H
#define RESOURCE_TOOLS_EMBEDDED_RESOURCE_H

#include <cstdint>
#include <cstddef>

// Check for C++23 std::expected support
#if __cplusplus >= 202302L && __has_include(<expected>)
    #include <expected>
    #define RESOURCE_TOOLS_HAS_EXPECTED 1
#else
    #define RESOURCE_TOOLS_HAS_EXPECTED 0
#endif

namespace resource_tools {

/**
 * Error codes for resource operations
 */
enum class ResourceError : uint32_t {
    Success = 0,
    NullPointer = 1,
    InvalidSize = 2,
    IntegerOverflow = 3,
    NotFound = 4
};

/**
 * Convert error code to human-readable string
 */
inline auto to_string(ResourceError err) -> const char* {
    switch(err) {
        case ResourceError::Success: return "Success";
        case ResourceError::NullPointer: return "Null pointer encountered";
        case ResourceError::InvalidSize: return "Invalid resource size (end < start)";
        case ResourceError::IntegerOverflow: return "Resource size exceeds uint32_t limit";
        case ResourceError::NotFound: return "Resource not found";
    }
    return "Unknown error";
}

/**
 * Resource data container with size
 */
struct ResourceData {
    const uint8_t* data;
    size_t size;

    /**
     * Convert resource data to string view (requires <string_view>)
     */
    #if __has_include(<string_view>)
    #include <string_view>
    auto as_string_view() const -> std::string_view {
        return std::string_view(reinterpret_cast<const char*>(data), size);
    }
    #endif
};

/**
 * Result type for operations that can fail
 * Contains either ResourceData or ResourceError
 */
struct ResourceResult {
    const uint8_t* data = nullptr;
    size_t size = 0;
    ResourceError error = ResourceError::Success;

    /**
     * Check if operation succeeded
     */
    explicit operator bool() const { return error == ResourceError::Success; }

    /**
     * Get error message
     */
    auto error_message() const -> const char* {
        return to_string(error);
    }
};

// ============================================================================
// SAFE API (C++20 compatible - returns ResourceResult)
// ============================================================================

/**
 * Safely get resource size with bounds checking
 *
 * @param start Pointer to start of resource data
 * @param end Pointer to end of resource data
 * @return ResourceResult with size or error
 */
inline auto getResourceSafe(const uint8_t* start, const uint8_t* end) -> ResourceResult {
    if (!start) {
        return {nullptr, 0, ResourceError::NullPointer};
    }

    if (!end) {
        return {nullptr, 0, ResourceError::NullPointer};
    }

    if (end < start) {
        return {nullptr, 0, ResourceError::InvalidSize};
    }

    size_t size = static_cast<size_t>(end - start);
    return {start, size, ResourceError::Success};
}

/**
 * Safely get resource size as size_t (for large files)
 *
 * @param start Pointer to start of resource data
 * @param end Pointer to end of resource data
 * @return ResourceResult with size or error
 */
inline auto getResourceSizeSafe(const uint8_t* start, const uint8_t* end) -> ResourceResult {
    return getResourceSafe(start, end);
}

// ============================================================================
// C++23 EXPECTED API (if available)
// ============================================================================

#if RESOURCE_TOOLS_HAS_EXPECTED

/**
 * Get resource data using std::expected (C++23)
 *
 * @param start Pointer to start of resource data
 * @param end Pointer to end of resource data
 * @return std::expected containing ResourceData or ResourceError
 */
inline auto getResourceExpected(const uint8_t* start, const uint8_t* end)
    -> std::expected<ResourceData, ResourceError>
{
    if (!start || !end) {
        return std::unexpected(ResourceError::NullPointer);
    }

    if (end < start) {
        return std::unexpected(ResourceError::InvalidSize);
    }

    size_t size = static_cast<size_t>(end - start);
    return ResourceData{start, size};
}

#endif // RESOURCE_TOOLS_HAS_EXPECTED

// ============================================================================
// LEGACY/UNSAFE API (for backward compatibility)
// ============================================================================

/**
 * Get the size of an embedded resource in bytes (LEGACY - unsafe)
 *
 * @param start Pointer to the start of the embedded resource data
 * @param end Pointer to the end of the embedded resource data
 * @return Size of the resource in bytes (uint32_t - may overflow for files >4GB)
 *
 * @deprecated Use getResourceSafe() or getResourceExpected() instead
 *
 * Usage:
 *   extern "C" const uint8_t _binary_my_file_ext_start;
 *   extern "C" const uint8_t _binary_my_file_ext_end;
 *   auto size = resource_tools::getResourceSize(&_binary_my_file_ext_start, &_binary_my_file_ext_end);
 */
[[deprecated("Use getResourceSafe() which returns ResourceResult with proper error handling")]]
inline auto getResourceSize(const uint8_t* start, const uint8_t* end) -> uint32_t {
    return static_cast<uint32_t>(end - start);
}

/**
 * Get pointer to embedded resource data (LEGACY - unsafe)
 * This is primarily for consistency - on most platforms you can use the start pointer directly.
 *
 * @param start Pointer to the start of the embedded resource data
 * @return Pointer to the resource data (same as input for most platforms)
 *
 * @deprecated Use getResourceSafe() or getResourceExpected() instead
 *
 * Usage:
 *   extern "C" const uint8_t _binary_my_file_ext_start;
 *   auto* data = resource_tools::getResourceData(&_binary_my_file_ext_start);
 */
[[deprecated("Use getResourceSafe() which returns ResourceResult with proper error handling")]]
inline auto getResourceData(const uint8_t* start) -> const uint8_t* {
    return start;
}

// ============================================================================
// DIAGNOSTIC/DEBUG SUPPORT
// ============================================================================

/**
 * Diagnostic callback function type
 * Called when resource operations encounter errors or warnings
 */
using DiagnosticCallback = void(*)(const char* message);

namespace detail {
    inline DiagnosticCallback g_diagnostic_callback = nullptr;
}

/**
 * Set diagnostic callback for debugging resource loading issues
 *
 * @param callback Function to call with diagnostic messages (nullptr to disable)
 *
 * Example:
 *   resource_tools::setDiagnosticCallback([](const char* msg) {
 *       std::cerr << "[RESOURCE] " << msg << std::endl;
 *   });
 */
inline void setDiagnosticCallback(DiagnosticCallback callback) {
    detail::g_diagnostic_callback = callback;
}

/**
 * Internal: Log diagnostic message
 */
namespace detail {
    inline void diagnostic_log(const char* message) {
        if (g_diagnostic_callback) {
            g_diagnostic_callback(message);
        }
    }
}

} // namespace resource_tools

#endif // RESOURCE_TOOLS_EMBEDDED_RESOURCE_H