import Cocoa

class NotepadTextView: NSTextView {
    // Intercept font changes from the NSFontPanel
    override func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        let oldFont = self.font ?? NSFont.systemFont(ofSize: 14)
        let newFont = fontManager.convert(oldFont)
        self.font = newFont
        
        // Persist the choice
        UserDefaults.standard.set(newFont.fontName, forKey: "FontName")
        UserDefaults.standard.set(Double(newFont.pointSize), forKey: "FontSize")
        UserDefaults.standard.synchronize()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var textView: NotepadTextView!
    var scrollView: NSScrollView!
    var currentFilePath: URL?
    var autoSaveTimer: Timer?
    
    var isAutoSaveEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "AutoSaveEnabled") }
        set { 
            UserDefaults.standard.set(newValue, forKey: "AutoSaveEnabled")
            setupAutoSave()
        }
    }
    
    var isDarkMode: Bool {
        get { UserDefaults.standard.bool(forKey: "DarkMode") }
        set {
            UserDefaults.standard.set(newValue, forKey: "DarkMode")
            updateAppearance()
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let windowSize = NSSize(width: 800, height: 600)
        let windowRect = NSRect(origin: .zero, size: windowSize)
        window = NSWindow(contentRect: windowRect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Untitled - Notepad"
        window.center()
        window.delegate = self
        
        // Setup Scroll View
        scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        
        // Setup Text View using our custom subclass
        let contentSize = scrollView.contentSize
        textView = NotepadTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // Load persistent font
        let fontName = UserDefaults.standard.string(forKey: "FontName") ?? "Menlo"
        let fontSize = UserDefaults.standard.double(forKey: "FontSize")
        let actualSize = fontSize > 0 ? CGFloat(fontSize) : 14
        textView.font = NSFont(name: fontName, size: actualSize) ?? NSFont.monospacedSystemFont(ofSize: actualSize, weight: .regular)

        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.delegate = self
        
        scrollView.documentView = textView
        window.contentView?.addSubview(scrollView)
        
        setupMenus()
        updateAppearance()
        setupAutoSave()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateAppearance() {
        if isDarkMode {
            window.appearance = NSAppearance(named: .darkAqua)
            textView.backgroundColor = .textBackgroundColor
            textView.textColor = .labelColor
        } else {
            window.appearance = NSAppearance(named: .aqua)
            textView.backgroundColor = .textBackgroundColor
            textView.textColor = .labelColor
        }
    }

    func updateWindowTitle() {
        let fileName = currentFilePath?.lastPathComponent ?? "Untitled"
        let editedIndicator = window.isDocumentEdited ? "*" : ""
        window.title = "\(editedIndicator)\(fileName) - Notepad"
    }

    func setupAutoSave() {
        autoSaveTimer?.invalidate()
        if isAutoSaveEnabled {
            autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                self?.performAutoSave()
            }
        }
    }

    @objc func performAutoSave() {
        guard let url = currentFilePath else { return }
        save(to: url)
    }

    func setupMenus() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Notepad", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Notepad", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        
        // File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "New", action: #selector(newDocument), keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem(title: "Open...", action: #selector(openDocument), keyEquivalent: "o"))
        fileMenu.addItem(NSMenuItem(title: "Save", action: #selector(saveDocument), keyEquivalent: "s"))
        fileMenu.addItem(NSMenuItem(title: "Save As...", action: #selector(saveDocumentAs), keyEquivalent: "S"))
        fileMenu.addItem(NSMenuItem.separator())
        let autoSaveItem = NSMenuItem(title: "Auto-save", action: #selector(toggleAutoSave), keyEquivalent: "")
        autoSaveItem.state = isAutoSaveEnabled ? .on : .off
        fileMenu.addItem(autoSaveItem)
        fileMenuItem.submenu = fileMenu
        
        // Edit Menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenu.addItem(NSMenuItem.separator())
        let timeDateItem = NSMenuItem(title: "Time/Date", action: #selector(insertTimeDate), keyEquivalent: "t")
        timeDateItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(timeDateItem)
        editMenu.addItem(NSMenuItem.separator())
        
        // Find Menu
        let findMenuItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "Find")
        let findItem = NSMenuItem(title: "Find...", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        findItem.tag = 1
        findMenu.addItem(findItem)
        let findNextItem = NSMenuItem(title: "Find Next", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
        findNextItem.tag = 2
        findMenu.addItem(findNextItem)
        findMenuItem.submenu = findMenu
        editMenu.addItem(findMenuItem)
        editMenuItem.submenu = editMenu

        // View Menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        let darkModeItem = NSMenuItem(title: "Dark Mode", action: #selector(toggleDarkMode), keyEquivalent: "")
        darkModeItem.state = isDarkMode ? .on : .off
        viewMenu.addItem(darkModeItem)
        viewMenuItem.submenu = viewMenu

        // Format Menu
        let formatMenuItem = NSMenuItem()
        mainMenu.addItem(formatMenuItem)
        let formatMenu = NSMenu(title: "Format")
        let wordWrapItem = NSMenuItem(title: "Word Wrap", action: #selector(toggleWordWrap(_:)), keyEquivalent: "w")
        wordWrapItem.state = .on
        formatMenu.addItem(wordWrapItem)
        formatMenu.addItem(NSMenuItem(title: "Font...", action: #selector(NSFontManager.orderFrontFontPanel(_:)), keyEquivalent: "t"))
        formatMenuItem.submenu = formatMenu
    }

    @objc func toggleDarkMode(_ sender: NSMenuItem) {
        isDarkMode = !isDarkMode
        sender.state = isDarkMode ? .on : .off
    }

    @objc func toggleAutoSave(_ sender: NSMenuItem) {
        isAutoSaveEnabled = !isAutoSaveEnabled
        sender.state = isAutoSaveEnabled ? .on : .off
    }

    @objc func toggleWordWrap(_ sender: NSMenuItem) {
        if sender.state == .on {
            sender.state = .off
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width, .height]
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            scrollView.hasHorizontalScroller = true
        } else {
            sender.state = .on
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.frame.size.width = scrollView.contentSize.width
            scrollView.hasHorizontalScroller = false
        }
    }

    @objc func insertTimeDate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a M/d/yyyy"
        let dateString = formatter.string(from: Date())
        textView.insertText(dateString, replacementRange: textView.selectedRange())
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Notepad"
        alert.informativeText = "Native macOS Notepad Clone\nBuilt with Swift & AppKit\n\nFeatures: Find/Replace, Word Wrap, Font Persistence, Time/Date Insert, Auto-save, Dark Mode."
        alert.runModal()
    }
    
    @objc func newDocument() {
        textView.string = ""
        currentFilePath = nil
        window.isDocumentEdited = false
        updateWindowTitle()
    }
    
    @objc func openDocument() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                textView.string = try String(contentsOf: url, encoding: .utf8)
                currentFilePath = url
                window.isDocumentEdited = false
                updateWindowTitle()
            } catch {
                showError("Error opening file", error.localizedDescription)
            }
        }
    }
    
    @objc func saveDocument() {
        if let url = currentFilePath { save(to: url) } else { saveDocumentAs() }
    }
    
    @objc func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = currentFilePath?.lastPathComponent ?? "Untitled.txt"
        if panel.runModal() == .OK, let url = panel.url {
            save(to: url)
            currentFilePath = url
            window.isDocumentEdited = false
            updateWindowTitle()
        }
    }
    
    func save(to url: URL) {
        do {
            try textView.string.write(to: url, atomically: true, encoding: .utf8)
            window.isDocumentEdited = false
            updateWindowTitle()
        }
        catch { showError("Error saving file", error.localizedDescription) }
    }

    func textDidChange(_ notification: Notification) {
        if !window.isDocumentEdited {
            window.isDocumentEdited = true
            updateWindowTitle()
        }
    }

    func showError(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApplication.shared.terminate(self)
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
