# Fork doctoralvarez/Nyxian — Changelog

Fork version is tracked here and in each modified file's header.
The app's `VERSION` in `Config.xcconfig` is intentionally left untouched:
Nyxian uses it to check compatibility with emexLabs OTA updates.

## 1.8.0 — 2026-11-07

- **Parameter help**: typing `(` or `,` in a call shows a bubble above the caret
  with the function's signature, the current argument in bold and its
  documentation; `)` or moving to another line closes it, **Esc** too, and
  **⌃⇧Space** shows it on demand. Swift uses the compiler's signature help
  (`IDEInspectionInstance::signatureHelp`); C/ObjC/C++ use Clang's overloads.
- **Documentation in suggestions**: the selected suggestion's doc comment is shown
  under the list (Clang brief comments, Swift doc comments).
- `CCASTUnitCopySignatureHelpAtLocation`, `-[MDKASTUnit signatureHelpAtLocation:]`,
  `-[NXLanguageServer signatureHelpAtLine:utf8Column:content:]`.

## 1.7.0 — 2026-11-07

- **Format Document (⌃I)**: C, Objective-C and C++ with clang-format (LLVM style,
  tab indentation, lines are never re-wrapped; `CCCopyFormattedSource`);
  Swift with a brace-depth re-indenter (`case` aligned with `switch`,
  multi-line strings left untouched). One undoable edit.
- **Rename Symbol (⌃⌘E)**: whole-word rename across every project text file.
  Shows how many occurrences in how many files before applying. Open tabs are
  edited in place (undo with ⌘Z); closed files are written directly. Text
  based: matches in comments and strings are renamed too.
- **Customization toggles**: "Code Completion" and "Shortcut List (hold ⌘)".
- Console tap-to-open stays iPad-only: the iPhone layout has no console pane.

## 1.6.0 — 2026-11-07

- **Shortcut list**: hold **⌘ alone for 2 seconds** to see the keyboard
  shortcuts of the current screen (read live from the app's key commands, with
  Spanish names). It closes when ⌘ is released or any other key is pressed.
  Uses GameController's keyboard input (`KeyboardShortcutsHUD`, ContentView.swift).
- **Fork version in Settings**: the footer shows "Fork doctoralvarez 1.6.0" under
  Nyxian's own version. Source of truth: `NYXIAN_FORK_VERSION` in
  `Config.xcconfig` (→ `NXForkVersion` in Info.plist); bump it with every release.
- **Editor font size 20 by default** (was 12); the stepper now goes up to 32. An
  existing setting still at the old default 12 is moved to 20 once.

## 1.5.0 — 2026-11-07

### Code completion phase 2: Swift
- Swift files get completions from the Swift compiler itself
  (`swift::ide::IDEInspectionInstance`, the engine behind SourceKit), already
  bundled in Nyxian's toolchain (`libswiftIDE`/`libswiftIDETool`), so no LLVM
  rebuild was needed.
- Understands types: members after `.`, argument labels, result types; nearer
  scopes (locals, members, this module) are listed before the SDK.
- Functions are inserted as `name()` with the caret inside the parentheses.
- The engine keeps the last type-checked AST and reuses it while typing inside
  function bodies. While it is busy, keystrokes use the word suggestions.
- Files: `CCASTUnit.cpp/.h`, `NXLanguageServer.h/.m`, `CodeEditor.swift`.

## 1.4.1 — 2026-11-07

- Build fix in `CCASTUnit.cpp`: include `clang/Frontend/FrontendActions.h`.

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
