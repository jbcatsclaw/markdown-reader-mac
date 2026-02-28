import SwiftUI

struct MarkdownPreviewView: View {
    let markdown: String
    let searchText: String

    // Match the Obsidian-like palette used in ContentView
    private let bg = Color(red: 0.05, green: 0.06, blue: 0.08)
    private let text = Color.white.opacity(0.92)

    var body: some View {
        ScrollView {
            MarkdownRenderedView(markdown: markdown, searchText: searchText)
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(bg)
        .foregroundColor(text)
    }
}

struct MarkdownRenderedView: View {
    let markdown: String
    let searchText: String
    
    var body: some View {
        if #available(macOS 14.0, *) {
            AttributedStringView(markdown: markdown, searchText: searchText)
        } else {
            LegacyMarkdownView(markdown: markdown, searchText: searchText)
        }
    }
}

// MARK: - macOS 14+ Using AttributedString

@available(macOS 14.0, *)
struct AttributedStringView: View {
    let markdown: String
    let searchText: String
    
    var body: some View {
        do {
            let attributed = try AttributedString(markdown: markdown, options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            ))
            
            Text(attributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .markdownStyle()
        } catch {
            Text(markdown)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Legacy macOS 13 View

struct LegacyMarkdownView: View {
    let markdown: String
    let searchText: String
    
    var body: some View {
        do {
            let attributed = try AttributedString(markdown: markdown)
            Text(attributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .markdownStyle()
        } catch {
            // Fallback to plain text
            Text(markdown)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Custom Markdown Styling

struct MarkdownStyling: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.white.opacity(0.92))
    }
}

extension View {
    func markdownStyle() -> some View {
        self.modifier(MarkdownStyling())
    }
}

// MARK: - Code Block Styling (Requires Custom Parser)

struct CodeBlockView: View {
    let code: String
    let language: String?
    
    var body: some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
