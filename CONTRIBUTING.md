# 🤝 Contributing to BreathSafe

Thank you for your interest in contributing to BreathSafe! This document provides guidelines for participating in the project.

## 💡 Ways to Contribute

- 🐛 **Report Bugs** — Found an issue? Open a GitHub Issue
- ✨ **Suggest Features** — Have an idea? Discuss in GitHub Discussions
- 📝 **Improve Documentation** — Fix typos, clarify instructions, add examples
- 🔧 **Fix Bugs** — Submit pull requests with fixes
- 🎨 **Enhance UI/UX** — Design improvements, new widgets
- 🧪 **Add Tests** — Improve test coverage
- 📦 **Update Dependencies** — Keep packages current
- 🌍 **Localization** — Add support for new languages

## 🏗️ Development Setup

### Prerequisites
- Flutter 3.10.3+
- Dart SDK 3.10+
- Android SDK (for Android development)
- Xcode (for iOS development, macOS only)
- Git

### Clone & Setup
```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR-USERNAME/Breathsafe.git
cd Breathsafe

# Add upstream remote
git remote add upstream https://github.com/ilaikram/Breathsafe.git

# Install dependencies
flutter pub get

# Verify setup
flutter doctor
flutter analyze
```

## 📋 Code Style & Conventions

### Dart Style Guide
Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart):

```dart
// ✅ Good
class AirQualityWidget extends StatefulWidget {
  const AirQualityWidget({
    Key? key,
    required this.airPurity,
    this.onTap,
  }) : super(key: key);

  final double airPurity;
  final VoidCallback? onTap;

  @override
  State<AirQualityWidget> createState() => _AirQualityWidgetState();
}

// ❌ Bad
class AirQualityWidget extends StatefulWidget {
  AirQualityWidget(this.airPurity, this.onTap);
  double airPurity;
  VoidCallback onTap;

  @override
  State<AirQualityWidget> createState() => _AirQualityWidgetState();
}
```

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Class | `UpperCamelCase` | `BleSensorService` |
| Method | `lowerCamelCase` | `connectToDevice()` |
| Variable | `lowerCamelCase` | `airPurity`, `_privateVar` |
| Constant | `lowerCamelCase` | `const maxRetries = 3` |
| File | `snake_case` | `ble_sensor_service.dart` |
| Widget | `UpperCamelCase` | `AirPurityRing` |

### Comments & Documentation

```dart
/// Brief description of the method.
///
/// More detailed explanation of what it does, parameters, and return value.
/// 
/// Example:
/// ```dart
/// final data = await parseBleSensorData("75,55.2,23.5");
/// ```
///
/// Throws:
/// - [FormatException] if payload format is invalid
List<double> parseBleSensorData(String payload) {
  // Implementation
}
```

### Code Organization

```dart
// 1. Imports (organize: dart, flutter, packages, relative)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// 2. Constants
const String deviceName = "BreatheSafe_Device";

// 3. Class/Enum definition
class BleScanDevice {
  // 3a. Properties
  final String name;
  final int rssi;

  // 3b. Constructor
  const BleScanDevice({
    required this.name,
    required this.rssi,
  });

  // 3c. Getters
  String get displayName => name.isNotEmpty ? name : 'Unknown';

  // 3d. Methods
  void updateRssi(int newRssi) { }

  // 3e. Override methods
  @override
  String toString() => 'BleScanDevice($name, $rssi)';
}
```

### Error Handling

```dart
// ✅ Good - Specific error handling
try {
  await bleService.connectToDevice(device);
} on TimeoutException catch (e) {
  showErrorMessage("Connection timeout. Device may be out of range.");
  logger.error("BLE connection timeout: $e");
} on PermissionException catch (e) {
  showErrorMessage("Bluetooth permission denied.");
} catch (e) {
  showErrorMessage("Unexpected error: $e");
}

// ❌ Bad - Generic catch-all
try {
  await bleService.connectToDevice(device);
} catch (e) {
  print("Error: $e");
}
```

## 🔄 Git Workflow

### 1. Create a Feature Branch
```bash
# Update main branch
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/add-dark-mode
# or for bugfixes:
git checkout -b bugfix/ble-reconnection-issue
```

**Branch Naming**:
- Feature: `feature/descriptive-name`
- Bugfix: `bugfix/issue-description`
- Docs: `docs/documentation-update`

### 2. Make Changes
```bash
# Make edits, test locally
flutter test
flutter analyze

# Stage changes
git add lib/screens/home_screen.dart lib/theme/app_theme.dart

# Commit with clear message
git commit -m "feat: add dark mode support to home screen

- Add theme toggle in settings
- Update app_theme.dart with dark color palette
- Persist theme preference in ProfileService
- Fixes #42"
```

**Commit Message Format**:
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring (no functionality change)
- `test`: Add/update tests
- `docs`: Documentation only
- `style`: Code style, formatting (no logic change)
- `perf`: Performance improvement
- `ci`: CI/CD changes

**Examples**:
```
feat(ble): add automatic reconnection on disconnect

fix(home-screen): prevent UI freeze during long BLE scan

test(profile-service): add unit tests for profile persistence

docs: update INSTALLATION.md for Linux desktop setup
```

### 3. Push & Create Pull Request
```bash
# Push to your fork
git push origin feature/add-dark-mode

# Go to GitHub and create Pull Request
# - Base branch: upstream/main
# - Compare branch: YOUR-FORK/feature/add-dark-mode
# - Fill in PR template with description, screenshots, testing notes
```

**Pull Request Template**:
```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Related Issue
Fixes #(issue number)

## Testing
- [ ] Tested on Android
- [ ] Tested on iOS
- [ ] Tested on Linux
- [ ] Unit tests added/updated
- [ ] Analyzed code: `flutter analyze` passes

## Screenshots (if UI change)
Attach before/after screenshots.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] No new warnings in `flutter analyze`
- [ ] Tests pass: `flutter test`
- [ ] Comments added for complex logic
- [ ] Documentation updated
```

### 4. Code Review & Merge
- Maintainers will review and suggest changes
- Address feedback by updating your branch (commits auto-add to PR)
- Once approved, PR will be merged

## 🧪 Testing

### Run Tests Locally
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.report -o coverage/html
open coverage/html/index.html
```

### Write Tests
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:breathe_safe/services/ble_sensor_service.dart';
import 'package:breathe_safe/models/sensor_data.dart';

void main() {
  group('BleSensorService', () {
    late BleSensorService service;

    setUp(() {
      service = BleSensorService();
    });

    test('parseBleSensorData parses 5-field payload correctly', () {
      final payload = "75,55.2,23.5,1250,1";
      final data = service.parseSensorPayload(payload);

      expect(data.airPurity, 75);
      expect(data.humidity, 55.2);
      expect(data.temperature, 23.5);
      expect(data.mq135Raw, 1250);
      expect(data.dhtValid, true);
    });

    test('parseBleSensorData handles legacy 3-field payload', () {
      final payload = "75,55.2,23.5";
      final data = service.parseSensorPayload(payload);

      expect(data.airPurity, 75);
      expect(data.humidity, 55.2);
      expect(data.temperature, 23.5);
      expect(data.mq135Raw, isNull);
      expect(data.dhtValid, isTrue);
    });

    test('parseBleSensorData throws on invalid format', () {
      expect(
        () => service.parseSensorPayload("invalid"),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

## 📊 Code Quality

### Static Analysis
```bash
# Run Dart analyzer
flutter analyze

# Fix issues automatically
dart fix --apply

# Custom lint rules in analysis_options.yaml
```

### Check Coverage
Maintain >80% test coverage for critical services:
```bash
flutter test --coverage
# View: coverage/lcov.report
```

## 🔍 Before Submitting PR

- [ ] `flutter test` passes all tests
- [ ] `flutter analyze` shows no errors or warnings
- [ ] Code follows Dart style guide
- [ ] Commit messages are clear & conventional
- [ ] Branch is up-to-date with `upstream/main`
- [ ] No merge conflicts
- [ ] Tested on relevant platform (Android/iOS/Linux)
- [ ] Updated documentation if needed
- [ ] Added/updated tests for new functionality

## 🚀 Release Process

1. Bump version in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Create release commit: `chore: release v1.1.0`
4. Create GitHub Release with APK/IPA builds
5. Tag commit: `git tag v1.1.0`

## 📞 Getting Help

- **Questions**: Open a GitHub Discussion
- **Bug Reports**: Open a GitHub Issue with steps to reproduce
- **Feature Ideas**: Discuss in GitHub Discussions first
- **Community**: Join our Discord (link TBD)

## ✅ PR Review Checklist (Maintainers)

- [ ] Changes align with project goals
- [ ] Code quality & style standards met
- [ ] Tests added & passing
- [ ] Documentation updated
- [ ] No performance regression
- [ ] Compatible with target platforms
- [ ] Conventional commit message used

## 🙏 Code of Conduct

We are committed to providing a welcoming and inclusive environment:
- Treat everyone with respect
- Provide constructive feedback
- Respect differing opinions
- Report unacceptable behavior to [maintainer email]

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License (see [LICENSE.md](LICENSE.md)).

---

**Thank you for contributing to BreathSafe!** 🎉
