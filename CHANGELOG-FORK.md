# Fork doctoralvarez/Nyxian — Changelog

Fork version is tracked here and in each modified file's header.
The app's `VERSION` in `Config.xcconfig` is intentionally left untouched:
Nyxian uses it to check compatibility with emexLabs OTA updates.

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
