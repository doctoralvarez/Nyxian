#!/usr/bin/env python3
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-08): CI test of nyxian_jedi (completion, diagnostics),
#    nyxian_mplbackend (plt.show) and the error file of runs.
"""Runs Nyxian's Python helpers the way the app does and checks the answers."""
import json
import os
import re
import subprocess
import sys
import tempfile

SOURCE = os.path.join(os.path.dirname(__file__), "..", "..", "Nyxian", "UI", "ContentView.swift")
NAMES = ["nyxian_jedi.py", "nyxian_mplbackend.py", "nyxian_lineedit.py", "sitecustomize.py"]


def extract(folder):
    text = open(SOURCE, encoding="utf-8").read()
    for name in NAMES:
        match = re.search(r'"%s": #"""\n(.*?)\n"""#' % re.escape(name), text, re.S)
        assert match, name
        with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
            handle.write(match.group(1) + "\n")


def main():
    print("Python", sys.version)
    helpers = tempfile.mkdtemp()
    extract(helpers)
    failed = False

    def check(label, ok, detail=""):
        nonlocal failed
        failed |= not ok
        print("OK  " if ok else "FAIL", label, detail)

    requests = [
        {"id": 1, "op": "ping"},
        {"id": 2, "op": "complete", "source": "import json\njson.du", "line": 2, "column": 7},
        {"id": 3, "op": "complete", "source": "import os\nos.", "line": 2, "column": 3},
        {"id": 4, "op": "diagnose", "source": "for i in range(3)\n    print(i)\n"},
        {"id": 5, "op": "diagnose", "source": "print('fine')\n"},
    ]
    run = subprocess.run([sys.executable, "-q", "-m", "nyxian_jedi"], input="\n".join(json.dumps(r) for r in requests) + "\n",
                         capture_output=True, text=True, env=dict(os.environ, PYTHONPATH=helpers), timeout=180)
    answers = {a["id"]: a for a in (json.loads(line) for line in run.stdout.splitlines() if line.strip())}
    check("ping", answers.get(1, {}).get("ok") is True, answers.get(1))
    names = [item["text"] for item in answers.get(2, {}).get("items", [])]
    check("complete json.du", "dumps" in names and "dump" in names, names[:5])
    dumps = next((item for item in answers.get(2, {}).get("items", []) if item["text"] == "dumps"), {})
    check("signature + doc", "(" in dumps.get("display", "") and bool(dumps.get("doc")), dumps)
    names = [item["text"] for item in answers.get(3, {}).get("items", [])]
    check("complete os.", "path" in names and "getcwd" in names, len(names))
    problems = answers.get(4, {}).get("problems", [])
    check("syntax error", bool(problems) and problems[0]["line"] == 1 and "':'" in problems[0]["message"], problems)
    check("no problems", answers.get(5, {}).get("problems") == [], answers.get(5))
    if run.stderr.strip():
        print(run.stderr[-800:])

    folder = tempfile.mkdtemp()
    with open(os.path.join(folder, "seno.py"), "w") as handle:
        handle.write("import matplotlib.pyplot as plt\nplt.plot([1, 2, 3])\nplt.show()\nprint('after')\nx = 1 / 0\n")
    env = dict(os.environ, PYTHONPATH=helpers + os.pathsep + folder, MPLBACKEND="module://nyxian_mplbackend",
               NYXIAN_TERMINAL="1", NYXIAN_ERROR_FILE=os.path.join(folder, ".nyxian-error.json"))
    run = subprocess.run([sys.executable, "seno.py"], cwd=folder, capture_output=True, env=env, timeout=180)
    check("plt.show marker", b"\x1b]7770;nyxian-preview;" in run.stdout and b"figure-1.png\x07" in run.stdout, run.stdout[:160])
    check("figure saved", os.path.exists(os.path.join(folder, "figures", "figure-1.png")))
    check("script went on", b"after" in run.stdout)
    error = json.load(open(os.path.join(folder, ".nyxian-error.json"))) if os.path.exists(os.path.join(folder, ".nyxian-error.json")) else {}
    check("error line", error.get("line") == 5 and "ZeroDivisionError" in error.get("message", ""), error)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
