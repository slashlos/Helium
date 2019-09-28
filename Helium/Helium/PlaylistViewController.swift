//
//  PlaylistViewController.swift
//  Helium
//
//  Created by Carlos D. Santiago on 2/15/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//
//  Kudos to Nate Thompson: Using Drag and Drop with NSTableview
//  https://www.natethompson.io/2019/03/23/nstableview-drag-and-drop.html

import Foundation
import AVFoundation
import AudioToolbox

class PlayTableView : NSTableView {
    var appDelegate : AppDelegate {
        get {
            return NSApp.delegate as! AppDelegate
        }
    }
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers! == String(Character(UnicodeScalar(NSEvent.SpecialKey.delete.rawValue)!)) ||
           event.charactersIgnoringModifiers! == String(Character(UnicodeScalar(NSEvent.SpecialKey.deleteForward.rawValue)!)) {
            
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
        let delegate = self.delegate as! PlaylistViewController
        let arrayController = [delegate.playlistArrayController,delegate.playitemArrayController][self.tag]!
        let objects = arrayController.arrangedObjects as! [NSPasteboardWriting]
        let indexSet = self.selectedRowIndexes
        var items = [NSDraggingItem]()
        
        for index in indexSet {
            let dragImage = (delegate.view.window?.windowController?.document as! Document).displayImage!
            let item = NSDraggingItem.init(pasteboardWriter: objects[index])
            item.setDraggingFrame(self.rect(ofRow: index), contents: dragImage)
            item.draggingFrame = self.rect(ofRow: index)
            items.append(item)
        }
        self.beginDraggingSession(with: items, event: event, source: self)
    }

    override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    override func dragImageForRows(with dragRows: IndexSet, tableColumns: [NSTableColumn], event dragEvent: NSEvent, offset dragImageOffset: NSPointPointer) -> NSImage {
        return NSApp.applicationIconImage.resize(w: 32, h: 32)
    }
    override func draggingEntered(_ info: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = info.draggingPasteboard
        
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly.rawValue]) {
            return .copy
        }
        return .copy
    }
    func tableViewColumnDidResize(notification: NSNotification ) {
        // Pay attention to column resizes and aggressively force the tableview's cornerview to redraw.
        self.cornerView?.needsDisplay = true
    }
    override func becomeFirstResponder() -> Bool {
        let notif = Notification(name: Notification.Name(rawValue: "NSTableViewSelectionDidChange"), object: self, userInfo: nil)
        (self.delegate as! PlaylistViewController).tableViewSelectionDidChange(notif)
        return true
    }
}

class PlayItemCornerButton : NSButton {
}

class PlayHeaderView : NSTableHeaderView {
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
            item.state = (state ? .off : .on)
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

class PlaylistViewController: NSViewController,NSTableViewDataSource,NSTableViewDelegate,NSMenuDelegate,NSWindowDelegate {

    @objc @IBOutlet weak var playlistArrayController: NSArrayController!
    @objc @IBOutlet weak var playitemArrayController: NSArrayController!

    @objc @IBOutlet weak var playlistTableView: PlayTableView!
    @objc @IBOutlet weak var playitemTableView: PlayTableView!
    @objc @IBOutlet weak var playlistSplitView: NSSplitView!

    //  we are managing the globals playlist, which includes app delegate histories
    var isGlobalPlaylist : Bool = false
    
    //  cache playlists read and saved to defaults
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    var defaults = UserDefaults.standard
    
    var shiftKeyDown : Bool {
        get {
            return (NSApp.delegate as! AppDelegate).shiftKeyDown
        }
    }
    var menuIconName : String {
        get {
            if shiftKeyDown {
                return "NSActionTemplate"
            }
            else
            {
                return "NSRefreshTemplate"
            }
        }
    }
    @objc @IBOutlet weak var cornerImage : NSImage! {
        get {
            return NSImage.init(imageLiteralResourceName: self.menuIconName)
        }
        set (value) {
            
        }
    }
    
	@objc @IBOutlet weak var cornerButton : PlayItemCornerButton!
	@objc @IBAction func cornerAction(_ sender: Any) {
        // Renumber playlist items via array controller
        playitemTableView.beginUpdates()
        
        //  True - prune duplicates & publish, false resequence
        switch shiftKeyDown {
        case true:
            var seen = [String:PlayItem]()
            for (row,item) in (playitemArrayController.arrangedObjects as! [PlayItem]).enumerated().reversed() {
                if item.plays == 0 { item.plays = 1}
                if seen[item.name] == nil {
                    seen[item.name] = item
                }
                else
                {
                    //  always take first date of items
                    if let hist = seen[item.name] {
                        hist.date = min(hist.date,item.date)
                        hist.plays += item.plays
                    }
                    self.remove(item: item, atIndex: row)
                }
            }
            
            //  publish seen plays across playlists
            for  (name,hist) in seen {
                Swift.print("update '\(name)' -> \(hist)");
                for play in playlists {
                    if let item = play.list.link(hist.link.absoluteString), item.plays != hist.plays {
                        item.plays = hist.plays
                    }
                }
            }
            self.cornerButton.setNeedsDisplay()
            break
            
        case false:
            for (row,item) in (playitemArrayController.arrangedObjects as! [PlayItem]).enumerated() {
                if let undo = self.undoManager {
                    undo.registerUndo(withTarget: self, handler: { [oldValue = item.rank] (PlaylistViewController) -> () in
                        (item as AnyObject).setValue(oldValue, forKey: "rank")
                        if !undo.isUndoing {
                            undo.setActionName(String.init(format: "Reseq %@", "rank"))
                        }
                    })
                }
                item.rank = row + 1
            }
        }
        playitemTableView.endUpdates()
	}
    @objc @IBOutlet weak var cornerTooltip : NSString! {
        get {
            if shiftKeyDown {
                return "Consolidate"
            }
            else
            {
                return "Resequence"
            }
        }
        set (value) {
            
        }
    }

	//  delegate keeps our parsing dict to keeps names unique
    //  PlayList.name.willSet will track changes in playdicts
    @objc dynamic var playlists = [PlayList]()
    @objc dynamic var playCache = [PlayList]()
    
    //  MARK:- Undo
    //  keys to watch for undo: PlayList and PlayItem
    var listIvars : [String] {
        get {
            return [k.name, k.list]
        }
    }
    var itemIvars : [String] {
        get {
            return [k.name, k.link, k.time, k.plays, k.rank, k.rect, k.label, k.hover, k.alpha, k.trans, k.temp]
        }
    }

    internal func observe(_ item: AnyObject, keyArray keys: [String], observing state: Bool) {
        switch state {
        case true:
            for keyPath in keys {
                item.addObserver(self, forKeyPath: keyPath, options: [.old,.new], context: nil)
            }
            break
        case false:
            for keyPath in keys {
                item.removeObserver(self, forKeyPath: keyPath)
            }
        }
        //Swift.print(item, (state ? "YES" : "NO"))
    }
    
    //  Start or forget observing any changes
    var _observingState : Bool = false
    @objc dynamic var observing : Bool {
        get {
            return _observingState
        }
        set (state) {
            guard state != _observingState else { return }
            if state {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(shiftKeyDown(_:)),
                    name: NSNotification.Name(rawValue: "shiftKeyDown"),
                    object: nil)
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(optionKeyDown(_:)),
                    name: NSNotification.Name(rawValue: "optionKeyDown"),
                    object: nil)
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(gotNewHistoryItem(_:)),
                    name: NSNotification.Name(rawValue: k.item),
                    object: nil)
            }
            else
            {
                NotificationCenter.default.removeObserver(self)
            }

            self.observe(self, keyArray: [k.playlists], observing: state)
            for playlist in playlists {
                self.observe(playlist, keyArray: listIvars, observing: state)
                for item in playlist.list {
                    self.observe(item, keyArray: itemIvars, observing: state)
                }
            }
            
            _observingState = state
        }
    }
    
    @objc internal func shiftKeyDown(_ note: Notification) {
        let keyPaths = ["cornerImage","cornerTooltip"]
        for keyPath in (keyPaths)
        {
            self.willChangeValue(forKey: keyPath)
        }
        
        for keyPath in (keyPaths)
        {
            self.didChangeValue(forKey: keyPath)
        }
    }
    
    @objc internal func optionKeyDown(_ note: Notification) {
        let keyPaths = ["playTooltip"]
        for keyPath in (keyPaths)
        {
            self.willChangeValue(forKey: keyPath)
        }
        
        for keyPath in (keyPaths)
        {
            self.didChangeValue(forKey: keyPath)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let oldValue = change?[NSKeyValueChangeKey(rawValue: "old")]
        let newValue = change?[NSKeyValueChangeKey(rawValue: "new")]

        switch keyPath {
        
        case k.playlists?, k.list?:
            //  arrays handled by [add,remove]<List,Play> callback closure block

            if (newValue != nil) {
                Swift.print(String.init(format: "%p:%@ new %@", object! as! CVarArg, keyPath!, newValue as! CVarArg))
            }
            else
            if (oldValue != nil) {
                Swift.print(String.init(format: "%p:%@ old %@", object! as! CVarArg, keyPath!, oldValue as! CVarArg))
            }
            else
            {
                Swift.print(String.init(format: "%p:%@ unk %@", object! as! CVarArg, keyPath!, "*no* values?"))
            }
            break
            
        default:
            if let undo = self.undoManager {
                
                //  scalars handled here with its matching closure block
                undo.registerUndo(withTarget: self, handler: { [oldValue] (PlaylistViewController) -> () in
                    
                    (object as AnyObject).setValue(oldValue, forKey: keyPath!)
                    if !undo.isUndoing {
                        undo.setActionName(String.init(format: "Edit %@", keyPath!))
                    }
                })
                Swift.print(String.init(format: "%@ %@ -> %@", keyPath!, oldValue as! CVarArg, newValue as! CVarArg))
            }
            
            // playlist names must be unique
            if let play = (object as? PlayList), keyPath == k.name,  playlists.list(newValue as! String).count > 1 {
                Swift.print("duplicate playlist.name \(newValue as! String)")
                play.name = oldValue as! String
                NSSound(named: "Sosumi")?.play()
            }
            
            // Save history info which might have changed
            if let play = (object as? PlayList), keyPath == k.name, play == historyCache {
                if UserSettings.HistoryName.value == oldValue as? String {
                    UserSettings.HistoryName.value = newValue as! String
                }
            }
        }
        
        if let doc = self.view.window?.windowController?.document {
            doc.updateChangeCount(.changeDone)
        }
    }
    
    //  A bad (duplicate) value was attempted
    @objc fileprivate func badPlayLitName(_ notification: Notification) {
        DispatchQueue.main.async {
            self.playlistTableView.reloadData()
            NSSound(named: "Sosumi")?.play()
         }
    }
    
    var canRedo : Bool {
        if let redo = self.undoManager  {
            return redo.canRedo
        }
        else
        {
            return false
        }
    }
    @objc @IBAction func redo(_ sender: Any) {
        if let undo = self.undoManager, undo.canRedo {
            undo.redo()
            Swift.print("redo:");
        }
    }
    
    var canUndo : Bool {
        if let undo = self.undoManager  {
            return undo.canUndo
        }
        else
        {
            return false
        }
    }
    
    @objc @IBAction func undo(_ sender: Any) {
        if let undo = self.undoManager, undo.canUndo {
            undo.undo()
            Swift.print("undo:");
        }
    }
    
    //  MARK:- View lifecycle
    fileprivate func setupHiddenColumns(_ tableView: NSTableView, hideit: [String]) {
        let table : String = tableView.identifier!.rawValue
        for col in tableView.tableColumns {
            let column = col.identifier.rawValue
            let pref = String(format: "hide.%@.%@", table, column)
            var isHidden = false
            
            //    If have a preference, honor it, else apply hidden default
            if defaults.value(forKey: pref) != nil
            {
                isHidden = defaults.bool(forKey: pref)
                hiddenColumns[pref] = String(isHidden)
            }
            else
            if hideit.contains(column)
            {
                isHidden = true
            }
            col.isHidden = isHidden
        }
    }
    
    override func viewDidLoad() {
        playlistTableView.registerForDraggedTypes([.list,.data,.fileURL,.filePromise,.files,.string,.URL])
        playitemTableView.registerForDraggedTypes([.item,.data,.fileURL,.filePromise,.files,.string,.URL])

        playlistTableView.doubleAction = #selector(playPlaylist(_:))
        playitemTableView.doubleAction = #selector(playPlaylist(_:))
        
        //  Restore hidden columns in tableviews using defaults
        setupHiddenColumns(playlistTableView, hideit: ["date","tally"])
        setupHiddenColumns(playitemTableView, hideit: ["date","link","plays","rect","label","hover","alpha","trans"])
    }

    var historyCache: PlayList = PlayList.init(name: UserSettings.HistoryName.value,
                                                 list: [PlayItem]())
    
    override func viewWillAppear() {
        //  Leave non-global extractions contents intact
        if isGlobalPlaylist {
            
            //  Load global pp delegate keep history
            self.restorePlaylists(nil)
            
            //  Prune duplicate history entries
            while let oldHistory = playlists.name(UserSettings.HistoryName.value)
            {
                playlistArrayController.removeObject(oldHistory)
            }
            historyCache = PlayList.init(name: UserSettings.HistoryName.value,
                                         list: appDelegate.histories)
            
            playlistArrayController.addObject(historyCache)
        }
        else
        if let doc = self.webViewController?.document, let url = doc.fileURL
        {
            //  Set window titleView with url as tooltip like .helium type
            if let titleView = self.view.window?.standardWindowButton(.closeButton)?.superview {
                titleView.toolTip = url.absoluteString.removingPercentEncoding
            }
            
            //  Start us of cleanly re: change count
            doc.updateChangeCount(.changeCleared)
            self.undoManager?.removeAllActions()
        }
        
        // cache our list before editing
        playCache = playlists
        
        //  Reset split view dimensions
        self.playlistSplitView.setPosition(120, ofDividerAt: 0)
        
        //  Watch for bad (duplicate) playlist names
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(badPlayLitName(_:)),
            name: NSNotification.Name(rawValue: "BadPlayListName"),
            object: nil)

        //  Start observing any changes
        self.observing = true
        
        //  Pin the playitem corner view to the header and scroll bar views
        guard let cornerView = playitemTableView.cornerView else { return }
		cornerView.addSubview(cornerButton)
        cornerButton.center(cornerView)
    }
    
    override func viewWillDisappear() {
        //  Stop observing any changes
        self.observing = false
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    //  MARK:- Playlist Actions
    //
    //  internal are also used by undo manager callback and by IBActions
    //
    //  Since we do *not* undo movements, we remove object *not* by their index
    //  but use their index to update the controller scrolling only initially.

    //  "Play" items are individual PlayItem items, part of a playlist
    internal func add(item: PlayItem, atIndex p_index: Int) {
        var index = p_index
        if let undo = self.undoManager {
            undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": index] as [String : Any]] (PlaylistViewController) -> () in
                self.remove(item: oldVals["item"] as! PlayItem, atIndex: oldVals["index"] as! Int)
                if !undo.isUndoing {
                    undo.setActionName("Add PlayItem")
                }
            })
        }
        observe(item, keyArray: itemIvars, observing: true)
        if index > 0 && index < (playitemArrayController.arrangedObjects as! [PlayItem]).count {
            playitemArrayController.insert(item, atArrangedObjectIndex: index)
        }
        else
        {
            playitemArrayController.addObject(item)
            playitemArrayController.rearrangeObjects()
            let row = playitemTableView.selectedRow
            if row >= 0 {
                index = row
            }
            else
            {
                index = (playitemArrayController.arrangedObjects as! [PlayItem]).count
            }
        }
        DispatchQueue.main.async {
            self.playitemTableView.scrollRowToVisible(index)
        }
    }
    internal func remove(item: PlayItem, atIndex p_index: Int) {
        var index = p_index
        if let undo = self.undoManager {
            undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": index] as [String : Any]] (PlaylistViewController) -> () in
                self.add(item: oldVals["item"] as! PlayItem, atIndex: oldVals["index"] as! Int)
                if !undo.isUndoing {
                    undo.setActionName("Remove PlayItem")
                }
            })
        }
        observe(item, keyArray: itemIvars, observing: false)
        playitemArrayController.removeObject(item)

        let row = playitemTableView.selectedRow
        if row >= 0 {
            index = row
        }
        else
        {
            index = max(0,min(index,(playitemArrayController.arrangedObjects as! [PlayItem]).count))
        }
        DispatchQueue.main.async {
            self.playitemTableView.scrollRowToVisible(index)
        }
    }

    //  "List" items are PlayList objects
    internal func add(list item: PlayList, atIndex p_index: Int) {
        var index = p_index
        if let undo = self.undoManager {
            undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": index] as [String : Any]] (PlaylistViewController) -> () in
                self.remove(list: oldVals["item"] as! PlayList, atIndex: oldVals["index"] as! Int)
                if !undo.isUndoing {
                    undo.setActionName("Add PlayList")
                }
            })
        }
        observe(item, keyArray: listIvars, observing: true)
        if index > 0 && index < (playlistArrayController.arrangedObjects as! [PlayItem]).count {
            playlistArrayController.insert(item, atArrangedObjectIndex: index)
        }
        else
        {
            playlistArrayController.addObject(item)
            playlistArrayController.rearrangeObjects()
            index = (playlistArrayController.arrangedObjects as! [PlayItem]).count - 1
        }
        DispatchQueue.main.async {
            self.playlistTableView.scrollRowToVisible(index)
        }
    }
    internal func remove(list item: PlayList, atIndex index: Int) {
        if let undo = self.undoManager {
            undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": index] as [String : Any]] (PlaylistViewController) -> () in
                self.add(list: oldVals["item"] as! PlayList, atIndex: oldVals["index"] as! Int)
                if !undo.isUndoing {
                    undo.setActionName("Remove PlayList")
                }
            })
        }
        observe(item, keyArray: listIvars, observing: false)
        playlistArrayController.removeObject(item)
        
        DispatchQueue.main.async {
            self.playlistTableView.scrollRowToVisible(index)
        }
    }

    //  published actions - first responder tells us who called
    @objc @IBAction func addPlaylist(_ sender: AnyObject) {
        let whoAmI = self.view.window?.firstResponder
        
        //  We want to add to existing play item list
        if whoAmI == playlistTableView {
            let item = PlayList()
            
            self.add(list: item, atIndex: -1)
        }
        else
        if let selectedPlaylist = playlistArrayController.selectedObjects.first as? PlayList {
            let list: Array<PlayItem> = selectedPlaylist.list.sorted(by: { (lhs, rhs) -> Bool in
                return lhs.rank < rhs.rank
            })
            let item = PlayItem()
            item.rank = (list.count > 0) ? (list.last?.rank)! + 1 : 1

            self.add(item: item, atIndex: -1)
        }
        else
        {
            Swift.print("firstResponder: \(String(describing: whoAmI))")
        }
    }
    @objc @IBOutlet weak var addButtonTooltip : NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder
            
            if whoAmI == playlistTableView || whoAmI == nil {
                return "Add playlist"
            }
            else
            {
                return "Add playitem"
            }
        }
        set (value) {
            
        }
	}

    @objc @IBAction func removePlaylist(_ sender: AnyObject) {
        let whoAmI = self.view.window?.firstResponder

        if playlistTableView == whoAmI {
            for item in (playlistArrayController.selectedObjects as! [PlayList]).reversed() {
                let index = (playlistArrayController.arrangedObjects as! [PlayList]).firstIndex(of: item)
                self.remove(list: item, atIndex: index!)
            }
            return
        }
            
        if playitemTableView == whoAmI {
            for item in (playitemArrayController.selectedObjects as! [PlayItem]).reversed() {
                let index = (playitemArrayController.arrangedObjects as! [PlayItem]).firstIndex(of: item)
                self.remove(item: item, atIndex: index!)
            }
            return
        }
        
        if playitemArrayController.selectedObjects.count > 0 {
            for item in (playitemArrayController.selectedObjects as! [PlayItem]) {
                let index = (playitemArrayController.arrangedObjects as! [PlayItem]).firstIndex(of: item)
                self.remove(item: item, atIndex: index!)
            }
        }
        else
        if playlistArrayController.selectedObjects.count > 0 {
            for item in (playlistArrayController.selectedObjects as! [PlayList]) {
                let index = (playlistArrayController.arrangedObjects as! [PlayList]).firstIndex(of: item)
                self.remove(list: item, atIndex: index!)
            }
        }
        else
        {
            Swift.print("firstResponder: \(String(describing: whoAmI))")
            NSSound(named: "Sosumi")?.play()
        }
    }
    @objc @IBOutlet weak var removeButtonTooltip: NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder
            
            if whoAmI == playlistTableView || whoAmI == nil {
                if playlistArrayController.selectedObjects.count == 0 {
                    return "Remove all playlists"
                }
                else
                {
                    return "Remove selected playlist(s)"
                }
            }
            else
            {
                if playitemArrayController.selectedObjects.count == 0 {
                    return "Remove playitem playitem(s)"
                }
                else
                {
                    return "Remove selected playitems(s)"
                }
            }
        }
        set (value) {
            
        }
	}

    // Our playlist panel return point if any
    var webViewController: WebViewController? = nil
    
    internal func play(_ sender: AnyObject, items: Array<PlayItem>, maxSize: Int) {
        let viewOptions = appDelegate.newViewOptions
        var firstHere : Bool = false
        
        //  Unless we're the standalone helium playlist window dismiss all
        if !(self.view.window?.isKind(of: HeliumPanel.self))! {
            /// dismiss whatever got us here
            super.dismiss(sender)

            //  If we were run modally as a window, close it
            //  current window to be reused for the 1st item
            if sender.isKind(of: NSTableView.self),
                let ppc = self.view.window?.windowController, ppc.isKind(of: PlaylistPanelController.self) {
                NSApp.abortModal()
                ppc.window?.orderOut(sender)
            }
            else
            {
                //  unless we want new windows/tabs instead
                firstHere = viewOptions == sameWindow
            }
        }
        
        //  Try to restore item at its last known location
        for (i,item) in (items.enumerated()).prefix(maxSize) {
            if firstHere {
                if let first = NSApp.keyWindow {
                    if let wvc = first.contentViewController as? WebViewController {
                        wvc.webView.next(url: item.link)
                        firstHere = false
                    }
                }
                if !firstHere { continue }
            }

            if appDelegate.doOpenFile(fileURL: item.link) {
                print(String(format: "%3d %3d %@", i, item.rank, item.name))
            }
            
            //  2nd item and on get a new view window
            appDelegate.newViewOptions.insert(.w_view)
        }
    }
    
    //  MARK:- IBActions
    @objc @IBAction func playPlaylist(_ sender: AnyObject) {
        appDelegate.newViewOptions = appDelegate.getViewOptions
        
        //  first responder tells us who called so dispatch
        let whoAmI = self.view.window?.firstResponder

        //  Quietly, do not exceed program / user specified throttle
        let throttle = UserSettings.PlaylistThrottle.value

        //  Our rank sorted list from which we'll take last 'throttle' to play
        var list = Array<PlayItem>()

        if playitemTableView == whoAmI {
            Swift.print("We are in playitemTableView")
            list.append(contentsOf: playitemArrayController.selectedObjects as! Array<PlayItem>)
        }
        else
        if playlistTableView == whoAmI {
            Swift.print("We are in playlistTableView")
            for selectedPlaylist in (playlistArrayController.selectedObjects as? [PlayList])! {
                list.append(contentsOf: selectedPlaylist.list )
            }
        }
        else
        {
            Swift.print("firstResponder: \(String(describing: whoAmI))")
            NSSound(named: "Sosumi")?.play()
            return
        }
        
        //  Do not exceed program / user specified throttle
        if list.count > throttle {
            let message = String(format: "Limiting playlist(s) %ld items to throttle?", list.count)
            let infoMsg = String(format: "User defaults: %@ = %ld",
                                 UserSettings.PlaylistThrottle.keyPath,
                                 throttle)
            
            appDelegate.sheetOKCancel(message, info: infoMsg,
                                      acceptHandler: { (button) in
                                        if button == NSApplication.ModalResponse.alertFirstButtonReturn {
                                            self.appDelegate.newViewOptions = self.appDelegate.getViewOptions
                                            self.play(sender, items:list, maxSize: throttle)
                                        }
            })
        }
        else
        {
            play(sender, items:list, maxSize: list.count)
        }
    }
    @objc @IBOutlet weak var playButtonTooltip: NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder
            
            if whoAmI == playlistTableView || whoAmI == nil {
                if playlistArrayController.selectedObjects.count == 0 {
                    return "Play all playlists"
                }
                else
                {
                    return "Play selected playlist(s)"
                }
            }
            else
            {
                if playitemArrayController.selectedObjects.count == 0 {
                    return "Play playlist playitem(s)"
                }
                else
                {
                    return "Play selected playitems(s)"
                }
            }
        }
        set (value) {
            
        }
	}

    // Return notification from webView controller
    @objc func gotNewHistoryItem(_ note: Notification) {
        guard let playlist = playlistArrayController.selectedObjects.first as? PlayList else { return }

        //  If history is current playplist, add to the history
        if historyCache.name == playlist.name {
            self.add(item: note.object as! PlayItem, atIndex: -1)
        }
    }

    @objc @IBOutlet weak var restoreButton: NSButton!
    @objc @IBOutlet weak var restoreButtonTooltip: NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder

            if whoAmI == playlistTableView || whoAmI == nil {
                if playlistArrayController.selectedObjects.count == 0 {
                    return "Restore all playlists"
                }
                else
                {
                    return "Restore selected playlist(s)"
                }
            }
            else
            {
                if playitemArrayController.selectedObjects.count == 0 {
                    return "Restore playlist playitem(s)"
                }
                else
                {
                    return "Restore selected playitems(s)"
                }
            }
        }
        set (value) {
            
        }
	}
    @objc @IBAction func restorePlaylists(_ sender: NSButton?) {
        let whoAmI = self.view.window?.firstResponder

        //  We want to restore to existing play item or list or global playlists
        if whoAmI == playlistTableView || whoAmI == nil {
            Swift.print("restore playlist(s)")
            
            let playArray = playlistArrayController.selectedObjects as! [PlayList]
            
            //  If no playlist(s) selection restore from defaults
            if playArray.count == 0 {
                if let plists = defaults.dictionary(forKey: k.playlists) {
                    playlists = [PlayList]()
                    for (name,plist) in plists {
                        guard let items = plist as? [Dictionary<String,Any>] else {
                            let item = PlayItem.init(with: (plist as? Dictionary<String,Any>)!)
                            let playlist = PlayList()
                            playlist.list.append(item)
                            playlists.append(playlist)
                            continue
                        }
                        var list : [PlayItem] = [PlayItem]()
                        for plist in items {
                            let item = PlayItem.init(with: plist)
                            list.append(item)
                        }
                        let playlist = PlayList.init(name: name, list: list)
                        playlistArrayController.addObject(playlist)
                    }
                }
            }
            else
            {
                for playlist in playArray {
                    if let plists = defaults.dictionary(forKey: playlist.name as String) {
                        
                        //  First update matching playitems
                        playlist.update(with: plists)
                        
                        //  Second, using plist, add playitems not found in playlist
                        if let value = plists[k.list], let dicts = value as? [[String:Any]]  {
                            for dict in dicts {
                                if !playlist.list.has(dict[k.link] as! String) {
                                    let item = PlayItem.init(with: dict)
                                    self.add(item: item, atIndex: -1)
                                }
                            }
                            
                            //  Third remove playitems not found in plist
                            for playitem in playlist.list {
                                var found = false

                                for dict in dicts {
                                    if playitem.link.absoluteString == (dict[k.link] as? String) { found = true; break }
                                }

                                if !found {
                                    remove(item: playitem, atIndex: -1)
                                }
                            }
                        }
                    }
                }
            }
        }
        else
        {
            Swift.print("restore playitems(s)")
            
            var itemArray = playitemArrayController.selectedObjects as! [PlayItem]
            
            if itemArray.count == 0 {
                itemArray = playitemArrayController.arrangedObjects as! [PlayItem]
            }
            
            for playitem in itemArray {
                if let dict = defaults.dictionary(forKey: playitem.link.absoluteString) {
                    playitem.update(with: dict)
                }
            }
        }
    }

    @objc @IBOutlet weak var saveButton: NSButton!
    @objc @IBOutlet weak var saveButtonTooltip: NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder
            
            if whoAmI == playlistTableView || whoAmI == nil {
                if playlistArrayController.selectedObjects.count == 0 {
                    return "Save all playlists"
                }
                else
                {
                    return "Save selected playlist(s)"
                }
            }
            else
            {
                if playitemArrayController.selectedObjects.count == 0 {
                    return "Save playlist playitem(s)"
                }
                else
                {
                    return "Save selected playitems(s)"
                }
            }
        }
        set (value) {
            
        }
	}
    
    @objc @IBAction func saveDocument(_ sender: AnyObject) {
        Swift.print("saveDocument");
        if let doc = self.view.window?.windowController?.document {
            (doc as! Document).save(sender)
            
            //  We would throw if any errors so clear redo now
            if 0 == doc.changeCount {
                self.undoManager?.removeAllActions()
            }
        }
    }
    
    @objc @IBAction func savePlaylists(_ sender: AnyObject) {
        let whoAmI = self.view.window?.firstResponder
        
        //  We want to save to existing play item or list
        if whoAmI == playlistTableView {
            let saveArray = playlistArrayController.selectionIndexes.count == 0
                ? playlistArrayController.arrangedObjects as! [PlayList]
                : playlistArrayController.selectedObjects as! [PlayList]
            var names = Array<String>()
            
            for playlist in saveArray {
                defaults.set(playlist.dictionary(), forKey: playlist.name as String)
                names.append(String(format: "%@: %d", playlist.name, playlist.list.count))
                
                //  propagate history to our delegate
                if playlist == historyCache {
                    appDelegate.histories = historyCache.list
                }
            }
            
            //  If no selection we saved *all* to global to be restored
            if saveArray.count == playlists.count {
// TODO: convert playlists to dictionary
//                defaults.set(playlists.allKeys, forKey: k.playlists)
                var names = Array<String>()
                
                for playlist in saveArray {
                    names.append(playlist.name)
                }
                defaults.set(names, forKey: k.playlists)

                appDelegate.userAlertMessage("Saved playlists", info: "Playlists globals updated")
            }
            else
            {
                appDelegate.userAlertMessage("Saved playlists(\(names.count))",
                    info: (names.count > 8) ? String(format: "%d - too many to list",names.count) : (names.count > 5) ? names.list : names.listing)
            }
        }
        else
        {
            var saveArray = playitemArrayController.selectedObjects as! [PlayItem]
            var names = Array<String>()

            if saveArray.count == 0 {
                saveArray = playitemArrayController.arrangedObjects as! [PlayItem]
            }

            for playitem in saveArray {
                defaults.set(playitem.dictionary(), forKey: playitem.link.absoluteString)
                names.append(playitem.name)
            }
            appDelegate.userAlertMessage("Saved playitems(\(names.count))",
                info: (names.count > 8) ? String(format: "%d - too many to list",names.count) : (names.count > 5) ? names.list : names.listing)
        }

        defaults.synchronize()
    }
    
    @objc @IBAction override func dismiss(_ sender: Any?) {
        super.dismiss(sender)
        
        //  If we were run as a window, close it
        if let plw = self.view.window, plw.isKind(of: PlaylistsPanel.self) {
            plw.orderOut(sender)
        }
        
        //  Save or go
        switch (sender! as AnyObject).tag == 0 {
            case true:
                // Save to the cache
                playCache = playlists
                
                // If we're global save that too
                if isGlobalPlaylist {
                    appDelegate.playlists = playlists
                }
                break
            case false:
                // Restore NON-HISTORY playlist(s) from cache
                if let historyIndex = playCache.firstIndex(of: historyCache) {
                    playCache.remove(at: historyIndex)
                }
                playlists = playCache
        }
    }

    @objc dynamic var hiddenColumns = Dictionary<String, Any>()
    @objc @IBAction func toggleColumnVisiblity(_ sender: NSMenuItem) {
        let col = sender.representedObject as! NSTableColumn
        let table : String = (col.tableView?.identifier)!.rawValue
        let column = col.identifier.rawValue
        let pref = String(format: "hide.%@.%@", table, column)
        let isHidden = !col.isHidden
        
        hiddenColumns.updateValue(String(isHidden), forKey: pref)
        defaults.set(isHidden, forKey: pref)
        col.isHidden = isHidden
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
        if (menuItem.representedObject as AnyObject).isKind(of: NSTableColumn.self)
        {
            return true
        }
        else
        {
            switch menuItem.title {
                
            default:
                menuItem.state = UserSettings.DisabledMagicURLs.value ? .off : .on
                break
            }
        }
        return true;
    }

    //  MARK:- Delegate

    //  We cannot alter a playitem once plays is non-zero; set to zero to alter
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        if tableView == playlistTableView {
            return true
        }
        else
        if tableView == playitemTableView, let item = playitemArrayController.selectedObjects.first {
            return (item as! PlayItem).plays == 0 || tableColumn?.identifier.rawValue != k.plays
        }
        else
        {
            return false
        }
    }
    /*
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = ([playlistArrayController,playitemArrayController][tableView.tag]?.arrangedObjects as! [AnyObject])[row]
        //let item = ((tableView.dataSource as! NSArrayController).arrangedObjects as! [AnyObject])[row]
        var view = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self)
        if view ==  nil {
            Swift.print("tag: \(tableView.tag) ident: \(tableColumn!.identifier.rawValue)")
            view = NSTableCellView.init()
            view?.identifier = tableColumn?.identifier
        }
        
        guard tableView.tag == 0 else { return view }

        guard isGlobalPlaylist, item.name == UserSettings.HistoryName.value,
            let identifier = tableColumn?.identifier,
            identifier.rawValue == k.name else { return view }

        if let cellView = view as? NSTableCellView {
            if tableView.selectedRowIndexes.intersection(IndexSet.init(integer: row)).count > 0 {
                cellView.textField?.font = .boldSystemFont(ofSize: -1)
                cellView.textField?.textColor = .white
            }
            else
            {
                cellView.textField?.font = .systemFont(ofSize: -1)
                cellView.textField?.textColor = .blue
            }
        }
        return view
    }
    */
    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        if tableView == playlistTableView
        {
            let play = (playlistArrayController.arrangedObjects as! [PlayList])[row]

            return play.tooltip as String
        }
        else
        if tableView == playitemTableView
        {
            let item = (playitemArrayController.arrangedObjects as! [PlayItem])[row]
            guard !shiftKeyDown else {
                return String(format: "%d play(s)", item.plays) }
            
            let temp = item.link.absoluteString

            if item.name == "search", let args = temp.split(separator: "=").last?.removingPercentEncoding
            {
                return args
            }
            else
            if let temp = temp.removingPercentEncoding
            {
                return temp
            }
        }
        return "no tip for you"
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        //  Alert tooltip changes when selection does in tableView
        let buttons = [ "add", "remove", "play", "restore", "save"]
        let tableView : NSTableView = notification.object as! NSTableView
        let hpc = tableView.delegate as! PlaylistViewController
//        Swift.print("change tooltips \(buttons)")
        for button in buttons {
            hpc.willChangeValue(forKey: String(format: "%@ButtonTooltip", button))
        }
        ;
        for button in buttons {
            hpc.didChangeValue(forKey: String(format: "%@ButtonTooltip", button))
        }
    }

    // MARK:- Drag-n-Drop
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        Swift.print("\(tableView.tag) writeRowsWith: \(rowIndexes.count)")
        if tableView == playlistTableView {
            let objects: [PlayList] = playlistArrayController.arrangedObjects as! [PlayList]
            var items: [NSPasteboardWriting] = [NSPasteboardWriting]()
            var promises = [String]()
 
            for index in rowIndexes {
                let item = objects[index]
                items.append(item)
                let dict = item.dictionary()
                let promise = dict.xmlString(withElement: item.className, isFirstElement: true)
                promises.append(promise)
            }
            
            //let data = NSKeyedArchiver.archivedData(withRootObject: items)
//            pboard.setPropertyList(items, forType: NSPasteboard.PasteboardType(rawValue: PlayList.className()))
            pboard.writeObjects(items)
            pboard.setPropertyList(promises, forType:NSPasteboard.PasteboardType.filePromise)
        }
        else
        {
            let objects: [PlayItem] = playitemArrayController.arrangedObjects as! [PlayItem]
            var items: [NSPasteboardWriting] = [NSPasteboardWriting]()
            var promises = [String]()
            
            for index in rowIndexes {
                let item = objects[index]
                items.append(item)
                let dict = item.dictionary()
                let promise = dict.xmlString(withElement: item.className, isFirstElement: true)
                promises.append(promise)
            }
            
            //let data = NSKeyedArchiver.archivedData(withRootObject: items)
//            pboard.setPropertyList(data, forType: NSPasteboard.PasteboardType(rawValue: PlayItem.className()))
            pboard.writeObjects(items)
            pboard.setPropertyList(promises, forType:NSPasteboard.PasteboardType.filePromise)
        }
        return true
    }
    
    var dragSequenceNo = 0
    func draggingUpdated(_ info: NSDraggingInfo) -> NSDragOperation {
        if dragSequenceNo != info.draggingSequenceNumber {
            let sourceTableView = info.draggingSource as? NSTableView
            let pboard: NSPasteboard = info.draggingPasteboard
            let items = pboard.pasteboardItems!

            Swift.print("\(String(describing: sourceTableView?.identifier)) draggingUpdate \(items.count) item(s)")

            appDelegate.newViewOptions = appDelegate.getViewOptions
            dragSequenceNo = info.draggingSequenceNumber
        }
        return .copy
    }

    func tableView(_ tableView: NSTableView, namesOfPromisedFilesDroppedAtDestination dropDestination: URL, forDraggedRowsWith indexSet: IndexSet) -> [String] {
        var dict = Dictionary<String,[Any]>()
        var names : [String] = [String]()
        let count = indexSet.count
        
        //	Always marshall an array regardless of count
        if tableView == playlistTableView {
            let objects: [PlayList] = playlistArrayController.arrangedObjects as! [PlayList]
            var promise : String!

            for (i,index) in indexSet.enumerated() {
                if i == 0 {
                    promise = String(format: "%@%@", objects[index].name,
                                     count > 2 ? String(format: "+%d", (count - 1)) : "")
                }
                let playlist = objects[index]
                var items: [Any] = [Any]()
                let name = playlist.name
                for item in playlist.list {
                    let dict = item.dictionary()
                    items.append(dict)
                }
                dict[name] = items
            }
            if let fileURL = NewFileURLForWriting(path: dropDestination.path, name: promise, type: k.h3w) {
                (dict as NSDictionary).write(to: fileURL, atomically: true)
                names.append(fileURL.absoluteString)
            }
        }
        else
        {
            let selection = playlistArrayController.selectedObjects.first as! PlayList
            let objects: [PlayItem] = playitemArrayController.arrangedObjects as! [PlayItem]
            let name = String(format: "%@(%ld)", selection.name, indexSet.count)
            var items: [AnyObject] = [AnyObject]()

            for index in indexSet {
                let item = objects[index]
                names.append(item.link.absoluteString)
                items.append(item.dictionary() as AnyObject)
            }
            
            if let fileURL = NewFileURLForWriting(path: dropDestination.path, name: name, type: k.h3w) {
                var dict = Dictionary<String,[AnyObject]>()
                dict[name] = items
                (dict as NSDictionary).write(to: fileURL, atomically: true)
            }
        }
        return names
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        let sourceTableView = info.draggingSource as? NSTableView

        Swift.print("source \(String(describing: sourceTableView?.identifier))")
        if dropOperation == .above {
            let pboard = info.draggingPasteboard;
            let options = [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true,
                           NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes : [kUTTypeMovie as String]] as [NSPasteboard.ReadingOptionKey : Any]
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
                        if track0.mediaType != AVMediaType.video
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
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let pasteboard = info.draggingPasteboard
        let options = [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true,
                       //NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes : [kUTTypeMovie as String],
                       NSPasteboard.ReadingOptionKey(rawValue: PlayList.className()) : true,
                       NSPasteboard.ReadingOptionKey(rawValue: PlayItem.className()) : true]
        let sourceTableView = info.draggingSource as? NSTableView
        let isSandboxed = appDelegate.isSandboxed()
        var play: PlayList? = nil
        var oldIndexes = [Int]()
        var oldIndexOffset = 0
        var newIndexOffset = 0
        var sandboxed = 0

        //  tableView is our destination; act depending on source
        tableView.beginUpdates()

        guard let items = info.draggingPasteboard.pasteboardItems else { return false }
        Swift.print("\(items.count) item(s)")

        // We have intra tableView drag-n-drop ?
        if tableView == sourceTableView {
            info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) {(draggingItem, index, stop) in

                if let str = (draggingItem.item as! NSPasteboardItem).string(forType: NSPasteboard.PasteboardType(rawValue: "public.data")), let index = Int(str) {
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
            }
        }
        else

        // We have inter tableView drag-n-drop ?
        // if source is a playlist, drag its items into the destination via copy
        // if source is a playitem, drag all items into the destination playlist
        // creating a new playlist item unless, we're dropping onto an existing.
        
        if sourceTableView == playlistTableView {
            let selectedRowIndexes = sourceTableView?.selectedRowIndexes
            
            for index in selectedRowIndexes! {
                let playlist = (playlistArrayController.arrangedObjects as! [PlayList])[index]
                for playItem in playlist.list {
                    add(item: playItem, atIndex: -1)
                }
            }
        }
        else
        
        if sourceTableView == playitemTableView {
            // These playitems get dropped into a new or append a playlist
            let items: [PlayItem] = playitemArrayController.arrangedObjects as! [PlayItem]
            var selectedPlaylist: PlayList? = playlistArrayController.selectedObjects.first as? PlayList
            let selectedRowIndexes = sourceTableView?.selectedRowIndexes

            if selectedPlaylist != nil && row < tableView.numberOfRows {
                selectedPlaylist = (playlistArrayController.arrangedObjects as! [PlayList])[row]
                for index in selectedRowIndexes! {
                    let item = items[index]
                    let togo = selectedPlaylist?.list.count
                    if let undo = self.undoManager {
                        undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": togo!] as [String : Any]] (PlaylistViewController) -> () in
                            selectedPlaylist?.list.removeLast()
                            selectedPlaylist?.list.remove(at: oldVals["index"] as! Int)
                            if !undo.isUndoing {
                                undo.setActionName("Add PlayItem")
                            }
                        })
                    }
                    observe(item, keyArray: itemIvars, observing: true)
                    selectedPlaylist?.list.append(items[index])
                }
            }
            else
            {
                add(list: PlayList(), atIndex: -1)
                tableView.scrollRowToVisible(row)
                playlistTableView.reloadData()
            }
            tableView.selectRowIndexes(IndexSet.init(integer: row), byExtendingSelection: false)
        }
        else
        if pasteboard.canReadItem(withDataConformingToTypes: [PlayList.className(), PlayItem.className()]) {
            //
            //  From another PlaylistViewController instance/window
            //  so use sourceTableView.tag: 0=playlist, 1=playitem.
            //
            if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: PlayList.className()))
            {
                if let items = pasteboard.readObjects(forClasses: [PlayList.classForCoder()], options: options) {
                    Swift.print(String(format:"%d playlist(s)", items.count))
                    var playlistSet : IndexSet? = nil
                    
                    if 0 == tableView.tag {
                        playlistSet = playlistTableView.selectedRowIndexes
                        playlistTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    }
                    
                    //  Project cross drops play list <-> item or when drop on
                    if (0 == tableView.tag && dropOperation == .on) || 1 == tableView.tag {
                        for play in items {
                            for item in (play as! PlayList).list {
                                add(item: item, atIndex: -1)
                            }
                        }
                        if 0 == tableView.tag { playlistTableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0)) }
                    }
                    else
                    {
                        for play in items as! [PlayList] {
                            add(list: play, atIndex: -1)
                        }
                    }
                    
                    if let restoreSet = playlistSet {
                        playlistTableView.selectRowIndexes(restoreSet, byExtendingSelection: false)
                    }
                }
                else
                if let items = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Any] {
                    Swift.print(String(format:"%d playlist(s)", (items as AnyObject).count))
                }
            }
            else
            if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: PlayItem.className()))
            {
                if let items = pasteboard.readObjects(forClasses: [PlayItem.classForCoder()], options: options) {
                    Swift.print(String(format:"%d playitem(s)", items.count))
                    var playlistSet : IndexSet? = nil
                    
                    //  Select the dropped on playlist(tag:0) if playitemView -> playlistView
                    if 0 == tableView.tag {
                        playlistSet = playlistTableView.selectedRowIndexes
                        playlistTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    }
                    
                    for item in items {
                        add(item: item as! PlayItem, atIndex: -1)
                    }
                    
                    if let restoreSet = playlistSet {
                        playlistTableView.selectRowIndexes(restoreSet, byExtendingSelection: false)
                    }
                }
                else
                if let items = NSKeyedUnarchiver.unarchiveObject(with: data) {
                    Swift.print(String(format:"%d playitem(s)", (items as AnyObject).count))
                }
            }
            else
            if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: PlayItem.className() + ".dict")) {
                Swift.print(String(format:"%d playitem dict:", data.count))
            }
        }
        else

        //    We have a Finder drag-n-drop of file or location URLs ?
        if let items: Array<AnyObject> = pasteboard.readObjects(forClasses: [NSURL.classForCoder()], options: options) as Array<AnyObject>? {

            //  add(item:) and add(list:) affect array controller selection,
            //  so we must alter selection to the drop row for playlist;
            //  note that we append items so adjust the newIndexOffset
            switch tableView {
            case playlistTableView:
                switch dropOperation {
                case .on:
                    //  selected playlist is already set
                    play = (playlistArrayController.arrangedObjects as! Array)[row]
                    playlistArrayController.setSelectionIndex(row)
                    break
                default:
                    play = PlayList()
                    add(list: play!, atIndex: -1)
                    playlistTableView.reloadData()
                    
                    //  Pick our selected playlist
                    let index = playlistArrayController.selectionIndexes.first
                    let selectionRow = index! + 1
                    tableView.selectRowIndexes(IndexSet.init(integer: selectionRow), byExtendingSelection: false)
                    newIndexOffset = -row
                    Swift.print("selection \(String(describing: playlistArrayController.selectedObjects.first))")
                    Swift.print("     play \(String(describing: play))")
                }
                break
                
            default: // playitemTableView:
                play = playlistArrayController.selectedObjects.first as? PlayList
                break
            }

            for itemURL in items {
                var fileURL : URL? = (itemURL as AnyObject).filePathURL
                let dc = NSDocumentController.shared
                var item: PlayItem?

                //  Resolve alias before storing bookmark
                if let original = (fileURL! as NSURL).resolvedFinderAlias() { fileURL = original }
                
                //  If we already know this url 1) known document, 2) our global items cache, use its settings
                if let doc = dc.document(for: fileURL!) {
                    item = (doc as! Document).playitem()
                }
                else
                if let dict = defaults.dictionary(forKey: (fileURL?.absoluteString)!) {
                    item = PlayItem.init(with: dict)
                }
                else
                {
                    //  Unknown files have to be sandboxed
                    if isSandboxed != appDelegate.storeBookmark(url: fileURL! as URL) {
                        Swift.print("Yoink, unable to sandbox \(String(describing: fileURL)))")
                    } else { sandboxed += 1 }

                    let path = fileURL!.absoluteString//.stringByRemovingPercentEncoding
                    let attr = appDelegate.metadataDictionaryForFileAt((fileURL?.path)!)
                    let time = attr?[kMDItemDurationSeconds] as? Double ?? 0.0
                    let fuzz = (itemURL as AnyObject).deletingPathExtension!!.lastPathComponent as NSString
                    let name = fuzz.removingPercentEncoding
                    let list: Array<PlayItem> = play!.list.sorted(by: { (lhs, rhs) -> Bool in
                        return lhs.rank < rhs.rank
                    })

                    item = PlayItem(name:name!,
                                    link:URL.init(string: path)!,
                                    time:time,
                                    rank:(list.count > 0) ? (list.last?.rank)! + 1 : 1)
                    defaults.set(item?.dictionary(), forKey: (item?.link.absoluteString)!) 
                }
                
                //  Insert item at valid offset, else append
                if (row+newIndexOffset) < (playitemArrayController.arrangedObjects as AnyObject).count {
                    add(item: item!, atIndex: row + newIndexOffset)
                    
                    //  Dropping on from a sourceTableView implies replacement
                    if dropOperation == .on {
                        let playitems: [PlayItem] = (playitemArrayController.arrangedObjects as! [PlayItem])
                        let oldItem = playitems[row+newIndexOffset+1]

                        //  We've shifted so remove old item at new location
                        remove(item: oldItem, atIndex: row+newIndexOffset+1)
                    }
                }
                else
                {
                    add(item: item!, atIndex: -1)
                }
                newIndexOffset += 1
            }
        }
        else
        {
            // Try to pick off whatever they sent us
            for element in pasteboard.pasteboardItems! {
                for elementType in element.types {
                    let elementItem = element.string(forType:elementType)
                    var item: PlayItem?
                    var url: URL?
                    
                    //  Use first playlist name
                    if elementItem?.count == 0 { continue }
//                    if !okydoKey { play?.name = elementType }

                    switch (elementType) {
                    case NSPasteboard.PasteboardType("public.url")://kUTTypeURL
                        if let testURL = URL(string: elementItem!) {
                            url = testURL
                        }
                        break
                    case NSPasteboard.PasteboardType("public.file-url"),
                         NSPasteboard.PasteboardType("public.utf8-plain-text")://kUTTypeFileURL
                        if let testURL = URL(string: elementItem!)?.standardizedFileURL {
                            url = testURL
                        }
                        break
                    case NSPasteboard.PasteboardType("com.apple.finder.node"):
                        continue // handled as public.file-url
                    case NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-content-type"):
                        if let testURL = URL(string: elementItem!)?.standardizedFileURL {
                            url = testURL
                            break
                        }
                        continue
                    default:
                        Swift.print("type \(elementType) \(elementItem!)")
                        continue
                    }
                    if url == nil { continue }
                    
                    //  Resolve finder alias
                    if let original = (url! as NSURL).resolvedFinderAlias() { url = original }
                    
                    if isSandboxed != appDelegate.storeBookmark(url: url!) {
                        Swift.print("Yoink, unable to sandbox \(String(describing: url)))")
                    } else { sandboxed += 1 }
                    
                    //  If item is in our playitems cache use it
                    if let dict = defaults.dictionary(forKey: (url?.absoluteString)!) {
                        item = PlayItem.init(with: dict)
                    }
                    else
                    {
                        let attr = appDelegate.metadataDictionaryForFileAt((url?.path)!)
                        let time = attr?[kMDItemDurationSeconds] as? TimeInterval ?? 0.0
                        let fuzz = url?.deletingPathExtension().lastPathComponent
                        let name = fuzz?.removingPercentEncoding
                        //  TODO: we should probably set selection to where row here is as above
                        let selectedPlaylist = playlistArrayController.selectedObjects.first as? PlayList
                        let list: Array<PlayItem> = selectedPlaylist!.list.sorted(by: { (lhs, rhs) -> Bool in
                            return lhs.rank < rhs.rank
                        })
                        
                        item = PlayItem(name: name!,
                                        link: url!,
                                        time: time,
                                        rank: (list.count > 0) ? (list.last?.rank)! + 1 : 1)
                    }
                    
                    if (row+newIndexOffset) < (playitemArrayController.arrangedObjects as AnyObject).count {
                        add(item: item!, atIndex: row + newIndexOffset)

                        //  Dropping on from a sourceTableView implies replacement
                        if dropOperation == .on {
                            let playitems: [PlayItem] = (playitemArrayController.arrangedObjects as! [PlayItem])
                            let oldItem = playitems[row+newIndexOffset+1]

                            //  We've shifted so remove old item at new location
                            remove(item: oldItem, atIndex: row+newIndexOffset+1)
                        }
                    }
                    else
                    {
                        add(item: item!, atIndex: -1)
                    }
                    newIndexOffset += 1
                }
            }
        }

        tableView.endUpdates()

        if sandboxed > 0 && isSandboxed != appDelegate.saveBookmarks() {
            Swift.print("Yoink, unable to save bookmarks")
        }
 
        return true
    }
}
