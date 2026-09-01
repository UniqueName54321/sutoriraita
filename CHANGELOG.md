# Changelog

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
