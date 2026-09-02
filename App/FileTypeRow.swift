import SwiftUI

struct FileTypeRow: View {
    @Binding var entry: FileTypeEntry
    let onDelete: (() -> Void)?
    @State private var showTemplateEditor = false
    @State private var extError: String? = nil

    static let templateColumnWidth: CGFloat = 56
    static let deleteColumnWidth: CGFloat = 24

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)

            Toggle("", isOn: $entry.enabled)
                .labelsHidden()
                .help("Show in the Finder menu")

            extensionField
                .frame(width: 110, alignment: .leading)

            TextField(
                "menu label",
                text: $entry.displayName,
                prompt: Text(FileTypeEntry.derivedDisplayName(ext: entry.ext))
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            .help("Label shown in the Finder menu")

            TextField(
                "filename",
                text: $entry.baseName,
                prompt: Text(entry.ext.isEmpty ? "filename" : ".\(entry.ext)")
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            .help("Filename for the created file. Blank creates a dotfile.")

            templateButton
                .frame(width: Self.templateColumnWidth)

            deleteColumn
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showTemplateEditor) {
            TemplateEditorSheet(extLabel: entry.ext, template: $entry.template)
        }
    }

    private var templateButton: some View {
        Button { showTemplateEditor = true } label: {
            Image(systemName: entry.template.isEmpty ? "doc" : "doc.text.fill")
                .foregroundStyle(entry.template.isEmpty ? Color.secondary : Color.accentColor)
        }
        .buttonStyle(.borderless)
        .help(entry.template.isEmpty
              ? "No template — new files start empty. Click to add one."
              : "Template configured — click to edit.")
    }

    @ViewBuilder
    private var deleteColumn: some View {
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .frame(width: Self.deleteColumnWidth)
            .help("Delete this custom type")
        } else {
            // Built-ins can be disabled but not deleted; keep column alignment.
            Color.clear.frame(width: Self.deleteColumnWidth, height: 16)
        }
    }

    @ViewBuilder
    private var extensionField: some View {
        if entry.isBuiltIn {
            HStack(spacing: 1) {
                Text(".").foregroundStyle(.secondary)
                Text(entry.ext)
            }
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
        } else {
            HStack(spacing: 1) {
                Text(".").foregroundStyle(.secondary)
                TextField("ext", text: $entry.ext)
                    .textFieldStyle(.plain)
                    .onChange(of: entry.ext) { newValue in
                        validateAndNormalize(newValue)
                    }
            }
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(extError == nil ? Color(nsColor: .separatorColor) : Color.red,
                                  lineWidth: 1)
            )
            .help(extError ?? "File extension (a-z, 0-9, . _ -)")
        }
    }

    private func validateAndNormalize(_ value: String) {
        do {
            let normalized = try FileTypeEntry.validateExtension(value)
            if normalized != entry.ext {
                entry.ext = normalized
            }
            extError = nil
        } catch let err as FileTypeEntry.ValidationError {
            extError = errorMessage(err)
        } catch {
            extError = "Invalid extension"
        }
    }

    private func errorMessage(_ err: FileTypeEntry.ValidationError) -> String {
        switch err {
        case .empty: return "Extension cannot be empty"
        case .tooLong: return "Extension too long (max 16 chars)"
        case .badCharacters: return "Allowed: a-z, 0-9, . _ -"
        }
    }
}
