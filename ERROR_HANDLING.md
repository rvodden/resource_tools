# Error Handling in resource_tools

This document describes the comprehensive error handling system implemented in resource_tools.

## Table of Contents

1. [Overview](#overview)
2. [Build-Time Error Handling](#build-time-error-handling)
3. [Runtime Error Handling](#runtime-error-handling)
4. [Migration Guide](#migration-guide)
5. [Debugging and Diagnostics](#debugging-and-diagnostics)

---

## Overview

resource_tools implements a **layered error handling strategy**:

- **Build-Time (CMake)**: Input validation, path sanitization, duplicate detection
- **Runtime (C++)**: Safe accessors with error codes or std::expected
- **Diagnostics**: Manifest files and optional logging callbacks

### Error Handling Layers

```
┌─────────────────────────────────────┐
│  Build Time (CMake)                 │  → FATAL_ERROR + diagnostic output
├─────────────────────────────────────┤
│  Code Generation                     │  → Manifest files + validation
├─────────────────────────────────────┤
│  Runtime (Safe API)                 │  → ResourceResult or std::expected
└─────────────────────────────────────┘
```

---

## Build-Time Error Handling

### Input Validation

The `embed_resources()` CMake function validates all inputs before code generation:

#### Namespace Validation

```cmake
embed_resources(
    TARGET my_app
    RESOURCES data.txt
    NAMESPACE invalid-namespace  # ❌ ERROR: hyphens not allowed
)
```

**Error:**
```
embed_resources: Invalid namespace 'invalid-namespace'
  Namespace must be a valid C++ identifier (letters, numbers, underscores)
  Must start with letter or underscore
  Examples: 'my_resources', 'gameAssets', 'res_v2'
```

#### Missing File Detection

```cmake
embed_resources(
    TARGET my_app
    RESOURCES missing.png data.json
    RESOURCE_DIR assets/
)
```

**Error:**
```
embed_resources: Missing or invalid resource files:
  - missing.png (expected at: /path/to/assets/missing.png)
  RESOURCE_DIR: /path/to/assets
  Check that files exist and paths are correct
```

#### Security: Path Traversal Prevention

```cmake
embed_resources(
    TARGET my_app
    RESOURCES ../../etc/passwd  # ❌ SECURITY ERROR
)
```

**Error:**
```
embed_resources: Invalid resource paths detected:
  - ../../etc/passwd (contains '..' - potential security issue)
  Security: Paths must be relative to RESOURCE_DIR and not contain '..'
```

#### Duplicate Symbol Detection

```cmake
embed_resources(
    TARGET my_app
    RESOURCES logo.png LOGO.PNG  # ❌ Both create symbol 'logo_png'
)
```

**Error:**
```
embed_resources: Duplicate symbol name 'logo_png'
  Files: LOGO.PNG and another file create the same symbol
  Rename one of the files to avoid collision
```

### Manifest Generation

Every embedded resource target generates a manifest file for debugging:

**Location:** `${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_resources.manifest`

**Example:**
```
# Resource Embedding Manifest
Target: my_app
Namespace: game_assets
Platform: Linux

Resources:
  logo.png (12 KB)
  - game_assets::getLogoPNGData()
  - game_assets::getLogoPNGSafe()
```

**View manifest:**
```bash
cmake --build build --target my_app-manifest
```

### Verbose Mode

Enable detailed diagnostic output:

```cmake
set(RESOURCE_TOOLS_VERBOSE ON)
# or
cmake -B build -DRESOURCE_TOOLS_VERBOSE=ON
```

Output:
```
-- embed_resources configuration:
--   Target: my_app
--   Namespace: assets
--   Resources (3 files):
--     - logo.png (48 KB)
--     - font.ttf (120 KB)
--     - data.json (2 KB)
```

---

## Runtime Error Handling

### Safe API (C++20 Compatible)

The safe API returns `ResourceResult` with explicit error codes:

```cpp
#include <resource_tools/embedded_resource.h>
#include <my_resources/embedded_data.h>

auto result = my_resources::getLogoPNGSafe();

if (result) {
    // Success
    const uint8_t* data = result.data;
    size_t size = result.size;
    // Use data...
} else {
    // Error
    std::cerr << "Failed to load logo: "
              << result.error_message() << "\n";
}
```

### Error Codes

```cpp
enum class ResourceError {
    Success,        // No error
    NullPointer,    // Null pointer encountered
    InvalidSize,    // Size calculation failed (end < start)
    IntegerOverflow,// Resource exceeds size limits
    NotFound        // Resource not found (Windows only)
};
```

### ResourceResult API

```cpp
struct ResourceResult {
    const uint8_t* data;
    size_t size;
    ResourceError error;

    explicit operator bool() const;  // Check success
    auto error_message() const -> const char*;
};
```

### C++23 std::expected API

If C++23 is available, use `std::expected`:

```cpp
#if RESOURCE_TOOLS_HAS_EXPECTED

auto result = resource_tools::getResourceExpected(start, end);

if (result) {
    auto [data, size] = *result;
    // Use data...
} else {
    std::cerr << "Error: "
              << resource_tools::to_string(result.error()) << "\n";
}

#endif
```

---

## Using with SDL/Libraries

**SDL Example:**
```cpp
auto load_font(int size) -> TTF_Font* {
    auto result = fonts::getArialTTFSafe();

    if (!result) {
        SDL_Log("Font load failed: %s", result.error_message());
        return nullptr;
    }

    SDL_RWops* rw = SDL_RWFromConstMem(result.data, result.size);
    return TTF_OpenFontRW(rw, 1, size);
}
```

**Image Loading:**
```cpp
auto load_texture(SDL_Renderer* renderer) -> SDL_Texture* {
    auto result = images::getLogoPNGSafe();

    if (!result) {
        return nullptr;
    }

    SDL_RWops* rw = SDL_RWFromConstMem(result.data, result.size);
    return IMG_LoadTexture_RW(renderer, rw, 1);
}
```

---

## Debugging and Diagnostics

### Diagnostic Callbacks

Set a callback to receive detailed error information:

```cpp
#ifdef DEBUG
resource_tools::setDiagnosticCallback([](const char* msg) {
    std::cout << "[RESOURCE] " << msg << std::endl;
});
#endif
```

### Build Diagnostics

**View manifest for a target:**
```bash
cmake --build build --target my_app-manifest
```

**Enable verbose CMake output:**
```bash
cmake -B build -DRESOURCE_TOOLS_VERBOSE=ON
cmake --build build --verbose
```

### Common Error Scenarios

#### 1. Null Pointer Errors

```cpp
auto result = getResourceSafe(nullptr, end);
// result.error == ResourceError::NullPointer
// result.error_message() == "Null pointer encountered"
```

#### 2. Invalid Size Errors

```cpp
const uint8_t* start = data + 10;
const uint8_t* end = data;  // end < start

auto result = getResourceSafe(start, end);
// result.error == ResourceError::InvalidSize
// result.error_message() == "Invalid resource size (end < start)"
```

#### 3. Resource Not Found (Windows)

```cpp
auto result = my_resources::getMissingSafe();
// result.error == ResourceError::NotFound
// result.error_message() == "Resource not found"
```

---

## Best Practices

### 1. Always Use Safe Accessors

```cpp
// ✅ Good
auto result = resources::getDataSafe();
if (!result) {
    handle_error(result.error);
}
```

### 2. Check Errors Before Use

```cpp
// ✅ Good
auto result = resources::getConfigSafe();
if (result) {
    parse_config(result.data, result.size);
}

// ❌ Bad
auto result = resources::getConfigSafe();
parse_config(result.data, result.size);  // May crash if failed
```

### 3. Log Errors for Debugging

```cpp
auto result = resources::getAssetSafe();
if (!result) {
    // ✅ Helpful error message
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Failed to load asset: %s",
                 result.error_message());
    return nullptr;
}
```

### 4. Use Verbose Mode During Development

```cmake
# CMakeLists.txt
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(RESOURCE_TOOLS_VERBOSE ON)
endif()
```

---

## Performance Considerations

- **Zero overhead in Release**: Error checking compiles to minimal assembly
- **Safe API is inline**: No function call overhead
- **Manifest generation**: Only at CMake configure time
- **Size_t support**: Large files (>4GB) use `size_t` without performance penalty

---

## Security Benefits

1. **Path Sanitization**: Prevents directory traversal attacks
2. **Input Validation**: Rejects malformed namespaces and paths
3. **Bounds Checking**: Prevents buffer overflows from size calculations
4. **No Silent Failures**: All errors are explicit and reportable

---

## Summary

| Feature | Safe API | Expected API (C++23) |
|---------|----------|---------------------|
| Error Handling | ✅ Error codes | ✅ std::expected |
| Null Safety | ✅ Checked | ✅ Checked |
| Large Files (>4GB) | ✅ size_t | ✅ size_t |
| Error Messages | ✅ Yes | ✅ Yes |

**Recommendation:** Use Safe API for all code. Use Expected API when C++23 is available.