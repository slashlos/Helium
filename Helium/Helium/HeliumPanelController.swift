//
//  HeliumPanelController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//

import AppKit

internal struct Settings {
    internal class Setup<T> {
        private let key: String
        private var setting: T
        
        init(_ userDefaultsKey: String, value: T) {
            self.key = userDefaultsKey
            self.setting = value
        }
        
        var keyPath: String {
            get {
                return self.key
            }
        }
        var `default`: T {
            get {
                if let value = UserDefaults.standard.object(forKey: self.key) as? T {
                    return value
                } else {
                    // Sets existing setting if failed
                    return self.setting
                }
            }
        }
        var value: T {
            get {
                return self.setting
            }
            set (value) {
                self.setting = value
                //  Inform all interested parties for this panel's controller only only
                NotificationCenter.default.post(name: Notification.Name(rawValue: self.keyPath), object: nil)
            }
        }
    }
    
    let autoHideTitle = Setup<Bool>("autoHideTitle", value: false)
    let disabledFullScreenFloat = Setup<Bool>("disabledFullScreenFloat", value: false)
    let windowTitle = Setup<String>("windowTitle", value: "Helium")
    let windowStyle = Setup<Int>("windowStyle", value: 0)
    let opacityPercentage = Setup<Int>("opacityPercentage", value: 60)
    
    // See values in HeliumPanelController.TranslucencyPreference
    let translucencyPreference = Setup<HeliumPanelController.TranslucencyPreference>("rawTranslucencyPreference", value: .never)
}

class HeliumPanelController : NSWindowController,NSWindowDelegate {

    var settings:Settings = Settings()
    
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
        panel.isFloatingPanel = true
        settings.windowStyle.value = Int(panel.styleMask.rawValue)
        
        // Close button is loaded but hidden so we can close later
        panel.standardWindowButton(NSWindowButton.closeButton)!.isHidden = true
        
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

        // MARK: Load settings from panel.settings

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.setFloatOverFullScreenApps),
            name: NSNotification.Name(rawValue: settings.disabledFullScreenFloat.keyPath),
            object:nil)
        setFloatOverFullScreenApps()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.willUpdateTitleBar),
            name: NSNotification.Name(rawValue: settings.autoHideTitle.keyPath),
            object:nil)
        willUpdateTitleBar()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.didUpdateTitle(_:)),
            name: NSNotification.Name(rawValue: settings.windowTitle.keyPath),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.willUpdateTranslucency),
            name: NSNotification.Name(rawValue: settings.translucencyPreference.keyPath),
            object:nil)
        willUpdateTranslucency()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumPanelController.willUpdateAlpha),
            name: NSNotification.Name(rawValue: settings.opacityPercentage.keyPath),
            object:nil)
       willUpdateAlpha()

    }

    // MARK:- Mouse events
    override func mouseEntered(with theEvent: NSEvent) {
        if theEvent.modifierFlags.contains(.shift) {
            NSApp.activate(ignoringOtherApps: true)
        }
        mouseOver = true
        updateTranslucency()
        willUpdateTitleBar()
    }
    
    override func mouseExited(with theEvent: NSEvent) {
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
    
    @IBAction func autoHideTitlePress(_ sender: NSMenuItem) {
        settings.autoHideTitle.value = (sender.state == NSOffState)
    }
    @IBAction func floatOverFullScreenAppsPress(_ sender: NSMenuItem) {
        settings.disabledFullScreenFloat.value = (sender.state == NSOnState)
    }
    @IBAction func openLocationPress(_ sender: AnyObject) {
        didRequestLocation()
    }
    
    @IBAction func openFilePress(_ sender: AnyObject) {
        didRequestFile()
    }
    
    @IBAction func percentagePress(_ sender: NSMenuItem) {
        settings.opacityPercentage.value = sender.tag
    }

    @IBAction func translucencyPress(_ sender: NSMenuItem) {
        settings.translucencyPreference.value = HeliumPanelController.TranslucencyPreference(rawValue: sender.tag)!
        translucencyPreference = settings.translucencyPreference.value
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let appDelegate: AppDelegate = NSApp.delegate as! AppDelegate

        return appDelegate.validateMenuItem(menuItem)
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

        // Wind down all observations
        webView.removeObserver(delegate, forKeyPath: "estimatedProgress")
        NotificationCenter.default.removeObserver(delegate)
        NotificationCenter.default.removeObserver(self)
        
        return true
    }
    
    //MARK:- Actual functionality
    
    @objc func willUpdateTitleBar() {
        if settings.autoHideTitle.value == true {
            panel.titleVisibility = NSWindowTitleVisibility.hidden;
            panel.styleMask = NSWindowStyleMask.borderless
            panel.title = settings.windowTitle.value
        } else {
            panel.titleVisibility = NSWindowTitleVisibility.visible;
            panel.styleMask = NSWindowStyleMask(rawValue: UInt(settings.windowStyle.value))
            panel.title = settings.windowTitle.value
        }
    }
    
    @objc fileprivate func setFloatOverFullScreenApps() {
        if settings.disabledFullScreenFloat.value {
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        } else {
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
    }
   
    @objc fileprivate func didUpdateTitle(_ notification: Notification) {
        panel.title = settings.windowTitle.value
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
