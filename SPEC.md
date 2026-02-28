# Markdown Reader for macOS — SPEC

## Goal
A lightweight, minimal, good-looking Markdown reader to run on the user's Mac.

## Default approach (proposed)
Native macOS app built with SwiftUI.

Rationale: smallest runtime footprint, best macOS integration, no Electron bloat.

## Scope
- Open local `.md` files and folders
- Render Markdown preview
- Basic navigation + search

## Non-goals
- Cloud sync
- Collaboration
- Full IDE features

## UX (draft)
- Sidebar: folder / recent files
- Main: rendered Markdown preview
- Top: filename, search

## Functional requirements
- Open file (via File > Open, drag-drop, or command-line `open`)
- Auto-reload on file change (optional)
- Search within document

## A11y
- Keyboard navigation
- Good focus states

## Acceptance criteria
- Can open and render common Markdown (headings, lists, code blocks, links)
- Handles at least a 1–2 MB markdown file without lag
- Works in dark mode

## Open questions (need user answers)
1) macOS version?
2) Xcode installed? (and OK to use it)
3) Desired features: (a) just preview (b) preview + raw editor (split view)
4) Preferred theme: neutral light/dark? accent color?
