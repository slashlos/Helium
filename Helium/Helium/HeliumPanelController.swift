//
//  HeliumPanelController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright (c) 2017 Carlos D. Santiago. All rights reserved.
//

import AppKit

class HeliumPanelController : NSWindowController,NSWindowDelegate {

    var webViewController: WebViewController {
        get {
            return self.window?.contentViewController as! WebViewController
        }
    }
    var webView: MyWebView {
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
    override func windowDidLoad() {
        nullImage = NSImage.init()
        closeButton = window?.standardWindowButton(.closeButton)
        closeButtonImage = closeButton?.image
        setupTrackingAreas(true)

        //  Default to no dragging by content
        panel.isMovableByWindowBackground = false
        
        panel.standardWindowButton(.closeButton)?.image = nullImage
        panel.isFloatingPanel = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.didBecomeActive),
            name: NSNotification.Name.NSApplicationDidBecomeActive,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.willResignActive),
            name: NSNotification.Name.NSApplicationWillResignActive,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.didUpdateURL(note:)),
            name: NSNotification.Name(rawValue: "HeliumDidUpdateURL"),
            object: nil)

        //  We allow drag from title's document icon to self or Finder
        panel.registerForDraggedTypes([NSURLPboardType])
    }

    func documentViewDidLoad() {
        // Moved later, called by view, when document is available
        setFloatOverFullScreenApps()
        
        updateTitleBar(didChange:false)
        
        willUpdateTranslucency()
        
        willUpdateAlpha()
    }
    
    func windowDidMove(_ notification: Notification) {
        if (notification.object as! NSWindow) == self.window {
            self.doc?.settings.rect.value = (self.window?.frame)!
        }
    }

    func windowWillClose(_ notification: Notification) {
        self.webViewController.webView.stopLoading()
        
        if let hvc: WebViewController = window?.contentViewController as? WebViewController {
            hvc.setupTrackingAreas(false)
        }
        setupTrackingAreas(false)
    }
    
    // MARK:- Mouse events
    var closeButton : NSButton?
    var closeButtonImage : NSImage?
    var nullImage : NSImage?
    var closeTrackingTag: NSTrackingRectTag?
    var viewTrackingTag: NSTrackingRectTag?
    var titleTrackingTag: NSTrackingRectTag?
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
            titleTrackingTag = titleView?.addTrackingRect((titleView?.bounds)!, owner: self, userData: nil, assumeInside: false)
        }
    }

    func draggingEntered(_ sender: NSDraggingInfo!) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard()
        
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboardURLReadingFileURLsOnlyKey]) {
            return .copy
        }
        return .copy
    }
    
    func performDragOperation(_ sender: NSDraggingInfo!) -> Bool {
        let webView = self.window?.contentView?.subviews.first as! MyWebView
        
        return webView.performDragOperation(sender)
    }
        
    override func mouseEntered(with theEvent: NSEvent) {
        let hideTitle = (doc?.settings.autoHideTitle.value == true)
        if theEvent.modifierFlags.contains(.shift) {
            NSApp.activate(ignoringOtherApps: true)
        }

        if let closeTag = self.closeTrackingTag, let _ = self.viewTrackingTag {
            switch theEvent.trackingNumber {
            case closeTag:
                closeButton?.image = closeButtonImage
                break
                
            default:
                let lastMouseOver = mouseOver
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

        if let closeTag = self.closeTrackingTag, let _ = self.viewTrackingTag {
            switch theEvent.trackingNumber {
            case closeTag:
                closeButton?.image = nullImage
                break
                
            default:
                if let vSize = self.window?.contentView?.bounds.size {
                
                    //  If we exit to the title bar area we're still in side
                    if theEvent.trackingNumber == titleTrackingTag, let tSize = titleView?.bounds.size {
                        if location.x >= 0.0 && location.x <= (vSize.width) && location.y < ((vSize.height) + tSize.height) {
                            return
                        }
                    }
                    else
                    if theEvent.trackingNumber == viewTrackingTag {
                        if location.x >= 0.0 && location.x <= (vSize.width) && location.y > (vSize.height) {
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
                    /*
                    Swift.print(String(format: "%@ exited",
                                       (theEvent.trackingNumber == titleTrackingTag
                                        ? "title" : "view")))*/
                }
            }
        }
    }
    
    // MARK:- Translucency
    fileprivate var mouseOver: Bool = false
    
    fileprivate var alpha: CGFloat = 0.6 { //default
        didSet {
            updateTranslucency()
        }
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
            if !NSApplication.shared().isActive {
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
    @IBAction func autoHideTitlePress(_ sender: NSMenuItem) {
        settings.autoHideTitle.value = (sender.state == NSOffState)
    }
    @IBAction func floatOverFullScreenAppsPress(_ sender: NSMenuItem) {
        settings.disabledFullScreenFloat.value = (sender.state == NSOnState)
        setFloatOverFullScreenApps()
    }
    @IBAction func percentagePress(_ sender: NSMenuItem) {
        settings.opacityPercentage.value = sender.tag
        willUpdateAlpha()
    }
    
    @IBAction private func toggleTranslucencyPress(_ sender: NSMenuItem) {
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

    @IBAction func translucencyPress(_ sender: NSMenuItem) {
        settings.translucencyPreference.value = HeliumPanelController.TranslucencyPreference(rawValue: sender.tag)!
        translucencyPreference = settings.translucencyPreference.value
        willUpdateTranslucency()
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.title {
        case "Preferences":
            break
        case "Auto-hide Title Bar":
            menuItem.state = settings.autoHideTitle.value ? NSOnState : NSOffState
            break
        //Transluceny Menu
        case "Enabled":
            menuItem.state = canBeTranslucent() ? NSOnState : NSOffState
            break
        case "Never":
            menuItem.state = settings.translucencyPreference.value == .never ? NSOnState : NSOffState
            break
        case "Always":
            menuItem.state = settings.translucencyPreference.value == .always ? NSOnState : NSOffState
            break
        case "Mouse Over":
            let value = settings.translucencyPreference.value
            menuItem.state = value == .offOver
                ? NSMixedState
                : value == .mouseOver ? NSOnState : NSOffState
            break
        case "Mouse Outside":
            let value = settings.translucencyPreference.value
            menuItem.state = value == .offOutside
                ? NSMixedState
                : value == .mouseOutside ? NSOnState : NSOffState
            break
        case "Create New Windows":
            menuItem.state = UserSettings.createNewWindows.value ? NSOnState : NSOffState
            break
        case "Float Above All Spaces":
            menuItem.state = settings.disabledFullScreenFloat.value ? NSOffState : NSOnState
            break;
        case "Hide Helium in menu bar":
            menuItem.state = UserSettings.HideAppMenu.value ? NSOnState : NSOffState
            break
        case "Home Page":
            break
        case "Magic URL Redirects":
            menuItem.state = UserSettings.disabledMagicURLs.value ? NSOffState : NSOnState
            break
            
        default:
            // Opacity menu item have opacity as tag value
            if menuItem.tag >= 10 {
                if let hwc = NSApp.keyWindow?.windowController {
                    menuItem.state = (menuItem.tag == (hwc as! HeliumPanelController).settings.opacityPercentage.value ? NSOnState : NSOffState)
                    menuItem.target = hwc
                }
                else
                {
                    menuItem.state = (menuItem.tag == settings.opacityPercentage.value ? NSOnState : NSOffState)
                    menuItem.target = self
                }
            }
            break
        }
        return true;
    }

    //MARK:- Notifications
    @objc func willUpdateAlpha() {
        let alpha = settings.opacityPercentage.value
        didUpdateAlpha(CGFloat(alpha))
    }
    @objc func willUpdateTranslucency() {
        translucencyPreference = settings.translucencyPreference.value
        updateTranslucency()
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let vindow = notification.object as? NSWindow,
            let wpc = vindow.windowController as? HeliumPanelController else { return }
        
        wpc.setupTrackingAreas(true)
        wpc.updateTranslucency()
    }
    
    func windowShouldClose(_ sender: Any) -> Bool {
        guard let vindow = sender as? NSWindow,
            let wvc = vindow.contentViewController as? WebViewController,
            let wpc = vindow.windowController as? HeliumPanelController,
            let webView = wvc.webView else { return false }
        
        vindow.ignoresMouseEvents = true
        wpc.setupTrackingAreas(false)
        
        //  Halt anything in progress
        let delegate = webView.navigationDelegate as! NSObject
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
        }
    }
    
    fileprivate func docIconToggle() {
        let docIconButton = panel.standardWindowButton(.documentIconButton)

        if settings.autoHideTitle.value == false || mouseOver {
            if let doc = self.document {
                docIconButton?.image = (doc as! Document).displayImage
            }
            else
            {
                docIconButton?.image = NSApp.applicationIconImage
            }
            docIconButton?.isHidden = false
            if let url = self.webView.url, url.isFileURL {
                self.synchronizeWindowTitleWithDocumentName()
            }
        }
        else
        {
            docIconButton?.isHidden = true
        }
    }
    
    @objc func updateTitleBar(didChange: Bool) {
        if didChange {
            if settings.autoHideTitle.value == true && !mouseOver {
                NSAnimationContext.runAnimationGroup({ (context) -> Void in
                    context.duration = 0.2
                    panel.animator().titleVisibility = NSWindowTitleVisibility.hidden
                    panel.animator().titlebarAppearsTransparent = true
                    panel.animator().styleMask.formUnion(.fullSizeContentView)
                }, completionHandler: nil)
            } else {
                NSAnimationContext.runAnimationGroup({ (context) -> Void in
                    context.duration = 0.2
                    panel.animator().titleVisibility = NSWindowTitleVisibility.visible
                    panel.animator().titlebarAppearsTransparent = false
                    panel.animator().styleMask.formSymmetricDifference(.fullSizeContentView)
                }, completionHandler: nil)
            }
        }
        docIconToggle()
    }
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        switch (self.document as! Document).docType {
        case k.docRelease:
            return k.docReleaseName
        default:
            if let length = self.webView.title?.count, length > 0 {
                return self.webView.title!
            }
            return displayName
        }
    }
    @objc func setFloatOverFullScreenApps() {
        if settings.disabledFullScreenFloat.value {
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        } else {
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
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
    
    func didUpdateAlpha(_ newAlpha: CGFloat) {
        alpha = newAlpha / 100
    }
}
