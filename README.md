# Sutōrīraitā

**v0.0.2 pre-alpha — expect bugs.** Do not trust this program with the only copy
of your writing. Keep independent backups. macOS and iOS are untested or rarely
tested and are especially likely to have bugs, even when their builds compile.

The dropdown menu redesign is the **v0.0.2 update**, separate from the initial
v0.0.1 release. Existing projects remain compatible; no migration is needed.
See [CHANGELOG.md](CHANGELOG.md) for the changes in each version.

A calm, local-first story-writing workspace targeting Windows, Android, Linux,
macOS and iOS.

New projects are stored as ordinary folders under
`Documents/Sutōrīraitā Projects`, with a readable `sutoriraita.json` manifest
and one Markdown file per scene. It includes chapter
and scene organisation, CommonMark writing and rendered viewing, a typed
encyclopedia, deterministic entity suggestions, aggressive autosave, recovery
copies, Markdown-folder import, and Markdown, plain-text, and portable exports.

The welcome screen groups actions into three compact dropdowns: **New project**
(blank or example), **Open** (packed project or folder), and **Import** (Markdown
or Novelist). Additional formats belong inside these menus, not in new buttons.

The startup screen scans the managed library and lists every valid project.
App settings choose whether launch opens that project list or resumes the most
recent project. Entity suggestions are deterministic and local: characters,
locations, and groups are suggested by default; experimental object and event
detection is opt-in. Suggestions never use AI or send manuscript text away.

**Open → Project folder** opens an existing folder containing `sutoriraita.json`. On Android,
it uses the Storage Access Framework and remembers granted access; saves go back
to the selected document provider without converting its content URI to a path.

**Open → Packed project (.sutoriraita)** selects a packed `.sutoriraita` file with the system picker.
Opening a package extracts a new editable library copy; it never modifies the
original snapshot. Opening the file externally does the same. Windows/Linux
bundles include registration scripts; see [BUILDING.md](BUILDING.md).

The folder is always the live project. A `.sutoriraita` file is a ZIP-backed
portable snapshot created only when the user chooses **Export portable package**;
autosave never rewrites that archive. Portable snapshots contain only canonical
project data: the manifest and supported `scenes`, `encyclopedia`, `notes`,
`research`, and `assets` directories. Recovery data, caches, temporary files,
OS metadata, symlinks, and nested `.sutoriraita` packages are excluded.

The welcome screen can install **Mochi, Markdown & the Moonlight Laundromat**,
a comedic furry slice-of-life example whose story quietly teaches project
folders, scene organisation, Markdown, autosave, recovery, import, and export.
It is copied into the managed library as a normal editable `— Copy`; the
canonical source and its compatibility metadata live conspicuously under
`assets/example_project/` and are exercised by `example_project_test.dart`.

## Run

```sh
flutter pub get
flutter run -d windows
```

For Android, connect a device or start an emulator and run `flutter run`.

To create a release build on Windows, double-click `build_windows.bat` or run
it from a terminal. The finished application is written to
`build/windows/x64/runner/Release`.

For a debug build, run `build_windows_debug.bat`. Its output is written to
`build/windows/x64/runner/Debug`.

To create an Android release APK, run `build_android.bat`. Its output is
written to `build/app/outputs/flutter-apk/app-release.apk`.

## Internal scene links

Use **More CommonMark → Internal scene link** to link selected text to another
scene. Links are stored as ordinary readable Markdown, for example
`[the cellar](scene:cellar)`, so renaming a scene does not break them. Preview
links navigate inside the project; HTML and EPUB exports use clickable anchors;
PDF exports resolve each link to its current destination page during pagination.

## Project layout

```text
Documents/
  Sutōrīraitā Projects/
    My Story/
      sutoriraita.json
      scenes/
        <scene-id>.md
      encyclopedia/
        <entry-id>.md
      .recovery/
        sutoriraita.json.bak
        scenes/
          <scene-id>.md.bak
        encyclopedia/
          <entry-id>.md.bak
        latest.json
```

Project saves use a flushed temporary file and rename cycle. The previous
manifest and previous copy of every changed scene are retained in `.recovery`.
Scene files carry their own ID, type, and visible heading so the manuscript can
be reconstructed even without its manifest. Editor preferences such as the
autosave delay live in application settings rather than inside the book.

See [CHANGELOG.md](CHANGELOG.md) for release history and [BUILDING.md](BUILDING.md)
for all five platforms, CI artifacts, signing requirements and testing limits.

[GitHub CI and build artifacts](https://github.com/UniqueName54321/sutoriraita/actions/workflows/build.yml)
cover Windows, macOS, Linux, Android and unsigned iOS.
