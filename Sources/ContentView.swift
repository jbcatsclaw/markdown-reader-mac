import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var markdownText: String = ""
    @State private var currentFileName: String = "No File Open"
    @State private var currentFileURL: URL?
    @State private var openFiles: [URL] = []  // Currently open documents (for tabs)
    @State private var recentFiles: [URL] = []
    @State private var searchText: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @State private var showOpenPanel: Bool = false
    @State private var saveRequestedTick: Int = 0

    // Notion-like LIGHT theme palette
    private let bg = Color(red: 0.98, green: 0.98, blue: 0.98)          // Near white background
    private let sidebarBg = Color(red: 0.96, green: 0.96, blue: 0.96)   // Sidebar background
    private let panel = Color.white                                      // Card/panel areas
    private let border = Color.black.opacity(0.08)                      // Subtle separators
    private let accent = Color(red: 0.18, green: 0.18, blue: 0.20)     // Dark gray accent
    private let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.14)
    private let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.50)

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            VStack(spacing: 0) {
                topBar
                Divider().overlay(border)

                if markdownText.isEmpty {
                    emptyStateView
                        .background(bg)
                } else {
                    splitEditor
                        .background(bg)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .background(bg)
        .tint(accent)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation {
                        columnVisibility = columnVisibility == .all ? .detailOnly : .all
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
            showOpenPanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            saveRequestedTick &+= 1
            saveCurrentFile()
        }
        .fileImporter(
            isPresented: $showOpenPanel,
            allowedContentTypes: [UTType(filenameExtension: "md") ?? .plainText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onAppear {
            loadRecentFiles()
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Files")
                .font(.headline)
                .foregroundColor(textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider().overlay(border)

            // Open Files section (closable tabs)
            if !openFiles.isEmpty {
                Section {
                    ForEach(openFiles, id: \.self) { url in
                        openFileRow(url: url)
                    }
                } header: {
                    Text("Open")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }
            }

            // Recent files list
            Section {
                List {
                    if recentFiles.isEmpty {
                        Text("No recent files")
                            .foregroundColor(textSecondary)
                            .italic()
                    } else {
                        ForEach(recentFiles, id: \.self) { url in
                            Button(action: { openFile(url) }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(accent)
                                    Text(url.lastPathComponent)
                                        .lineLimit(1)
                                        .foregroundColor(textPrimary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: removeRecentFile)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            } header: {
                Text("Recent")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            Spacer()

            Divider().overlay(border)

            // Open button
            Button(action: { showOpenPanel = true }) {
                Label("Open File...", systemImage: "folder")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(textPrimary)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(sidebarBg)
    }

    // MARK: - Open File Row (with close button)
    
    private func openFileRow(url: URL) -> some View {
        let isActive = currentFileURL == url
        
        return HStack(spacing: 8) {
            Button(action: { openFile(url) }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundColor(accent)
                        .font(.system(size: 12))
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                        .foregroundColor(isActive ? accent : textPrimary)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Close button (X)
            Button(action: { closeFile(url) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(textSecondary)
                    .frame(width: 18, height: 18)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close \(url.lastPathComponent)")
            .keyboardShortcut(.delete, modifiers: [])
            .accessibilityLabel("Close \(url.lastPathComponent)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.black.opacity(0.04) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Top bar / Split editor

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentFileName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                if let url = currentFileURL {
                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !markdownText.isEmpty {
                Text("\(wordCount) words")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(textSecondary)
            }

            Button {
                showOpenPanel = true
            } label: {
                Label("Open", systemImage: "folder")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(panel)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border))
            .cornerRadius(10)

            Button {
                saveCurrentFile()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(panel)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border))
            .cornerRadius(10)
            .disabled(currentFileURL == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(panel)
        .foregroundColor(textPrimary)
    }

    private var splitEditor: some View {
        VStack(spacing: 0) {
            // Search row
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(textSecondary)
                TextField("Search in preview…", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(panel)

            Divider().overlay(border)

            HSplitView {
                // Left: Editor
                editorView
                    .frame(minWidth: 350)

                // Right: Preview
                MarkdownPreviewView(markdown: filteredMarkdown, searchText: searchText)
                    .frame(minWidth: 350)
            }
        }
    }

    private var editorView: some View {
        TextEditor(text: $markdownText)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(14)
            .foregroundColor(textPrimary)
            .background(Color(red: 0.94, green: 0.94, blue: 0.95))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border))
            .cornerRadius(12)
            .padding(12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18)
                .fill(panel)
                .overlay(
                    Image(systemName: "doc.text")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(textSecondary)
                )
                .frame(width: 84, height: 84)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(border))

            Text("Open a Markdown file")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(textPrimary)

            Text("Drop a .md file here, or click Open.")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)

            HStack(spacing: 10) {
                Button {
                    showOpenPanel = true
                } label: {
                    Text("Open")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(accent)
                .foregroundColor(.white)
                .cornerRadius(10)

                if let url = recentFiles.first {
                    Button {
                        openFile(url)
                    } label: {
                        Text("Reopen last")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(panel)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(border))
                    .cornerRadius(10)
                    .foregroundColor(textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let item = providers.first else { return false }
            item.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard
                    let data,
                    let urlData = data as? Data,
                    let url = URL(dataRepresentation: urlData, relativeTo: nil)
                else { return }
                DispatchQueue.main.async {
                    openFile(url)
                }
            }
            return true
        }
    }
    
    // MARK: - Helpers
    
    private var wordCount: Int {
        let words = markdownText.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    private var filteredMarkdown: String {
        markdownText
    }

    private func saveCurrentFile() {
        guard let url = currentFileURL else { return }
        do {
            try markdownText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving file: \(error)")
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                openFile(url)
            }
        case .failure:
            break
        }
    }
    
    private func openFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            markdownText = content
            currentFileName = url.lastPathComponent
            currentFileURL = url
            
            // Add to openFiles if not already present
            if !openFiles.contains(url) {
                openFiles.insert(url, at: 0)
            }
            
            addToRecentFiles(url)
        } catch {
            print("Error reading file: \(error)")
        }
    }
    
    private func closeFile(_ url: URL) {
        // Remove from openFiles
        openFiles.removeAll { $0 == url }
        
        // If this was the current file, switch to next or show empty
        if currentFileURL == url {
            if let nextFile = openFiles.first {
                openFile(nextFile)
            } else {
                // No more open files - show empty state
                currentFileURL = nil
                currentFileName = "No File Open"
                markdownText = ""
            }
        }
    }
    
    private func addToRecentFiles(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > 10 {
            recentFiles = Array(recentFiles.prefix(10))
        }
        saveRecentFiles()
    }
    
    private func removeRecentFile(at offsets: IndexSet) {
        recentFiles.remove(atOffsets: offsets)
        saveRecentFiles()
    }
    
    private func loadRecentFiles() {
        if let data = UserDefaults.standard.data(forKey: "recentFiles"),
           let urls = try? JSONDecoder().decode([URL].self, from: data) {
            recentFiles = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }
    
    private func saveRecentFiles() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(data, forKey: "recentFiles")
        }
    }
}
