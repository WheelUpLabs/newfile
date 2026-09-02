import SwiftUI

struct TemplateEditorSheet: View {
    let extLabel: String
    @Binding var template: String

    @State private var buffer: String
    private let hadTemplate: Bool
    @Environment(\.dismiss) private var dismiss

    init(extLabel: String, template: Binding<String>) {
        self.extLabel = extLabel
        self._template = template
        self._buffer = State(initialValue: template.wrappedValue)
        self.hadTemplate = !template.wrappedValue.isEmpty
    }

    private var title: String {
        extLabel.isEmpty ? "Template" : "Template for .\(extLabel)"
    }

    private var trimmedBuffer: String {
        buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Non-blocking hints only — an invalid template still saves.
    private var warning: String? {
        guard !trimmedBuffer.isEmpty else { return nil }
        switch extLabel {
        case "json":
            let ok = (try? JSONSerialization.jsonObject(
                with: Data(trimmedBuffer.utf8), options: [.fragmentsAllowed])) != nil
            return ok ? nil : "Not valid JSON yet — you can still save."
        case "sh":
            return trimmedBuffer.hasPrefix("#!")
                ? nil
                : "Tip: shell scripts usually start with a shebang, e.g. #!/bin/sh"
        default:
            return nil
        }
    }

    private var helperText: String {
        if let warning { return warning }
        return extLabel.isEmpty
            ? "The contents of every new file created with this type."
            : "The contents of every new .\(extLabel) file created with this type."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            TextEditor(text: $buffer)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .frame(minHeight: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.separator, lineWidth: 1)
                )
            Text(helperText)
                .font(.caption)
                .foregroundStyle(warning == nil ? AnyShapeStyle(.secondary)
                                                : AnyShapeStyle(Color.orange))
            HStack {
                if hadTemplate {
                    Button("Remove Template", role: .destructive) {
                        template = ""
                        dismiss()
                    }
                    .tint(.red)
                    .help("The type keeps working; new files start empty")
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Template") {
                    // Saving empty content removes the template — an empty
                    // template is indistinguishable from none.
                    template = buffer
                    dismiss()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(trimmedBuffer.isEmpty && !hadTemplate)
            }
        }
        .padding(20)
        .frame(minWidth: 560, idealWidth: 560, maxWidth: .infinity,
               minHeight: 420, idealHeight: 420, maxHeight: .infinity)
    }
}
