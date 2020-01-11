//
//  HeliumPanelController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import AppKit

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        let components = (
            R: CGFloat((hex >> 16) & 0xff) / 255,
            G: CGFloat((hex >> 08) & 0xff) / 255,
            B: CGFloat((hex >> 00) & 0xff) / 255
        )
        self.init(red: components.R, green: components.G, blue: components.B, alpha: alpha)
    }
}

class HeliumTitleDragButton : NSButton {
/* https://developer.apple.com/library/archive/samplecode/PhotoEditor/Listings/
 *  Photo_Editor_WindowDraggableButton_swift.html#//
 *  apple_ref/doc/uid/TP40017384-Photo_Editor_WindowDraggableButton_swift-DontLinkElementID_22
 */
    //  once our controller appear, update
    var _hpc : HeliumPanelController?
    var hpc : HeliumPanelController? {
        get {
            return _hpc
        }
        set (value) {
            _hpc = value
            self.window?.contentView?.needsDisplay = true
        }
    }
    var borderColor : NSColor {
        get {
            guard let hpc = self.hpc else {
                return NSColor.clear
            }
            if let window = hpc.window, let url = window.representedURL, url.absoluteString != UserSettings.HomePageURL.value {
                if url.isFileURL {
                    return NSColor.controlColor
                } else {
                    return NSColor.clear
                }
            }
            else
            {
                return NSColor(hex: 0x44AAFF)///.white
            }
        }
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.cell?.controlView?.wantsLayer = true
        self.layer?.borderWidth = 2
        self.layer?.borderColor = borderColor.cgColor/// NSColor(hex: 0x44AAFF).cgColor
    }
      
    required init?(coder: NSCoder) {
        ///super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))

        super.draw(dirtyRect)
        
        guard let hpc = self.hpc else { return }
        
        if hpc.autoHideTitlePreference == .never || hpc.mouseOver {
            let color = self.borderColor
            self.layer?.borderColor = color.cgColor
            color.setStroke()
            path.stroke()
        }
    }
    
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
                        if iconFrame.contains(startingPoint), let hpc = hpc {
                            let dragItem = NSDraggingItem.init(pasteboardWriter: hpc)
                            dragItem.draggingFrame.size = NSMakeSize(32.0,32.0)
                            docIconButton.beginDraggingSession(with: [dragItem], event: event!, source: hpc)
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
    
    fileprivate func configureTitleDrag() {
        panel.standardWindowButton(.closeButton)?.image = NSImage.init()
        
        //  Overlay title with our drag title button if needed
        var dragFrame = titleView?.frame
        dragFrame?.size.height += 2
        dragFrame?.size.width += 2
        titleDragButton = HeliumTitleDragButton.init(frame: dragFrame!)
        self.contentViewController?.view.addSubview(titleDragButton!)
        titleDragButton?.top((titleDragButton?.superview)!)
        titleDragButton?.addSubview(titleView!)
        titleDragButton?.isTransparent = false
        titleDragButton?.isBordered = false
        titleView?.fit(titleDragButton!)
        titleDragButton?.hpc = self;
        titleDragButton?.title = ""

        // place the hover bar
        hoverBar = PanelButtonBar.init(frame: NSMakeRect(5, -3, 80, 19))
        self.titleView?.superview?.addSubview(hoverBar!)
        
        //  We do not support a miniaturize button at this time; statically hide zoom
        miniaturizeButton?.isHidden = true
        zoomButton?.isHidden = UserSettings.HideZoomIcon.value
        
        //  we want our own hover bar of buttons (no mini or zoom was visible)
        if let panelButton = hoverBar!.closeButton, let windowButton = window?.standardWindowButton(.closeButton) {
            panelButton.target = windowButton.target
            panelButton.action = windowButton.action
        }
    }
    
    override func windowDidLoad() {
        //  Default to not dragging by content
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        
        //  Set up hover & buttons unless we're not a helium document
        guard !self.isKind(of: ReleasePanelController.self) else { return }
        configureTitleDrag()
                
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
        panel.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0)})
        panel.registerForDraggedTypes([.promise, .URL, .fileURL])
    }

    func documentDidLoad() {
        // Moved later, called by view, when document is available
        mouseOver = false

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
        let options : [NSPasteboard.ReadingOptionKey: Any] =
            [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true,
             NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes : [
                kUTTypeImage, kUTTypeVideo, kUTTypeMovie]]
        let classes = [NSFilePromiseReceiver.self, NSURL.self]
        let pboard = sender.draggingPasteboard
        let items = pboard.pasteboardItems
        var handled = 0

        //  Handle promises first
        sender.enumerateDraggingItems(options: [], for: nil, classes: classes, searchOptions: options) {(draggingItem, _, _) in
            switch draggingItem.item {
            case let filePromiseReceiver as NSFilePromiseReceiver:
                filePromiseReceiver.receivePromisedFiles(atDestination: self.destinationURL, options: [:],
                                                         operationQueue: self.workQueue) { (fileURL, error) in
                    if let error = error {
                        self.handleError(error)
                    } else {
                        self.handleFile(at: fileURL)
                        handled += 1
                    }
                }
            case let fileURL as URL:
                self.handleFile(at: fileURL)
                handled += 1
            default: break
            }
        }
        return handled == items?.count ? true : false
    }

    func window(_ window: NSWindow, shouldDragDocumentWith event: NSEvent, from dragImageLocation: NSPoint, with pasteboard: NSPasteboard) -> Bool {
        if promiseURL.isFileURL { return true }
        pasteboard.clearContents()
        pasteboard.writeObjects([self.panel])
        let dragImage = doc?.displayImage ?? NSImage.init(named: k.Helium)
        window.drag(dragImage!.resize(w: 32, h: 32), at: dragImageLocation, offset: .zero, event: event, pasteboard: pasteboard, source: window, slideBack: true)
        ///window.standardWindowButton(.documentIconButton)?.dragPromisedFiles(ofTypes: ["fileloc","webloc"], from: dragImage!.alignmentRect, source: self, slideBack: true, event: event)

        return false
    }
    
    // MARK:- Promise Provider
    lazy var workQueue : OperationQueue = {
        let providerQueue = OperationQueue()
        providerQueue.qualityOfService = .userInitiated
        return providerQueue
    }()
    
    var promiseURL : URL {
        get {
            return window?.representedURL ?? URL.init(string: UserSettings.HomePageURL.value)!
        }
    }
    
    // directory URL used for accepting file promises
    private lazy var destinationURL: URL = {
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Drops")
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        return destinationURL
    }()

    // updates the canvas with a given image file
    private func handleFile(at url: URL) {
        ///let data = NSImageRep.init(contentsOf: url)
        let data = NSKeyedArchiver.archivedData(withRootObject: NSImage(contentsOf: url) as Any)
        OperationQueue.main.addOperation {
            self.webView?.load(data, mimeType: data.mimeType, characterEncodingName: "UTF16", baseURL: url)
        }
    }
        
    // displays an error
    private func handleError(_ error: Error) {
        OperationQueue.main.addOperation {
            if let window = self.window {
                self.presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                self.presentError(error)
            }
        }
    }

    //  MARK: Promise Handling

    var promiseContents : String {
        let htmlString = String(format: """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
        <plist version=\"1.0\">
        <dict>
        <key>URL</key>
        <string>%@</string>
        </dict>
        </plist>
        """, promiseURL.absoluteString)
        return htmlString
    }
    var promiseFilename : String {
        get {
            let url = self.promiseURL
            
            return url.isFileURL ? url.lastPathComponent : url.absoluteString
        }
    }
    var promiseType : String {
        get {
            return ((promiseURL.isFileURL ? kUTTypeSymLink : kUTTypeHTML) as String)
        }
    }
    
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
        let fileName = String(format: "%@.webloc", promiseFilename)
        return [fileName]
    }
    /*
    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        Swift.print("heliumWO type: \(type.rawValue)")
        switch type {
        default:
            return .promised
        }
    }
     https://www.google.com/search?q=big%20kid%20deluxe%20muslin%20fleece%20blanket
    */
    func pasteboardWriter(forPanel panel: HeliumPanel) -> NSPasteboardWriting {
        return promiseFilename as NSString
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        Swift.print("ppl type: \(type.rawValue)")
        switch type {
        case .promise:
            return NSKeyedArchiver.archivedData(withRootObject: promiseURL.absoluteString as NSString)
            
        case .files:
            return [promiseFilename]
 
        case .fileURL, .URL:
            return NSKeyedArchiver.archivedData(withRootObject: self.promiseURL)
            
        case .string:
            return self.promiseURL.absoluteString
            
        default:
            Swift.print("unknown \(type)")
            return nil
        }
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types : [NSPasteboard.PasteboardType] = [.fileURL, .URL, .string]

        types.append((promiseURL.isFileURL ? .files : .promise))
        Swift.print("wtp \(types)")
        return types
    }
    
    // MARK: - NSFilePromiseProviderDelegate
    public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        let urlString = promiseFilename
        let fileName = String(format: "%@.%@", urlString, promiseURL.isFileURL ? "fileloc" : "webloc")
        return fileName
    }
    
    public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                                    writePromiseTo url: URL,
                                    completionHandler: @escaping (Error?) -> Void) {
        let urlString = promiseContents
        Swift.print("WindowDelegate -filePromiseProvider\n \(urlString)")

        do {
            try urlString.write(to: url, atomically: true, encoding: .utf8)
            completionHandler(nil)
        } catch let error {
            completionHandler(error)
        }
    }
    
    public func promiseOperationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return self.workQueue
    }
    
    override func mouseEntered(with theEvent: NSEvent) {
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
                closeButton?.isMouseOver = false
                miniaturizeButton?.isMouseOver = false
                zoomButton?.isMouseOver = false
            }
        }
        
        DispatchQueue.main.async {
            self.mouseOver = true
        }
    }
    
    override func mouseExited(with theEvent: NSEvent) {
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
                }
            }
        }
        
        DispatchQueue.main.async {
            self.mouseOver = false
        }
    }
    
    // MARK:- Floating
    var floatAboveAllPreference: FloatAboveAllPreference {
        get {
            guard let doc : Document = self.doc else { return .spaces }
            return doc.settings.floatAboveAllPreference.value
        }
        set (value) {
            doc?.settings.floatAboveAllPreference.value = value
        }
    }
    struct FloatAboveAllPreference: OptionSet {
        let rawValue: Int
        
        static let spaces   = FloatAboveAllPreference(rawValue: 0)
        static let disabled = FloatAboveAllPreference(rawValue: 1)
        static let screen   = FloatAboveAllPreference(rawValue: 2)
    }
    let floatAboveAllSpaces : FloatAboveAllPreference = []

    // MARK:- Titling
    var autoHideTitlePreference: AutoHideTitlePreference {
        get {
            guard let doc : Document = self.doc else { return .never }
            return doc.settings.autoHideTitlePreference.value
        }
        set (value) {
            doc?.settings.autoHideTitlePreference.value = value
            updateTitleBar(didChange: true)
        }
    }
    enum AutoHideTitlePreference: Int {
        case never = 0
        case outside = 1
     }

    // MARK:- Translucency, AutoHideTitle Bar
    fileprivate dynamic var mouseOver: Bool = false {
        didSet {
            let hideTitle = autoHideTitlePreference != .never

            if let url = panel.representedURL, !url.isFileURL, url.absoluteString != UserSettings.HomePageURL.value {
                panel.titleVisibility = .hidden
                titleDragButton?.isBordered = false
                titleDragButton?.needsDisplay = true
                return
            }
            
            if let window = self.webView?.window {
                if autoHideTitlePreference == .outside {
                    window.titleVisibility =
                        (autoHideTitlePreference != .never)
                            ? mouseOver ? .visible : .hidden
                            : .visible
                    titleDragButton?.isHidden = !mouseOver
                    titleDragButton?.isBordered = mouseOver
                    titleDragButton?.needsDisplay = true
                }
                else
                {
                    window.titleVisibility = .visible
                    titleDragButton?.isHidden = false
                    titleDragButton?.isBordered = true
                    titleDragButton?.needsDisplay = true
                }
            }
            updateTranslucency()
            
            //  view or title entered
            if hideTitle { updateTitleBar(didChange: true) }

            docIconVisibility(mouseOver)
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
    
    var translucencyPreference: TranslucencyPreference {
        get {
            guard let doc : Document = self.doc else { return .never }
            return doc.settings.translucencyPreference.value
        }
        set (value) {
            doc?.settings.translucencyPreference.value = value
            updateTitleBar(didChange: true)
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
                panel.alphaValue = alpha
                panel.isOpaque = false
            } else {
                panel.isOpaque = true
                panel.alphaValue = 1
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
        /* Implicit Arguments
         * - mouseOver
         * - autoHideTitlePreference
         */

        switch autoHideTitlePreference {
        case .never:
            return true
        case .outside:
            return !mouseOver
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
        guard autoHideTitlePreference.rawValue != sender.tag else { return }
        
        let newTitlePref = HeliumPanelController.AutoHideTitlePreference(rawValue: sender.tag)!

        //  Make sure queue affects are immediately effective
        if autoHideTitlePreference == .outside {
            titleDragButton?.isTransparent = false
            titleDragButton?.isBordered = true
            titleDragButton?.needsDisplay = true
        }
        else
        {
            titleDragButton?.isTransparent = true
            titleDragButton?.isBordered = false
            titleDragButton?.needsDisplay = true
        }
        
        //  Presume false so our action result is immediate
        autoHideTitlePreference = newTitlePref

        updateTitleBar(didChange: true)
        cacheSettings()
    }
    
    @objc @IBAction func floatOverAllSpacesPress(_ sender: NSMenuItem) {
        if sender.state == .on {
            settings.floatAboveAllPreference.value.remove(.disabled)
        }
        else
        {
            settings.floatAboveAllPreference.value.insert(.disabled)
        }
        setFloatOverFullScreenApps()
        cacheSettings()
    }
    @objc @IBAction func floatOverFullScreenAppsPress(_ sender: NSMenuItem) {
        if sender.state == .on {
            settings.floatAboveAllPreference.value.remove(.screen)
        }
        else
        {
            settings.floatAboveAllPreference.value.insert(.screen)
        }
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
        willUpdateTranslucency()
    }

    @objc @IBAction func translucencyPress(_ sender: NSMenuItem) {
        translucencyPreference = HeliumPanelController.TranslucencyPreference(rawValue: sender.tag)!
        willUpdateTranslucency()
    }

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let autoHideTitleBarMenu = menuItem.menu?.title == "Auto-hide Title Bar"
        let translucenceMenu = menuItem.menu?.title == "Translucency"
        
        switch menuItem.title {
        case "Preferences":
            break
        //Transluceny Menu
        case "Enabled":
            menuItem.state = canBeTranslucent() ? .on : .off
            break
        //AutoHide / Transluceny Menu
        case "Never":
            if autoHideTitleBarMenu {
                menuItem.state = autoHideTitlePreference == .never ? .on : .off
            }
            else
            if translucenceMenu
            {
                menuItem.state = translucencyPreference == .never ? .on : .off
            }
            break
        case "Outside":
            if autoHideTitleBarMenu {
                menuItem.state = autoHideTitlePreference == .outside ? .on : .off
            }
            else
            if translucenceMenu
            {
                menuItem.state = translucencyPreference == .always ? .on : .off
            }
            break
        case "Mouse Over":
            menuItem.state = translucencyPreference == .offOver
                ? .mixed
                : translucencyPreference == .mouseOver ? .on : .off
            break
        case "Mouse Outside":
            menuItem.state = translucencyPreference == .offOutside
                ? .mixed
                : translucencyPreference == .mouseOutside ? .on : .off
            break
        case "All Spaces Disabled":
            menuItem.state = settings.floatAboveAllPreference.value.contains(.disabled) ? .on : .off
            break;
        case "Full Screen":
            menuItem.state = settings.floatAboveAllPreference.value.contains(.screen) ? .on : .off
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
        
        //  synchronize prefs to document's panel state
        let hideableTitle = autoHideTitlePreference != HeliumPanelController.AutoHideTitlePreference.never
        if hideableTitle != (panel.titleVisibility != .hidden), !self.shouldBeVisible() {
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

        wvc.clear()

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
    
    fileprivate func docIconVisibility(_ mouseWasOver: Bool) {
        if let docIconButton = panel.standardWindowButton(.documentIconButton) {
            //  initially keep doc & title vertically aligned
            if 0 == docIconButton.constraints.count, let titleView = self.titleView {
                docIconButton.vCenter(titleView)
            }
            
            if let doc = self.doc {
                 docIconButton.image = doc.displayImage.resize(w: 12, h: 12)
            }
            else
            {
                 docIconButton.image = NSApp.applicationIconImage.resize(w: 12, h: 12)
            }

            if autoHideTitlePreference == .outside {
                docIconButton.isHidden = !mouseWasOver
            }
            else
            {
                docIconButton.isHidden = false
                if let url = self.webView?.url, url.isFileURL {
                    self.synchronizeWindowTitleWithDocumentName()
                }
            }
        }
        cacheSettings()
    }
    
    @objc func updateTitleBar(didChange: Bool) {
        
        if let url = window?.representedURL, !url.isFileURL, url.absoluteString != UserSettings.HomePageURL.value {
            panel.titleVisibility = .hidden
            titleDragButton?.isTransparent = true
            titleDragButton?.isBordered = false
            if let docIconButton = panel.standardWindowButton(.documentIconButton) {
                docIconButton.isHidden = true
            }
            return
        }
        
        if didChange {
            if autoHideTitlePreference != .never && !mouseOver {
                DispatchQueue.main.async {
                    self.panel.titleVisibility = .hidden
                    self.titleView?.isHidden = true
                    self.titleDragButton?.isTransparent = true
                    self.titleDragButton?.isBordered = false
                 }
            } else {
                DispatchQueue.main.async {
                    self.panel.titleVisibility = .visible
                    self.titleView?.isHidden = false
                    self.titleDragButton?.isTransparent = false
                    self.titleDragButton?.isBordered = true
                }
            }
            self.titleDragButton?.needsDisplay = true
        }
        docIconVisibility(autoHideTitlePreference == .never || translucencyPreference == .never)
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
        if settings.floatAboveAllPreference.value.contains(.disabled) {
            panel.collectionBehavior = [NSWindow.CollectionBehavior.moveToActiveSpace, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        } else {
            panel.collectionBehavior = [NSWindow.CollectionBehavior.canJoinAllSpaces, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        }
        if settings.floatAboveAllPreference.value.contains(.screen) {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        } else {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
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

