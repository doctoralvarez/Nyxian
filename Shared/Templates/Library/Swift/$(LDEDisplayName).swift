import Foundation

/// A Swift dynamic library: built as lib$(LDEDisplayName).dylib.
/// `public` declarations are what other code can use; @_cdecl exports a C symbol
/// (callable from C, Objective-C or dlsym).
public enum LibraryInfo {
    public static let version = "1.0"

    public static func greeting(for name: String) -> String {
        "Hello, \(name)!"
    }
}

@_cdecl("library_add")
public func library_add(_ a: Int32, _ b: Int32) -> Int32 {
    a &+ b
}
