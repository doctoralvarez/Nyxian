# Fork doctoralvarez/Nyxian — Changelog

Fork version is tracked here and in each modified file's header.
The app's `VERSION` in `Config.xcconfig` is intentionally left untouched:
Nyxian uses it to check compatibility with emexLabs OTA updates.

## 1.4.0 — 2026-11-07

### Code completion (improvement 9, phases 0 and 1)
- A suggestion list appears under the caret after typing 2+ letters of a word.
  **Tab** or **Return** accepts, **↑/↓** choose, **Esc** dismisses, or tap a row.
- **Phase 0 (all languages, Swift included):** words from the file being edited,
  the rest of the project and a built-in vocabulary (Swift keywords, common
  Swift/SwiftUI/Charts names; C/Objective-C keywords and common APIs).
- **Phase 1 (C, Objective-C, C++):** real completions from Clang
  (`ASTUnit::CodeComplete`), including members after `.` and `->`, with result
  types. Falls back to phase 0 until the file has been parsed once.
- Files: `CCASTUnit.cpp/.h` (CoreCompiler), `MDKASTUnit.h/.m`,
  `NXLanguageServer.h/.m`, `CodeEditor.swift`, `CodeEditorCoordinator.swift`.

## 1.3.1 — 2026-11-07

- Build fix in `FileList.swift` (search / quick open): `project.url` stored as a
  non-optional `URL`.

## 1.3.0 — 2026-11-07

### Editor and workspace
- **Search in Project** (⇧⌘F on iPad, or ⋯ > Search in Project): finds text in
  every project file; tapping a result opens the file at that line.
- **Open Quickly** (⇧⌘O on iPad, or ⋯ > Open Quickly): type part of a file name.
- **Move lines** up / down with ⌥⌘↑ / ⌥⌘↓.
- **Tappable runtime errors**: "file X.swift, line N" (Swift traps) and
  "path/X.swift:N:M" printed in the iPad console are underlined; tapping one
  opens that file and line.

### Projects
- **Import Swift Playgrounds apps (.swiftpm)** with the existing import button,
  as a folder or zipped. Becomes a SwiftUI app project; name, bundle ID and
  version come from Package.swift; images in Assets.xcassets become loose files.
  It warns about Swift package dependencies, `Bundle.module` and asset-catalog
  items that cannot be compiled on the device (colors, app icon).

Files: `CodeEditor.swift`, `FileList.swift`, `FileList+iPad.swift`,
`ContentView.swift`, `NXConsoleView.m`.

### CI (on main)
- Weekly "Check upstream (emexLabs)" workflow; `actions/checkout@v5`.

## 1.2.0 — 2026-11-07

### File list (project editor)
- Selection mode (⋯ > Select) gets a "Select All" button right after Delete.
  It turns into "Deselect All" once every file is selected, and back again.
  Delete, Copy and Share then act on whatever is selected.
- Checkmarks no longer disappear from selected rows while scrolling.
- File: `Nyxian/UI/FileList/FileList.swift`.

## 1.1.0 — 2026-11-07

### Boot
- New "Boot bundled IDE (this fork)" setting, on by default (Recovery > Settings).
  A normal boot now loads the IDE built into this IPA (`SuperSlot.dylib`) instead
  of downloading and booting the official emexLabs ROM from OTA, so the fork's
  changes are what actually runs. Turn it off to use a flashed/official ROM.
- "Restore Defaults" turns it back on.
- File: `Nyxian/UI/BootViewController.swift`.

## 1.0.0 — 2026-11-06

### Editor
- Find & Replace using the system find navigator (UIFindInteraction via Runestone).
  - ⌘F find, ⌥⌘F find and replace, ⌘G next match, ⇧⌘G previous match.
  - Magnifying-glass button in the on-screen editor toolbar for touch use.
- ⌘/ toggles `//` comments on the selected lines (C, ObjC, C++, Swift).
- ⌘] / ⌘[ shift the selected lines right / left.
- ⌘D duplicates the current line or selected lines.
- ⌘L go to line.

### iPad workspace
- ⌘B builds (compile and link) without signing, installing or running.
- ⇧⌘I opens the Issue Navigator.

### Issue Navigator
- Rows that navigate show "Line N, Col M" and a disclosure chevron.
- `path:line:col` references inside linker / internal messages are tappable.
- Fixed a possible crash when tapping the "Contains no messages" placeholder row.

Files: `Nyxian/UI/CodeEditor/CodeEditor.swift`,
`Nyxian/UI/FileList/FileList+iPad.swift`,
`Nyxian/LindChain/IDEBuilder/NXBuilder.swift`,
`Nyxian/LindChain/IDEFoundation/Project+Debug.swift`.
