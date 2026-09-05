# Sutōrīraitā

**v0.1.2 pre-alpha — expect bugs.** Do not trust this program with the only copy
of your writing. Keep independent backups. macOS and iOS are untested or rarely
tested and are especially likely to have bugs, even when their builds compile.

The **v0.1.2 update** adds a question-driven Gemmell Wizard and encyclopedia
discovery, plus split/merge, duplication, multi-selection, metadata, project
search/replace, aliases, backlinks, persistent trash, and action undo/redo.
Prose remains the default focus; enable **Experimental Features** for Screenplay
or Interactive Fiction. The **Use Gemmell wizard** preference is independent of
**Use export wizards**. Gemmell still uses Prompt Bridge: copy the prepared prompt
to your chatbot and review its suggestions manually.

This source version is separate from v0.1.1. Published download links below remain
unchanged until new release artifacts are published.
See [CHANGELOG.md](CHANGELOG.md) for the changes in each version, or
[download v0.1.0 pre-alpha](https://github.com/UniqueName54321/sutoriraita/releases/tag/v0.1.0-pre-alpha).

A calm, local-first story-writing workspace targeting Windows, Android, Linux,
macOS and iOS.

## Download the app

You do not need to build the app yourself. The latest published builds are
**v0.1.0 pre-alpha**:

<!-- Update the version and every asset link below when publishing a new release. -->

| Platform | Download | Getting started |
| --- | --- | --- |
| Windows (64-bit) | [Download ZIP](https://github.com/UniqueName54321/sutoriraita/releases/download/v0.1.0-pre-alpha/sutoriraita-v0.1.0-pre-alpha-windows.zip) | Extract the **whole ZIP**, then run `sutoriraita.exe`. Keep its accompanying files together. |
| macOS | [Download app ZIP](https://github.com/UniqueName54321/sutoriraita/releases/download/v0.1.0-pre-alpha/sutoriraita-v0.1.0-pre-alpha-macos.zip) | Extract and move `sutoriraita.app` to Applications. This build is unnotarized, so macOS may block it. |
| Linux (x86-64) | [Download tar.gz](https://github.com/UniqueName54321/sutoriraita/releases/download/v0.1.0-pre-alpha/sutoriraita-v0.1.0-pre-alpha-linux.tar.gz) | Extract the full archive, then run `sutoriraita`. Run `sh install.sh` to add desktop/file-type integration. Requires GTK 3. |
| Android | [Download APK](https://github.com/UniqueName54321/sutoriraita/releases/download/v0.1.0-pre-alpha/sutoriraita-v0.1.0-pre-alpha-android.apk) | Open the APK on your device and allow installation from that source when prompted. This is a development-signed build. |
| iOS | [Download unsigned app ZIP](https://github.com/UniqueName54321/sutoriraita/releases/download/v0.1.0-pre-alpha/sutoriraita-v0.1.0-pre-alpha-ios-unsigned.zip) | **Not ready to install.** Apple signing and provisioning are required; there is no signed IPA or TestFlight release yet. |

See the [release notes](https://github.com/UniqueName54321/sutoriraita/releases/tag/v0.1.0-pre-alpha)
and [SHA-256 checksums](https://github.com/UniqueName54321/sutoriraita/releases/download/v0.1.0-pre-alpha/SHA256SUMS).
**Android upgrades:** development signing keys can differ between builds, preventing
an in-place upgrade. Back up your projects before uninstalling an existing version:
uninstalling removes its app-private project library.

See [BUILDING.md](BUILDING.md#document-registration) for file-type registration
and [build/signing requirements](BUILDING.md). macOS and iOS remain rarely tested.

## About the project

New projects are stored as ordinary folders under
`Documents/Sutōrīraitā Projects`, with a readable `sutoriraita.json` manifest
and one Markdown file per scene. It includes chapter
and scene organisation, CommonMark writing and rendered viewing, a typed
encyclopedia, deterministic entity suggestions, aggressive autosave, recovery
copies, Markdown-folder import, and Markdown, plain-text, and portable exports.

The welcome screen groups actions into three compact dropdowns: **New project**
(blank or example), **Open** (packed project or folder), and **Import** (Markdown,
Novelist, Hammer, or Fountain). Additional formats belong inside these menus, not in new buttons.

## Extensible document models (v0.1.0)

Choose a document model when creating a project:

| Model | Editing model | Mode export |
| --- | --- | --- |
| Prose | Chapters and CommonMark scenes | Existing Markdown, document, Hammer, Novelist, and native exports |
| Screenplay | Typed scene headings, action, character, dialogue, parenthetical, transition, shot, lyric, and note elements | Fountain (`.fountain`) |
| Interactive Fiction | Sōhōkō-sei Story / Choice graph with CommonMark passages, choices, variables, conditions, effects, start and ending passages | Ink (`.ink`) |

Screenplay editing provides smart Enter transitions, Tab element cycling,
character-name autocomplete, and the existing scene navigator. Fountain files can
be imported from **Import → Fountain screenplay**. Fountain is an interchange
format; the native `.sutoriraita` project remains the complete editable source.

Interactive Fiction uses the versioned **Sōhōkō-sei** intermediate representation
instead of treating Ink as its storage model. The editor includes a selectable node
graph, dead-link and unreachable-passage checks, variables, conditional choices,
assignments/effects, and an in-app Play/Test flow. v0.1.0 implements Ink-style
**Story / Choice** fiction. It does not implement Quest-style World / Parser fiction.
Keep native backups because Ink export is intentionally a generated target.

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
portable snapshot created only when the user chooses **Export story project → Sutōrīraitā**;
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

## Hammer and Novelist stories (v0.0.3)

Use **Import → Hammer story → Story folder** and select the individual story folder
containing `project.toml` and `scenes`, not its parent `HammerProjects` folder.
Alternatively, select **Story ZIP** to import a ZIP containing one Hammer project.
On iOS, compress the story folder in Files and use Story ZIP; folder import is not
offered because the current picker does not retain the required security scope.
The import creates a separate editable copy. Android uses its system document-tree
picker; it never treats a `content://` URI as a filesystem path.

On desktop platforms where Documents is readable, startup detects stories under
`Documents/HammerProjects` and asks before importing anything. **Import copies**
imports the detected stories; **Skip these stories** remembers the decision.
Manual import remains available. Newly discovered folders can trigger a later
prompt. Failed imports can be retried. There is no background synchronization.
Android/iOS sandboxes do not permit automatic discovery of another app's files;
sandboxed macOS builds also require access to Documents.

In a project, choose **⋯ → Export story project…**:

| Format | What it contains / how to use it |
| --- | --- |
| Sutōrīraitā (`.sutoriraita`) | Complete native snapshot, including retained Hammer source data. Recommended for backups. |
| Hammer (`.hammer.zip`) | Extract the story folder inside into Hammer's `HammerProjects` directory, using a new name if a folder already exists. Includes current Markdown scenes, encyclopedia entries, author/language, and retained Hammer notes, timeline, images and drafts. |
| Novelist (`.nov`) | A version-4 Novelist story backup with chapters, scenes, bold/italic spans, and encyclopedia categories/items. Import through Novelist's backup/restore flow; it is not a renamed manuscript file. |

Hammer support targets **dataVersion 2**, as used by the supplied examples.
Unchanged hierarchy and numeric scene IDs are retained; structural edits flatten
nested groups into the current chapter order. Empty source groups are not represented
in the editor. Names containing Hammer's reserved `~` delimiter are sanitized.
Notes, timeline and images are preserved but do not yet have editing UIs here.
The original imported files are kept in `assets/hammer-source.json` and travel in
native project backups: this snapshot can still contain text subsequently deleted
from the working manuscript. Hammer exports use current scenes and entries and
clear server association information. Always extract into a **new** folder;
merging into an existing Hammer folder can leave stale scenes behind.

Novelist import accepts version 4 and 5, reading the latest revision for version 4
and the first book for version 5. Export simplifies headings, lists, links, tables
and other advanced Markdown to text; embedded images are not transferred. Native
relations, schema/custom fields, Hammer notes/timeline, and history are not mapped
into Novelist. Author/language are retained in optional Sutōrīraitā metadata; the
author also appears in the story description. Keep a native backup for a full copy.
Direct interoperability in Hammer and Novelist, especially on mobile, still needs
interactive testing. Keep the originals until you have checked the result.

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

## Editing features in v0.1.2

- In **Write** mode, use **Formatting and scene actions → Split scene at cursor**.
  Scene menus offer duplicate, merge with next, and scene details. Merging keeps
  the first scene's title/metadata and puts the other original scenes in Trash.
- Use scene checkboxes for multi-selection; Shift-click a checkbox for a range.
  Chapter menus can select all their scenes. Use the selected-scene menu or drag
  a selected grip to move the whole selection. **Move selected** allows an exact
  destination chapter and position, including positions outside the current view.
- Use **Scene details** for POV, location, date/time and status. Fictional dates
  are free text. Metadata is retained in native projects and duplicated scenes.
- Use **Project menu → Project search / replace** (Ctrl+Shift+F). Search is literal,
  with optional case and whole-word matching; it covers active scene body text
  and, by default, encyclopedia body text. Results preview matches and link to
  their source. Titles, metadata and Trash are excluded from replacement.
- In an encyclopedia entry's menu, edit **Aliases** or choose **Where is this
  mentioned?** to open mentions, including aliases, in the manuscript.
- Deleted scenes, chapters and entries go to **Project menu → Trash / restore**.
  Trash persists across restarts and native backups. It is omitted from manuscript
  exports and external story formats. Existing whole-project archive/delete
  controls remain separate.
- Use sidebar undo/redo or **Ctrl+Alt+Z / Ctrl+Alt+Y** for action history. History
  holds the last 60 actions in the current project session, including grouped
  typing edits; it resets when switching projects. Native editor text undo remains
  available. Undo can recover the exact pre-merge scene structure and links.
- With Gemmell enabled, its tools button opens the wizard. Discovery asks whether
  to include the full manuscript or current chapter, otherwise using the scene.
  Its prepared prompt includes scene references and known names/aliases; it does
  not create encyclopedia entries or run an AI service automatically.
