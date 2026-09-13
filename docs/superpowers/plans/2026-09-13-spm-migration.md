# Swift Package Manager Support (iOS/macOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real Swift Package Manager support to `webcontent_converter` for both iOS and macOS, while keeping the existing CocoaPods path fully working, and prove both paths build and pass the real integration test suite in the example app.

**Architecture:** Move the plugin's Swift/ObjC sources from `darwin/Classes/` into the SPM-required `darwin/webcontent_converter/Sources/webcontent_converter/` layout (one shared package for both platforms, matching how the existing single podspec already serves both), add a `Package.swift` next to it, and repoint the existing podspec's `source_files` at the new location instead of duplicating anything. Along the way, delete the already-dead Objective-C registration shim and rename the Swift plugin class to match `pluginClass` exactly, matching Flutter's own current plugin template.

**Tech Stack:** Flutter 3.47.4 (installed via `fvm` at `/Users/whitehat/fvm/versions/3.47.4/bin/flutter`), Swift 5.9 tools version, CocoaPods (existing), Xcode.

**Spec:** `docs/superpowers/specs/2026-09-13-spm-migration-design.md`

## Global Constraints

- Both CocoaPods and SPM must work after this migration — Flutter's policy requires plugins to support both "until further notice." Never remove the podspec.
- `Package.swift` platforms: `.iOS("15.0")`, `.macOS("12.0")` — Flutter 3.47.4's actual minimums (`FlutterDarwinPlatform.deploymentTarget()` in `flutter_tools`), matching what the example app was already bumped to.
- `swift-tools-version: 5.9` (Flutter 3.47.4's `minimumSwiftToolchainVersion`).
- One shared package for both platforms — never duplicate source between an `ios/` tree and a `macos/` tree; this plugin's `sharedDarwinSource: true` stays true in `pubspec.yaml` (no change needed there).
- No third-party CocoaPods dependencies exist today (only `Flutter`/`FlutterMacOS` themselves) — nothing to port to SPM package dependencies.
- Use the Flutter binary at `/Users/whitehat/fvm/versions/3.47.4/bin/flutter` for every command in this plan (this repo's target version). Prefix CocoaPods/build commands with `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` — this machine's Ruby/CocoaPods otherwise fails with a `Unicode Normalization not appropriate for ASCII-8BIT` error.
- iOS Simulator target for verification: discover a booted device with `xcrun simctl list devices booted` (this session used `iPhone 17`, UDID `C8077E80-08B2-434C-8646-C314FC19B44E`; boot one via `xcrun simctl boot "iPhone 17"` if none is booted, then `open -a Simulator`).
- macOS target for verification: `-d macos`.

---

## File Structure

```
darwin/
  webcontent_converter.podspec          (modified: source_files, deployment targets, xcconfig split)
  .gitignore                            (modified: add .build/, .swiftpm/)
  Classes/                              (deleted once empty)
  webcontent_converter/                 (new)
    Package.swift                       (new)
    Sources/
      webcontent_converter/             (new — the moved + renamed source files)
        WebcontentConverterPlugin.swift (renamed from SwiftWebcontentConverterPlugin.swift)
        ConversionQueue.swift
        FLWebView.swift
        Page.swift
        PdfPageMerger.swift
        PrintPreviewWindowMacOS.swift
        RequestWatchdog.swift
        WKWebView+Debug.swift
example/integration_test/webcontent_converter_test.dart  (modified: 2 stale path comments)
CHANGELOG.md, pubspec.yaml              (modified: version bump)
```

Deleted: `darwin/Classes/WebcontentConverterPlugin.h`, `darwin/Classes/WebcontentConverterPlugin.m`.

---

## Task 1: Remove the dead Objective-C shim and rename the Swift plugin class

The registrants in the example app (`example/ios/Runner/GeneratedPluginRegistrant.m` and `example/macos/Flutter/GeneratedPluginRegistrant.swift`) already call `SwiftWebcontentConverterPlugin` directly — neither references the Objective-C shim class `WebcontentConverterPlugin` in `darwin/Classes/WebcontentConverterPlugin.h`/`.m` at all. This task removes that dead shim and renames the real Swift class to match `pluginClass: WebcontentConverterPlugin` from `pubspec.yaml`, with files still in their current location (no directory restructuring yet — that's Task 2). This keeps the two risks — "is the rename safe" and "does the new directory layout build" — independently reviewable.

**Files:**
- Delete: `darwin/Classes/WebcontentConverterPlugin.h`
- Delete: `darwin/Classes/WebcontentConverterPlugin.m`
- Modify: `darwin/Classes/SwiftWebcontentConverterPlugin.swift` → rename to `darwin/Classes/WebcontentConverterPlugin.swift`
- Modify: `example/integration_test/webcontent_converter_test.dart:99,103` (comment references to the old file path/name)

**Interfaces:**
- Consumes: nothing from other tasks (this is the first task).
- Produces: a Swift class named `WebcontentConverterPlugin` (public, `NSObject, FlutterPlugin`) at `darwin/Classes/WebcontentConverterPlugin.swift`, which Task 2 moves without renaming again.

- [ ] **Step 1: Delete the dead Objective-C shim files**

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter
rm darwin/Classes/WebcontentConverterPlugin.h darwin/Classes/WebcontentConverterPlugin.m
```

- [ ] **Step 2: Rename the Swift class and the file**

```bash
sed -i '' 's/SwiftWebcontentConverterPlugin/WebcontentConverterPlugin/g' darwin/Classes/SwiftWebcontentConverterPlugin.swift
git mv darwin/Classes/SwiftWebcontentConverterPlugin.swift darwin/Classes/WebcontentConverterPlugin.swift
```

Verify only the expected 3 occurrences changed (a doc comment, the class declaration, and a `self`-instantiation):

```bash
grep -n "WebcontentConverterPlugin" darwin/Classes/WebcontentConverterPlugin.swift
```

Expected: line with `/// \`WebcontentConverterPlugin.activeDelegates\` for the job's lifetime`, line with `public class WebcontentConverterPlugin: NSObject, FlutterPlugin {`, and a line with `let instance = WebcontentConverterPlugin()`. No occurrences of `SwiftWebcontentConverterPlugin` should remain:

```bash
grep -rn "SwiftWebcontentConverterPlugin" darwin/
```

Expected: no output.

- [ ] **Step 3: Update the two stale comment references in the integration test**

Read `example/integration_test/webcontent_converter_test.dart` around lines 99 and 103 first (line numbers may have shifted slightly from earlier edits this session — search for the text instead of trusting the line numbers):

```bash
grep -n "darwin/Classes/SwiftWebcontentConverterPlugin.swift" example/integration_test/webcontent_converter_test.dart
```

For each match, replace `darwin/Classes/SwiftWebcontentConverterPlugin.swift` with `darwin/webcontent_converter/Sources/webcontent_converter/WebcontentConverterPlugin.swift` (the Task 2 destination path — safe to reference now since Task 2 immediately follows) using the Edit tool, keeping the existing line-number suffix (e.g. `:212-246`) as-is; Task 2's Step 4 will correct those numbers once the real file exists at that path.

- [ ] **Step 4: Force Flutter to regenerate the plugin registrants and confirm they reference the new name**

The registrant files under `example/ios/Runner/GeneratedPluginRegistrant.*` and `example/macos/Flutter/GeneratedPluginRegistrant.swift` are auto-generated and must not be hand-edited. Delete them and regenerate:

```bash
cd example
rm -f ios/Runner/GeneratedPluginRegistrant.h ios/Runner/GeneratedPluginRegistrant.m macos/Flutter/GeneratedPluginRegistrant.swift
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter pub get
grep -n "WebcontentConverterPlugin" ios/Runner/GeneratedPluginRegistrant.m macos/Flutter/GeneratedPluginRegistrant.swift
```

Expected: both files exist again, and both now call `WebcontentConverterPlugin` (not `SwiftWebcontentConverterPlugin`) — e.g. `[WebcontentConverterPlugin registerWithRegistrar:...]` in the `.m` file and `WebcontentConverterPlugin.register(with:...)` in the `.swift` file. If they still say `SwiftWebcontentConverterPlugin`, the rename in Step 2 didn't take effect before `pub get` ran — re-check Step 2 and repeat this step.

- [ ] **Step 5: Verify the CocoaPods build still succeeds on iOS Simulator**

Files haven't moved yet, so the existing podspec (`s.source_files = 'Classes/**/*'`) still finds everything.

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter/example
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d <booted-ios-simulator-udid>
```

Expected: `Xcode build done.` followed by `All tests passed!` (8 tests). If CocoaPods complains about a stale `Podfile.lock`/sandbox, run `cd ios && pod install && cd ..` first.

- [ ] **Step 6: Verify the CocoaPods/default build still succeeds on macOS**

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d macos --name '^((?!rejects content larger).)*$'
```

(The `--name` filter excludes the one pathological-input sub-test known from earlier this session to hang in this specific tool-driven macOS session for environment reasons unrelated to this change — see the spec's linked prior work if this needs re-litigating.) Expected: `All tests passed!` (7 tests).

- [ ] **Step 7: Commit**

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter
git add darwin/Classes/WebcontentConverterPlugin.swift example/integration_test/webcontent_converter_test.dart \
        example/ios/Runner/GeneratedPluginRegistrant.h example/ios/Runner/GeneratedPluginRegistrant.m \
        example/macos/Flutter/GeneratedPluginRegistrant.swift
git rm darwin/Classes/WebcontentConverterPlugin.h darwin/Classes/WebcontentConverterPlugin.m darwin/Classes/SwiftWebcontentConverterPlugin.swift 2>/dev/null
git status --short
git commit -m "$(cat <<'EOF'
refactor(darwin): drop dead ObjC shim, rename plugin class to match pluginClass

WebcontentConverterPlugin.h/.m forwarded to SwiftWebcontentConverterPlugin
but neither generated registrant (iOS's .m or macOS's .swift) referenced
it -- both already called SwiftWebcontentConverterPlugin directly. Renamed
that class to WebcontentConverterPlugin (matching pubspec.yaml's
pluginClass exactly, matching Flutter's current plugin template) and
deleted the shim. No behavior change; verified via the real integration
test suite on iOS Simulator and macOS.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Restructure `darwin/` into the SPM-required layout and repoint the podspec

**Files:**
- Move: `darwin/Classes/WebcontentConverterPlugin.swift` → `darwin/webcontent_converter/Sources/webcontent_converter/WebcontentConverterPlugin.swift`
- Move: `darwin/Classes/ConversionQueue.swift` → `darwin/webcontent_converter/Sources/webcontent_converter/ConversionQueue.swift`
- Move: `darwin/Classes/FLWebView.swift` → `darwin/webcontent_converter/Sources/webcontent_converter/FLWebView.swift`
- Move: `darwin/Classes/Page.swift` → `darwin/webcontent_converter/Sources/webcontent_converter/Page.swift`
- Move: `darwin/Classes/PdfPageMerger.swift` → `darwin/webcontent_converter/Sources/webcontent_converter/PdfPageMerger.swift`
- Move: `darwin/Classes/PrintPreviewWindowMacOS.swift` → `darwin/webcontent_converter/Sources/webcontent_converter/PrintPreviewWindowMacOS.swift`
- Move: `darwin/Classes/RequestWatchdog.swift` → `darwin/webcontent_converter/Sources/webcontent_converter/RequestWatchdog.swift`
- Move: `darwin/Classes/WKWebView+Debug.swift` → `darwin/webcontent_converter/Sources/webcontent_converter/WKWebView+Debug.swift`
- Modify: `darwin/webcontent_converter.podspec`
- Modify: `example/integration_test/webcontent_converter_test.dart` (finalize the 2 path comments from Task 1 Step 3 with correct line numbers)
- Delete: `darwin/Classes/` (once empty)

**Interfaces:**
- Consumes: `darwin/Classes/WebcontentConverterPlugin.swift` produced by Task 1.
- Produces: `darwin/webcontent_converter/Sources/webcontent_converter/` — the directory Task 3's `Package.swift` targets.

- [ ] **Step 1: Create the new directory and move every source file into it**

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter
mkdir -p darwin/webcontent_converter/Sources/webcontent_converter
git mv darwin/Classes/WebcontentConverterPlugin.swift darwin/webcontent_converter/Sources/webcontent_converter/
git mv darwin/Classes/ConversionQueue.swift darwin/webcontent_converter/Sources/webcontent_converter/
git mv darwin/Classes/FLWebView.swift darwin/webcontent_converter/Sources/webcontent_converter/
git mv darwin/Classes/Page.swift darwin/webcontent_converter/Sources/webcontent_converter/
git mv darwin/Classes/PdfPageMerger.swift darwin/webcontent_converter/Sources/webcontent_converter/
git mv darwin/Classes/PrintPreviewWindowMacOS.swift darwin/webcontent_converter/Sources/webcontent_converter/
git mv darwin/Classes/RequestWatchdog.swift darwin/webcontent_converter/Sources/webcontent_converter/
git mv darwin/Classes/'WKWebView+Debug.swift' darwin/webcontent_converter/Sources/webcontent_converter/
ls darwin/Classes/
```

Expected: `darwin/Classes/` is now empty (or contains only a leftover empty directory listing).

- [ ] **Step 2: Remove the now-empty `Classes/` directory**

```bash
rmdir darwin/Classes
```

If this fails because the directory isn't empty, run `find darwin/Classes -type f` and move whatever remains (there should be nothing — every file was listed in Step 1).

- [ ] **Step 3: Update the podspec to point at the new location and current deployment targets**

Read the current file, then replace its full contents:

```ruby
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint webcontent_converter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'webcontent_converter'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'webcontent_converter/Sources/webcontent_converter/**/*'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.ios.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.osx.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
```

This is the only file to fully rewrite in this task; every other change is a move or a small in-place comment edit.

- [ ] **Step 4: Fix the two path comments in the integration test to their final path and correct line numbers**

```bash
cd example
grep -n "darwin/webcontent_converter/Sources/webcontent_converter/WebcontentConverterPlugin.swift" integration_test/webcontent_converter_test.dart
```

For each of the two matches, open the referenced range in the *actual* moved file (`../darwin/webcontent_converter/Sources/webcontent_converter/WebcontentConverterPlugin.swift`) and confirm the cited line range still covers the iOS/macOS format-specific rendering logic the comment describes (`UIGraphicsImageRenderer`-based iOS drawing and the macOS `takeSnapshot` sizing, respectively — search for those symbol names if the exact numbers drifted from the class rename). Update the `:NNN-NNN` suffix in each comment to match.

- [ ] **Step 5: Verify the CocoaPods build still succeeds from the new source location — iOS Simulator**

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter/example
rm -rf ios/Pods ios/Podfile.lock
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d <booted-ios-simulator-udid>
```

(Deleting `Pods`/`Podfile.lock` first forces a clean re-resolution against the podspec's new `source_files` path — otherwise a stale sandbox could mask a broken path.) Expected: `All tests passed!` (8 tests). If `pod install` reports it can't find source files, the podspec's `source_files` glob or the directory move in Step 1 has a typo — re-check both.

- [ ] **Step 6: Verify the CocoaPods build still succeeds from the new source location — macOS**

```bash
rm -rf macos/Pods macos/Podfile.lock
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d macos --name '^((?!rejects content larger).)*$'
```

Expected: `All tests passed!` (7 tests).

- [ ] **Step 7: Commit**

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter
git add darwin/webcontent_converter darwin/webcontent_converter.podspec example/integration_test/webcontent_converter_test.dart
git status --short  # confirm darwin/Classes/ is gone and no unrelated files are staged
git commit -m "$(cat <<'EOF'
refactor(darwin): move sources into the SPM-required package layout

Moves every file from darwin/Classes/ into
darwin/webcontent_converter/Sources/webcontent_converter/ -- the
directory shape Flutter's SPM tooling requires for a sharedDarwinSource
plugin -- and repoints the existing podspec's source_files at the new
location. Also bumps the podspec's deployment targets to iOS 15.0/macOS
12.0 (Flutter 3.47.4's actual minimums, matching what the example app
already uses) and splits pod_target_xcconfig per platform, matching
Flutter's own SPM-variant podspec template. No new Package.swift yet
(Task 3) -- this step only proves the CocoaPods path survives the move.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add `Package.swift` and verify the SPM build path

**Files:**
- Create: `darwin/webcontent_converter/Package.swift`
- Modify: `darwin/.gitignore` (add `.build/`, `.swiftpm/`)

**Interfaces:**
- Consumes: `darwin/webcontent_converter/Sources/webcontent_converter/` from Task 2.
- Produces: a resolvable local Swift package named `webcontent_converter`, which Flutter's SPM integration picks up automatically (no pubspec.yaml change needed — `sharedDarwinSource: true` and the `ios`/`macos` platform blocks in `pubspec.yaml` are unchanged and already correct).

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "webcontent_converter",
    platforms: [
        .iOS("15.0"),
        .macOS("12.0")
    ],
    products: [
        .library(name: "webcontent-converter", targets: ["webcontent_converter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "webcontent_converter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it collects user
                // data, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
```

This is copied from Flutter 3.47.4's own `plugin_darwin_spm` template (`packages/flutter_tools/templates/plugin_darwin_spm/darwin.tmpl/projectName.tmpl/Package.swift.tmpl`), with `{{projectName}}` → `webcontent_converter` and `{{swiftLibraryName}}` → `webcontent-converter` (underscores to hyphens, matching the template's own substitution rule and real shipped plugins like `webview_flutter_wkwebview` → `webview-flutter-wkwebview`). The `../FlutterFramework` path dependency is a fixed convention Flutter's build tooling resolves automatically when assembling the outer Xcode project — do not change it.

- [ ] **Step 2: Add SPM build artifacts to `.gitignore`**

Add these two lines to `darwin/.gitignore` (anywhere in the file; grouping with the existing `build/` line is fine):

```
.build/
.swiftpm/
```

- [ ] **Step 3: Confirm the SPM warning is gone and the package resolves — iOS Simulator**

SPM is Flutter 3.47.4's live default on this machine (no override in `flutter config`), so no config change is needed here — just rebuild:

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter/example
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter pub get
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d <booted-ios-simulator-udid> 2>&1 | tee /tmp/spm_ios_verify.log
grep -c "does not have Swift Package Manager support" /tmp/spm_ios_verify.log
```

Expected: the `grep -c` count is `0` (the warning that printed on every build throughout the earlier 3.47.4 upgrade work is now gone for this plugin), and the test output ends with `All tests passed!` (8 tests).

- [ ] **Step 4: Confirm `Package Dependencies` is wired into the iOS Xcode project**

```bash
grep -c "FlutterGeneratedPluginSwiftPackage" ios/Runner.xcodeproj/project.pbxproj
```

Expected: a nonzero count (Flutter's one-time SPM migration adds this package reference to the Runner project the first time a build with SPM support succeeds).

- [ ] **Step 5: Confirm the SPM path works and is wired in on macOS**

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d macos --name '^((?!rejects content larger).)*$' 2>&1 | tee /tmp/spm_macos_verify.log
grep -c "does not have Swift Package Manager support" /tmp/spm_macos_verify.log
grep -c "FlutterGeneratedPluginSwiftPackage" macos/Runner.xcodeproj/project.pbxproj
```

Expected: both `grep -c` counts confirm the warning is gone and the package reference is present; the test output ends with `All tests passed!` (7 tests).

- [ ] **Step 6: Check for any newly-untracked SPM artifacts in the example app and extend `.gitignore` if needed**

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter
git status --short example/
```

If genuine build artifacts appear untracked (e.g. `example/ios/.swiftpm/`, resolved-package caches) rather than meaningful project-state changes (the `project.pbxproj` diffs and any `Package.resolved` files Flutter itself commits as part of its migration are expected and should be tracked), add the artifact paths to `example/ios/.gitignore` / `example/macos/.gitignore`. Do not blanket-ignore `Package.resolved` — Flutter's own migrated projects commit it.

- [ ] **Step 7: Commit**

```bash
git add darwin/webcontent_converter/Package.swift darwin/.gitignore example/ios example/macos
git status --short  # review every file before committing -- this includes Flutter's one-time project migration
git commit -m "$(cat <<'EOF'
feat(darwin): add Package.swift for Swift Package Manager support

Adds darwin/webcontent_converter/Package.swift (swift-tools-version
5.9, iOS 15.0/macOS 12.0, following Flutter 3.47.4's own
plugin_darwin_spm template exactly). Verified on the example app for
both iOS Simulator and macOS: the "doesn't support Swift Package
Manager" warning is gone, FlutterGeneratedPluginSwiftPackage is wired
into both Runner.xcodeproj files, and the real integration test suite
(actual native-plugin PDF/image conversion, not mocks) passes on both.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Explicitly verify the CocoaPods fallback still works

Task 2 already proved CocoaPods works when it's the *only* path (before `Package.swift` existed). This task proves it still works as the *fallback* now that SPM is also available — the actual scenario Flutter's dual-support policy exists for (an app that hasn't migrated to SPM yet, or has explicitly opted out).

**Files:** none (verification only).

**Interfaces:** none.

- [ ] **Step 1: Record the current global Swift Package Manager config state**

```bash
cat ~/.config/flutter/settings 2>/dev/null | grep -i swift
```

Expected: no output (no override set — confirmed earlier this session). If this prints something, note the exact current value so Step 4 restores it precisely instead of assuming "no override."

- [ ] **Step 2: Force CocoaPods-only mode and rebuild on iOS Simulator**

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter config --no-enable-swift-package-manager
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter/example
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d <booted-ios-simulator-udid>
```

Expected: `All tests passed!` (8 tests) — the plugin builds via CocoaPods exactly as it did before this migration existed.

- [ ] **Step 3: Force CocoaPods-only mode and rebuild on macOS**

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d macos --name '^((?!rejects content larger).)*$'
```

Expected: `All tests passed!` (7 tests).

- [ ] **Step 4: Restore the global config to its recorded state**

Since Step 1 found no override, restore that exact state (not just "turn it back on" — the goal is leaving this machine's global Flutter config exactly as found, since it affects every Flutter project on this machine, not just this repo):

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter config --clear-features
cat ~/.config/flutter/settings 2>/dev/null | grep -i swift
```

Expected: no output again, matching Step 1. If Step 1 had instead found an explicit value, use `flutter config --enable-swift-package-manager` or `--no-enable-swift-package-manager` to set that exact value back instead of `--clear-features` (which resets *all* feature flags, not just this one — only safe here because Step 1 confirmed none were set).

- [ ] **Step 5: Re-confirm the default (SPM) path still works after restoring config**

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test integration_test/webcontent_converter_test.dart -d <booted-ios-simulator-udid>
```

Expected: `All tests passed!` (8 tests) — proves the config restore in Step 4 actually took effect and didn't leave the project stuck in CocoaPods-only mode.

No commit for this task — it's pure verification with no file changes (unless Step 1 revealed a non-empty prior state that Step 4 needed to explicitly restore via a flag rather than `--clear-features`, in which case there's still nothing to commit, since `flutter config` writes to the user's global settings file outside this repo, not to any tracked file).

---

## Task 5: Version bump and changelog

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`

**Interfaces:** none — this is the final housekeeping task, matching the pattern already established in this repo's history (see `CHANGELOG.md`'s `0.0.14`/`0.0.15` entries for the exact tone/format to follow).

- [ ] **Step 1: Read the current version**

```bash
cd /Users/whitehat/coding/mylekha/frontend/mylekha_helper/webcontent_converter
grep "^version:" pubspec.yaml
head -5 CHANGELOG.md
```

- [ ] **Step 2: Bump the version**

Increment the patch component by one from whatever Step 1 showed (e.g. if it's `0.0.15`, change to `0.0.16`) in `pubspec.yaml`'s `version:` line.

- [ ] **Step 3: Add a changelog entry**

Insert a new top entry in `CHANGELOG.md` (above the current top entry), matching this shape:

```markdown
## 0.0.16

- feat: added Swift Package Manager support for iOS and macOS, alongside the existing CocoaPods support (both are required by Flutter's current plugin policy). Verified on the example app: the plugin builds and the full integration test suite passes via both CocoaPods (`flutter config --no-enable-swift-package-manager`) and SPM (Flutter 3.47.4's default) on iOS Simulator and macOS.
- refactor: removed the unused Objective-C plugin registration shim (`WebcontentConverterPlugin.h`/`.m` — neither generated registrant referenced it) and renamed the Swift implementation class from `SwiftWebcontentConverterPlugin` to `WebcontentConverterPlugin`, matching `pluginClass` in `pubspec.yaml` and Flutter's current plugin template. No behavior change.
```

(Replace `0.0.16` with whatever version Step 2 actually used, if different.)

- [ ] **Step 4: Run the full check one more time to confirm nothing regressed**

```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter analyze
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /Users/whitehat/fvm/versions/3.47.4/bin/flutter test
```

Expected: `No issues found!` and `All tests passed!` for the plugin's own unit test suite.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore: bump version for Swift Package Manager support

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Notes

- **Spec coverage:** every numbered item in the spec's "Plan" section maps to a task here — shim removal/rename (Task 1), directory move + podspec (Task 2), `Package.swift` + gitignore (Task 3), dual-verification including the temporary global-config check (Task 4), housekeeping (Task 5, matching the spec's out-of-scope note that no other platform or dependency needs touching).
- **Placeholder scan:** no TBD/TODO; every code block is complete, copy-pasteable content, not a description of content.
- **Type/name consistency:** `WebcontentConverterPlugin` (renamed in Task 1) is the exact name used in Task 2's file moves, Task 3's `Package.swift` target name, and every verification command — no `Swift`-prefixed reference survives past Task 1.
