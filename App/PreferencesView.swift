import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var fileTypes: [FileTypeEntry]
    @Published var useRightClickSubmenu: Bool {
        didSet { store?.useRightClickSubmenu = useRightClickSubmenu }
    }

    private let store: SettingsStore?
    private var persistCancellable: AnyCancellable?

    init(store: SettingsStore? = SettingsStore.appGroupStore()) {
        self.store = store
        self.fileTypes = store?.fileTypes ?? SeedPresets.builtIns
        self.useRightClickSubmenu = store?.useRightClickSubmenu ?? false

        // Persist off a debounce, not per keystroke: every edit used to JSON-encode
        // the full list into UserDefaults synchronously from the row's onChange.
        persistCancellable = $fileTypes
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [store] types in
                store?.fileTypes = Self.validOnly(types)
            }
    }

    /// Rows with an invalid extension stay visible in the UI but never reach
    /// the store (the extension would render them in the Finder menu).
    nonisolated private static func validOnly(_ types: [FileTypeEntry]) -> [FileTypeEntry] {
        types.filter { $0.isBuiltIn || (try? FileTypeEntry.validateExtension($0.ext)) != nil }
    }

    func persist() {
        store?.fileTypes = Self.validOnly(fileTypes)
    }

    func delete(_ entry: FileTypeEntry) {
        fileTypes.removeAll { $0.id == entry.id }
        persist()
    }

    func addCustomType() {
        let new = FileTypeEntry(
            ext: "",
            baseName: "",
            displayName: "",  // blank -> menuTitle derives from ext
            template: "",
            enabled: true,
            isBuiltIn: false
        )
        fileTypes.append(new)
    }
}

struct PreferencesView: View {
    @StateObject private var vm = PreferencesViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var draggingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("File Types").font(.headline)
                Spacer()
                Button("+ Add Type…") { vm.addCustomType() }
            }

            columnHeaders

            // Plain ScrollView, not List: the NSTableView row machinery behind
            // List added first-click latency on the row text fields.
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($vm.fileTypes) { $entry in
                        if !entry.isBuiltIn && isFirstCustom(entry, in: vm.fileTypes) {
                            sectionHeader("Custom types")
                        }
                        FileTypeRow(
                            entry: $entry,
                            onDelete: entry.isBuiltIn ? nil : { vm.delete(entry) },
                            onReorderDrag: {
                                draggingID = entry.id
                                return NSItemProvider(object: entry.id.uuidString as NSString)
                            }
                        )
                        .padding(.horizontal, 8)
                        .onDrop(of: [.text],
                                delegate: RowReorderDelegate(item: entry,
                                                             list: $vm.fileTypes,
                                                             draggingID: $draggingID))
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minHeight: 320, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            Toggle("Group enabled types in a submenu", isOn: $vm.useRightClickSubmenu)
            Text("When off, each enabled type appears directly in the Finder menu.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") {
                    vm.persist()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 660, minHeight: 560)
    }

    /// Column captions for the row fields. Mirrors FileTypeRow's fixed widths
    /// so the captions line up; "enabled" spans the handle + toggle columns.
    private var columnHeaders: some View {
        HStack(spacing: 8) {
            Text("enabled")
                .frame(width: FileTypeRow.handleColumnWidth + 8 + FileTypeRow.toggleColumnWidth,
                       alignment: .leading)
                .help("Checked types appear in the Finder menu")
            Text("extension")
                .frame(width: 110, alignment: .leading)
            Text("menu label")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("default filename")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("template")
                .frame(width: FileTypeRow.templateColumnWidth)
            Color.clear.frame(width: FileTypeRow.deleteColumnWidth + 4, height: 1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.bottom, -6)
    }

    private func isFirstCustom(_ entry: FileTypeEntry, in list: [FileTypeEntry]) -> Bool {
        guard let first = list.first(where: { !$0.isBuiltIn }) else { return false }
        return first.id == entry.id
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 2)
            .padding(.horizontal, 8)
    }
}

/// Moves the dragged row as the cursor passes over other rows; the drop
/// itself just clears the drag state.
private struct RowReorderDelegate: DropDelegate {
    let item: FileTypeEntry
    @Binding var list: [FileTypeEntry]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != item.id,
              let from = list.firstIndex(where: { $0.id == draggingID }),
              let to = list.firstIndex(where: { $0.id == item.id })
        else { return }
        withAnimation {
            list.move(fromOffsets: IndexSet(integer: from),
                      toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

#Preview {
    PreferencesView()
}
