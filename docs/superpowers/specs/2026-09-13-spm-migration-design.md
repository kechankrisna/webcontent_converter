# Swift Package Manager Support for iOS/macOS: Design

## Problem

`webcontent_converter` uses `sharedDarwinSource: true` — one `darwin/`
folder and one podspec (`darwin/webcontent_converter.podspec`) serve both
`ios` and `macos` in `pubspec.yaml`. It has no CocoaPods-only support:
every build under Flutter 3.44+ (SPM is the live default there, confirmed
by `flutter config` having no override set on this machine) prints

```
Plugin webcontent_converter does not have Swift Package Manager support
for ios/macos. Consider adding Swift Package Manager compatibility...
```

and falls back to CocoaPods per-plugin. The goal: add real SPM support to
this plugin (and prove the example app builds with it), without breaking
the CocoaPods path — Flutter's policy is that plugins must support both
"until further notice."

## Ground truth used

Rather than trust doc summaries, this was verified directly against
Flutter 3.47.4's own `flutter_tools` source and template files (the exact
version this repo targets), plus real shipped plugins for cross-checking:

- `packages/flutter_tools/templates/plugin_darwin_spm/darwin.tmpl/` — the
  live template for a `sharedDarwinSource` SPM plugin: one
  `<name>/Package.swift` and `<name>/Sources/<name>/` directory, **not**
  duplicated per platform. `Package.swift` declares both
  `.iOS(...)`/`.macOS(...)` in a single target; the existing podspec
  already does the same platform split via `s.ios.dependency` /
  `s.osx.dependency`, so this isn't a new pattern for this codebase.
- `packages/flutter_tools/lib/src/darwin/darwin.dart`
  (`FlutterDarwinPlatform.deploymentTarget()`): Flutter 3.47.4's actual
  minimums are `iOS 15.0` / `macOS 12.0` — matching what this repo's
  example app was already bumped to during the earlier 3.47.4 upgrade
  work, not the older 13.0/10.15 the current podspec still declares.
- `packages/flutter_tools/lib/src/macos/swift_packages.dart`:
  `swift-tools-version: 5.9`.
- Cross-checked against `webview_flutter_wkwebview` and
  `local_auth_darwin` (both real, shipped `sharedDarwinSource` + SPM
  plugins in `flutter/packages`) for directory shape.
- Confirmed via `docs.flutter.dev/.../for-app-developers`: Flutter falls
  back to CocoaPods per-dependency, so the example app's *other*
  CocoaPods-only plugins (`path_provider`, `printing`, etc.) need no
  changes.

## Existing registration is already dead-code-adjacent

`darwin/Classes/WebcontentConverterPlugin.h`/`.m` is a thin Objective-C
shim forwarding to `SwiftWebcontentConverterPlugin`. Checked both
generated registrants in the example app:

- `example/ios/Runner/GeneratedPluginRegistrant.m` calls
  `[SwiftWebcontentConverterPlugin registerWithRegistrar:...]` directly.
- `example/macos/Flutter/GeneratedPluginRegistrant.swift` calls
  `SwiftWebcontentConverterPlugin.register(with:...)` directly.

Neither references the `.h`/`.m` shim at all — it's already unused. Since
`SwiftWebcontentConverterPlugin` is `public class ... NSObject,
FlutterPlugin`, it's already visible to Objective-C via the
auto-generated `<module>-Swift.h` bridging header (that's how the current
ObjC shim calls it today), so renaming it to match `pluginClass` exactly
and dropping the shim works from both registrants with no interop
workarounds needed. Confirmed (with the user) as the preferred approach
over keeping the ObjC shim under SPM's `include/<name>/` convention,
since it matches Flutter's own current plugin template exactly.

## Plan

**In `webcontent_converter`'s own `darwin/`:**

1. Delete `darwin/Classes/WebcontentConverterPlugin.h` and `.m`.
2. In `darwin/Classes/SwiftWebcontentConverterPlugin.swift`, rename the
   class `SwiftWebcontentConverterPlugin` → `WebcontentConverterPlugin`
   (matching `pluginClass: WebcontentConverterPlugin` in `pubspec.yaml`);
   rename the file to `WebcontentConverterPlugin.swift`.
3. Move the remaining source files into
   `darwin/webcontent_converter/Sources/webcontent_converter/`:
   `WebcontentConverterPlugin.swift`, `ConversionQueue.swift`,
   `FLWebView.swift`, `Page.swift`, `PdfPageMerger.swift`,
   `PrintPreviewWindowMacOS.swift`, `RequestWatchdog.swift`,
   `WKWebView+Debug.swift`.
4. Add `darwin/webcontent_converter/Package.swift`
   (`swift-tools-version: 5.9`, `.iOS("15.0")`, `.macOS("12.0")`,
   `FlutterFramework` path dependency) — copied from Flutter 3.47.4's own
   `plugin_darwin_spm` template, substituting this plugin's name.
5. Update `darwin/webcontent_converter.podspec`: `source_files` →
   `'webcontent_converter/Sources/webcontent_converter/**/*'`, bump
   `s.ios.deployment_target`/`s.osx.deployment_target` to `15.0`/`12.0`,
   split `pod_target_xcconfig` into `s.ios.pod_target_xcconfig` /
   `s.osx.pod_target_xcconfig` — matching Flutter's SPM-variant podspec
   template exactly (this is the same file Flutter's tooling reads for
   the CocoaPods fallback path, so it must keep working standalone).
6. Delete the now-empty `darwin/Classes/` directory.
7. Add `.build/` and `.swiftpm/` to `.gitignore` if not already covered.

**Verification:**

1. `--no-enable-swift-package-manager` (temporary, restored immediately
   after) to confirm the example app still builds/runs via CocoaPods on
   iOS Simulator and macOS — proving nothing broke for the fallback path.
2. Default (SPM) path: rebuild, confirm the "doesn't support Swift
   Package Manager" warning is gone, confirm
   `example/ios/Runner.xcodeproj` and
   `example/macos/Runner.xcodeproj` pick up
   `FlutterGeneratedPluginSwiftPackage`.
3. Re-run `example/integration_test/webcontent_converter_test.dart` (real
   native-plugin calls) on iOS Simulator and macOS under the SPM path,
   using the same isolation technique established earlier this session
   for the one macOS-environment-specific pathological-input case if it
   recurs.
4. `flutter analyze` / `flutter test` stay clean.

## Out of scope

- Migrating the example app's *other* CocoaPods-only plugin dependencies
  to SPM — not needed; Flutter mixes both per-dependency.
- Any change to Android or Windows.
- Publishing a `.podspec`-free, SPM-only release — CocoaPods stays
  mandatory per Flutter's current policy.
