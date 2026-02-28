import SwiftUI

struct MarkdownPreviewView: View {
    let markdown: String
    let searchText: String

    // Notion-like LIGHT theme palette
    private let bg = Color(red: 0.98, green: 0.98, blue: 0.98)
    private let panel = Color.white
    private let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.14)
    private let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.50)
    private let border = Color.black.opacity(0.08)
    private let accent = Color(red: 0.18, green: 0.18, blue: 0.20)
    private let codeBg = Color(red: 0.94, green: 0.94, blue: 0.96)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MarkdownRenderedView(markdown: markdown, searchText: searchText)
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading) // Max width for readability
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(bg)
        .foregroundColor(textPrimary)
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
    
    private let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.14)
    private let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.50)
    private let accent = Color(red: 0.18, green: 0.18, blue: 0.20)
    private let border = Color.black.opacity(0.08)
    private let codeBg = Color(red: 0.94, green: 0.94, blue: 0.96)
    
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
    
    private func inlineAttributed(_ content: String) -> AttributedString {
        // Parse inline markdown (bold, italic, code, links). Keep options minimal for compatibility.
        if let parsed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnly)
        ) {
            return parsed
        }
        return AttributedString(content)
    }

    @ViewBuilder
    private func renderLine(_ line: (type: LineType, content: String), index: Int) -> some View {
        let attString = inlineAttributed(line.content)

        switch line.type {
        case .heading1:
            Text(attString)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(textPrimary)
                .padding(.top, 24)
                .padding(.bottom, 12)
                .lineSpacing(4)
        case .heading2:
            Text(attString)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(textPrimary)
                .padding(.top, 20)
                .padding(.bottom, 10)
                .lineSpacing(3)
        case .heading3:
            Text(attString)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(textPrimary)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .lineSpacing(2)
        case .heading4:
            Text(attString)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(textPrimary)
                .padding(.top, 8)
                .padding(.bottom, 3)
        case .bullet:
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .foregroundColor(accent)
                Text(attString)
                    .lineSpacing(4)
            }
            .padding(.vertical, 2)
        case .numbered:
            Text(attString)
        case .codeBlock:
            Text(attString)
                .font(.system(.body, design: .monospaced))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(codeBg)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(border))
        case .blockquote:
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(accent.opacity(0.6))
                    .frame(width: 3)
                Text(attString)
                    .foregroundColor(textSecondary)
            }
            .padding(.vertical, 4)
        case .paragraph:
            Text(attString)
                .lineSpacing(6)
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
    
    private let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.14)
    
    var body: some View {
        // Fallback for macOS 13 - show raw text with basic styling
        Text(markdown)
            .font(.body)
            .foregroundColor(textPrimary)
            .lineSpacing(4)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Code Block Styling

struct CodeBlockView: View {
    let code: String
    let language: String?
    
    private let panel = Color.white
    private let border = Color.black.opacity(0.08)
    private let codeBg = Color(red: 0.94, green: 0.94, blue: 0.96)
    
    var body: some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(codeBg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(border, lineWidth: 1)
        )
    }
}
