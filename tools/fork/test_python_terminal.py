#!/usr/bin/env python3
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-07): CI test of Nyxian's Python REPL in a pseudo terminal
#    set up like Nyxian's (no echo / no line editing, CR -> LF), with the
#    Python version the app ships.
"""Drives nyxian_repl the way Nyxian's terminal does and checks the answers."""
import os
import pty
import re
import select
import sys
import tempfile
import termios
import time

SOURCE = os.path.join(os.path.dirname(__file__), "..", "..", "Nyxian", "UI", "ContentView.swift")
NAMES = ["nyxian_lineedit.py", "nyxian_repl.py", "nyxian_keytest.py", "sitecustomize.py"]


def extract(folder):
    text = open(SOURCE, encoding="utf-8").read()
    for name in NAMES:
        match = re.search(r'"%s": #"""\n(.*?)\n"""#' % re.escape(name), text, re.S)
        assert match, name
        with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
            handle.write(match.group(1) + "\n")


def spawn(folder, module):
    pid, fd = pty.fork()
    if pid == 0:
        attrs = termios.tcgetattr(0)
        attrs[0] = termios.ICRNL | termios.ISTRIP | termios.INPCK
        attrs[1] = termios.OPOST | termios.ONLCR
        attrs[3] = termios.ISIG
        attrs[6][termios.VMIN] = 1
        attrs[6][termios.VTIME] = 0
        termios.tcsetattr(0, termios.TCSANOW, attrs)
        os.environ.update(NYXIAN_TERMINAL="1", PYTHONPATH=folder, PYTHONUNBUFFERED="1")
        os.chdir(folder)
        os.execv(sys.executable, [sys.executable, "-q", "-m", module])
    return fd


def drain(fd, seconds=2.0, until=b">>> "):
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
            if until and out.endswith(until):
                break
    return out


def main():
    print("Python", sys.version)
    folder = tempfile.mkdtemp()
    extract(folder)
    fd = spawn(folder, "nyxian_repl")
    assert drain(fd, 10).endswith(b">>> "), "no prompt"
    checks = [
        (b"print(2+2)\r", b"4"),
        (b"import json; json.dumps({'a': 1})\r", b'{"a": 1}'),
        (b"for i in range(2):\r", b"... "),
        (b"    print(i * 10)\r", b"... "),
        (b"\r", b"10"),
        (b"1/0\r", b"ZeroDivisionError"),
        (b"x = input('n? ')\r", b"n? "),
        (b"42\r", b">>> "),
        (b"x\r", b"'42'"),
    ]
    failed = False
    for keys, expected in checks:
        for byte in keys:
            os.write(fd, bytes([byte]))
        out = drain(fd, 5, b"n? " if expected == b"n? " else b">>> ")
        ok = expected in out
        failed |= not ok
        print("OK  " if ok else "FAIL", keys, "->", out)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
