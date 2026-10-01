# Contributing to justtrack SDK 

Thank you for your interest in contributing to the justtrack SDK. This document provides guidelines and instructions for contributing to this project.

## Project Structure

- `JustTrackSDK/` - Main iOS SDK framework
- `JustTrackSDK/JustTrackSDKTests/` - Unit tests
- `JustTrackSDK/TestApp/` - Test/demo application
- `JustTrackSDK/scripts/` - Build, release, and utility scripts
- `Adapters/` - Third-party adapter modules (AppLovin, Firebase, IronSource, UnityAds, Facebook, GoogleOdm)
- `IntegrationApp/` - Integration testing application

## Prerequisites

- Xcode (latest stable version recommended)
- [mise](https://mise.jdx.dev) (manages the pinned SwiftLint / pre-commit versions)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (used to generate the `.xcodeproj`)
- [swift-format](https://github.com/apple/swift-format) (install via Homebrew: `brew install swift-format`)
- CocoaPods (for the integration app and adapter testing)

## Setup

1. Install the pinned tooling and the git hooks:

   ```bash
   mise trust && mise install
   pre-commit install
   ```

2. Copy `local.properties` and place it under `JustTrackSDK/`.
3. Run `make` inside the `JustTrackSDK/` directory to generate the Xcode project:

   ```bash
   cd JustTrackSDK
   make
   ```

4. Open the generated `JustTrackSDK.xcodeproj` in Xcode.

## Code Quality

Before submitting changes, make sure your code passes all quality checks:

### Formatting

```bash
make format
```

### Linting

```bash
make lint
```

### Running Tests

Unit tests can be run from Xcode by selecting the `JustTrackSDKTests` scheme and pressing `Cmd+U`, or via the command line:

```bash
xcodebuild test \
  -project JustTrackSDK.xcodeproj \
  -scheme JustTrackSDKTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Building

To build the SDK framework, run the build script:

```bash
./scripts/build.sh
```

To build the adapters:

```bash
./scripts/buildAdapters.sh
```

## How to Contribute

1. Fork the repository.
2. Create a feature branch from `main`:

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. Make your changes.
4. Ensure all formatting, linting, and tests pass.
5. Commit your changes with a clear, descriptive commit message.
6. Push your branch and open a merge request.

## Reporting Issues

If you find a bug or have a feature request, please open an issue with:

- A clear and descriptive title
- Steps to reproduce the issue (for bugs)
- Expected vs actual behavior
- SDK version and iOS version

## License

By contributing to this project, you agree that your contributions will be licensed under the [MIT License](/LICENSE).
