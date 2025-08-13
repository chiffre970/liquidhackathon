import SwiftUI

struct NoteEditorView: View {
    @Binding var text: String
    let isRecording: Bool
    let onTextChange: (String) -> Void
    
    @State private var showFormattingBar = true
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if showFormattingBar {
                FormattingToolbar(
                    text: $text,
                    isFocused: _isFocused
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
            }
            
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    onTextChange(newValue)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        HStack {
                            Button(action: insertTimestamp) {
                                Image(systemName: "clock")
                            }
                            
                            Button(action: { insertMarkdown("**", "**") }) {
                                Image(systemName: "bold")
                            }
                            
                            Button(action: { insertMarkdown("*", "*") }) {
                                Image(systemName: "italic")
                            }
                            
                            Button(action: { insertMarkdown("- ") }) {
                                Image(systemName: "list.bullet")
                            }
                            
                            Button(action: { insertMarkdown("## ") }) {
                                Image(systemName: "number")
                            }
                            
                            Spacer()
                            
                            Button("Done") {
                                isFocused = false
                            }
                        }
                    }
                }
        }
        .background(Color.white)
    }
    
    private func insertTimestamp() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timestamp = "[\(formatter.string(from: Date()))] "
        text += timestamp
    }
    
    private func insertMarkdown(_ prefix: String, _ suffix: String = "") {
        if let selectedRange = getSelectedTextRange() {
            let startIndex = text.index(text.startIndex, offsetBy: selectedRange.lowerBound)
            let endIndex = text.index(text.startIndex, offsetBy: selectedRange.upperBound)
            let selectedText = String(text[startIndex..<endIndex])
            
            let replacement = prefix + selectedText + suffix
            text.replaceSubrange(startIndex..<endIndex, with: replacement)
        } else {
            text += prefix + suffix
        }
    }
    
    private func getSelectedTextRange() -> Range<Int>? {
        return nil
    }
}

struct FormattingToolbar: View {
    @Binding var text: String
    @FocusState var isFocused: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                FormatButton(icon: "bold", action: { insertFormat("**", "**") })
                FormatButton(icon: "italic", action: { insertFormat("*", "*") })
                FormatButton(icon: "strikethrough", action: { insertFormat("~~", "~~") })
                
                Divider()
                    .frame(height: 20)
                
                FormatButton(icon: "number", action: { insertFormat("## ") })
                FormatButton(icon: "list.bullet", action: { insertFormat("- ") })
                FormatButton(icon: "list.number", action: { insertFormat("1. ") })
                FormatButton(icon: "checkmark.square", action: { insertFormat("- [ ] ") })
                
                Divider()
                    .frame(height: 20)
                
                FormatButton(icon: "link", action: { insertFormat("[", "](url)") })
                FormatButton(icon: "quote.opening", action: { insertFormat("> ") })
                FormatButton(icon: "doc.text", action: { insertFormat("```\n", "\n```") })
            }
        }
    }
    
    private func insertFormat(_ prefix: String, _ suffix: String = "") {
        text += prefix + suffix
        isFocused = true
    }
}

struct FormatButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(Color.white)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
    }
}