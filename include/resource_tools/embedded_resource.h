#ifndef RESOURCE_TOOLS_EMBEDDED_RESOURCE_H
#define RESOURCE_TOOLS_EMBEDDED_RESOURCE_H

#include <cstdint>

namespace resource_tools {

/**
 * Utility functions for accessing embedded binary resources.
 * Provides a unified interface across platforms for resources embedded via CMake.
 */

/**
 * Get the size of an embedded resource in bytes.
 *
 * @param start Pointer to the start of the embedded resource data
 * @param end Pointer to the end of the embedded resource data
 * @return Size of the resource in bytes
 *
 * Usage:
 *   extern "C" const uint8_t _binary_my_file_ext_start;
 *   extern "C" const uint8_t _binary_my_file_ext_end;
 *   auto size = resource_tools::getResourceSize(&_binary_my_file_ext_start, &_binary_my_file_ext_end);
 */
inline auto getResourceSize(const uint8_t* start, const uint8_t* end) -> uint32_t {
    return static_cast<uint32_t>(end - start);
}

/**
 * Get pointer to embedded resource data.
 * This is primarily for consistency - on most platforms you can use the start pointer directly.
 *
 * @param start Pointer to the start of the embedded resource data
 * @return Pointer to the resource data (same as input for most platforms)
 *
 * Usage:
 *   extern "C" const uint8_t _binary_my_file_ext_start;
 *   auto* data = resource_tools::getResourceData(&_binary_my_file_ext_start);
 */
inline auto getResourceData(const uint8_t* start) -> const uint8_t* {
    return start;
}

} // namespace resource_tools

#endif // RESOURCE_TOOLS_EMBEDDED_RESOURCE_H