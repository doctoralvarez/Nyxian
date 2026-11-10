#!/usr/bin/env python3
# Fork doctoralvarez/Nyxian — version 1.1.0
# Changelog:
#  - 1.1.0 (2026-11-10): scripts with #! (python, sh), sh FILE / source, and
#    node / npm / npx when the machine has Node.js (as NYXIAN_NODE).
#  - 1.0.0 (2026-11-09): CI test of Nyxian Shell (nyxian_shell) in a pseudo
#    terminal set up like Nyxian's: built-in commands, pipes, redirection,
#    && ||, variables, globs, programs as processes, ^Z / jobs / fg / bg.
"""Drives nyxian_shell the way Nyxian's terminal does and checks the answers."""
import os
import pty
import re
import select
import shutil
import sys
import tempfile
import termios
import time

SOURCE = os.path.join(os.path.dirname(__file__), "..", "..", "Nyxian", "UI", "ContentView.swift")
NAMES = ["nyxian_lineedit.py", "nyxian_shell.py"]


def extract(folder):
    text = open(SOURCE, encoding="utf-8").read()
    for name in NAMES:
        match = re.search(r'"%s": #"""\n(.*?)\n"""#' % re.escape(name), text, re.S)
        assert match, name
        with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
            handle.write(match.group(1) + "\n")


def spawn(helpers, work):
    pid, fd = pty.fork()
    if pid == 0:
        attrs = termios.tcgetattr(0)
        attrs[0] = termios.ICRNL | termios.INPCK | getattr(termios, "IUTF8", 0)
        attrs[1] = termios.OPOST | termios.ONLCR
        attrs[3] = (termios.ICANON | termios.ECHO | termios.ECHOE | termios.ECHOK | termios.ECHOKE
                    | termios.ECHOCTL | termios.ISIG | termios.IEXTEN)
        termios.tcsetattr(0, termios.TCSANOW, attrs)
        os.environ.update(NYXIAN_TERMINAL="1", PYTHONPATH=helpers, PYTHONUNBUFFERED="1", HOME=work)
        node = shutil.which("node")
        if node:
            # as in Nyxian: node by path, npm's scripts under NYXIAN_NODE_HOME
            os.environ.update(NYXIAN_NODE=node, NYXIAN_NODE_HOME=os.path.dirname(os.path.dirname(os.path.realpath(node))),
                              npm_config_prefix=os.path.join(work, ".node"), npm_config_update_notifier="false")
        os.chdir(work)
        os.execv(sys.executable, [sys.executable, "-q", "-m", "nyxian_shell"])
    return fd


def drain(fd, seconds, until):
    out = b""
    end = time.time() + seconds
    while time.time() < end:
        ready, _, _ = select.select([fd], [], [], 0.05)
        if ready:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
            if until and until in out:
                # a little more: the prompt after the answer
                time.sleep(0.15)
                while select.select([fd], [], [], 0.05)[0]:
                    try:
                        more = os.read(fd, 4096)
                    except OSError:
                        break
                    if not more:
                        break
                    out += more
                break
    return out


def main():
    print("Python", sys.version)
    helpers = tempfile.mkdtemp()
    work = tempfile.mkdtemp()
    extract(helpers)
    with open(os.path.join(work, "datos.txt"), "w") as handle:
        handle.write("uno\ndos\ntres\ncuatro\n")
    with open(os.path.join(work, "hola.py"), "w") as handle:
        handle.write("import sys\nprint('hola desde python', sys.argv[1:])\n")
    with open(os.path.join(work, "herramienta"), "w") as handle:
        handle.write("#!/usr/bin/env python3\nimport sys\nprint('herramienta con', sys.argv[1:])\n")
    os.chmod(os.path.join(work, "herramienta"), 0o755)
    with open(os.path.join(work, "pasos.sh"), "w") as handle:
        handle.write("# comentario\necho paso uno $1\ncat datos.txt | grep -c o\n")
    with open(os.path.join(work, "hola.js"), "w") as handle:
        handle.write("console.log('hola desde node', process.argv.slice(2).join(','));\n")
    fd = spawn(helpers, work)
    first = drain(fd, 15, b"$ ")
    failed = not first.endswith(b"$ ") and b"$ " not in first
    print("OK  " if not failed else "FAIL", "prompt", first[-80:])
    checks = [
        (b"ls\r", b"datos.txt"),
        (b"cat datos.txt | grep -n o\r", b"2:dos"),
        (b"cat datos.txt | wc -l\r", b"4"),
        (b"echo hola > a.txt && cat a.txt\r", b"hola"),
        (b"echo mas >> a.txt; wc -l a.txt\r", b"2 a.txt"),
        (b"false || echo fallo\r", b"fallo"),
        (b"true && echo bien\r", b"bien"),
        (b"export NOMBRE=Nyxian; echo $NOMBRE ${NOMBRE}!\r", b"Nyxian Nyxian!"),
        (b"echo '$NOMBRE'\r", b"$NOMBRE"),
        (b"ls *.py\r", b"hola.py"),
        (b"mkdir -p d/e && cd d/e && pwd\r", b"/d/e"),
        (b"cd ~ && pwd\r", work.encode()),
        (b"python3 hola.py uno dos\r", b"hola desde python ['uno', 'dos']"),
        (b"python3 hola.py x | grep -c hola\r", b"\r\n1\r\n"),
        (b"python3 -c \"import sys; print(sys.stdin.read().upper())\" < datos.txt\r", b"CUATRO"),
        (b"python3 -c \"import sys; sys.stderr.write('err\\n')\" 2> e.txt; cat e.txt\r", b"err"),
        (b"nada\r", b"command not found"),
        (b"sort -r datos.txt | head -n 1\r", b"uno"),
        (b"find . -name '*.txt' | sort\r", b"./datos.txt"),
        (b"./herramienta a b\r", b"herramienta con ['a', 'b']"),
        (b"sh pasos.sh X\r", b"paso uno X"),
        (b"source pasos.sh\r", b"\r\n3\r\n"),
        (b"sh -c 'echo dentro'\r", b"dentro"),
    ]
    if shutil.which("node"):
        checks += [
            (b"node hola.js a b\r", b"hola desde node a,b"),
            (b"node -e \"console.log(6*7)\" | grep 42\r", b"42"),
            (b"npm --version\r", b"."),
            (b"which npm\r", b"npm-cli.js"),
            (b"npx nada-instalado\r", b"is not installed here"),
        ]
    for keys, expected in checks:
        os.write(fd, keys)
        out = drain(fd, 15, expected)
        ok = expected in out
        failed |= not ok
        print("OK  " if ok else "FAIL", keys, "->", out[-200:])

    # job control: ^Z stops the program in front, fg brings it back, ^C ends it
    os.write(fd, b"python3 -c \"import time; [print('tic', i, flush=True) or time.sleep(0.3) for i in range(200)]\"\r")
    out = drain(fd, 10, b"tic 2")
    os.write(fd, b"\x1a")
    out = drain(fd, 10, b"Stopped")
    ok = b"Stopped" in out
    failed |= not ok
    print("OK  " if ok else "FAIL", "^Z stops the program ->", out[-160:])
    os.write(fd, b"jobs\r")
    out = drain(fd, 10, b"Stopped")
    ok = b"[1]" in out and b"Stopped" in out
    failed |= not ok
    print("OK  " if ok else "FAIL", "jobs ->", out[-160:])
    os.write(fd, b"bg\r")
    out = drain(fd, 10, b"tic")
    ok = b"&" in out
    failed |= not ok
    print("OK  " if ok else "FAIL", "bg ->", out[-160:])
    os.write(fd, b"fg\r")
    out = drain(fd, 5, b"tic")
    os.write(fd, b"\x03")
    out = drain(fd, 10, b"$ ")
    os.write(fd, b"jobs; echo listo\r")
    out = drain(fd, 10, b"listo")
    ok = b"listo" in out and b"Stopped" not in out and b"Running" not in out
    failed |= not ok
    print("OK  " if ok else "FAIL", "fg then ^C ends the job ->", out[-160:])
    os.write(fd, b"sleep 0.5 &\r")
    out = drain(fd, 5, b"$ ")
    time.sleep(1)
    os.write(fd, b"echo fin\r")
    out = drain(fd, 5, b"fin")
    ok = b"Done" in out
    failed |= not ok
    print("OK  " if ok else "FAIL", "background built-in is reported Done ->", out[-160:])
    os.write(fd, b"exit\r")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
