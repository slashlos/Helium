//
//  HeliumPanelController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import AppKit

class HeliumTitleDragButton : NSButton {
// https://developer.apple.com/library/archive/samplecode/PhotoEditor/Listings/Photo_Editor_WindowDraggableButton_swift.html#//apple_ref/doc/uid/TP40017384-Photo_Editor_WindowDraggableButton_swift-DontLinkElementID_22
override func mouseDown(with mouseDownEvent: NSEvent) {
    let window = self.window!
    let startingPoint = mouseDownEvent.locationInWindow
    
    highlight(true)
    
    // Track events until the mouse is up (in which we interpret as a click), or a drag starts (in which we pass off to the Window Server to perform the drag)
    var shouldCallSuper = false

    // trackEvents won't return until after the tracking all ends
    window.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: NSEvent.foreverDuration, mode: RunLoop.Mode.default) { event, stop in
        switch event?.type {
                case .leftMouseUp:
                    // Stop on a mouse up; post it back into the queue and call super so it can handle it
                    shouldCallSuper = true
                    NSApp.postEvent(event!, atStart: false)
                    stop.pointee = true
                
                case .leftMouseDragged:
                    // track mouse drags, and if more than a few points are moved we start a drag
                    let currentPoint = event!.locationInWindow
                    if let window = self.window,
                        let docIconButton = window.standardWindowButton(.documentIconButton),
                        let iconBasePoint = docIconButton.superview?.superview?.frame.origin {
                        let docIconFrame = docIconButton.frame
                        let iconFrame = NSMakeRect(iconBasePoint.x + docIconFrame.origin.x,
                                                   iconBasePoint.y + docIconFrame.origin.y,
                                                   docIconFrame.size.width, docIconFrame.size.height)
                        //  If we're over the docIconButton send event to it
                        if iconFrame.contains(startingPoint) {
                            let dragItem = NSDraggingItem.init(pasteboardWriter: self.window)
                            docIconButton.beginDraggingSession(with: [dragItem], event: event, source: self.window)
                            break
                        }
                     }
                    
                    if (abs(currentPoint.x - startingPoint.x) >= 5 || abs(currentPoint.y - startingPoint.y) >= 5) {
                        self.highlight(false)
                        stop.pointee = true
                        window.performDrag(with: event!)
                    }
                
                default:
                    break
            }
        }
                
        if (shouldCallSuper) {
            super.mouseDown(with: mouseDownEvent)
        }
    }
}

class HeliumPanelController : NSWindowController,NSWindowDelegate,NSPasteboardWriting {
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        <#code#>
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        <#code#>
    }
    

class HeliumPanelController : NSWindowController,NSWindowDelegate,NSFilePromiseProviderDelegate,NSDraggingSource,NSPasteboardWriting {
    var webViewController: WebViewController {
        get {
            return self.window?.contentViewController as! WebViewController
        }
    }
    var webView: MyWebView? {
        get {
            return self.webViewController.webView
        }
    }
    fileprivate var panel: HeliumPanel! {
        get {
            return (self.window as! HeliumPanel)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        shouldCascadeWindows = true
    }
    
    // MARK: Window lifecycle
    var hoverBar : PanelButtonBar?
    var titleDragButton : HeliumTitleDragButton?
    override func windowDidLoad() {
        //  Default to not dragging by content
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        
        //  Set up hover & buttons unless we're not a helium document
        guard !self.isKind(of: ReleasePanelController.self) else { return }
        panel.standardWindowButton(.closeButton)?.image = NSImage.init()
        
        //  Overlay title with our drag title button
        titleDragButton = HeliumTitleDragButton.init(frame: titleView!.frame)
        self.titleView?.superview?.addSubview(titleDragButton!)
        titleDragButton?.fit((titleView?.superview)!)
        titleDragButton?.isTransparent = true
        
        // place the hover bar
        hoverBar = PanelButtonBar.init(frame: NSMakeRect(5, 3, 80, 19))
        self.titleView?.superview?.addSubview(hoverBar!)
        
        //  We do not support a miniaturize button at this time; statically hide zoom
        miniaturizeButton?.isHidden = true
        zoomButton?.isHidden = UserSettings.HideZoomIcon.value
        
        //  we want our own hover bar of buttons (no mini or zoom was visible)
        if let panelButton = hoverBar!.closeButton, let windowButton = window?.standardWindowButton(.closeButton) {
            panelButton.target = windowButton.target
            panelButton.action = windowButton.action
        }
        
        setupTrackingAreas(true)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.didBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.willResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.didUpdateURL(note:)),
            name: NSNotification.Name(rawValue: "HeliumDidUpdateURL"),
            object: nil)

        //  We allow drag from title's document icon to self or Finder
        panel.registerForDraggedTypes([.URL, .fileURL])
    }

    func documentDidLoad() {
        // Moved later, called by view, when document is available
        setFloatOverFullScreenApps()
        
        willUpdateTitleBar()
        
        willUpdateTranslucency()
        
        willUpdateAlpha()
    }
    
    func windowDidMove(_ notification: Notification) {
        if (notification.object as! NSWindow) == self.window {
            self.doc?.settings.rect.value = (self.window?.frame)!
            cacheSettings()
        }
    }
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        if sender == self.window {
            var frame = sender.frame
            frame.size = frameSize

            settings.rect.value = frame
            cacheSettings()
        }
        return frameSize
    }
    
    func windowWillClose(_ notification: Notification) {
        self.webViewController.webView.stopLoading()
        
        if let hvc: WebViewController = window?.contentViewController as? WebViewController {
            hvc.setupTrackingAreas(false)
        }
        setupTrackingAreas(false)
    }
    
    // MARK:- Mouse events
    var closeButton : PanelButton? {
        get {
            return self.hoverBar?.closeButton
        }
    }
    var miniaturizeButton : PanelButton? {
        get {
            return self.hoverBar?.miniaturizeButton
        }
    }
    var zoomButton : PanelButton? {
        get {
            return self.hoverBar?.zoomButton
        }
    }
    var closeTrackingTag: NSView.TrackingRectTag?
    var miniTrackingTag:  NSView.TrackingRectTag?
    var zoomTrackingTag:  NSView.TrackingRectTag?
    var viewTrackingTag:  NSView.TrackingRectTag?
    var titleTrackingTag: NSView.TrackingRectTag?
    var titleView : NSView? {
        get {
            return self.window?.standardWindowButton(.closeButton)?.superview
        }
    }
    func setupTrackingAreas(_ establish : Bool) {
        if let tag = closeTrackingTag {
            closeButton?.removeTrackingRect(tag)
            closeTrackingTag = nil
        }
        if let tag = titleTrackingTag {
            titleView?.removeTrackingRect(tag)
            titleTrackingTag = nil
        }
        if establish {
            closeTrackingTag = closeButton?.addTrackingRect((closeButton?.bounds)!, owner: self, userData: nil, assumeInside: false)
            miniTrackingTag = miniaturizeButton?.addTrackingRect((miniaturizeButton?.bounds)!, owner: self, userData: nil, assumeInside: false)
            zoomTrackingTag = zoomButton?.addTrackingRect((zoomButton?.bounds)!, owner: self, userData: nil, assumeInside: false)
            titleTrackingTag = titleView?.addTrackingRect((titleView?.bounds)!, owner: self, userData: nil, assumeInside: false)
        }
    }

    // MARK:- Dragging
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingEntered(_ sender: NSDraggingInfo!) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly.rawValue]) {
            return .copy
        }
        return .copy
    }
    
    func performDragOperation(_ sender: NSDraggingInfo!) -> Bool {
        let webView = self.window?.contentView?.subviews.first as! MyWebView
        
        return webView.performDragOperation(sender)
    }

    func window(_ window: NSWindow, shouldDragDocumentWith event: NSEvent, from dragImageLocation: NSPoint, with pasteboard: NSPasteboard) -> Bool {
        pasteboard.clearContents()
        pasteboard.writeObjects([self])
        //let dragImage = document?.draggedImage ?? NSImage.init(named: k.Helium)
        //window.drag(dragImage!.resize(w: 32, h: 32), at: dragImageLocation, offset: .zero, event: event, pasteboard: pasteboard, source: self, slideBack: true)
        return true
    }
    
    // MARK:- Promise Provider
    public override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
        let url = window?.representedURL ?? URL.init(string: UserSettings.HomePageURL.value)
        let urlString = url!.lastPathComponent
        let fileName = String(format: "%@.webloc", urlString)
        return [fileName]
    }

    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        Swift.print("heliumWO type: \(type.rawValue)")
        switch type {
        default:
            return .promised
        }
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        Swift.print("listW type: \(type.rawValue)")
        switch type {
        case .data:
            return NSKeyedArchiver.archivedData(withRootObject: window?.representedURL as Any)
            
        case .promise:
            let promise = HeliumPromiseProvider.init(fileType: kUTTypeInternetLocation as String, delegate: self)
            return promise

        case .string:
            return window?.representedURL?.absoluteString
            
        default:
            Swift.print("unknown \(type)")
            return nil
        }
    }
    

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.data, .promise, .string]
    }
    
    // MARK: - NSFilePromiseProviderDelegate
    var promiseFilename : String {
        get {
            let url = window?.representedURL ?? URL.init(string: UserSettings.HomePageURL.value)!
            return url.lastPathComponent
        }
    }
    
    public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        let urlString = promiseFilename
        let fileName = String(format: "%@.webloc", urlString)
        return fileName
    }

    public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                                    writePromiseTo url: URL,
                                    completionHandler: @escaping (Error?) -> Void) {
        let urlString = String(format: """
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
    <plist version=\"1.0\">
    <dict>
    <key>URL</key>
    <string>%@</string>
    </dict>
    </plist>
    """, window?.representedURL?.absoluteString ?? UserSettings.HomePageURL.value)
        Swift.print("WindowDelegate -filePromiseProvider\n \(urlString)")

        do {
            try urlString.write(to: url, atomically: true, encoding: .utf8)
            completionHandler(nil)
        } catch let error {
            completionHandler(error)
        }
    }

    override func mouseEntered(with theEvent: NSEvent) {
        let hideTitle = (doc?.settings.autoHideTitle.value == true)
        if theEvent.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
            NSApp.activate(ignoringOtherApps: true)
        }
        let tag = theEvent.trackingNumber
        
        if let closeTag = self.closeTrackingTag, let miniTag = self.miniTrackingTag, let zoomTag = zoomTrackingTag/*, let viewTag = self.viewTrackingTag*/ {
            
            ///Swift.print(String(format: "%@ entered", (viewTag == tag ? "view" : "button")))

            switch tag {
            case closeTag:
                closeButton?.isMouseOver = true
                return
            case miniTag:
                miniaturizeButton?.isMouseOver = true
                return
            case zoomTag:
                zoomButton?.isMouseOver = true
                break
                
            default:
                let lastMouseOver = mouseOver
                closeButton?.isMouseOver = false
                miniaturizeButton?.isMouseOver = false
                zoomButton?.isMouseOver = false
                mouseOver = true
                updateTranslucency()
                
                //  view or title entered
                if hideTitle && (lastMouseOver != mouseOver) {
                    updateTitleBar(didChange: lastMouseOver != mouseOver)
                }
            }
        }
    }
    
    override func mouseExited(with theEvent: NSEvent) {
        let hideTitle = (doc?.settings.autoHideTitle.value == true)
        let location : NSPoint = theEvent.locationInWindow
        let tag = theEvent.trackingNumber

        if let closeTag = self.closeTrackingTag, let miniTag = self.miniTrackingTag, let zoomTag = zoomTrackingTag/*, let viewTag = self.viewTrackingTag*/ {

            ///Swift.print(String(format: "%@ exited", (viewTag == tag ? "view" : "button")))

            switch tag {
            case closeTag, miniTag, zoomTag:
                closeButton?.isMouseOver = false
                miniaturizeButton?.isMouseOver = false
                zoomButton?.isMouseOver = false
                break

            default:
                if let vSize = self.window?.contentView?.bounds.size {
                
                    //  If we exit to the title bar area we're still in side
                    if theEvent.trackingNumber == titleTrackingTag, let tSize = titleView?.bounds.size {
                        if location.x >= 0.0 && location.x <= (vSize.width) && location.y < ((vSize.height) + tSize.height) {
                            return
                        }
                    }
                    
                    var lastMouseOver = mouseOver
                    mouseOver = false
                    updateTranslucency()
                    
                    if ((titleView?.hitTest(theEvent.locationInWindow)) != nil) ||
                        ((self.window?.contentView?.hitTest(theEvent.locationInWindow)) != nil) {
                        //Swift.print("still here")
                        lastMouseOver = true
                        mouseOver = true
                    }
                    if hideTitle {
                        updateTitleBar(didChange: lastMouseOver != mouseOver)
                    }
                }
            }
        }
    }
    
    // MARK:- Translucency
    fileprivate var mouseOver: Bool = false {
        didSet {
            if (doc?.settings.autoHideTitle.value)! {
                updateTitleBar(didChange: true)
            }
        }
    }
    
    fileprivate var alpha: CGFloat = 0.6 { //default
        didSet {
            updateTranslucency()
        }
    }
    
    enum NewViewLocation : Int {
        case same = 0
        case window = 1
        case tab = 2
    }
    
    var translucencyPreference: TranslucencyPreference = .never {
        didSet {
             updateTranslucency()
        }
    }
    
    enum TranslucencyPreference: Int {
        case never = 0
        case always = 1
        case mouseOver = 2
        case mouseOutside = 3
        case offOver = -2
        case offOutside = -3
    }

    @objc fileprivate func updateTranslucency() {
        currentlyTranslucent = shouldBeTranslucent()
    }
    
    fileprivate var currentlyTranslucent: Bool = false {
        didSet {
            if !NSApplication.shared.isActive {
                panel.ignoresMouseEvents = currentlyTranslucent
            }
            if currentlyTranslucent {
                panel.animator().alphaValue = alpha
                panel.isOpaque = false
            } else {
                panel.isOpaque = true
                panel.animator().alphaValue = 1
            }
        }
    }

    fileprivate func shouldBeTranslucent() -> Bool {
        /* Implicit Arguments
         * - mouseOver
         * - translucencyPreference
         */
        
        switch translucencyPreference {
        case .never, .offOver, .offOutside:
            return false
        case .always:
            return true
        case .mouseOver:
            return mouseOver
        case .mouseOutside:
            return !mouseOver
        }
    }
    fileprivate func canBeTranslucent() -> Bool {
        switch translucencyPreference {
        case .never, .offOver, .offOutside:
            return false
        case .always, .mouseOver, .mouseOutside:
            return true
        }
    }
    
    fileprivate func shouldBeVisible() -> Bool {
        if doc?.settings.autoHideTitle.value == false {
            return true
        }
        else
        if ((self.contentViewController?.view.hitTest((NSApp.currentEvent?.locationInWindow)!)) != nil) {
            return false
        }
        else
        {
            return true
        }
    }
    //MARK:- IBActions
    
    fileprivate var doc: Document? {
        get {
            return self.document as? Document
        }
    }
    fileprivate var settings: Settings {
        get {
            if let doc = self.doc {
                return doc.settings
            }
            else
            {
                return Settings()
            }
        }
    }
    fileprivate func cacheSettings() {
        if let doc = self.doc, let url = doc.fileURL {
            doc.cacheSettings(url)
        }
    }
    @objc @IBAction func autoHideTitlePress(_ sender: NSMenuItem) {
        settings.autoHideTitle.value = (sender.state == .off)
        self.panel.titlebarAppearsTransparent = (sender.state == .off)
        mouseOver = false
        updateTitleBar(didChange: true)
        cacheSettings()
    }
    @objc @IBAction func floatOverFullScreenAppsPress(_ sender: NSMenuItem) {
        settings.disabledFullScreenFloat.value = (sender.state == .on)
        setFloatOverFullScreenApps()
        cacheSettings()
    }
    @objc @IBAction func percentagePress(_ sender: NSMenuItem) {
        settings.opacityPercentage.value = sender.tag
        willUpdateAlpha()
        cacheSettings()
    }
    
    @objc @IBAction func saveDocument(_ sender: NSMenuItem) {
        if let doc = self.doc {
            doc.save(sender)
        }
    }
    
    @objc @IBAction private func toggleTranslucencyPress(_ sender: NSMenuItem) {
        switch translucencyPreference {
        case .never:
            translucencyPreference = .always
            break
        case .always:
            translucencyPreference = .never
            break
        case .mouseOver:
            translucencyPreference = .offOver
            break
        case .mouseOutside:
            translucencyPreference = .offOutside
            break
        case .offOver:
            translucencyPreference = .mouseOver
            break
        case .offOutside:
            translucencyPreference = .mouseOutside
        }
        settings.translucencyPreference.value = translucencyPreference
        willUpdateTranslucency()
    }

    @objc @IBAction func translucencyPress(_ sender: NSMenuItem) {
        settings.translucencyPreference.value = HeliumPanelController.TranslucencyPreference(rawValue: sender.tag)!
        translucencyPreference = settings.translucencyPreference.value
        willUpdateTranslucency()
    }

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.title {
        case "Preferences":
            break
        case "Auto-hide Title Bar":
            menuItem.state = settings.autoHideTitle.value ? .on : .off
            break
        //Transluceny Menu
        case "Enabled":
            menuItem.state = canBeTranslucent() ? .on : .off
            break
        case "Never":
            menuItem.state = settings.translucencyPreference.value == .never ? .on : .off
            break
        case "Always":
            menuItem.state = settings.translucencyPreference.value == .always ? .on : .off
            break
        case "Mouse Over":
            let value = settings.translucencyPreference.value
            menuItem.state = value == .offOver
                ? .mixed
                : value == .mouseOver ? .on : .off
            break
        case "Mouse Outside":
            let value = settings.translucencyPreference.value
            menuItem.state = value == .offOutside
                ? .mixed
                : value == .mouseOutside ? .on : .off
            break
        case "Float Above All Spaces":
            menuItem.state = settings.disabledFullScreenFloat.value ? .off : .on
            break;
        case "Hide Helium in menu bar":
            menuItem.state = UserSettings.HideAppMenu.value ? .on : .off
            break
        case "Home Page":
            break
        case "Magic URL Redirects":
            menuItem.state = UserSettings.DisabledMagicURLs.value ? .off : .on
            break
        case "Save":
            break

        default:
            // Opacity menu item have opacity as tag value
            if menuItem.tag >= 10 {
                if let hwc = NSApp.keyWindow?.windowController {
                    menuItem.state = (menuItem.tag == (hwc as! HeliumPanelController).settings.opacityPercentage.value ? .on : .off)
                    menuItem.target = hwc
                }
                else
                {
                    menuItem.state = (menuItem.tag == settings.opacityPercentage.value ? .on : .off)
                    menuItem.target = self
                }
            }
            break
        }
        return true;
    }

    //MARK:- Notifications
    @objc func willUpdateAlpha() {
        didUpdateAlpha(settings.opacityPercentage.value)
        cacheSettings()
    }
    func willUpdateTitleBar() {
        guard let doc = self.doc else {
            return
        }
        
        //  synchronize prefs to document's panel state
        if doc.settings.autoHideTitle.value != (panel.titleVisibility != .hidden), !self.shouldBeVisible(){
            updateTitleBar(didChange:true)
        }
        

    }
    @objc func willUpdateTranslucency() {
        translucencyPreference = settings.translucencyPreference.value
        updateTranslucency()
        cacheSettings()
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let vindow = notification.object as? NSWindow,
            let wpc = vindow.windowController as? HeliumPanelController else { return }
        
        wpc.setupTrackingAreas(true)
        wpc.updateTranslucency()
        cacheSettings()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let vindow = window,
            let wvc = vindow.contentViewController as? WebViewController,
            let wpc = vindow.windowController as? HeliumPanelController,
            let webView = wvc.webView else { return false }
        
        vindow.ignoresMouseEvents = true
        wpc.setupTrackingAreas(false)
        
        //  Halt anything in progress
        guard let delegate = webView.navigationDelegate as? NSObject else { return true }
        assert(delegate == wvc, "webView delegate mismatch")

        //  Stop whatever is going on by brute force
        (panel.contentViewController as! WebViewController).viewWillDisappear()

        //  Propagate to super after removal
        wvc.setupTrackingAreas(false)
        
        // Wind down all observations
        NotificationCenter.default.removeObserver(self)
        
        return true
    }
    
    //MARK:- Actual functionality
    
    @objc func didUpdateURL(note: Notification) {
        let webView = self.window?.contentView?.subviews.first as! MyWebView

        if note.object as? URL == webView.url {
            self.updateTitleBar(didChange: false)
            cacheSettings()
        }
    }
    
    fileprivate func docIconToggle() {
        let docIconButton = panel.standardWindowButton(.documentIconButton)
        var mouseWasOver = mouseOver
        if !(NSApp.delegate as! AppDelegate).openForBusiness {
            mouseWasOver = true
        }

        if settings.autoHideTitle.value == true && !mouseWasOver {
            docIconButton?.isHidden = true
        }
        else
        {
            if let doc = self.doc {
                docIconButton?.image = doc.displayImage
            }
            else
            {
                docIconButton?.image = NSApp.applicationIconImage
            }
            docIconButton?.isHidden = false
            if let url = self.webView?.url, url.isFileURL {
                self.synchronizeWindowTitleWithDocumentName()
            }
        }
        cacheSettings()
    }
    
    @objc func updateTitleBar(didChange: Bool) {
        if didChange {/*
            if settings.autoHideTitle.value == true && !mouseOver {
                NSAnimationContext.runAnimationGroup({ (context) -> Void in
                    context.duration = 0.5
                    panel.animator().titleVisibility = NSWindow.TitleVisibility.hidden
                }, completionHandler: nil)
            } else {
                NSAnimationContext.runAnimationGroup({ (context) -> Void in
                    context.duration = 0.5
                    panel.animator().titleVisibility = NSWindow.TitleVisibility.visible
                }, completionHandler: nil)
            }*/
            self.titleView?.isHidden = !mouseOver
            self.titleDragButton?.isHidden = !mouseOver
         }
        docIconToggle()
    }
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        guard let doc = self.doc else {
            return displayName }
        
        switch self.doc!.docType {
        case .playlist, .release:
            return doc.displayName
        default:
            if let length = self.webView?.title?.count, length > 0 {
                return self.webView!.title!
            }
            return displayName
        }
    }
    @objc func setFloatOverFullScreenApps() {
        if settings.disabledFullScreenFloat.value {
            panel.collectionBehavior = [NSWindow.CollectionBehavior.moveToActiveSpace, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        } else {
            panel.collectionBehavior = [NSWindow.CollectionBehavior.canJoinAllSpaces, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        }
        cacheSettings()
    }
    
    @objc fileprivate func doPlaylistItem(_ notification: Notification) {
        if let playlist = notification.object {
            let playlistURL = playlist as! URL
            self.webViewController.loadURL(url: playlistURL)
        }
    }

    @objc fileprivate func didBecomeActive() {
        panel.ignoresMouseEvents = false
    }
    
    @objc fileprivate func willResignActive() {
        if currentlyTranslucent {
            panel.ignoresMouseEvents = true
        }
    }
    
    func didUpdateAlpha(_ intAlpha: Int) {
        alpha = CGFloat(intAlpha) / 100.0
    }
}

class ReleasePanelController : HeliumPanelController {

}

