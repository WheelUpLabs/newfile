import XCTest

/// Covers the settings -> Finder-menu-label binding (issue #2): the menu
/// renders `entry.menuTitle`, so these pin the fallback + override rules.
final class MenuTitleTests: XCTestCase {

    private func custom(ext: String, displayName: String) -> FileTypeEntry {
        FileTypeEntry(ext: ext, baseName: "file", displayName: displayName,
                      enabled: true, isBuiltIn: false)
    }

    func testExplicitDisplayName_winsForCustomType() {
        XCTAssertEqual(custom(ext: "png", displayName: "Invoice Scan").menuTitle, "Invoice Scan")
    }

    func testBlankDisplayName_derivesFromExtension() {
        XCTAssertEqual(custom(ext: "png", displayName: "").menuTitle, "New .png")
    }

    func testWhitespaceDisplayName_derivesFromExtension() {
        XCTAssertEqual(custom(ext: "toml", displayName: "   ").menuTitle, "New .toml")
    }

    func testBlankDisplayNameAndBlankExt_fallsBackToGenericLabel() {
        XCTAssertEqual(custom(ext: "", displayName: "").menuTitle, "New file")
    }

    func testBuiltInLabels_unchangedByFallback() {
        // Option 2's whole point: shipped built-in labels must not be rewritten.
        for entry in SeedPresets.builtIns {
            XCTAssertEqual(entry.menuTitle, entry.displayName, "built-in .\(entry.ext)")
        }
    }

    func testEditedBuiltInDisplayName_reachesMenuTitle() {
        // Ballou's case: renaming a built-in must change the menu label.
        var md = SeedPresets.builtIns.first { $0.ext == "md" }!
        md.displayName = "New Note"
        XCTAssertEqual(md.menuTitle, "New Note")
    }

    func testDerivedDisplayName_trimsExt() {
        XCTAssertEqual(FileTypeEntry.derivedDisplayName(ext: " md "), "New .md")
    }
}
