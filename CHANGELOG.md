# Changelog

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
