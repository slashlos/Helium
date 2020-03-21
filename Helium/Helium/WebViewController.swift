//
//  WebViewController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017-2020 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import WebKit
import AVFoundation
import Carbon.HIToolbox
import Quartz

fileprivate var defaults : UserDefaults {
    get {
        return UserDefaults.standard
    }
}
fileprivate var appDelegate : AppDelegate {
    get {
        return NSApp.delegate as! AppDelegate
    }
}
fileprivate var docController : HeliumDocumentController {
    get {
        return NSDocumentController.shared as! HeliumDocumentController
    }
}

extension WKNavigationType {
    var name : String {
        get {
            let names = ["linkActivated","formSubmitted","backForward","reload","formResubmitted"]
            return names.indices.contains(self.rawValue) ? names[self.rawValue] : "other"
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

class ProgressIndicator : NSProgressIndicator {
    init() {
        super.init(frame: NSMakeRect(0, 0, 32, 32))

        isDisplayedWhenStopped = false
        isIndeterminate = true
        style = .spinning
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        guard !isHidden else { return }
        Swift.print("we want to stop something...")
        
        if let webView : MyWebView = self.superview as? MyWebView, webView.isLoading {
            webView.stopLoading()
        }
    }
}

extension WKBackForwardListItem {
    var article : String {
        get {
            guard let title = self.title, title.count > 0 else { return url.absoluteString }
            return title
        }
    }
}

class MySchemeHandler : NSObject,WKURLSchemeHandler {
    var task: WKURLSchemeTask?
    
    func fetchAndLoad() -> Dictionary<String,Any>? {
        guard let task = task, let url = task.request.url, var dict = defaults.dictionary(forKey: url.absoluteString) else { return nil }
        
        let paths = url.pathComponents
        let type = paths[1]
        guard "/" == paths.first, paths.count == 3 else { return nil }

 
        switch type {// type data,html,text

        case k.html,k.text:
            guard let html = dict[k.text] as? String else { return nil }
            let data = html.dataFromHexString()
            task.didReceive(URLResponse(url: url, mimeType: dict[k.mime] as? String, expectedContentLength: data!.count, textEncodingName: type))
            task.didReceive(html.data(using: .utf8)!)
 
        case k.data:
            guard let hexString : String = dict[k.data] as? String else { return nil }
            let data = hexString.dataFromHexString()
            task.didReceive(URLResponse(url: url, mimeType: dict[k.mime] as? String, expectedContentLength: data!.count, textEncodingName: type))
            task.didReceive(data!)
            dict[k.data] = data!

        default:
            Swift.print("unknown helium: type \(type)")
            return nil
        }
                
        task.didFinish()
        
        return dict
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        task = urlSchemeTask
            
        if let dict = fetchAndLoad(), let type : String = dict[k.type] as? String {
            switch type {
            case k.data:
                guard let data = dict[k.data] as? Data, let mime = dict[k.mime] as? String, let url  = task?.request.url else { return }
                _ = webView.load(data, mimeType: mime, characterEncodingName: k.utf8, baseURL: url)
                
            case k.html,k.text:
                guard let html = dict[k.text] as? String else { return }
                _ = webView.loadHTMLString(html, baseURL: nil)
                
            default:
                Swift.print("unknown helium: type \(type)")
            }
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        task = nil
    }
}

class MyWebView : WKWebView {
    // MARK: TODO: load new files in distinct windows
    dynamic var dirty = false
    var docController : HeliumDocumentController {
        get {
            return NSDocumentController.shared as! HeliumDocumentController
        }
    }

    override class func handlesURLScheme(_ urlScheme: String) -> Bool {
        Swift.print("handleURLScheme: \(urlScheme)")
        return urlScheme == k.scheme
    }
    var selectedText : String?
    var selectedURL : URL?
    var chromeType: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "org.chromium.drag-dummy-type") }
    var finderNode: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "com.apple.finder.node") }
    var webarchive: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "com.apple.webarchive") }
    var acceptableTypes: Set<NSPasteboard.PasteboardType> { return [.URL, .fileURL, .list, .item, .html, .pdf, .png, .rtf, .rtfd, .tiff, finderNode, webarchive] }
    var filteringOptions = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes:NSImage.imageTypes]
    var htmlContents : String? {
        didSet {
            dirty = true
        }
    }
    
    var borderView = WebBorderView()
    var loadingIndicator = ProgressIndicator()
    var incognito = false
    var homeURL : URL {
        get {
            return URL.init(string: incognito ? UserSettings.HomeStrkURL.value : UserSettings.HomePageURL.default)!
        }
    }
    init() {
        super.init(frame: .zero, configuration: appDelegate.webConfiguration)
        
        // Custom user agent string for Netflix HTML5 support
        customUserAgent = UserSettings.UserAgent.value
        
        // Allow zooming
        allowsMagnification = true
        
        // Alow back and forth
        allowsBackForwardNavigationGestures = true
        
        // Allow look ahead views
        allowsLinkPreview = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc internal func menuClicked(_ sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            Swift.print("Menu \(menuItem.title) clicked")
        }
    }
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(incognito, forKey: "incognito")
    }
    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        
        incognito = coder.decodeBool(forKey: "incognito")
    }
    
    @objc open func jump(to item: NSMenuItem) -> WKNavigation? {
        if let nav = go(to: item.representedObject as! WKBackForwardListItem) {
            self.window?.title = item.title
            return nav
        }
        return  nil
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {

        //  Pick off javascript items we want to ignore or handle
        for title in ["Open Link", "Open Link in New Window", "Download Linked File"] {
            if let item = menu.item(withTitle: title) {
                if title == "Download Linked File" {
                    if let url = selectedURL {
                        item.representedObject = url
                        item.action = #selector(MyWebView.downloadLinkedFile(_:))
                        item.target = self
                    }
                    else
                    {
                        item.isHidden = true
                    }
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

        publishContextualMenu(menu);
    }
    
    @objc func openLinkInWindow(_ item: NSMenuItem) {
        if let urlString = self.selectedText, let url = URL.init(string: urlString) {
            _ = load(URLRequest.init(url: url))
        }
        else
        if let url = self.selectedURL {
            _ = load(URLRequest.init(url: url))
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
    var ui : WebViewController {
        get {
            return uiDelegate as! WebViewController
        }
    }
    @objc func downloadLinkedFile(_ item: NSMenuItem) {
        let downloadURL : URL = item.representedObject as! URL
        downloadURL.saveAs(responseHandler: { saveAsURL in
            if let saveAsURL = saveAsURL {
                self.ui.loadFileAsync(downloadURL, to: saveAsURL, completion: { (path, error) in
                    if let error = error {
                        NSApp.presentError(error)
                    }
                    else
                    {
                        if appDelegate.isSandboxed() { _ = appDelegate.storeBookmark(url: saveAsURL, options: [.withSecurityScope]) }
                    }
                })
            }
        })
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

    fileprivate func load(_ request: URLRequest, with cookies: [HTTPCookie]) -> WKNavigation? {
        var request = request
        let headers = HTTPCookie.requestHeaderFields(with: cookies)
        for (name,value) in headers {
            request.addValue(value, forHTTPHeaderField: name)
        }
        return super.load(request)
    }
    
    override func load(_ original: URLRequest) -> WKNavigation? {
        guard let request = (original as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            Swift.print("Unable to create mutable request \(String(describing: original.url))")
            return super.load(original) }
        guard let url = original.url else { return super.load(original) }
        Swift.print("load(_:Request) <= \(request)")
        
        let urlDomain = url.host
        let requestIsSecure = url.scheme == "https"
        var cookies = [HTTPCookie]()

        //  Fetch legal, relevant, authorized cookies
        for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
            if cookie.name.contains("'") { continue } // contains a "'"
            if !cookie.domain.hasSuffix(urlDomain!) { continue }
            if cookie.isSecure && !requestIsSecure { continue }
            cookies.append(cookie)
        }
        
        //  Marshall cookies into header field(s)
        for (name,value) in HTTPCookie.requestHeaderFields(with: cookies) {
            request.addValue(value, forHTTPHeaderField: name)
        }

        //  And off you go...
        return super.load(request as URLRequest)
    }

    func next(url: URL) -> Bool {
        guard let doc = self.webViewController?.document else { return false }

        //  Resolve alias before sandbox bookmarking
        if let webloc = url.webloc { return next(url: webloc) }
        if let original = (url as NSURL).resolvedFinderAlias() { return next(url: original) }

        if url.isFileURL
        {
            if appDelegate.isSandboxed() != appDelegate.storeBookmark(url: url) {
                Swift.print("Yoink, unable to sandbox \(url)")
                return false
            }
            let baseURL = appDelegate.authenticateBaseURL(url)
                
            return self.loadFileURL(url, allowingReadAccessTo: baseURL) != nil
        }
        else
        if self.load(URLRequest(url: url)) != nil {
            doc.fileURL = url
            doc.save(doc)
            return true
        }
        return false
    }
    
    func data(_ data : Data) -> Bool {
        guard let url = URL.init(cache: data) else { return false }
        return next(url: url)
    }
    
    func html(_ html : String) -> Bool {
        guard let url = URL.init(cache: html) else { return false }
        return next(url: url)
    }
    
    func text(_ text : String) -> Bool {
        if let url = URL.init(string: text) { return next(url: url) }
        
        if FileManager.default.fileExists(atPath: text) {
            return next(url: URL.init(fileURLWithPath: text))
        }
        
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                let wvc = self.window?.contentViewController
                (wvc as! WebViewController).loadAttributes(dict: json as! Dictionary<String, Any>)
                return true
            } catch let error as NSError {
                Swift.print("json: \(error.code):\(error.localizedDescription): \(text)")
            }
        }
        
        guard let url = URL.init(cache: text) else { return false }
        return next(url: url)
    }
    
    func text(attrributedString text: NSAttributedString) -> Bool {
        guard let url = URL.init(cache: text) else { return false }
        return next(url: url)
    }
    
    //  MARK: Mouse tracking idle
    var trackingArea : NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if trackingArea != nil {
            self.removeTrackingArea(trackingArea!)
        }
        let options : NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        if let hpc = heliumPanelController {
            hpc.mouseIdle = false
        }
    }

    // MARK: Drag and Drop - Before Release
    func shouldAllowDrag(_ info: NSDraggingInfo) -> Bool {
        guard let doc = webViewController?.document, doc.docGroup == .helium else { return false }
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
                kUTTypeImage, kUTTypeVideo, kUTTypeMovie, kUTTypeText],
             NSPasteboard.ReadingOptionKey(rawValue: PlayList.className()) : true,
             NSPasteboard.ReadingOptionKey(rawValue: PlayItem.className()) : true]
        let pboard = sender.draggingPasteboard
        let items = pboard.pasteboardItems
        let window = self.window!
        var handled = 0
        
        for item in items! {
            if handled == items!.count { break }
            
            if let urlString = item.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeURL as String)) {
                handled += self.next(url: URL(string: urlString)!) ? 1 : 0
                continue
            }

            for type in pboard.types! {
                Swift.print("web type: \(type)")

                switch type {
                case .files:
                    if let files = pboard.propertyList(forType: type) {
                        Swift.print("files \(files)")
                    }
                    
                case .URL, .fileURL:
                    if let urlString = item.string(forType: type), let url = URL.init(string: urlString) {
                        // MARK: TODO: load new files in distinct windows
                        if url.isFileURL || dirty { viewOptions.insert(.t_view) }
                        
                        if viewOptions.contains(.t_view) {
                            handled += appDelegate.openURLInNewWindow(url, attachTo: window) ? 1 : 0
                        }
                        else
                        if viewOptions.contains(.w_view) {
                            handled += appDelegate.openURLInNewWindow(url) ? 1 : 0
                        }
                        else
                        {
                            handled += self.next(url: url) ? 1 : 0
                        }
                        //  Multiple files implies new windows
                        viewOptions.insert(.w_view)
                    }
                    else
                    if let data = item.data(forType: type), let url = NSKeyedUnarchiver.unarchiveObject(with: data) {
                        if viewOptions.contains(.t_view) {
                            handled += appDelegate.openURLInNewWindow(url as! URL , attachTo: window) ? 1 : 0
                        }
                        else
                        if viewOptions.contains(.w_view) {
                            handled += appDelegate.openURLInNewWindow(url as! URL) ? 1 : 0
                        }
                        else
                        {
                            handled += self.next(url: url as! URL) ? 1 : 0
                        }
                        //  Multiple files implies new windows
                        viewOptions.insert(.w_view)
                    }
                    else
                    if let urls: Array<AnyObject> = pboard.readObjects(forClasses: [NSURL.classForCoder()], options: options) as Array<AnyObject>? {
                        for url in urls as! [URL] {
                            if viewOptions.contains(.t_view) {
                                handled += appDelegate.openURLInNewWindow(url, attachTo: window) ? 1 : 0
                            }
                            else
                            if viewOptions.contains(.w_view) {
                                handled += appDelegate.openURLInNewWindow(url) ? 1 : 0
                            }
                            else
                            {
                                handled += load(URLRequest.init(url: url)) != nil ? 1 : 0
                            }

                            if let cvc : WebViewController = window.contentViewController as? WebViewController {
                                cvc.representedObject = url
                            }
                        }
                    }
                    
                case .list:
                    if let playlists: Array<AnyObject> = pboard.readObjects(forClasses: [PlayList.classForCoder()], options: options) as Array<AnyObject>? {
                        for playlist in playlists {
                            for playitem in playlist.list {
                                if viewOptions.contains(.t_view) {
                                    handled += appDelegate.openURLInNewWindow(playitem.link, attachTo: window) ? 1 : 0
                                }
                                else
                                if viewOptions.contains(.w_view) {
                                    handled += appDelegate.openURLInNewWindow(playitem.link) ? 1 : 0
                                }
                                else
                                {
                                    handled += self.next(url: playitem.link) ? 1 : 0
                                }
                                
                                //  Multiple files implies new windows
                                viewOptions.insert(.w_view)
                            }
                            handled += 1
                        }
                    }
                    
                case .item:
                    if let playitems: Array<AnyObject> = pboard.readObjects(forClasses: [PlayItem.classForCoder()], options: options) as Array<AnyObject>? {
                        var items = 0
                        
                        for playitem in playitems {
                            Swift.print("item: \(playitem)")
                            if viewOptions.contains(.t_view) {
                                items += appDelegate.openURLInNewWindow(playitem.link, attachTo: window) ? 1 : 0
                            }
                            else
                            if viewOptions.contains(.w_view) {
                                items += appDelegate.openURLInNewWindow(playitem.link) ? 1 : 0
                            }
                            else
                            {
                                items += self.next(url: playitem.link) ? 1 : 0
                            }
                            
                            //  Multiple files implies new windows
                            viewOptions.insert(.w_view)
                            handled += (items == playitems.count) ? 1 : 0
                        }
                    }
                    
                case .data:
                    if let data = item.data(forType: type) {
                        handled += self.data(data) ? 1 : 0
                    }

                case .rtf, .rtfd:
                    if let data = item.data(forType: type), let text = NSAttributedString(rtf: data, documentAttributes: nil) {
                        handled += self.text(text.string) ? 1 : 0
                    }
                    
                case .string, .tabularText:
                    if let text = item.string(forType: type) {
                        handled += self.text(text) ? 1 : 0
                    }
                    
                case webarchive:
                    if let data = item.data(forType: type) {
                        let html = String(decoding: data, as: UTF8.self)
                        handled += self.html(html) ? 1 : 0
                    }
                    else
                    if let text = item.string(forType: type) {
                        Swift.print("\(type) text \(String(describing: text))")
                        handled += self.text(text) ? 1 : 0
                    }
                    else
                    if let prop = item.propertyList(forType: type) {
                        if let html = String.init(data: prop as! Data, encoding: .utf8)  {
                            handled += self.html(html) ? 1 : 0
                        }
                        else
                        {
                            Swift.print("\(type) prop \(String(describing: prop))")
                        }
                    }
 
                case chromeType:
                    if let data = item.data(forType: type) {
                        let html = String(decoding: data, as: UTF8.self)
                        if html.count > 0 {
                            handled += self.html(html) ? 1 : 0
                        }
                    }
                    if let text = item.string(forType: type) {
                        Swift.print("\(type) text \(String(describing: text))")
                        if text.count > 0 {
                            handled += self.text(text) ? 1 : 0
                        }
                    }
                    if let prop = item.propertyList(forType: type) {
                        if let html = String.init(data: prop as! Data, encoding: .utf8)  {
                            handled += self.html(html) ? 1 : 0
                        }
                        else
                        {
                            Swift.print("\(type) prop \(String(describing: prop))")
                        }
                    }
                    
///                case .filePromise:
///                    Swift.print(".filePromise")
///                    break
///
///                case .promise:
///                    Swift.print(".promise")
///                    break
                    
                default:
                    Swift.print("unkn: \(type)")

                    if let data = item.data(forType: type) {
                        handled += self.data(data) ? 1 : 0
                    }
                }
                if handled == items?.count { break }
            }
        }
        
        //  Either way signal we're done
        isReceivingDrag = false
        
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
    func publishContextualMenu(_ menu: NSMenu) {
        guard let window = self.window else { return }
        let wvc = window.contentViewController as! WebViewController
        let hpc = window.windowController as! HeliumPanelController
        let document : Document = hpc.document as! Document
        let settings = (hpc.document as! Document).settings
        let autoHideTitle = hpc.autoHideTitlePreference
        let translucency = hpc.translucencyPreference
        
        //  Remove item(s) we cannot support
        for title in ["Enter Picture in Picture"] {
            if let item = menu.item(withTitle: title) {
                menu.removeItem(item)
            }
        }
        
        //  Alter item(s) we want to support
        for title in ["Download Video", "Enter Full Screen", "Open Video in New Window"] {
            if let item = menu.item(withTitle: title) {
                Swift.print("old: \(title) -> target:\(String(describing: item.target)) action:\(String(describing: item.action)) tag:\(item.tag)")
                if item.title.hasPrefix("Download") {
                    item.isHidden = true
                }
                else
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
            }
        }
        var item: NSMenuItem

        item = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "")
        menu.addItem(item)
        item = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        menu.addItem(item)
        item = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "")
        menu.addItem(item)
        menu.addItem(NSMenuItem.separator())

        //  Add backForwardList navigation if any
        let back = backForwardList.backList
        let fore = backForwardList.forwardList
        if back.count > 0 || fore.count > 0 {
            item = NSMenuItem(title: "History", action: #selector(menuClicked(_:)), keyEquivalent: "")
            menu.addItem(item)
            let jump = NSMenu()
            item.submenu = jump

            for prev in back {
                item = NSMenuItem(title: prev.article, action: #selector(MyWebView.jump(to:)), keyEquivalent: "")
                item.toolTip = prev.url.absoluteString
                item.representedObject = prev
                jump.addItem(item)
            }
            if let curr = backForwardList.currentItem {
                item = NSMenuItem(title: curr.article, action: #selector(MyWebView.jump(to:)), keyEquivalent: "")
                item.toolTip = curr.url.absoluteString
                item.representedObject = curr
                item.state = .on
                jump.addItem(item)
            }
            for next in fore {
                item = NSMenuItem(title: next.article, action: #selector(MyWebView.jump(to:)), keyEquivalent: "")
                item.toolTip = next.url.absoluteString
                item.representedObject = next
                jump.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        //  Add tab support once present
        var tabItemUpdated = false
        if let tabs = self.window?.tabbedWindows, tabs.count > 0 {
            if tabs.count > 1 {
                item = NSMenuItem(title: "Tabs", action: #selector(menuClicked(_:)), keyEquivalent: "")
                menu.addItem(item)
                let jump = NSMenu()
                item.submenu = jump
                for tab in tabs {
                    item = NSMenuItem(title: tab.title, action: #selector(hpc.selectTabItem(_:)), keyEquivalent: "")
                    if tab == self.window { item.state = .on }
                    item.toolTip = tab.representedURL?.absoluteString
                    item.representedObject = tab
                    jump.addItem(item)
                }
            }
            item = NSMenuItem(title: "To New Window", action: #selector(window.moveTabToNewWindow(_:)), keyEquivalent: "")
            menu.addItem(item)
            item = NSMenuItem(title: "Show All Tabs", action: #selector(window.toggleTabOverview(_:)), keyEquivalent: "")
            menu.addItem(item)
            tabItemUpdated = true
        }
        if docController.documents.count > 1 {
            item = NSMenuItem(title: "Merge All Windows", action: #selector(window.mergeAllWindows(_:)), keyEquivalent: "")
            menu.addItem(item)
            tabItemUpdated = true
        }
        if tabItemUpdated { menu.addItem(NSMenuItem.separator()) }

        item = NSMenuItem(title: "New Window", action: #selector(docController.newDocument(_:)), keyEquivalent: "")
        item.target = docController
        item.tag = 1
        menu.addItem(item)
        
        item = NSMenuItem(title: "New Tab", action: #selector(docController.newDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
        item.representedObject = self.window
        item.target = docController
        item.isAlternate = true
        item.tag = 3
        menu.addItem(item)
        
        item = NSMenuItem(title: "Load", action: #selector(menuClicked(_:)), keyEquivalent: "")
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

        item = NSMenuItem(title: "Preferences", action: #selector(menuClicked(_:)), keyEquivalent: "")
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

        item = NSMenuItem(title: "Snapshot", action: #selector(webViewController?.snapshot(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = wvc
        menu.addItem(item)
        
        item = NSMenuItem(title: "Save", action: #selector(document.save(_:)) as Selector, keyEquivalent: "")
        item.representedObject = self.window
        item.target = document
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
    
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
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

class WebViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, NSMenuDelegate, NSTabViewDelegate, WKHTTPCookieStoreObserver, QLPreviewPanelDataSource, QLPreviewPanelDelegate, URLSessionDelegate,URLSessionTaskDelegate,URLSessionDownloadDelegate {

    @available(OSX 10.13, *)
    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        DispatchQueue.main.async {
            let waitGroup = DispatchGroup()
            guard let url = self.webView.url, let urlDomain = url.host else { return }
            cookieStore.getAllCookies { cookies in
                for cookie in cookies {
                    if cookie.domain.hasSuffix(urlDomain) {
                        waitGroup.enter()
                        self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: { waitGroup.leave() })
                    }
                }
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

        //  Programmatically create a new web view
        //  with shared config, prefs, cookies(?).
        webView.frame = view.frame
        view.addSubview(webView)
        
        //  Wire in ourselves as its delegate
        webView.navigationDelegate = self
        webView.uiDelegate = self

        borderView.frame = view.frame
        view.addSubview(borderView)

        view.addSubview(loadingIndicator)

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
            selector: #selector(WebViewController.snapshot(_:)),
            name: NSNotification.Name(rawValue: "HeliumSnapshotAll"),
            object: nil)
        
        //  Watch command key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.commandKeyDown(_:)),
            name: NSNotification.Name(rawValue: "commandKeyDown"),
            object: nil)

        //  Watch option + command key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.optionAndCommandKeysDown(_:)),
            name: NSNotification.Name(rawValue: "optionAndCommandKeysDown"),
            object: nil)
        /*
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avPlayerView(_:)),
            name: NSNotification.Name(rawValue: "AVPlayerView"),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wkScrollView(_:)),
            name: NSNotification.Name(rawValue: "NSScrollView"),
            object: nil)
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
            if subview.className == "AVPlayerView" {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AVPlayerView"), object: subview)
            }
            if subview.className == "NSScrollView" {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "NSScrollView"), object: subview)
            }
            if subview.className == "WKFlippedView" {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "WKFlippedView"), object: subview)
            }
        }
        
        let newDidAddSubviewImplementation = imp_implementationWithBlock(unsafeBitCast(newDidAddSubviewImplementationBlock, to: AnyObject.self))
        method_setImplementation(originalDidAddSubviewMethod!, newDidAddSubviewImplementation)*/
        
        // WebView KVO - load progress, title
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.loading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
    
        //  Intercept drags
        webView.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0)})
        webView.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        webView.registerForDraggedTypes(Array(webView.acceptableTypes))
        observing = true
        
        //  Watch javascript selection messages unless already done
        let controller = webView.configuration.userContentController
        guard controller.userScripts.count == 0 else { return }
        
        controller.add(self, name: "newWindowWithUrlDetected")
        controller.add(self, name: "newSelectionDetected")
        controller.add(self, name: "newUrlDetected")

        let js = NSString.string(fromAsset: "Helium-js")
        let script = WKUserScript.init(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)
        
        //  make http: -> https: guarded by preference
        if #available(OSX 10.13, *), UserSettings.PromoteHTTPS.value {
            //  https://developer.apple.com/videos/play/wwdc2017/220/ 14:05, 21:04
            let jsonString = """
                [{
                    "trigger" : { "url-filter" : ".*" },
                    "action" : { "type" : "make-https" }
                }]
            """
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "httpRuleList", encodedContentRuleList: jsonString, completionHandler: {(list, error) in
                guard let contentRuleList = list else { fatalError("emptyRulelist after compilation!") }
                controller.add(contentRuleList)
            })
        }
        
        // TODO: Watch click events
        // https://stackoverflow.com/questions/45062929/handling-javascript-events-in-wkwebview/45063303#45063303
        
        let source = "document.addEventListener('click', function(){ window.webkit.messageHandlers.clickMe.postMessage('clickMe clickMe!'); })"
        let clickMe = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        controller.addUserScript(clickMe)
        controller.add(self, name: "clickMe")
        
        //  Dealing with cookie changes
        let cookieChangeScript = WKUserScript.init(source: "window.webkit.messageHandlers.updateCookies.postMessage(document.cookie);",
            injectionTime: .atDocumentStart, forMainFrameOnly: false)
        controller.addUserScript(cookieChangeScript)
        controller.add(self, name: "updateCookies")
    }
    /*
    @objc func avPlayerView(_ note: NSNotification) {
        print("AV Player \(String(describing: note.object)) will be opened now")
        guard let view = note.object as? NSView else { return }
        
        Swift.print("player is \(view.className)")
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
    
    @objc func wkScrollView(_ note: NSNotification) {
        print("WK Scroll View \(String(describing: note.object)) will be opened now")
        if let scrollView : NSScrollView = note.object as? NSScrollView {
            scrollView.autohidesScrollers = true
        }
    }*/
    
    override func viewWillLayout() {
        super.viewWillLayout()

        //  the autolayout is complete only when the view has appeared.
        webView.autoresizingMask = [.height,.width]
        if 0 == webView.constraints.count { webView.fit(view) }
        
        borderView.autoresizingMask = [.height,.width]
        if 0 == borderView.constraints.count { borderView.fit(view) }
        
        if 0 == loadingIndicator.constraints.count { loadingIndicator.center(view) }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if let document = self.document, let url = document.fileURL {
            _ = loadURL(url: url)
        }
        else
        {
            clear()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        guard let doc = self.document, doc.docGroup == .helium else { return }
        
        //  https://stackoverflow.com/questions/32056874/programmatically-wkwebview-inside-an-uiview-with-auto-layout
 
        //  the autolayout is complete only when the view has appeared.
        webView.autoresizingMask = [.height,.width]
        if 0 == webView.constraints.count { webView.fit(webView.superview!) }
        
        borderView.autoresizingMask = [.height,.width]
        if 0 == borderView.constraints.count { borderView.fit(borderView.superview!) }
        
        loadingIndicator.center(loadingIndicator.superview!)
        loadingIndicator.bind(NSBindingName(rawValue: "animate"), to: webView as Any, withKeyPath: "loading", options: nil)
        
        //  ditch loading indicator background
        loadingIndicator.appearance = NSAppearance.init(named: NSAppearance.Name.aqua)
    }
    
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

        //  TODO: ditch horizonatal scroll when not over
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
        super .viewWillDisappear()
        
        guard let wc = self.view.window?.windowController, !wc.isKind(of: ReleasePanelController.self) else { return }
        if let navDelegate : NSObject = webView.navigationDelegate as? NSObject {
        
            webView.stopLoading()
            webView.uiDelegate = nil
            webView.navigationDelegate = nil

            // Wind down all observations
            if observing {
                webView.removeObserver(navDelegate, forKeyPath: "estimatedProgress")
                webView.removeObserver(navDelegate, forKeyPath: "loading")
                webView.removeObserver(navDelegate, forKeyPath: "title")
                observing = false
            }
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
    
    @objc internal func cancel(_ sender: AnyObject)
    {
        webView.stopLoading()
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
        self.webView.configuration.preferences.setValue((sender.state != .on), forKey: "developerExtrasEnabled")
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
            if response == .OK {
                // MARK: TODO: load new files in distinct windows
                /*if self.webView.dirty {*/ viewOptions.insert(.t_view) ///}

                let urls = open.urls
                var handled = 0

                for url in urls {
                    if viewOptions.contains(.t_view) {
                        handled += appDelegate.openURLInNewWindow(url, attachTo: window) ? 1 : 0
                    }
                    else
                    if viewOptions.contains(.w_view) {
                        handled += appDelegate.openURLInNewWindow(url) ? 1 : 0
                    }
                    else
                    {
                        handled += self.webView.next(url: url) ? 1 : 0
                    }
                    
                    //  Multiple files implies new windows
                    viewOptions.insert(.w_view)
                }
            }
        })
    }
    
    @objc @IBAction func openLocationPress(_ sender: AnyObject) {
        let viewOptions = ViewOptions(rawValue: sender.tag)
        let window = self.view.window
        var urlString = currentURLString
        
        if let rawString = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string), rawString.isValidURL() {
            urlString = rawString
        }

        appDelegate.didRequestUserUrl(RequestUserStrings (
            currentURLString:   urlString,
            alertMessageText:   "URL to load",
            alertButton1stText: "Load",     alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.HomePageURL.value),
                                      onWindow: window as? HeliumPanel,
                                      title: "Enter URL",
                                      acceptHandler: { (urlString: String) in
                                        guard let newURL = URL.init(string: urlString) else { return }
                                        
                                        if viewOptions.contains(.t_view) {
                                            _ = appDelegate.openURLInNewWindow(newURL, attachTo: window)
                                        }
                                        else
                                        if viewOptions.contains(.w_view) {
                                            _ = appDelegate.openURLInNewWindow(newURL)
                                        }
                                        else
                                        {
                                            _ = self.webView.next(url: newURL) ? 1 : 0
                                        }
        })
    }
    @objc @IBAction func openSearchPress(_ sender: AnyObject) {
        let viewOptions = ViewOptions(rawValue: sender.tag)
        let window = self.view.window

        let name = k.searchNames[ UserSettings.Search.value ]
        let info = k.searchInfos[ UserSettings.Search.value ]

        appDelegate.didRequestSearch(RequestUserStrings (
            currentURLString:   nil,
            alertMessageText:   "Search",
            alertButton1stText: name,         alertButton1stInfo: info,
            alertButton2ndText: "Cancel",     alertButton2ndInfo: nil,
            alertButton3rdText: "New Window", alertButton3rdInfo: "Results in new window"),
                                     onWindow: self.view.window as? HeliumPanel,
                                     title: "Web Search",
                                     acceptHandler: { (newWindow: Bool, searchURL: URL) in
                                        if viewOptions.contains(.t_view) {
                                            _ = appDelegate.openURLInNewWindow(searchURL, attachTo: window)
                                        }
                                        else
                                        if viewOptions.contains(.w_view) {
                                            _ = appDelegate.openURLInNewWindow(searchURL)
                                        }
                                        else
                                        {
                                            _ = self.loadURL(url: searchURL)
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
        guard let window = self.view.window, window.isVisible else { return }
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
                if (result == .OK) {
                    desktop = openPanel.url!
                    _ = appDelegate.storeBookmark(url: desktop, options: appDelegate.rwOptions)
                    appDelegate.desktopData = appDelegate.bookmarks[desktop]
                    UserSettings.SnapshotsURL.value = desktop.absoluteString
                    DispatchQueue.main.async {
                        if !appDelegate.saveBookmarks() {
                            Swift.print("Yoink, unable to save desktop booksmark(s)")
                        }
                    }
                }
            }
        }
        
        //  Form a filename: ~/"<app's name> View Shot <timestamp>"
        let dateFMT = DateFormatter()
        dateFMT.locale = Locale(identifier: "en_US_POSIX")
        dateFMT.dateFormat = "yyyy-MM-dd"
        let timeFMT = DateFormatter()
        timeFMT.locale = Locale(identifier: "en_US_POSIX")
        timeFMT.dateFormat = "h.mm.ss a"
        let now = Date()

        let path = URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value).appendingPathComponent(
            String(format: "%@ Shapshot %@ at %@.png", appDelegate.appName, dateFMT.string(from: now), timeFMT.string(from: now)))
        
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
            currentURLString:   webView.customUserAgent,
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
            Swift.print("represented object \(String(describing: representedObject))")
        }
    }
    
    // MARK: Loading
    
    internal var currentURLString: String? {
        return webView.url?.absoluteString
    }

    internal func loadURL(text: String) -> Bool {
        let text = UrlHelpers.ensureScheme(text)
        if let url = URL(string: text) {
            return webView.load(URLRequest.init(url: url)) != nil
        }
        return false
    }

    internal func loadURL(url: URL) -> Bool {
        return webView.next(url: url)
    }

    @objc internal func loadURL(urlFileURL: Notification) -> Bool {
        if let fileURL = urlFileURL.object, let userInfo = urlFileURL.userInfo {
            if userInfo["hwc"] as? NSWindowController == self.view.window?.windowController {
                return loadURL(url: fileURL as! URL)
            }
            else
            {
                //  load new window with URL
                return loadURL(url: urlFileURL.object as! URL)
            }
        }
        return false
    }
    
    @objc func loadURL(urlString: Notification) -> Bool {
        if let userInfo = urlString.userInfo {
            if userInfo["hwc"] as? NSWindowController != self.view.window?.windowController {
                return false
            }
        }
        
        if let string = urlString.object as? String {
            return loadURL(text: string)
        }
        return false
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
        Swift.print("UCC \(message.name) => \"\(message.body)\"")
        
        switch message.name {
        case "newWindowWithUrlDetected":
            if let url = URL.init(string: message.body as! String) {
                webView.selectedURL = url
                Swift.print("new win -> \(url.absoluteString)")
            }
            
        case "newSelectionDetected":
            if let urlString : String = message.body as? String
            {
                webView.selectedText = urlString
                Swift.print("new str -> \(urlString)")
            }
            
        case "newUrlDetected":
            if let url = URL.init(string: message.body as! String) {
                webView.selectedURL = url
                Swift.print("new url -> \(url.absoluteString)")
            }
            
        case "clickMe":
            Swift.print("message: \(message.body)")
            break
            
        case "updateCookies":
            guard appDelegate.shareWebCookies,appDelegate.storeWebCookies else { return }
            let updates = (message.body as! String).components(separatedBy: "; ")
            Swift.print("cookie(\(updates.count)) \(message.body)")

            for update in updates {
                let keyval = update.components(separatedBy: "=")
                guard keyval.count == 2 else { continue }
                
                if let url = webView.url, let cookies : [HTTPCookie] = HTTPCookieStorage.shared.cookies(for: url) {
                    let cookieStorage = HTTPCookieStorage.shared

                    for cookie in cookies {
                        if cookie.name == keyval.first! {
                            var properties : Dictionary<HTTPCookiePropertyKey,Any> = (cookie.properties as AnyObject).mutableCopy() as! Dictionary<HTTPCookiePropertyKey, Any>
                            properties[HTTPCookiePropertyKey("HTTPCookieValue")] = keyval.last!
                            if let updated = HTTPCookie.init(properties: properties) {
                                cookieStorage.setCookie(updated)
                            }
                        }
                        else
                        {
                            Swift.print("+ cookie \(update)")
                            if let newbie = HTTPCookie(properties: [
                                .domain:    url.host!,
                                .path:      "/",
                                .name:      keyval.first!,
                                .value:     keyval.last!,
                                .secure:    url.scheme == "https"]) {
                                cookieStorage.setCookie(newbie)
                            }
                        }
                    }
                }
            }
            
        default:
            appDelegate.userAlertMessage("Unhandled user controller message", info: message.name)
        }
    }

    // MARK: Webview functions
    // https://stackoverflow.com/a/56338070/564870
    class func clean() {
        guard #available(iOS 9.0, *) else {return}

        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                #if DEBUG
                    print("WKWebsiteDataStore record deleted:", record)
                #endif
            }
        }
    }
    
    func clear() {
        // Reload to home page (or default if no URL stored in UserDefaults)
        _ = webView.load(URLRequest.init(url: webView.homeURL))
    }

	var webView = MyWebView()
	var webImageView = NSImageView.init()
	var webSize = CGSize(width: 0,height: 0)
    
    var borderView : WebBorderView {
        get {
            return webView.borderView
        }
    }
    var loadingIndicator : ProgressIndicator {
        get {
            return webView.loadingIndicator
        }
    }
	
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let mwv = object as? MyWebView, mwv == self.webView else { return }

        //  We *must* have a key path
        guard let keyPath = keyPath else { return }
        
        switch keyPath {
        case "estimatedProgress":

            if let progress = change?[NSKeyValueChangeKey(rawValue: "new")] as? Float {
                let percent = progress * 100
                var title : String = String(format: "Loading... %.2f%%", percent)
                if percent == 100, let url = (self.webView.url) {

                    //  Initial recording for this url session
                    if UserSettings.HistorySaves.value, !webView.incognito {
                        let notif = Notification(name: Notification.Name(rawValue: "HeliumNewURL"), object: url, userInfo: [k.fini : false, k.view : self.webView as Any])
                        NotificationCenter.default.post(notif)
                    }
                    
                    // once loaded update window title,size with video name,dimension
                    if let toolTip = (mwv.url?.absoluteString) {
                        if url.isFileURL {
                            title = url.lastPathComponent
                        } else
                        if let doc = self.document {
                            title = doc.displayName
                        }
                        else
                        {
                            title = appDelegate.appName
                        }
                        self.heliumPanelController?.hoverBar?.superview?.toolTip = toolTip.removingPercentEncoding

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
                    } else {
                        title = appDelegate.appName
                    }
                    
                    // Remember for later restoration
                    NSApp.changeWindowsItem(self.view.window!, title: title, filename: false)

                }
            }
            
        case "loading":
            guard let loading = change?[NSKeyValueChangeKey(rawValue: "new")] as? Bool, loading == loadingIndicator.isHidden else { return }
            Swift.print("loading: \(loading ? "YES" : "NO")")
            
        case "title":
            if let newTitle = change?[NSKeyValueChangeKey(rawValue: "new")] as? String {
                if let window = self.view.window {
                    window.title = newTitle
                    NSApp.changeWindowsItem(window, title: newTitle, filename: false)
                }
            }
             
        case "url":///currently *not* KVO ?
            if let urlString = change?[NSKeyValueChangeKey(rawValue: "new")] as? String {
                guard let dict = defaults.dictionary(forKey: urlString) else { return }
                
                if let doc = self.document {
                    doc.restoreSettings(with: dict)
                }
            }

        default:
            Swift.print("Unknown observing keyPath \(String(describing: keyPath))")
        }
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
    
    // MARK:- Navigation Delegate

    // Redirect Hulu and YouTube to pop-out videos
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        Swift.print(String(format: "0DP: navigationAction: %p", webView))

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
                _ = loadURL(url: newUrl)
            }
        }
        
        Swift.print("navType: \(navigationAction.navigationType.name)")
        
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    /*  OPTIONAL @available(OSX 10.15, *)
     /** @abstract Decides whether to allow or cancel a navigation after its
     response is known.
     @param webView The web view invoking the delegate method.
     @param navigationResponse Descriptive information about the navigation
     response.
     @param decisionHandler The decision handler to call to allow or cancel the
     navigation. The argument is one of the constants of the enumerated type WKNavigationResponsePolicy.
     @discussion If you do not implement this method, the web view will allow the response, if the web view can show it.
     */
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
    }
    */
    var quickLookURL : URL?
    var quickLookFilename: String?
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { return 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        let url = quickLookURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(quickLookFilename!)
        return url as QLPreviewItem
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let response = navigationResponse.response as? HTTPURLResponse,
            let url = navigationResponse.response.url else {
                decisionHandler(.allow)
                return
        }
        
        Swift.print(String(format: "1DP navigationResponse: %p <= %@", webView, url.absoluteString))
        
        //  load cookies
        if #available(OSX 10.13, *) {
            if let headerFields = response.allHeaderFields as? [String:String] {
                Swift.print("\(url.absoluteString) allHeaderFields:\n\(headerFields)")
                let waitGroup = DispatchGroup()

                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                cookies.forEach({ cookie in
                    waitGroup.enter()
                    webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: { waitGroup.leave() })
                })
            }
        }
        
        guard !url.hasUserContent(), url.hasDataContent(), let suggestion = response.suggestedFilename else { decisionHandler(.allow); return }
        let downloadDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let saveURL = downloadDir.appendingPathComponent(suggestion)
        saveURL.saveAs(responseHandler: { saveAsURL in
            if let saveAsURL = saveAsURL {
                self.loadFileAsync(url, to: saveAsURL, completion: { (path, error) in
                    if let error = error {
                        NSApp.presentError(error)
                    }
                    else
                    {
                        if appDelegate.isSandboxed() { _ = appDelegate.storeBookmark(url: saveAsURL, options: [.withSecurityScope]) }
                    }
                })
            }

            decisionHandler(.cancel)
            self.backPress(self)
         })
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Swift.print(String(format: "1LD: %p didStartProvisionalNavigation: %p %@", navigation, webView, webView.url!.debugDescription))
        
        //  Restore setting not done by document controller
        if let hpc = heliumPanelController { hpc.documentDidLoad() }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        Swift.print(String(format: "2SR: %p didReceiveServerRedirectForProvisionalNavigation: %p", navigation, webView))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Swift.print(String(format: "?LD: %p didFailProvisionalNavigation: %p", navigation, webView) + " \((error as NSError).code): \(error.localizedDescription)")
        handleError(error)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Swift.print(String(format: "2NV: %p - didCommit: %p", navigation, webView))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        guard let url = webView.url else { return }
        
        Swift.print(String(format: "3NV: %p didFinish: %p", navigation, webView) + " \"\(String(describing: webView.title))\" => \(url.absoluteString)")
        if let doc = self.document, let dict = defaults.dictionary(forKey: url.absoluteString) {
            doc.restoreSettings(with: dict)
        }
        
        //  Finish recording of for this url session
        if UserSettings.HistorySaves.value, let webView = (webView as? MyWebView), !webView.incognito {
            let notif = Notification(name: Notification.Name(rawValue: "HeliumNewURL"), object: url, userInfo: [k.fini : true])
            NotificationCenter.default.post(notif)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Swift.print(String(format: "?NV: %p didFail: %p", navigation, webView) + " \((error as NSError).code): \(error.localizedDescription)")
        handleError(error)
    }
    
    fileprivate func handleError(_ error: Error) {
        let message = error.localizedDescription
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
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authMethod = challenge.protectionSpace.authenticationMethod
        Swift.print(String(format: "2AC: didReceive: %p \(authMethod)", webView))

        guard let serverTrust = challenge.protectionSpace.serverTrust else { return completionHandler(.useCredential, nil) }
        let exceptions = SecTrustCopyExceptions(serverTrust)
        SecTrustSetExceptions(serverTrust, exceptions)
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Swift.print(String(format: "3DT: webViewWebContentProcessDidTerminate: %p", webView))
        
        //  If incognito tear down...
        if let webView = (webView as? MyWebView), webView.incognito {
            Swift.print("webView specific tear down for incognito...")
        }
    }
    
    //  MARK:- UI Delegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        Swift.print(String(format: "UI: %p createWebViewWith:", webView))

        if navigationAction.targetFrame == nil {
            _ = appDelegate.openURLInNewWindow(navigationAction.request.url!)
            return nil
        }
        
        //  We really want to use the supplied config, so use custom setup
        var newWebView : WKWebView?
        
        if let newURL = navigationAction.request.url {
            do {
                let doc = try NSDocumentController.shared.makeDocument(withContentsOf: newURL, ofType: k.Custom)
                if let hpc = doc.windowControllers.first, let window = hpc.window, let wvc = window.contentViewController as? WebViewController {
                    newWebView = MyWebView()
                    wvc.webView = newWebView as! MyWebView
                    wvc.viewDidLoad()
                    
                    _ = wvc.loadURL(url: newURL)
                 }
            } catch let error {
                NSApp.presentError(error)
            }
        }

        return newWebView
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        Swift.print(String(format: "UI: %p webViewDidClose:", webView))
        webView.stopLoading()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
        Swift.print(String(format: "UI: %p runJavaScriptAlertPanelWithMessage: %@", webView, message))

        appDelegate.userAlertMessage(message, info: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (Bool) -> Void) {
        Swift.print(String(format: "UI: %p runJavaScriptConfirmPanelWithMessage: %@", webView, message))

        completionHandler( appDelegate.userConfirmMessage(message, info: nil) )
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String?) -> Void) {
        Swift.print(String(format: "UI: %p runJavaScriptTextInputPanelWithPrompt: %@", webView, prompt))

        completionHandler( appDelegate.userTextInput(prompt, defaultText: defaultText) )
    }
    
    func webView(_ webView: WKWebView, didFinishLoad navigation: WKNavigation) {
        Swift.print(String(format: "3LD: %p didFinishLoad: %p", navigation, webView))
        //  deprecated
    }
    
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        Swift.print(String(format: "UI: %p runOpenPanelWith:", webView))
        
        let openPanel = NSOpenPanel()
                
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        openPanel.canChooseFiles = false
        if #available(OSX 10.13.4, *) {
            openPanel.canChooseDirectories = parameters.allowsDirectories
        } else {
            openPanel.canChooseDirectories = false
        }
        openPanel.canCreateDirectories = false
        
        openPanel.begin() { (result) -> Void in
            if result == .OK {
                completionHandler(openPanel.urls)
            }
            else
            {
                completionHandler(nil)
            }
        }
    }
    
    //  MARK:- URLSessionDelegate
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Swift.print(String(format: "SU: %p didBecomeInvalidWithError: %@", session, error?.localizedDescription ?? "?Error"))
        if let error = error {
            NSApp.presentError(error)
        }
    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Swift.print(String(format: "SU: %p challenge:", session))

    }

    //  MARK: URLSessionTaskDelegate
    @available(OSX 10.13, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        Swift.print(String(format: "SU: %p task: %ld willBeginDelayedRequest: request: %@", session, task.taskIdentifier, request.url?.absoluteString ?? "?url"))

    }
    
    @available(OSX 10.13, *)
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        Swift.print(String(format: "SU: %p task: %ld taskIsWaitingForConnectivity:", session, task.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        Swift.print(String(format: "SU: %p task: %ld willPerformHTTPRedirection:", session, task.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Swift.print(String(format: "SU: %p task: %ld challenge:", session, task.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        Swift.print(String(format: "SU: %p task: %ld needNewBodyStream:", session, task.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        Swift.print(String(format: "SU: %p task: %ld didSendBodyData:", session))

    }
    
    @available(OSX 10.12, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        Swift.print(String(format: "SU: %p task: %ld didFinishCollecting:", session))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Swift.print(String(format: "SU: %p task: %ld didCompleteWithError:", session))

    }
    
    //  MARK: URLSessionDataDelegate
        
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        Swift.print(String(format: "SU: %p dataTask: %ld didReceive response:", session))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        Swift.print(String(format: "SD: %p dataTask: %ld downloadTask:", session))

    }
    
    @available(OSX 10.11, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        Swift.print(String(format: "SD: %p dataTask: %ld streamTask:", session))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Swift.print(String(format: "SD: %p dataTask: %ld didReceive data:", session))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        Swift.print(String(format: "SD: %p dataTask: %ld proposedResponse:", session, dataTask.taskIdentifier))
        
    }

    //  MARK: URLSessionDownloadDelegate
        
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Swift.print(String(format: "SU: %p downloadTask: %ld didFinishDownloadingTo:", session, downloadTask.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Swift.print(String(format: "session: %p downloadTask: %ld didWriteData bytesWritten:", session, downloadTask.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        Swift.print(String(format: "session: %p downloadTask: %ld didResumeAtOffset:", session, downloadTask.taskIdentifier))

    }

    //  MARK:- TabView Delegate
    
    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            Swift.print("tab willSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            Swift.print("tab didSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }

//  https://stackoverflow.com/a/56580009/564870

    func loadFileSync(_ sourceURL: URL, to targetURL: URL, completion: @escaping (String?, Error?) -> Void)
    {
        if FileManager().fileExists(atPath: targetURL.path)
        {
            print("File already exists [\(targetURL.path)]")
            completion(targetURL.path, nil)
        }
        else if let dataFromURL = NSData(contentsOf: sourceURL)
        {
            if dataFromURL.write(to: targetURL, atomically: true)
            {
                print("file saved [\(targetURL.path)]")
                completion(targetURL.path, nil)
            }
            else
            {
                print("error saving file")
                let error = NSError(domain:"Error saving file", code:1001, userInfo:nil)
                completion(targetURL.path, error)
            }
        }
        else
        {
            let error = NSError(domain:"Error downloading file", code:1002, userInfo:nil)
            completion(targetURL.path, error)
        }
    }

    func loadFileAsync(_ sourceURL: URL, to targetURL: URL, completion: @escaping (String?, Error?) -> Void)
    {
        if FileManager().fileExists(atPath: targetURL.path)
        {
            ///print("File already exists [\(targetURL.path)]")
            completion(targetURL.path, nil)
        }
        else
        {
            let session = URLSession(configuration: appDelegate.sessionConfiguration, delegate: nil, delegateQueue: nil)
            var request = URLRequest(url: sourceURL)
            request.httpMethod = "GET"
            let task = session.dataTask(with: request, completionHandler:
            {
                data, response, error in
                if error == nil
                {
                    if let response = response as? HTTPURLResponse
                    {
                        if response.statusCode == 200
                        {
                            if let data = data
                            {
                                if let _ = try? data.write(to: targetURL, options: Data.WritingOptions.atomic)
                                {
                                    completion(targetURL.path, error)
                                }
                                else
                                {
                                    completion(targetURL.path, error)
                                }
                            }
                            else
                            {
                                completion(targetURL.path, error)
                            }
                        }
                    }
                }
                else
                {
                    completion(targetURL.path, error)
                }
            })
            task.resume()
        }
    }
}

class ReleaseViewController : WebViewController {

}
