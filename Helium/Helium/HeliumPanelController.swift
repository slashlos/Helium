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
    var trackingTag: NSTrackingRectTag?
    
    func setupTrackingAreas(_ establish : Bool) {
        if let tag = trackingTag {
            closeButton?.removeTrackingRect(tag)
        }
        if establish {
            trackingTag = closeButton?.addTrackingRect((closeButton?.bounds)!, owner: self, userData: nil, assumeInside: false)
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
        if theEvent.modifierFlags.contains(.shift) {
            NSApp.activate(ignoringOtherApps: true)
        }
        let lastMouseOver = mouseOver
        mouseOver = true
        updateTranslucency()
        if doc?.settings.autoHideTitle.value == true && lastMouseOver != mouseOver {
            updateTitleBar(didChange: true)
        }
        if trackingTag == theEvent.trackingNumber {
            closeButton?.image = closeButtonImage
        }
    }
    
    override func mouseExited(with theEvent: NSEvent) {
        let lastMouseOver = mouseOver
        mouseOver = false
        updateTranslucency()
        if doc?.settings.autoHideTitle.value == true && lastMouseOver != mouseOver {
            updateTitleBar(didChange: true)
        }
        if trackingTag == theEvent.trackingNumber {
            closeButton?.image = nullImage
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
        case .never:
            return false
        case .always:
            return true
        case .mouseOver:
            return mouseOver
        case .mouseOutside:
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
            return doc!.settings
        }
    }
    @IBAction func autoHideTitlePress(_ sender: NSMenuItem) {
        settings.autoHideTitle.value = (sender.state == NSOffState)
        updateTitleBar(didChange: !mouseOver)
    }
    @IBAction func floatOverFullScreenAppsPress(_ sender: NSMenuItem) {
        settings.disabledFullScreenFloat.value = (sender.state == NSOnState)
        setFloatOverFullScreenApps()
    }    
    @IBAction func percentagePress(_ sender: NSMenuItem) {
        settings.opacityPercentage.value = sender.tag
        willUpdateAlpha()
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
        case "Never":
            menuItem.state = settings.translucencyPreference.value == .never ? NSOnState : NSOffState
            break
        case "Always":
            menuItem.state = settings.translucencyPreference.value == .always ? NSOnState : NSOffState
            break
        case "Mouse Over":
            menuItem.state = settings.translucencyPreference.value == .mouseOver ? NSOnState : NSOffState
            break
        case "Mouse Outside":
            menuItem.state = settings.translucencyPreference.value == .mouseOutside ? NSOnState : NSOffState
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
    
    func windowShouldClose(_ sender: Any) -> Bool {
        panel.ignoresMouseEvents = true
        
        //  Halt anything in progress
        if let wvc: WebViewController = self.contentViewController as? WebViewController,  let webView = wvc.webView {
            let delegate = webView.navigationDelegate as! NSObject

            //  Stop whatever is going on by brute force
            webView.stopLoading()
            webView.load(URLRequest.init(url: URL.init(string: "about:blank")!))
            
            //  Remove view tracking, observations
            webView.removeObserver(delegate, forKeyPath: "estimatedProgress")
            NotificationCenter.default.removeObserver(delegate)

            //  Propagate to super after removal
//            wvc.setupTrackingAreas(false)
       }
        
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
    
    @objc func updateTitleBar(didChange: Bool) {
        let docIconButton = panel.standardWindowButton(.documentIconButton)

        if didChange {
            if settings.autoHideTitle.value == true && !mouseOver {
                panel.titleVisibility = NSWindowTitleVisibility.hidden
                panel.titlebarAppearsTransparent = true
                self.window!.styleMask.formUnion(.fullSizeContentView)
                docIconButton?.isHidden = true
            } else {
                panel.titleVisibility = NSWindowTitleVisibility.visible
                panel.titlebarAppearsTransparent = false
                self.window!.styleMask.formSymmetricDifference(.fullSizeContentView)
            }
        }
        if settings.autoHideTitle.value == false || mouseOver {
            if let doc = self.document {
                docIconButton?.image = (doc as! Document).displayImage
            }
            else
            {
                docIconButton?.image = NSApp.applicationIconImage
            }
            docIconButton?.isHidden = false
            self.synchronizeWindowTitleWithDocumentName()
        }
    }
    
    @objc fileprivate func setFloatOverFullScreenApps() {
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
    
    fileprivate func didUpdateAlpha(_ newAlpha: CGFloat) {
        alpha = newAlpha / 100
    }
}
