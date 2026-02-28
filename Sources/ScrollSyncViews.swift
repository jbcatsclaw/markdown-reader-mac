import SwiftUI
import AppKit

// MARK: - Scrolling Text View (Editor)
// Wraps NSTextView to expose scroll position

struct ScrollingTextView: NSViewRepresentable {
    let text: Binding<String>
    var onScrollPositionChange: ((CGFloat) -> Void)?
    
    // Theme colors
    private let textColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
    private let bgColor = NSColor(red: 0.94, green: 0.94, blue: 0.95, alpha: 1.0)
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 14, height: 14)
        
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = textColor
        textView.backgroundColor = bgColor
        textView.drawsBackground = true
        
        textView.delegate = context.coordinator
        textView.string = text.wrappedValue
        
        scrollView.documentView = textView
        
        // Observe scroll position changes
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text.wrappedValue {
            let selectedRanges = textView.selectedRanges
            textView.string = text.wrappedValue
            textView.selectedRanges = selectedRanges
        }
    }
    
    func destroyNSView(_ scrollView: NSScrollView, context: Context) {
        NotificationCenter.default.removeObserver(context.coordinator)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScrollingTextView
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?
        private var isUpdatingText = false
        private var lastReportedFraction: CGFloat = -1
        
        init(_ parent: ScrollingTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard !isUpdatingText, let textView = notification.object as? NSTextView else { return }
            isUpdatingText = true
            parent.text.wrappedValue = textView.string
            isUpdatingText = false
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let scrollView = scrollView, let textView = textView else { return }
            
            let visibleRect = scrollView.documentVisibleRect
            let contentSize = textView.bounds.size
            
            guard contentSize.height > visibleRect.height else { return }
            
            let fraction = visibleRect.origin.y / (contentSize.height - visibleRect.height)
            let clampedFraction = max(0, min(1, fraction))
            
            // Avoid reporting same fraction (reduces noise)
            if abs(clampedFraction - lastReportedFraction) > 0.001 {
                lastReportedFraction = clampedFraction
                parent.onScrollPositionChange?(clampedFraction)
            }
        }
    }
}

// MARK: - Scrolling Preview View
// Wraps preview content in NSScrollView for programmatic scrolling

struct ScrollingPreviewView<Content: View>: View {
    let content: () -> Content
    var scrollToFraction: CGFloat?
    var onScrollPositionChange: ((CGFloat) -> Void)?

    init(
        @ViewBuilder content: @escaping () -> Content,
        scrollToFraction: CGFloat? = nil,
        onScrollPositionChange: ((CGFloat) -> Void)? = nil
    ) {
        self.content = content
        self.scrollToFraction = scrollToFraction
        self.onScrollPositionChange = onScrollPositionChange
    }

    var body: some View {
        ScrollingPreviewRepresentable(
            content: AnyView(content()),
            scrollToFraction: scrollToFraction,
            onScrollPositionChange: onScrollPositionChange
        )
    }
}

struct ScrollingPreviewRepresentable: NSViewRepresentable {
    let content: AnyView
    var scrollToFraction: CGFloat?
    var onScrollPositionChange: ((CGFloat) -> Void)?
    
    init<Content: View>(
        content: Content,
        scrollToFraction: CGFloat? = nil,
        onScrollPositionChange: ((CGFloat) -> Void)? = nil
    ) {
        self.content = AnyView(content)
        self.scrollToFraction = scrollToFraction
        self.onScrollPositionChange = onScrollPositionChange
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        
        // Create a hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = hostingView
        
        context.coordinator.scrollView = scrollView
        context.coordinator.hostingView = hostingView
        
        // Setup width constraint to match scroll view
        let widthConstraint = hostingView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        widthConstraint.isActive = true
        
        // Observe scroll position for bidirectional sync (optional)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Update content
        context.coordinator.hostingView?.rootView = content
        
        // Handle programmatic scroll
        if let fraction = scrollToFraction {
            context.coordinator.scrollToFraction(fraction)
        }
    }
    
    func destroyNSView(_ scrollView: NSScrollView, context: Context) {
        NotificationCenter.default.removeObserver(context.coordinator)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        var parent: ScrollingPreviewRepresentable
        weak var scrollView: NSScrollView?
        weak var hostingView: NSHostingView<AnyView>?
        private var lastReportedFraction: CGFloat = -1
        private var isProgrammaticScroll = false
        
        init(_ parent: ScrollingPreviewRepresentable) {
            self.parent = parent
        }
        
        func scrollToFraction(_ fraction: CGFloat) {
            guard let scrollView = scrollView, let documentView = scrollView.documentView else { return }
            
            let visibleHeight = scrollView.contentView.bounds.height
            let contentHeight = documentView.bounds.height
            
            guard contentHeight > visibleHeight else { return }
            
            let maxOffset = contentHeight - visibleHeight
            let targetOffset = fraction * maxOffset
            
            isProgrammaticScroll = true
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetOffset))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            
            // Reset after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.isProgrammaticScroll = false
            }
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard !isProgrammaticScroll, let scrollView = scrollView, let documentView = scrollView.documentView else { return }
            
            let visibleRect = scrollView.documentVisibleRect
            let contentHeight = documentView.bounds.height
            
            guard contentHeight > visibleRect.height else { return }
            
            let fraction = visibleRect.origin.y / (contentHeight - visibleRect.height)
            let clampedFraction = max(0, min(1, fraction))
            
            if abs(clampedFraction - lastReportedFraction) > 0.001 {
                lastReportedFraction = clampedFraction
                parent.onScrollPositionChange?(clampedFraction)
            }
        }
    }
}
