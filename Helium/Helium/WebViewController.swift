//
//  WebViewController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright (c) 2017 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import WebKit
import AVFoundation
import Carbon.HIToolbox

class MyWebView : WKWebView {
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    override class func handlesURLScheme(_ urlScheme: String) -> Bool {
        Swift.print("handleURLScheme: \(urlScheme)")
        return true
    }
    var selectedText : String?
    var selectedURL : URL?
    
    internal func menuClicked(_ sender: AnyObject) {
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
                    item.representedObject = self.window
                    item.action = #selector(MyWebView.openLinkInWindow(_:))
                    item.target = self
                }
                else
                {
                    item.action = #selector(MyWebView.openLinkInNewWindow(_:))
                    item.target = self
                }
            }
        }

        publishApplicationMenu(menu);
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            //  We crash otherwise, so just close window
            self.window?.performClose(event)
        }
        else
        if let chr = event.charactersIgnoringModifiers, chr.starts(with: "?")
        {
            (self.window?.contentViewController as! WebViewController).openSearchPress(event)
        }
        else
        {
            // still here?
            super.keyDown(with: event)
        }
    }
    
    func openLinkInWindow(_ item: NSMenuItem) {
        if let urlString = self.selectedText, let url = URL.init(string: urlString) {
            load(URLRequest.init(url: url))
        }
        if let url = self.selectedURL {
            load(URLRequest.init(url: url))
        }
      }
    
    func openLinkInNewWindow(_ item: NSMenuItem) {
        if let urlString = self.selectedText, let url = URL.init(string: urlString) {
            appDelegate.openURLInNewWindow(url)
        }
        if let url = self.selectedURL {
            appDelegate.openURLInNewWindow(url)
        }
    }
/*
    override func load(_ request: URLRequest) -> WKNavigation? {
        Swift.print("we got \(request)")
        return super.load(request)
    }
*/
    func next(url: URL) {
        let doc = self.window?.windowController?.document as? Document
        let newWindows = UserSettings.createNewWindows.value
        let appDelegate = NSApp.delegate as! AppDelegate
        var nextURL = url

        //  Pick off request (non-file) urls first
        if !url.isFileURL {
            if appDelegate.openForBusiness && newWindows && doc != nil {
                do
                {
                    let next = try NSDocumentController.shared().openUntitledDocumentAndDisplay(true) as! Document
                    let oldWindow = self.window
                    let newWindow = next.windowControllers.first?.window
                    (newWindow?.contentView?.subviews.first as! MyWebView).load(URLRequest(url: url))
                    newWindow?.offsetFromWindow(oldWindow!)
                }
                catch let error {
                    NSApp.presentError(error)
                    Swift.print("Yoink, unable to create new url doc for (\(url))")
                    return
                }
            }
            else
            {
                self.load(URLRequest(url: url))
            }
            return
        }
        
        //  Resolve alias before bookmarking
        if let original = (nextURL as NSURL).resolvedFinderAlias() { nextURL = original }

        if url.isFileURL, appDelegate.isSandboxed() && !appDelegate.storeBookmark(url: nextURL) {
            Swift.print("Yoink, unable to sandbox \(nextURL)")
            return
        }
        
        if appDelegate.openForBusiness && newWindows && doc != nil {
            do
            {
                let next = try NSDocumentController.shared().openUntitledDocumentAndDisplay(true) as! Document
                let oldWindow = self.window
                let newWindow = next.windowControllers.first?.window
                (newWindow?.contentView?.subviews.first as! MyWebView).load(URLRequest(url: nextURL))
                newWindow?.offsetFromWindow(oldWindow!)
            }
            catch let error {
                NSApp.presentError(error)
                Swift.print("Yoink, unable to create new url doc for (\(url))")
                return
            }
        }
        else
        {
            self.load(URLRequest(url: nextURL))
        }
        doc?.update(to: nextURL)
    }
    
    // MARK: Drag and Drop - Before Release
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
//        Swift.print("draggingUpdated -> .copy")
        return .copy
    }
    // MARK: Drag and Drop - After Release
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
//        let homeURL = FileManager.default.homeDirectoryForCurrentUser
//        let rootURL = URL.init(string: "file:///")
        let pboard = sender.draggingPasteboard()
        let items = pboard.pasteboardItems

        //  Open subsequent items in new windows
        let createNewWindows = UserSettings.createNewWindows.value
        
        if (pboard.types?.contains(NSURLPboardType))! {
            for item in items! {

                if let urlString = item.string(forType: kUTTypeUTF8PlainText as String/*"public.utf8-plain-text"*/) {
                    self.next(url: URL(string: urlString)!)
                }
                else
                if let urlString = item.string(forType: kUTTypeURL as String/*"public.url"*/) {
                    self.next(url: URL(string: urlString)!)
                }
                else
                if let urlString = item.string(forType: kUTTypeFileURL as String/*"public.file-url"*/), var itemURL = URL.init(string: urlString) {
                    if appDelegate.openForBusiness && UserSettings.createNewWindows.value {
                        _ = appDelegate.doOpenFile(fileURL: itemURL, fromWindow: self.window)
                        continue
                    }
                    guard itemURL.isFileURL, appDelegate.isSandboxed() else {
                        self.next(url: URL(string: urlString)!)
                        continue
                    }
                    
                    //  Resolve alias before bookmarking
                    if let original = (itemURL as NSURL).resolvedFinderAlias() { itemURL = original }

                    if appDelegate.storeBookmark(url: itemURL as URL) {
                    // DON'T use self.loadFileURL(<#T##URL: URL##URL#>, allowingReadAccessTo: <#T##URL#>)
                    // instead we need to load requests *and* utilize the exception handler
//                      self.next(url: URL(string: urlString)!)
                        self.loadFileURL(itemURL, allowingReadAccessTo: itemURL)
                        (self.window?.windowController?.document as! Document).update(to: itemURL)
                     }
                }
                else
/*
                kUTTypeData as String,
                kUTTypeURL as String,
                PlayList.className(),
                PlayItem.className(),
                NSFilenamesPboardType,
                NSFilesPromisePboardType,
                NSURLPboardType
*/
                if let text = item.string(forType: "com.apple.pasteboard.promised-file-url") {
                    let data = item.data(forType: "com.apple.pasteboard.promised-file-url")
                    let list = item.propertyList(forType: "com.apple.pasteboard.promised-file-url")

                    Swift.print("data \(String(describing: data))")
                    Swift.print("text \(String(describing: text))")
                    Swift.print("list \(String(describing: list))")
                    continue
                }
                else
                if let text = item.string(forType: "com.apple.pasteboard.promised-file-content-type") {
                    let data = item.data(forType: "com.apple.pasteboard.promised-file-content-type")
                    let list = item.propertyList(forType: "com.apple.pasteboard.promised-file-content-type")

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
                if !UserSettings.createNewWindows.value {
                    UserSettings.createNewWindows.value = true
                }
            }
        }
        else
        if (pboard.types?.contains(NSPasteboardURLReadingFileURLsOnlyKey))! {
            Swift.print("we have NSPasteboardURLReadingFileURLsOnlyKey")
//          NSApp.delegate?.application!(NSApp, openFiles: items! as [String])
        }
        
        if UserSettings.createNewWindows.value != createNewWindows {
            UserSettings.createNewWindows.value = createNewWindows
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
        let hwc = self.window?.windowController as! HeliumPanelController
        let doc = hwc.document as! Document
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
                    item.keyEquivalent = "f"
                }
                else
                if self.url != nil {
                    item.representedObject = self.url
                    item.target = appDelegate
                    item.action = #selector(appDelegate.openURLInNewWindowPress(_:))
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
//                let state = item.state == NSOnState ? "yes" : "no"
//                Swift.print("target: \(title) -> \(String(describing: item.action)) state: \(state) tag:\(item.tag)")
            }
        }
        var item: NSMenuItem

        item = NSMenuItem(title: "Open", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subOpen = NSMenu()
        item.submenu = subOpen

        item = NSMenuItem(title: "File…", action: #selector(WebViewController.openFilePress(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = wvc
        subOpen.addItem(item)

        item = NSMenuItem(title: "URL…", action: #selector(WebViewController.openLocationPress(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = wvc
        subOpen.addItem(item)

        item = NSMenuItem(title: "Window", action: #selector(AppDelegate.newDocument(_:)), keyEquivalent: "")
        item.target = appDelegate
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Playlists", action: #selector(AppDelegate.presentPlaylistSheet(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = appDelegate
        menu.addItem(item)

        item = NSMenuItem(title: "Preferences", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subPref = NSMenu()
        item.submenu = subPref

        item = NSMenuItem(title: "Auto-hide Title Bar", action: #selector(hwc.autoHideTitlePress(_:)), keyEquivalent: "")
        item.state = doc.settings.autoHideTitle.value ? NSOnState : NSOffState
        item.target = hwc
        subPref.addItem(item)

        item = NSMenuItem(title: "Create New Windows", action: #selector(AppDelegate.createNewWindowPress(_:)), keyEquivalent: "")
        item.state = UserSettings.createNewWindows.value ? NSOnState : NSOffState
        item.target = appDelegate
        subPref.addItem(item)
        
        item = NSMenuItem(title: "Float Above All Spaces", action: #selector(hwc.floatOverFullScreenAppsPress(_:)), keyEquivalent: "")
        item.state = doc.settings.disabledFullScreenFloat.value ? NSOffState : NSOnState
        item.target = hwc
        subPref.addItem(item)
        
        item = NSMenuItem(title: "Home Page", action: #selector(AppDelegate.homePagePress(_:)), keyEquivalent: "")
        item.target = appDelegate
        subPref.addItem(item)

        item = NSMenuItem(title: "Magic URL Redirects", action: #selector(AppDelegate.magicURLRedirectPress(_:)), keyEquivalent: "")
        item.state = UserSettings.disabledMagicURLs.value ? NSOffState : NSOnState
        item.target = appDelegate
        subPref.addItem(item)

        item = NSMenuItem(title: "User Agent", action: #selector(AppDelegate.userAgentPress(_:)), keyEquivalent: "")
        item.target = appDelegate
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

        item = NSMenuItem(title: "10%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (10 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 10
        subOpacity.addItem(item)
        item = NSMenuItem(title: "20%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.isEnabled = translucency.rawValue > 0
        item.state = (20 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 20
        subOpacity.addItem(item)
        item = NSMenuItem(title: "30%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (30 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 30
        subOpacity.addItem(item)
        item = NSMenuItem(title: "40%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (40 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 40
        subOpacity.addItem(item)
        item = NSMenuItem(title: "50%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (50 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 50
        subOpacity.addItem(item)
        item = NSMenuItem(title: "60%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (60 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 60
        subOpacity.addItem(item)
        item = NSMenuItem(title: "70%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (70 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 70
        subOpacity.addItem(item)
        item = NSMenuItem(title: "80%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (80 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 80
        subOpacity.addItem(item)
        item = NSMenuItem(title: "90%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (90 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 90
        subOpacity.addItem(item)
        item = NSMenuItem(title: "100%", action: #selector(hwc.percentagePress(_:)), keyEquivalent: "")
        item.state = (100 == opacity ? NSOnState : NSOffState)
        item.target = hwc
        item.tag = 100
        subOpacity.addItem(item)

        item = NSMenuItem(title: "Never", action: #selector(hwc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.never.rawValue
        item.state = translucency == .never ? NSOnState : NSOffState
        item.target = hwc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Always", action: #selector(hwc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.always.rawValue
        item.state = translucency == .always ? NSOnState : NSOffState
        item.target = hwc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Mouse Over", action: #selector(hwc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.mouseOver.rawValue
        item.state = translucency == .mouseOver ? NSOnState : NSOffState
        item.target = hwc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Mouse Outside", action: #selector(hwc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.mouseOutside.rawValue
        item.state = translucency == .mouseOutside ? NSOnState : NSOffState
        item.target = hwc
        subTranslucency.addItem(item)

        item = NSMenuItem(title: "Search…", action: #selector(AppDelegate.openSearchPress(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = appDelegate
        menu.addItem(item)
        
        item = NSMenuItem(title: "Close", action: #selector(NSApp.keyWindow?.performClose(_:)), keyEquivalent: "")
        item.target = NSApp.keyWindow
        menu.addItem(item)

        item = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "")
        item.target = NSApp
        menu.addItem(item)
    }
}

class WebViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    var trackingTag: NSTrackingRectTag? {
        get {
            return (self.webView.window?.windowController as? HeliumPanelController)?.viewTrackingTag
        }
        set (value) {
            (self.webView.window?.windowController as? HeliumPanelController)?.viewTrackingTag = value!
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.loadUserAgent(userAgentString:)),
            name: NSNotification.Name(rawValue: "HeliumNewUserAgentString"),
            object: nil)
        
        if self.webView != nil { setupWebView() }
    }
    
    fileprivate func setupWebView() {
        
        webView.autoresizingMask = [NSAutoresizingMaskOptions.viewHeightSizable, NSAutoresizingMaskOptions.viewWidthSizable]
        if webView.constraints.count == 0 {
            fit(webView, parentView: webView.superview!)
        }
        
        // Allow plug-ins such as silverlight
        webView.configuration.preferences.plugInsEnabled = true
        
        // Custom user agent string for Netflix HTML5 support
        webView._customUserAgent = UserSettings.userAgent.value
        
        // Allow zooming
        webView.allowsMagnification = true
        
        // Alow back and forth
        webView.allowsBackForwardNavigationGestures = true
        
        // Listen for load progress
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)

        //  Intercept Finder drags
        webView.register(forDraggedTypes: [NSURLPboardType])
        
        //  Watch javascript selection messages unless already done
        let controller = webView.configuration.userContentController
        if controller.userScripts.count > 0 { return }
        
        controller.add(self, name: "newWindowWithUrlDetected")
        controller.add(self, name: "newSelectionDetected")
        controller.add(self, name: "newUrlDetected")

        let js = """
//  https://stackoverflow.com/questions/50846404/how-do-i-get-the-selected-text-from-a-wkwebview-from-objective-c
function getSelectionAndSendMessage()
{
    var txt = document.getSelection().toString() ;
    window.webkit.messageHandlers.newSelectionDetected.postMessage(txt) ;
}
document.onmouseup   = getSelectionAndSendMessage ;
document.onkeyup     = getSelectionAndSendMessage ;

//  https://stackoverflow.com/questions/21224327/how-to-detect-middle-mouse-button-click/21224428
document.body.onclick = function (e) {
  if (e && (e.which == 2 || e.button == 4 )) {
    sendLink;
  }
}
function middleLink()
{
    window.webkit.messageHandlers.newWindowWithUrlDetected.postMessage(this.href) ;
}

//  https://stackoverflow.com/questions/51894733/how-to-get-mouse-over-urls-into-wkwebview-with-swift/51899392#51899392
function sendLink()
{
    window.webkit.messageHandlers.newUrlDetected.postMessage(this.href) ;
}

var allLinks = document.links;
for(var i=0; i< allLinks.length; i++)
{
    allLinks[i].onmouseover = sendLink ;
}
"""
        let script = WKUserScript.init(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)
        
        clear()
    }
    
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    
    func setupTrackingAreas(_ establish: Bool) {
        if let tag = trackingTag {
            view.removeTrackingRect(tag)
        }
        if establish {
            trackingTag = view.addTrackingRect(view.bounds, owner: self, userData: nil, assumeInside: false)
        }
        webView.updateTrackingAreas()
    }
    override func viewDidLayout() {
        super.viewDidLayout()

        // Deferred window setup needing a document' settings
        if let hwc = self.view.window?.windowController {
            (hwc as! HeliumPanelController).documentViewDidLoad()
        }
        
        setupTrackingAreas(true)
    }

    // MARK: Actions
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool{
        switch menuItem.title {
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
    
    fileprivate func zoomIn() {
        webView.magnification += 0.1
     }
    
    fileprivate func zoomOut() {
        webView.magnification -= 0.1
    }
    
    fileprivate func resetZoom() {
        webView.magnification = 1
    }

    @IBAction func openFilePress(_ sender: AnyObject) {
        let window = self.view.window
        let open = NSOpenPanel()
        
        open.allowsMultipleSelection = true
        open.canChooseDirectories = false
        open.resolvesAliases = true
        open.canChooseFiles = true
        
        open.worksWhenModal = true
        open.beginSheetModal(for: window!, completionHandler: { (response: NSModalResponse) in
            if response == NSModalResponseOK {
                let urls = open.urls
                for url in urls {
                    _ = self.appDelegate.doOpenFile(fileURL: url, fromWindow: window)
                }
            }
        })
    }
    
    @IBAction func openLocationPress(_ sender: AnyObject) {
        let rawString = NSPasteboard.general().string(forType: NSPasteboardTypeString)
        let urlString = URL.init(string: rawString!)?.absoluteString ?? currentURL

        appDelegate.didRequestUserUrl(RequestUserStrings (
            currentURL:         urlString,
            alertMessageText:   "URL to load",
            alertButton1stText: "Load",     alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.homePageURL.value),
                                      onWindow: self.view.window as? HeliumPanel,
                                      title: "Enter URL",
                                      acceptHandler: { (newUrl: String) in
                                        self.loadURL(text: newUrl)
        })
    }
    @IBAction func openSearchPress(_ sender: AnyObject) {
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
                                        if newWindow {
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

    internal func loadUserAgent(userAgentString: Notification) {
        webView._customUserAgent = UserSettings.userAgent.value
    }
    
    internal func loadURL(text: String) {
        let text = UrlHelpers.ensureScheme(text)
        if let url = URL(string: text) {
            loadURL(url: url)
        }
    }

    internal func loadURL(url: URL) {
        webView.next(url: url)
    }

    internal func loadURL(urlFileURL: Notification) {
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
    
    func loadURL(urlString: Notification) {
        if let userInfo = urlString.userInfo {
            if userInfo["hwc"] as? NSWindowController != self.view.window?.windowController {
                return
            }
        }
        
        if let string = urlString.object as? String {
            _ = loadURL(text: string)
        }
    }

    // TODO: For now just log what we would play once we figure out how to determine when an item finishes so we can start the next
    func playerDidFinishPlaying(_ note: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: note.object)
        print("Video Finished")
    }
    
    fileprivate func requestedReload() {
        webView.reload()
    }
    
    fileprivate func shiftKeyDown(_ note: Notification) {
        webView.willChangeValue(forKey: "mouseDownCanMoveWindow")
        ;
        webView.didChangeValue(forKey: "mouseDownCanMoveWindow")
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
        loadURL(text: UserSettings.homePageURL.value)
    }

	@IBOutlet var webView: MyWebView!
	var webSize = CGSize(width: 0,height: 0)
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "estimatedProgress", let view = object as? MyWebView, view == webView {

            if let progress = change?[NSKeyValueChangeKey(rawValue: "new")] as? Float {
                let percent = progress * 100
                var title = NSString(format: "Loading... %.2f%%", percent)
                if percent == 100, let url = (self.webView.url) {

                    // once loaded update window title,size with video name,dimension
                    if let urlTitle = (self.webView.url?.absoluteString) {
                        title = urlTitle as NSString

                        if let track = AVURLAsset(url: url, options: nil).tracks.first {

                            //    if it's a video file, get and set window content size to its dimentions
                            if track.mediaType == AVMediaTypeVideo {
                                
                                title = url.lastPathComponent as NSString
                                webSize = track.naturalSize
                                
                                //  Try to adjust initial sizee if possible
                                let os = appDelegate.os
                                switch (os.majorVersion, os.minorVersion, os.patchVersion) {
                                case (10, 10, _), (10, 11, _), (10, 12, _):
                                    if let oldSize = webView.window?.contentView?.bounds.size, oldSize != webSize, var origin = self.webView.window?.frame.origin, let theme = self.view.window?.contentView?.superview {
                                        var iterator = theme.constraints.makeIterator()
                                        Swift.print(String(format:"view:%p webView:%p", webView.superview!, webView))
                                        while let constraint = iterator.next()
                                        {
                                            Swift.print("\(constraint.priority) \(constraint)")
                                        }
                                        
                                        origin.y += (oldSize.height - webSize.height)
                                        webView.window?.setContentSize(webSize)
                                        webView.window?.setFrameOrigin(origin)
                                        webView.bounds.size = webSize
                                    }
                                    break
                                    
                                default:
                                    //  Issue still to be resolved so leave as-is for now
                                    Swift.print("os \(os)")
                                }
                            }
                            //  If we have save attributes restore them
                            self.restoreSettings(title as String)


                            //  Wait for URL to finish
                            let videoPlayer = AVPlayer(url: url)
                            let item = videoPlayer.currentItem
                            NotificationCenter.default.addObserver(self, selector: #selector(WebViewController.playerDidFinishPlaying(_:)),
                                                                             name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)

                            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
                                DispatchQueue.main.async {
                                    Swift.print("restarting #1")
                                    videoPlayer.seek(to: kCMTimeZero)
                                    videoPlayer.play()
                                }
                            })
                            
                            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
                                DispatchQueue.main.async {
                                    Swift.print("restarting #2")
                                    videoPlayer.seek(to: kCMTimeZero)
                                    videoPlayer.play()
                                }
                            })
                        }
                        else
                        {
                            self.restoreSettings(title as String)
                        }
                    } else {
                        title = "Helium"
                    }
                    
                    self.view.window?.title = title as String

                    // Remember for later restoration
                    if let hwc = self.view.window?.windowController, let doc = self.view.window?.windowController?.document {
                        (doc as! Document).update(to: url)
                        self.view.window?.representedURL = url
                        (hwc as! HeliumPanelController).updateTitleBar(didChange: false)
                        NSApp.addWindowsItem(self.view.window!, title: url.lastPathComponent, filename: false)
                    }
                }
            }
        }
        else
        if keyPath == "title" {
            title = webView.title
        }
    }
    
    fileprivate func restoreSettings(_ title: String) {
        if let playitems = UserDefaults.standard.dictionary(forKey: k.Playitems) {
            if let playitem = playitems[title] as? PlayItem {
                let hwc = self.view.window?.windowController as! HeliumPanelController
                let doc = hwc.document as! Document
                let rect = playitem.rect
                webSize = rect.size
                webView.window?.setContentSize(webSize)
                webView.bounds.size = webSize
                self.view.window?.setFrameOrigin(rect.origin)
                doc.settings.autoHideTitle.value = playitem.label
                hwc.updateTitleBar(didChange: false)
                doc.settings.opacityPercentage.value = Int(playitem.alpha)
                hwc.willUpdateAlpha()
                doc.settings.disabledFullScreenFloat.value = playitem.hover
                doc.settings.translucencyPreference.value = HeliumPanelController.TranslucencyPreference(rawValue: playitem.trans)!
                hwc.translucencyPreference = doc.settings.translucencyPreference.value
                hwc.willUpdateTranslucency()
            }
        }
    }
    
    //Convert a YouTube video url that starts at a certian point to popup/embedded design
    // (i.e. ...?t=1m2s --> ?start=62)
    fileprivate func makeCustomStartTimeURL(_ url: String) -> String {
        let startTime = "?t="
        let idx = url.indexOf(startTime)
        if idx == -1 {
            return url
        } else {
            var returnURL = url
            let timing = url.substring(from: url.index(url.startIndex, offsetBy: idx+3))
            let hoursDigits = timing.indexOf("h")
            var minutesDigits = timing.indexOf("m")
            let secondsDigits = timing.indexOf("s")
            
            returnURL.removeSubrange(returnURL.index(returnURL.startIndex, offsetBy: idx+1) ..< returnURL.endIndex)
            returnURL = "?start="
            
            //If there are no h/m/s params and only seconds (i.e. ...?t=89)
            if (hoursDigits == -1 && minutesDigits == -1 && secondsDigits == -1) {
                let onlySeconds = url.substring(from: url.index(url.startIndex, offsetBy: idx+3))
                returnURL = returnURL + onlySeconds
                return returnURL
            }
            
            //Do check to see if there is an hours parameter.
            var hours = 0
            if (hoursDigits != -1) {
                hours = Int(timing.substring(to: timing.index(timing.startIndex, offsetBy: hoursDigits)))!
            }
            
            //Do check to see if there is a minutes parameter.
            var minutes = 0
            if (minutesDigits != -1) {
                minutes = Int(timing.substring(with: timing.index(timing.startIndex, offsetBy: hoursDigits+1) ..< timing.index(timing.startIndex, offsetBy: minutesDigits)))!
            }
            
            if minutesDigits == -1 {
                minutesDigits = hoursDigits
            }
            
            //Do check to see if there is a seconds parameter.
            var seconds = 0
            if (secondsDigits != -1) {
                seconds = Int(timing.substring(with: timing.index(timing.startIndex, offsetBy: minutesDigits+1) ..< timing.index(timing.startIndex, offsetBy: secondsDigits)))!
            }
            
            //Combine all to make seconds.
            let secondsFinal = 3600*hours + 60*minutes + seconds
            returnURL = returnURL + String(secondsFinal)
            
            return returnURL
        }
    }
    
    //Helper function to return the hash of the video for encoding a popout video that has a start time code.
    fileprivate func getVideoHash(_ url: String) -> String {
        let startOfHash = url.indexOf(".be/")
        let endOfHash = url.indexOf("?t")
        let hash = url.substring(with: url.index(url.startIndex, offsetBy: startOfHash+4) ..<
            (endOfHash == -1 ? url.endIndex : url.index(url.startIndex, offsetBy: endOfHash)))
        return hash
    }

    // MARK: Navigation Delegate

    // Redirect Hulu and YouTube to pop-out videos
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard navigationAction.buttonNumber <= 1 else {
            if let url = navigationAction.request.url {
                Swift.print("newWindow with url:\(String(describing: url))")
                self.appDelegate.openURLInNewWindow(url)
            }
            decisionHandler(WKNavigationActionPolicy.cancel)
            return
        }
        
        guard !UserSettings.disabledMagicURLs.value,
            let url = navigationAction.request.url,
            !((navigationAction.request.url?.absoluteString.hasPrefix("file://"))!) else {
                if let myWebView: MyWebView = webView as? MyWebView, NSApp.currentEvent?.buttonNumber == 2, let url = myWebView.selectedURL {
                    Swift.print("newWindow with url:\(url)")
                    appDelegate.openURLInNewWindow(url)
 //                   webView.goBack()
                    decisionHandler(WKNavigationActionPolicy.cancel)
                }
                else
                {
                    decisionHandler(WKNavigationActionPolicy.allow)
                }
                return
        }

        if let newUrl = UrlHelpers.doMagic(url) {
            decisionHandler(WKNavigationActionPolicy.cancel)
            loadURL(url: newUrl)
        } else {
            decisionHandler(WKNavigationActionPolicy.allow)
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Swift.print("didStartProvisionalNavigation - 1st")
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Swift.print("didCommit - 2nd")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Swift.print("didFail")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Swift.print("didFailProvisionalNavigation")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        guard let url = webView.url else {
            return
        }
        let notif = Notification(name: Notification.Name(rawValue: "HeliumNewURL"), object: url);
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
    
    //  MARK: UI Delegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        let newWindows = UserSettings.createNewWindows.value
        var newWebView : WKWebView?
        Swift.print("createWebViewWith")
        
        if let newURL = navigationAction.request.url {
            UserSettings.createNewWindows.value = false
            do {
                let doc = try NSDocumentController.shared().makeDocument(withContentsOf: newURL, ofType: "Custom")
                if let hpc = doc.windowControllers.first as? HeliumPanelController,
                    let window = hpc.window, let wvc = window.contentViewController as? WebViewController {
                    let newView = MyWebView.init(frame: webView.frame, configuration: configuration)
                    let contentView = window.contentView!
                    
                    hpc.webViewController.webView = newView
                    contentView.addSubview(newView)
                    wvc.viewDidLoad()

                    hpc.webViewController.loadURL(text: newURL.absoluteString)
                    newView.navigationDelegate = wvc
                    newView.uiDelegate = wvc
                    newWebView = hpc.webView
                    
                    //  Setups all done, make us visible
                    window.makeKeyAndOrderFront(self)
                }
            } catch let error {
                NSApp.presentError(error)
            }
        }
        if UserSettings.createNewWindows.value != newWindows {
            UserSettings.createNewWindows.value = newWindows
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
    
}
