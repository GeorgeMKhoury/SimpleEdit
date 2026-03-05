import SwiftUI
import AppKit

// MARK: - AppState

class AppState: ObservableObject {
    @Published var text = ""
    @Published var currentFilePath: URL?
    @Published var isDocumentEdited = false
    @Published var isWordWrap = true

    @Published var isAutoSaveEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoSaveEnabled, forKey: "AutoSave")
            setupAutoSave()
        }
    }
    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "DarkMode") }
    }
    @Published var fontName: String {
        didSet { UserDefaults.standard.set(fontName, forKey: "FontName") }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "FontSize") }
    }

    var errorHandler: ((String, String) -> Void)?

    // Incrementing this tells NativeTextEditor to push text to the NSTextView
    private(set) var externalTextVersion = 0

    private var autoSaveTimer: Timer?

    init() {
        let d = UserDefaults.standard
        isDarkMode = d.bool(forKey: "DarkMode")
        fontName = d.string(forKey: "FontName") ?? "Menlo"
        let size = d.double(forKey: "FontSize")
        fontSize = size > 0 ? size : 14.0
        isAutoSaveEnabled = d.bool(forKey: "AutoSave")
    }

    func newDocument() {
        text = ""
        currentFilePath = nil
        isDocumentEdited = false
        externalTextVersion += 1
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            text = try String(contentsOf: url, encoding: .utf8)
            currentFilePath = url
            isDocumentEdited = false
            externalTextVersion += 1
        } catch {
            errorHandler?("Error Opening File", error.localizedDescription)
        }
    }

    func saveDocument() {
        if let url = currentFilePath { save(to: url) } else { saveDocumentAs() }
    }

    func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = currentFilePath?.lastPathComponent ?? "Untitled.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        currentFilePath = url
        save(to: url)
    }

    func save(to url: URL) {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            isDocumentEdited = false
        } catch {
            errorHandler?("Error Saving File", error.localizedDescription)
        }
    }

    func insertTimeDate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a M/d/yyyy"
        NotificationCenter.default.post(name: .insertText, object: formatter.string(from: Date()))
    }

    func setupAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        guard isAutoSaveEnabled else { return }
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self, let url = self.currentFilePath else { return }
            self.save(to: url)
        }
    }
}

extension Notification.Name {
    static let insertText = Notification.Name("SimpleEditInsertText")
}

// MARK: - SimpleEditTextView

class SimpleEditTextView: NSTextView {
    var onFontChange: ((NSFont) -> Void)?

    override func changeFont(_ sender: Any?) {
        guard let fm = sender as? NSFontManager else { return }
        let newFont = fm.convert(font ?? NSFont.systemFont(ofSize: 14))
        self.font = newFont
        onFontChange?(newFont)
    }
}

// MARK: - NativeTextEditor

struct NativeTextEditor: NSViewRepresentable {
    @ObservedObject var state: AppState

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let size = scrollView.contentSize
        let tv = SimpleEditTextView(frame: NSRect(origin: .zero, size: size))
        tv.minSize = NSSize(width: 0, height: size.height)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: size.width, height: .greatestFiniteMagnitude)
        tv.isRichText = false
        tv.allowsUndo = true
        tv.usesFindPanel = true
        tv.delegate = context.coordinator

        let fontSize = CGFloat(state.fontSize)
        tv.font = NSFont(name: state.fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        let coordinator = context.coordinator
        tv.onFontChange = { font in coordinator.handleFontChange(font) }

        scrollView.documentView = tv
        context.coordinator.textView = tv
        context.coordinator.scrollView = scrollView

        coordinator.insertObserver = NotificationCenter.default.addObserver(
            forName: .insertText, object: nil, queue: .main
        ) { [weak tv] note in
            guard let text = note.object as? String, let tv else { return }
            tv.insertText(text, replacementRange: tv.selectedRange())
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? SimpleEditTextView else { return }
        let coordinator = context.coordinator

        // Push text only on explicit external changes (new/open), not during typing
        if coordinator.lastExternalVersion != state.externalTextVersion {
            tv.string = state.text
            coordinator.lastExternalVersion = state.externalTextVersion
        }

        // Sync font
        let fontSize = CGFloat(state.fontSize)
        let desired = NSFont(name: state.fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if tv.font != desired { tv.font = desired }

        // Sync word wrap
        let wantWrap = state.isWordWrap
        let isWrapping = tv.textContainer?.widthTracksTextView ?? true
        if wantWrap != isWrapping {
            if wantWrap {
                tv.isHorizontallyResizable = false
                tv.autoresizingMask = [.width]
                tv.textContainer?.widthTracksTextView = true
                tv.textContainer?.containerSize = NSSize(
                    width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
                tv.frame.size.width = scrollView.contentSize.width
                scrollView.hasHorizontalScroller = false
            } else {
                tv.isHorizontallyResizable = true
                tv.autoresizingMask = [.width, .height]
                tv.textContainer?.widthTracksTextView = false
                tv.textContainer?.containerSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                scrollView.hasHorizontalScroller = true
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    class Coordinator: NSObject, NSTextViewDelegate {
        let state: AppState
        weak var textView: SimpleEditTextView?
        weak var scrollView: NSScrollView?
        var lastExternalVersion = -1
        var insertObserver: Any?

        init(state: AppState) { self.state = state }

        deinit {
            if let obs = insertObserver { NotificationCenter.default.removeObserver(obs) }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            state.text = tv.string
            if !state.isDocumentEdited { state.isDocumentEdited = true }
        }

        func handleFontChange(_ font: NSFont) {
            state.fontName = font.fontName
            state.fontSize = Double(font.pointSize)
        }
    }
}

// MARK: - WindowConfigurator

struct WindowConfigurator: NSViewRepresentable {
    let title: String
    let isEdited: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = self.title
            window.isDocumentEdited = self.isEdited
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject var state: AppState
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showError = false

    var windowTitle: String {
        (state.currentFilePath?.lastPathComponent ?? "Untitled") + " - SimpleEdit"
    }

    var body: some View {
        NativeTextEditor(state: state)
            .frame(minWidth: 400, minHeight: 300)
            .background(WindowConfigurator(title: windowTitle, isEdited: state.isDocumentEdited))
            .preferredColorScheme(state.isDarkMode ? .dark : .light)
            .alert(errorTitle, isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                state.errorHandler = { title, message in
                    errorTitle = title
                    errorMessage = message
                    showError = true
                }
            }
    }
}

// MARK: - Find Panel Helper

class FindSender: NSObject {
    @objc var tag: Int
    init(_ tag: Int) { self.tag = tag }
}

// MARK: - EditorCommands

struct EditorCommands: Commands {
    @FocusedObject private var state: AppState?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") { state?.newDocument() }
                .keyboardShortcut("n", modifiers: .command)
            Button("Open…") { state?.openDocument() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Save") { state?.saveDocument() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Save As…") { state?.saveDocumentAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Toggle("Auto-save", isOn: Binding(
                get: { state?.isAutoSaveEnabled ?? false },
                set: { state?.isAutoSaveEnabled = $0 }
            ))
            .keyboardShortcut("s", modifiers: [.command, .option])
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Time/Date") { state?.insertTimeDate() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Menu("Find") {
                Button("Find…") {
                    NSApp.sendAction(
                        #selector(NSTextView.performFindPanelAction(_:)), to: nil, from: FindSender(1))
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") {
                    NSApp.sendAction(
                        #selector(NSTextView.performFindPanelAction(_:)), to: nil, from: FindSender(2))
                }
                .keyboardShortcut("g", modifiers: .command)
            }
        }

        CommandGroup(after: .toolbar) {
            Toggle("Dark Mode", isOn: Binding(
                get: { state?.isDarkMode ?? false },
                set: { state?.isDarkMode = $0 }
            ))
        }

        CommandMenu("Format") {
            Toggle("Word Wrap", isOn: Binding(
                get: { state?.isWordWrap ?? true },
                set: { state?.isWordWrap = $0 }
            ))
            Divider()
            Button("Font…") { NSFontManager.shared.orderFrontFontPanel(nil) }
                .keyboardShortcut("t", modifiers: .command)
        }
    }
}

// MARK: - App Entry Point

@main
struct SimpleEditApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .focusedObject(state)
        }
        .commands { EditorCommands() }
    }
}
