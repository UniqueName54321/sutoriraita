# Building and releasing v0.0.1 pre-alpha

Use Flutter **3.47.2 stable**, Dart **3.13.2** (bundled), and the committed
`pubspec.lock`. Run `flutter doctor -v`, `flutter pub get`, `flutter analyze`,
and `flutter test` before building. CI repeats analysis and tests on every runner.

| Target | Build host and requirements | Command | Output |
| --- | --- | --- | --- |
| Windows | Windows, Visual Studio with Desktop development with C++, Windows SDK | `flutter build windows --release` | `build/windows/x64/runner/Release/` |
| Linux | Ubuntu 24.04, clang, cmake, ninja-build, pkg-config, libgtk-3-dev, liblzma-dev | `flutter build linux --release` | `build/linux/x64/release/bundle/` |
| macOS | macOS, Xcode and command-line tools, Flutter plugin tooling | `flutter build macos --release` | `build/macos/Build/Products/Release/sutoriraita.app` |
| Android | Android SDK and accepted licenses, JDK 17 or newer compatible with Gradle | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| iOS | macOS, Xcode with iOS SDK, Flutter plugin tooling | `flutter build ios --release --no-codesign` | `build/ios/iphoneos/Runner.app` |

CI uses Windows, Ubuntu and macOS runners, not cross-compilation placeholders.
Download artifacts from the **Test and build** workflow. Each includes a complete
bundle, not just a desktop executable. The iOS artifact is an **unsigned .app ZIP**,
not an installable/signed IPA. Compile success is not proof of device usability.

## Document registration

- Android: install the APK; manifest VIEW filters accept the custom MIME type and
  ZIP/octet-stream providers. Android content URIs can conceal filenames, so other
  ZIP files may offer Sutōrīraitā in Open With; invalid projects are rejected.
- iOS/macOS: the app declares `org.sutoriraita.project`, `.sutoriraita` and
  `application/x-sutoriraita`. Finder/Files launch URLs retain security-scoped
  access until consumed. Install the macOS app in Applications.
- Windows: extract the whole bundle to a permanent location and run
  `powershell -ExecutionPolicy Bypass -File .\register.ps1`. This registers the
  current executable for the current user without administrator rights. Windows
  may require choosing the app in Open With. Rerun after moving the bundle.
- Linux: extract the bundle, then run `sh install.sh`. Requires
  `shared-mime-info`, `desktop-file-utils` and `xdg-utils`. It installs a per-user
  desktop entry/MIME definition pointing at this bundle. Rerun after moving it.

Windows/Linux external opens start a separate app instance. Avoid editing the same
live folder from multiple instances. Packed documents open as new library copies.

## Signing and publication

The current Android release configuration deliberately uses a **development/debug
key** for sideload testing. It is not a production Play Store release. Configure a
private release keystore and signing configuration before production publication;
never commit passwords, keystores or provisioning profiles. CI development keys
can differ between runs and from your local key, so Android may reject an in-place
upgrade. Use a consistent private signing key for upgrades; export independent
backups before uninstalling any existing app, because uninstalling removes its
private project library.

iOS installation/distribution requires an Apple developer team, a suitable bundle
identifier, certificates and provisioning profiles. Configure those locally or via
protected CI secrets, then use `flutter build ipa --release`. No dummy signing is
used to make unsigned CI pass. macOS public distribution needs Developer ID signing
and notarization; CI output is unnotarized. Windows public distribution should be
code signed. Existing `com.example.sutoriraita` application identifiers are retained
to avoid silently changing the existing app's storage/upgrade identity; choose final
identifiers and a migration strategy before a production release.

Before creating a version tag and GitHub **pre-release**, review successful CI
artifacts and record which interactive checks below were performed or remain
unverified. A production release requires completing those checks on supported
platforms. No workflow auto-publishes a production release. Keep `pubspec.yaml`,
README and CHANGELOG versions aligned.

## Required interactive checks

1. Create, edit, close and resume a normal library project; verify recovery files.
2. Android: select a project via Open Folder in Files, edit, force-stop and reopen;
   confirm changes in the provider. Repeat with a cloud provider, revoked access,
   picker cancellation and a folder missing `sutoriraita.json`.
3. On each OS: Open Project, cancel the picker, open a valid snapshot, reject an
   invalid ZIP, edit/export/reopen, and confirm the source snapshot is unchanged.
4. Open `.sutoriraita` from the system file manager with the app stopped and running.
   Test filenames containing spaces and non-ASCII characters.
5. Check import/export and platform-specific file permissions on real devices.

SAF saves use provider streams and preserve previous changed content under
`.recovery`; providers do not promise filesystem-style atomic renames. A failed
provider write must be treated as a save failure. Re-select folders after access
is revoked or a provider moves them. Native folder/provider integration is not
covered by the mocked Dart channel tests and needs the device checks above.


## v0.0.1 verification record (2026-08-30)

[CI run 33295809177](https://github.com/UniqueName54321/sutoriraita/actions/runs/33295809177)
passed analysis, all **28 tests**, and release builds on all five native platforms
for application commit `3f0c72b3528e954dd492ff26d70ba5bab7538c9f`. Release binaries
come from that run; subsequent release-preparation changes affect only documentation and the manual
artifact-staging workflow, not application code.
Windows and Android release builds also succeeded locally on Windows.

Downloaded desktop bundles were checked for their executable/runtime and document
registration metadata/scripts. The iOS artifact's document UTI and disabled automatic
URL routing were checked, and its Runner app has no app signature/provisioning.
Windows per-user format registration was applied and its quoted launch command
verified. The Linux registration script passed shell syntax validation.

No Android emulator or physical device was available in this session. Actual native
picker/provider interactions, restart permission behavior, and external-open UI
flows remain unverified on devices. macOS/iOS compilation must not be described as
interactive platform testing. The Dart SAF tests use a mocked document channel.


The manual **Stage pre-alpha release assets** workflow takes a successful build
run ID and an existing draft pre-release tag, downloads all five CI artifacts,
and uploads them with SHA256SUMS. It refuses failed builds or published/non-pre-alpha
releases, and never publishes the draft. Review the selected build commit and
artifact checksums before publishing the pre-release.
