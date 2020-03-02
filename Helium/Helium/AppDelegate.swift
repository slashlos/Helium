//
//  AppDelegate.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017-2020 Carlos D. Santiago. All rights reserved.
//
//  We have user IBAction centrally here, share by panel and webView controllers
//  The design is to centrally house the preferences and notify these interested
//  parties via notification.  In this way all menu state can be consistency for
//  statusItem, main menu, and webView contextual menu.
//
import Cocoa
import CoreLocation

struct RequestUserStrings {
    let currentURL: String?
    let alertMessageText: String
    let alertButton1stText: String
    let alertButton1stInfo: String?
    let alertButton2ndText: String
    let alertButton2ndInfo: String?
    let alertButton3rdText: String?
    let alertButton3rdInfo: String?
}

fileprivate class SearchField : NSSearchField {
    var title : String?
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let textEditor = currentEditor() {
            textEditor.selectAll(self)
        }
    }
    
    convenience init(withValue: String?, modalTitle: String?) {
        self.init()
        
        if let string = withValue {
            self.stringValue = string
        }
        if let title = modalTitle {
            self.title = title
        }
        else
        {
            self.title = (NSApp.delegate as! AppDelegate).title
        }
        if let cell : NSSearchFieldCell = self.cell as? NSSearchFieldCell {
            cell.searchMenuTemplate = searchMenu()
            cell.usesSingleLineMode = false
            cell.wraps = true
            cell.lineBreakMode = .byWordWrapping
            cell.formatter = nil
            cell.allowsEditingTextAttributes = false
        }
        (self.cell as! NSSearchFieldCell).searchMenuTemplate = searchMenu()
    }
    
    fileprivate func searchMenu() -> NSMenu {
        let menu = NSMenu.init(title: "Search Menu")
        var item : NSMenuItem
        
        item = NSMenuItem.init(title: "Clear", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.clearRecentsMenuItemTag
        menu.addItem(item)
        
        item = NSMenuItem.separator()
        item.tag = NSSearchField.recentsTitleMenuItemTag
        menu.addItem(item)
        
        item = NSMenuItem.init(title: "Recent Searches", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.recentsTitleMenuItemTag
        menu.addItem(item)
        
        item = NSMenuItem.init(title: "Recent", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.recentsTitleMenuItemTag
        menu.addItem(item)
        
        item = NSMenuItem.init(title: "Recent Searches", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.recentsMenuItemTag
        menu.addItem(item)
        
        return menu
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let title = self.title {
            self.window?.title = title
        }
        
        // MARK: this gets us focus even when modal
        self.becomeFirstResponder()
    }
}

fileprivate class URLField: NSTextField {
    var title : String?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let textEditor = currentEditor() {
            textEditor.selectAll(self)
        }
    }
    
    convenience init(withValue: String?, modalTitle: String?) {
        self.init()
        
        if let string = withValue {
            self.stringValue = string
        }
        if let title = modalTitle {
            self.title = title
        }
        else
        {
            let infoDictionary = (Bundle.main.infoDictionary)!
            
            //    Get the app name field
            let appName = infoDictionary[kCFBundleExecutableKey as String] as? String ?? k.Helium
            
            //    Setup the version to one we constrict
            self.title = String(format:"%@ %@", appName,
                               infoDictionary["CFBundleVersion"] as! CVarArg)
        }
        self.lineBreakMode = .byTruncatingHead
        self.usesSingleLineMode = true
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let title = self.title {
            self.window?.title = title
        }

        // MARK: this gets us focus even when modal
        self.becomeFirstResponder()
    }
}

struct ViewOptions : OptionSet {
    let rawValue: Int
    
    static let w_view            = ViewOptions(rawValue: 1 << 0)
    static let t_view            = ViewOptions(rawValue: 1 << 1)
}
let sameWindow : ViewOptions = []

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, CLLocationManagerDelegate {

    //  who we are from 'about'
    var appName: String {
        get {
            let infoDictionary = (Bundle.main.infoDictionary)!
            
            //    Get the app name field
            let appName = infoDictionary[kCFBundleExecutableKey as String] as? String ?? k.Helium
            
            return appName
        }
    }

    func getDesktopDirectory() -> URL {
        let homedir = FileManager.default.homeDirectoryForCurrentUser
        let desktop = homedir.appendingPathComponent(k.desktop, isDirectory: true)
        return desktop
    }
    
    //  return key state for external paths
    var newViewOptions : ViewOptions = sameWindow
    var getViewOptions : ViewOptions {
        get {
            var viewOptions = ViewOptions()
            if shiftKeyDown { viewOptions.insert(.w_view) }
            if optionKeyDown { viewOptions.insert(.t_view) }
            return viewOptions
        }
    }
    //  For those site that require your location while we're active
    var locationManager : CLLocationManager?
    var isLocationEnabled : Bool {
        get {
            guard CLLocationManager.locationServicesEnabled() else { return false }
            return [.authorizedAlways, .authorized].contains(CLLocationManager.authorizationStatus())
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            Swift.print("location notDetermined")
            
        case .restricted:
            Swift.print("location restricted")
            
        case .denied:
            Swift.print("location denied")
            
        case .authorizedWhenInUse:
            print("location authorizedWhenInUse")
            
        case .authorizedAlways:
            print("location authorizedWhenInUse")
            
        default:
            fatalError()
        }
    }

    var docController : HeliumDocumentController {
        get {
            return NSDocumentController.shared as! HeliumDocumentController
        }
    }
    
    var os = ProcessInfo().operatingSystemVersion
    @objc @IBOutlet weak var magicURLMenu: NSMenuItem!

    //  MARK:- Global IBAction, but ship to keyWindow when able
    @objc @IBOutlet weak var appMenu: NSMenu!
	var appStatusItem:NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    fileprivate var searchField : SearchField = SearchField.init(withValue: k.Helium, modalTitle: "Search")

    @objc dynamic var _webSearches : [PlayItem]?
    @objc dynamic var  webSearches : [PlayItem] {
        get {
            if  _webSearches == nil {
                _webSearches = [PlayItem]()
                
                // Restore search name change
                if let searchesName = self.defaults.string(forKey: UserSettings.SearchNames.keyPath), searchesName != UserSettings.SearchNames.value {
                    UserSettings.SearchNames.value = searchesName
                }
                
                if let items = self.defaults.array(forKey: UserSettings.SearchNames.keyPath) {
                    
                    // Load histories from defaults up to their maximum
                    for playitem in items {
                        if let name : String = playitem as? String, let dict = defaults.dictionary(forKey: name) {
                            self._webSearches?.append(PlayItem.init(with: dict))
                        }
                        else
                        if let dict : Dictionary <String,AnyObject> = playitem as? Dictionary <String,AnyObject> {
                            self._webSearches?.append(PlayItem.init(with: dict))
                        }
                        else
                        {
                            Swift.print("unknown search \(playitem)")
                        }
                    }
                    Swift.print("searches \(self._webSearches!.count) restored")
                }
            }
            return _webSearches!
        }
        set (array) {
            _webSearches = array
        }
    }
    
    var recentSearches : Array<String> {
        get {
            var searches = Array<String>()
            for search in webSearches {
                searches.append(search.name)
            }
            return searches
        }
    }
    
    var title : String {
        get {
            let infoDictionary = (Bundle.main.infoDictionary)!
            
            //    Setup the version to one we constrict
            let title = String(format:"%@ %@", appName,
                               infoDictionary["CFBundleVersion"] as! CVarArg)

            return title
        }
    }
    @objc internal func menuClicked(_ sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            Swift.print("Menu '\(menuItem.title)' clicked")
        }
    }
    internal func syncAppMenuVisibility() {
        if UserSettings.HideAppMenu.value {
            NSStatusBar.system.removeStatusItem(appStatusItem)
        }
        else
        {
            appStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            appStatusItem.image = NSImage.init(named: "statusIcon")
            let menu : NSMenu = appMenu.copy() as! NSMenu

            //  add quit to status menu only - already is in dock
            let item = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "")
            item.target = NSApp
            menu.addItem(item)

            appStatusItem.menu = menu
        }
    }
	@objc @IBAction func hideAppStatusItem(_ sender: NSMenuItem) {
		UserSettings.HideAppMenu.value = (sender.state == .off)
        self.syncAppMenuVisibility()
	}
    @objc @IBAction func homePagePress(_ sender: AnyObject) {
        didRequestUserUrl(RequestUserStrings (
            currentURL: UserSettings.HomePageURL.value,
            alertMessageText:   "New home page",
            alertButton1stText: "Set",      alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Default",  alertButton3rdInfo: UserSettings.HomePageURL.default),
                          onWindow: NSApp.keyWindow as? HeliumPanel,
                          title: "Enter URL",
                          acceptHandler: { (newUrl: String) in
                            UserSettings.HomePageURL.value = newUrl
        }
        )
    }

    //  Restore operations are progress until open
    @objc dynamic var openForBusiness = false
    
    //  By defaut we show document title bar
    @objc @IBAction func autoHideTitlePress(_ sender: NSMenuItem) {
        UserSettings.AutoHideTitle.value = (sender.state == .off)
     }

    //  By default we auto save any document changes
    @objc @IBOutlet weak var autoSaveDocsMenuItem: NSMenuItem!
    @objc @IBAction func autoSaveDocsPress(_ sender: NSMenuItem) {
        autoSaveDocs = (sender.state == .off)
	}
	var autoSaveDocs : Bool {
        get {
            return UserSettings.AutoSaveDocs.value
        }
        set (value) {
            UserSettings.AutoSaveDocs.value = value
            if value {
                for doc in docController.documents {
                    DispatchQueue.main.async {
                        doc.save(self.autoSaveDocsMenuItem)
                    }
                 }
                docController.saveAllDocuments(autoSaveDocsMenuItem)
            }
        }
    }
    
	@IBAction func clearHistoryPress(_ sender: Any) {
        
        let message = "Confirm clearing URL and search history"
        let infoMsg = String(format: "%ld history(s), %ld search(es)", _histories?.count ?? 0,
                             recentSearches.count)
        
        sheetOKCancel(message, info: infoMsg,
                                acceptHandler: { (button) in

                                    //  Make them confirm first, then clear lazily
                                    if button == NSApplication.ModalResponse.alertFirstButtonReturn {
                                        self._histories = [PlayItem]()
                                        let forget = Array<Any>()
                                        self.defaults.set(forget, forKey: UserSettings.HistoryList.keyPath)
                                        let forgot = Array<PlayItem>()
                                        self.defaults.set(forgot, forKey: UserSettings.SearchNames.keyPath)
                                    }
        })
	}
	
	@IBAction func keepHistoryPress(_ sender: NSMenuItem) {
        UserSettings.HistorySaves.value = (sender.state == .off)
	}
	
	@objc @IBAction func developerExtrasEnabledPress(_ sender: NSMenuItem) {
        UserSettings.DeveloperExtrasEnabled.value = (sender.state == .off)
    }
    
    var fullScreen : NSRect? = nil
    @objc @IBAction func toggleFullScreen(_ sender: NSMenuItem) {
        if let keyWindow : HeliumPanel = NSApp.keyWindow as? HeliumPanel {
            keyWindow.heliumPanelController.floatOverFullScreenAppsPress(sender)
        }
    }

    @objc @IBAction func magicURLRedirectPress(_ sender: NSMenuItem) {
        UserSettings.DisabledMagicURLs.value = (sender.state == .on)
    }
    
	func doOpenFile(fileURL: URL, fromWindow: NSWindow? = nil) -> Bool {
        if isSandboxed() != storeBookmark(url: fileURL) {
            Swift.print("Yoink, unable to sandbox \(fileURL)")
            return false
        }
        
        if let thisWindow = fromWindow != nil ? fromWindow : NSApp.keyWindow {
            guard openForBusiness || (thisWindow.contentViewController?.isKind(of: PlaylistViewController.self))! else {
                if let wvc = thisWindow.contentViewController as? WebViewController {
                    return wvc.webView.next(url: fileURL)
                }
                else
                {
                    return false
                }
            }
        }
        
        //  This could be anything so add/if a doc and initialize
        do {
            let typeName = fileURL.isFileURL && fileURL.pathExtension == k.hpl ? k.Playlist : k.Helium
            let doc = try docController.makeDocument(withContentsOf: fileURL, ofType: typeName)
            docController.noteNewRecentDocumentURL(fileURL)
            doc.showWindows()
            return true
        } catch let error {
            print("*** Error open file: \(error.localizedDescription)")
            return false
        }
    }
    
    @objc @IBAction func locationServicesPress(_ sender: NSMenuItem) {
        if isLocationEnabled {
            locationManager?.stopMonitoringSignificantLocationChanges()
            locationManager?.stopUpdatingLocation()
            locationManager = nil
        }
        else
        {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.startUpdatingLocation()
        }
        //  Lazily store preference setting to what it is now
        UserSettings.RestoreLocationSvcs.value = isLocationEnabled
    }
    
    @objc @IBAction func openFilePress(_ sender: AnyObject) {
        var viewOptions = ViewOptions(rawValue: sender.tag)
        
        let open = NSOpenPanel()
        open.allowsMultipleSelection = true
        open.canChooseDirectories = false
        open.resolvesAliases = true
        open.canChooseFiles = true
        
        //  No window, so load panel modally
        NSApp.activate(ignoringOtherApps: true)
        
        if open.runModal() == .OK {
            open.orderOut(sender)
            let urls = open.urls
            for url in urls {
                if viewOptions.contains(.t_view) {
                    _ = openFileInNewWindow(url, attachTo: sender.representedObject as? NSWindow)
                }
                else
                if viewOptions.contains(.w_view) {
                    _ = openFileInNewWindow(url)
                }
                else
                {
                    _ = self.doOpenFile(fileURL: url)
                }
            }
            //  Multiple files implies new windows
            viewOptions.insert(.w_view)
        }
        return
    }
    
    internal func openFileInNewWindow(_ url: URL, attachTo parentWindow: NSWindow? = nil) -> Bool {
        return openURLInNewWindow(url, attachTo: parentWindow)
    }
    
    func openURLInNewWindow(_ url: URL, attachTo parentWindow : NSWindow? = nil) -> Bool {
        if url.isFileURL, isSandboxed() != storeBookmark(url: url) {
            Swift.print("Yoink, unable to sandbox \(url)")
            return false
        }
        
        do {
            let typeName = url.pathExtension == k.hpl ? k.Playlist : k.Helium
            let doc = try docController.makeDocument(withContentsOf: url, ofType: typeName)
            
            guard let wc = doc.windowControllers.first else { return false }
            
            guard let window = wc.window else { return false }
            
            if let parent = parentWindow {
                parent.addTabbedWindow(window, ordered: .above)
            }
            doc.showWindows()
            return true
            
        } catch let error {
            NSApp.presentError(error)
        }
        return false
    }
        
    @objc @IBAction func openVideoInNewWindowPress(_ sender: NSMenuItem) {
        if let newURL = sender.representedObject {
            _ = self.openURLInNewWindow(newURL as! URL, attachTo: sender.representedObject as? NSWindow)
        }
    }
    
    @objc @IBAction func openLocationPress(_ sender: AnyObject) {
        let viewOptions = ViewOptions(rawValue: sender.tag)
        var urlString = UserSettings.HomePageURL.value
        
        //  No window, so load alert modally
        if let rawString = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string), rawString.isValidURL() {
            urlString = rawString
        }
        didRequestUserUrl(RequestUserStrings (
            currentURL:         urlString,
            alertMessageText:   "URL to load",
            alertButton1stText: "Load",     alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.HomePageURL.value),
                          onWindow: nil,
                          title: "Enter URL",
                          acceptHandler: { (urlString: String) in
                            guard let newURL = URL.init(string: urlString) else { return }
                            
                            if viewOptions.contains(.t_view), let parent = sender.representedObject {
                                _ = self.openURLInNewWindow(newURL, attachTo: parent as? NSWindow)
                            }
                            else
                            {
                                _ = self.openURLInNewWindow(newURL)
                            }
        })
    }

    @objc @IBAction func openSearchPress(_ sender: AnyObject) {
        let name = k.searchNames[ UserSettings.Search.value ]
        let info = k.searchInfos[ UserSettings.Search.value ]

        //  No window?, so load alert modally
            
        didRequestSearch(RequestUserStrings (
            currentURL: nil,
            alertMessageText:   "Search",
            alertButton1stText: name,         alertButton1stInfo: info,
            alertButton2ndText: "Cancel",     alertButton2ndInfo: nil,
            alertButton3rdText: nil,          alertButton3rdInfo: nil),
                         onWindow: nil,
                         title: "Web Search",
                         acceptHandler: { (newWindow,searchURL: URL) in
                            _ = self.openURLInNewWindow(searchURL, attachTo: sender.representedObject as? NSWindow)
        })
    }
    
    @objc @IBAction func pickSearchPress(_ sender: NSMenuItem) {
        //  This needs to match validateMenuItem below
		let group = sender.tag / 100
		let index = (sender.tag - (group * 100)) % 3
		let key = String(format: "search%d", group)

		defaults.set(index as Any, forKey: key)
//        Swift.print("\(key) -> \(index)")
	}
	
    @objc @IBAction func presentPlaylistSheet(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)

        //  If we have a window, present a sheet with playlists, otherwise ...
        guard let item: NSMenuItem = sender as? NSMenuItem, let window: NSWindow = item.representedObject as? NSWindow else {
            //  No contextual window, load panel and its playlist controller
            do {
                let doc = try docController.makeUntitledDocument(ofType: k.Playlist)
                if 0 == doc.windowControllers.count { doc.makeWindowControllers() }
                doc.showWindows()
            }
            catch let error {
                NSApp.presentError(error)
                Swift.print("Yoink, unable to load playlists")
            }
            return
        }
        
        if let wvc = window.windowController?.contentViewController {

            //  We're already here so exit
            if wvc.isKind(of: PlaylistViewController.self) { return }
            
            //  If a web view controller, fetch and present playlist here
            if let wvc: WebViewController = wvc as? WebViewController {
                if wvc.presentedViewControllers?.count == 0 {
                    let pvc = storyboard.instantiateController(withIdentifier: "PlaylistViewController") as! PlaylistViewController
                    pvc.playlists.append(contentsOf: playlists)
                    pvc.webViewController = wvc
                    wvc.presentAsSheet(pvc)
                }
                return
            }
            Swift.print("who are we? \(String(describing: window.contentViewController))")
        }
    }
	
    @objc @IBAction func promoteHTTPSPress(_ sender: NSMenuItem) {
        UserSettings.PromoteHTTPS.value = (sender.state == .on ? false : true)
	}
    
    @objc @IBAction func restoreDocAttrsPress(_ sender: NSMenuItem) {
        UserSettings.RestoreDocAttrs.value = (sender.state == .on ? false : true)
	}
	
    @objc @IBAction func restoreWebURLsPress(_ sender: NSMenuItem) {
        UserSettings.RestoreWebURLs.value = (sender.state == .on ? false : true)
    }
    
    @objc @IBAction func showReleaseInfo(_ sender: Any) {
        do
        {
            let url = URL.init(string: k.ReleaseURL)!
            let doc = try docController.makeDocument(withContentsOf: url, ofType: k.Helium)
            doc.showWindows()
        }
        catch let error {
            NSApp.presentError(error)
        }
	}
	
    @objc @IBAction func snapshotAll(_ sender: NSMenuItem) {
        let notif = Notification(name: Notification.Name(rawValue: "HeliumSnapshotAll"), object: sender)
        NotificationCenter.default.post(notif)
    }

	var canRedo : Bool {
        if let redo = NSApp.keyWindow?.undoManager  {
            return redo.canRedo
        }
        else
        {
            return false
        }
    }
    @objc @IBAction func redo(_ sender: Any) {
		if let window = NSApp.keyWindow, let undo = window.undoManager, undo.canRedo {
            Swift.print("redo:");
		}
	}
    
    var canUndo : Bool {
        if let undo = NSApp.keyWindow?.undoManager  {
            return undo.canUndo
        }
        else
        {
            return false
        }
    }

    @objc @IBAction func undo(_ sender: Any) {
        if let window = NSApp.keyWindow, let undo = window.undoManager, undo.canUndo {
            Swift.print("undo:");
        }
	}
    
    @objc @IBAction func userAgentPress(_ sender: AnyObject) {
        didRequestUserAgent(RequestUserStrings (
            currentURL: UserSettings.UserAgent.value,
            alertMessageText:   "Default user agent",
            alertButton1stText: "Set",      alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Default",  alertButton3rdInfo: UserSettings.UserAgent.default),
                          onWindow: NSApp.keyWindow as? HeliumPanel,
                          title: "Default User Agent",
                          acceptHandler: { (newUserAgent: String) in
                            UserSettings.UserAgent.value = newUserAgent
        }
        )
    }
    
    func modalOKCancel(_ message: String, info: String?) -> Bool {
        let alert: NSAlert = NSAlert()
        alert.messageText = message
        if info != nil {
            alert.informativeText = info!
        }
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:
            return true
        default:
            return false
        }
    }

    func sheetOKCancel(_ message: String, info: String?,
                       acceptHandler: @escaping (NSApplication.ModalResponse) -> Void) {
        let alert = NSAlert()
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if info != nil {
            alert.informativeText = info!
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: { response in
                acceptHandler(response)
            })
        }
        else
        {
            acceptHandler(alert.runModal())
        }
        alert.buttons.first!.becomeFirstResponder()
    }
    
    func userAlertMessage(_ message: String, info: String?) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        if info != nil {
            alert.informativeText = info!
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: { response in
                return
            })
        }
        else
        {
            alert.runModal()
            return
        }
    }
    
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.title.hasPrefix("Redo") {
            menuItem.isEnabled = self.canRedo
        }
        else
        if menuItem.title.hasPrefix("Undo") {
            menuItem.isEnabled = self.canUndo
        }
        else
        {
            switch menuItem.title {
            case k.bingName, k.googleName, k.yahooName:
                let group = menuItem.tag / 100
                let index = (menuItem.tag - (group * 100)) % 3
                
                menuItem.state = UserSettings.Search.value == index ? .on : .off
                break

            case "Preferences":
                break
            case "Auto-hide Title Bar":
                menuItem.state = UserSettings.AutoHideTitle.value ? .on : .off
                break
            case "Auto save documents":
                menuItem.state = UserSettings.AutoSaveDocs.value ? .on : .off
             case "Developer Extras":
                guard let type = NSApp.keyWindow?.className, type == "WKInspectorWindow" else {
                    guard let wc = NSApp.keyWindow?.windowController,
                        let hpc : HeliumPanelController = wc as? HeliumPanelController,
                        let state = hpc.webView?.configuration.preferences.value(forKey: "developerExtrasEnabled") else {
                            menuItem.state = UserSettings.DeveloperExtrasEnabled.value ? .on : .off
                            break
                    }
                    menuItem.state = (state as! NSNumber).boolValue ? .on : .off
                    break
                }
                menuItem.state = .on
            case "Hide Helium in menu bar":
                menuItem.state = UserSettings.HideAppMenu.value ? .on : .off
            case "Keep history record":
                menuItem.state = UserSettings.HistorySaves.value ? .on : .off
            case "Home Page":
                break
            case "Location services":
                menuItem.state = isLocationEnabled ? .on : .off
           case "Magic URL Redirects":
                menuItem.state = UserSettings.DisabledMagicURLs.value ? .off : .on
            case "Upgrade HTTP -> HTTPS Links":
                menuItem.state = UserSettings.PromoteHTTPS.value ? .on : .off
            case "Restore Doc Attributes":
                menuItem.state = UserSettings.RestoreDocAttrs.value ? .on : .off
            case "Restore Web URLs":
                menuItem.state = UserSettings.RestoreWebURLs.value ? .on : .off
            case "User Agent":
                break
            case "Quit":
                break

            default:
                break
            }
        }
        return true;
    }

    //  MARK:- Lifecyle
    @objc dynamic var documentsToRestore = false
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        //  Now we're open for business
        self.openForBusiness = true

        //  If we will restore then skip initial Untitled
        return !documentsToRestore && !disableDocumentReOpening
    }
    
    func resetDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        //  Clear any snapshots URL sandbox resources
        if nil != desktopData {
            let desktop = URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value)
            desktop.stopAccessingSecurityScopedResource()
            bookmarks[desktop] = nil
            desktopData = nil
            UserSettings.SnapshotsURL.value = UserSettings.SnapshotsURL.default
        }
    }
    
    let toHMS = hmsTransformer()
    let rectToString = rectTransformer()
    var launchedAsLogInItem : Bool = false
    
    var desktopData: Data?
    let rwOptions:URL.BookmarkCreationOptions = [.withSecurityScope]

    func applicationWillFinishLaunching(_ notification: Notification) {
        //  We need our own to reopen our "document" urls
        _ = HeliumDocumentController.init()
        
        let flags : NSEvent.ModifierFlags = NSEvent.ModifierFlags(rawValue: NSEvent.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue)
        let event = NSAppleEventDescriptor.currentProcess()

        //  We want automatic tab support
        NSPanel.allowsAutomaticWindowTabbing = true
        
        //  Wipe out defaults when OPTION+SHIFT is held down at startup
        if flags.contains([NSEvent.ModifierFlags.shift,NSEvent.ModifierFlags.option]) {
            Swift.print("shift+option at start")
            resetDefaults()
            NSSound(named: "Purr")?.play()
        }
        
        //  Don't reopen docs when OPTION is held down at startup
        if flags.contains(NSEvent.ModifierFlags.option) {
            Swift.print("option at start")
            disableDocumentReOpening = true
        }
        
        //  We were started as a login item startup save this
        launchedAsLogInItem = event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(AppDelegate.handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        //  So they can interact everywhere with us without focus
        appStatusItem.image = NSImage.init(named: "statusIcon")
        appStatusItem.menu = appMenu

        //  Initialize our h:m:s transformer
        ValueTransformer.setValueTransformer(toHMS, forName: NSValueTransformerName(rawValue: "hmsTransformer"))
        
        //  Initialize our rect [point,size] transformer
        ValueTransformer.setValueTransformer(rectToString, forName: NSValueTransformerName(rawValue: "rectTransformer"))

        //  Maintain a history of titles
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(AppDelegate.haveNewTitle(_:)),
            name: NSNotification.Name(rawValue: "HeliumNewURL"),
            object: nil)

        //  Load sandbox bookmark url when necessary
        if self.isSandboxed() {
            if !self.loadBookmarks() {
                Swift.print("Yoink, unable to load bookmarks")
            }
            else
            {
                //  1st time gain access to the ~/Deskop
                let url = URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value, isDirectory: true)
                if let data = bookmarks[url], fetchBookmark((key: url, value: data)) {
                    Swift.print ("snapshotURL \(url.absoluteString)")
                    desktopData = data
                }
            }
        }
        
        //  For site that require location services
        if UserSettings.RestoreLocationSvcs.value {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
        }
    }

    var itemActions = Dictionary<String, Any>()

    //  Keep playlist names unique by Array entension checking name
    @objc dynamic var _playlists : [PlayList]?
    @objc dynamic var  playlists : [PlayList] {
        get {
            if  _playlists == nil {
                _playlists = restorePlaylists()
            }
            return _playlists!
        }
        set (array) {
            _playlists = array
        }
    }
    
    func restorePlaylists() -> [PlayList] {
        var playlists = [PlayList]()
            
        //  read back playlists as [Dictionary] or [String] keys to each [PlayItem]
        if let plists = self.defaults.dictionary(forKey: k.playlists) {
            for (name,plist) in plists {
                guard let items = plist as? [Dictionary<String,Any>] else {
                    let playlist = PlayList.init(name: name, list: [PlayItem]())
                    playlists.append(playlist)
                    continue
                }
                var list : [PlayItem] = [PlayItem]()
                for plist in items {
                    let item = PlayItem.init(with: plist)
                    list.append(item)
                }
                let playlist = PlayList.init(name: name, list: list)
                playlists.append(playlist)
            }
        }
        else
        if let plists = self.defaults.array(forKey: k.playlists) as? [String] {
            for name in plists {
                guard let plist = self.defaults.dictionary(forKey: name) else {
                    let playlist = PlayList.init(name: name, list: [PlayItem]())
                    playlists.append(playlist)
                    continue
                }
                let playlist = PlayList.init(with: plist, createMissingItems: true)
                playlists.append(playlist)
            }
        }
        else
        {
            self.defaults.set([Dictionary<String,Any>](), forKey: k.playlists)
        }
        return playlists
    }
    
    @objc @IBAction func savePlaylists(_ sender: Any) {
        var plists = [Dictionary<String,Any>]()
        
        for plist in playlists {
            plists.append(plist.dictionary())
        }
        
        self.defaults.set(plists, forKey: k.playlists)
    }
    
    //  Histories restore deferred until requested
    @objc dynamic var _histories : [PlayItem]?
    @objc dynamic var  histories : [PlayItem] {
        get {
            if  _histories == nil {
                _histories = [PlayItem]()
                
                // Restore history name change
                if let historyName = self.defaults.string(forKey: UserSettings.HistoryName.keyPath), historyName != UserSettings.HistoryName.value {
                    UserSettings.HistoryName.value = historyName    
                }
                
                if let items = self.defaults.array(forKey: UserSettings.HistoryList.keyPath) {
                    let keep = UserSettings.HistoryKeep.value
                    
                    // Load histories from defaults up to their maximum
                    for playitem in items.suffix(keep) {
                        if let name : String = playitem as? String, let dict = defaults.dictionary(forKey: name) {
                            self._histories?.append(PlayItem.init(with: dict))
                        }
                        else
                        if let dict : Dictionary <String,AnyObject> = playitem as? Dictionary <String,AnyObject> {
                            self._histories?.append(PlayItem.init(with: dict))
                        }
                        else
                        {
                            Swift.print("unknown history \(playitem)")
                        }
                    }
                    Swift.print("histories \(self._histories!.count) restored")
                }
            }
            return _histories!
        }
        set (array) {
            _histories = array
        }
    }
    var defaults = UserDefaults.standard
    var hiddenWindows = Dictionary<String, Any>()

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let docCount = docController.documents.count
        return docCount > 0
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let reopenMessage = disableDocumentReOpening ? "do not reopen doc(s)" : "reopen doc(s)"
        let hasVisibleDocs = flag ? "has doc(s)" : "no doc(s)"
        Swift.print("applicationShouldHandleReopen: \(reopenMessage) docs:\(hasVisibleDocs)")
        if !flag && 0 == docController.documents.count { return !applicationOpenUntitledFile(sender) }
        return !disableDocumentReOpening || flag
    }

    //  Local/global event monitor: CTRL+OPTION+COMMAND to toggle windows' alpha / audio values
    //  https://stackoverflow.com/questions/41927843/global-modifier-key-press-detection-in-swift/41929189#41929189
    var localKeyDownMonitor : Any? = nil
    var globalKeyDownMonitor : Any? = nil
    var shiftKeyDown : Bool = false {
        didSet {
            let notif = Notification(name: Notification.Name(rawValue: "shiftKeyDown"),
                                     object: NSNumber(booleanLiteral: shiftKeyDown));
            NotificationCenter.default.post(notif)
        }
    }
    var optionKeyDown : Bool = false {
        didSet {
            let notif = Notification(name: Notification.Name(rawValue: "optionKeyDown"),
                                     object: NSNumber(booleanLiteral: optionKeyDown));
            NotificationCenter.default.post(notif)
        }
    }
    var commandKeyDown : Bool = false {
        didSet {
            let notif = Notification(name: Notification.Name(rawValue: "commandKeyDown"),
                                     object: NSNumber(booleanLiteral: commandKeyDown))
            NotificationCenter.default.post(notif)
        }
    }

    func keyDownMonitor(event: NSEvent) -> Bool {
        switch event.modifierFlags.intersection(NSEvent.ModifierFlags.deviceIndependentFlagsMask) {
        case [NSEvent.ModifierFlags.control, NSEvent.ModifierFlags.option, NSEvent.ModifierFlags.command]:
            print("control-option-command keys are pressed")
            if self.hiddenWindows.count > 0 {
//                Swift.print("show all windows")
                for frame in self.hiddenWindows.keys {
                    let dict = self.hiddenWindows[frame] as! Dictionary<String,Any>
                    let alpha = dict["alpha"]
                    let win = dict["window"] as! NSWindow
//                    Swift.print("show \(frame) to \(String(describing: alpha))")
                    win.alphaValue = alpha as! CGFloat
                    if let path = dict["name"], let actions = itemActions[path as! String]
                    {
                        if let action = (actions as! Dictionary<String,Any>)["mute"] {
                            let item = (action as! Dictionary<String,Any>)["item"] as! NSMenuItem
                            Swift.print("action \(item)")
                        }
                        if let action = (actions as! Dictionary<String,Any>)["play"] {
                            let item = (action as! Dictionary<String,Any>)["item"] as! NSMenuItem
                            Swift.print("action \(item)")
                        }
                    }
                }
                self.hiddenWindows = Dictionary<String,Any>()
            }
            else
            {
//                Swift.print("hide all windows")
                for win in NSApp.windows {
                    let frame = NSStringFromRect(win.frame)
                    let alpha = win.alphaValue
                    var dict = Dictionary <String,Any>()
                    dict["alpha"] = alpha
                    dict["window"] = win
                    if let wvc = win.contentView?.subviews.first as? MyWebView, let url = wvc.url {
                        dict["name"] = url.absoluteString
                    }
                    self.hiddenWindows[frame] = dict
//                    Swift.print("hide \(frame) to \(String(describing: alpha))")
                    win.alphaValue = 0.01
                }
            }
            return true
            
        case [NSEvent.ModifierFlags.option, NSEvent.ModifierFlags.command]:
            let notif = Notification(name: Notification.Name(rawValue: "optionAndCommandKeysDown"),
                                     object: NSNumber(booleanLiteral: commandKeyDown))
            NotificationCenter.default.post(notif)
            return true
            
        case [NSEvent.ModifierFlags.shift]:
            self.shiftKeyDown = true
            return true
            
        case [NSEvent.ModifierFlags.option]:
            self.optionKeyDown = true
            return true
            
        case [NSEvent.ModifierFlags.command]:
            self.commandKeyDown = true
            return true
            
        default:
            //  Only clear when true
            if shiftKeyDown { self.shiftKeyDown = false }
            if commandKeyDown { self.commandKeyDown = false }
            return false
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Local/Global Monitor
        _ /*accessEnabled*/ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) { (event) -> Void in
            _ = self.keyDownMonitor(event: event)
        }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) { (event) -> NSEvent? in
            return self.keyDownMonitor(event: event) ? nil : event
        }
        
        // Asynchronous code running on the low priority queue
        DispatchQueue.global(qos: .utility).async {

            if let items = self.defaults.array(forKey: UserSettings.SearchNames.keyPath) {
                for search in items {
                    self.webSearches.append(PlayItem.init(with: (search as! Dictionary)))
                }
                Swift.print("searches \(self.webSearches.count) restored")
            }
        }
        
        //  Remember item actions; use when toggle audio/video
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemAction(_:)),
            name: NSNotification.Name(rawValue: "HeliumItemAction"),
            object: nil)

        //  Synchronize our app menu visibility
        self.syncAppMenuVisibility()
        
        /* NYI  //  Register our URL protocol(s)
        URLProtocol.registerClass(HeliumURLProtocol.self) */
        
        //  If started via login item, launch the login items playlist
        if launchedAsLogInItem {
            Swift.print("We were launched as a startup item")
        }
        
        //  Developer extras off by default
        UserSettings.DeveloperExtrasEnabled.value = false
        
        //  Capture default user agent string for this platform
        UserSettings.UserAgent.default = WKWebView()._userAgent
        
        //  Restore auto save settings
        autoSaveDocs = UserSettings.AutoSaveDocs.value

        //  Restore our web (non file://) document windows if any via
        guard !disableDocumentReOpening else { return }
        if let keep = defaults.array(forKey: UserSettings.KeepListName.value) {
            for item in keep {
                guard let urlString = (item as? String) else { continue }
                if urlString == UserSettings.HomePageURL.value { continue }
                guard let url = URL.init(string: urlString ) else { continue }
                _ = self.openURLInNewWindow(url)
                Swift.print("restore \(item)")
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
        //  Forget key down monitoring
        NSEvent.removeMonitor(localKeyDownMonitor!)
        NSEvent.removeMonitor(globalKeyDownMonitor!)
        
        //  Forget location services
        if !UserSettings.RestoreLocationSvcs.value && isLocationEnabled {
            locationManager?.stopMonitoringSignificantLocationChanges()
            locationManager?.stopUpdatingLocation()
            locationManager = nil
        }
        
        //  Save sandbox bookmark urls when necessary
        if isSandboxed() != saveBookmarks() {
            Swift.print("Yoink, unable to save booksmarks")
        }

        // Save play;sits to defaults - no maximum
        savePlaylists(self)
        
        // Save histories to defaults up to their maximum
        let keep = UserSettings.HistoryKeep.value
        var temp = Array<Any>()
        for item in histories.sorted(by: { (lhs, rhs) -> Bool in return lhs.rank < rhs.rank}).suffix(keep) {
            temp.append(item.dictionary())
        }
        defaults.set(temp, forKey: UserSettings.HistoryList.keyPath)

        //  Save searches to defaults up to their maximum
        temp = Array<Any>()
        for item in webSearches.suffix(254) {
            temp.append(item.dictionary())
        }
        defaults.set(temp, forKey: UserSettings.SearchNames.keyPath)
        
        //  Save our web URLs (non file://) windows to our keep list
        if UserSettings.RestoreWebURLs.value {
            temp = Array<String>()
            for document in NSApp.orderedDocuments {
                guard let webURL = document.fileURL, !webURL.isFileURL else {
                    Swift.print("skip \(String(describing: document.fileURL?.absoluteString))")
                    continue
                }
                Swift.print("keep \(String(describing: document.fileURL?.absoluteString))")
                temp.append(webURL.absoluteString)
            }
            defaults.set(temp, forKey: UserSettings.KeepListName.value)
        }
        
        defaults.synchronize()
    }

    func applicationDockMenu(sender: NSApplication) -> NSMenu? {
        let menu = NSMenu(title: appName)
        var item: NSMenuItem

        item = NSMenuItem(title: "Open", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subOpen = NSMenu()
        item.submenu = subOpen
        
        item = NSMenuItem(title: "File…", action: #selector(AppDelegate.openFilePress(_:)), keyEquivalent: "")
        item.target = self
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "URL…", action: #selector(AppDelegate.openLocationPress(_:)), keyEquivalent: "")
        item.target = self
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Window", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "")
        item.isAlternate = true
        item.target = docController
        subOpen.addItem(item)

        item = NSMenuItem(title: "Tab", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.shift
        item.isAlternate = true
        item.target = self
        item.tag = 3
        subOpen.addItem(item)
        return menu
    }
    
    //MARK: - handleURLEvent(s)

    func metadataDictionaryForFileAt(_ fileName: String) -> Dictionary<NSObject,AnyObject>? {
        
        guard let item = MDItemCreate(kCFAllocatorDefault, fileName as CFString) else { return nil }
        
        guard let list = MDItemCopyAttributeNames(item) else { return nil }
        
        let resDict = MDItemCopyAttributes(item,list) as Dictionary
        return resDict
    }

    @objc fileprivate func haveNewTitle(_ notification: Notification) {
        guard UserSettings.HistorySaves.value else { return }
        guard let itemURL = notification.object as? URL, itemURL.scheme != k.about,
            itemURL.absoluteString != UserSettings.HomePageURL.value else {
            return
        }
        
        let item : PlayItem = PlayItem.init()
        let info = notification.userInfo!
        var fini = (info[k.fini] as AnyObject).boolValue == true
        
        //  If the title is already seen, update global and playlists
        if let dict = defaults.dictionary(forKey: itemURL.absoluteString) {
            item.update(with: dict)
        }
        else
        {
            if let fileURL: URL = (itemURL as NSURL).filePathURL {
                let path = fileURL.absoluteString//.stringByRemovingPercentEncoding
                let attr = metadataDictionaryForFileAt(fileURL.path)
                let fuzz = (itemURL as AnyObject).deletingPathExtension!!.lastPathComponent as NSString
                item.name = fuzz.removingPercentEncoding!
                item.link = URL.init(string: path)!
                item.time = attr?[kMDItemDurationSeconds] as? TimeInterval ?? 0
            }
            else
            {
                item.name = itemURL.lastPathComponent
                item.link = itemURL
                item.time = 0
            }
            fini = false
        }
        item.rank = histories.count + 1
        histories.append(item)

        //  if not finished bump plays for this item
        if fini {
            //  move to next item in playlist
            Swift.print("move to next item in playlist")
        }
        else
        {
            //  publish tally across playlists
            for play in playlists {
                guard let seen = play.list.link(item.link.absoluteString) else { continue }
                seen.plays += 1
            }
        }
        //  always synchronize this item to defaults - lazily
        defaults.set(item.dictionary(), forKey: item.link.absoluteString)
        
        //  tell any playlist controller we have updated history
        let notif = Notification(name: Notification.Name(rawValue: k.item), object: item)
        NotificationCenter.default.post(notif)
    }
    
    @objc fileprivate func clearItemAction(_ notification: Notification) {
        if let itemURL = notification.object as? URL {
            itemActions[itemURL.absoluteString] = nil
        }
    }
    @objc fileprivate func handleItemAction(_ notification: Notification) {
        if let item = notification.object as? NSMenuItem {
            let webView: MyWebView = item.representedObject as! MyWebView
            let name = webView.url?.absoluteString
            var dict : Dictionary<String,Any> = itemActions[name!] as? Dictionary<String,Any> ?? Dictionary<String,Any>()
            itemActions[name!] = dict
            if item.title == "Mute" {
                dict["mute"] = item.state == .off
            }
            else
            {
                dict["play"] = item.title == "Play"
            }
            //  Cache item for its target/action we use later
            dict["item"] = item
            Swift.print("action[\(String(describing: name))] -> \(dict)")
        }
    }

    /// Shows alert asking user to input user agent string
    /// Process response locally, validate, dispatch via supplied handler
    func didRequestUserAgent(_ strings: RequestUserStrings,
                             onWindow: HeliumPanel?,
                             title: String?,
                             acceptHandler: @escaping (String) -> Void) {
        
        // Create alert
        let alert = NSAlert()
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = strings.alertMessageText
        
        // Create urlField
        let urlField = URLField(withValue: strings.currentURL, modalTitle: title)
        urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        
        // Add urlField and buttons to alert
        alert.accessoryView = urlField
        let alert1stButton = alert.addButton(withTitle: strings.alertButton1stText)
        if let alert1stToolTip = strings.alertButton1stInfo {
            alert1stButton.toolTip = alert1stToolTip
        }
        let alert2ndButton = alert.addButton(withTitle: strings.alertButton2ndText)
        if let alert2ndtToolTip = strings.alertButton2ndInfo {
            alert2ndButton.toolTip = alert2ndtToolTip
        }
        if let alert3rdText = strings.alertButton3rdText {
            let alert3rdButton = alert.addButton(withTitle: alert3rdText)
            if let alert3rdtToolTip = strings.alertButton3rdInfo {
                alert3rdButton.toolTip = alert3rdtToolTip
            }
        }

        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)
        
        if let urlWindow = onWindow {
            alert.beginSheetModal(for: urlWindow, completionHandler: { response in
                // buttons are accept, cancel, default
                if response == NSApplication.ModalResponse.alertThirdButtonReturn {
                    let newUA = (alert.accessoryView as! NSTextField).stringValue
                    if UAHelpers.isValidUA(uaString: newUA) {
                        acceptHandler(newUA)
                    }
                    else
                    {
                        self.userAlertMessage("This apppears to be an invalid User Agent", info: newUA)
                    }
                }
                else
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    // swiftlint:disable:next force_cast
                    let newUA = (alert.accessoryView as! NSTextField).stringValue
                    if UAHelpers.isValidUA(uaString: newUA) {
                        acceptHandler(newUA)
                    }
                    else
                    {
                        self.userAlertMessage("This apppears to be an invalid User Agent", info: newUA)
                    }
                }
            })
        }
        else
        {
            switch alert.runModal() {
            case NSApplication.ModalResponse.alertThirdButtonReturn:
                let newUA = (alert.accessoryView as! NSTextField).stringValue
                if UAHelpers.isValidUA(uaString: newUA) {
                    acceptHandler(newUA)
                }
                else
                {
                    userAlertMessage("This apppears to be an invalid User Agent", info: newUA)
                }
                 
            case NSApplication.ModalResponse.alertFirstButtonReturn:
                let newUA = (alert.accessoryView as! NSTextField).stringValue
                if UAHelpers.isValidUA(uaString: newUA) {
                    acceptHandler(newUA)
                }
                else
                {
                    userAlertMessage("This apppears to be an invalid User Agent", info: newUA)
                }

            default:// NSAlertSecondButtonReturn:
                return
            }
        }
        
        // Set focus on urlField
        alert.accessoryView!.becomeFirstResponder()
    }
    
    func didRequestSearch(_ strings: RequestUserStrings,
                          onWindow: HeliumPanel?,
                          title: String?,
                          acceptHandler: @escaping (Bool,URL) -> Void) {
        
        // Create alert
        let alert = NSAlert()
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = strings.alertMessageText
        
        // Create our search field with recent searches
        let search = SearchField(withValue: strings.currentURL, modalTitle: title)
        search.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        (search.cell as! NSSearchFieldCell).maximumRecents = 254
        search.recentSearches = recentSearches
        alert.accessoryView = search
        
        // Add urlField and buttons to alert
        let alert1stButton = alert.addButton(withTitle: strings.alertButton1stText)
        if let alert1stToolTip = strings.alertButton1stInfo {
            alert1stButton.toolTip = alert1stToolTip
        }
        let alert2ndButton = alert.addButton(withTitle: strings.alertButton2ndText)
        if let alert2ndtToolTip = strings.alertButton2ndInfo {
            alert2ndButton.toolTip = alert2ndtToolTip
        }
        if let alert3rdText = strings.alertButton3rdText {
            let alert3rdButton = alert.addButton(withTitle: alert3rdText)
            if let alert3rdtToolTip = strings.alertButton3rdInfo {
                alert3rdButton.toolTip = alert3rdtToolTip
            }
        }
        
        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)
        
        if let urlWindow = onWindow {
            alert.beginSheetModal(for: urlWindow, completionHandler: { response in
                // buttons are user-search-url, cancel, google-search
                switch response {
                case NSApplication.ModalResponse.alertFirstButtonReturn,NSApplication.ModalResponse.alertThirdButtonReturn:
                    let newUrlFormat = k.searchLinks[ UserSettings.Search.value ]
                    let rawString = (alert.accessoryView as! NSTextField).stringValue
                    let newUrlString = rawString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)
                    var urlString = String(format: newUrlFormat, newUrlString!)
                    let newWindow = (response == NSApplication.ModalResponse.alertThirdButtonReturn)
                    
                    urlString = UrlHelpers.ensureScheme(urlString)
                    if UrlHelpers.isValidUA(urlString: urlString) {
                        acceptHandler(newWindow,URL.init(string: urlString)!)
                        Swift.print("search \(rawString)")
                    }

                default:
                    return
                }
            })
        }
        else
        {
            let response = alert.runModal()
            switch response {
            case NSApplication.ModalResponse.alertFirstButtonReturn,NSApplication.ModalResponse.alertThirdButtonReturn:
                let newUrlFormat = k.searchLinks[ UserSettings.Search.value ]
                let rawString = (alert.accessoryView as! NSTextField).stringValue
                let newUrlString = rawString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)
                var urlString = String(format: newUrlFormat, newUrlString!)
                let newWindow = (response == NSApplication.ModalResponse.alertThirdButtonReturn)

                urlString = UrlHelpers.ensureScheme(urlString)
                guard UrlHelpers.isValidUA(urlString: urlString), let searchURL = URL.init(string: urlString) else {
                    Swift.print("invalid: \(urlString)")
                    return
                }
                acceptHandler(newWindow,searchURL)
                Swift.print("search \(rawString)")

            default:// NSAlertSecondButtonReturn:
                return
            }
        }
        
        // Set focus on urlField
        alert.accessoryView!.becomeFirstResponder()
    }

    func didRequestUserUrl(_ strings: RequestUserStrings,
                           onWindow: HeliumPanel?,
                           title: String?,
                           acceptHandler: @escaping (String) -> Void) {
        
        // Create alert
        let alert = NSAlert()
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = strings.alertMessageText
        
        // Create urlField
        let urlField = URLField(withValue: strings.currentURL, modalTitle: title)
        urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        alert.accessoryView = urlField

        // Add urlField and buttons to alert
        let alert1stButton = alert.addButton(withTitle: strings.alertButton1stText)
        if let alert1stToolTip = strings.alertButton1stInfo {
            alert1stButton.toolTip = alert1stToolTip
        }
        let alert2ndButton = alert.addButton(withTitle: strings.alertButton2ndText)
        if let alert2ndtToolTip = strings.alertButton2ndInfo {
            alert2ndButton.toolTip = alert2ndtToolTip
        }
        if let alert3rdText = strings.alertButton3rdText {
            let alert3rdButton = alert.addButton(withTitle: alert3rdText)
            if let alert3rdtToolTip = strings.alertButton3rdInfo {
                alert3rdButton.toolTip = alert3rdtToolTip
            }
        }
        
        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)
        
        if let urlWindow = onWindow {
            alert.beginSheetModal(for: urlWindow, completionHandler: { response in
                // buttons are accept, cancel, default
                if response == NSApplication.ModalResponse.alertThirdButtonReturn {
                    var newUrl = (alert.buttons[2] as NSButton).toolTip
                    newUrl = UrlHelpers.ensureScheme(newUrl!)
                    if UrlHelpers.isValidUA(urlString: newUrl!) {
                        acceptHandler(newUrl!)
                    }
                }
                else
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    // swiftlint:disable:next force_cast
                    var newUrl = (alert.accessoryView as! NSTextField).stringValue
                    newUrl = UrlHelpers.ensureScheme(newUrl)
                    if UrlHelpers.isValidUA(urlString: newUrl) {
                        acceptHandler(newUrl)
                    }
                }
            })
        }
        else
        {
            //  No window, so load panel modally
            NSApp.activate(ignoringOtherApps: true)

            switch alert.runModal() {
            case NSApplication.ModalResponse.alertThirdButtonReturn:
                var newUrl = (alert.buttons[2] as NSButton).toolTip
                newUrl = UrlHelpers.ensureScheme(newUrl!)
                if UrlHelpers.isValidUA(urlString: newUrl!) {
                    acceptHandler(newUrl!)
                }
                
            case NSApplication.ModalResponse.alertFirstButtonReturn:
                var newUrl = (alert.accessoryView as! NSTextField).stringValue
                newUrl = UrlHelpers.ensureScheme(newUrl)
                if UrlHelpers.isValidUA(urlString: newUrl) {
                    acceptHandler(newUrl)
                }
                
            default:// NSAlertSecondButtonReturn:
                return
            }
        }
        
        // Set focus on urlField
        alert.accessoryView!.becomeFirstResponder()
    }
    
    // Called when the App opened via URL.
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        let viewOptions = getViewOptions

        guard let keyDirectObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)),
            let rawString = keyDirectObject.stringValue else {
                return print("No valid URL to handle")
        }

        //  strip helium://
        let index = rawString.index(rawString.startIndex, offsetBy: 9)
        let urlString = rawString.suffix(from: index)
        
        //  Handle new window here to narrow cast to new or current panel controller
        if (viewOptions == sameWindow || !openForBusiness), let wc = NSApp.keyWindow?.windowController {
            if let hpc : HeliumPanelController = wc as? HeliumPanelController {
                _ = (hpc.contentViewController as! WebViewController).loadURL(text: String(urlString))
                return
            }
        }
        else
        {
            _ = openURLInNewWindow(URL.init(string: String(urlString))!)
        }
    }

    @objc func handleURLPboard(_ pboard: NSPasteboard, userData: NSString, error: NSErrorPointer) {
        if let selection = pboard.string(forType: NSPasteboard.PasteboardType.string) {

            // Notice: string will contain whole selection, not just the urls
            // So this may (and will) fail. It should instead find url in whole
            // Text somehow
            NotificationCenter.default.post(name: Notification.Name(rawValue: "HeliumLoadURLString"), object: selection)
        }
    }
    
    // MARK: Application Events
    dynamic var disableDocumentReOpening = false

    func application(_ sender: NSApplication, openFile: String) -> Bool {
        let urlString = (openFile.hasPrefix("file://") ? openFile : "file" + openFile)
        let fileURL = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!
        disableDocumentReOpening = openFileInNewWindow(fileURL)
        return disableDocumentReOpening
    }
    
    func application(_ sender: NSApplication, openFiles: [String]) {
        // Create a FileManager instance
        let fileManager = FileManager.default
        
        for path in openFiles {

            do {
                if var url = URL.init(string: path.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!) {
                    if nil == url.scheme { url = url.settingScheme("file") }
                    if !url.hasDirectory() { url = url.settingDirectoryPath(fileManager.currentDirectoryPath) }
                    if isSandboxed() != storeBookmark(url: url) { continue }
                    if !self.application(sender, openURL: url) {
                        Swift.print("Yoink url? \(url.absoluteString)")
                    }
                    continue
                }
                
                if fileManager.fileExists(atPath: path) {
                    if !self.application(sender, openFile: path) {
                        Swift.print("Yoink path \(path)")
                    }
                    continue
                }

                let files = try fileManager.contentsOfDirectory(atPath: path)
                for file in files {
                    _ = self.application(sender, openFile: file)
                }
            }
            catch let error as NSError {
                print("Yoink \(error.localizedDescription)")
            }
        }
    }
    
    func application(_ application: NSApplication, openURL: URL) -> Bool {
        disableDocumentReOpening = openURLInNewWindow(openURL)
        return disableDocumentReOpening
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        
        for url in urls {
            
            if !self.application(application, openURL: url) {
                print("Yoink unable to open \(url)")
            }
        }
    }
    
    // MARK:- Sandbox Support
    var bookmarks = [URL: Data]()

    func authenticateBaseURL(_ url: URL) -> URL {
        guard isSandboxed(), url.hasHTMLContent() else { return url }
        
        let openPanel = NSOpenPanel()
        var baseURL = url
        
        openPanel.message = "Authorize access to " + baseURL.lastPathComponent
        openPanel.prompt = "Authorize"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.directoryURL = baseURL.deletingLastPathComponent()
        
        openPanel.begin() { (result) -> Void in
            if (result == .OK) {
                if let authURL = openPanel.url {
                    if self.storeBookmark(url: authURL) {
                        baseURL = authURL
                    }
                    else
                    {
                        Swift.print("Yoink, unable to sandbox base \(authURL)")
                    }
                }
            }
        }
        return baseURL
    }
    
    func isSandboxed() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        var staticCode:SecStaticCode?
        var isSandboxed:Bool = false
        let kSecCSDefaultFlags:SecCSFlags = SecCSFlags(rawValue: SecCSFlags.RawValue(0))
        
        if SecStaticCodeCreateWithPath(bundleURL as CFURL, kSecCSDefaultFlags, &staticCode) == errSecSuccess {
            if SecStaticCodeCheckValidityWithErrors(staticCode!, SecCSFlags(rawValue: kSecCSBasicValidateOnly), nil, nil) == errSecSuccess {
                let appSandbox = "entitlement[\"com.apple.security.app-sandbox\"] exists"
                var sandboxRequirement:SecRequirement?
                
                if SecRequirementCreateWithString(appSandbox as CFString, kSecCSDefaultFlags, &sandboxRequirement) == errSecSuccess {
                    let codeCheckResult:OSStatus  = SecStaticCodeCheckValidityWithErrors(staticCode!, SecCSFlags(rawValue: kSecCSBasicValidateOnly), sandboxRequirement, nil)
                    if (codeCheckResult == errSecSuccess) {
                        isSandboxed = true
                    }
                }
            }
        }
        return isSandboxed
    }
    
    func bookmarkPath() -> String?
    {
        if var documentsPathURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsPathURL = documentsPathURL.appendingPathComponent("Bookmarks.dict")
            return documentsPathURL.path
        }
        else
        {
            return nil
        }
    }
    
    func loadBookmarks() -> Bool
    {
        //  Ignore loading unless configured
        guard isSandboxed() else { return false }

        let fm = FileManager.default
        
        guard let path = bookmarkPath(), fm.fileExists(atPath: path) else {
            return saveBookmarks()
        }
        
        var restored = 0
        bookmarks = NSKeyedUnarchiver.unarchiveObject(withFile: path) as! [URL: Data]
        var iterator = bookmarks.makeIterator()

        while let bookmark = iterator.next()
        {
            //  stale bookmarks get dropped
            if !fetchBookmark(bookmark) {
                bookmarks.removeValue(forKey: bookmark.key)
            }
            else
            {
                restored += 1
            }
        }
        return restored == bookmarks.count
    }
    
    func saveBookmarks() -> Bool
    {
        //  Ignore saving unless configured
        guard isSandboxed() else { return false }

        if let path = bookmarkPath() {
            return NSKeyedArchiver.archiveRootObject(bookmarks, toFile: path)
        }
        else
        {
            return false
        }
    }
    
    func storeBookmark(url: URL, options: URL.BookmarkCreationOptions = [.withSecurityScope,.securityScopeAllowOnlyReadAccess]) -> Bool
    {
        guard isSandboxed() else { return false }
        
        //  Peek to see if we've seen this key before
        if let data = bookmarks[url] {
            if self.fetchBookmark((key: url, value: data)) {
//                Swift.print ("= \(url.absoluteString)")
                return true
            }
        }
        do
        {
            let data = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarks[url] = data
            return self.fetchBookmark((key: url, value: data))
        }
        catch let error
        {
            NSApp.presentError(error)
            Swift.print ("Error storing bookmark: \(url)")
            return false
        }
    }
    
    func reloadBookmark(_ url: URL) -> Bool {
        guard isSandboxed() else { return false }

        if let data = bookmarks[url] {
            if self.fetchBookmark((key: url, value: data)) {
                return fetchBookmark( (key: url, value: data))
            }
        }
        return false
    }

    func fetchBookmark(_ bookmark: (key: URL, value: Data)) -> Bool
    {
        guard isSandboxed() else { return false }

        let restoredUrl: URL?
        var isStale = true
        
        do
        {
            restoredUrl = try URL.init(resolvingBookmarkData: bookmark.value, options: URL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
        catch let error
        {
            Swift.print("! \(bookmark.key) \n\(error.localizedDescription)")
            return false
        }
        
        guard let url = restoredUrl else {
            Swift.print ("? \(bookmark.key)")
            return false
        }
        
        if isStale {
            Swift.print ("≠ \(bookmark.key)")
            return false
        }
        
        let fetch = url.startAccessingSecurityScopedResource()
        Swift.print ("\(fetch ? "•" : "º") \(bookmark.key)")
        return fetch
    }
}

