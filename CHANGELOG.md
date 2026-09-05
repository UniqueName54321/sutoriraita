# Changelog

## v0.1.2 pre-alpha — 2026-09-05

- Introduce a question-driven Gemmell Wizard for manuscript selections, scenes,
  whole-story audits and encyclopedia entries. Each recommendation explains the
  tool with an example. A separate **Use Gemmell wizard** setting restores the
  original lists; the export wizard preference is independent.
- Add **Discover encyclopedia entries**, with current scene, current chapter and
  entire manuscript scope. Prompt Bridge includes named source scenes and known
  encyclopedia names/aliases, and requests evidence-backed proposals for review.
- Split Prose scenes at the cursor; merge selected scenes in manuscript order;
  duplicate scenes or chapters with fresh IDs and copied metadata. Internal links
  within duplicated chunks target their copies; merging redirects scene links.
- Add scene checkboxes, Shift-range selection, chapter selection and batch move,
  duplicate, merge and trash actions. Dragging a selected scene moves its selected
  chunk. The Move dialog specifies a destination chapter and insertion position.
- Add POV, location, fictional date/time and status metadata to scenes.
- Add literal project search/replace across scene bodies and optional encyclopedia
  bodies, with case/whole-word controls, result previews and undo.
- Add encyclopedia aliases and mention backlinks that open the matching scene and
  select the text. Discovery recognizes existing aliases and avoids duplicates.
- Move deleted scenes, chapters and encyclopedia entries to persistent Trash,
  with restore. Native packages preserve trash; manuscript exports omit it.
- Add bounded session undo/redo for manuscript operations, metadata, search/replace
  and encyclopedia changes, grouping consecutive prose edits. Keyboard shortcuts:
  Ctrl+Alt+Z / Ctrl+Alt+Y for action undo/redo, Ctrl+Shift+F for project search.
- Version `0.1.2+7` is separate from v0.1.1; optional native fields remain backward
  compatible with format 1. Older app versions may discard the new fields.

## v0.1.1 pre-alpha — 2026-09-05

- Drag chapter grips to reorder whole chapters, with all their scenes. Drag scene
  grips between positions in the same chapter or into another chapter, including
  empty chapters. Drop on a chapter title to insert at its start.
- Add, replace and remove PNG/JPEG covers in Project settings. Covers persist
  locally and appear in PDF, EPUB, HTML, FB2 and ODT manuscript exports. Plain
  text and Markdown omit covers; all story-project transfers strip covers.
- Use Yes/No export wizards by default, with Back, Cancel and a final format
  confirmation. Disable Use export wizards in App settings for the original lists.
- Add Experimental Features, disabled by default. Screenplay and Interactive
  Fiction creation, editors and format actions require it. Existing experimental
  projects remain intact and can be edited again after enabling the setting.
  Parser IF additionally requires the existing Developer Mode setting.
- Version `0.1.1+6` is a separate release from v0.1.0; native format remains 1.

## v0.1.0 pre-alpha — 2026-09-01

**Stories are no longer assumed to be linear prose.**

- Add a backward-compatible extensible document model. Manifests without a
  `projectType` remain Prose; native format version remains 1.
- Let project creation choose Prose, Screenplay, or Interactive Fiction
  (Ink-style Story / Choice, not Quest-style World / Parser).
- Add a typed screenplay editor with scene headings, action, character, dialogue,
  parenthetical, transition, shot, lyrics, and notes; smart Enter/Tab transitions;
  character autocomplete; and the existing scene navigator.
- Import and export Fountain screenplays through native system pickers.
- Add the versioned Sōhōkō-sei IF intermediate representation with passages,
  choices, variables, conditions, assignments/effects, start/ending passages,
  stored graph positions, and CommonMark passage prose.
- Add node-graph visualization, dead-link and unreachable-node analysis, and a
  built-in Play/Test flow that evaluates simple conditions and effects.
- Export Sōhōkō-sei Story / Choice projects as generated Ink `.ink` stories.
- Keep project creation, persistence, native packages, Prose behavior, Hammer,
  Novelist, and existing document exports compatible.
- Increment application version/build to `0.1.0+5`.

## v0.0.4 pre-alpha — 2026-09-01

- Make the workspace, project list, encyclopedia, dialogs, and editor respond to
  small phone/tablet viewports, landscape orientation, safe areas, keyboards,
  and enlarged text without hiding controls or content.
- Open and close the mobile manuscript drawer through the workspace Scaffold key,
  removing the unreliable context above the Scaffold.
- Replace overflowing mobile Scene Editor and encyclopedia toolbars with compact
  icon actions and overflow menus while preserving the existing desktop layout.
- Keep project actions compact at high text scaling and allow project filters and
  section headers to wrap within narrow screens.
- Add widget coverage at 320×568, 568×320, 360×640, and 600×960 with safe-area,
  keyboard, and 160–200% text scaling checks, including a real drawer interaction.
- Increment app version/build to `0.0.4+4`; native project format remains 1.

This is the final planned pre-alpha update before v0.1.0.

## v0.0.3 pre-alpha — 2026-08-30

- Import Hammer dataVersion-2 story folders and ZIPs, including Android document-tree
  URIs. iOS uses ZIP import to avoid losing access to security-scoped folders.
- Preserve ordered Markdown scenes, root scenes, encyclopedia, author/language,
  and source notes, timeline, images and drafts without changing the originals.
- Detect readable desktop Documents/HammerProjects folders at startup and request
  confirmation before importing copies. Remember skipped/imported folders; manual
  import remains available.
- Export Hammer story ZIP folders and Novelist `.nov` version-4 backups from a
  compact Export story project dialog. Keep native portable export available.
- Import Novelist version-4 backups as well as version 5; read picked files as
  streams, preserve bold/italic spans, and give each import its own identity.
- Increment app version/build to `0.0.3+3`; native project format remains 1.
- Update platform download links and document transfer limits and signing requirements.

## v0.0.2 pre-alpha — 2026-08-30

- Group welcome-screen actions into New project, Open and Import dropdown menus.
  All existing actions remain available; future formats can be added without
  expanding the button row.
- Keep the same project/container format and existing creation, opening and import behavior.
- Increment the application version to `0.0.2+2` and update the in-app pre-alpha label.

## v0.0.1 pre-alpha — 2026-08-30

Initial pre-alpha release. Expect bugs and keep independent backups of your work.
macOS and iOS have received little or no interactive testing.

- Local project library, chapters, Markdown scenes, encyclopedia, autosave and recovery copies.
- Example project, Markdown and Novelist imports, genre packs and manuscript exports.
- Android Open Folder uses Storage Access Framework document trees and persists granted access.
- Open Project uses the system picker to unpack `.sutoriraita` snapshots into independent editable library copies.
- Packed-project validation rejects unsafe paths, duplicate entries and unsupported formats.
- External document opening on Android, iOS, Windows, macOS and Linux; desktop bundle registration scripts.
- GitHub Actions tests and native builds for all five platforms, including unsigned iOS artifacts.

Known limitations: document providers do not guarantee atomic writes; recovery copies
are saved before changes. Portable packages remain snapshots, not live archive-backed
projects. Apple builds require platform testing and signing before distribution.
