# Markdown Reader (macOS)

A lightweight, minimal Markdown reader/editor for macOS.

## What it is
- Left: rendered Markdown preview
- Right: raw Markdown editor (monospace)
- Open `.md` files, edit, and save (`⌘S`)
- Dark "obsidian metal" theme

## Build
This is a native SwiftUI app.

### Local (requires Xcode)
Open `MarkdownReader.xcodeproj` and run.

## Notes
- No network access.
- Rendering uses `AttributedString(markdown:)` for speed and simplicity.
