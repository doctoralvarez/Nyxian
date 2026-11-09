#!/usr/bin/env python3
# Fork doctoralvarez/Nyxian — version 1.2.0
# Changelog:
#  - 1.2.0 (2026-11-09): cell outputs (output, errors, new figures per cell);
#    the debugger (stops at a breakpoint, state file, variables).
#  - 1.1.0 (2026-11-09): pyflakes lint and the test runner.
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
NAMES = ["nyxian_pdb.py", "nyxian_jedi.py", "nyxian_mplbackend.py", "nyxian_lineedit.py", "nyxian_tests.py", "nyxian_repl.py", "sitecustomize.py"]


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
        {"id": 6, "op": "diagnose", "source": "import os\nprint(undefined_name)\n"},
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
    lint = answers.get(6, {}).get("problems", [])
    check("pyflakes: unused import (warning)", any(p["line"] == 1 and p["level"] == "warning" and "os" in p["message"] for p in lint), lint)
    check("pyflakes: undefined name (error)", any(p["line"] == 2 and p["level"] == "error" for p in lint), lint)

    tests = tempfile.mkdtemp()
    with open(os.path.join(tests, "test_demo.py"), "w") as handle:
        handle.write("def test_ok():\n    assert 1 + 1 == 2\n\n\ndef test_bad():\n    assert 2 + 2 == 5\n")
    result_file = os.path.join(tests, ".nyxian-tests.json")
    run = subprocess.run([sys.executable, "-m", "nyxian_tests", "."], cwd=tests, capture_output=True, env=dict(os.environ, PYTHONPATH=helpers, NYXIAN_TEST_FILE=result_file), timeout=180)
    result = json.load(open(result_file)) if os.path.exists(result_file) else {}
    check("tests: counts", result.get("passed") == 1 and result.get("failed") == 1, result)
    check("tests: failing line", any(f.get("line") == 6 for f in result.get("failures", [])), result.get("failures"))
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

    cells_dir = tempfile.mkdtemp()
    cells_file = os.path.join(cells_dir, ".nyxian-cells.json")
    driver = (
        "import nyxian_repl\n"
        "c = nyxian_repl.NyxianConsole(locals={'__name__': '__main__'})\n"
        "c.run_block('x = 21\\nprint(\"doble\", x * 2)\\nx + 1')\n"
        "c.run_block('import matplotlib.pyplot as plt\\nplt.plot([3, 1, 2])\\nplt.show()')\n"
        "c.run_block('1 / 0')\n"
    )
    env = dict(os.environ, PYTHONPATH=helpers, MPLBACKEND="module://nyxian_mplbackend", NYXIAN_CELLS_FILE=cells_file)
    run = subprocess.run([sys.executable, "-c", driver], cwd=cells_dir, capture_output=True, env=env, timeout=180)
    cells = json.load(open(cells_file)).get("cells", []) if os.path.exists(cells_file) else []
    check("cells: three recorded", [c.get("n") for c in cells] == [1, 2, 3], [c.get("n") for c in cells])
    if len(cells) == 3:
        check("cells: output and value", "doble 42" in cells[0]["output"] and "22" in cells[0]["output"] and not cells[0]["failed"], cells[0])
        check("cells: new figure", any(f.endswith("figure-1.png") for f in cells[1]["figures"]), cells[1])
        check("cells: error kept", cells[2]["failed"] and "ZeroDivisionError" in cells[2]["output"], cells[2]["output"][-120:])
    if run.stderr.strip() and not cells:
        print(run.stderr[-800:])

    debug_dir = tempfile.mkdtemp()
    with open(os.path.join(debug_dir, "demo.py"), "w") as handle:
        handle.write("def f(n):\n    total = 0\n    for i in range(n):\n        total += i\n    return total\n\nx = f(4)\nprint('x =', x)\ny = x * 2\nprint('y =', y)\n")
    state = os.path.join(debug_dir, ".nyxian-debug.json")
    variables = os.path.join(debug_dir, ".nyxian-vars.json")
    env = dict(os.environ, PYTHONPATH=helpers, NYXIAN_BREAKPOINTS=json.dumps([{"file": "demo.py", "line": 9}]),
               NYXIAN_DEBUG_STATE=state, NYXIAN_VARS_FILE=variables)
    probe = subprocess.run([sys.executable, "-m", "nyxian_pdb", "demo.py"], cwd=debug_dir, input="p x + 100\nlocals\nc\n",
                           capture_output=True, text=True, env=env, timeout=120)
    check("debugger: stops at the breakpoint", "demo.py(9)" in probe.stdout and "106" in probe.stdout, probe.stdout[-400:])
    check("debugger: runs on after c", "y = 12" in probe.stdout and "[debugging ended]" in probe.stdout, probe.stdout[-200:])
    names = [row["name"] for row in json.load(open(variables)).get("variables", [])] if os.path.exists(variables) else []
    check("debugger: variables for the inspector", "x" in names, names)
    ended = json.load(open(state)) if os.path.exists(state) else {}
    check("debugger: state file", ended.get("ended") is True, ended)
    if probe.stderr.strip():
        print(probe.stderr[-600:])
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
