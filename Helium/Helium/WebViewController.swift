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
    internal func menuClicked(_ sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            Swift.print("Menu \(menuItem.title) clicked")
        }
    }

    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        publishApplicationMenu(menu);
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            //  We crash otherwise, so just close window
            self.window?.performClose(event)
        }
        else
        {
            // still here?
            super.keyDown(with: event)
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let doc = self.window?.windowController?.document as! Document
        let pboard = sender.draggingPasteboard()
        let items = pboard.pasteboardItems
        
        if (pboard.types?.contains(NSURLPboardType))! {
            for item in items! {
                if let urlString = item.string(forType: kUTTypeURL as String) {
                    self.load(URLRequest(url: URL(string: urlString)!))
                }
                else
                if let urlString = item.string(forType: kUTTypeFileURL as String/*"public.file-url"*/) {
                    guard var itemURL = URL.init(string: urlString), itemURL.isFileURL, appDelegate.isSandboxed() else {
                        self.load(URLRequest(url: URL(string: urlString)!))
                        return true
                    }
                    //  Resolve alias before storing bookmark
                    if let origURL = (itemURL as NSURL).resolvedFinderAlias() {
                        itemURL = origURL
                    }

                    if appDelegate.storeBookmark(url: itemURL as URL) {
                        // MARK:- only initial url loads; subsequent ignored.
                        // The app historically has the ability to drop new assets, links
                        // etc to supersede what went before but this functionality
                        // is lost in a sandbox enviornment.
                        if doc.fileURL == nil {
                            self.loadFileURL(itemURL, allowingReadAccessTo: itemURL)
                            doc.update(to: itemURL, ofType: itemURL.pathExtension)
                            return true
                        }
                        else
                        {
                            do {
                                let next = try NSDocumentController.shared().openUntitledDocumentAndDisplay(true) as! Document
                                let oldWindow = doc.windowControllers.first?.window
                                let newWindow = next.windowControllers.first?.window
                                (newWindow?.contentView?.subviews.first as! MyWebView).loadFileURL(itemURL, allowingReadAccessTo: itemURL)
                                newWindow?.offsetFromWindow(oldWindow!)
                                next.update(to: itemURL, ofType: itemURL.pathExtension)
                                return true
                            }
                            catch let error
                            {
                                NSApp.presentError(error)
                                Swift.print("Yoink, unable to create new doc for (\(itemURL))")
                                return false
                            }
                        }
                    }
                    Swift.print("Yoink, storeBookmark(\(itemURL)) failed?")
                    return false
                }
                else
                {
                    Swift.print("items has \(item.types)")
                    return false
                }
            }
        }
        else
        if (pboard.types?.contains(NSPasteboardURLReadingFileURLsOnlyKey))! {
            Swift.print("we have NSPasteboardURLReadingFileURLsOnlyKey")
            //          NSApp.delegate?.application!(NSApp, openFiles: items! as [String])
        }
        return true
    }
    
    //    Either by contextual menu, or status item, populate our app menu
    func publishApplicationMenu(_ menu: NSMenu) {
        let hwc = self.window?.windowController as! HeliumPanelController
        let dc = NSDocumentController.shared()
        let doc = hwc.document as! Document
        let translucency = doc.settings.translucencyPreference.value
        
        var item: NSMenuItem

        item = NSMenuItem(title: "Open", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subOpen = NSMenu()
        item.submenu = subOpen

        item = NSMenuItem(title: "File", action: #selector(HeliumPanelController.openFilePress(_:)), keyEquivalent: "")
        item.target = hwc
        subOpen.addItem(item)

        item = NSMenuItem(title: "Location", action: #selector(HeliumPanelController.openLocationPress(_:)), keyEquivalent: "")
        item.target = hwc
        subOpen.addItem(item)

        item = NSMenuItem(title: "Window", action: #selector(dc.newDocument(_:)), keyEquivalent: "")
        item.target = dc.currentDocument
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Playlists", action: #selector(WebViewController.presentPlaylistSheet(_:)), keyEquivalent: "")
        item.target = self.uiDelegate
        menu.addItem(item)

        item = NSMenuItem(title: "Preferences", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subPref = NSMenu()
        item.submenu = subPref

        item = NSMenuItem(title: "Auto-hide Title Bar", action: #selector(hwc.autoHideTitlePress(_:)), keyEquivalent: "")
        item.state = doc.settings.autoHideTitle.value ? NSOnState : NSOffState
        item.target = hwc
        subPref.addItem(item)

        item = NSMenuItem(title: "Float Above All Spaces", action: #selector(hwc.floatOverFullScreenAppsPress(_:)), keyEquivalent: "")
        item.state = (doc.settings.disabledFullScreenFloat.value == true) ? NSOffState : NSOnState
        item.target = hwc
        subPref.addItem(item)
        
        item = NSMenuItem(title: "Home Page", action: #selector(AppDelegate.homePagePress(_:)), keyEquivalent: "")
        item.target = appDelegate
        subPref.addItem(item)

        item = NSMenuItem(title: "Magic URL Redirects", action: #selector(AppDelegate.magicURLRedirectPress(_:)), keyEquivalent: "")
        item.state = (UserSettings.disabledMagicURLs.value == true) ? NSOffState : NSOnState
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

        item = NSMenuItem(title: "Close", action: #selector(NSApp.keyWindow?.performClose(_:)), keyEquivalent: "")
        item.target = NSApp.keyWindow
        menu.addItem(item)

        item = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "")
        item.target = NSApp
        menu.addItem(item)
    }
}

class WebViewController: NSViewController, WKNavigationDelegate {

    var trackingTag: NSTrackingRectTag?

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

        // Layout webview
        view.addSubview(webView)
        fit(webView, parentView: view)

        webView.frame = view.bounds
        webView.autoresizingMask = [NSAutoresizingMaskOptions.viewHeightSizable, NSAutoresizingMaskOptions.viewWidthSizable]
        
        // Allow plug-ins such as silverlight
        webView.configuration.preferences.plugInsEnabled = true
        
        // Custom user agent string for Netflix HTML5 support
        webView._customUserAgent = UserSettings.userAgent.value
        
        // Setup magic URLs
        webView.navigationDelegate = self
        
        // Allow zooming
        webView.allowsMagnification = true
        
        // Alow back and forth
        webView.allowsBackForwardNavigationGestures = true
        
        // Listen for load progress
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: NSKeyValueObservingOptions.new, context: nil)

        //  Intercept Finder drags
        webView.register(forDraggedTypes: [NSURLPboardType])

        clear()
    }
    
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    
    func updateTrackingAreas() {
        if let tag = trackingTag {
            view.removeTrackingRect(tag)
        }
        
        trackingTag = view.addTrackingRect(view.bounds, owner: self, userData: nil, assumeInside: false)
    }
    override func viewDidLayout() {
        super.viewDidLayout()

        // Deferred window setup needing a document' settings
        if let hwc = self.view.window?.windowController {
            (hwc as! HeliumPanelController).documentViewDidLoad()
        }
        
        if videoFileReferencedURL {
            let newSize = webView.bounds.size
            let aspect = webSize.height / webSize.width
            let magnify = newSize.width / webSize.width
            let newHeight = newSize.width * aspect
            let adjSize = NSMakeSize(newSize.width-1,newHeight-1)
            webView.setMagnification((magnify > 1 ? magnify : 1), centeredAt: NSMakePoint(adjSize.width/2.0, adjSize.height/2.0))
            view.setBoundsSize(adjSize)
        }
        updateTrackingAreas()
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
        if !videoFileReferencedURL {
            webView.magnification += 0.1
        }
     }
    
    fileprivate func zoomOut() {
        if !videoFileReferencedURL {
            webView.magnification -= 0.1
        }
    }
    
    fileprivate func resetZoom() {
        if !videoFileReferencedURL {
            webView.magnification = 1
        }
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
    
    //  MARK: Playlists
    lazy var playlistViewController: PlaylistViewController = {
        return self.storyboard!.instantiateController(withIdentifier: "PlaylistViewController")
            as! PlaylistViewController
    }()
    
    @IBAction func presentPlaylistSheet(_ sender: AnyObject) {
        let pvc = self.playlistViewController
        pvc.webViewController = self
        self.presentViewControllerAsSheet(pvc)
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
        var loadURL: URL = url
        if appDelegate.isSandboxed() && loadURL.isFileURL {
            //  Resolve alias before storing bookmark
            if let origURL = (loadURL as NSURL).resolvedFinderAlias() {
                loadURL = origURL
            }

            //  Store and fetch our url security scope url
            _ = appDelegate.storeBookmark(url: loadURL)
        }
        if loadURL.isFileURL {
            webView.loadFileURL(loadURL, allowingReadAccessTo: loadURL)
        }
        else
        {
            webView.load(URLRequest(url: loadURL))
        }
    }

    internal func loadURL(urlFileURL: Notification) {
        if let fileURL = urlFileURL.object, let info = urlFileURL.userInfo {
            if info["hwc"] as? NSWindowController == self.view.window?.windowController {
                webView.load(URLRequest(url: fileURL as! URL))
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
    
    // MARK: Webview functions
    func clear() {
        // Reload to home page (or default if no URL stored in UserDefaults)
        loadURL(text: UserSettings.homePageURL.value)
    }

    var webView = MyWebView()
    var webSize = CGSize(width: 0,height: 0)
    var shouldRedirect: Bool {
        get {
            return !UserSettings.disabledMagicURLs.value
        }
    }
    
    // Redirect Hulu and YouTube to pop-out videos
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if (navigationAction.request.url?.absoluteString.hasPrefix("file://"))! {
            decisionHandler(WKNavigationActionPolicy.allow)
            return
        }
        
        guard !UserSettings.disabledMagicURLs.value,
            let url = navigationAction.request.url else {
                decisionHandler(WKNavigationActionPolicy.allow)
                return
        }

        if let newUrl = UrlHelpers.doMagic(url) {
            decisionHandler(WKNavigationActionPolicy.cancel)
            loadURL(url: newUrl)
        } else {
            decisionHandler(WKNavigationActionPolicy.allow)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        if let pageTitle = webView.title {
            if let hwc = self.view.window?.windowController {
                let doc = hwc.document as! Document
                var title = pageTitle;
                if title.isEmpty { title = doc.displayName }
                let notif = Notification(name: Notification.Name(rawValue: "HeliumNextTitle"),
                                         object: title, userInfo: ["hwc":hwc]);
                NotificationCenter.default.post(notif)
                Swift.print("webView:didFinish: \(title)")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinishLoad navigation: WKNavigation) {
        Swift.print("webView:didFinishLoad:")
    }
    
    var videoFileReferencedURL = false
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "estimatedProgress",
            let view = object as? WKWebView, view == webView {

            if let progress = change?[NSKeyValueChangeKey(rawValue: "new")] as? Float {
                let percent = progress * 100
                var title = NSString(format: "Loading... %.2f%%", percent)
                if percent == 100, let url = (self.webView.url) {
                    videoFileReferencedURL = false

                    if (url.isFileURL) {
                        if let original = (url as NSURL).resolvedFinderAlias() {
                            self.loadURL(url: original)
                            return
                        }
                    }

                    let notif = Notification(name: Notification.Name(rawValue: "HeliumNewURL"), object: url);
                    NotificationCenter.default.post(notif)

                    // once loaded update window title,size with video name,dimension
                    if let urlTitle = (self.webView.url?.absoluteString) {
                        title = urlTitle as NSString

                        if let track = AVURLAsset(url: url, options: nil).tracks.first {

                            //    if it's a video file, get and set window content size to its dimentions
                            if track.mediaType == AVMediaTypeVideo {
                                let oldSize = webView.window?.contentView?.bounds.size
                                title = url.lastPathComponent as NSString
                                webSize = track.naturalSize
                                if oldSize != webSize, var origin = self.webView.window?.frame.origin {
                                    origin.y += ((oldSize?.height)! - webSize.height)
                                    webView.window?.setContentSize(webSize)
                                    webView.window?.setFrameOrigin(origin)
                                    webView.bounds.size = webSize
                                }
                                videoFileReferencedURL = true
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
                        self.view.window?.representedURL = url
                        (doc as! Document).update(to: url, ofType: url.pathExtension)
                        (hwc as! HeliumPanelController).updateTitleBar(didChange: false)
                        NSApp.addWindowsItem(self.view.window!, title: (doc as! Document).displayName, filename: false)
                    }
                 }
            }
        }
    }
    
    fileprivate func restoreSettings(_ title: String) {
        if let playitems = UserDefaults.standard.dictionary(forKey: UserSettings.Playitems.default) {
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
}
