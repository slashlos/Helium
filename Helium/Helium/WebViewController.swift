//
//  WebViewController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import WebKit
import AVFoundation
import Carbon.HIToolbox

extension WKWebViewConfiguration {
    /// Async Factory method to acquire WKWebViewConfigurations packaged with system cookies
    static func cookiesIncluded(completion: @escaping (WKWebViewConfiguration?) -> Void) {
        let config = WKWebViewConfiguration()
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            completion(config)
            return
        }
        // Use nonPersistent() or default() depending on if you want cookies persisted to disk
        // and shared between WKWebViews of the same app (default), or not persisted and not shared
        // across WKWebViews in the same app.
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let waitGroup = DispatchGroup()
        for cookie in cookies {
            waitGroup.enter()
            if #available(OSX 10.13, *) {
                dataStore.httpCookieStore.setCookie(cookie) { waitGroup.leave() }
            } else {
                // Fallback on earlier versions
            }
        }
        waitGroup.notify(queue: DispatchQueue.main) {
            config.websiteDataStore = dataStore
            completion(config)
        }
    }
}

class MyWebView : WKWebView {
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    override class func handlesURLScheme(_ urlScheme: String) -> Bool {
        Swift.print("handleURLScheme: \(urlScheme)")
        return true
    }
    var selectedText : String?
    var selectedURL : URL?
    
    @objc internal func menuClicked(_ sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            Swift.print("Menu \(menuItem.title) clicked")
        }
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {

        //  Pick off javascript items we want to ignore or handle
        for title in ["Open Link", "Open Link in New Window", "Download Linked File"] {
            if let item = menu.item(withTitle: title) {
                if title == "Download Linked File" {
                    menu.removeItem(item)
                }
                else
                if title == "Open Link"
                {
                    item.action = #selector(MyWebView.openLinkInWindow(_:))
                    item.target = self
                }
                else
                {
                    item.tag = ViewOptions.w_view.rawValue
                    item.action = #selector(MyWebView.openLinkInNewWindow(_:))
                    item.target = self
                }
            }
        }

        publishApplicationMenu(menu);
    }
    
    @objc func openLinkInWindow(_ item: NSMenuItem) {
        if let urlString = self.selectedText, let url = URL.init(string: urlString) {
            load(URLRequest.init(url: url))
        }
        else
        if let url = self.selectedURL {
            load(URLRequest.init(url: url))
        }
      }
    
    @objc func openLinkInNewWindow(_ item: NSMenuItem) {
        if let urlString = self.selectedText, let url = URL.init(string: urlString) {
            appDelegate.openURLInNewWindow(url, attachTo: item.representedObject as? NSWindow)
        }
        else
        if let url = self.selectedURL {
            appDelegate.openURLInNewWindow(url, attachTo: item.representedObject as? NSWindow)
        }
    }
    
    override var mouseDownCanMoveWindow: Bool {
        get {
            if let window = self.window {
                return window.isMovableByWindowBackground
            }
            else
            {
                return false
            }
        }
    }
/*
    override func load(_ request: URLRequest) -> WKNavigation? {
        Swift.print("we got \(request)")
        return super.load(request)
    }
*/
    @IBAction internal func cut(_ sender: Any) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let urlString = self.url?.absoluteString {
            pb.setString(urlString, forType: NSPasteboard.PasteboardType.string)
            (self.uiDelegate as! WebViewController).clear()
        }
    }
    @IBAction internal func copy(_ sender: Any) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let urlString = self.url?.absoluteString {
            pb.setString(urlString, forType: NSPasteboard.PasteboardType.string)
        }
    }
    @IBAction internal func paste(_ sender: Any) {
        let pb = NSPasteboard.general
        guard let rawString = pb.string(forType: NSPasteboard.PasteboardType.string), rawString.isValidURL() else { return }
        
        self.load(URLRequest.init(url: URL.init(string: rawString)!))
    }
    @IBAction internal func delete(_ sender: Any) {
        self.cancelOperation(sender)
        Swift.print("cancel")
    }

    func next(url: URL) {
        let doc = self.window?.windowController?.document as? Document
        var nextURL = url

        //  Pick off request (non-file) urls first
        guard url.isFileURL else {
            
            if doc.fileType == "h3w" {
                doc.update(to: url)
            }

            self.load(URLRequest(url: url))
            return
        }
        
        //  Resolve alias before bookmarking
        if let original = (nextURL as NSURL).resolvedFinderAlias() { nextURL = original }

        if nextURL.isFileURL, appDelegate.isSandboxed() && !appDelegate.storeBookmark(url: nextURL) {
            Swift.print("Yoink, unable to sandbox \(nextURL)")
            return
        }
        
        self.load(URLRequest(url: nextURL))
        doc?.update(to: nextURL)
    }
    
    func text(_ text : String) {
        if FileManager.default.fileExists(atPath: text) {
            let url = URL.init(fileURLWithPath: text)
            next(url: url)
            return
        }
        
        if let url = URL.init(string: text) {
            next(url: url)
            return
        }
        
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                let wvc = self.window?.contentViewController
                (wvc as! WebViewController).loadAttributes(dict: json as! Dictionary<String, Any>)
                return
            } catch let error as NSError {
                NSApp.presentError(error)
                Swift.print(error)
            }
        }
        
        let html = String(format: """
<html>
<body>
<code>
%@
</code>
</body>
</html>
""", text);
        self.loadHTMLString(html, baseURL: nil)
    }
    
    // MARK: Drag and Drop - Before Release
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        appDelegate.newViewOptions = appDelegate.getViewOptions
//        Swift.print("draggingUpdated -> .copy")
        return .copy
    }
    // MARK: Drag and Drop - After Release
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let viewOptions = appDelegate.newViewOptions

        let pboard = sender.draggingPasteboard
        let items = pboard.pasteboardItems

        if (pboard.types?.contains(NSURLPboardType))! {
            for item in items! {

                if let urlString = item.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeUTF8PlainText as String)/*"public.utf8-plain-text"*/), !urlString.hasPrefix("file://") {
                    if let webloc = urlString.webloc {
                        self.next(url: webloc)
                    }
                    else
                    {
                        self.text(urlString)
                    }
                }
                else
                if let urlString = item.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeURL as String)/*"public.url"*/) {
                    self.next(url: URL(string: urlString)!)
                }
                else
                if let urlString = item.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeFileURL as String)/*"public.file-url"*/) {
                    if appDelegate.openForBusiness && viewOptions != sameWindow, let itemURL = URL.init(string: urlString) {
                        _ = appDelegate.doOpenFile(fileURL: itemURL, fromWindow: self.window)
                        continue
                    }
                    self.next(url: URL(string: urlString)!)
                }
                else
                if let urlString = item.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeData as String)), let url = urlString.webloc {
                    self.next(url: url)
                }
                else
/*
                kUTTypeURL as String,
                PlayList.className(),
                PlayItem.className(),
                NSFilenamesPboardType,
                NSFilesPromisePboardType,
                NSURLPboardType
*/
                if let text = item.string(forType: NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-url")) {
                    let data = item.data(forType: NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-url"))
                    let list = item.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-url"))

                    Swift.print("data \(String(describing: data))")
                    Swift.print("text \(String(describing: text))")
                    Swift.print("list \(String(describing: list))")
                    continue
                }
                else
                if let text = item.string(forType: NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-content-type")) {
                    let data = item.data(forType: NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-content-type"))
                    let list = item.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "com.apple.pasteboard.promised-file-content-type"))

                    Swift.print("data \(String(describing: data))")
                    Swift.print("text \(String(describing: text))")
                    Swift.print("list \(String(describing: list))")
                    continue
                }
                else
                {
                    for type in item.types {
                        let data = item.data(forType: type)
                        let text = item.string(forType: type)
                        let list = item.propertyList(forType: type)
                        
                        Swift.print("data \(String(describing: data))")
                        Swift.print("text \(String(describing: text))")
                        Swift.print("list \(String(describing: list))")
                    }
                    continue
                }
            }
        }
        else
            if (pboard.types?.contains(NSPasteboard.PasteboardType(rawValue: "NSPasteboardURLReadingFileURLsOnlyKey")))! {
            Swift.print("we have NSPasteboardURLReadingFileURLsOnlyKey")
//          NSApp.delegate?.application!(NSApp, openFiles: items! as [String])
        }
        else
        if ((pboard.types?.contains(NSPasteboard.PasteboardType(rawValue: kUTTypeUTF8PlainText as String)))!) {
            if let urlString = pboard.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeUTF8PlainText as String)/*"public.utf8-plain-text"*/) {
                if let webloc = urlString.webloc {
                    self.next(url: webloc)
                }
                else
                {
                    self.text(urlString)
                }
            }
        }
        return true
    }
    
    //  MARK: Context Menu
    //
    //  Intercepted actions; capture state needed for avToggle()
    var playPressMenuItem = NSMenuItem()
    @IBAction func playActionPress(_ sender: NSMenuItem) {
//        Swift.print("\(playPressMenuItem.title) -> target:\(String(describing: playPressMenuItem.target)) action:\(String(describing: playPressMenuItem.action)) tag:\(playPressMenuItem.tag)")
        _ = playPressMenuItem.target?.perform(playPressMenuItem.action, with: playPressMenuItem.representedObject)
        //  this releases original menu item
        sender.representedObject = self
        let notif = Notification(name: Notification.Name(rawValue: "HeliumItemAction"), object: sender)
        NotificationCenter.default.post(notif)
    }
    
    var mutePressMenuItem = NSMenuItem()
    @IBAction func muteActionPress(_ sender: NSMenuItem) {
//        Swift.print("\(mutePressMenuItem.title) -> target:\(String(describing: mutePressMenuItem.target)) action:\(String(describing: mutePressMenuItem.action)) tag:\(mutePressMenuItem.tag)")
        _ = mutePressMenuItem.target?.perform(mutePressMenuItem.action, with: mutePressMenuItem.representedObject)
        //  this releases original menu item
        sender.representedObject = self
        let notif = Notification(name: Notification.Name(rawValue: "HeliumItemAction"), object: sender)
        NotificationCenter.default.post(notif)
    }
    
    //
    //  Actions used by contextual menu, or status item, or our app menu
    func publishApplicationMenu(_ menu: NSMenu) {
        let wvc = self.window?.contentViewController as! WebViewController
        let hpc = self.window?.windowController as! HeliumPanelController
        let doc = hpc.document as! Document
        let translucency = doc.settings.translucencyPreference.value
        
        //  Remove item(s) we cannot support
        for title in ["Enter Picture in Picture", "Download Video"] {
            if let item = menu.item(withTitle: title) {
                menu.removeItem(item)
            }
        }
        //  Alter item(s) we want to support
        for title in ["Enter Full Screen", "Open Video in New Window"] {
            if let item = menu.item(withTitle: title) {
//                Swift.print("old: \(title) -> target:\(String(describing: item.target)) action:\(String(describing: item.action)) tag:\(item.tag)")
                if item.title == "Enter Full Screen" {
                    item.target = appDelegate
                    item.action = #selector(appDelegate.toggleFullScreen(_:))
                }
                else
                if self.url != nil {
                    item.representedObject = self.url
                    item.target = appDelegate
                    item.action = #selector(appDelegate.openVideoInNewWindowPress(_:))
                }
                else
                {
                    item.isEnabled = false
                }
//                Swift.print("new: \(title) -> target:\(String(describing: item.target)) action:\(String(describing: item.action)) tag:\(item.tag)")
            }
        }
        
        //  Intercept these actions so we can record them for later
        //  NOTE: cache original menu item so it does not disappear
        for title in ["Play", "Pause", "Mute"] {
            if let item = menu.item(withTitle: title) {
                if item.title == "Mute" {
                    mutePressMenuItem.action = item.action
                    mutePressMenuItem.target = item.target
                    mutePressMenuItem.title = item.title
                    mutePressMenuItem.state = item.state
                    mutePressMenuItem.tag = item.tag
                    mutePressMenuItem.representedObject = item
                    item.action = #selector(self.muteActionPress(_:))
                    item.target = self
                }
                else
                {
                    playPressMenuItem.action = item.action
                    playPressMenuItem.target = item.target
                    playPressMenuItem.title = item.title
                    playPressMenuItem.state = item.state
                    playPressMenuItem.tag = item.tag
                    playPressMenuItem.representedObject = item
                    item.action = #selector(self.playActionPress(_:))
                    item.target = self
                }
//                let state = item.state == OnState ? "yes" : "no"
//                Swift.print("target: \(title) -> \(String(describing: item.action)) state: \(state) tag:\(item.tag)")
            }
        }
        var item: NSMenuItem

        item = NSMenuItem(title: "Cut", action: #selector(MyWebView.cut(_:)), keyEquivalent: "")
        menu.addItem(item)
        item = NSMenuItem(title: "Copy", action: #selector(MyWebView.copy(_:)), keyEquivalent: "")
        menu.addItem(item)
        item = NSMenuItem(title: "Paste", action: #selector(MyWebView.paste(_:)), keyEquivalent: "")
        menu.addItem(item)
        menu.addItem(NSMenuItem.separator())

        item = NSMenuItem(title: "Open", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subOpen = NSMenu()
        item.submenu = subOpen

        item = NSMenuItem(title: "File…", action: #selector(WebViewController.openFilePress(_:)), keyEquivalent: "")
        item.target = wvc
        subOpen.addItem(item)

        item = NSMenuItem(title: "File in new window…", action: #selector(WebViewController.openFilePress(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.shift
        item.isAlternate = true
        item.target = wvc
        item.tag = 1
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "File in new tab…", action: #selector(WebViewController.openFilePress(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
        item.isAlternate = true
        item.target = wvc
        item.tag = 3
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "URL…", action: #selector(WebViewController.openLocationPress(_:)), keyEquivalent: "")
        item.target = wvc
        subOpen.addItem(item)

        item = NSMenuItem(title: "URL in new window…", action: #selector(WebViewController.openLocationPress(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.shift
        item.isAlternate = true
        item.target = wvc
        item.tag = 1
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "URL in new tab…", action: #selector(WebViewController.openLocationPress(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
        item.isAlternate = true
        item.target = wvc
        item.tag = 3
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Window", action: #selector(appDelegate.newDocument(_:)), keyEquivalent: "")
        item.target = appDelegate
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Tab", action: #selector(appDelegate.newDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
        item.target = appDelegate
        item.isAlternate = true
        item.tag = 3
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Window", action: #selector(appDelegate.newDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
        item.target = appDelegate
        item.isAlternate = true
        item.tag = 1
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Playlists", action: #selector(AppDelegate.presentPlaylistSheet(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = appDelegate
        menu.addItem(item)

        item = NSMenuItem(title: "Appearance", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subPref = NSMenu()
        item.submenu = subPref

        item = NSMenuItem(title: "Auto-hide Title Bar", action: #selector(hpc.autoHideTitlePress(_:)), keyEquivalent: "")
        item.state = doc.settings.autoHideTitle.value ? OnState : OffState
        item.target = hpc
        subPref.addItem(item)

        item = NSMenuItem(title: "Float Above All Spaces", action: #selector(hpc.floatOverFullScreenAppsPress(_:)), keyEquivalent: "")
        item.state = doc.settings.disabledFullScreenFloat.value ? OffState : OnState
        item.target = hpc
        subPref.addItem(item)
        
        item = NSMenuItem(title: "User Agent", action: #selector(wvc.userAgentPress(_:)), keyEquivalent: "")
        item.target = wvc
        subPref.addItem(item)
        
        item = NSMenuItem(title: "Translucency", action: #selector(menuClicked(_:)), keyEquivalent: "")
        subPref.addItem(item)
        let subTranslucency = NSMenu()
        item.submenu = subTranslucency

        item = NSMenuItem(title: "Opacity", action: #selector(menuClicked(_:)), keyEquivalent: "")
        let opacity = doc.settings.opacityPercentage.value
        subTranslucency.addItem(item)
        let subOpacity = NSMenu()
        item.submenu = subOpacity

        item = NSMenuItem(title: "10%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (10 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 10
        subOpacity.addItem(item)
        item = NSMenuItem(title: "20%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.isEnabled = translucency.rawValue > 0
        item.state = (20 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 20
        subOpacity.addItem(item)
        item = NSMenuItem(title: "30%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (30 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 30
        subOpacity.addItem(item)
        item = NSMenuItem(title: "40%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (40 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 40
        subOpacity.addItem(item)
        item = NSMenuItem(title: "50%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (50 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 50
        subOpacity.addItem(item)
        item = NSMenuItem(title: "60%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (60 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 60
        subOpacity.addItem(item)
        item = NSMenuItem(title: "70%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (70 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 70
        subOpacity.addItem(item)
        item = NSMenuItem(title: "80%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (80 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 80
        subOpacity.addItem(item)
        item = NSMenuItem(title: "90%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (90 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 90
        subOpacity.addItem(item)
        item = NSMenuItem(title: "100%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (100 == opacity ? OnState : OffState)
        item.target = hpc
        item.tag = 100
        subOpacity.addItem(item)

        item = NSMenuItem(title: "Never", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.never.rawValue
        item.state = translucency == .never ? OnState : OffState
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Always", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.always.rawValue
        item.state = translucency == .always ? OnState : OffState
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Mouse Over", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.mouseOver.rawValue
        item.state = translucency == .mouseOver ? OnState : OffState
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Mouse Outside", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.mouseOutside.rawValue
        item.state = translucency == .mouseOutside ? OnState : OffState
        item.target = hpc
        subTranslucency.addItem(item)

        item = NSMenuItem(title: "Save", action: #selector(hpc.saveDocument(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = hpc
        menu.addItem(item)
        
        item = NSMenuItem(title: "Search…", action: #selector(WebViewController.openSearchPress(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = wvc
        menu.addItem(item)
        
        item = NSMenuItem(title: "Close", action: #selector(NSApp.keyWindow?.performClose(_:)), keyEquivalent: "")
        item.target = NSApp.keyWindow
        menu.addItem(item)
        
        menu.addItem(NSMenuItem.separator())
        
        item = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "")
        item.target = NSApp
        menu.addItem(item)
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool{
        switch menuItem.title {
        default:
            return true
        }
    }
}

class WebViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, NSMenuDelegate, NSTabViewDelegate, WKHTTPCookieStoreObserver {

    @available(OSX 10.13, *)
    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        DispatchQueue.main.async {
            cookieStore.getAllCookies { cookies in
                // Process cookies
            }
        }
    }

    var defaults = UserDefaults.standard
    var document : Document? {
        get {
            if let document : Document = self.view.window?.windowController?.document as? Document {
                return document
            }
            return nil
        }
    }
    var heliumPanelController : HeliumPanelController? {
        get {
            guard let hpc : HeliumPanelController = self.view.window?.windowController as? HeliumPanelController else { return nil }
            return hpc
        }
    }

    var trackingTag: NSView.TrackingRectTag? {
        get {
            return (self.webView.window?.windowController as? HeliumPanelController)?.viewTrackingTag
        }
        set (value) {
            (self.webView.window?.windowController as? HeliumPanelController)?.viewTrackingTag = value
        }
    }

    // MARK: View lifecycle
    func fit(_ childView: NSView, parentView: NSView) {
        childView.translatesAutoresizingMaskIntoConstraints = false
        childView.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
        childView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
        childView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
        childView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        webView.becomeFirstResponder()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.loadURL(urlFileURL:)),
            name: NSNotification.Name(rawValue: "HeliumLoadURL"),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.loadURL(urlString:)),
            name: NSNotification.Name(rawValue: "HeliumLoadURLString"),
            object: nil)
        
        //  We want to be notified when a player is added
        let originalDidAddSubviewMethod = class_getInstanceMethod(NSView.self, #selector(NSView.didAddSubview(_:)))
        let originalDidAddSubviewImplementation = method_getImplementation(originalDidAddSubviewMethod!)
        
        typealias DidAddSubviewCFunction = @convention(c) (AnyObject, Selector, NSView) -> Void
        let castedOriginalDidAddSubviewImplementation = unsafeBitCast(originalDidAddSubviewImplementation, to: DidAddSubviewCFunction.self)
        
        let newDidAddSubviewImplementationBlock: @convention(block) (AnyObject?, NSView) -> Void = { (view: AnyObject!, subview: NSView) -> Void in
            castedOriginalDidAddSubviewImplementation(view, Selector(("didAddsubview:")), subview)
//            Swift.print("view: \(subview.className)")
            if subview.className == "WKFlippedView" {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "WKFlippedView"), object: subview)
            }
        }
        
        let newDidAddSubviewImplementation = imp_implementationWithBlock(unsafeBitCast(newDidAddSubviewImplementationBlock, to: AnyObject.self))
        method_setImplementation(originalDidAddSubviewMethod!, newDidAddSubviewImplementation)
        
        NotificationCenter.default.addObserver(self, selector: #selector(wkFlippedView(_:)), name: NSNotification.Name(rawValue: "WKFlippedView"), object: nil)
    }
    
    @objc func wkFlippedView(_ note: NSNotification) {
        print("A Player \(String(describing: note.object)) will be opened now")
        guard let view = note.object as? NSView, let scrollView = view.enclosingScrollView else { return }
        
        if scrollView.hasHorizontalScroller {
            scrollView.horizontalScroller?.isHidden = true
        }
        if scrollView.hasVerticalScroller {
            scrollView.verticalScroller?.isHidden = true
        }
    }
    
    func scrollView(_ note: NSNotification) {
        print("Scroll View \(String(describing: note.object)) will be opened now")
        if let scrollView : NSScrollView = note.object as? NSScrollView {
            scrollView.autohidesScrollers = true
        }
    }
    
    override func viewDidAppear() {
        //  https://stackoverflow.com/questions/32056874/programmatically-wkwebview-inside-an-uiview-with-auto-layout
        //  the autolayout is complete only when the view has appeared.
        if self.webView != nil { setupWebView() }
        
        // Final panel updates, called by view, when document is available
        if let hpc = self.heliumPanelController {
            hpc.documentDidLoad()
        }
        
        //  load developer panel if asked - initially no
        self.webView?.configuration.preferences.setValue(UserSettings.DeveloperExtrasEnabled.value, forKey: "developerExtrasEnabled")
    }
    
    fileprivate func setupWebView() {
        
        webView.autoresizingMask = [NSView.AutoresizingMask.height, NSView.AutoresizingMask.width]
        if webView.constraints.count == 0 {
            fit(webView, parentView: webView.superview!)
        }
        
        // Allow plug-ins such as silverlight
        webView.configuration.preferences.plugInsEnabled = true
        
        // Custom user agent string for Netflix HTML5 support
        webView.customUserAgent = UserSettings.UserAgent.value
        
        // Allow zooming
        webView.allowsMagnification = true
        
        // Alow back and forth
        webView.allowsBackForwardNavigationGestures = true
        
        // Allow look ahead views
        webView.allowsLinkPreview = true
        
        //  ditch loading indicator background
        loadingIndicator.appearance = NSAppearance.init(named: NSAppearance.Name.aqua)
        
        //  Fetch, synchronize and observe data store for cookie changes
        if #available(OSX 10.13, *) {
            let websiteDataStore = WKWebsiteDataStore.nonPersistent()
            let configuration = webView.configuration
            configuration.websiteDataStore = websiteDataStore
            
            configuration.processPool = WKProcessPool()
            let cookies = HTTPCookieStorage.shared.cookies ?? [HTTPCookie]()
            
            cookies.forEach({ configuration.websiteDataStore.httpCookieStore.setCookie($0, completionHandler: nil) })
            WKWebsiteDataStore.default().httpCookieStore.add(self)
        }
        
        // Listen for load progress
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "loading", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        observing = true
        
        //    Watch command key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.commandKeyDown(_:)),
            name: NSNotification.Name(rawValue: "commandKeyDown"),
            object: nil)

        //  Intercept Finder drags
        webView.registerForDraggedTypes([NSURLPboardType,NSPasteboard.PasteboardType.string])
        
        //  Watch javascript selection messages unless already done
        let controller = webView.configuration.userContentController
        if controller.userScripts.count > 0 { return }
        
        controller.add(self, name: "newWindowWithUrlDetected")
        controller.add(self, name: "newSelectionDetected")
        controller.add(self, name: "newUrlDetected")

        let js = NSString.string(fromAsset: "Helium-js")
        let script = WKUserScript.init(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)
        
        //  make http: -> https: guarded by preference
        if #available(OSX 10.13, *), UserSettings.PromoteHTTPS.value {
            //  https://developer.apple.com/videos/play/wwdc2017/220/ 21:04
            let jsonString = """
                [{
                    "trigger" : { "url-filter" : ".*" },
                    "action" : { "type" : "make-https" }
                }]
            """
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "httpRuleList", encodedContentRuleList: jsonString, completionHandler: {(list, error) in
                guard let contentRuleList = list else { return }
                self.webView.configuration.userContentController.add(contentRuleList)
            })
        }
        
        clear()
    }
    
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    @objc dynamic var observing : Bool = false
    
    func setupTrackingAreas(_ establish: Bool) {
        if let tag = trackingTag {
            view.removeTrackingRect(tag)
            trackingTag = nil
        }
        if establish {
            trackingTag = view.addTrackingRect(view.bounds, owner: self, userData: nil, assumeInside: false)
        }
        webView.updateTrackingAreas()
    }
    override func viewDidLayout() {
        super.viewDidLayout()

        //  ditch horizonatal scroll when not over
        if let scrollView = self.webView.enclosingScrollView {
            if scrollView.hasHorizontalScroller {
                scrollView.horizontalScroller?.isHidden = true
            }
            if scrollView.hasVerticalScroller {
                scrollView.verticalScroller?.isHidden = true
            }
        }

        setupTrackingAreas(true)
    }
    
    override func viewWillDisappear() {
        let navDelegate = webView.navigationDelegate as! NSObject
        
        //  Halt anything in progress
        webView.stopLoading()
        webView.loadHTMLString("about:blank", baseURL: nil)
        
        // Wind down all observations
        if observing {
            webView.removeObserver(navDelegate, forKeyPath: "estimatedProgress")
            webView.removeObserver(navDelegate, forKeyPath: "title")
            observing = false
        }
    }

    // MARK: Actions
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool{
        switch menuItem.title {
        case "Developer Extras":
            guard let state = webView.configuration.preferences.value(forKey: "developerExtrasEnabled") else { return false }
            menuItem.state = (state as? NSNumber)?.boolValue == true ? OnState : OffState
            return true

        case "Back":
            return webView.canGoBack
        case "Forward":
            return webView.canGoForward
        default:
            return true
        }
    }

    @IBAction func backPress(_ sender: AnyObject) {
        webView.goBack()
    }
    
    @IBAction func forwardPress(_ sender: AnyObject) {
        webView.goForward()
    }
    
    @objc internal func commandKeyDown(_ notification : Notification) {
        let commandKeyDown : NSNumber = notification.object as! NSNumber
        if let window = self.view.window {
            window.isMovableByWindowBackground = commandKeyDown.boolValue
//            Swift.print(String(format: "CMND %@", commandKeyDown.boolValue ? "v" : "^"))
        }
    }
    
    fileprivate func zoomIn() {
        webView.magnification += 0.1
     }
    
    fileprivate func zoomOut() {
        webView.magnification -= 0.1
    }
    
    fileprivate func resetZoom() {
        webView.magnification = 1
    }

    @IBAction func developerExtrasEnabledPress(_ sender: NSMenuItem) {
        self.webView?.configuration.preferences.setValue((sender.state != OnState), forKey: "developerExtrasEnabled")
    }

    @IBAction func openFilePress(_ sender: AnyObject) {
        var viewOptions = ViewOptions(rawValue: sender.tag)
        let window = self.view.window
        let open = NSOpenPanel()
        
        open.allowsMultipleSelection = true
        open.canChooseDirectories = false
        open.resolvesAliases = true
        open.canChooseFiles = true
        
        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)

        open.worksWhenModal = true
        open.beginSheetModal(for: window!, completionHandler: { (response: NSApplication.ModalResponse) in
            if response == NSApplication.ModalResponse.OK {
                let urls = open.urls
                
                for url in urls {
                    if viewOptions.contains(.t_view) {
                        self.appDelegate.openURLInNewWindow(url, attachTo: window)
                    }
                    else
                    if viewOptions.contains(.w_view) {
                        self.appDelegate.openURLInNewWindow(url)
                    }
                    else
                    {
                        self.webView.next(url: url)
                    }
                    //  Multiple files implies new windows
                    viewOptions.insert(.w_view)
                }
            }
        })
    }
    
    @IBAction func openLocationPress(_ sender: AnyObject) {
        let viewOptions = ViewOptions(rawValue: sender.tag)
        let window = self.view.window
        var urlString = currentURL
        
        if let rawString = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string), rawString.isValidURL() {
            urlString = rawString
        }

        appDelegate.didRequestUserUrl(RequestUserStrings (
            currentURL:         urlString,
            alertMessageText:   "URL to load",
            alertButton1stText: "Load",     alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.HomePageURL.value),
                                      onWindow: window as? HeliumPanel,
                                      title: "Enter URL",
                                      acceptHandler: { (urlString: String) in
                                        guard let newURL = URL.init(string: urlString) else { return }
                                        
                                        if viewOptions.contains(.t_view) {
                                            self.appDelegate.openURLInNewWindow(newURL, attachTo: window)
                                        }
                                        else
                                        if viewOptions.contains(.w_view) {
                                            self.appDelegate.openURLInNewWindow(newURL)
                                        }
                                        else
                                        {
                                            self.loadURL(url: newURL)
                                        }
        })
    }
    @IBAction func openSearchPress(_ sender: AnyObject) {
        let viewOptions = ViewOptions(rawValue: sender.tag)
        let window = self.view.window

        let name = k.searchNames[ UserSettings.Search.value ]
        let info = k.searchInfos[ UserSettings.Search.value ]

        appDelegate.didRequestSearch(RequestUserStrings (
            currentURL:         nil,
            alertMessageText:   "Search",
            alertButton1stText: name,         alertButton1stInfo: info,
            alertButton2ndText: "Cancel",     alertButton2ndInfo: nil,
            alertButton3rdText: "New Window", alertButton3rdInfo: "Results in new window"),
                                     onWindow: self.view.window as? HeliumPanel,
                                     title: "Web Search",
                                     acceptHandler: { (newWindow: Bool, searchURL: URL) in
                                        if viewOptions.contains(.t_view) {
                                            self.appDelegate.openURLInNewWindow(searchURL, attachTo: window)
                                        }
                                        else
                                        if newWindow || viewOptions.contains(.w_view) {
                                            self.appDelegate.openURLInNewWindow(searchURL)
                                        }
                                        else
                                        {
                                            self.loadURL(url: searchURL)
                                        }
        })
    }

    @IBAction fileprivate func reloadPress(_ sender: AnyObject) {
        requestedReload()
    }
    
    @IBAction fileprivate func clearPress(_ sender: AnyObject) {
        clear()
    }
    
    @IBAction fileprivate func resetZoomLevel(_ sender: AnyObject) {
        resetZoom()
    }
    
    @IBAction func userAgentPress(_ sender: AnyObject) {
        appDelegate.didRequestUserAgent(RequestUserStrings (
            currentURL: webView.customUserAgent,
            alertMessageText:   "Custom user agent",
            alertButton1stText: "Set",      alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Default",  alertButton3rdInfo: UserSettings.UserAgent.default),
                            onWindow: NSApp.keyWindow as? HeliumPanel,
                            title: "Custom User Agent",
                            acceptHandler: { (newUserAgent: String) in
                                self.webView.customUserAgent = newUserAgent
        }
        )
    }

    @IBAction fileprivate func zoomIn(_ sender: AnyObject) {
        zoomIn()
    }
    @IBAction fileprivate func zoomOut(_ sender: AnyObject) {
        zoomOut()
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // MARK: Loading
    
    internal var currentURL: String? {
        return webView.url?.absoluteString
    }

    internal func loadURL(text: String) {
        let text = UrlHelpers.ensureScheme(text)
        if let url = URL(string: text) {
            webView.load(URLRequest.init(url: url))
        }
    }

    internal func loadURL(url: URL) {
        webView.next(url: url)
    }

    @objc internal func loadURL(urlFileURL: Notification) {
        if let fileURL = urlFileURL.object, let info = urlFileURL.userInfo {
            if info["hwc"] as? NSWindowController == self.view.window?.windowController {
                loadURL(url: fileURL as! URL)
            }
            else
            {
                //  load new window with URL
                loadURL(url: urlFileURL.object as! URL)
            }
        }
    }
    
    @objc func loadURL(urlString: Notification) {
        if let userInfo = urlString.userInfo {
            if userInfo["hwc"] as? NSWindowController != self.view.window?.windowController {
                return
            }
        }
        
        if let string = urlString.object as? String {
            _ = loadURL(text: string)
        }
    }
    
    func loadAttributes(dict: Dictionary<String,Any>) {
        Swift.print("loadAttributes: dict \(dict)")
    }
    
    func loadAttributes(item: PlayItem) {
        loadAttributes(dict: item.dictionary())
    }
    
    // TODO: For now just log what we would play once we figure out how to determine when an item finishes so we can start the next
    @objc func playerDidFinishPlaying(_ note: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: note.object)
        print("Video Finished")
    }
    
    fileprivate func requestedReload() {
        webView.reload()
    }
    
    // MARK: Javascript
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        //Swift.print("userContentController")
        
        switch message.name {
        case "newWindowWithUrlDetected":
            if let url = URL.init(string: message.body as! String) {
                webView.selectedURL = url
                //Swift.print("ucc: new -> \(url.absoluteString)")
            }
            break
            
        case "newSelectionDetected":
            if let urlString : String = message.body as? String
            {
                webView.selectedText = urlString
                //Swift.print("ucc: str -> \(urlString)")
            }
            break
            
        case "newUrlDetected":
            if let url = URL.init(string: message.body as! String) {
                webView.selectedURL = url
                //Swift.print("ucc: url -> \(url.absoluteString)")
            }
            break
            
        default:
            Swift.print("ucc: unknown \(message.name)")
        }
    }

    // MARK: Webview functions
    func clear() {
        // Reload to home page (or default if no URL stored in UserDefaults)
        guard let url = URL.init(string: UserSettings.HomePageURL.value) else { return }
        webView.load(URLRequest.init(url: url))
    }

	@IBOutlet var webView: MyWebView!
	var webSize = CGSize(width: 0,height: 0)
    
	@IBOutlet weak var loadingIndicator: NSProgressIndicator!
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let mwv = object as? MyWebView, mwv == self.webView else { return }

        //  We *must* have a key path
        guard let keyPath = keyPath else { return }
        
        switch keyPath {
        case "estimatedProgress":

            if let progress = change?[NSKeyValueChangeKey(rawValue: "new")] as? Float {
                let percent = progress * 100
                var title = NSString(format: "Loading... %.2f%%", percent)
                if percent == 100, let url = (self.webView.url) {

                    //  Initial recording of for this url session
                    let notif = Notification(name: Notification.Name(rawValue: "HeliumNewURL"), object: url, userInfo: [k.fini : false, k.view : self.webView as Any])
                    NotificationCenter.default.post(notif)

                    // once loaded update window title,size with video name,dimension
                    if let urlTitle = (mwv.url?.absoluteString) {
                        title = urlTitle as NSString

                        if let track = AVURLAsset(url: url, options: nil).tracks.first {

                            //    if it's a video file, get and set window content size to its dimentions
                            if track.mediaType == AVMediaType.video {
                                
                                title = url.lastPathComponent as NSString
                                webSize = track.naturalSize
                                
                                //  Try to adjust initial size if possible
                                let os = appDelegate.os
                                switch (os.majorVersion, os.minorVersion, os.patchVersion) {
                                case (10, 10, _), (10, 11, _), (10, 12, _):
                                    if let oldSize = mwv.window?.contentView?.bounds.size, oldSize != webSize, var origin = mwv.window?.frame.origin, let theme = self.view.window?.contentView?.superview {
                                        var iterator = theme.constraints.makeIterator()
                                        Swift.print(String(format:"view:%p webView:%p", mwv.superview!, mwv))
                                        while let constraint = iterator.next()
                                        {
                                            Swift.print("\(constraint.priority) \(constraint)")
                                        }
                                        
                                        origin.y += (oldSize.height - webSize.height)
                                        mwv.window?.setContentSize(webSize)
                                        mwv.window?.setFrameOrigin(origin)
                                        mwv.bounds.size = webSize
                                    }
                                    break
                                    
                                default:
                                    //  Issue still to be resolved so leave as-is for now
                                    Swift.print("os \(os)")
                                }
                            }
                            
                            //  Wait for URL to finish
                            let videoPlayer = AVPlayer(url: url)
                            let item = videoPlayer.currentItem
                            NotificationCenter.default.addObserver(self, selector: #selector(WebViewController.playerDidFinishPlaying(_:)),
                                                                             name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)

                            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
                                DispatchQueue.main.async {
                                    Swift.print("restarting #1")
                                    videoPlayer.seek(to: CMTime.zero)
                                    videoPlayer.play()
                                }
                            })
                            
                            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
                                DispatchQueue.main.async {
                                    Swift.print("restarting #2")
                                    videoPlayer.seek(to: CMTime.zero)
                                    videoPlayer.play()
                                }
                            })
                        }
                        else
                        {
                            restoreSettings(title as String)
                        }
                    } else {
                        title = appDelegate.appName as NSString
                    }
                    
                    self.view.window?.title = title as String

                    // Remember for later restoration
                    if let doc = self.document, let hpc = doc.heliumPanelController {
                        doc.update(to: url)
                        self.view.window?.representedURL = url
                        hpc.updateTitleBar(didChange: false)
                        NSApp.addWindowsItem(self.view.window!, title: url.lastPathComponent, filename: false)
                    }
                }
            }
            break
            
        case "loading":
            guard let loading = change?[NSKeyValueChangeKey(rawValue: "new")] as? Bool, loading == loadingIndicator.isHidden else { return }
            Swift.print("loading: \(loading ? "YES" : "NO")")
            break;
            
        case "title":
            title = mwv.title
            break;
            
        default:
            Swift.print("Unknown observing keyPath \(String(describing: keyPath))")
        }
    }
/*
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var arrayController: NSArrayController!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    let fetcher = ScheduleFetcher()
    dynamic var courses: [Course] = []
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        tableView.target = self
        tableView.doubleAction = Selector("openClass:")
        
        progressIndicator.startAnimation(self)
        progressIndicator.hidden = false
        
        fetcher.fetchCoursesUsingCompletionHandler({ (result) in
            self.progressIndicator.stopAnimation(self)
            self.progressIndicator.hidden = true
            switch result {
            case .Success(let courses):
                print("Got courses: \(courses)")
                self.courses = courses
            case .Failure(let error):
                print("Got error: \(error)")
                NSAlert(error: error).runModal()
                self.courses = []
            }
        })
    }
    
    func openClass(sender: AnyObject!) {
        if let course = arrayController.selectedObjects.first as? Course {
            NSWorkspace.sharedWorkspace().openURL(course.url)
        }
    }
*/
    fileprivate func restoreSettings(_ title: String) {
        guard let dict = defaults.dictionary(forKey: title), let doc = self.document, let hpc = doc.heliumPanelController else
        {
            return
        }
        doc.restoreSettings(with: dict)
        hpc.documentDidLoad()
    }
    
    //Convert a YouTube video url that starts at a certian point to popup/embedded design
    // (i.e. ...?t=1m2s --> ?start=62)
    func makeCustomStartTimeURL(_ url: String) -> String {
        let startTime = "?t="
        let idx = url.indexOf(startTime)
        if idx == -1 {
            return url
        } else {
            let timeIdx = idx.advanced(by: 3)
            let hmsString = url[timeIdx...].replacingOccurrences(of: "h", with: ":").replacingOccurrences(of: "m", with: ":").replacingOccurrences(of: "s", with: ":")
            
            var returnURL = url
            var final = 0
            
            let hms = hmsString.components(separatedBy: ":")
            if hms.count > 2, let hrs = Int(hms[2]) {
                final += 3600 * hrs
            }
            if hms.count > 1, let mins = Int(hms[1]) {
                final += 60 * mins
            }
            if hms.count > 0, let secs = Int(hms[0]) {
                final += secs
            }
            
            returnURL.removeSubrange(returnURL.index(returnURL.startIndex, offsetBy: idx+1) ..< returnURL.endIndex)
            returnURL = "?start="

            returnURL = returnURL + String(final)
            
            return returnURL
        }
    }
    
    //Helper function to return the hash of the video for encoding a popout video that has a start time code.
    fileprivate func getVideoHash(_ url: String) -> String {
        let startOfHash = url.indexOf(".be/")
        let endOfHash = startOfHash.advanced(by: 4)
        let restOfUrl = url.indexOf("?t")
        let hash = url[url.index(url.startIndex, offsetBy: endOfHash) ..< (endOfHash == -1 ? url.endIndex : url.index(url.startIndex, offsetBy: restOfUrl))]
        return String(hash)
    }
    /*
    func webView(webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
        
        let alertController = NSAlertController(title: nil, message: message, preferredStyle: .ActionSheet)
        
        alertController.addAction(NSAlertAction(title: "Ok", style: .Default, handler: { (action) in
            completionHandler()
        }))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func webView(webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (Bool) -> Void) {
        
        let alertController = AlertController(title: nil, message: message, preferredStyle: .ActionSheet)
        
        alertController.addAction(AlertAction(title: "Ok", style: .Default, handler: { (action) in
            completionHandler(true)
        }))
        
        alertController.addAction(AlertAction(title: "Cancel", style: .Default, handler: { (action) in
            completionHandler(false)
        }))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func webView(webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String?) -> Void) {
        
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .ActionSheet)
        
        alertController.addTextFieldWithConfigurationHandler { (textField) in
            textField.text = defaultText
        }
        
        alertController.addAction(AlertAction(title: "Ok", style: .Default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
            
        }))
        
        alertController.addAction(AlertAction(title: "Cancel", style: .Default, handler: { (action) in
            
            completionHandler(nil)
            
        }))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    */
    // MARK: Navigation Delegate

    // Redirect Hulu and YouTube to pop-out videos
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let viewOptions = appDelegate.getViewOptions
        var url = navigationAction.request.url!
        
        guard navigationAction.buttonNumber < 2 else {
            Swift.print("newWindow with url:\(String(describing: url))")
            if viewOptions.contains(.t_view) {
                appDelegate.openURLInNewWindow(url, attachTo: webView.window )
            }
            else
            {
                appDelegate.openURLInNewWindow(url)
            }
            decisionHandler(WKNavigationActionPolicy.cancel)
            return
        }
        
        guard !UserSettings.DisabledMagicURLs.value else {
            if let selectedURL = (webView as! MyWebView).selectedURL {
                url = selectedURL
            }
            if navigationAction.buttonNumber > 1 {
                if viewOptions.contains(.t_view) {
                    appDelegate.openURLInNewWindow(url, attachTo: webView.window )
                }
                else
                {
                    appDelegate.openURLInNewWindow(url)
                }
                decisionHandler(WKNavigationActionPolicy.cancel)
            }
            else
            {
                decisionHandler(WKNavigationActionPolicy.allow)
            }
            return
        }

        if let newUrl = UrlHelpers.doMagic(url), newUrl != url {
            decisionHandler(WKNavigationActionPolicy.cancel)
            if let selectedURL = (webView as! MyWebView).selectedURL {
                url = selectedURL
            }
            if navigationAction.buttonNumber > 1
            {
                if viewOptions.contains(.t_view) {
                    appDelegate.openURLInNewWindow(newUrl, attachTo: webView.window )
                }
                else
                {
                    appDelegate.openURLInNewWindow(newUrl)
                }
            }
            else
            {
                loadURL(url: newUrl)
            }
        } else {
            decisionHandler(WKNavigationActionPolicy.allow)
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        
        guard let response = navigationResponse.response as? HTTPURLResponse,
            let url = navigationResponse.response.url else {
                decisionHandler(.allow)
                return
        }
        
        //  load cookies
        if #available(OSX 10.13, *) {
            if let headerFields = response.allHeaderFields as? [String:String] {
                Swift.print("\(url.absoluteString) allHeaderFields:\n\(headerFields)")

                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                cookies.forEach({ cookie in
                    webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: nil)
                })
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Swift.print("didStartProvisionalNavigation - 1st")
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Swift.print("didCommit - 2nd")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleError(error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleError(error)
    }
    fileprivate func handleError(_ error: Error) {
        let message = error.localizedDescription
        Swift.print("didFail?: \(message)")
        if (error as NSError).code >= 400 {
            NSApp.presentError(error)
        }
        else
        if (error as NSError).code < 0 {
            if let info = error._userInfo as? [String: Any] {
                if let url = info["NSErrorFailingURLKey"] as? URL {
                    appDelegate.userAlertMessage(message, info: url.absoluteString)
                }
                else
                if let urlString = info["NSErrorFailingURLStringKey"] as? String {
                    appDelegate.userAlertMessage(message, info: urlString)
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        let doc = self.document
        let hpc = doc?.heliumPanelController
        
        guard let url = webView.url else {
            return
        }
        
        //  Restore setting not done by document controller
        if let dict = defaults.dictionary(forKey: url.absoluteString), let doc = doc, let hpc = hpc {
            doc.restoreSettings(with: dict)
            hpc.documentDidLoad()
        }
        
        //  Finish recording of for this url session
        let notif = Notification(name: Notification.Name(rawValue: "HeliumNewURL"), object: url, userInfo: [k.fini : true])
        NotificationCenter.default.post(notif)
        
        Swift.print("webView:didFinish navigation: '\(String(describing: webView.title))' => \(url.absoluteString) - last")
/*
        let html = """
<html>
<body>
<h1>Hello, Swift!</h1>
</body>
</html>
"""
        webView.loadHTMLString(html, baseURL: nil)*/
    }
    
    func webView(_ webView: WKWebView, didFinishLoad navigation: WKNavigation) {
        guard let title = webView.title, let urlString : String = webView.url?.absoluteString else {
            return
        }
        Swift.print("webView:didFinishLoad: '\(title)' => \(urlString)")
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else { return completionHandler(.useCredential, nil) }
        let exceptions = SecTrustCopyExceptions(serverTrust)
        SecTrustSetExceptions(serverTrust, exceptions)
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
    
    //  MARK: UI Delegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        if navigationAction.targetFrame == nil {
            appDelegate.openURLInNewWindow(navigationAction.request.url!)
            return nil
        }
        
        //  We really want to use the supplied config, so use custom setup
        var newWebView : WKWebView?
        Swift.print("createWebViewWith")
        
        if let newURL = navigationAction.request.url {
            do {
                let doc = try NSDocumentController.shared.makeDocument(withContentsOf: newURL, ofType: k.Custom)
                if let hpc = doc.windowControllers.first as? HeliumPanelController,
                    let window = hpc.window, let wvc = window.contentViewController as? WebViewController {
                    let newView = MyWebView.init(frame: webView.frame, configuration: configuration)
                    let contentView = window.contentView!
                    
                    hpc.webViewController.webView = newView
                    contentView.addSubview(newView)

                    hpc.webViewController.loadURL(text: newURL.absoluteString)
                    newView.navigationDelegate = wvc
                    newView.uiDelegate = wvc
                    newWebView = hpc.webView
                    wvc.viewDidLoad()

                    //  Setups all done, make us visible
                    window.makeKeyAndOrderFront(self)
                }
            } catch let error {
                NSApp.presentError(error)
            }
        }

        return newWebView
     }
    
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        Swift.print("runOpenPanelWith")
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        Swift.print("runJavaScriptAlertPanelWithMessage")
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        Swift.print("runJavaScriptConfirmPanelWithMessage")
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        Swift.print("webViewDidClose")
    }
    
    //  MARK: TabView Delegate
    
    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            Swift.print("willSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            Swift.print("didSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }
}
