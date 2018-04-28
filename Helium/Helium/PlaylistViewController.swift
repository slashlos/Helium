//
//  PlaylistViewController.swift
//  Helium
//
//  Created by Carlos D. Santiago on 2/15/17.
//  Copyright (c) 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation
import AVFoundation

struct k {
    static let play = "play"
    static let item = "item"
    static let name = "name"
    static let list = "list"
    static let link = "link"
    static let time = "time"
    static let rank = "rank"
    static let rect = "rect"
    static let label = "label"
    static let hover = "hover"
    static let alpha = "alpha"
    static let trans = "trans"
    static let TitleUtility: CGFloat = 16.0
    static let TitleNormal: CGFloat = 22.0
    static let ToolbarItemHeight: CGFloat = 48.0
    static let ToolbarItemSpacer: CGFloat = 4.0
    static let ToolbarTextHeight: CGFloat = 12.0
    static let ToolbarlessSpacer: CGFloat = 4.0
}

extension NSImage {
    
    func resize(w: Int, h: Int) -> NSImage {
        let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        self.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height),
                   from: NSMakeRect(0, 0, self.size.width, self.size.height),
                         operation: .sourceOver,
                         fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        return NSImage(data: newImage.tiffRepresentation!)!
    }
}

//	Create a file Handle or url for writing to a new file located in the directory specified by 'dirpath'.
//  If the file basename.extension already exists at that location, then append "-N" (where N is a whole
//  number starting with 1) until a unique basename-N.extension file is found.  On return oFilename
//  contains the name of the newly created file referenced by the returned NSFileHandle (autoreleased).
func NewFileHandleForWriting(path: String, name: String, type: String, outFile: inout String?) -> FileHandle? {
    let fm = FileManager.default
    var file: String? = nil
    var fileURL: URL? = nil
    var uniqueNum = 0

    do {
        while true {
            let tag = (uniqueNum > 0 ? String(format: "-%d", uniqueNum) : "")
            let unique = String(format: "%@%@.%@", name, tag, type)
            file = String(format: "%@/%@", path, unique)
            fileURL = URL.init(fileURLWithPath: file!)
            if false == ((try? fileURL?.checkResourceIsReachable()) ?? false) { break }
            
            // Try another tag.
            uniqueNum += 1;
        }
        outFile = file!
        
        if fm.createFile(atPath: file!, contents: nil, attributes: [FileAttributeKey.extensionHidden.rawValue: true]) {
            let fileHandle = try FileHandle.init(forWritingTo: fileURL!)
            print("\(file!) was opened for writing")
            return fileHandle
        } else {
            return nil
        }
    } catch let error {
        NSApp.presentError(error)
        return nil;
    }
}

func NewFileURLForWriting(path: String, name: String, type: String) -> URL? {
    let fm = FileManager.default
    var file: String? = nil
    var fileURL: URL? = nil
    var uniqueNum = 0
    
    while true {
        let tag = (uniqueNum > 0 ? String(format: "-%d", uniqueNum) : "")
        let unique = String(format: "%@%@.%@", name, tag, type)
        file = String(format: "%@/%@", path, unique)
        fileURL = URL.init(fileURLWithPath: file!)
        if false == ((try? fileURL?.checkResourceIsReachable()) ?? false) { break }
        
        // Try another tag.
        uniqueNum += 1;
    }
    
    if fm.createFile(atPath: file!, contents: nil, attributes: [FileAttributeKey.extensionHidden.rawValue: true]) {
        return fileURL
    } else {
        return nil
    }
}

class PlayTableView : NSTableView {
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers! == String(Character(UnicodeScalar(NSDeleteCharacter)!)) ||
           event.charactersIgnoringModifiers! == String(Character(UnicodeScalar(NSDeleteFunctionKey)!)) {
            // Take action in the delegate.
            let delegate: PlaylistViewController = self.delegate as! PlaylistViewController
            
            delegate.removePlaylist(self)
        }
        else
        {
            // still here?
            super.keyDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let dragPosition = self.convert(event.locationInWindow, to: nil)
        let imageLocation = NSMakeRect(dragPosition.x - 16.0, dragPosition.y - 16.0, 32.0, 32.0)

        _ = self.dragPromisedFiles(ofTypes: ["h3w"], from: imageLocation, source: self, slideBack: true, event: event)
    }

    override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    override func dragImageForRows(with dragRows: IndexSet, tableColumns: [NSTableColumn], event dragEvent: NSEvent, offset dragImageOffset: NSPointPointer) -> NSImage {
        return NSApp.applicationIconImage.resize(w: 32, h: 32)
    }
    override func draggingEntered(_ info: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = info.draggingPasteboard()
        
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboardURLReadingFileURLsOnlyKey]) {
            return .copy
        }
        return .copy
    }
    func tableViewColumnDidResize(notification: NSNotification ) {
        // Pay attention to column resizes and aggressively force the tableview's cornerview to redraw.
        self.cornerView?.needsDisplay = true
    }

}

class PlayItemCornerView : NSView {
    @IBOutlet weak var playlistArrayController: NSDictionaryController!
	@IBOutlet weak var playitemArrayController: NSArrayController!
    @IBOutlet weak var playitemTableView: PlayTableView!
    override func draw(_ dirtyRect: NSRect) {
        let tote = NSImage.init(imageLiteralResourceName: "NSRefreshTemplate")
        let alignRect = tote.alignmentRect
        
        NSGraphicsContext.saveGraphicsState()
        tote.draw(in: NSMakeRect(2, 5, 7, 11), from: alignRect, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }
    
    override func mouseDown(with event: NSEvent) {
        // Renumber playlist items via array controller
        playitemTableView.beginUpdates()
        for (row,item) in (playitemArrayController.arrangedObjects as! [PlayItem]).enumerated() {
            item.rank = row + 1
        }
        playitemTableView.endUpdates()
    }
}

class PlayItemHeaderView : NSTableHeaderView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let action = #selector(PlaylistViewController.toggleColumnVisiblity(_ :))
        let target = self.tableView?.delegate
        let menu = NSMenu.init()
        var item: NSMenuItem
        
        //	We auto enable items as views present them
        menu.autoenablesItems = true
        
        //	TableView level column customizations
        for col in (self.tableView?.tableColumns)! {
            let title = col.headerCell.stringValue
            let state = col.isHidden
            
            item = NSMenuItem.init(title: title, action: action, keyEquivalent: "")
            item.image = NSImage.init(named: (state) ? "NSOnImage" : "NSOffImage")
            item.state = (state ? NSOffState : NSOnState)
            item.representedObject = col
            item.isEnabled = true
            item.target = target
            menu.addItem(item)
        }
        return menu
    }
}

extension NSURL {
    
    func compare(_ other: URL ) -> ComparisonResult {
        return (self.absoluteString?.compare(other.absoluteString))!
    }
//  https://stackoverflow.com/a/44908669/564870
    func resolvedFinderAlias() -> URL? {
        if (self.fileReferenceURL() != nil) { // item exists
            do {
                // Get information about the file alias.
                // If the file is not an alias files, an exception is thrown
                // and execution continues in the catch clause.
                let data = try NSURL.bookmarkData(withContentsOf: self as URL)
                // NSURLPathKey contains the target path.
                let rv = NSURL.resourceValues(forKeys: [ URLResourceKey.pathKey ], fromBookmarkData: data)
                var urlString = rv![URLResourceKey.pathKey] as! String
                if !urlString.hasPrefix("file://") {
                    urlString = "file://" + urlString
                }
                return URL(string: urlString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!
            } catch {
                // We know that the input path exists, but treating it as an alias
                // file failed, so we assume it's not an alias file so return nil.
                return nil
            }
        }
        return nil
    }
}

class PlaylistViewController: NSViewController,NSTableViewDataSource,NSTableViewDelegate {

    @IBOutlet var playlistArrayController: NSDictionaryController!
    @IBOutlet var playitemArrayController: NSArrayController!

    @IBOutlet var playlistTableView: PlayTableView!
    @IBOutlet var playitemTableView: PlayTableView!
    @IBOutlet var playlistSplitView: NSSplitView!

    //    cache playlists read and saved to defaults
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    var defaults = UserDefaults.standard
    dynamic var playlists = Dictionary<String, Any>()
    dynamic var playCache = Dictionary<String, Any>()
    
    override func viewDidLoad() {
        let types = [kUTTypeData as String,
                     kUTTypeURL as String,
                     NSDictionaryControllerKeyValuePair.className(),
                     PlayItem.className(),
                     NSFilenamesPboardType,
                     NSFilesPromisePboardType,
                     NSURLPboardType]

        playlistTableView.register(forDraggedTypes: types)
        playitemTableView.register(forDraggedTypes: types)

        playlistTableView.doubleAction = #selector(playPlaylist(_:))
        playitemTableView.doubleAction = #selector(playPlaylist(_:))
        
        //  Load playlists shared by all document; our delegate maintains history
        self.restorePlaylists(restoreButton)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gotNewHistoryItem(_:)),
            name: NSNotification.Name(rawValue: "HeliumNewHistoryItem"),
            object: nil)

        //  Restore hidden columns in playitems using defaults
        let hideit = ["link","rect","label","hover","alpha","trans"]
        for col in playitemTableView.tableColumns {
            let identifier = col.identifier
            let pref = String(format: "hide.%@", identifier)
            var isHidden = false
            
            //	If have a preference, honor it, else apply hidden default
            if defaults.value(forKey: pref) != nil
            {
                isHidden = defaults.bool(forKey: pref)
                hiddenColumns[pref] = String(isHidden)
            }
            else
            if hideit.contains(identifier)
            {
                isHidden = true
            }
            col.isHidden = isHidden
        }
    }

    var historyCache: NSDictionaryControllerKeyValuePair? = nil
    override func viewWillAppear() {
        // add existing history entry if any AVQueuePlayer
        if historyCache == nil {
            historyCache = playlistArrayController.newObject() as NSDictionaryControllerKeyValuePair
            historyCache!.key = UserSettings.HistoryName.value
            historyCache!.value = [PlayItem]()
        }
        
        if appDelegate.histories.count > 0 {
            playlists[UserSettings.HistoryName.value] = nil
            
            // overlay in history using NSDictionaryControllerKeyValuePair Protocol setKey
            historyCache = playlistArrayController.newObject() as NSDictionaryControllerKeyValuePair
            historyCache!.key = UserSettings.HistoryName.value
            historyCache!.value = appDelegate.histories
        }
        playlistArrayController.addObject(historyCache!)
        
        // cache our list before editing
        playCache = playlists
        
        self.playlistSplitView.setPosition(120, ofDividerAt: 0)
        NSApp.activate(ignoringOtherApps: true)
        self.view.window?.makeKeyAndOrderFront(self)
    }

    @IBAction func addPlaylist(_ sender: NSButton) {
        let whoAmI = self.view.window?.firstResponder
        
        if whoAmI == playlistTableView, let selectedPlaylist = playlistArrayController.selectedObjects.first as? NSDictionaryControllerKeyValuePair {
            let list: Array<PlayItem> = selectedPlaylist.value as! Array
            let item = PlayItem(name:"item#",link:URL.init(string: "http://")!,time:0.0,rank:list.count + 1);
            let temp = NSString(format:"%p",item) as String
            item.name += String(temp.suffix(3))

            playitemArrayController.addObject(item)

            DispatchQueue.main.async {
                self.playitemTableView.scrollRowToVisible(list.count - 1)
            }
        }
        else
        if whoAmI == playlistTableView {
            let item = playlistArrayController.newObject()
            let list = Array <PlayItem>()

            let temp = NSString(format:"%p",list) as String
            let name = "play#" + String(temp.suffix(3))
            item.key = name
            item.value = list
            
            playlistArrayController.addObject(item)

            DispatchQueue.main.async {
                self.playlistTableView.scrollRowToVisible(self.playlists.count - 1)
            }
        }
        else
        {
            Swift.print("firstResponder: \(String(describing: whoAmI))")
        }
    }

    @IBAction func removePlaylist(_ sender: AnyObject) {
        let whoAmI = self.view.window?.firstResponder

        if whoAmI == playlistTableView, let selectedPlaylist = playlistArrayController.selectedObjects.first as? NSDictionaryControllerKeyValuePair {
            playlistArrayController.removeObject(selectedPlaylist)
        }
        else
        if whoAmI == playitemTableView, let selectedPlayItem = playitemArrayController.selectedObjects.first as? PlayItem {
            playitemArrayController.removeObject(selectedPlayItem)
        }
        else
        if let selectedPlayItem = playitemArrayController.selectedObjects.first as? PlayItem {
            playitemArrayController.removeObject(selectedPlayItem)
        }
        else
        if let selectedPlaylist = playlistArrayController.selectedObjects.first as? Dictionary<String,AnyObject> {
            playlistArrayController.removeObject(selectedPlaylist)
        }
        else
        {
            Swift.print("firstResponder: \(String(describing: whoAmI))")
            AudioServicesPlaySystemSound(1051);
        }
    }

    // Our playlist panel return point if any
    var webViewController: WebViewController? = nil
    
    @IBAction func playPlaylist(_ sender: AnyObject) {
        let whoAmI = self.view.window?.firstResponder

        if whoAmI == playitemTableView, let selectedPlayItem = playitemArrayController.selectedObjects.first as? PlayItem {
            super.dismiss(sender)

            //  If we were run modally as a window, close it
            if let ppc = self.view.window?.windowController {
                if ppc.isKind(of: PlaylistPanelController.self) {
                    NSApp.abortModal()
                }
            }
            
            if (webViewController != nil) {
                webViewController?.loadURL(url: selectedPlayItem.link)
            }
            else
            {
                //  if we have a panel send it there, else create new doc window
                if let first = NSApp.windows.first {
                    if let hpc = first.windowController as? HeliumPanelController {
                        hpc.webViewController.loadURL(url: selectedPlayItem.link)
                        return
                    }
                }
                
                //  This could be anything so add/if a doc and initialize
                do {
                    let dc = NSDocumentController.shared()
                    let fileURL = selectedPlayItem.link
                    let fileType = fileURL.pathExtension
                    
                    let doc = try Document.init(contentsOf: fileURL, ofType: fileType)
                    doc.makeWindowControllers()
                    dc.addDocument(doc)
                    
                    if let hwc = (doc as NSDocument).windowControllers.first {
                        (hwc.contentViewController as! WebViewController).loadURL(url: (doc as Document).fileURL!)
                        hwc.window?.orderFront(self)
                    }
                } catch let error {
                    print("*** Error open file: \(error.localizedDescription)")
                }
             }
        }
        else
        if whoAmI == playlistTableView, let selectedPlaylist = playlistArrayController.selectedObjects.first as? NSDictionaryControllerKeyValuePair {
            let list: Array<PlayItem> = (selectedPlaylist.value as! Array).sorted(by: { (lhs, rhs) -> Bool in
                return lhs.rank < rhs.rank
                })
            
            if list.count > 0 {
                super.dismiss(sender)
                
                //  Do not exceed program / user specified throttle
                if list.count > UserSettings.playlistThrottle.value {
                    let message = String(format: "Playlist's %ld items exceeds throttle.",
                                         list.count)
                    let infoMsg = String(format: "User defaults: %@ = %ld",
                                         UserSettings.playlistThrottle.keyPath,
                                         UserSettings.playlistThrottle.value)
                    appDelegate.userAlertMessage(message, info: infoMsg)
                    return
                }
                
                //  Try to restore item at its last known location
                print("play \(selectedPlaylist) \(list.count)")
                for (i,item) in list.enumerated() {
                    do {
                        _ = try Document.init(withPlayitem: item)
                        print(String(format: "%3d %3d %@", i, item.rank, item.name))
                    } catch let error {
                        NSApp.presentError(error)
                    }
                }
            }
        }
        else
        {
            Swift.print("firstResponder: \(String(describing: whoAmI))")
            AudioServicesPlaySystemSound(1051);
        }
    }
    
    // Return notification from webView controller
    @objc func gotNewHistoryItem(_ note: Notification) {
        historyCache!.value = appDelegate.histories
    }

    @IBOutlet weak var restoreButton: NSButton!
    @IBAction func restorePlaylists(_ sender: NSButton) {
        if playCache.count > 0 {
            playlists = playCache
        }
        else
        if let playArray = defaults.dictionary(forKey: UserSettings.Playlists.keyPath) {
            for (name,plist) in playArray {
                guard let items = plist as? [Dictionary<String,Any>] else {
                    let item = PlayItem.init(with: (plist as? Dictionary<String,Any>)!)
                    playlists[name] = [item]
                    continue
                }
                var list : [PlayItem] = [PlayItem]()
                for playitem in items {
                    let item = PlayItem.init(with: playitem)
                    
                    list.append(item)
                }
                playlists[name] = list
            }
        }
    }

    @IBOutlet weak var saveButton: NSButton!
    @IBAction func savePlaylists(_ sender: AnyObject) {
        let playArray = playlistArrayController.arrangedObjects as! [NSDictionaryControllerKeyValuePair]
        var temp = Dictionary<String,Any>()
        for playlist in playArray {
            var list = Array<Any>()
            for playitem in playlist.value as! [PlayItem] {
                //  Capture latest rect if this item's is zero and one is available
                playitem.refresh()

                let dict = playitem.dictionary()
                list.append(dict)
            }
            temp[playlist.key!] = list
        }
        defaults.set(temp, forKey: UserSettings.Playlists.keyPath)
        defaults.synchronize()
    }
    
    @IBAction override func dismiss(_ sender: Any?) {
        super.dismiss(sender)
        
        //  If we were run modally as a window, close it
        if let ppc = self.view.window?.windowController {
            if ppc.isKind(of: PlaylistPanelController.self) {
                NSApp.abortModal()
            }
        }
        
        //    Save or go
        switch (sender! as AnyObject).tag == 0 {
            case true:
                // Save history info which might have changed
                if historyCache != nil {
                    appDelegate.histories = historyCache?.value as! Array<PlayItem>
                    UserSettings.HistoryName.value = (historyCache?.key)!
                }
                // Save to the cache
                playCache = playlists
                break
            case false:
                // Restore from cache
                playlists = playCache
        }
    }

    dynamic var hiddenColumns = Dictionary<String, Any>()
    @IBAction func toggleColumnVisiblity(_ sender: NSMenuItem) {
        let col = sender.representedObject as! NSTableColumn
        let identifier = col.identifier
        let pref = String(format: "hide.%@", identifier)
        let isHidden = !col.isHidden
        
        hiddenColumns.updateValue(String(isHidden), forKey: pref)
        defaults.set(isHidden, forKey: pref)
        col.isHidden = isHidden
     }

    // MARK:- Drag-n-Drop
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {

        if tableView == playlistTableView {
            let objects: [NSDictionaryControllerKeyValuePair] = playlistArrayController.arrangedObjects as! [NSDictionaryControllerKeyValuePair]
            var items: [NSDictionaryControllerKeyValuePair] = [NSDictionaryControllerKeyValuePair]()
            var promises = [String]()
            for index in rowIndexes {
                let listitem = objects[index]
                promises.append(listitem.key!)
                items.append(listitem)
            }
            pboard.setPropertyList(items, forType: NSDictionaryControllerKeyValuePair.className())
            pboard.setPropertyList(promises, forType:NSFilesPromisePboardType)
            pboard.writeObjects(promises as [NSPasteboardWriting])
        }
        else
        {
            let objects: [PlayItem] = playitemArrayController.arrangedObjects as! [PlayItem]
            var items: [PlayItem] = [PlayItem]()
            var promises = [String]()
            for index in rowIndexes {
                let playitem = objects[index]
                promises.append(playitem.link.absoluteString)
                items.append(playitem)
            }
            pboard.setPropertyList(promises, forType:NSFilesPromisePboardType)
            pboard.setPropertyList(promises, forType: kUTTypeFileURL as String)
            pboard.writeObjects(promises as [NSPasteboardWriting])
        }
        return true
    }
    
    func performDragOperation(info: NSDraggingInfo) -> Bool {
        let pboard: NSPasteboard = info.draggingPasteboard()
        let types = pboard.types
    
        if (types?.contains(NSFilenamesPboardType))! {
            let names = info.namesOfPromisedFilesDropped(atDestination: URL.init(string: "file://~/Desktop/")!)
            // Perform operation using the files’ names, but without the
            // files actually existing yet
            Swift.print("performDragOperation: NSFilenamesPboardType \(String(describing: names))")
        }
        if (types?.contains(NSFilesPromisePboardType))! {
            let names = info.namesOfPromisedFilesDropped(atDestination: URL.init(string: "file://~/Desktop/")!)
            // Perform operation using the files’ names, but without the
            // files actually existing yet
            Swift.print("performDragOperation: NSFilesPromisePboardType \(String(describing: names))")
        }
        return true
    }

    func tableView(_ tableView: NSTableView, namesOfPromisedFilesDroppedAtDestination dropDestination: URL, forDraggedRowsWith indexSet: IndexSet) -> [String] {
        var names: [String] = [String]()
        //	Always marshall an array of items regardless of item count
        if tableView == playlistTableView {
            let objects: [NSDictionaryControllerKeyValuePair] = playlistArrayController.arrangedObjects as! [NSDictionaryControllerKeyValuePair]
            for index in indexSet {
                let dictKV = objects[index]
                var items: [Any] = [Any]()
                let name = dictKV.key!
                for item in dictKV.value as! [PlayItem] {
                    let dict = item.dictionary()
                    items.append(dict)
                }

                if let fileURL = NewFileURLForWriting(path: dropDestination.path, name: name, type: "h3w") {
                    var dict = Dictionary<String,[Any]>()
                    dict[UserSettings.Playitems.default] = items
                    dict[UserSettings.Playlists.default] = [name as AnyObject]
                    dict[name] = items
                    (dict as NSDictionary).write(to: fileURL, atomically: true)
                    names.append(fileURL.absoluteString)
                }
            }
        }
        else
        {
            let selection = playlistArrayController.selectedObjects.first as! NSDictionaryControllerKeyValuePair
            let objects: [PlayItem] = playitemArrayController.arrangedObjects as! [PlayItem]
            let name = String(format: "%@+%ld", selection.key!, indexSet.count)
            var items: [AnyObject] = [AnyObject]()

            for index in indexSet {
                let item = objects[index]
                names.append(item.link.absoluteString)
                items.append(item.dictionary() as AnyObject)
            }
            
            if let fileURL = NewFileURLForWriting(path: dropDestination.path, name: name, type: "h3w") {
                var dict = Dictionary<String,[AnyObject]>()
                dict[UserSettings.Playitems.default] = items
                dict[UserSettings.Playlists.default] = [name as AnyObject]
                dict[name] = items
                (dict as NSDictionary).write(to: fileURL, atomically: true)
            }
        }
        return names
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableViewDropOperation) -> NSDragOperation {
//        let sourceTableView = info.draggingSource() as? NSTableView

        if dropOperation == .above {
            let pboard = info.draggingPasteboard();
            let options = [NSPasteboardURLReadingFileURLsOnlyKey : true,
                           NSPasteboardURLReadingContentsConformToTypesKey : [kUTTypeMovie as String]] as [String : Any]
            let items = pboard.readObjects(forClasses: [NSURL.classForCoder()], options: options)
            let isSandboxed = appDelegate.isSandboxed()
            
            if items!.count > 0 {
                for item in items! {
                    if (item as! URL).isFileURL {
                        var fileURL : NSURL? = (item as AnyObject).filePathURL!! as NSURL

                        //  Resolve alias before storing bookmark
                        if let original = fileURL?.resolvedFinderAlias() { fileURL = original as NSURL }
                        
                        if isSandboxed != appDelegate.storeBookmark(url: fileURL! as URL) {
                            Swift.print("Yoink, unable to sandbox \(String(describing: fileURL)))")
                        }

                        //    if it's a video file, get and set window content size to its dimentions
                        let track0 = AVURLAsset(url:fileURL! as URL, options:nil).tracks[0]
                        if track0.mediaType != AVMediaTypeVideo
                        {
                            Swift.print("Yoink, unknown media type: \(track0.mediaType) in \(String(describing: fileURL)))")
                        }
                    } else {
                        print("validate item -> \(item)")
                    }
                }
                
                if isSandboxed != appDelegate.saveBookmarks() {
                    Swift.print("Yoink, unable to save bookmarks")
                }
            }
            return .copy
        }
        return .every
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableViewDropOperation) -> Bool {
        let pasteboard = info.draggingPasteboard()
        let options = [NSPasteboardURLReadingFileURLsOnlyKey : true,
                       NSPasteboardURLReadingContentsConformToTypesKey : [kUTTypeMovie as String]] as [String : Any]
        let sourceTableView = info.draggingSource() as? NSTableView
        var oldIndexes = [Int]()
        var oldIndexOffset = 0
        var newIndexOffset = 0

        // We have intra tableView drag-n-drop ?
        if tableView == sourceTableView {
            info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) {
                tableView.beginUpdates()

                if let str = ($0.0.item as! NSPasteboardItem).string(forType: "public.data"), let index = Int(str) {
                    oldIndexes.append(index)
                }
                // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
                // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
                
                for oldIndex in oldIndexes {
                    if oldIndex < row {
                        tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
                        oldIndexOffset -= 1
                    } else {
                        tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
                        newIndexOffset += 1
                    }
                }
                tableView.endUpdates()
            }
        }
        else

        // We have inter tableView drag-n-drop ?
        // if source is a playlist, drag its items into the destination via copy
        // if source is a playitem, drag all items into the destination playlist
        // creating a new playlist item unless, we're dropping onto an existing.
        
        if sourceTableView == playlistTableView {
            let selectedRowIndexes = sourceTableView?.selectedRowIndexes
            
            tableView.beginUpdates()
            for index in selectedRowIndexes! {
                let source = (playlistArrayController.arrangedObjects as! [Any])[index] as! NSDictionaryControllerKeyValuePair
                for playItem in source.value as! [PlayItem] {
                    
                    playitemArrayController.addObject(playItem)

                }
            }
            tableView.endUpdates()
        }
        else
        
        if sourceTableView == playitemTableView {
            // These playitems get dropped into a new or append a playlist
            let items: [PlayItem] = playitemArrayController.arrangedObjects as! [PlayItem]
            var selectedPlaylist: NSDictionaryControllerKeyValuePair? = playlistArrayController.selectedObjects.first as? NSDictionaryControllerKeyValuePair
            let selectedRowIndexes = sourceTableView?.selectedRowIndexes
            var list: [PlayItem]? = nil

            tableView.beginUpdates()
            if selectedPlaylist != nil && row < tableView.numberOfRows {
                selectedPlaylist = (playlistArrayController.arrangedObjects as! Array)[row]
                list = (selectedPlaylist?.value as! [PlayItem])
            }
            else
            {
                selectedPlaylist = playlistArrayController.newObject()
                list = [PlayItem]()
                let temp = NSString(format:"%p",list!) as String
                let name = "play#" + String(temp.suffix(3))
                selectedPlaylist?.value = list
                selectedPlaylist?.key = name
                playlistArrayController.addObject(selectedPlaylist!)
                tableView.scrollRowToVisible(row)
                playlistTableView.reloadData()
            }
            tableView.selectRowIndexes(IndexSet.init(integer: row), byExtendingSelection: false)

            for index in selectedRowIndexes! {
                playitemArrayController.addObject(items[index])
            }
            tableView.endUpdates()
        }
        else

        //    We have a Finder drag-n-drop of file or location URLs ?
        if let items: Array<AnyObject> = pasteboard.readObjects(forClasses: [NSURL.classForCoder()], options: options) as Array<AnyObject>? {
            var play = playlistArrayController.selectedObjects.first as? NSDictionaryControllerKeyValuePair
            let isSandboxed = appDelegate.isSandboxed()
            var okydoKey = false
            
            if (play == nil) {
                play = playlistArrayController.newObject() as NSDictionaryControllerKeyValuePair
                play?.value = Array <PlayItem>()
            
                playlistArrayController.addObject(play!)
                
                DispatchQueue.main.async {
                    self.playlistTableView.scrollRowToVisible(self.playlists.count - 1)
                }
            }
            else
            {
                okydoKey = true
            }
            
            for itemURL in items {
                var fileURL : URL? = (itemURL as AnyObject).filePathURL
                let dc = NSDocumentController.shared()
                var item: PlayItem?

                //  Resolve alias before storing bookmark
                if let original = (fileURL! as NSURL).resolvedFinderAlias() { fileURL = original }
                
                // Capture playlist name from origin folder of 1st item
                if !okydoKey {
                    let spec = fileURL?.deletingLastPathComponent
                    let head = spec!().absoluteString
                    play?.key = head
                    okydoKey = true
                }
                //  If we already know this url use its settings
                if let doc = dc.document(for: fileURL!) {
                    item = (doc as! Document).playitem()
                }
                else
                if let lists = UserDefaults.standard.dictionary(forKey: UserSettings.Playitems.default),
                    let playitem: PlayItem = lists[(fileURL?.absoluteString)!] as? PlayItem {
                    item = playitem
                }
                else
                {
                    if isSandboxed != appDelegate.storeBookmark(url: fileURL! as URL) {
                        Swift.print("Yoink, unable to sandbox \(String(describing: fileURL)))")
                    }

                    let path = fileURL!.absoluteString//.stringByRemovingPercentEncoding
                    let attr = appDelegate.metadataDictionaryForFileAt((fileURL?.path)!)
                    let time = attr?[kMDItemDurationSeconds] as! Double
                    let fuzz = (itemURL as AnyObject).deletingPathExtension!!.lastPathComponent as NSString
                    let name = fuzz.removingPercentEncoding
                    item = PlayItem(name:name!,
                                    link:URL.init(string: path)!,
                                    time:time,
                                    rank:(playitemArrayController.arrangedObjects as AnyObject).count + 1)
                }
                
                //  Refresh time,rect as needed
                item?.refresh()
                
                if (row+newIndexOffset) < (playitemArrayController.arrangedObjects as AnyObject).count {
                    playitemArrayController.insert(item as Any, atArrangedObjectIndex: row + newIndexOffset)
                    if dropOperation == .on {
                        //  We've shifted so remove old item at new location
                        playitemArrayController.remove(atArrangedObjectIndex: row+newIndexOffset+1)
                    }
                }
                else
                {
                    playitemArrayController.addObject(item as Any)
                }
                newIndexOffset += 1
            }
            
            // Try to pick off whatever they sent us
            if items.count == 0 {
                for element in pasteboard.pasteboardItems! {
                    for elementType in element.types {
                        let elementItem = element.string(forType:elementType)
                        var item: PlayItem?
                        var url: URL?
                        
                        //  Use first playlist name 
                        if !okydoKey { play?.key = elementType }

                        switch (elementType) {
                        case "public.url"://kUTTypeURL
                            url = URL(string: elementItem!)
                            break
                        case "public.file-url"://kUTTypeFileURL
                            url = URL(string: elementItem!)?.standardizedFileURL
                            break
                        case "com.apple.finder.node":
                            continue // handled as public.file-url
                        default:
                            Swift.print("type \(elementType) \(elementItem!)")
                            continue
                        }
                        
                        //  Resolve finder alias
                        if let original = (url! as NSURL).resolvedFinderAlias() { url = original }
                        
                        if isSandboxed != appDelegate.storeBookmark(url: url!) {
                            Swift.print("Yoink, unable to sandbox \(String(describing: url)))")
                        }
                        
                        //  If item is in our playitems cache use it
                        if let lists = UserDefaults.standard.dictionary(forKey: UserSettings.Playitems.default),
                            let playitem: PlayItem = lists[(url?.absoluteString)!] as? PlayItem {
                            item = playitem
                        }
                        else
                        {
                            let attr = appDelegate.metadataDictionaryForFileAt((url?.path)!)
                            let time = attr?[kMDItemDurationSeconds] as? TimeInterval ?? 0.0
                            let fuzz = url?.deletingPathExtension().lastPathComponent
                            let name = fuzz?.removingPercentEncoding
                            item = PlayItem(name: name!,
                                            link: url!,
                                            time: time,
                                            rank: (playitemArrayController.arrangedObjects as AnyObject).count + 1)
                        }
                        
                        //  Refresh time,rect as needed
                        item?.refresh()

                        if (row+newIndexOffset) < (playitemArrayController.arrangedObjects as AnyObject).count {
                            playitemArrayController.insert(item as Any, atArrangedObjectIndex: row + newIndexOffset)
                            if dropOperation == .on {
                                //  We've shifted so remove old item at new location
                                playitemArrayController.remove(atArrangedObjectIndex: row+newIndexOffset+1)
                            }
                        }
                        else
                        {
                            playitemArrayController.addObject(item as Any)
                        }
                        newIndexOffset += 1
                    }
                }
            }
            
            DispatchQueue.main.async {
                let rows = IndexSet.init(integersIn: NSMakeRange(row, newIndexOffset).toRange() ?? 0..<0)
                self.playitemTableView.selectRowIndexes(rows, byExtendingSelection: false)
            }
            
            if isSandboxed != appDelegate.saveBookmarks() {
                Swift.print("Yoink, unable to save bookmarks")
            }
        }
        else
        {
            Swift.print("acceptDrop? \(info)")
            return false
        }
        return true
    }

}
