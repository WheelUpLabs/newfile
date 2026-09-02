import Combine
import SwiftUI

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

    func move(from source: IndexSet, to destination: Int) {
        fileTypes.move(fromOffsets: source, toOffset: destination)
        persist()
    }
}

struct PreferencesView: View {
    @StateObject private var vm = PreferencesViewModel()
    @Environment(\.dismiss) private var dismiss

    private let rowInsets = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("File types").font(.headline)
                Spacer()
                Button("+ Add type…") { vm.addCustomType() }
            }

            columnHeaders

            List {
                ForEach($vm.fileTypes) { $entry in
                    if !entry.isBuiltIn && isFirstCustom(entry, in: vm.fileTypes) {
                        sectionHeader("Custom types")
                    }
                    FileTypeRow(
                        entry: $entry,
                        onDelete: entry.isBuiltIn ? nil : { vm.delete(entry) }
                    )
                    .listRowInsets(rowInsets)
                }
                .onMove { source, dest in vm.move(from: source, to: dest) }

                // Breathing room after the last row inside the scroll area.
                Color.clear
                    .frame(height: 8)
                    .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
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

    /// Column captions for the row fields. Mirrors FileTypeRow's layout with
    /// hidden copies of its fixed-size controls so the captions line up.
    private var columnHeaders: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal").hidden()
            Toggle("", isOn: .constant(true)).labelsHidden().hidden()
                .overlay(
                    Image(systemName: "checkmark")
                        .help("Checked types appear in the Finder menu")
                )
            Text("extension")
                .frame(width: 110, alignment: .leading)
            Text("menu label")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("default filename")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("template")
                .frame(width: FileTypeRow.templateColumnWidth)
            Color.clear.frame(width: FileTypeRow.deleteColumnWidth, height: 1)
        }
        .font(.caption)
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
            .padding(.top, 10)
            .padding(.bottom, 2)
            .listRowInsets(rowInsets)
    }
}

#Preview {
    PreferencesView()
}
