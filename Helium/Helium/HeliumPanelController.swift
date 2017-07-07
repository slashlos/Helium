//
//  HeliumPanelController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
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
        panel.standardWindowButton(.closeButton)?.image = NSApp.applicationIconImage
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
            selector: #selector(HeliumPanelController.didUpdateUpdateURL(note:)),
            name: NSNotification.Name(rawValue: "HeliumDidUpdateURL"),
            object: nil)

    }

    func documentViewDidLoad() {
        // Moved later, called by view, when document is available
        setFloatOverFullScreenApps()
        
        willUpdateTitleBar()
        
        willUpdateTranslucency()
        
        willUpdateAlpha()
    }
    
    // MARK:- Mouse events
    override func mouseEntered(with theEvent: NSEvent) {
        if theEvent.modifierFlags.contains(.shift) {
            NSApp.activate(ignoringOtherApps: true)
            Swift.print(String(format: "mouse up %@", (self.window?.title)!))
        }
        Swift.print(String(format: "mouse in %@", (self.window?.title)!))
        mouseOver = true
        updateTranslucency()
        willUpdateTitleBar()
    }
    
    override func mouseExited(with theEvent: NSEvent) {
        Swift.print(String(format: "mouse ou %@", (self.window?.title)!))
        mouseOver = false
        updateTranslucency()
        willUpdateTitleBar()
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
        willUpdateTitleBar()
    }
    @IBAction func floatOverFullScreenAppsPress(_ sender: NSMenuItem) {
        settings.disabledFullScreenFloat.value = (sender.state == NSOnState)
        setFloatOverFullScreenApps()
    }
    @IBAction func openLocationPress(_ sender: AnyObject) {
        didRequestLocation()
    }
    
    @IBAction func openFilePress(_ sender: AnyObject) {
        didRequestFile()
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
        Swift.print(String(format: "hwc %@ %@", menuItem.title, menuItem.state == NSOnState ? "on" : "off"))
        return true;
    }

    //MARK:- Notifications
    @objc fileprivate func willUpdateAlpha() {
        let alpha = settings.opacityPercentage.value
        didUpdateAlpha(CGFloat(alpha))
    }
    @objc fileprivate func willUpdateTranslucency() {
        translucencyPreference = settings.translucencyPreference.value
        updateTranslucency()
    }
    
    func windowShouldClose(_ sender: Any) -> Bool {
        let webView = self.window?.contentView?.subviews.first as! MyWebView
        let delegate = webView.navigationDelegate as! NSObject
        panel.ignoresMouseEvents = true

        // Wind down all observations
        webView.removeObserver(delegate, forKeyPath: "estimatedProgress")
        NotificationCenter.default.removeObserver(delegate)
        NotificationCenter.default.removeObserver(self)
        
        return true
    }
    
    //MARK:- Actual functionality
    
    @objc func didUpdateUpdateURL(note: Notification) {
        let webView = self.window?.contentView?.subviews.first as! MyWebView

        if note.object as? URL == webView.url {
            self.willUpdateTitleBar()
        }
    }
    
    @objc func willUpdateTitleBar() {
        if settings.autoHideTitle.value == true && !mouseOver {
            panel.titleVisibility = NSWindowTitleVisibility.hidden;
            panel.titlebarAppearsTransparent = true
//            panel.styleMask = NSWindowStyleMask(rawValue: NSWindowStyleMask.fullSizeContentView.rawValue + panel.styleMask.rawValue)
            panel.styleMask = NSWindowStyleMask.borderless
        } else {
            panel.titleVisibility = NSWindowTitleVisibility.visible;
            panel.styleMask = panel.lastStyleMask
            
            let docIconButton = panel.standardWindowButton(.documentIconButton)
            if let doc = self.document {
                docIconButton?.image = (doc as! Document).displayImage
                panel.title = doc.displayName
            }
            else
            {
                docIconButton?.image = NSApp.applicationIconImage
            }
            panel.styleMask = panel.lastStyleMask
            panel.title = (document?.displayName)!
            
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
   
    fileprivate func didRequestFile() {
        
        let open = NSOpenPanel()
        open.allowsMultipleSelection = false
        open.canChooseFiles = true
        open.canChooseDirectories = false
        
        if open.runModal() == NSModalResponseOK {
            if let url = open.url {
                webViewController.loadURL(url:url)
            }
        }
    }
    
    fileprivate func didRequestLocation() {
        let appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
        
        appDelegate.didRequestUserUrl(RequestUserUrlStrings (
            currentURL: self.webViewController.currentURL,
            alertMessageText: "Enter new home Page URL",
            alertButton1stText: "Load",     alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.homePageURL.value),
                          onWindow: self.window as? HeliumPanel,
                          acceptHandler: { (newUrl: String) in
                            self.webViewController.loadURL(text: newUrl)
        }
        )
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
