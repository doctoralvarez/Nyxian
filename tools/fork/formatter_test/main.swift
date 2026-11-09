// Fork doctoralvarez/Nyxian — version 1.1.0
// Changelog:
//  - 1.1.0 (2026-11-08): the formatter is taken from CodeEditor.swift
//    (BEGIN/END ForkSwiftFormatter block).
//  - 1.0.0 (2026-11-08): CI test of ForkSwiftFormatter.
import Foundation

var failures = 0
func check(_ name: String, _ input: String, _ expected: String, python: Bool = false) {
    let output = python ? ForkSwiftFormatter.formatPython(input) : ForkSwiftFormatter.formatSwift(input)
    if output == expected {
        print("OK   \(name)")
    } else {
        failures += 1
        print("FAIL \(name)\n--- expected\n\(expected)--- got\n\(output)---")
    }
}

check("swiftui chain", """
struct V: View {
var body: some View {
VStack {
Text("a,b")
.font(.title)
.padding()
}
.padding()
}
}
""", """
struct V: View {
    var body: some View {
        VStack {
            Text("a,b")
                .font(.title)
                .padding()
        }
        .padding()
    }
}

""")

check("switch and spacing", """
func f(x:Int,y:Int)->Int{
switch x {
case 1:
return y
default:
if(y>0){ return 1 }else{ return 2 }
}
}
""", """
func f(x:Int, y:Int)->Int{
    switch x {
    case 1:
        return y
    default:
        if (y>0) { return 1 } else { return 2 }
    }
}

""")

check("blank lines and trailing spaces", "struct A {   \n\n\n    var a = 1  \n\n\n\n    var b = 2\n\n}\n\n\n", """
struct A {
    var a = 1

    var b = 2
}

""")

check("tabs kept", "enum E {\n\tcase a\n\tcase b\n\tfunc f() {\n\t\tprint(\"x\")\n\t}\n}\n", "enum E {\n\tcase a\n\tcase b\n\tfunc f() {\n\t\tprint(\"x\")\n\t}\n}\n")

check("strings and multiline untouched", """
let s = "if(a){ x,y }"
let m = \"\"\"
   keep,this(  )
\"\"\"
// comment,with{braces
""", """
let s = "if(a){ x,y }"
let m = \"\"\"
   keep,this(  )
\"\"\"
// comment,with{braces

""")

check("python", "def f():\n\treturn 1   \n\n\n\n\nprint(f())\n\n", "def f():\n    return 1\n\n\nprint(f())\n", python: true)

print(failures == 0 ? "all formatter tests passed" : "\(failures) formatter test(s) failed")
exit(failures == 0 ? 0 : 1)
