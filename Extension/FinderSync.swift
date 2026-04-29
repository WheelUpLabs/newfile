import Cocoa
import FinderSync
import os

private let log = Logger(subsystem: "dev.newfile.NewFile", category: "extension")

final class FinderSync: FIFinderSync {

    private static let baseName = "New Text File"
    private static let fileExtension = "txt"

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        log.info("FinderSync init")
    }

    // MARK: - Toolbar item

    override var toolbarItemName: String { "NewFile" }

    override var toolbarItemToolTip: String { "Create a new text file in this folder" }

    override var toolbarItemImage: NSImage {
        Self.toolbarIcon(accessibility: "New File")
    }

    // MARK: - Menus

    override func menu(for menu: FIMenuKind) -> NSMenu? {
        let nsMenu = NSMenu(title: "")
        let item = NSMenuItem(title: "New Text File",
                              action: #selector(createNewFile(_:)),
                              keyEquivalent: "")
        item.target = self
        item.image = Self.menuIcon()
        nsMenu.addItem(item)
        return nsMenu
    }

    private static func toolbarIcon(accessibility: String?) -> NSImage {
        let bundle = Bundle(for: FinderSync.self)
        if let image = bundle.image(forResource: "ToolbarIcon") {
            image.isTemplate = true
            image.accessibilityDescription = accessibility
            return image
        }
        // Fallback if asset is missing — keeps the toolbar item usable.
        let fallback = NSImage(systemSymbolName: "square.and.pencil",
                               accessibilityDescription: accessibility)
            ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }

    // Context-menu row uses the canonical macOS "compose" SF Symbol. Template
    // tinting through the Finder-Sync extension XPC path is unreliable in
    // current macOS, so we apply an explicit palette tint with the dynamic
    // labelColor — resolves to ~white in dark menus, ~black in light menus,
    // matching the system items above.
    private static func menuIcon() -> NSImage {
        guard let base = NSImage(systemSymbolName: "square.and.pencil",
                                 accessibilityDescription: "New File") else {
            return NSImage()
        }
        let config = NSImage.SymbolConfiguration(paletteColors: [.labelColor])
        return base.withSymbolConfiguration(config) ?? base
    }

    // MARK: - Action

    private static let firstUseNotificationName =
        Notification.Name("dev.newfile.NewFile.toolbarOrMenuUsed")

    @objc func createNewFile(_ sender: AnyObject?) {
        log.info("createNewFile invoked")
        DistributedNotificationCenter.default().postNotificationName(
            Self.firstUseNotificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        let controller = FIFinderSyncController.default()
        let target = controller.targetedURL()
        let selected = controller.selectedItemURLs()
        log.info("targetedURL=\(target?.path ?? "nil", privacy: .public) selected=\(selected?.map { $0.path }.joined(separator: ", ") ?? "nil", privacy: .public)")

        guard let directory = directoryForCreation(target: target, selected: selected) else {
            log.error("No target directory available")
            NSSound.beep()
            return
        }
        log.info("creating in directory=\(directory.path, privacy: .public)")

        do {
            let url = try createUniqueFile(in: directory)
            log.info("created file=\(url.path, privacy: .public)")
            revealFile(at: url)
        } catch {
            log.error("create failed: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    // MARK: - Helpers

    private func directoryForCreation(target: URL?, selected: [URL]?) -> URL? {
        if let target { return resolvedDirectory(for: target) }
        if let first = selected?.first { return resolvedDirectory(for: first) }
        return nil
    }

    private func resolvedDirectory(for url: URL) -> URL {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
           isDir.boolValue {
            return url
        }
        return url.deletingLastPathComponent()
    }

    private func createUniqueFile(in directory: URL) throws -> URL {
        let url = uniqueFileURL(in: directory,
                                baseName: Self.baseName,
                                ext: Self.fileExtension)
        let scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        try Data().write(to: url, options: [.withoutOverwriting])
        return url
    }

    private func uniqueFileURL(in directory: URL, baseName: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = directory.appendingPathComponent("\(baseName).\(ext)")
        var i = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) \(i).\(ext)")
            i += 1
        }
        return candidate
    }

    private func revealFile(at url: URL) {
        // NSWorkspace from extension context: select via Finder app directly.
        NSWorkspace.shared.selectFile(url.path,
                                      inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
}
