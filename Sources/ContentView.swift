import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var markdownText: String = ""
    @State private var currentFileName: String = "No File Open"
    @State private var currentFileURL: URL?
    @State private var recentFiles: [URL] = []
    @State private var searchText: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @State private var showOpenPanel: Bool = false
    @State private var saveRequestedTick: Int = 0

    // Obsidian-like palette (dark metal)
    private let bg = Color(red: 0.05, green: 0.06, blue: 0.08)
    private let panel = Color(red: 0.08, green: 0.09, blue: 0.12)
    private let border = Color.white.opacity(0.08)
    private let accent = Color(red: 0.36, green: 0.82, blue: 0.62)

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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
            
            // Recent files list
            List {
                if recentFiles.isEmpty {
                    Text("No recent files")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(recentFiles, id: \.self) { url in
                        Button(action: { openFile(url) }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.accentColor)
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
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
            
            Divider()
            
            // Open button
            Button(action: { showOpenPanel = true }) {
                Label("Open File...", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(panel)
    }
    
    // MARK: - Top bar / Split editor

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentFileName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let url = currentFileURL {
                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !markdownText.isEmpty {
                Text("\(wordCount) words")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
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
        .foregroundColor(.white.opacity(0.92))
    }

    private var splitEditor: some View {
        VStack(spacing: 0) {
            // Search row
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search in preview…", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white.opacity(0.92))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(panel)

            Divider().overlay(border)

            HSplitView {
                // Left: Preview
                MarkdownPreviewView(markdown: filteredMarkdown, searchText: searchText)
                    .frame(minWidth: 350)

                // Right: Editor
                editorView
                    .frame(minWidth: 350)
            }
        }
    }

    private var editorView: some View {
        TextEditor(text: $markdownText)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(14)
            .foregroundColor(.white.opacity(0.92))
            .background(panel.opacity(0.35))
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
                        .foregroundColor(.white.opacity(0.75))
                )
                .frame(width: 84, height: 84)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(border))

            Text("Open a Markdown file")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))

            Text("Drop a .md file here, or click Open.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))

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
                .foregroundColor(Color.black.opacity(0.85))
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
                    .foregroundColor(.white.opacity(0.9))
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
        // Keep preview simple: render full markdown; search is handled by preview layer.
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
            addToRecentFiles(url)
        } catch {
            print("Error reading file: \(error)")
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
