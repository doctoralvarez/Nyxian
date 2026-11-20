# Fork doctoralvarez/Nyxian — version 0.2.3
# Changelog:
#  - 0.2.3 (2026-11-19): the bridge functions return TRUE, not rpy2's NULL
#    (plots showed "ValueError: rternalized … NULLType" after opening).
#  - 0.2.2 (2026-11-19): R starts with no default packages (its own attempt
#    printed "package 'utils' … was not found") and nyxian_r attaches them
#    right after, quietly.
#  - 0.2.1 (2026-11-19): downloads verify HTTPS with certifi's certificates
#    (pip's own copy if certifi is not installed): Python on iOS has no
#    system certificate store, so every download failed and install.packages
#    offered to build packages that were already built. Only a real "not
#    found" (404) offers a build; other errors are shown. R's libcurl gets
#    the same certificates.
#  - 0.2.0 (2026-11-19): install.packages(): the package and the
#    dependencies it lacks (Depends/Imports from each DESCRIPTION), built for
#    iOS, from the ios-r-packages release; R's user library is
#    site-packages/nyxian_r_library, where Nyxian signs binaries as it does
#    pip's (it offers a fresh window, as after pip); packages not built yet
#    are offered for building (ESC ] 7770 ; nyxian-build ; rpkg;0;names).
#  - 0.1.5 (2026-11-19): the C shell hook is set before R starts; default
#    packages startup missed (utils, stats) are attached after it.
#  - 0.1.4 (2026-11-19): R's errors and warnings printed as R prints them.
#  - 0.1.3 (2026-11-19): R's start-script environment given directly (rpy2
#    ran Rscript, a process, to read it).
#  - 0.1.2 (2026-11-19): rpy2 3.6 starts R with initr() (initr_simple is
#    gone); no LD_LIBRARY_PATH lookup through Rscript (a process).
#  - 0.1.1 (2026-11-19): tells rpy2 where libR is on iOS itself (whichever
#    rpy2-rinterface wheel pip picks).
#  - 0.1.0 (2026-11-19): R for iOS inside Nyxian's Python (rpy2, ABI mode).
#    start() opens R once per process (R_HOME is the R/ folder next to this
#    file) and gives R the bridge its Rprofile.site uses for what R would run
#    as other processes: .nyxian_shell (Nyxian Shell in this process, also
#    behind C's system()/popen() through R_nyxian_shell), .nyxian_which,
#    .nyxian_open (Nyxian's browser), .nyxian_preview (plots), .nyxian_install
#    (R packages built for iOS) and .nyxian_quit.
"""R for iOS in Nyxian: `import nyxian_r; nyxian_r.start()`, or `python3 -m nyxian_r`."""
import ctypes
import os
import shlex
import shutil
import sys
import tempfile

__version__ = "4.6.2"
HOME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "R")
# R packages go next to Python's: Nyxian signs the binaries it finds in site-packages
LIBRARY = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "nyxian_r_library")
RELEASE = "https://github.com/doctoralvarez/Nyxian/releases/download/ios-r-packages"

_started = False
_quit = [None]
_keep = []  # callbacks R holds on to


def _escape(kind, text):
    """Asks Nyxian's terminal for something (ESC ] 7770 ; kind ; text BEL)."""
    try:
        os.write(1, ("\x1b]7770;%s;%s\x07" % (kind, text)).encode("utf-8"))
    except OSError:
        pass


# ---------------------------------------------------------------- the bridge

def shell(command, stdin_text=""):
    """Runs a command line in Nyxian Shell here; returns (status, output)."""
    try:
        import nyxian_shell
    except ImportError:
        return 127, "R: Nyxian Shell is not available\n"
    infile = None
    line = command
    if stdin_text:
        infile = tempfile.NamedTemporaryFile("w", delete=False, suffix=".txt")
        infile.write(stdin_text)
        infile.close()
        line = "%s < %s" % (command, shlex.quote(infile.name))
    with tempfile.TemporaryFile() as out:
        sys.stdout.flush()
        sys.stderr.flush()
        saved = os.dup(1), os.dup(2)
        os.dup2(out.fileno(), 1)
        os.dup2(out.fileno(), 2)
        try:
            status = nyxian_shell.run_line(line)
        except SystemExit as stop:
            status = stop.code if isinstance(stop.code, int) else 0
        except Exception as error:  # the shell's own failure, as its output
            os.write(2, ("%s\n" % error).encode())
            status = 1
        finally:
            sys.stdout.flush()
            sys.stderr.flush()
            os.dup2(saved[0], 1)
            os.dup2(saved[1], 2)
            os.close(saved[0])
            os.close(saved[1])
            if infile:
                os.unlink(infile.name)
        out.seek(0)
        text = out.read().decode("utf-8", "replace")
    return int(status or 0), text


def _description_deps(folder):
    """Depends + Imports of an installed package (its DESCRIPTION)."""
    fields, key = {}, None
    try:
        with open(os.path.join(folder, "DESCRIPTION"), encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if line[:1] in (" ", "\t") and key:
                    fields[key] += " " + line.strip()
                elif ":" in line:
                    key, value = line.split(":", 1)
                    fields[key] = value.strip()
    except OSError:
        return []
    names = []
    for field in ("Depends", "Imports"):
        for item in fields.get(field, "").split(","):
            name = item.strip().split("(")[0].strip()
            if name and name != "R":
                names.append(name)
    return names


def _ca_file():
    """certifi's certificate file (or pip's copy of it): iOS Python has no system store."""
    for module in ("certifi", "pip._vendor.certifi"):
        try:
            found = __import__(module, fromlist=["where"]).where()
            if os.path.isfile(found):
                return found
        except Exception:
            pass
    return None


def _download(url, timeout=120):
    import ssl
    import urllib.request
    context = ssl.create_default_context(cafile=_ca_file())
    return urllib.request.urlopen(url, timeout=timeout, context=context).read()


def _have(name, libraries):
    return any(os.path.isfile(os.path.join(lib, name, "DESCRIPTION")) for lib in libraries)


def _install(packages, lib):
    """install.packages(): R packages built for iOS (and the dependencies they lack)."""
    import io
    import tarfile
    import urllib.request
    os.makedirs(lib, exist_ok=True)
    libraries = [lib, LIBRARY, os.path.join(HOME, "library")]
    import urllib.error
    todo, done, missing, failed = list(packages), [], [], []
    while todo:
        name = todo.pop(0)
        if name in done or name in missing:
            continue
        if name not in packages and _have(name, libraries):
            continue
        url = "%s/%s-ios-arm64.tar.gz" % (RELEASE, name)
        try:
            data = _download(url)
        except urllib.error.HTTPError as error:
            if error.code == 404:
                missing.append(name)
            else:
                failed.append("%s (%s)" % (name, error))
            continue
        except Exception as error:
            failed.append("%s (%s)" % (name, error))
            continue
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            archive.extractall(lib, filter="data")
        done.append(name)
        print("installed %s (built for iOS)" % name)
        todo.extend(d for d in _description_deps(os.path.join(lib, name)) if not _have(d, libraries))
    if failed:
        print("could not download: %s" % "; ".join(failed))
    if missing:
        print("not built for iOS yet: %s" % ", ".join(missing))
        # Nyxian offers to build them (like pip does for wheels)
        _escape("nyxian-build", "rpkg;0;%s" % " ".join(missing))
    elif done:
        # their binaries get Nyxian's signature in a fresh window (as after pip install)
        print("Open a new window (Nyxian offers it) to use them: library(%s)" % packages[0])
        _escape("nyxian-installed", " ".join(done))
    return not missing and not failed


def _set_c_shell():
    """system()/popen() in R's C code go to shell() (R_nyxian_shell in libR)."""
    try:
        lib = ctypes.CDLL(os.path.join(HOME, "lib", "libR.dylib"))
        hook = ctypes.c_void_p.in_dll(lib, "R_nyxian_shell")
    except (OSError, ValueError):
        return
    libc = ctypes.CDLL(None)
    libc.malloc.restype = ctypes.c_void_p
    libc.malloc.argtypes = [ctypes.c_size_t]
    proto = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p))

    def run(cmd, stdin, output):
        status, text = shell(cmd.decode("utf-8", "replace"), (stdin or b"").decode("utf-8", "replace"))
        data = text.encode("utf-8") + b"\0"
        buffer = libc.malloc(len(data))
        if buffer:
            ctypes.memmove(buffer, data, len(data))
            output[0] = buffer
        return status

    callback = proto(run)
    _keep.append(callback)
    hook.value = ctypes.cast(callback, ctypes.c_void_p).value


def start():
    """Opens R (once per process) with the bridge in place."""
    global _started
    if _started:
        return
    os.environ["R_HOME"] = HOME
    os.environ.setdefault("RPY2_CFFI_MODE", "ABI")
    os.environ.setdefault("R_LIBS_USER", LIBRARY)
    # R's own start would try utils/stats before Nyxian's bridge is in place (and warn): none
    # at start, the usual ones attached by start() below
    os.environ["R_DEFAULT_PACKAGES"] = "NULL"
    os.makedirs(os.environ["R_LIBS_USER"], exist_ok=True)
    ca = _ca_file()
    if ca:
        os.environ.setdefault("NYXIAN_CA_BUNDLE", ca)
        os.environ.setdefault("CURL_CA_BUNDLE", ca)
    # rpy2 knows Linux/Darwin/Windows: on iOS R is lib/libR.dylib, as on the Mac
    import rpy2.situation as situation
    situation.get_rlib_path = lambda r_home, system: os.path.join(r_home, "lib", "libR.dylib")
    # rpy2 asks Rscript (a process) for LD_LIBRARY_PATH: nothing to ask on iOS
    situation.r_ld_library_path_from_subprocess = lambda r_home: ""
    import rpy2.rinterface as ri
    # rpy2 also runs Rscript to copy the environment R's start script sets: on iOS those are
    # these (etc/Renviron is read by R itself when it starts)
    ri._getrenvvars = lambda *args, **kwargs: (
        ("R_SHARE_DIR", os.path.join(HOME, "share")),
        ("R_INCLUDE_DIR", os.path.join(HOME, "include")),
        ("R_DOC_DIR", os.path.join(HOME, "doc")),
        ("R_ARCH", ""),
    )
    # R's messages, warnings and errors: plain text on stderr (rpy2 logs them as Python warnings)
    from rpy2.rinterface_lib import callbacks
    callbacks.consolewrite_warnerror = lambda text: (sys.stderr.write(text), sys.stderr.flush())
    callbacks.showmessage = lambda text: print(text)
    # libR is open once rpy2.rinterface is imported: system()/popen() work from R's very start
    _set_c_shell()
    ri.initr(interactive=False)

    def r_shell(cmd, stdin_text):
        status, text = shell(str(cmd[0]), str(stdin_text[0]) if len(stdin_text) else "")
        return ri.ListSexpVector([ri.StrSexpVector([text]), ri.StrSexpVector([""]), ri.IntSexpVector([status])])

    def r_which(name):
        return ri.StrSexpVector([shutil.which(str(name[0])) or ""])

    def r_open(url):
        _escape("nyxian-open", str(url[0]))
        return ri.BoolSexpVector([True])  # (rternalize does not take rpy2's NULL back)

    def r_preview(path):
        _escape("nyxian-preview", str(path[0]))
        return ri.BoolSexpVector([True])  # (rternalize does not take rpy2's NULL back)

    def r_install(packages, lib):
        return ri.BoolSexpVector([_install([str(p) for p in packages], str(lib[0]))])

    def r_quit(status):
        _quit[0] = int(status[0]) if len(status) else 0
        return ri.BoolSexpVector([True])  # (rternalize does not take rpy2's NULL back)

    env = ri.globalenv
    for name, fn in ((".nyxian_shell", r_shell), (".nyxian_which", r_which), (".nyxian_open", r_open),
                     (".nyxian_preview", r_preview), (".nyxian_install", r_install), (".nyxian_quit", r_quit)):
        wrapped = ri.rternalize(fn)
        _keep.append(wrapped)
        env[name] = wrapped
    # .nyxian_shell returns list(out, err, status) with names
    ri.evalr('local({ f <- .nyxian_shell; assign(".nyxian_shell", function(cmd, input = "") '
             '{ r <- f(cmd, input); names(r) <- c("out", "err", "status"); r }, envir = globalenv()) })')
    # the default packages R attaches at start (utils, stats…): whatever startup missed, now,
    # with the real error shown if one still does not load
    ri.evalr('for (p in c("datasets", "utils", "grDevices", "graphics", "stats", "methods")) if (!(paste0("package:", p) %in% search())) '
             'tryCatch(suppressPackageStartupMessages(library(p, character.only = TRUE)), '
             'error = function(e) message("could not load ", p, ": ", conditionMessage(e)))')
    _started = True


# ---------------------------------------------------------------- console

_EVAL = r'''
function(code) {
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) e)
  if (inherits(exprs, "error")) {
    if (grepl("unexpected end of input|INCOMPLETE_STRING|unexpected INCOMPLETE", conditionMessage(exprs)))
      return("incomplete")
    message("Error: ", sub("^<text>:", "", conditionMessage(exprs)))
    return("error")
  }
  for (e in exprs) {
    r <- withCallingHandlers(
      tryCatch(withVisible(eval(e, globalenv())),
               error = function(err) {
                 call <- conditionCall(err)
                 message("Error", if (!is.null(call)) paste0(" in ", deparse(call)[1L]), ": ", conditionMessage(err))
                 NULL }),
      warning = function(w) { message("Warning message:\n", conditionMessage(w)); invokeRestart("muffleWarning") })
    if (!is.null(r) && isTRUE(r$visible)) print(r$value)
  }
  # plots made by this line: shown now
  f <- get0(".nyxian_plot_file", envir = globalenv())
  if (!is.null(f) && grDevices::dev.cur() > 1L) {
    grDevices::dev.off(); rm(".nyxian_plot_file", envir = globalenv())
    if (file.exists(f)) .nyxian_preview(f)
  }
  "ok"
}
'''


def evaluate(code):
    """Runs R code (text) like R's console does; returns 'ok', 'error' or 'incomplete'."""
    start()
    import rpy2.rinterface as ri
    global _evaluator
    try:
        _evaluator
    except NameError:
        _evaluator = ri.evalr(_EVAL)
    return str(_evaluator(ri.StrSexpVector([code]))[0])


def console():
    start()
    import rpy2.rinterface as ri
    print(str(ri.evalr('R.version.string')[0]) + " for iOS in Nyxian · q() quits")
    buffer = ""
    while _quit[0] is None:
        try:
            line = input("+ " if buffer else "> ")
        except EOFError:
            print()
            break
        except KeyboardInterrupt:
            print()
            buffer = ""
            continue
        buffer += line + "\n"
        try:
            result = evaluate(buffer)
        except Exception as error:  # q() and R's own aborts end up here
            if _quit[0] is not None:
                break
            print("Error: %s" % error)
            result = "error"
        if result != "incomplete":
            buffer = ""
    return _quit[0] or 0


def run_file(path, args=()):
    """Rscript FILE.R [ARGS]: commandArgs(trailingOnly = TRUE) gives ARGS."""
    start()
    import rpy2.rinterface as ri
    ri.globalenv[".nyxian_args"] = ri.StrSexpVector(list(args))
    ri.evalr('local({ a <- get(".nyxian_args", envir = globalenv()); '
             'f <- function(trailingOnly = FALSE) if (trailingOnly) a else c("R", "--args", a); '
             'e <- baseenv(); unlockBinding("commandArgs", e); assign("commandArgs", f, envir = e); lockBinding("commandArgs", e) })')
    with open(path, encoding="utf-8") as handle:
        code = handle.read()
    result = evaluate(code)
    if _quit[0] is not None:
        return _quit[0]
    return 0 if result == "ok" else 1
