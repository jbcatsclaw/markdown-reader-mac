import SwiftUI

@main
struct MarkdownReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}
