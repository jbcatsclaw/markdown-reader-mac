import SwiftUI

struct MarkdownPreviewView: View {
    let markdown: String
    let searchText: String

    // Match the Obsidian-like palette used in ContentView
    private let bg = Color(red: 0.05, green: 0.06, blue: 0.08)
    private let panel = Color(red: 0.08, green: 0.09, blue: 0.12)
    private let text = Color.white.opacity(0.92)
    private let border = Color.white.opacity(0.08)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MarkdownRenderedView(markdown: markdown, searchText: searchText)
            }
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
            FullMarkdownView(markdown: markdown, searchText: searchText)
        } else {
            LegacyMarkdownView(markdown: markdown, searchText: searchText)
        }
    }
}

// MARK: - macOS 14+ Using Full Markdown Parsing

@available(macOS 14.0, *)
struct FullMarkdownView: View {
    let markdown: String
    let searchText: String
    
    // Use inlineOnly syntax (not inlineOnlyPreservingWhitespace) for better rendering
    // Note: AttributedString on SwiftUI has limitations with block-level elements.
    // For full block rendering, we parse line by line.
    private var parsedLines: [(type: LineType, content: String)] {
        parseMarkdownLines(markdown)
    }
    
    enum LineType {
        case heading1, heading2, heading3, heading4
        case bullet
        case numbered
        case codeBlock
        case blockquote
        case paragraph
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parsedLines.enumerated()), id: \.offset) { index, line in
                renderLine(line, index: index)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func renderLine(_ line: (type: LineType, content: String), index: Int) -> some View {
        let content = line.content
        let attString: AttributedString
        
        // Parse the content with inline markdown (bold, italic, code, links)
        // NOTE: keep options minimal for broad Xcode/Swift compatibility.
        if let parsed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnly)
        ) {
            attString = parsed
        } else {
            attString = AttributedString(content)
        }
        
        switch line.type {
        case .heading1:
            Text(attString)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white.opacity(0.95))
                .padding(.top, 16)
                .padding(.bottom, 8)
        case .heading2:
            Text(attString)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.93))
                .padding(.top, 14)
                .padding(.bottom, 6)
        case .heading3:
            Text(attString)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
                .padding(.top, 12)
                .padding(.bottom, 4)
        case .heading4:
            Text(attString)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.91))
                .padding(.top, 8)
                .padding(.bottom, 3)
        case .bullet:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundColor(Color(red: 0.36, green: 0.82, blue: 0.62))
                Text(attString)
            }
        case .numbered:
            Text(attString)
        case .codeBlock:
            let codeBg = Color(red: 0.08, green: 0.09, blue: 0.12)
            let codeBorder = Color.white.opacity(0.08)
            Text(attString)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(codeBg)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(codeBorder))
        case .blockquote:
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color(red: 0.36, green: 0.82, blue: 0.62).opacity(0.6))
                    .frame(width: 3)
                Text(attString)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 4)
        case .paragraph:
            Text(attString)
                .lineSpacing(4)
        }
    }
    
    private func parseMarkdownLines(_ text: String) -> [(type: LineType, content: String)] {
        var result: [(type: LineType, content: String)] = []
        let lines = text.components(separatedBy: .newlines)
        
        var inCodeBlock = false
        var codeBlockContent = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Code block handling
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    result.append((.codeBlock, codeBlockContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                    codeBlockContent = ""
                }
                inCodeBlock = !inCodeBlock
                continue
            }
            
            if inCodeBlock {
                codeBlockContent += line + "\n"
                continue
            }
            
            // Empty line
            if trimmed.isEmpty {
                continue
            }
            
            // Heading detection
            if trimmed.hasPrefix("# ") {
                result.append((.heading1, String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("## ") {
                result.append((.heading2, String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("### ") {
                result.append((.heading3, String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("#### ") {
                result.append((.heading4, String(trimmed.dropFirst(5))))
            }
            // Bullet list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                result.append((.bullet, String(trimmed.dropFirst(2))))
            }
            // Numbered list
            else if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                result.append((.numbered, trimmed))
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                result.append((.blockquote, String(trimmed.dropFirst(2))))
            }
            // Paragraph
            else {
                result.append((.paragraph, trimmed))
            }
        }
        
        return result
    }
}

// MARK: - Legacy macOS 13 View

struct LegacyMarkdownView: View {
    let markdown: String
    let searchText: String
    
    var body: some View {
        // Fallback for macOS 13 - show raw text with basic styling
        Text(markdown)
            .font(.body)
            .foregroundColor(.white.opacity(0.92))
            .lineSpacing(4)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Code Block Styling

struct CodeBlockView: View {
    let code: String
    let language: String?
    
    private let panel = Color(red: 0.08, green: 0.09, blue: 0.12)
    private let border = Color.white.opacity(0.08)
    
    var body: some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(panel)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(border, lineWidth: 1)
        )
    }
}
