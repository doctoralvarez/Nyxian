# Fork doctoralvarez/Nyxian — Changelog

Fork version is tracked here and in each modified file's header.
The app's `VERSION` in `Config.xcconfig` is intentionally left untouched:
Nyxian uses it to check compatibility with emexLabs OTA updates.

## 1.53.0 — 2026-11-10

- Python could still stay on "Installing python3…" until Nyxian was closed
  (and then unpack again on the next launch). Installing a launcher in
  `usr/bin` through Nyxian's service now waits at most 12 s per attempt; a
  call that does not answer counts as a failed attempt (retried, then
  reported as an error instead of waiting forever).
- The "Preparing…" window of Python and Node.js has **Hide (keeps
  preparing)**: no need to close Nyxian; a notice says when it is ready.
- The signing report is written in the background and only reads the
  signatures (building an identity could sign a file again and hold up a
  launch).
- **Java in Shell** opens an interactive Shell that starts with
  `java -version` and a tip, instead of a window that printed the version
  and ended (it looked like an error).

## 1.52.0 — 2026-11-10

- `node` and `java` now start from Nyxian Shell (confirmed on the iPhone).
- Java no longer prints mimalloc's "unable to allocate aligned OS memory
  directly" warning: the `java` launcher (and Java's environment) asks
  miniJVM's allocator for 64 MiB reservations instead of 1 GiB, which iOS
  refuses, and not to print warnings.
- Python could stay on "Preparing…" or "Installing…" until Nyxian was
  closed: it could be signing while Node.js or Java were signing in the
  background. Python, Node.js and Java are now prepared one at a time; while
  waiting it says so.

## 1.51.0 — 2026-11-10

- Nyxian Shell used Nyxian's posix_spawn but programs still did not start,
  and the host still never saw the request. Nyxian's posix_spawn first reads
  the program (inside python3) to check its signature; python3's file sandbox
  did not include `usr/bin`, where node and java live, so the check failed
  and the request was refused right there. python3 may now read `usr/bin`
  (only its launcher is signed again, once). Programs the Shell starts
  inherit this sandbox, so they can read their own executable too.

## 1.50.0 — 2026-11-10

- **Probable cause of "could not start (Operation not permitted)"** in
  Nyxian Shell: the host never even saw the request (no "what Nyxian saw").
  The Shell called posix_spawn through ctypes, which looks it up with dlsym
  and so gets the system's posix_spawn — iOS refuses it — instead of
  Nyxian's, which Nyxian puts in place with dyld interposing (dlsym does not
  see that). The Shell now calls Nyxian's own posix_spawn (through its
  `posix_spawn__ptr`), else `os.posix_spawn`; the error says which it used.
- The host's refusal report goes to Python's home as Nyxian sees it (inside
  LiveContainer NSHomeDirectory() is another folder).

## 1.49.0 — 2026-11-10

- The signing report showed python3's signature is fine and grants
  `process.spawn`, yet the host still refuses its spawns. When it refuses,
  the host now writes what it saw — python3's entitlements now, at most, and
  from its signature — to `opt/python/.nyxian-spawn.txt`, and Nyxian Shell
  prints it ("what Nyxian saw").
- Notices are shown one at a time: "Node.js is ready" and "Java is ready"
  arriving together could freeze Nyxian. A notice that arrives while another
  is open, or while a screen is appearing or going away, now waits.

## 1.48.0 — 2026-11-10

- Still investigating why Nyxian Shell cannot start `node`, `java` (any
  program): the host refuses python3's spawn request. Now:
  - the host says whether python3's process was unknown (ESRCH) or lacks
    the `process.spawn` entitlement (EPERM), and logs it;
  - each time a terminal opens Nyxian writes `opt/python/.nyxian-signing.txt`:
    the result of signing each launcher's NXT2 entitlements and how Nyxian
    sees python3, node and java (NXT2 blob valid/signed/cdhash, trust level,
    may start programs). The Shell prints it when a program cannot start.
- Preparing Python shows each step after "Installing pip…" (writing files,
  checking packages, installing python3), so a stall shows where it is.

## 1.47.0 — 2026-11-10

- `node` and `java` still could not start from Nyxian Shell ("Operation not
  permitted"). The Shell now hands a program only stdin, stdout and stderr
  instead of every descriptor python3 has open (Nyxian sends each one to the
  new process).
- When Nyxian does not start a program it now says why: posix_spawn returns
  a telling error (signature/entitlements refused, LiveProcess did not
  start, ended right away, too many processes, process group) instead of
  always EPERM, and the reason is logged as `PEProcess:spawn`. The Shell
  prints the error number and the reason.

## 1.46.1 — 2026-11-10

- Java runtime build: the check that miniJVM's library exports minijvm_main
  no longer fails on its own (nm's output is read from a file).

## 1.46.0 — 2026-11-10

- **java in Nyxian Shell** said "could not start (Operation not permitted)".
  miniJVM is now a library (`opt/java/lib/libminijvm.dylib`) loaded by a
  tiny `java` launcher, the same way `node` loads Node.js; the library is
  signed like NodeMobile.
- Programs the Shell starts get python3's file sandbox: python3 may now also
  read `opt/node` and `opt/java`. Only its launcher is signed again (fast,
  once), Python is not unpacked again.
- When Nyxian does not let `java` or `node` start, the Shell says to try
  Reinstall Java / Node.js.

## 1.45.1 — 2026-11-10

- Java for iOS now compiles: the iOS build of miniJVM leaves out sljit (its
  JIT code generator), which miniJVM does not use on iOS and which did not
  compile for iOS.

## 1.45.0 — 2026-11-10

Java and .jar files:
- **miniJVM** comes inside Nyxian: a Java virtual machine written in C that
  interprets bytecode (on iOS its JIT is off). It runs offline in the
  terminal, with the Java 8 language and miniJVM's class library — a subset
  of the JDK, without Swing or AWT windows. It is prepared in the background
  after Python and Node.js.
- **▶ / ⌘R on a .java file** compiles it (javac: janino-continue) and runs it;
  files it writes come back to the project. Java is colored
  (tree-sitter-java). New example: Java (miniJVM).
- **Nyxian Shell**: `java FILE.java`, `java -jar APP.jar` (Main-Class and
  Class-Path from the manifest), `java -cp DIR CLASS`, `javac -d DIR FILES`,
  and `jar` (c/t/x/u with f, m, e, v and -C) to make, list, extract and
  update jars.
- **A .jar in Files** (tap or hold it):
  - **Run (java -jar)** with miniJVM.
  - **Run in Browser (CheerpJ)**: the full Java 8, 11, 17 or 21, chosen from
    the jar's classes, with Swing windows, in Nyxian's browser. It needs the
    internet (CheerpJ loads from its CDN; free for personal use).
  - **Open Contents** makes NAME.jar.contents to edit MANIFEST, resources and
    classes; hold that folder › **Pack into NAME.jar** (the previous jar is
    kept as .bak).
- Python panel › **Java**, java HOME folder, Reinstall Java.

## 1.44.0 — 2026-11-10

JavaScript and Node.js (tanda B):
- **Node.js 18** (nodejs-mobile, the standard iOS build: V8 **without JIT**)
  comes inside Nyxian with **npm** and corepack. It is unpacked and signed
  once, in the background after Python (once per update).
- **▶ / ⌘R on a .js, .mjs or .cjs file** runs it with node from a copy of the
  project; files it makes come back to the project. Run with Arguments
  (⌥⌘R), Shell in This Project and Node.js Console in the editor's menu.
  JavaScript is colored (tree-sitter-javascript).
- **Python panel › Node.js**: Node.js Console (REPL), Install Package (npm
  install -g, so `require()` finds it from any script), Installed Packages,
  the **node NODE_MODULES** and node HOME folders, Reinstall Node.js.
- **Nyxian Shell**: `node`, `npm`, `npx` (commands already installed),
  commands in `node_modules/.bin` and npm's global bin; any script with
  `#!` runs with its interpreter (node, python, sh); `sh FILE`, `source
  FILE` / `. FILE` with `$1 $2…`; `sh -c '…'`.
- Local servers printed as "listening at", "Local:", "Servidor en"… open in
  Nyxian's browser. Two examples: JavaScript (Node.js) and Servidor web.
- Limits (iOS): no JIT; `child_process` cannot start programs, so npm runs
  with `--ignore-scripts`; packages with native code (`.node`) do not load.

## 1.43.0 — 2026-11-10

- **Landscape**: console, shell, Python console and every other window now
  widen when you turn the iPhone or iPad sideways (title bar included); the
  windows are laid out again whenever the screen size or safe area changes.
- **iPhone key bar**: the top row of terminal keys scrolls sideways again,
  even when the slide starts on a key, so paste and the rest are reachable.
- **Your signing certificate comes with the private IPA**: the `-cert.ipa`
  in the private `ipa` release carries it, and Nyxian installs it on its
  own after a reinstall; if it doesn't match the app's profile, Nyxian asks
  for one as before. The public build never contains it.
- **No welcome screen** ("Welcome to Nyxian": Development,
  MobileDevelopmentKit…) after installing. Recovery › Settings › **Show
  welcome screen** brings it back, like the TeamWin boot splash.
- **turtle works**: `import turtle` draws in memory (iOS has no Tk window)
  and `done()`, `mainloop()`, `exitonclick()` or the end of the script shows
  the drawing as PNG, saved in `figures/`. New example: Tortuga (turtle).

## 1.42.0 — 2026-11-10

Python, like Python3IDE's main panel (tanda A):
- **Python panel** (tap **</>** on the project list; long press for the old
  menu): Python Console, **Modules** (packages, pip), Install Package,
  **Examples and Tutorials**, **Open Notebook (.ipynb)**, **Shell** in your
  home `$` or in Python HOME `$`, **ARGS** (every script's arguments: edit,
  clear), **Browser**, the **folders** Python and the compiler use (python
  HOME, SITE-PACKAGES, STDLIB, home, the iOS SDK as clang/swift SYSROOT,
  Projects), **About This Fork**, **What's New** and Reinstall Python.
- **Examples and Tutorials**: 12 ready Python projects with comments in
  Spanish — first steps, NumPy, pandas, matplotlib, SciPy, scikit-learn,
  notebook cells, the debugger, pytest, arguments and files, a Flask web
  page, Nyxian Shell. Picking one creates the project and opens its file.
- **Jupyter notebooks**: an `.ipynb` (in a project, or picked from Files)
  shows its cells with the outputs and plots it was saved with; **Run as
  Cells** turns it into a `.py` of `# %%` cells (markdown as comments) to run
  with ⌘↩; **Save as Notebook (.ipynb)** (edit/⋯ menu of a `.py`) writes it
  back, with the outputs and figures the cell console recorded.
- **Browser** inside Nyxian: opens by itself when Flask, Django or uvicorn
  say where they listen, and for `webbrowser.open()`; address bar,
  localhost:5000/8000 shortcuts, Safari, share; retries while a local server
  starts. **Flask and Django come bundled.**
- **About This Fork**: version, GitHub, builds, report a problem, your
  private backups, the original Nyxian, What's New (this list, inside the
  app) and sharing the kernel log.
- New Python projects show up in the Python section right away.

## 1.41.0 — 2026-11-09

- **Python is signed once, not every time it opens.** The date kept for
  each signed package binary was the one from *before* signing (a value the
  file URL had cached), so every start (Python console, Shell, cells, pip)
  found numpy, scipy, pandas… "changed" and signed them all again. Now the
  real date after signing is kept.
- Unchanged `site-packages` is not even scanned: a stamp of the folder says
  whether pip changed something since the last signing.
- **Prepared in the background when Nyxian opens**: unpacking/signing (only
  after a Nyxian update that brings a new runtime, or new packages) starts
  by itself a moment after the project list shows ("Preparing Python in the
  background…" / "Python is ready"); a window opened meanwhile shows its
  progress and waits for it instead of doing the work twice.
- The runtime is recognised by its checksum (written by CI), so a Nyxian
  update that brings the same Python no longer unpacks and signs it again.
  This update itself prepares Python one last time.

## 1.40.0 — 2026-11-09

Nyxian keeps building and running even if emexLabs' sites or GitHub
repositories go away:
- **LLVM-On-iOS is part of the fork** (it was a submodule of
  emexlab/LLVM-On-iOS; the same commit, `tools/fork/llvm-on-ios.commit`, so
  the toolchain cache stays valid). CI no longer fetches submodules
  (libroot and TrollStore are not used by the build).
- **Private backup repository** (default `doctoralvarez/nyxian-sdk`, secret
  `SDK_REPO_TOKEN`; `tools/fork/backup_asset.sh`): CI saves there, once per
  version, the built LLVM/Swift toolchain (5 hours to rebuild), the Python
  runtime and every build's IPA (artifacts expire after 90 days). When
  GitHub's cache is gone, CI takes them back from there before building
  anything.
- **Backups workflow** (weekly and by hand): a git bundle of the whole fork,
  of emexlab/Nyxian and emexlab/LLVM-On-iOS while they are reachable,
  emexLabs' public files (root CA key, TrustStore, OTA list) and the iOS
  wheels.
- **The app**: the emexLabs root CA key ships inside the app (CI puts it in
  `Shared/Backup`); the SDK zip and that key can be dropped into Files › On
  My iPhone/iPad › Nyxian and are used without any download.
- "Check upstream" ends fine (with a warning) when emexlab/Nyxian cannot be
  reached.

## 1.39.0 — 2026-11-09

- **Nyxian Shell** (</> › Shell, or ⋯ › Shell in This Project in a `.py`):
  a shell written in Python for Nyxian's terminal (iOS has no `/bin/sh`).
  Built-in `ls -la`, `cd`, `pwd`, `cat`, `head`/`tail`, `wc`, `grep -inrvlc`,
  `find -name -type`, `tree`, `sort`, `mkdir -p`, `rm -r`, `cp -r`, `mv`,
  `touch`, `echo`, `env`, `export`, `which`, `history`, `clear`, `help`;
  pipes `|`, redirection `> >> < 2> 2>&1`, `;` `&&` `||`, `$VARIABLES`,
  `~`, `*.globs`, quotes. Programs (`python3 file.py`, `pip …`, your command
  line tools) run as processes of their own joined by real pipes, with job
  control: **^Z** stops the program in front, `jobs`, `fg`, `bg`,
  `kill [-9] %n`, `cmd &`. In a project it works in its run copy; new files
  come back when it closes. python3 may now start processes (signed once
  more on its next start).
- **Python debugger** (⌥⌘D, or Debug in the edit/⋯ menu): runs the script
  and stops at the breakpoints set with ⌘\ (no Swift debugger needed); the
  stop line turns green in the editor and Show Variables (⌥⌘V) shows that
  frame's variables. In the terminal: `c` continue, `n` next, `s` step into,
  `r` return, `p`/`pp` expression, `l` list, `w` where, `u`/`d`, `b`,
  `locals`, `q`. An error that ends the script stops there too.
- **Quicker SwiftUI previews**: a preview first compiles only the Swift files
  the previewed file needs (the files that declare the types and functions it
  names, their extensions, and so on); if that build misses something, the
  whole project is built and that project is always previewed whole from
  then on.

## 1.38.0 — 2026-11-09

- **Two-finger selection in the file list**: slide two fingers down the
  files and folders of a project (as in Files or Mail) to select several at
  once; selection mode starts by itself and shows iOS's selection circles
  (Delete, Select All, Copy, Share as before). On iPad, Shift-click and
  ⌘-click with a trackpad or mouse also work.
- **Cell outputs, like a notebook** (⌥⌘O, or ⋯ › Cell Outputs in a `.py`):
  every cell run with ⌘↩ shows under the previous one — `In [n]`, its code,
  its output (errors in red) and the figures it made (tap one for Quick
  Look). Leave the sheet half open next to the code: while it is open the
  console window stays behind the editor and plots don't pop up.
- **Processes ↔ profiler**: Processes keeps the last minute of CPU and
  memory of every process (small CPU line in each row) and "Activity (CPU
  and Memory)…" shows it as live graphs; the profiler of a running app has
  "All Processes".

## 1.37.0 — 2026-11-09

- **Per-program permissions** (Settings → Management → Permissions, or
  Processes → a process → Permissions…): for an installed app, Python
  (python3) or any executable:
  - **Files**: *Nyxian default* (as the file system sandbox setting says),
    *Only what it declares* (its container and the folders its entitlements
    ask for, even with the sandbox off) or *All of Nyxian* (even with the
    sandbox on), plus extra **read-only** and **read-write** folders.
    Enforced by iOS's sandbox extensions the kernel hands the program.
  - **Network**: on/off. Off: IPv4/IPv6 `socket()`/`connect()` fail with
    "Operation not permitted" (local sockets keep working). A guard in the
    program's libc calls set when it starts, not a firewall.
  - Applied when the program starts; programs it starts follow it. "Restart
    It Now" ends it so the next start uses them. The kernel log notes them.

## 1.36.0 — 2026-11-09

- **Processes** (Settings → Management → Processes): every process of
  Nyxian's kernel with its PID, parent, group, state (running, stopped,
  zombie), CPU, memory, threads and run time, updated every second; search,
  sort by PID/CPU/memory/name, pause updates. Tap one to stop (SIGSTOP),
  continue, interrupt, terminate or kill it (swipe: Stop/Continue, Kill);
  PID 1 (launchd) asks first.
- **Kernel Log** (Management → Kernel Log (kmsg)): what the kernel logs, of
  this launch (live, follows the end) or of the previous one (to see why it
  crashed); filter lines, errors in red, copy, share as a file.
- **Job control** in terminal windows: ^Z stops the program
  (`[1]+ Stopped`) and the window takes commands: `fg` continues it here,
  `bg` in the background (its output still shows), `jobs`, `kill [-9]`,
  `exit`, `help`; ^Z stops a job in the background again. A program stopped
  or continued from Processes is noticed too.

## 1.35.0 — 2026-11-09

- **Real terminal line discipline** (canonical mode, as on macOS/Linux): a
  program that reads lines (C `scanf`/`fgets`, Swift `readLine()`, Python
  `sys.stdin.readline()`, pip's "Proceed (Y/n)?") now **shows what you type**
  and lets you edit it before Enter: ⌫ erases a character (a whole ñ/á/€),
  ^W a word, ^U the line, ^R shows it again, ^V types the next key as it is.
  **^D on an empty line ends the input** (`read()` returns 0, `EOFError` in
  Python); with text, it hands it over without Enter. ^C/^Z/^\ show as ^C…
  and drop the half-typed line.
- Programs that read keys one by one turn it off as usual (`tcsetattr`,
  raw mode); Nyxian's Python REPL and `input()` do so, so they behave as
  before. Without canonical mode nothing changed (^U still kills).
- CI tests the line discipline (30 cases) and the Python terminal now starts
  in canonical mode, as in the app.

## 1.34.0 — 2026-11-09

- **Variable inspector** (⌥⌘V, Show Variables): the variables of the
  project's cell console — name, type, size/shape, dtype and value — updated
  after every cell; tap one to see it whole (DataFrames and arrays keep their
  columns and scroll both ways; share the text). The sheet can stay half open
  next to the code.
- **Python linter**: pyflakes (bundled) marks unused imports and variables,
  misspelled or undefined names, `return` outside a function… while you type
  (undefined names in red, the rest in orange).
- **Run Tests** (⌘U): pytest (bundled; unittest otherwise) on a `test_*.py`
  file or on the whole project, in a terminal; each failed test marks its line
  in the editor and a notice gives the count.
- **Run with Arguments** (⌥⌘R): arguments as in a shell, remembered per file
  (⌘R / ▶ use them too, shown in the window title); "Add a File of the
  Project…" puts a project file's path in them.

## 1.33.1 — 2026-11-09

- **Crash with a template named "ObservableObject"**: the class inherited from
  itself (`final class ObservableObject: ObservableObject`) and the Swift
  compiler, which checks the code inside Nyxian, crashed — and again at every
  launch, as the tab reopened. Now:
  - templates named like a system type get a suffix (`ObservableObjectModel`);
  - a type that inherits from itself is found before the compiler is asked,
    and marked on its line, in every file of the project;
  - if Nyxian ever closes while checking a project, live checking of that
    project is paused for the next session (building still shows errors).

## 1.33.0 — 2026-11-09

- **Your own copy of the iOS SDK as the bootstrap's backup**: after two failed
  tries at nyxian.app, Nyxian downloads `iPhoneOS27.0.sdk.zip` from the
  "ios-sdk" release of your (private) GitHub repository — Settings ›
  Customization › **SDK Backup** (owner/repo, default
  `doctoralvarez/nyxian-sdk`) and **GitHub Token** (read access to it).
- **iOS SDK backup** workflow (`.github/workflows/ios-sdk.yml`, run by hand):
  takes the SDK from GitHub's Xcode 27 runner (27.0 when installed), zips it
  like nyxian.app's and uploads it to that private release; it refuses a
  public repository (the SDK is Apple's).
- Downloads can carry headers (a token) and a number of attempts; the token
  is dropped when GitHub sends the file to another host.

## 1.32.1 — 2026-11-08

- **Bootstrap downloads that survive a bad connection** (the iOS SDK after a
  fresh install): up to 6 attempts with pauses, each one resuming where the
  last stopped instead of starting over, waiting while the network is gone,
  and only an HTTP 2xx answer counts. The error now says why it failed.
- **A failed bootstrap no longer deletes everything**: the steps already done
  stay, and the failed step is tried again by itself after 30 s (5 times).
  Before, a failure reset the bootstrap to zero and builds waited forever for
  it — likely the cause of ▶ hanging the first time after reinstalling.

## 1.32.0 — 2026-11-08

- **Rename Symbol (⌃⌘E) by meaning in Swift**: every match of the name in the
  project is checked with the compiler, and only the references to the very
  symbol under the caret are renamed — another symbol with the same name, a
  comment or a string stays as it is (the dialog says how many; "Rename Every
  Match" is still there). C, Objective-C and Python keep the whole-word rename.
- **Format Document (⌃I)** for Swift: the file's own indentation (spaces or
  tabs), SwiftUI modifier chains one level in, `case` aligned with `switch`,
  spaces in `if(`, `){`, `}else`, `else{` and after commas, no trailing
  spaces, at most one blank line in a row; strings and comments untouched.
  Python files: trailing spaces, tabs in indentation and blank-line runs.
  Tested by CI.
- **New › From Template**: SwiftUI View, List and Detail, Observable Model
  (ObservableObject), Codable Model (JSON load/save), Python Script, Python
  Notebook (# %% cells), Python Module.
- **Live SwiftUI preview**: after ⌥⌘P, saving the file (⌘S) builds and shows
  the preview again by itself; ⇧⌥⌘P stops it.

## 1.31.0 — 2026-11-08

- **Python comes with the science pack installed**: numpy, scipy, pandas,
  matplotlib and scikit-learn (with their dependencies) are part of the
  runtime inside the app — nothing to download after installing or
  reinstalling Nyxian. On an update they join the packages you already have,
  once, never over a version you installed yourself, and not again after you
  uninstall one.
- **Faster first imports**: the standard library and the bundled packages
  ship compiled to bytecode (by CI, CPython 3.14, unchecked-hash .pyc), so the
  device does not compile them the first time; `PYTHONPYCACHEPREFIX` is gone.
- Bundled binaries are signed once while unpacking, not again afterwards.

## 1.30.0 — 2026-11-08

- **scipy and scikit-learn for Python on iOS**: pip also looks in Flet's index
  of mobile wheels (`pypi.flet.dev`, which has scipy 1.18 built for iOS and
  CPython 3.14 — with a Fortran compiler and Accelerate), and the fork's
  "iOS wheels" CI copies those wheels onto its own release so Nyxian does not
  depend on that site.
- **Install Science Pack** (Packages › +): numpy, scipy, pandas, matplotlib and
  scikit-learn in one go.

## 1.29.0 — 2026-11-08

- **Python cells, like a notebook**: in a `.py` file, `# %%` lines split it
  into cells. **Run Cell** (⌘↩, the ▶︎□ key, or the edit menu) runs the cell
  the caret is in — or the selection — in the project's **cell console**, a
  Python console that stays open: variables, imports and data stay from one
  cell to the next; the caret goes on to the next cell. **Run File in
  Console** (⇧⌘↩) runs the whole file there. Plots open as with `plt.show()`.
- **Python packages** (`</>` › Packages…): what is installed, with version and
  summary, search; swipe (or tap) to upgrade or uninstall; + installs a
  package or a requirements.txt. A `requirements*.txt` open in the editor
  has **Install with pip** in its edit menu.
- **iOS wheels CI**: one run builds several packages (pandas, scipy…),
  skips those that already have an iOS wheel for CPython 3.14, and goes on
  when one fails.

## 1.28.0 — 2026-11-08

- **Faster Swift builds** (as fast as Nyxian's own again): the cross-import
  overlays are loaded only for projects whose code uses one (SceneView,
  SpriteView, Map, VideoPlayer…), and line-table debug info is made only with
  the debugger on. The debugger is now **off by default** (Settings ›
  Customization › Debugger); setting a breakpoint with it off says so. Turning
  it on or off rebuilds the project once.
- **Cancel** (top left, red) while a project builds: the screen is yours at
  once, the build stops before its next stage, nothing is installed or run,
  and what was already compiled is kept for the next build.

## 1.27.0 — 2026-11-08

- **`plt.show()` shows the figures**: Nyxian's matplotlib backend
  (`nyxian_mplbackend`) saves the open figures as PNG in `figures/` and the
  terminal opens them in a preview right away (swipe between several); in
  the console as well as in scripts. The PNGs come into the project when the
  run ends.
- **Python completion with jedi**: suggestions of modules, functions and
  attributes — after `np.`, `os.`… too — with the signature and the first
  line of the documentation. jedi and parso ship inside the runtime
  (`lib/nyxian`, apart from pip's packages) and run in a python3 without a
  window (`nyxian_jedi`).
- **Errors marked in the editor**: syntax errors and warnings of `.py` files
  are marked on their line while you type (from Python's own compiler), and
  when a run ends with an error its line is marked (and, on iPad, the file
  opens there). The mark goes when you edit the file.

## 1.26.0 — 2026-11-08

- **Plots and other files from Python scripts come into the project by
  themselves** when a run ends (listed in the terminal: "copied to the
  project: seno.png …"); a file the script writes again (a new plot) replaces
  the old copy. `.py` files are never overwritten.
- **Preview of pictures and documents**: tapping a PNG/JPG/PDF/SVG/video…
  in the file list opens Quick Look (share, save to Photos, mark up) instead
  of the text editor.
- "Copy Python Output to Project" is also in the editor's ⋯ menu on iPhone.

## 1.25.0 — 2026-11-08

- **Landscape**: iPhone now turns to landscape too (iPad already did).
  Settings › Customization › **Orientation**: Automatic, Portrait or
  Landscape — Landscape keeps Nyxian in landscape on iPhone, whose system
  lock only locks portrait. On iPad the system rotation lock keeps the
  current orientation.
- **pip / Python launch**: new binary modules of installed packages are
  signed file by file with the progress saved, and a file Nyxian was signing
  when it closed is skipped from then on — a binary that makes signing fail
  can no longer make every Python launch fail. pip starts once its prompt has
  gone, and the progress alert is never presented from another alert.
- **Packages survive Nyxian updates**: unpacking the runtime again (every
  update) used to delete `site-packages`; it is now kept and its binaries are
  signed again.

## 1.24.0 — 2026-11-08

- **"Python" project template** (New Project › Python, suggested name
  "Pythons"): a project of Python scripts — no app to build. It starts with
  `main.py`; add more with New › File (`name.py`). It has its own **Python**
  section in the project list. ▶ / ⌘R (iPad) and Run (iPhone) run the `.py`
  on screen (else `main.py`) instead of building. Made as a command line tool
  project without sources plus a marker (`Config/.nyxian-python`).

## 1.23.0 — 2026-11-08

- **Projects in Apple's Files app**: `UIFileSharingEnabled` and
  `LSSupportsOpeningDocumentsInPlace` on. Files › On My iPhone/iPad › Nyxian ›
  Projects. Project folders are named by UUID: **Project Names.txt** (next to
  Projects) says which is which, and **Show in Files** in a project's menu
  opens Files right at its folder.
- **Running a .py file** from the editor: the project is copied to its run
  folder in the background (files compared by size/date and copied without
  reading them into memory; build folders and files over 100 MB left out),
  the editor's keyboard is closed first and the progress alert is shown from
  the top screen.
- **pip at the first try**: pip runs through `nyxian_pip`, which says at once
  that it started, shows "still working (N s)" when pip prints nothing for a
  while, and after 3 silent minutes prints where pip is waiting. The Python
  console compiles pip once in the background, so the first install does not
  spend minutes on it.
- **Editor bar on iPhone**: tab, undo/redo, ▶ (Python) and hide keyboard stay;
  fix, breakpoint, symbols and find go into a ⋯ menu (hide keyboard was cut
  off).

## 1.22.0 — 2026-11-08

- **matplotlib for Python on iOS**: there is no matplotlib wheel for
  CPython 3.14 on iOS on PyPI or BeeWare's index, so this fork builds it:
  `.github/workflows/ios-wheels.yml` (cibuildwheel, `--platform ios`)
  publishes matplotlib 3.11.2 on the **ios-wheels** release, and Nyxian's pip
  looks there (`PIP_FIND_LINKS`). Its dependencies come from BeeWare's index
  (kiwisolver, contourpy) and PyPI (pillow, numpy and pure-Python ones).
- **Binary packages load** (numpy, matplotlib, pillow…): wheels for iOS link
  `@rpath/Python.framework/Python`; libpython now has that install name and
  an rpath to `Frameworks/`, where Nyxian links `Python.framework/Python` to
  it. The runtime changes, so Python is unpacked again on first use:
  packages installed before have to be installed again.
- **Key bar**: symbol keys have one width (paste was very wide on iPhone),
  the fixed keys don't stretch, and the bar has a fixed height (it sometimes
  came back with none and did not show).

## 1.21.8 — 2026-11-08

- **Pasting code into the Python console**: the console asks the terminal to
  mark pastes (bracketed paste), so a pasted block arrives whole. It is
  cleaned — line ends of any kind (CR LF included), non-breaking and other
  look-alike spaces from web pages and chats, zero-width characters, curly
  quotes, tabs in the indentation, indentation common to all lines — shown
  with `... `, and run statement by statement, like Python 3.13's REPL: blank
  lines inside a `def` and code right after a block work, and the values of
  expressions are shown. A one-line paste is inserted for editing. The key
  bar's paste key works the same way.
- **Python font**: 24 pt on iPad, 18 on iPhone by default (sizes saved
  earlier are not kept).

## 1.21.7 — 2026-11-08

- pip no longer warns "The script … is installed in …/opt/python/bin which is
  not on PATH": that folder is now on `PATH` in Python windows (with and
  without `/private` in front, since pip compares the paths as text).

## 1.21.6 — 2026-11-08

- **pip install works**: pip also writes command scripts to `opt/python/bin`
  (and data to `share/`, `include/`), where python3 was not allowed to write
  ("Operation not permitted: …/opt/python/bin/idna"). python3 may now write
  all of `opt/python`. Python is unpacked and signed once more on the first
  launch after updating.

## 1.21.5 — 2026-11-08

- **Python Console closes with Ctrl-D / `exit()`** (the window used to stay
  open showing "process exited"). Other terminal windows say how to close
  them: any key, or the new ✕.
- **Key bar, much fuller and scrollable sideways**: esc, tab, ⏎, ^C, ^D ·
  ← ↓ ↑ →, home, end · paste, clear, page up/down, A−/A+ (font size) ·
  ^A ^E ^K ^W ^Z ^\ · `( ) [ ] { } < > = + - * / \ | _ : ; ' " # ~ ` ! ? @ $ % & ^ .`
  Fixed on the right: hide keyboard and a red **✕ that closes the window**.
- **Bigger font in Python windows**: 30 pt on iPad, 22 on iPhone (a bit more
  than twice before). Change it in Settings → Customization → **Python Font
  Size**, or with A−/A+ in the key bar (saved).
- Python line editor: ← → move the cursor inside the line, home/end and
  Ctrl-A/Ctrl-E jump, Ctrl-K erases to the end, Ctrl-W erases a word,
  Ctrl-L clears the screen.

## 1.21.4 — 2026-11-08

- **Python Console: blocks of several lines** — after a line ending in `:`
  (`for`, `if`, `def`…) the next line starts already indented; an empty Enter
  ends the block; ⌫ on the indentation removes a whole level. Pasted blocks
  keep their own indentation. Curly quotes from the keyboard become straight.
- **Terminal above the keyboard**: every Nyxian terminal now ends where the
  keyboard (and its key bar) starts, so the line being typed is visible and
  older output can be scrolled. Before, the terminal ran behind the keyboard.
- **ñ, accents, ¿ ¡ in terminals**: the terminal stripped the 8th bit of each
  byte (ISTRIP), which mangled every non-ASCII character. Now off.

## 1.21.3 — 2026-11-07

- **Python Console: Enter runs the line** — robust terminal I/O:
  `sys.stdout`/`sys.stderr` write straight to Nyxian's terminal, the REPL
  writes results and errors itself and flushes after every line, Enter
  accepts CR, LF or CR LF.
- **⏎ key** in the key bar above the keyboard (sends Return), as a second way
  to enter a line.
- **Python Keyboard Test** (menu `</>`): shows the code of every key Python
  receives — to find a key that seems to do nothing.
- **Ctrl-\\** in a Python terminal prints where Python is stuck (faulthandler).
- CI runs the REPL in a pseudo terminal configured like Nyxian's, with
  Python 3.14 (`tools/fork/test_python_terminal.py`).

## 1.21.2 — 2026-11-07

- **Python installs again (and on the first try)**: the installing service
  can refuse the launcher's first signature — a second full install used to
  work because it signed everything again. 1.21.0 retried with the same
  signature, so every retry failed. Now the launcher is signed last, from a
  pristine copy, and signed again from that copy before each retry.

## 1.21.1 — 2026-11-07

- Build fix for 1.21.0 (string literal delimiters).

## 1.21.0 — 2026-11-07

- **Python Console that answers**: Nyxian's terminal passes keys raw (no echo,
  no line editing), so the built-in Python REPL showed nothing. The console now
  runs Nyxian's REPL (`nyxian_repl`): what you type is shown, ⌫ deletes, ↑↓
  history, Tab indents, Ctrl-C interrupts, Ctrl-D / `exit()` quits. `input()` in
  scripts echoes too (`sitecustomize`).
- **Python installs on the first try**: installing the launcher is retried up
  to 5 times (the first request after launch could miss the 2-second answer).
- **New key bar above the keyboard** in every Nyxian terminal: esc, tab,
  Ctrl-C, Ctrl-D, arrows and a button that **closes the keyboard** (SwiftTerm's
  button switched to its own key panel instead).

## 1.20.1 — 2026-11-07

- **Python: "cannot load libpython … blocked by sandbox" fixed.** With
  Nyxian's Filesystem Sandbox (on by default) a utility only reaches the paths
  its NXT2 entitlements list, and the python3 launcher was signed without any.
  It now gets read access to `<rootfs>/opt/python` and read-write to
  site-packages (pip) and `<rootfs>/var/mobile` (home, run folders). The
  runtime is signed again automatically on the next Python start.

## 1.20.0 — 2026-11-07

- **Python packages with native code**: pip also searches BeeWare's index of
  iOS builds (`pypi.anaconda.org/beeware/simple`, the one Briefcase uses), so
  numpy, Pillow and others install when an iOS build exists; every new binary
  module pip writes to site-packages is signed before the next Python run.
- **matplotlib**: `MPLBACKEND=Agg`, so `plt.savefig("plot.png")` works.
  **Copy Python Output to Project** (⇧⌘R, or the edit menu of a `.py`) brings
  the files a script created (plots, CSV…) into the project — scripts run in a
  copy of the project inside Nyxian's rootfs.
- New `.py` files start with a `#` header.
- CI: the Python runtime is the real one again (1.19.x packed the whole
  checkout by mistake — 443 MB IPA); the zip size is checked.

## 1.19.2 — 2026-11-07

- Build fix for 1.19 (terminal session initializer).

## 1.19.1 — 2026-11-07

- Python files get **syntax colors** (tree-sitter-python 0.23.6).
- CI: the Python packing script finds the standard library, `lib-dynload` and
  libpython inside BeeWare's support package instead of assuming paths.

## 1.19.0 — 2026-11-07

- **Python 3.14** (CPython for iOS, the official PEP 730 build packaged by
  BeeWare; the CI packs it as `Shared/python-ios.zip`, cached):
  - Projects screen > **</> menu**: *Python Console* (the `>>>` REPL in a
    terminal window), *Install Package (pip)…*, *Reinstall Python Runtime*.
  - In the editor, a `.py` file runs with **⌘R** or the play button: its
    project is copied to Nyxian's rootfs (where utilities may read) and the
    script runs there in a terminal window.
  - First use unpacks the runtime into `<rootfs>/opt/python`, signs every
    binary with your certificate, and installs **pip** from ensurepip's wheel.
    Pure-Python packages install from PyPI; packages with native code (numpy,
    pandas…) need iOS builds — next phase.
  - Word completion knows Python keywords and builtins.
- Terminal windows accept arguments, environment, working directory and
  a title (`NXWindowSessionTerminal`).

## 1.18.1 — 2026-11-07

- Framework + SwiftUI overlays back on now that `@State` is fixed:
  `SceneView` (`_SceneKit_SwiftUI`), `SpriteView` (`_SpriteKit_SwiftUI`), `Map`,
  `VideoPlayer`, StoreKit views, `SignInWithAppleButton`, `PhotosPicker`… —
  `-enable-cross-import-overlays` as in Xcode, plus an explicit import of the
  overlays the code uses when the SDK has them.

## 1.18.0 — 2026-11-07

- **@State works with the iOS 27 SDK**: that SDK declares `@State` as a macro
  in SwiftUICore (`SwiftUIMacros.StateMacro`) alongside the `State` property
  wrapper; the macro wins name lookup and its plugin
  (`libSwiftUIMacros.dylib`) only ships inside Xcode — the same failure
  Command Line Tools builds on the Mac have. On launch, Nyxian renames that
  macro once in its own copy of the SDK (SwiftUI / SwiftUICore interfaces) and
  clears the cached SwiftUI modules, so `@State` is the property wrapper again
  (what SDK 26.5 and earlier had). Your code does not change.
- The overlay experiments of 1.17.0–1.17.3 were not the cause; Nyxian stops
  at the first failing file, which is why this only surfaced now.

## 1.17.4 — 2026-11-07

- **@State fixed for real**: the framework + SwiftUI overlays of the iOS 27
  SDK themselves (`_SpriteKit_SwiftUI`, `_SceneKit_SwiftUI`, …) turn `@State`
  into a macro that needs Xcode's `SwiftUIMacros` plugin. 1.17.3 still loaded
  them when the code mentioned `SpriteView` / `SceneView`. Nyxian no longer
  loads any overlay (as up to 1.16). Use `SKView` / `SCNView` in a
  `UIViewRepresentable` instead of `SpriteView`.

## 1.17.3 — 2026-11-07

- **Fix for 1.17.0**: turning on every cross-import overlay broke `@State`
  ("external macro implementation type 'SwiftUIMacros.StateMacro' could not be
  found"): an iOS 27 SDK overlay makes `@State` a macro whose plugin only ships
  with Xcode. The global flag is gone; Nyxian now imports only the overlays the
  project's code uses, when the SDK has them: `SpriteView` → `_SpriteKit_SwiftUI`,
  `SceneView` → `_SceneKit_SwiftUI`, `Map`/`Marker` → `_MapKit_SwiftUI`,
  `VideoPlayer` → `_AVKit_SwiftUI`, StoreKit views, `SignInWithAppleButton`,
  `quickLookPreview`, `PhotosPicker`.

## 1.17.2 — 2026-11-07

- `Package.swift` (and `Package@swift-*.swift`, `.swiftpm/`, `.build/`) inside
  a project is no longer compiled as app code. It only describes a Swift
  package and imports `PackageDescription`, which apps do not have ("no such
  module 'PackageDescription'"). The file stays in the project, so exporting
  or pushing it keeps working.

## 1.17.1 — 2026-11-07

- Build fix for 1.17.0 (debugger nullability).

## 1.17.0 — 2026-11-07

- **Debugger** (attached to every Run and Preview; Customization > Debugger):
  - **Pause / Continue** (button left of the profiler pill, or ⌃⌘Y): every
    thread with its backtrace — app frames with function names (Swift
    demangled) and file:line; tap a frame to open it.
  - **Breakpoints**: ⌘\ or the breakpoint button in the editor toolbar
    toggles one on the caret's line (tinted blue). Up to 6 at a time — they use
    the CPU's hardware breakpoint registers (iOS does not allow patching app
    code). When one is hit the app stops, the line turns green and the stop
    sheet opens; Continue goes on.
  - Swift runtime errors (traps) stop in the debugger too; Continue then lets
    the app crash as before.
  - Variables are not shown (that needs a full LLDB).
- Builds now carry line tables (`-gline-tables-only`), so the first build of
  each project recompiles everything once.
- **Cross-import overlays on**: `SpriteView`, `SceneView` and the other
  framework + SwiftUI overlays are found (Swift flag
  `-enable-cross-import-overlays`, added to every project).

## 1.16.0 — 2026-11-07

- **Git**: ⋯ > GitHub > **Branches…** (list, create from the current state,
  switch — needs no unpushed changes) and **History** (commits of the branch;
  tap one for its files with +/− and the patch). In *Commit and Push…* swipe a
  file to **Discard** it (back to the last sync; new files are deleted).
- **Export assistant**: Export (iPad archive button, iPhone ⋯ > Export) first
  shows version and build number (with "+1"), and checks: bundle identifier,
  app icon, and permissions the code uses without a usage description (one tap
  adds it), background tasks. Then it builds the .ipa (not signed for
  distribution — sign it externally).
- **Profiler**: a pill over the console (iPad) and in the iPhone Console
  window shows CPU, memory and threads of the running app every second; tap it
  for the last minute as graphs.
- **Metal shaders**: every `.metal` file is copied into the app and joined as
  `NyxianShaders.metal`; ⋯ > **Add Metal Helper** writes
  `MetalLibrary+App.swift` (`device.makeAppLibrary()`: Xcode's compiled
  library, or the sources compiled on the device) and a sample `Shaders.metal`.
- **SwiftUI Preview** (⌥⌘P or the edit menu in a Swift file): builds a copy of
  the project whose app shows only the chosen `#Preview` / `PreviewProvider`
  (`@Previewable` supported) and runs it as "<App> Preview". It is a full
  build, not a live canvas.

## 1.15.0 — 2026-11-07

- **Jump to Definition** now also in Swift files, with **⌃⌘J** (and the edit
  menu as before). SDK symbols say which module defines them.
- **Find References** (**⇧⌃⌘F**, or the edit menu): every whole-word match in
  the project's files of the same language; in Swift each match is checked by
  the compiler (same symbol, not only the same name). C/Objective-C results
  are text matches.

## 1.14.1 — 2026-11-07

- Build fix for 1.14.0 (console view initializer).

## 1.14.0 — 2026-11-07

- **Document Symbols** (⌃6, or the list button in the editor toolbar):
  functions, types, properties, enum cases and `MARK` sections of the file
  (Swift, C, C++, Objective-C), filterable; tap to jump.
- **Recent tabs** (iPad): ⌃⇥ goes to the previously used tab (again to come
  back), ⌃⇧⇥ to the least recently used one.
- **Faster Swift rebuilds**: when no Swift file changed since the last build
  (and the flags are the same), the Swift compiler is skipped and only the
  link runs. Any Swift change still recompiles all Swift files.
- **iPhone console**: the app's `print()` output goes to a **Console** window
  (project ⋯ menu > Console) that lives next to the app in the window
  switcher — no new edge gestures.
- **GitHub: review before pushing**: *Commit and Push…* first lists the files
  modified / added / deleted since the last sync with +/− line counts; tap a
  file for its line diff, then *Commit…*.
- Code folding is not included: the editor engine (Runestone) cannot hide
  lines.

## 1.13.0 — 2026-11-07

- **App icons**: importing a `.swiftpm` turns its `AppIcon` into a real icon
  (loose PNGs + `CFBundleIcons`, no asset catalog compiler needed);
  long-press a project > **Set App Icon…** for any project; the project list
  shows the icon; exporting writes `AppIcon.appiconset` and
  `appIcon: .asset("AppIcon")`.
- **Permissions**: `capabilities` with a `purposeString` (camera, photos,
  location, microphone, contacts, calendars, Face ID, Bluetooth…) become
  Info.plist usage descriptions on import, and go back to `capabilities` on
  export (the original block is reused when the project came from a package).
- **Update from .swiftpm…** (long-press a project): re-imports a package into
  the existing project, replacing its Swift files.

## 1.12.0 — 2026-11-07

- **No TeamWin splash on launch**: normal launches show a plain background
  while the IDE loads. Recovery > Settings > *Show TeamWin boot splash* brings
  the image back; verbose boot still shows its console.
- **Faster launch**: when booting the bundled IDE with a TrustStore already
  installed, the TrustStore check runs in the background instead of holding
  the launch for up to 4 seconds. The 1-second volume-button window stays, as
  it is the way into Recovery.

## 1.11.2 — 2026-11-07

- **.swiftpm export fix**: Swift Playgrounds rejected the manifest
  ("PlaceholderIcon has no member 'gear'"). The default icon is now `.leaf`.
- Imported `.swiftpm` apps keep their original manifest in
  `Config/SwiftPlaygrounds-Package.swift.txt`; exporting them back reuses its
  placeholder icon and accent color. (Projects imported before 1.11.2 use the
  defaults.)

## 1.11.1 — 2026-11-07

- **Link fix** for apps whose display name differs from the executable name
  (typical of imported `.swiftpm` apps, e.g. "ZCS Explorer" / `ZCSExplorer`):
  the linker wrote into `Payload/<display name>.app`, but the builder only
  creates `Payload/<executable>.app` ("failed to open … No such file or
  directory"). `-[NXProject machoURL]` now redirects into the real bundle, so
  already-imported projects work without re-importing; new projects and the
  importer use `$(NXExecutable).app`.

## 1.11.0 — 2026-11-07

- **Export as Swift Playgrounds App (.swiftpm)**: long-press a project, or
  swipe it right > Export. Writes `Package.swift` (`.iOSApplication`, target
  `AppModule`, path `.`), copies the Swift files with their folders, turns loose
  images (`name.png`, `name@2x.png`…) into `Assets.xcassets` image sets, puts
  other resources in `Resources/` and saves the package with "Export to Files".
  It warns about C/Objective-C files (left out), a missing SwiftUI `@main App`,
  `Bundle.module`, and usage descriptions to re-add in App Settings.
- **Swipe actions in the project list**: swipe left for **Delete** (asks
  first), swipe right for **Export** (Nyxian `.zip` or `.swiftpm`).

## 1.10.0 — 2026-11-07

- **GitHub sync** without a git binary (REST "Git Data" API):
  - ⋯ > **GitHub** in a project: *Commit and Push…*, *Pull*, *Repository…*
    (owner/repo + branch) and *Account…* (personal access token, kept in the
    Keychain of this device only).
  - Push refuses when GitHub has commits the project does not have (pull
    first). The first push into an existing branch keeps the files that only
    exist on GitHub.
  - Pull never overwrites a file you changed since the last sync (it is
    reported as a conflict) and only deletes local files you did not touch.
  - The sync state lives in `Config/GitHub.plist`, which is never pushed.
- **Clone from GitHub…** in the import button of the Projects screen: a Nyxian
  project is downloaded and stays linked; a Swift Playgrounds app
  (`Package.swift`) is converted like an imported `.swiftpm`.

## 1.9.1 — 2026-11-07

- Build fix for 1.7.0: `MDKFile.fileURL` is optional in Swift; the open-tabs
  registry and Rename Symbol now unwrap it.

## 1.9.0 — 2026-11-07

- **Fix-its**: **⌥⌘↩** (or the new wrench button in the editor toolbar) applies
  the compiler's suggested fix for the caret's line (a list when there are
  several); **⌃⌥⌘F** applies every fix in the file after a confirmation. The file
  is re-checked first so the positions match what is on screen; the result is
  a single undoable edit.
- Fixes come from Clang's stored diagnostics and from Swift's
  `DiagnosticInfo::FixIts` (`CCASTUnitCopyFixIts`, `-[MDKASTUnit fixIts]`,
  `-[NXLanguageServer getFixIts]`).

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
