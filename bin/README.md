# 🚀 Chrome Desktop Downloader

A command-line tool to download Chrome/Chromium binaries for desktop platforms.

## 📋 Table of Contents

- [Usage](#-usage)
- [Platform Options](#-platform-options)
- [Examples](#-examples)
- [Features](#-features)

## 🛠️ Usage

### Basic Syntax
```bash
dart bin/download_desktop.dart [options]
```

### Available Options
| Option | Short | Description | Required |
|--------|-------|-------------|----------|
| `--platform` | `-p` | Target platform to download | No |
| `--help` | `-h` | Show usage information | No |

## 🖥️ Platform Options

| Platform | Aliases | Description |
|----------|---------|-------------|
| `macos` | `mac` | macOS (defaults to ARM64) |
| `mac-arm64` | `macos-arm64` | macOS Apple Silicon |
| `mac-x64` | `macos-x64`, `mac-intel` | macOS Intel |
| `windows` | `win` | Windows (defaults to 64-bit) |
| `win32` | `windows32` | Windows 32-bit |
| `win64` | `windows64` | Windows 64-bit |
| `linux` | `linux64` | Linux 64-bit |

## 📚 Examples

### Auto-detect Platform
Automatically detects your current operating system and architecture:
```bash
dart bin/download_desktop.dart
```

### Specify Platform Explicitly
Download Chrome for a specific platform:

**macOS:**
```bash
# Generic macOS (auto-selects ARM64)
dart bin/download_desktop.dart --platform macos

# Apple Silicon Macs
dart bin/download_desktop.dart --platform mac-arm64

# Intel Macs
dart bin/download_desktop.dart --platform mac-x64
```

**Windows:**
```bash
# Generic Windows (auto-selects 64-bit)
dart bin/download_desktop.dart --platform windows

# Windows 64-bit
dart bin/download_desktop.dart --platform win64

# Windows 32-bit
dart bin/download_desktop.dart --platform win32
```

**Linux:**
```bash
# Linux 64-bit
dart bin/download_desktop.dart --platform linux64
```

### Short Form
Use the short `-p` flag for convenience:
```bash
dart bin/download_desktop.dart -p windows
dart bin/download_desktop.dart -p mac-arm64
dart bin/download_desktop.dart -p linux64
```

### Get Help
Display usage information and available options:
```bash
dart bin/download_desktop.dart --help
# or
dart bin/download_desktop.dart -h
```

## ✨ Features

- 🔍 **Auto-detection**: Automatically detects your platform if not specified
- 🎯 **Multi-platform**: Supports macOS, Windows, and Linux
- 📊 **Progress tracking**: Shows download progress and speed
- 🛡️ **Error handling**: Comprehensive error messages and validation
- 🏗️ **Architecture support**: Handles both ARM64 and x64 architectures
- 📱 **Flexible input**: Multiple aliases for platform names

## 🔧 Output Information

The tool displays:
- 📱 **Platform**: Target platform and architecture
- 🔢 **Version**: Chrome version being downloaded
- 📂 **Paths**: Cache and save directory paths
- 📊 **Progress**: Real-time download progress and speed
- ✅ **Results**: Final executable path upon completion

## 💡 Tips

1. **First time users**: Run without arguments to auto-detect your platform
2. **Cross-platform development**: Use specific platform flags to download Chrome for testing on different systems
3. **CI/CD pipelines**: Specify exact platforms for consistent builds
4. **Troubleshooting**: Use `--help` to see all available options

---

**Need help?** Run `dart bin/download_desktop.dart --help` for detailed usage information.