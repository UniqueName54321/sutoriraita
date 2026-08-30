# Building and releasing v0.0.3 pre-alpha

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
README, CHANGELOG and the in-app version label aligned. Every distinct update gets
a new application version and a monotonically increasing build number. The current
release is `0.0.3+3` / `v0.0.3-pre-alpha`; retain the old v0.0.1 and v0.0.2 tags,
notes and downloads unchanged. Project `formatVersion` is independent of the app
version and remains **1**; this update needs no native data migration.

## Required interactive checks

1. Create, edit, close and resume a normal library project; verify recovery files.
2. Android: select a project via Open → Project folder in Files, edit, force-stop and reopen;
   confirm changes in the provider. Repeat with a cloud provider, revoked access,
   picker cancellation and a folder missing `sutoriraita.json`.
3. On each OS: Open → Packed project, cancel the picker, open a valid snapshot, reject an
   invalid ZIP, edit/export/reopen, and confirm the source snapshot is unchanged.
4. Open `.sutoriraita` from the system file manager with the app stopped and running.
   Test filenames containing spaces and non-ASCII characters.
5. Check import/export and platform-specific file permissions on real devices.
6. With Documents/HammerProjects present, decline the startup prompt and verify no
   copies are made. Restart, manually import, then try consenting with new folders.
7. Import a Hammer story, edit it, export, unzip into a new HammerProjects folder,
   and open it in Hammer. Check scene order, Unicode titles, notes, timeline and images.
8. Export `.nov`, restore it in Novelist, and check chapters, emphasis and encyclopedia.
   Advanced Markdown and native-only metadata intentionally do not fully transfer.

SAF saves use provider streams and preserve previous changed content under
`.recovery`; providers do not promise filesystem-style atomic renames. A failed
provider write must be treated as a save failure. Re-select folders after access
is revoked or a provider moves them. Native folder/provider integration is not
covered by the mocked Dart channel tests and needs the device checks above.


## v0.0.3 transfer verification (2026-08-30)

[CI run 33298451787](https://github.com/UniqueName54321/sutoriraita/actions/runs/33298451787)
passed analysis, 39 tests, and release builds on Windows, macOS, Linux, Android
and unsigned iOS. Final application commit:
`c8b0d8546bf6a9148ea0b28194c2608d4eae6082`. Release assets come from this run;
subsequent release-preparation commits change documentation only.
Local analysis passed and **40 tests passed** with the supplied Hammer examples
enabled (CI runs 39 tests and explicitly skips that local-only check).
Windows and Android release builds succeeded locally. Windows reports `0.0.3+3`;
Android's APK reports versionName `0.0.3`, versionCode `3`.
Downloaded macOS and iOS bundles report version `0.0.3`, build `3`, and retain
native document registration. The iOS Runner app has neither an app signature
nor provisioning profile. Downloaded Windows/Linux bundles include their
executables, runtimes and document-registration files/scripts.


Synthetic tests cover Hammer ordering, Unicode names, TOML null handling,
source-file preservation through native portable export, safe Hammer ZIP import,
empty-story exports, structural edits, rejected
formats/IDs, Android content-tree reads, startup consent/decline, and Novelist backup
structure/round trips. The supplied Hammer examples were also imported and exported
locally with manuscript equality and byte equality for notes, timeline and images;
the original folders were read-only test inputs and are not committed to Git.

To repeat that optional check in PowerShell:

```powershell
$env:SUTORIRAITA_HAMMER_EXAMPLES = 'C:\path\to\HammerProjects'
flutter test test/story_transfer_test.dart
```

CI uses synthetic fixtures; that local-only example test is explicitly skipped
unless the environment variable is set. No signing credentials are needed for
format support. iOS remains an unsigned build, not an installable IPA; Android
uses development signing. Native file-provider and external-app interoperability
checks remain unverified on real mobile/Apple devices. Hammer folder import is
not offered on iOS because the current picker does not retain the security scope;
use its ZIP import route instead.

## v0.0.2 verification record (2026-08-30)

[CI run 33296789835](https://github.com/UniqueName54321/sutoriraita/actions/runs/33296789835)
passed analysis, all **28 tests**, and release builds for Windows, macOS, Linux,
Android and unsigned iOS at application commit
`7f56160cc299bb88391450d7304f015052a39f0d`. The release uses those artifacts;
subsequent release-preparation commits only update documentation.

The local Windows executable reports `0.0.2+2`; downloaded macOS and iOS app
metadata reports version `0.0.2`, build `2`. The new release tag is
`v0.0.2-pre-alpha` and download filenames include that version. No project-format
change or data migration is involved. Device-level UI checks remain unperformed;
compilation and unit/widget test results are not a substitute for them.

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
and uploads them with versioned filenames and SHA256SUMS. It checks that the
release tag agrees with the selected build's pubspec version. It refuses failed builds or published/non-pre-alpha
releases, and never publishes the draft. Review the selected build commit and
artifact checksums before publishing the pre-release.
