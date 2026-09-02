import Foundation

enum FilenameGenerator {
    /// Returns a non-colliding file URL inside `directory`.
    /// - If `baseName` is non-empty: `"<baseName>.<ext>"`, `"<baseName> 2.<ext>"`, …
    /// - If `baseName` is empty:     `".<ext>"`,           `".<ext> 2"`,           …
    /// `fileExists` is injected for testability (defaults to FileManager).
    static func uniqueFileURL(
        in directory: URL,
        baseName: String,
        ext: String,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        // Users sometimes type the full filename ("data.json", ".env") into the
        // base-name field; strip one redundant ".<ext>" suffix so the result
        // never doubles the extension (.env.env, data.json.json).
        var base = baseName
        let redundantSuffix = ".\(ext)"
        if base.lowercased().hasSuffix(redundantSuffix.lowercased()) {
            base = String(base.dropLast(redundantSuffix.count))
        }
        let isDotfile = base.isEmpty

        func candidate(_ i: Int) -> URL {
            if isDotfile {
                return i == 1
                    ? directory.appendingPathComponent(".\(ext)")
                    : directory.appendingPathComponent(".\(ext) \(i)")
            } else {
                return i == 1
                    ? directory.appendingPathComponent("\(base).\(ext)")
                    : directory.appendingPathComponent("\(base) \(i).\(ext)")
            }
        }

        var i = 1
        while fileExists(candidate(i)) { i += 1 }
        return candidate(i)
    }
}
