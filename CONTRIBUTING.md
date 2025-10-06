# Contributing to resource_tools

Thank you for your interest in contributing to resource_tools!

## Development Workflow

### Setting Up

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/resource_tools.git
   cd resource_tools
   ```

3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Building and Testing

```bash
# Configure with tests enabled
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DRESOURCE_TOOLS_BUILD_TESTS=ON

# Build
cmake --build build

# Run all tests
cd build && ctest --output-on-failure

# Run specific test groups
ctest -R resource_tools_test  # Unit tests only
ctest -R install_resource_tools  # Installation tests only
```

### Code Style

- Use C++20 features where appropriate
- Follow existing code formatting
- Use trailing return types: `auto function() -> ReturnType`
- Use `#ifndef`/`#define`/`#endif` include guards (not `#pragma once`)
- Document public APIs with comments

### Making Changes

1. Make your changes
2. Add tests for new functionality
3. Ensure all tests pass
4. Update documentation if needed
5. Commit with clear messages

### Submitting Pull Requests

1. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Create a Pull Request against the `main` branch

3. Ensure CI tests pass

4. Address any review feedback

## Release Process

### Automated Versioning

resource_tools uses automated releases via GitHub Actions:

1. **Version is determined by CMakeLists.txt**
   - The version is read from the `project(resource_tools VERSION x.y.z)` line
   - Follow [Semantic Versioning](https://semver.org/):
     - MAJOR: Breaking changes
     - MINOR: New features (backwards compatible)
     - PATCH: Bug fixes

2. **Release workflow triggers on push to main**
   - All tests must pass
   - If the version in CMakeLists.txt doesn't have a tag yet, a new release is created
   - The tag format is `vX.Y.Z` (e.g., `v1.2.3`)

3. **To create a new release:**
   ```cmake
   # Update version in CMakeLists.txt
   project(resource_tools
       VERSION 1.2.3  # <-- Update this
       DESCRIPTION "Cross-platform resource embedding library"
       LANGUAGES CXX)
   ```

   Then commit and push to main:
   ```bash
   git add CMakeLists.txt
   git commit -m "Bump version to 1.2.3"
   git push origin main
   ```

4. **GitHub Actions will:**
   - Run all tests on Linux, Windows, and macOS
   - Create a git tag `v1.2.3`
   - Create a GitHub Release with changelog
   - Include installation instructions

### What Gets Included in a Release

- Changelog from commits since last tag
- Installation instructions for:
  - CMake FetchContent
  - Git submodules
  - System installation

## Testing Guidelines

### Unit Tests

- Test files go in `test/`
- Use GoogleTest framework
- Test both success and failure cases
- Test edge cases

### Installation Tests

- Test files go in `test_installed/`
- These verify the installed library works correctly
- Run automatically via CTest fixtures

### Platform Coverage

Tests run on:
- **Linux**: GCC and Clang
- **Windows**: MSVC
- **macOS**: Apple Clang

Both Debug and Release builds are tested.

## Documentation

- Update README.md for new features
- Add examples for new functionality
- Document breaking changes clearly
- Keep API reference up to date

## Questions?

Feel free to open an issue for:
- Bug reports
- Feature requests
- Questions about usage
- Clarifications on contributing

Thank you for contributing!