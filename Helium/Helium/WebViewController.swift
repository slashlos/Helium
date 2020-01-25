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

class WebBorderView : NSView {
    var isReceivingDrag = false {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        self.isHidden = !isReceivingDrag
//        Swift.print("web borderView drawing \(isHidden ? "NO" : "YES")....")

        if isReceivingDrag {
            NSColor.selectedKnobColor.set()
            
            let path = NSBezierPath(rect:bounds)
            path.lineWidth = 4
            path.stroke()
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
    var chromeType: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "org.chromium.drag-dummy-type") }
    var finderNode: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "com.apple.finder.node") }
    var webarchive: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "com.apple.webarchive") }
    var acceptableTypes: Set<NSPasteboard.PasteboardType> { return [.URL, .fileURL, .list, .item, .html, .pdf, .png, .rtf, .rtfd, .tiff, finderNode, webarchive] }
    var filteringOptions = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes:NSImage.imageTypes]

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
            _ = appDelegate.openURLInNewWindow(url, attachTo: item.representedObject as? NSWindow)
        }
        else
        if let url = self.selectedURL {
            _ = appDelegate.openURLInNewWindow(url, attachTo: item.representedObject as? NSWindow)
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
    
    var heliumPanelController : HeliumPanelController? {
        get {
            guard let hpc : HeliumPanelController = self.window?.windowController as? HeliumPanelController else { return nil }
            return hpc
        }
    }
    var webViewController : WebViewController? {
        get {
            guard let wvc : WebViewController = self.window?.contentViewController as? WebViewController else { return nil }
            return wvc
        }
    }
/*
    override func load(_ request: URLRequest) -> WKNavigation? {
        Swift.print("we got \(request)")
        return super.load(request)
    }
*/
    @objc @IBAction internal func cut(_ sender: Any) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let urlString = self.url?.absoluteString {
            pb.setString(urlString, forType: NSPasteboard.PasteboardType.string)
            (self.uiDelegate as! WebViewController).clear()
        }
    }
    @objc @IBAction internal func copy(_ sender: Any) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let urlString = self.url?.absoluteString {
            pb.setString(urlString, forType: NSPasteboard.PasteboardType.string)
        }
    }
    @objc @IBAction internal func paste(_ sender: Any) {
        let pb = NSPasteboard.general
        guard let rawString = pb.string(forType: NSPasteboard.PasteboardType.string), rawString.isValidURL() else { return }
        
        self.load(URLRequest.init(url: URL.init(string: rawString)!))
    }
    @objc @IBAction internal func delete(_ sender: Any) {
        self.cancelOperation(sender)
        Swift.print("cancel")
    }

    func html(_ html : String) {
        self.loadHTMLString(html, baseURL: nil)
    }

    func next(url: URL) {
        let doc = self.heliumPanelController?.document as! Document
        var nextURL = url

        //  Resolve alias before sandbox bookmarking
        if let webloc = nextURL.webloc {
            next(url: webloc)
            return
        }

        if nextURL.isFileURL {
            if let original = (nextURL as NSURL).resolvedFinderAlias() { nextURL = original }

            if nextURL.isFileURL, appDelegate.isSandboxed() && !appDelegate.storeBookmark(url: nextURL) {
                Swift.print("Yoink, unable to sandbox \(nextURL)")
                return
            }
        }
        
        //  h3w files are playlist extractions, presented as a sheet or window
        guard nextURL.pathExtension == k.h3w, let dict = NSDictionary(contentsOf: url)  else {
            //  keep document in sync with webView url
            doc.update(to: nextURL)
            
            self.load(URLRequest(url: nextURL))
            ///self.loadFileURL(nextURL, allowingReadAccessTo: nextURL)
            
            return
        }
        
        //  We could have 3 keys: <source-name>, k.playlists, k.playitems or promise file of playlists
        var playlists = [PlayList]()
        if let names : [String] = dict.value(forKey: k.playlists) as? [String] {
            for name in names {
                if let items = dict.value(forKey: name) as? [Dictionary<String,Any>] {
                    let playlist = PlayList.init(name: name, list: [PlayItem]())
                    for item in items {
                        playlist.list.append(PlayItem.init(with: item))
                    }
                    playlists.append(playlist)
                }
            }
        }
        else
        if let items = dict.value(forKey: k.playitems) as? [Dictionary<String,Any>] {
            let playlist = PlayList.init(name: nextURL.lastPathComponent, list: [PlayItem]())
            for item in items {
                playlist.list.append(PlayItem.init(with: item))
            }
            playlists.append(playlist)
        }
        else
        {
            for (name,list) in dict {
                let playlist = PlayList.init(name: name as! String, list: [PlayItem]())
                for item in (list as? [Dictionary<String,Any>])! {
                    playlist.list.append(PlayItem.init(with: item))
                }
                playlists.append(playlist)
            }
        }
        
        if let wvc = self.webViewController, wvc.presentedViewControllers?.count == 0 {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            
            let pvc = storyboard.instantiateController(withIdentifier: "PlaylistViewController") as! PlaylistViewController
            pvc.playlists.append(contentsOf: playlists)
            pvc.webViewController = self.webViewController
            wvc.presentAsSheet(pvc)
        }
    }
    
    func text(_ text : String) {
        if FileManager.default.fileExists(atPath: text) {
            let url = URL.init(fileURLWithPath: text)
            next(url: url)
            return
        }
        
        if let url = URL.init(string: text) {
            do {
                if try url.checkResourceIsReachable() {
                    next(url: url)
                    return
                }
            } catch let error as NSError {
                Swift.print("url?: \(error.code):\(error.localizedDescription): \(text)")
            }
        }
        
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                let wvc = self.window?.contentViewController
                (wvc as! WebViewController).loadAttributes(dict: json as! Dictionary<String, Any>)
                return
            } catch let error as NSError {
                Swift.print("json: \(error.code):\(error.localizedDescription): \(text)")
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
    
    func text(attrributedString text: NSAttributedString) {
        do {
            let docAttrs = [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.html]
            let data = try text.data(from: NSMakeRange(0, text.length), documentAttributes: docAttrs)
            if let attrs = String(data: data, encoding: .utf8) {
                let html = String(format: """
<html>
<body>
<code>
%@
</code>
</body>
</html>
""", attrs);
                self.loadHTMLString(html, baseURL: nil)
            }
        } catch let error as NSError {
            Swift.print("attributedString -> html: \(error.code):\(error.localizedDescription): \(text)")
        }
    }
    
    // MARK: Drag and Drop - Before Release
    func shouldAllowDrag(_ info: NSDraggingInfo) -> Bool {
        guard let doc = webViewController?.document, doc.docType == .helium else { return false }
        let pboard = info.draggingPasteboard
        let items = pboard.pasteboardItems!
        var canAccept = false
        
        let readableClasses = [NSURL.self, NSString.self, NSAttributedString.self, NSPasteboardItem.self, PlayList.self, PlayItem.self]
        
        if pboard.canReadObject(forClasses: readableClasses, options: filteringOptions) {
            canAccept = true
        }
        else
        {
            for item in items {
                Swift.print("item: \(item)")
            }
        }
        Swift.print("web shouldAllowDrag -> \(canAccept) \(items.count) item(s)")
        return canAccept
    }
    
    var borderView: WebBorderView {
        get {
            return (uiDelegate as! WebViewController).borderView
        }
    }
    
    var isReceivingDrag : Bool {
        get {
            return borderView.isReceivingDrag
        }
        set (value) {
            borderView.isReceivingDrag = value
        }
    }
    
    override func draggingEntered(_ info: NSDraggingInfo) -> NSDragOperation {
        let pboard = info.draggingPasteboard
        let items = pboard.pasteboardItems!
        let allow = shouldAllowDrag(info)
        if uiDelegate != nil { isReceivingDrag = allow }
        
        let dragOperation = allow ? .copy : NSDragOperation()
        Swift.print("web draggingEntered -> \(dragOperation) \(items.count) item(s)")
        return dragOperation
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let allow = shouldAllowDrag(sender)
        sender.animatesToDestination = true
        Swift.print("web prepareForDragOperation -> \(allow)")
        return allow
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        Swift.print("web draggingExited")
        if uiDelegate != nil { isReceivingDrag = false }
    }
    
    var lastDragSequence : Int = 0
    override func draggingUpdated(_ info: NSDraggingInfo) -> NSDragOperation {
        appDelegate.newViewOptions = appDelegate.getViewOptions
        let sequence = info.draggingSequenceNumber
        if sequence != lastDragSequence {
            Swift.print("web draggingUpdated -> .copy")
            lastDragSequence = sequence
        }
        return .copy
    }
    
    // MARK: Drag and Drop - After Release
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        var viewOptions = appDelegate.newViewOptions
        let options : [NSPasteboard.ReadingOptionKey: Any] =
            [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true,
             NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes : [
                kUTTypeImage, kUTTypeVideo, kUTTypeMovie],
             NSPasteboard.ReadingOptionKey(rawValue: PlayList.className()) : true,
             NSPasteboard.ReadingOptionKey(rawValue: PlayItem.className()) : true]
        let pboard = sender.draggingPasteboard
        let items = pboard.pasteboardItems
        var parent : NSWindow? = self.window
        var latest : Document?
        var handled = 0
        
        for item in items! {
            if handled == items!.count { break }
            
            if let urlString = item.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeURL as String)) {
                self.next(url: URL(string: urlString)!)
                handled += 1
                continue
            }

            for type in pboard.types! {
                Swift.print("web type: \(type)")

                switch type {
                case .files:
                    if let files = pboard.propertyList(forType: type) {
                        Swift.print("files \(files)")
                    }
                    break
                    
                case .URL, .fileURL:
                    if let urlString = item.string(forType: type), let url = URL.init(string: urlString) {
                         if viewOptions.contains(.t_view) {
                             latest = self.appDelegate.openURLInNewWindow(url, attachTo: parent)
                         }
                         else
                         if viewOptions.contains(.w_view) {
                             latest = self.appDelegate.openURLInNewWindow(url)
                         }
                         else
                         {
                             self.next(url: url)
                         }
                         //  Multiple files implies new windows
                         if latest != nil { parent = latest?.windowControllers.first?.window }
                         viewOptions.insert(.w_view)
                         handled += 1
                    }
                    else
                    if let data = item.data(forType: type), let url = NSKeyedUnarchiver.unarchiveObject(with: data) {
                        if viewOptions.contains(.t_view) {
                            latest = self.appDelegate.openURLInNewWindow(url as! URL , attachTo: parent)
                        }
                        else
                        if viewOptions.contains(.w_view) {
                            latest = self.appDelegate.openURLInNewWindow(url as! URL)
                        }
                        else
                        {
                            self.next(url: url as! URL)
                        }
                        //  Multiple files implies new windows
                        if latest != nil { parent = latest?.windowControllers.first?.window }
                        viewOptions.insert(.w_view)
                        handled += 1
                    }
                    else
                    if let urls: Array<AnyObject> = pboard.readObjects(forClasses: [NSURL.classForCoder()], options: options) as Array<AnyObject>? {
                        for url in urls as! [URL] {
                            if viewOptions.contains(.t_view) {
                                latest = self.appDelegate.openURLInNewWindow(url , attachTo: parent)
                            }
                            else
                            if viewOptions.contains(.w_view) {
                                latest = self.appDelegate.openURLInNewWindow(url)
                            }
                            else
                            {
                                self.next(url: url)
                            }
                            //  Multiple files implies new windows
                            if latest != nil { parent = latest?.windowControllers.first?.window }
                            viewOptions.insert(.w_view)
                            handled += 1
                        }
                    }
                    break
                    
                case .list:
                    if let playlists: Array<AnyObject> = pboard.readObjects(forClasses: [PlayList.classForCoder()], options: options) as Array<AnyObject>? {
                        var parent : NSWindow? = self.window
                        var latest : Document?
                        for playlist in playlists {
                            for playitem in playlist.list {
                                if viewOptions.contains(.t_view) {
                                    latest = self.appDelegate.openURLInNewWindow(playitem.link, attachTo: parent)
                                }
                                else
                                if viewOptions.contains(.w_view) {
                                    latest = self.appDelegate.openURLInNewWindow(playitem.link)
                                }
                                else
                                {
                                   self.next(url: playitem.link)
                                }
                                
                                //  Multiple files implies new windows
                                if latest != nil { parent = latest?.windowControllers.first?.window }
                                viewOptions.insert(.w_view)
                            }
                            handled += 1
                        }
                    }
                    break
                    
                case .item:
                    if let playitems: Array<AnyObject> = pboard.readObjects(forClasses: [PlayItem.classForCoder()], options: options) as Array<AnyObject>? {
                        var parent : NSWindow? = self.window
                        var latest : Document?
                        for playitem in playitems {
                            Swift.print("item: \(playitem)")
                            if viewOptions.contains(.t_view) {
                                latest = self.appDelegate.openURLInNewWindow(playitem.link, attachTo: parent)
                            }
                            else
                            if viewOptions.contains(.w_view) {
                                latest = self.appDelegate.openURLInNewWindow(playitem.link)
                            }
                            else
                            {
                               self.next(url: playitem.link)
                            }
                            //  Multiple files implies new windows
                            if latest != nil { parent = latest?.windowControllers.first?.window }
                            viewOptions.insert(.w_view)
                            handled += 1
                        }
                    }
                    break
                    
                case .data:
                    if let data = item.data(forType: type), let item = NSKeyedUnarchiver.unarchiveObject(with: data) {
                        if let playlist = item as? PlayList {
                            Swift.print("list: \(playlist)")
                            handled += 1
                        }
                        else
                        if let playitem = item as? PlayItem {
                            Swift.print("item: \(playitem)")
                            handled += 1
                        }
                        else
                        {
                            Swift.print("data: \(data)")
                        }
                     }
                    break

                case .rtf, .rtfd, .tiff:
                    if let data = item.data(forType: type), let text = NSAttributedString(rtf: data, documentAttributes: nil) {
                        self.text(text.string)
                        handled += 1
                    }
                    break
                    
                case .string, .tabularText:
                    if let text = item.string(forType: type) {
                        self.text(text)
                        handled += 1
                    }
                    break
                    
                case webarchive:
                    if let data = item.data(forType: type) {
                        let html = String(decoding: data, as: UTF8.self)
                        self.html(html)
                        handled += 1
                    }
                    if let text = item.string(forType: type) {
                        Swift.print("\(type) text \(String(describing: text))")
                        self.text(text)
                        handled += 1
                    }
                    if let prop = item.propertyList(forType: type) {
                        if let html = String.init(data: prop as! Data, encoding: .utf8)  {
                            self.html(html)
                            handled += 1
                        }
                        else
                        {
                            Swift.print("\(type) prop \(String(describing: prop))")
                        }
                    }
                    break

                case chromeType:
                    if let data = item.data(forType: type) {
                        let html = String(decoding: data, as: UTF8.self)
                        if html.count > 0 {
                            self.html(html)
                            handled += 1
                        }
                    }
                    if let text = item.string(forType: type) {
                        Swift.print("\(type) text \(String(describing: text))")
                        if text.count > 0 {
                            self.text(text)
                            handled += 1
                        }
                    }
                    if let prop = item.propertyList(forType: type) {
                        if let html = String.init(data: prop as! Data, encoding: .utf8)  {
                            self.html(html)
                            handled += 1
                        }
                        else
                        {
                            Swift.print("\(type) prop \(String(describing: prop))")
                        }
                    }
                    break
                    
                default:
                    Swift.print("unkn: \(type)")

                    if let data = item.data(forType: type) {
                        Swift.print("data: \(data.count) bytes")
                        //self.load(data, mimeType: <#T##String#>, characterEncodingName: UTF8, baseURL: <#T##URL#>)
                    }
                }
                if handled == items?.count { break }
            }
        }
        Swift.print("web performDragOperation -> \(handled == items?.count ? "true" : "false")")

        return handled == items?.count
    }
    
    //  MARK: Context Menu
    //
    //  Intercepted actions; capture state needed for avToggle()
    var playPressMenuItem = NSMenuItem()
    @objc @IBAction func playActionPress(_ sender: NSMenuItem) {
//        Swift.print("\(playPressMenuItem.title) -> target:\(String(describing: playPressMenuItem.target)) action:\(String(describing: playPressMenuItem.action)) tag:\(playPressMenuItem.tag)")
        _ = playPressMenuItem.target?.perform(playPressMenuItem.action, with: playPressMenuItem.representedObject)
        //  this releases original menu item
        sender.representedObject = self
        let notif = Notification(name: Notification.Name(rawValue: "HeliumItemAction"), object: sender)
        NotificationCenter.default.post(notif)
    }
    
    var mutePressMenuItem = NSMenuItem()
    @objc @IBAction func muteActionPress(_ sender: NSMenuItem) {
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
        guard let window = self.window else { return }
        let wvc = window.contentViewController as! WebViewController
        let hpc = window.windowController as! HeliumPanelController
        let settings = (hpc.document as! Document).settings
        let autoHideTitle = hpc.autoHideTitlePreference
        let translucency = hpc.translucencyPreference
        
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
                if item.title.hasSuffix("Enter Full Screen") {
                    item.target = appDelegate
                    item.action = #selector(appDelegate.toggleFullScreen(_:))
                    item.state = appDelegate.fullScreen != nil ? .on : .off
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
//                let state = item.state == .on ? "yes" : "no"
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

        //  Add tab support once present
        var tabItemUpdated = false
        if let tabs = self.window?.tabbedWindows, tabs.count > 0 {
            if tabs.count > 1 {
                item = NSMenuItem(title: "Prev Tab", action: #selector(window.selectPreviousTab(_:)), keyEquivalent: "")
                menu.addItem(item)
                item = NSMenuItem(title: "Next Tab", action: #selector(window.selectNextTab(_:)), keyEquivalent: "")
                menu.addItem(item)
            }
            item = NSMenuItem(title: "To New Window", action: #selector(window.moveTabToNewWindow(_:)), keyEquivalent: "")
            menu.addItem(item)
            item = NSMenuItem(title: "Show All Tabs", action: #selector(window.toggleTabOverview(_:)), keyEquivalent: "")
            menu.addItem(item)
            tabItemUpdated = true
        }
        if NSApp.windows.count > 1 {
            item = NSMenuItem(title: "Merge All Windows", action: #selector(window.mergeAllWindows(_:)), keyEquivalent: "")
            menu.addItem(item)
            tabItemUpdated = true
        }
        if tabItemUpdated { menu.addItem(NSMenuItem.separator()) }

        item = NSMenuItem(title: "New Window", action: #selector(appDelegate.newDocument(_:)), keyEquivalent: "")
        item.target = appDelegate
        item.tag = 1
        menu.addItem(item)
        
        item = NSMenuItem(title: "New Tab", action: #selector(appDelegate.newDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
        item.representedObject = self.window
        item.target = appDelegate
        item.isAlternate = true
        item.tag = 3
        menu.addItem(item)
        
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
        item.representedObject = self.window
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
        item.representedObject = self.window
        item.isAlternate = true
        item.target = wvc
        item.tag = 3
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Playlists", action: #selector(AppDelegate.presentPlaylistSheet(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = appDelegate
        menu.addItem(item)

        item = NSMenuItem(title: "Snapshot", action: #selector(webViewController?.snapshot(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = wvc
        menu.addItem(item)
        
        item = NSMenuItem(title: "Appearance", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subPref = NSMenu()
        item.submenu = subPref

        item = NSMenuItem(title: "Auto-hide Title Bar", action: #selector(menuClicked(_:)), keyEquivalent: "")
        subPref.addItem(item)
        let subAuto = NSMenu()
        item.submenu = subAuto
        
        item = NSMenuItem(title: "Never", action: #selector(hpc.autoHideTitlePress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.AutoHideTitlePreference.never.rawValue
        item.state = autoHideTitle == .never ? .on : .off
        item.target = hpc
        subAuto.addItem(item)
        item = NSMenuItem(title: "Outside", action: #selector(hpc.autoHideTitlePress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.AutoHideTitlePreference.outside.rawValue
        item.state = autoHideTitle == .outside ? .on : .off
        item.target = hpc
        subAuto.addItem(item)

        item = NSMenuItem(title: "Float Above", action: #selector(menuClicked(_:)), keyEquivalent: "")
        subPref.addItem(item)
        let subFloat = NSMenu()
        item.submenu = subFloat
        
        item = NSMenuItem(title: "All Spaces Disabled", action: #selector(hpc.floatOverAllSpacesPress), keyEquivalent: "")
        item.state = settings.floatAboveAllPreference.value.contains(.disabled) ? .on : .off
        item.target = hpc
        subFloat.addItem(item)

        item = NSMenuItem(title: "Full Screen", action: #selector(hpc.floatOverFullScreenAppsPress(_:)), keyEquivalent: "")
        item.state = settings.floatAboveAllPreference.value.contains(.screen) ? .on : .off
        item.target = hpc
        subFloat.addItem(item)

        item = NSMenuItem(title: "User Agent", action: #selector(wvc.userAgentPress(_:)), keyEquivalent: "")
        item.target = wvc
        subPref.addItem(item)
        
        item = NSMenuItem(title: "Translucency", action: #selector(menuClicked(_:)), keyEquivalent: "")
        subPref.addItem(item)
        let subTranslucency = NSMenu()
        item.submenu = subTranslucency

        item = NSMenuItem(title: "Opacity", action: #selector(menuClicked(_:)), keyEquivalent: "")
        let opacity = settings.opacityPercentage.value
        subTranslucency.addItem(item)
        let subOpacity = NSMenu()
        item.submenu = subOpacity

        item = NSMenuItem(title: "10%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (10 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 10
        subOpacity.addItem(item)
        item = NSMenuItem(title: "20%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.isEnabled = translucency.rawValue > 0
        item.state = (20 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 20
        subOpacity.addItem(item)
        item = NSMenuItem(title: "30%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (30 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 30
        subOpacity.addItem(item)
        item = NSMenuItem(title: "40%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (40 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 40
        subOpacity.addItem(item)
        item = NSMenuItem(title: "50%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (50 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 50
        subOpacity.addItem(item)
        item = NSMenuItem(title: "60%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (60 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 60
        subOpacity.addItem(item)
        item = NSMenuItem(title: "70%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (70 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 70
        subOpacity.addItem(item)
        item = NSMenuItem(title: "80%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (80 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 80
        subOpacity.addItem(item)
        item = NSMenuItem(title: "90%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (90 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 90
        subOpacity.addItem(item)
        item = NSMenuItem(title: "100%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (100 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 100
        subOpacity.addItem(item)

        item = NSMenuItem(title: "Never", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.never.rawValue
        item.state = translucency == .never ? .on : .off
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Always", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.always.rawValue
        item.state = translucency == .always ? .on : .off
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Mouse Over", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.mouseOver.rawValue
        item.state = translucency == .mouseOver ? .on : .off
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Mouse Outside", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumPanelController.TranslucencyPreference.mouseOutside.rawValue
        item.state = translucency == .mouseOutside ? .on : .off
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
        
        item = NSMenuItem(title: "Close", action: #selector(HeliumPanel.performClose(_:)), keyEquivalent: "")
        item.target = hpc.window
        menu.addItem(item)
        
        menu.addItem(NSMenuItem.separator())
        
        item = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "")
        item.target = NSApp
        menu.addItem(item)
    }
    
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool{
        switch menuItem.title {
        default:
            return true
        }
    }
}

extension NSView {
    func fit(_ parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
    }
    func center(_ parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.centerXAnchor.constraint(equalTo: parentView.centerXAnchor).isActive = true
        self.centerYAnchor.constraint(equalTo: parentView.centerYAnchor).isActive = true
    }
    func vCenter(_ parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.centerYAnchor.constraint(equalTo: parentView.centerYAnchor).isActive = true
    }
    func top(_ parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
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
            object: nil)/*
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wkFlippedView(_:)),
            name: NSNotification.Name(rawValue: "WKFlippedView"),
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
        }*/
    }
    
    override func viewDidAppear() {
        guard let doc = self.document, doc.docType == .helium else { return }
        
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
        let config = webView.configuration
        
        webView.autoresizingMask = [NSView.AutoresizingMask.height, NSView.AutoresizingMask.width]
        if webView.constraints.count == 0 {
            webView.fit(webView.superview!)
        }
        
        // Allow plug-ins such as silverlight
        config.preferences.plugInsEnabled = true
        
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
            config.websiteDataStore = websiteDataStore
            
            config.processPool = WKProcessPool()
            let cookies = HTTPCookieStorage.shared.cookies ?? [HTTPCookie]()
            
            cookies.forEach({ config.websiteDataStore.httpCookieStore.setCookie($0, completionHandler: nil) })
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

        //    Watch option + command key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.optionAndCommandKeysDown(_:)),
            name: NSNotification.Name(rawValue: "optionAndCommandKeysDown"),
            object: nil)

        //  Intercept drags
        webView.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0)})
        webView.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        webView.registerForDraggedTypes(Array(webView.acceptableTypes))

        //  Watch javascript selection messages unless already done
        let controller = config.userContentController
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
        guard let wc = self.view.window?.windowController, !wc.isKind(of: ReleasePanelController.self) else { return }
        let navDelegate = webView.navigationDelegate as! NSObject
        
        // Wind down all observations
        if observing {
            webView.removeObserver(navDelegate, forKeyPath: "estimatedProgress")
            webView.removeObserver(navDelegate, forKeyPath: "title")
            observing = false
        }
    }

    // MARK: Actions
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool{
        switch menuItem.title {
        case "Developer Extras":
            guard let state = webView.configuration.preferences.value(forKey: "developerExtrasEnabled") else { return false }
            menuItem.state = (state as? NSNumber)?.boolValue == true ? .on : .off
            return true

        case "Back":
            return webView.canGoBack
        case "Forward":
            return webView.canGoForward
        default:
            return true
        }
    }

    @objc @IBAction func backPress(_ sender: AnyObject) {
        webView.goBack()
    }
    
    @objc @IBAction func forwardPress(_ sender: AnyObject) {
        webView.goForward()
    }
    
    @objc internal func optionKeyDown(_ notification : Notification) {
        
    }
    
    @objc internal func commandKeyDown(_ notification : Notification) {
        let commandKeyDown : NSNumber = notification.object as! NSNumber
        if let window = self.view.window {
            window.isMovableByWindowBackground = commandKeyDown.boolValue
//            Swift.print(String(format: "CMND %@", commandKeyDown.boolValue ? "v" : "^"))
        }
    }
    
    @objc internal func optionAndCommandKeysDown(_ notification : Notification) {
        Swift.print("optionAndCommandKeysDown")
        snapshot(self)
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

    @objc @IBAction func developerExtrasEnabledPress(_ sender: NSMenuItem) {
        self.webView?.configuration.preferences.setValue((sender.state != .on), forKey: "developerExtrasEnabled")
    }

    @objc @IBAction func openFilePress(_ sender: AnyObject) {
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
                var parent : NSWindow? = window
                var latest : Document?
                let urls = open.urls
                
                for url in urls {
                    if viewOptions.contains(.t_view) {
                        latest = self.appDelegate.openURLInNewWindow(url, attachTo: parent)
                    }
                    else
                    if viewOptions.contains(.w_view) {
                        latest = self.appDelegate.openURLInNewWindow(url)
                    }
                    else
                    {
                        self.webView.next(url: url)
                    }
                    //  Multiple files implies new windows
                    if latest != nil { parent = latest?.windowControllers.first?.window }
                    viewOptions.insert(.w_view)
                }
            }
        })
    }
    
    @objc @IBAction func openLocationPress(_ sender: AnyObject) {
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
                                            _ = self.appDelegate.openURLInNewWindow(newURL, attachTo: window)
                                        }
                                        else
                                        if viewOptions.contains(.w_view) {
                                            _ = self.appDelegate.openURLInNewWindow(newURL)
                                        }
                                        else
                                        {
                                            self.loadURL(url: newURL)
                                        }
        })
    }
    @objc @IBAction func openSearchPress(_ sender: AnyObject) {
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
                                            _ = self.appDelegate.openURLInNewWindow(searchURL, attachTo: window)
                                        }
                                        else
                                        if viewOptions.contains(.w_view) {
                                            _ = self.appDelegate.openURLInNewWindow(searchURL)
                                        }
                                        else
                                        {
                                            self.loadURL(url: searchURL)
                                        }
        })
    }

    @objc @IBAction fileprivate func reloadPress(_ sender: AnyObject) {
        requestedReload()
    }
    
    @objc @IBAction fileprivate func clearPress(_ sender: AnyObject) {
        clear()
    }
    
    @objc @IBAction fileprivate func resetZoomLevel(_ sender: AnyObject) {
        resetZoom()
    }
    
    @IBAction func snapshot(_ sender: Any) {
        webView.takeSnapshot(with: nil) {image, error in
            if let image = image {
                self.webImageView.image = image
            } else {
                print("Failed taking snapshot: \(error?.localizedDescription ?? "--")")
                self.webImageView.image = nil
            }
        }
        guard let image = webImageView.image else { return }
        guard let tiffData = image.tiffRepresentation else { NSSound(named: "Sosumi")?.play(); return }
         
        //  1st around authenticate and cache sandbox data if needed
        if appDelegate.isSandboxed(), appDelegate.desktopData == nil {
            var desktop =
                UserSettings.SnapshotsURL.value.count == 0
                    ? appDelegate.getDesktopDirectory()
                    : URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value, isDirectory: true)
            
            let openPanel = NSOpenPanel()
            openPanel.message = "Authorize access to Snapshots"
            openPanel.prompt = "Authorize"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.directoryURL = desktop
            openPanel.begin() { (result) -> Void in
                if (result == NSApplication.ModalResponse.OK) {
                    desktop = openPanel.url!
                    _ = self.appDelegate.storeBookmark(url: desktop, options: self.appDelegate.rwOptions)
                    self.appDelegate.desktopData = self.appDelegate.bookmarks[desktop]
                    UserSettings.SnapshotsURL.value = desktop.absoluteString
                    DispatchQueue.main.async {
                        if !self.appDelegate.saveBookmarks() {
                            Swift.print("Yoink, unable to save desktop booksmark(s)")
                        }
                    }
                }
            }
        }
        
        //  Form a filename: ~/"<app's name> View Shot <timestamp>"
        let dateFMT = DateFormatter()
        dateFMT.dateFormat = "yyyy-dd-MM"
        let timeFMT = DateFormatter()
        timeFMT.dateFormat = "h.mm.ss a"
        let now = Date()

        let path = URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value).appendingPathComponent(
            String(format: "%@ View Shot %@ at %@.png", appDelegate.appName, dateFMT.string(from: now), timeFMT.string(from: now)))
        
        let bitmapImageRep = NSBitmapImageRep(data: tiffData)
        
        //  With sandbox clearance to the desktop...
        do
        {
            try bitmapImageRep?.representation(using: .png, properties: [:])?.write(to: path)
            DispatchQueue.main.async {
                // https://developer.apple.com/library/archive/qa/qa1913/_index.html
                if let asset = NSDataAsset(name:"Grab") {

                    do {
                        // Use NSDataAsset's data property to access the audio file stored in Sound.
                         let player = try AVAudioPlayer(data:asset.data, fileTypeHint:"caf")
                        // Play the above sound file.
                        player.play()
                    } catch {
                        Swift.print("no sound for you")
                    }
                }
            }
        } catch let error {
            NSApp.presentError(error)
            NSSound(named: "Sosumi")?.play()
        }
    }
    
    @objc @IBAction func userAgentPress(_ sender: AnyObject) {
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

    @objc @IBAction fileprivate func zoomIn(_ sender: AnyObject) {
        zoomIn()
    }
    @objc @IBAction fileprivate func zoomOut(_ sender: AnyObject) {
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
        if let fileURL = urlFileURL.object, let userInfo = urlFileURL.userInfo {
            if userInfo["hwc"] as? NSWindowController == self.view.window?.windowController {
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
        guard self.document?.docType == .helium, let url = URL.init(string: UserSettings.HomePageURL.value) else { return }
        webView.load(URLRequest.init(url: url))
    }

    @objc @IBOutlet weak var webView: MyWebView!
    var webImageView = NSImageView.init()
	var webSize = CGSize(width: 0,height: 0)
    
    @objc @IBOutlet weak var borderView: WebBorderView!
	
    @objc @IBOutlet weak var loadingIndicator: NSProgressIndicator!
	
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let mwv = object as? MyWebView, mwv == self.webView else { return }

        //  We *must* have a key path
        guard let keyPath = keyPath else { return }
        
        switch keyPath {
        case "estimatedProgress":

            if let progress = change?[NSKeyValueChangeKey(rawValue: "new")] as? Float {
                let percent = progress * 100
                var title = String(format: "Loading... %.2f%%", percent)
                if percent == 100, let url = (self.webView.url) {

                    //  Initial recording for this url session
                    let notif = Notification(name: Notification.Name(rawValue: "HeliumNewURL"), object: url, userInfo: [k.fini : false, k.view : self.webView as Any])
                    NotificationCenter.default.post(notif)

                    // once loaded update window title,size with video name,dimension
                    if let toolTip = (mwv.url?.absoluteString) {
                        title = url.isFileURL ? url.lastPathComponent : (url.path != "/" ? url.lastPathComponent : url.host) ?? document!.displayName
                        self.heliumPanelController?.hoverBar?.superview?.toolTip = toolTip

                        if let track = AVURLAsset(url: url, options: nil).tracks.first {

                            //    if it's a video file, get and set window content size to its dimentions
                            if track.mediaType == AVMediaType.video {
                                
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
                                    if webSize != webView.fittingSize {
                                        webView.bounds.size = webView.fittingSize
                                        webSize = webView.bounds.size
                                    }
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
                            restoreSettings(url.absoluteString)
                        }
                    } else {
                        title = appDelegate.appName
                    }
                    
                    self.view.window?.title = title

                    // Remember for later restoration
                    if let doc = self.document, let hpc = doc.heliumPanelController {
                        self.view.window?.representedURL = url
                        hpc.updateTitleBar(didChange: false)
                        NSApp.addWindowsItem(self.view.window!, title: doc.displayName, filename: false)
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
            self.view.window?.windowController?.synchronizeWindowTitleWithDocumentName()
            break;
            
        default:
            Swift.print("Unknown observing keyPath \(String(describing: keyPath))")
        }
    }
    
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
                _ = appDelegate.openURLInNewWindow(url, attachTo: webView.window )
            }
            else
            {
                _ = appDelegate.openURLInNewWindow(url)
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
                    _ = appDelegate.openURLInNewWindow(url, attachTo: webView.window )
                }
                else
                {
                    _ = appDelegate.openURLInNewWindow(url)
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
                    _ = appDelegate.openURLInNewWindow(newUrl, attachTo: webView.window )
                }
                else
                {
                    _ = appDelegate.openURLInNewWindow(newUrl)
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
        //  make sure we are visible
        if let doc = self.document, let window = webView.window, !window.isVisible {
            doc.showWindows()
        }
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
        Swift.print("didFail?: \((error as NSError).code): \(message)")
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
        if let hpc = hpc { hpc.documentDidLoad() }
        
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
            _ = appDelegate.openURLInNewWindow(navigationAction.request.url!)
            return nil
        }
        
        //  We really want to use the supplied config, so use custom setup
        var newWebView : WKWebView?
        Swift.print("createWebViewWith")
        
        if let newURL = navigationAction.request.url {
            do {
                let doc = try NSDocumentController.shared.makeDocument(withContentsOf: newURL, ofType: k.Custom)
                if let hpc = doc.windowControllers.first as? HeliumPanelController, let window = hpc.window {
                    let newView = MyWebView.init(frame: webView.frame, configuration: configuration)
                    let contentView = window.contentView!
                    let wvc = hpc.webViewController

                    hpc.webViewController.webView = newView
                    contentView.addSubview(newView)

                    hpc.webViewController.loadURL(text: newURL.absoluteString)
                    newView.navigationDelegate = wvc
                    newView.uiDelegate = wvc
                    newWebView = hpc.webView
                    wvc.viewDidLoad()

                    //  Setups all done, make us visible
                    doc.showWindows()
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

class ReleaseViewController : WebViewController {
    
}
