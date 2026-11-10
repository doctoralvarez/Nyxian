// Fork doctoralvarez/Nyxian — version 1.0.0
// Changelog:
//  - 1.0.0 (2026-11-10): tests of ForkNotebook (ContentView.swift): reading an
//    .ipynb with outputs, "# %%" cells and back, recorded outputs added.
import Foundation

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    print(ok ? "ok   " : "FAIL ", name, ok ? "" : detail())
    if !ok { failures += 1 }
}

let png = Data([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]).base64EncodedString()
let ipynb = """
{"cells": [
 {"cell_type": "markdown", "metadata": {}, "source": ["# Título\\n", "Texto **fuerte**"]},
 {"cell_type": "code", "execution_count": 1, "metadata": {}, "source": ["x = 2\\n", "x * 3"],
  "outputs": [{"output_type": "execute_result", "data": {"text/plain": ["6"]}, "metadata": {}, "execution_count": 1}]},
 {"cell_type": "code", "execution_count": 2, "metadata": {}, "source": "print('hola')",
  "outputs": [{"output_type": "stream", "name": "stdout", "text": ["hola\\n"]},
              {"output_type": "display_data", "data": {"image/png": "\(png)", "text/plain": ["<Figure size 640x480>"]}, "metadata": {}}]},
 {"cell_type": "code", "execution_count": 3, "metadata": {}, "source": ["1/0"],
  "outputs": [{"output_type": "error", "ename": "ZeroDivisionError", "evalue": "division by zero", "traceback": ["\\u001b[31mZeroDivisionError\\u001b[0m: division by zero"]}]}
], "metadata": {"language_info": {"name": "python"}}, "nbformat": 4, "nbformat_minor": 5}
"""
guard let notebook = ForkNotebook(data: Data(ipynb.utf8)) else { print("FAIL could not read"); exit(1) }
check("4 cells", notebook.cells.count == 4, "\(notebook.cells.count)")
check("markdown joined", notebook.cells[0].kind == "markdown" && notebook.cells[0].source == "# Título\nTexto **fuerte**", notebook.cells[0].source)
check("execute_result text", notebook.cells[1].outputs.first?.text == "6")
check("stream + image", notebook.cells[2].outputs.count == 2 && notebook.cells[2].outputs[1].image != nil && notebook.cells[2].outputs[1].text.isEmpty)
check("error without ANSI", notebook.cells[3].outputs.first?.isError == true && notebook.cells[3].outputs.first?.text == "ZeroDivisionError: division by zero", notebook.cells[3].outputs.first?.text ?? "")

let script = notebook.percentScript
check("percent script has cells", script.components(separatedBy: "# %%").count - 1 == 4, script)
check("markdown as comments", script.contains("# %% [markdown]\n# # Título\n# Texto **fuerte**"), script)

let back = ForkNotebook.fromPercentScript(script)
check("round trip: same cells", back.cells.map { $0.kind } == ["markdown", "code", "code", "code"], "\(back.cells.map { $0.kind })")
check("round trip: same code", back.cells.map { $0.source } == notebook.cells.map { $0.source }, "\(back.cells.map { $0.source })")

let plain = ForkNotebook.fromPercentScript("import os\n\n# %%\na = 1\n\n# %% Second\nprint(a)\n")
check("code before the first marker is a cell", plain.cells.map { $0.source } == ["import os", "a = 1", "print(a)"], "\(plain.cells.map { $0.source })")

let recorded: [[String: Any]] = [["source": "a = 1\n", "output": "", "failed": false, "figures": []],
                                 ["source": "print(a)", "output": "1\n", "failed": false, "figures": []]]
if let data = plain.jsonData(outputs: recorded), let again = ForkNotebook(data: data),
   let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    check("saved notebook is nbformat 4", (object["nbformat"] as? Int) == 4)
    check("recorded output kept", again.cells[2].outputs.first?.text == "1\n", "\(again.cells[2].outputs)")
    check("cell without a run has no output", again.cells[0].outputs.isEmpty)
} else {
    check("saved notebook reads back", false)
}
print(failures == 0 ? "all notebook tests passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
