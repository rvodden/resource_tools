# resource_tools

[![CI](https://github.com/rvodden/resource_tools/actions/workflows/ci.yml/badge.svg)](https://github.com/rvodden/resource_tools/actions/workflows/ci.yml)
[![Release](https://github.com/rvodden/resource_tools/actions/workflows/release.yml/badge.svg)](https://github.com/rvodden/resource_tools/actions/workflows/release.yml)
[![License](https://img.shields.io/badge/license-LGPL-blue.svg)](LICENSE)

A cross-platform CMake library for embedding binary resources into C++ applications.

## Features

- 🔧 **Cross-platform**: Works on Windows (RC files) and Unix/Linux (object files)
- 📦 **Easy to use**: Simple CMake function to embed any files
- 🎯 **Type-safe**: Generates clean C++ functions with proper types
- 🛡️ **Safe by default**: Comprehensive error handling with `ResourceResult` API
- 🔄 **Template-based**: Maintainable code generation
- 📱 **Header-only**: No runtime dependencies
- 🧪 **Well-tested**: Comprehensive test suite including installation tests
- 🔒 **Secure**: Input validation, path sanitization, and bounds checking

## Quick Start

### Installation (Recommended: FetchContent)

The easiest way to use resource_tools is with CMake's FetchContent:

```cmake
include(FetchContent)

FetchContent_Declare(
    resource_tools
    GIT_REPOSITORY https://github.com/rvodden/resource_tools.git
    GIT_TAG v1.0.0  # Or use 'main' for latest
    OVERRIDE_FIND_PACKAGE  # Makes find_package() use this
)
FetchContent_MakeAvailable(resource_tools)
```

That's it! The `embed_resources()` function is now available in your project.

### Alternative Installation Methods

<details>
<summary>System Installation (Click to expand)</summary>

```bash
# Clone a specific release
git clone -b v1.0.0 https://github.com/rvodden/resource_tools.git
cd resource_tools
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
sudo cmake --install build --prefix /usr/local
```

Then in your CMakeLists.txt:
```cmake
find_package(resource_tools REQUIRED)
```
</details>

<details>
<summary>Git Submodule (Click to expand)</summary>

```bash
git submodule add https://github.com/rvodden/resource_tools.git third_party/resource_tools
```

Then in your CMakeLists.txt:
```cmake
add_subdirectory(third_party/resource_tools)
```
</details>

### Usage

1. **Embed your resources:**

```cmake
embed_resources(
    TARGET my_app
    RESOURCES logo.png font.ttf config.json
    RESOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/assets
    NAMESPACE my_resources
)
```

2. **Link to your target:**

```cmake
add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE my_app-data resource_tools::resource_tools)
```

3. **Use in C++ code (Safe API):**

```cpp
#include <my_resources/embedded_data.h>

int main() {
    // Safe access with error handling
    auto result = my_resources::getLogoPNGSafe();

    if (result) {
        const uint8_t* data = result.data;
        size_t size = result.size;
        // Use data safely...
    } else {
        std::cerr << "Failed: " << result.error_message() << "\n";
        return 1;
    }

    return 0;
}
```

## API Reference

### CMake Functions

#### `embed_resources`

Embeds binary files as C++ resources.

```cmake
embed_resources(
    TARGET <target_name>
    RESOURCES <file1> [<file2> ...]
    [RESOURCE_DIR <directory>]
    [HEADER_OUTPUT_DIR <directory>]
    [NAMESPACE <namespace>]
)
```

**Parameters:**
- `TARGET`: Name of the target (creates `<target>-data` library)
- `RESOURCES`: List of files to embed
- `RESOURCE_DIR`: Directory containing resource files (default: `CMAKE_CURRENT_SOURCE_DIR`)
- `HEADER_OUTPUT_DIR`: Output directory for generated headers (default: `CMAKE_CURRENT_BINARY_DIR/include`)
- `NAMESPACE`: C++ namespace for generated functions (default: `resources`)

### Generated C++ API

For each embedded file, two functions are generated:

```cpp
namespace your_namespace {
    // Get pointer to resource data
    auto getFileNameEXTData() -> const uint8_t*;

    // Get size of resource in bytes
    auto getFileNameEXTSize() -> uint32_t;
}
```

**File name transformation:**
- `logo.png` → `getLogoPNGData()` / `getLogoPNGSize()`
- `tic_tac_toe.png` → `getTicTacToePNGData()` / `getTicTacToePNGSize()`
- `PressStart2P-Regular.ttf` → `getPressstart2pRegularTTFData()` / `getPressstart2pRegularTTFSize()`

### Safe API Functions

```cpp
#include <resource_tools/embedded_resource.h>

namespace your_namespace {
    // Safe accessor with error handling (recommended)
    auto getFileNameEXTSafe() -> resource_tools::ResourceResult;
}

namespace resource_tools {
    // Safe utility function with error handling
    auto getResourceSafe(const uint8_t* start, const uint8_t* end) -> ResourceResult;

    // Error result type
    struct ResourceResult {
        const uint8_t* data;
        size_t size;
        ResourceError error;

        explicit operator bool() const;  // Check if successful
        auto error_message() const -> const char*;
    };

    // Error codes
    enum class ResourceError {
        Success, NullPointer, InvalidSize, IntegerOverflow, NotFound
    };
}
```

## Examples

### Embedding Game Assets

```cmake
embed_resources(
    TARGET my_game
    RESOURCES
        sprites/player.png
        sprites/enemy.png
        sounds/jump.wav
        levels/level1.json
    RESOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/assets
    NAMESPACE game_assets
)

add_executable(my_game src/main.cpp)
target_link_libraries(my_game PRIVATE my_game-data resource_tools::resource_tools)
```

```cpp
#include <game_assets/embedded_data.h>

void loadAssets() {
    // Load sprite data
    auto* player_sprite = game_assets::getPlayerPNGData();
    auto player_size = game_assets::getPlayerPNGSize();

    // Load level data
    auto* level_data = game_assets::getLevel1JSONData();
    auto level_size = game_assets::getLevel1JSONSize();

    // Create textures, parse JSON, etc.
}
```

### Embedding Fonts

```cmake
embed_resources(
    TARGET font_demo
    RESOURCES
        fonts/arial.ttf
        fonts/monospace.ttf
    NAMESPACE fonts
)
```

```cpp
#include <fonts/embedded_data.h>
#include <SDL_ttf.h>

TTF_Font* loadEmbeddedFont(int size) {
    auto* font_data = fonts::getArialTTFData();
    auto font_size = fonts::getArialTTFSize();

    SDL_RWops* rw = SDL_RWFromConstMem(font_data, font_size);
    return TTF_OpenFontRW(rw, 1, size);
}
```

## How It Works

### Windows Implementation
- Uses Windows Resource Compiler (RC)
- Embeds files as `RCDATA` resources
- Accesses via `FindResource`/`LoadResource` API
- Generates resource IDs and accessor functions

### Unix/Linux Implementation
- Uses `ld --relocatable --format binary` to create object files
- Links object files into static library
- Accesses via `extern "C"` symbols
- Calculates sizes using start/end symbol pointers

### Cross-Platform Compatibility
- Generates identical C++ API on all platforms
- Handles platform differences transparently
- Uses templates for maintainable code generation

## Requirements

- CMake 3.20 or later
- C++20 compiler
- On Unix/Linux: `ld` linker and `objcopy` utility
- On Windows: RC (Resource Compiler)

## Building and Testing

```bash
# Configure
cmake -B build -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build build

# Run tests
cd build && ctest

# Run installation tests
ctest -R install_resource_tools

# Install
cmake --install build --prefix /usr/local
```

## Integration

### With FetchContent (Recommended)

```cmake
include(FetchContent)
FetchContent_Declare(
    resource_tools
    GIT_REPOSITORY https://github.com/rvodden/resource_tools.git
    GIT_TAG v1.0.0  # Use a specific version tag
    OVERRIDE_FIND_PACKAGE  # Automatically satisfies find_package() calls
)
FetchContent_MakeAvailable(resource_tools)
```

Benefits:
- ✅ No manual installation required
- ✅ Version pinned to specific tag
- ✅ Works across all platforms
- ✅ CMake handles everything automatically

### As a Git Submodule

```bash
git submodule add https://github.com/rvodden/resource_tools.git third_party/resource_tools
```

```cmake
add_subdirectory(third_party/resource_tools)
# embed_resources function is now available
```

### System Installation

```bash
# Install system-wide
sudo cmake --install build --prefix /usr/local

# Use in projects
find_package(resource_tools REQUIRED)
```

## License

This project is licensed under the GNU Lesser General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `ctest`
5. Submit a pull request

## Troubleshooting

### Common Issues

**"Unknown CMake command 'embed_resources'"**
- Ensure `find_package(resource_tools REQUIRED)` is called
- Check that resource_tools is properly installed

**"Cannot find embedded header files"**
- Verify the target links with both the data library and resource_tools:
  ```cmake
  target_link_libraries(app PRIVATE app-data resource_tools::resource_tools)
  ```

**Link errors with binary symbols**
- Ensure the data library is linked before the main target
- Check that resource files exist at build time

**Windows RC compilation errors**
- Verify RC.exe is available in PATH
- Check that resource files don't contain invalid characters

### Debug Information

Enable verbose output to see what's happening:

```bash
cmake --build build --verbose
ctest --verbose
```

## Architecture

resource_tools uses a template-based approach for maximum maintainability:

```
resource_tools/
├── include/resource_tools/     # Public headers
│   └── embedded_resource.h    # Utility functions
├── cmake/                     # CMake modules
│   ├── EmbedResources.cmake   # Main CMake function
│   └── templates/             # Code generation templates
│       ├── embedded_data_unix.h.in
│       ├── embedded_data_windows.h.in
│       ├── resources.rc.in
│       └── resource_ids.h.in
├── test/                      # Unit tests
├── test_installed/            # Installation tests
└── CMakeLists.txt            # Build configuration
```

This design ensures the library is easy to maintain, extend, and debug.