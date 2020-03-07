//
//  Helium.swift
//  Helium
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright © 2017-2020 Carlos D. Santiago. All rights reserved.
//
//  Document instance read/save/write are to default; use super for files

import Foundation
import QuickLook

// Document type
struct DocGroup : OptionSet {
    let rawValue: Int

    static let helium       = DocGroup(rawValue: 0)
    static let playlist     = DocGroup(rawValue: 1)
}
let docHelium : ViewOptions = []

//  Global static strings
struct k {
    static let Helium = "Helium" /// aka Playitem
    static let helium = "helium"
    static let about = "about"
    static let asset = "asset"
    static let html = "html"
    static let text = "text"
    static let desktop = "Desktop"
    static let docIcon = "docIcon"
    static let Playlist = "Playlist"
    static let Playlists = "Playlists"
    static let playlists = "playlists"
    static let Playitems = "Playitems"
    static let playitems = "playitems"
    static let Settings = "settings"
    static let Custom = "Custom"
    static let webloc = "webloc"
    static let hpi = "hpi"
    static let hpl = "hpl"
    static let play = "play"
    static let item = "item"
    static let name = "name"
    static let list = "list"
    static let tooltip = "tooltip"
    static let link = "link"
    static let date = "date"
    static let time = "time"
    static let rank = "rank"
    static let rect = "rect"
    static let plays = "plays"
    static let label = "label"
    static let hover = "hover"
    static let alpha = "alpha"
    static let trans = "trans"
    static let agent = "agent"
    static let tabby = "tabby"
    static let view = "view"
    static let fini = "finish"
    static let vers = "vers"
    static let data = "data"
    static let temp = "temp"
    static let TitleUtility: CGFloat = 16.0
    static let TitleNormal: CGFloat = 22.0
    static let ToolbarItemHeight: CGFloat = 48.0
    static let ToolbarItemSpacer: CGFloat = 1.0
    static let ToolbarTextHeight: CGFloat = 12.0
    static let Release = "Release"
    static let ReleaseURL = "about:///asset/RELEASE"
    static let ReleaseNotes = "Helium Release Notes"
    static let bingInfo = "Microsoft Bing Search"
    static let bingName = "Bing"
    static let bingLink = "https://search.bing.com/search?Q=%@"
    static let googleInfo = "Google Search"
    static let googleName = "Google"
    static let googleLink = "https://www.google.com/search?q=%@"
    static let yahooName = "Yahoo"
    static let yahooInfo = "Yahoo! Search"
    static let yahooLink = "https://search.yahoo.com/search?q=%@"
    static let searchInfos = [k.bingInfo, k.googleInfo, k.yahooInfo]
    static let searchNames = [k.bingName, k.googleName, k.yahooName]
    static let searchLinks = [k.bingLink, k.googleLink, k.yahooLink]
}

let docGroups = [k.Helium, k.Playlist]
let docNames = [k.Helium, k.Playlist]

extension NSPasteboard.PasteboardType {
    static let data    = NSPasteboard.PasteboardType(kUTTypeData as String)
    static let dict    = NSPasteboard.PasteboardType(NSDictionary.className())
    static let item    = NSPasteboard.PasteboardType(PlayItem.className())
    static let list    = NSPasteboard.PasteboardType(PlayList.className())
    static let files   = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    static let promise = NSPasteboard.PasteboardType(kPasteboardTypeFileURLPromise)
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

//  Create a file Handle or url for writing to a new file located in the directory specified by 'dirpath'.
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
            if false == ((((try? fileURL?.checkResourceIsReachable()) as Bool??)) ?? false) { break }
            
            // Try another tag.
            uniqueNum += 1;
        }
        outFile = file!
        
        if fm.createFile(atPath: file!, contents: nil, attributes: [FileAttributeKey(rawValue: FileAttributeKey.extensionHidden.rawValue): true]) {
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
        if false == ((((try? fileURL?.checkResourceIsReachable()) as Bool??)) ?? false) { break }
        
        // Try another tag.
        uniqueNum += 1;
    }
    
    if fm.createFile(atPath: file!, contents: nil, attributes: [FileAttributeKey(rawValue: FileAttributeKey.extensionHidden.rawValue): true]) {
        return fileURL
    } else {
        return nil
    }
}

extension Array where Element:PlayList {
    func has(_ name: String) -> Bool {
        return self.name(name) != nil
    }
    func name(_ name: String) -> PlayList? {
        for play in self {
            if play.name == name {
                return play
            }
        }
        return nil
    }
    func list(_ name: String) -> [PlayList] {
        var list = [PlayList]()
        for play in self {
            if play.name == name {
                list.append(play)
            }
        }
        return list
    }
}

extension Array where Element:PlayItem {
    func has(_ name: String) -> Bool {
        return self.item(name) != nil
    }
    func item(_ name: String) -> PlayItem? {
        for item in self {
            if item.name == name {
                return item
            }
        }
        return nil
    }
    func link(_ urlString: String) -> PlayItem? {
        for item in self {
            if item.link.absoluteString == urlString {
                return item
            }
        }
        return nil
    }
}

extension NSObject {
    func kvoTooltips(_ keyPaths : [String]) {
        for keyPath in (keyPaths)
        {
            self.willChangeValue(forKey: keyPath)
        }
        
        for keyPath in (keyPaths)
        {
            self.didChangeValue(forKey: keyPath)
        }
    }
}

class PlayList : NSObject, NSCoding, NSCopying, NSDraggingSource, NSDraggingDestination, NSPasteboardWriting, NSPasteboardReading {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate

    @objc dynamic var name : String = k.name
    @objc dynamic var list : Array <PlayItem> = Array()
    @objc dynamic var date : TimeInterval = Date.timeIntervalSinceReferenceDate
    @objc dynamic var tally: Int {
        get {
            return self.list.count
        }
    }
    @objc dynamic var plays: Int {
        get {
            var plays = 0
            for item in self.list {
                plays += item.plays
            }
            return plays
        }
    }
    @objc dynamic var shiftKeyDown : Bool {
        get {
            return (NSApp.delegate as! AppDelegate).shiftKeyDown
        }
    }
    @objc dynamic var optionKeyDown : Bool {
        get {
            return (NSApp.delegate as! AppDelegate).optionKeyDown
        }
    }

    @objc @IBOutlet weak var tooltip : NSString! {
        get {
            if shiftKeyDown {
                return String(format: "%ld play(s)", self.plays) as NSString
            }
            else
            {
                return String(format: "%ld item(s)", self.list.count) as NSString
            }
        }
        set (value) {
            
        }
    }
    @objc dynamic var image: NSImage {
        get {
            return NSImage.init(named: k.Helium)!
        }
    }

    override var description: String {
        get {
            return String(format: "<%@: %p '%@' %ld item(s)", self.className, self, self.name, list.count)
        }
    }
    
    // MARK:- Functions
    override init() {
        let test = k.play + "#"
        date = Date().timeIntervalSinceReferenceDate
        super.init()

        list = Array <PlayItem> ()
        let temp = (String(format:"%p",self)).suffix(4)
        name = test + temp

        //  watch shift key changes affecting our playlist
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shiftKeyDown(_:)),
            name: NSNotification.Name(rawValue: "shiftKeyDown"),
            object: nil)

        //  watch option key changes affecting our playlist
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(optionKeyDown(_:)),
            name: NSNotification.Name(rawValue: "optionKeyDown"),
            object: nil)
    }
    
    @objc internal func shiftKeyDown(_ note: Notification) {
        self.kvoTooltips([k.tooltip])
    }
    
    @objc internal func optionKeyDown(_ note: Notification) {
        self.kvoTooltips([k.tooltip])
    }

    convenience init(name:String, list:Array <PlayItem>) {
        self.init()

        self.list = list
        self.name = name
    }
    
    func dictionary() -> Dictionary<String,Any> {
        var dict = Dictionary<String,Any>()
        var items: [Any] = Array()
        for item in self.list {
            items.append(item.dictionary())
        }
        dict[k.name] = self.name
        dict[k.list] = items
        dict[k.date] = self.date
        return dict
    }
    convenience init(with dictionary: Dictionary<String,Any>, createMissingItems: Bool = false) {
        self.init()
        
        self.update(with: dictionary, createMissingItems: createMissingItems)
    }
    func update(with dictionary: Dictionary<String,Any>, createMissingItems: Bool = false) {
        if let name : String = dictionary[k.name] as? String, name != self.name {
            self.name = name
        }
        if let plists : [Dictionary<String,Any>] = dictionary[k.list] as? [Dictionary<String,Any>] {
            
            for plist in plists {
                if let item : PlayItem = list.link(plist[k.link] as! String) {
                    item.update(with: plist)
                }
                else
                if createMissingItems
                {
                    list.append(PlayItem.init(with: plist))
                }
            }
        }
        if let date : TimeInterval = dictionary[k.date] as? TimeInterval, date != self.date {
            self.date = date
        }
    }
    
    // MARK:- NSCoder
    required convenience init(coder: NSCoder) {
        let name = coder.decodeObject(forKey: k.name) as! String
        let list = coder.decodeObject(forKey: k.list) as! [PlayItem]
        let date = coder.decodeDouble(forKey: k.date)
        self.init(name: name, list: list)
        self.date = date
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: k.name)
        coder.encode(list, forKey: k.list)
        coder.encode(date, forKey: k.date)
    }
    
    // MARK:- NSCopying
    convenience required init(_ with: PlayList) {
        self.init()
        
        self.name = with.name
        self.list = with.list
        self.date = with.date
    }
    
    func copy(with zone: NSZone? = nil) -> Any
    {
        return type(of:self).init(self)
    }
    
    // MARK:- Pasteboard Reading
    static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        Swift.print("listRO type: \(type.rawValue)")
        switch type {
        case .list:
            return .asPropertyList
            
        case .data:
            return .asData

        case .dict:
            return .asKeyedArchive
            
         case .string:
            return .asString
            
        default:
            return .asKeyedArchive
        }
     }

    required convenience init(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        Swift.print("listR type: \(type.rawValue)")
        switch type {
        case .list:
            self.init(with: propertyList as! Dictionary, createMissingItems: true)
            
        case .data:
            let item = NSKeyedUnarchiver.unarchiveObject(with: propertyList as! Data)
            self.init(item as! PlayList)
            
        case .dict:
            let dict = NSKeyedUnarchiver.unarchiveObject(with: propertyList as! Data)
            self.init(with: dict as! Dictionary, createMissingItems: true)

        case .string:
            self.init()
            if let xmlString = propertyList as? String {
                Swift.print("convert \(xmlString) to playlist")
            }
            
        default:
            Swift.print("unknown \(type)")
            self.init()
        }
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.list, .data, .dict, .string]
    }
    
    // MARK:- Pasteboard Writing
    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        Swift.print("listWO type: \(type.rawValue)")
        switch type {
        case .list:
            return .promised
            
        case .data:
            return .promised

        case .dict:
            return .promised
            
         case .string:
            return .promised
            
        default:
            return .promised
        }
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        Swift.print("listW type: \(type.rawValue)")
        switch type {
        case .list:
            return self.dictionary()

        case .data:
            return NSKeyedArchiver.archivedData(withRootObject: self)
            
        case .dict:
            return NSKeyedArchiver.archivedData(withRootObject: self.dictionary())
            
        case .string:
            return self.dictionary().xmlString(withElement: self.className, isFirstElement: true)
            
        default:
            Swift.print("unknown \(type)")
            return nil
        }
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.list, .data, .dict, .string]
    }
}

class PlayItem : NSObject, NSCoding, NSCopying, NSDraggingSource, NSDraggingDestination, NSPasteboardWriting, NSPasteboardReading {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    @objc dynamic var name : String = k.item
    @objc dynamic var link : URL = URL.init(string: "http://")!
    @objc dynamic var time : TimeInterval
    @objc dynamic var date : TimeInterval
    @objc dynamic var rank : Int
    @objc dynamic var rect : NSRect
    @objc dynamic var plays: Int
    @objc dynamic var label: Int
    @objc dynamic var hover: Int
    @objc dynamic var alpha: Int
    @objc dynamic var trans: Int
    @objc dynamic var agent: String = UserSettings.UserAgent.value
    @objc dynamic var tabby: Bool
    @objc dynamic var temp : String {
        get {
            return link.absoluteString
        }
        set (value) {
            link = URL.init(string: value)!
        }
    }
    @objc dynamic var image: NSImage {
        get {
            guard link.isFileURL else { return NSImage.init(named: k.docIcon)! }
            
            let size = NSMakeSize(32.0, 32.0)
                
            let tmp = QLThumbnailImageCreate(kCFAllocatorDefault, link as CFURL , size, nil)
            if let tmpImage = tmp?.takeUnretainedValue() {
                ///let tmpIcon = NSImage(cgImage: tmpImage, size: size)
                ///return tmpIcon
                return NSImage(cgImage: tmpImage, size: size)
            }
            return NSImage.init(named: k.docIcon)!
        }
    }
    // MARK:- Functions
    override init() {
        name = k.item + "#"
        link = URL.init(string: "http://")!
        time = 0.0
        date = Date().timeIntervalSinceReferenceDate
        rank = 0
        rect = NSZeroRect
        plays = 0
        label = 0
        hover = 0
        alpha = 60
        trans = 0
        agent = UserSettings.UserAgent.value
        tabby = false
        super.init()
        
        let temp = String(format:"%p",self)
        name += String(temp.suffix(4))
    }
    init(name:String, link:URL, time:TimeInterval, rank:Int) {
        self.name = name
        self.link = link
        self.date = Date().timeIntervalSinceReferenceDate
        self.time = time
        self.rank = rank
        self.rect = NSZeroRect
        self.plays = 1
        self.label = 0
        self.hover = 0
        self.alpha = 60
        self.trans = 0
        self.agent = UserSettings.UserAgent.value
        self.tabby = false
        super.init()
    }
    init(name:String, link:URL, date:TimeInterval, time:TimeInterval, rank:Int, rect:NSRect, plays:Int, label:Int, hover:Int, alpha:Int, trans: Int, agent: String, asTab: Bool) {
        self.name = name
        self.link = link
        self.date = date
        self.time = time
        self.rank = rank
        self.rect = rect
        self.plays = plays
        self.label = label
        self.hover = hover
        self.alpha = alpha
        self.trans = trans
        self.agent = agent
        self.tabby = asTab
        super.init()
    }
    convenience init(with dictionary: Dictionary<String,Any>) {
        self.init()
        self.update(with: dictionary)
    }
    
    func update(with dictionary: Dictionary<String,Any>) {
        if let name : String = dictionary[k.name] as? String, name != self.name {
            self.name = name
        }
        if let link : URL = dictionary[k.link] as? URL, link != self.link {
            self.link = link
        }
        else
        if let urlString : String = dictionary[k.link] as? String, let link = URL.init(string: urlString), link != self.link {
            self.link = link
        }
        if let date : TimeInterval = dictionary[k.date] as? TimeInterval, date != self.date {
            self.date = date
        }
        if let time : TimeInterval = dictionary[k.time] as? TimeInterval, time != self.time {
            self.time = time
        }
        if let rank : Int = dictionary[k.rank] as? Int, rank != self.rank {
            self.rank = rank
        }
        if let rect = dictionary[k.rect] as? NSRect, rect != self.rect {
            self.rect = rect
        }
        if let plays : Int = dictionary[k.plays] as? Int, plays != self.plays {
            self.plays = plays
        }
        self.plays = (self.plays == 0) ? 1 : self.plays // default missing value
        if let label : Int = dictionary[k.label] as? Int, label != self.label  {
            self.label  = label
        }
        if let hover : Int = dictionary[k.hover] as? Int, hover != self.hover {
            self.hover = hover
        }
        if let alpha : Int = dictionary[k.alpha] as? Int, alpha != self.alpha {
            self.alpha = alpha
        }
        if let trans : Int = dictionary[k.trans] as? Int, trans != self.trans {
            self.trans = trans
        }
        if let agent : String = dictionary[k.agent] as? String, agent != self.agent {
            self.agent = agent
        }
        if let tabby : Bool = dictionary[k.tabby] as? Bool, tabby != self.tabby {
            self.tabby = tabby
        }
    }
    override var description : String {
        return String(format: "%@: %p '%@'", self.className, self, name)
    }
    
    func dictionary() -> Dictionary<String,Any> {
        var dict = Dictionary<String,Any>()
        dict[k.name] = name
        dict[k.link] = link.absoluteString
        dict[k.date] = date
        dict[k.time] = time
        dict[k.rank] =  rank
        dict[k.rect] = NSStringFromRect(rect)
        dict[k.plays] = plays
        dict[k.label] = label
        dict[k.hover] = hover
        dict[k.alpha] = alpha
        dict[k.trans] = trans
        dict[k.agent] = agent
        dict[k.tabby] = tabby
        return dict
    }

    // MARK:- NSCoder
    required convenience init(coder: NSCoder) {
        let name = coder.decodeObject(forKey: k.name) as! String
        let link = URL.init(string: coder.decodeObject(forKey: k.link) as! String)
        let date = coder.decodeDouble(forKey: k.date)
        let time = coder.decodeDouble(forKey: k.time)
        let rank = coder.decodeInteger(forKey: k.rank)
        let rect = NSRectFromString(coder.decodeObject(forKey: k.rect) as! String)
        let plays = coder.decodeInteger(forKey: k.plays)
        let label = coder.decodeInteger(forKey: k.label)
        let hover = coder.decodeInteger(forKey: k.hover)
        let alpha = coder.decodeInteger(forKey: k.alpha)
        let trans = coder.decodeInteger(forKey: k.trans)
        let agent = coder.decodeObject(forKey: k.agent) as! String
        let tabby = coder.decodeBool(forKey: k.tabby)
        self.init(name: name, link: link!, date: date, time: time, rank: rank, rect: rect,
                  plays: plays, label: label, hover: hover, alpha: alpha, trans: trans, agent: agent, asTab: tabby)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: k.name)
        coder.encode(link.absoluteString, forKey: k.link)
        coder.encode(date, forKey: k.date)
        coder.encode(time, forKey: k.time)
        coder.encode(rank, forKey: k.rank)
        coder.encode(NSStringFromRect(rect), forKey: k.rect)
        coder.encode(plays, forKey: k.plays)
        coder.encode(label, forKey: k.label)
        coder.encode(hover, forKey: k.hover)
        coder.encode(alpha, forKey: k.alpha)
        coder.encode(trans, forKey: k.trans)
        coder.encode(agent, forKey: k.agent)
        coder.encode(tabby, forKey: k.tabby)
    }
    
    // MARK:- NSCopying
    convenience required init(_ with: PlayItem) {
        self.init()
        
        self.name  = with.name
        self.link  = with.link
        self.date  = with.date
        self.time  = with.time
        self.rank  = with.rank
        self.rect  = with.rect
        self.plays = with.plays
        self.label = with.label
        self.hover = with.hover
        self.alpha = with.alpha
        self.trans = with.trans
        self.agent = with.agent
        self.tabby = with.tabby
    }
    
    func copy(with zone: NSZone? = nil) -> Any
    {
        return type(of:self).init(self)
    }
    
    // MARK:- Pasteboard Reading
    static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        Swift.print("itemRO type: \(type.rawValue)")
        switch type {
        case .item:
            return .asPropertyList
            
        case .data:
            return .asData

        case .dict:
            return .asKeyedArchive
            
         case .string:
            return .asString
            
        default:
            return .asKeyedArchive
        }
     }
    
    required convenience init(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        Swift.print("itemR type: \(type.rawValue)")
        switch type {
        case .item:
            self.init(with: propertyList as! Dictionary)
            
        case .data:
            let item = NSKeyedUnarchiver.unarchiveObject(with: propertyList as! Data)
            self.init(item as! PlayItem)
            
        case .dict:
            let dict = NSKeyedUnarchiver.unarchiveObject(with: propertyList as! Data)
            self.init(with: dict as! Dictionary)
            
        case .string:
            self.init()
            if let xmlString = propertyList as? String {
                Swift.print("convert \(xmlString) to playitem")
            }
            
        default:
            Swift.print("unknown \(type)")
            self.init()
        }
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.item, .data, .dict, .string, .URL]
    }
    
    // MARK:- Pasteboard Writing
    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        Swift.print("itemWO type: \(type.rawValue)")
        switch type {
        case .item:
            return .promised
            
        case .data:
            return .promised

        case .dict:
            return .promised
            
         case .string:
            return .promised
            
        default:
            return .promised
        }
     }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        Swift.print("itemW type: \(type.rawValue)")
        switch type {
        case .item:
            return self.dictionary()
            
        case .data:
            return NSKeyedArchiver.archivedData(withRootObject: self)
            
        case .dict:
            return NSKeyedArchiver.archivedData(withRootObject: self.dictionary())
            
        case .string:
            return self.dictionary().xmlString(withElement: self.className, isFirstElement: true)
        
        case .URL, .fileURL:
            return link.absoluteString

        default:
            Swift.print("unknown \(type)")
            return nil
        }
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.item, .data, .dict, .fileURL, .string, .URL]
    }
}

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
    
    let autoHideTitlePreference = Setup<HeliumPanelController.AutoHideTitlePreference>("rawAutoHideTitle", value: .never)
    let floatAboveAllPreference = Setup<HeliumPanelController.FloatAboveAllPreference>("rawFloatAboveAll", value: .spaces)
    let opacityPercentage = Setup<Int>("opacityPercentage", value: 60)
    let rank = Setup<Int>(k.rank, value: 0)
    let date = Setup<TimeInterval>(k.date, value: Date().timeIntervalSinceReferenceDate)
    let time = Setup<TimeInterval>(k.time, value: 0.0)
    let rect = Setup<NSRect>(k.rect, value: NSMakeRect(0, 0, 0, 0))
    let plays = Setup<Int>(k.plays, value: 0)
    let customUserAgent = Setup<String>("customUserAgent", value: UserSettings.UserAgent.value)
    let tabby = Setup<Bool>("tabby", value: false)
    
    // See values in HeliumPanelController.TranslucencyPreference
    let translucencyPreference = Setup<HeliumPanelController.TranslucencyPreference>("rawTranslucencyPreference", value: .never)
}

class HeliumDocumentController : NSDocumentController {
    override func makeDocument(for urlOrNil: URL?, withContentsOf contentsURL: URL, ofType typeName: String) throws -> Document {
        var doc: Document
        do {
            if [k.hpi,k.hpl].contains(contentsURL.pathExtension) || k.Playlist == typeName {
                doc = try super.makeDocument(for: urlOrNil, withContentsOf: contentsURL, ofType: typeName) as! Document
            }
            else
            {
                doc = try Document.init(contentsOf: contentsURL, ofType: typeName)
                doc.makeWindowControllers()
                doc.revertToSaved(self)
            }
        } catch let error {
            NSApp.presentError(error)
            doc = try Document.init(contentsOf: contentsURL)
            doc.makeWindowControllers()
            doc.revertToSaved(self)
        }
        
        return doc
    }

    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> Document {
        var doc: Document
        do {
            doc = try self.makeDocument(for: url, withContentsOf: url, ofType: typeName)
        } catch let error {
            NSApp.presentError(error)
            doc = try self.makeUntitledDocument(ofType: typeName) as! Document
        }
        return doc
    }
    
    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        var doc: Document
        do {
            doc = try super.makeUntitledDocument(ofType: typeName) as! Document
        } catch let error {
            NSApp.presentError(error)
            doc = try Document.init(type: typeName)
            doc.makeWindowControllers()
            doc.revertToSaved(self)
        }
        return doc
    }
    
    class override func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        if (NSApp.delegate as! AppDelegate).disableDocumentReOpening {
            completionHandler(nil, NSError.init(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil) )
        }
        else
        {
            super.restoreWindow(withIdentifier: identifier, state: state, completionHandler: completionHandler)
        }
    }
}

fileprivate var homeURL : URL {
    get {
        return URL.init(string: UserSettings.HomePageURL.value)!
    }
}

class Document : NSDocument {
8
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    override class var autosavesInPlace: Bool {
        return false
    }
    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        
        //  Update UI (red dot in close button) immediately
        if let hpc = heliumPanelController, let hoverBar = hpc.hoverBar {
            hoverBar.closeButton?.setNeedsDisplay()
        }
    }
    var docController : HeliumDocumentController {
        get {
            return NSDocumentController.shared as! HeliumDocumentController
        }
    }
    var defaults = UserDefaults.standard
    var autoSaveDocs : Bool {
        get {
            return UserSettings.AutoSaveDocs.value
        }
    }
    var settings: Settings
    var docGroup : DocGroup {
        get {
            if let fileType = self.fileType {
                return DocGroup(rawValue: docGroups.firstIndex(of: fileType) ?? DocGroup.helium.rawValue)
            }
            else
            {
                return .helium
            }
        }
    }
    
    var heliumPanelController : HeliumPanelController? {
        get {
            guard let hpc : HeliumPanelController = windowControllers.first as? HeliumPanelController else { return nil }
            return hpc
        }
    }
    
    var url : URL? {
        get {
            if let url = self.fileURL
            {
                return url
            }
            else
            if let hpc = heliumPanelController, let webView = hpc.webView
            {
                return webView.url
            }
            else
            {
                return homeURL
            }
        }
    }

    func dictionary() -> Dictionary<String,Any> {
        var dict: Dictionary<String,Any> = Dictionary()
        dict[k.name] = self.displayName
        dict[k.link] = self.fileURL?.absoluteString
        dict[k.date] = settings.date.value
        dict[k.time] = settings.time.value
        dict[k.rank] = settings.rank.value
        dict[k.rect] = NSStringFromRect(settings.rect.value)
        dict[k.plays] = settings.plays.value
        dict[k.label] = settings.autoHideTitlePreference.value.rawValue as AnyObject
        dict[k.hover] = settings.floatAboveAllPreference.value.rawValue as AnyObject
        dict[k.alpha] = settings.opacityPercentage.value
        dict[k.trans] = settings.translucencyPreference.value.rawValue as AnyObject
        dict[k.agent] = settings.customUserAgent.value
        dict[k.tabby] = settings.tabby.value
        return dict
    }
    
    func playitem() -> PlayItem {
        let item = PlayItem.init()
        item.name = self.displayName
        if let fileURL = self.fileURL { item.link = fileURL }
        item.date = self.settings.date.value
        item.time = self.settings.time.value
        item.rank = self.settings.rank.value
        item.rect = self.settings.rect.value
        item.plays = self.settings.plays.value
        item.label = self.settings.autoHideTitlePreference.value.rawValue
        item.hover = self.settings.floatAboveAllPreference.value.rawValue
        item.alpha = self.settings.opacityPercentage.value
        item.trans = self.settings.translucencyPreference.value.rawValue
        item.agent = self.settings.customUserAgent.value
        item.tabby = self.settings.tabby.value
        return item
    }
    
    func restoreSettings(with dictionary: Dictionary<String,Any>) {
        //  Wait until we're restoring after open or in intialization
        guard !appDelegate.openForBusiness || UserSettings.RestoreDocAttrs.value else { return }
        
        if let name : String = dictionary[k.name] as? String, name != self.displayName {
            self.displayName = name
        }
        if let link : URL = dictionary[k.link] as? URL, link != self.fileURL {
            self.fileURL = link
        }
        if let date : TimeInterval = dictionary[k.date] as? TimeInterval, date != self.settings.date.value {
            self.settings.date.value = date
        }
        if let time : TimeInterval = dictionary[k.time] as? TimeInterval, time != self.settings.time.value {
            self.settings.time.value = time
        }
        if let rank : Int = dictionary[k.rank] as? Int, rank != self.settings.rank.value {
            self.settings.rank.value = rank
        }
        if let rect = dictionary[k.rect] as? String {
            self.settings.rect.value = NSRectFromString(rect)
            if let window = self.windowControllers.first?.window {
                window.setFrame(from: rect)
            }
        }
        if let plays : Int = dictionary[k.plays] as? Int, plays != self.settings.plays.value {
            self.settings.plays.value = plays
        }
        if let label : Int = dictionary[k.label] as? Int, label != self.settings.autoHideTitlePreference.value.rawValue {
            self.settings.autoHideTitlePreference.value = HeliumPanelController.AutoHideTitlePreference(rawValue: label)!
        }
        if let hover : Int = dictionary[k.hover] as? Int, hover != self.settings.floatAboveAllPreference.value.rawValue {
            self.settings.floatAboveAllPreference.value = HeliumPanelController.FloatAboveAllPreference(rawValue: hover)
        }
        if let alpha : Int = dictionary[k.alpha] as? Int, alpha != self.settings.opacityPercentage.value {
            self.settings.opacityPercentage.value = alpha
        }
        if let trans : Int = dictionary[k.trans] as? Int, trans != self.settings.translucencyPreference.value.rawValue {
            self.settings.translucencyPreference.value = HeliumPanelController.TranslucencyPreference(rawValue: trans)!
        }

        if self.settings.time.value == 0.0, let url = self.url, url.isFileURL {
            let attr = appDelegate.metadataDictionaryForFileAt((self.fileURL?.path)!)
            if let secs = attr?[kMDItemDurationSeconds] {
                self.settings.time.value = secs as! TimeInterval
            }
        }
        if self.settings.rect.value == NSZeroRect, let fileURL = self.fileURL, let dict = defaults.dictionary(forKey: fileURL.absoluteString) {
            if let rect = dict[k.rect] as? String {
                self.settings.rect.value = NSRectFromString(rect)
                if let window = self.windowControllers.first?.window {
                    window.setFrame(from: rect)
                }
            }
        }
        if let agent : String = dictionary[k.agent] as? String, agent != settings.customUserAgent.value {
            self.settings.customUserAgent.value = agent
            if let hpc = heliumPanelController, let webView = hpc.webView {
                webView.customUserAgent = agent
            }
        }
        if let tabby : Bool = dictionary[k.tabby] as? Bool, tabby != self.settings.tabby.value {
            self.settings.tabby.value = tabby
        }
    }
    
    func update(to url: URL) {
        self.fileURL = url
        
        if let dict = defaults.dictionary(forKey: url.absoluteString) {
            let item = PlayItem.init(with: dict)
            
            if item.rect != NSZeroRect {
                self.settings.rect.value = item.rect
             }
        }
        if url.isFileURL { _displayImage = nil }
    }
    func update(with item: PlayItem) {
        self.restoreSettings(with: item.dictionary())
        self.update(to: item.link)
    }
    
    override func defaultDraftName() -> String {
        return docNames[docGroup.rawValue]
    }

    var _displayImage: NSImage?
    var displayImage: NSImage {
        get {
            switch docGroup {
            case .playlist:
                return NSImage.init(named: "docIcon")!

            default:
                guard _displayImage == nil else { return _displayImage! }
                
                guard let url = self.fileURL, url.isFileURL else { return NSImage.init(named: k.docIcon)! }
                
                let size = NSMakeSize(32.0, 32.0)
                    
                let tmp = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL , size, nil)
                if let tmpImage = tmp?.takeUnretainedValue() {
                    ///let tmpIcon = NSImage(cgImage: tmpImage, size: size)
                    ///return tmpIcon
                    _displayImage = NSImage(cgImage: tmpImage, size: size)
                    return _displayImage!
                }
                return NSImage.init(named: k.docIcon)!
            }
        }
    }
    var dragImage : NSImage {
        get {
            return displayImage.resize(w: 32, h: 32)
        }
    }
    override var displayName: String! {
        get {
            guard let fileURL = self.fileURL else { return super.displayName }
            if fileURL.isFileURL
            {
                return fileURL.deletingPathExtension().lastPathComponent
            }
            else
            {
                return super.displayName
            }
        }
        set (newName) {
            super.displayName = newName
        }
    }
    
    // MARK: Initialization
    override init() {
        settings = Settings()
        super.init()
    }
    
    convenience init(type typeName: String) throws {
        do {
            self.init()
        
            //  sync docGroup group identifier to typeName
            fileType = typeName
        }
    }
        
    convenience init(contentsOf url: URL) throws {
        do {
            try self.init(contentsOf: url, ofType: url.pathExtension == k.hpl ? k.Playlist : k.Helium)
        }
    }
    
    convenience init(contentsOf url: URL, ofType typeName: String) throws {
        //  Record url and type, caller will load via notification
        do {
            self.init()

            fileURL = url
            fileType = typeName
        }
    }
    
    override func data(ofType typeName: String) throws -> Data {
        switch docGroup {
        case .playlist:
            let pvc : PlaylistViewController = windowControllers.first!.contentViewController as! PlaylistViewController

            //  For Playlist doc group, write out dictionary of playlists, history and searches
            var plists = [PlayList]()
             
            // Save playlists - no maximum
            plists.append(contentsOf: pvc.playlists)
             
            // Save histories - no maximum
            plists.append(PlayList.init(name: UserSettings.HistoryList.keyPath , list: appDelegate.histories))

            //  Save searches - no maximum
            plists.append(PlayList.init(name: UserSettings.SearchNames.keyPath, list: appDelegate.webSearches))
 
            return NSKeyedArchiver.archivedData(withRootObject: plists)
  
        default:
            let ilists = [playitem()]
            
            return NSKeyedArchiver.archivedData(withRootObject: ilists)
        }
    }

    override func read(from data: Data, ofType typeName: String) throws {
        switch docGroup {
        case .playlist:
            guard let pdata = NSKeyedUnarchiver.unarchiveObject(with: data) else {
                throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
            }
            guard let plists : [PlayList] = pdata as? [PlayList]  else {
                throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
            }
            
            //  files are [playlist] extractions, presented as a sheet or window
            let pvc : PlaylistViewController = windowControllers.first!.contentViewController as! PlaylistViewController
            pvc.playlists = plists
            pvc.playlistArrayController.content = pvc.playlists

            guard pvc.playlists.count > 0 else {
                throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
            }
             
        default:
            guard let idata = NSKeyedUnarchiver.unarchiveObject(with: data) else {
                throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
            }
            guard let ilists : [PlayItem] = idata as? [PlayItem]  else {
                throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
            }
        
            for (i,item) in ilists.enumerated() {
                switch i {
                case 0:
                    restoreSettings(with: item.dictionary())
                    fileURL = item.link
                    
                default:
                    Swift.print("\(i) -> \(item.link.absoluteString)")
                }
            }
        }
    }

    override func read(from url: URL, ofType typeName: String) throws {
        
        if let dict = defaults.dictionary(forKey: url.absoluteString) {
            restoreSettings(with: dict)
        }
        
        switch docGroup {
        case .playlist:
            try super.read(from: url, ofType: typeName)

        default:
            let wvc : WebViewController = windowControllers.first!.contentViewController as! WebViewController
            
            if url.isFileURL, [k.hpi].contains(url.pathExtension) {
                try super.read(from: url, ofType: typeName)
            }
            else
            if k.about == url.scheme {
                //  "about" scheme formatted URLs: 'about:///<path>/<file>'
                let paths = url.pathComponents
                guard "/" == paths.first else { return }
                let path = paths[1]
                let file = paths[2]
                if k.asset == path {
                    wvc.webView.htmlContents = NSString.string(fromAsset: file)
                }
                else
                if k.html == path {
                    Swift.print("load html: \(file)")
                }
                else
                if k.text == path {
                    Swift.print("load text: \(file)")
                }
            }
        }
    }
    
    override func revertToSaved(_ sender: Any?) {
 
        //  If we have a file and type revert to them
        if let url = fileURL, let type = fileType {
            do {
                try revert(toContentsOf: url, ofType: type)
            }
            catch let error {
                NSApp.presentError(error)
            }
            return
        }

        //  non-file revert handling, either defaults or an asset (about:)
        switch docGroup {
        case .playlist:
            let pvc : PlaylistViewController = windowControllers.first!.contentViewController as! PlaylistViewController

            pvc.playlists = appDelegate.restorePlaylists()
            pvc.playlistArrayController.content = pvc.playlists
            
        default:
            break
        }
    }
    
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {

        //  Defer custom setups until we have a webView
        if [k.Custom].contains(typeName) { return }

        //  revert() should call read(data) then restore controller later
        
        switch docGroup {

        case .playlist:
            let pvc : PlaylistViewController = windowControllers.first!.contentViewController as! PlaylistViewController
            
            if let dict = defaults.dictionary(forKey: url.absoluteString) {
                restoreSettings(with: dict)
            }
            
            try super.revert(toContentsOf: url, ofType: typeName)
            pvc.playlistArrayController.content = pvc.playlists
            
        default:
            try read(from: url, ofType: typeName)
        }
    }
    
    @objc @IBAction override func save(_ sender: (Any)?) {
        guard let url = url, url != homeURL else {
            cacheSettings(homeURL)
            updateChangeCount(.changeCleared)
            return
        }
        
        if url.isFileURL, [k.hpi,k.hpl].contains(url.pathExtension) {
            super.save(sender)
        }
        else
        {
            do {
                switch docGroup {
                case .playlist:
                    appDelegate.savePlaylists(self)
                    
                default:
                    if let url = fileURL, let type = fileType {
                        try self.write(to: url, ofType: type)
                    }
                    else
                    {
                        cacheSettings(fileURL ?? homeURL)
                    }
                }
                updateChangeCount(.changeCleared)
            } catch let error {
                NSApp.presentError(error)
            }
        }
    }
    
    @objc @IBAction override func saveAs(_ sender: Any?) {
        if let window = windowControllers.first?.window {
            let savePanel = NSSavePanel()
            let fileType = self.fileType!
            savePanel.allowedFileTypes = [self.fileNameExtension(forType: fileType, saveOperation: .saveAsOperation)!]
            
            savePanel.beginSheetModal(for: window, completionHandler: { (result: NSApplication.ModalResponse) in
                if result == .OK {
                    do {
                        if let saveURL = savePanel.url {
                            try super.write(to: saveURL, ofType: fileType)
                            self.updateChangeCount(.changeCleared)
                            _ = saveURL.hideFileExtensionInPath()
                        }
                    } catch let error {
                        NSApp.presentError(error)
                    }
                }
            })
         }
    }
    
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        guard url != homeURL else {
            cacheSettings(homeURL)
            updateChangeCount(.changeCleared)
            return
        }

        if url.isFileURL, [k.hpi,k.hpl].contains(url.pathExtension) {
            super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
        }
        else
        {
            do {
                try writeSafely(to: url, ofType: typeName, for: saveOperation)
                completionHandler(nil)
            } catch let error {
                completionHandler(error)
            }
        }
    }
    
    override func save(withDelegate delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        save(self)
    }
    
    func cacheSettings(_ url : URL) {
        guard url != homeURL else { return }
        //  soft update fileURL to cache if needed
        if self.url != url { self.fileURL = url }
        defaults.set(self.dictionary(), forKey: url.absoluteString)
    }
    
    override func write(to url: URL, ofType typeName: String) throws {
        switch docGroup {
        case .playlist:
            appDelegate.savePlaylists(self)
            
        default:
            cacheSettings(url)
            
            //  When a document is written, update its global play items
            UserDefaults.standard.synchronize()
        }
        self.updateChangeCount(.changeCleared)
    }
    
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        if url.isFileURL, [k.hpi,k.hpl].contains(url.pathExtension) {
            try super.writeSafely(to: url, ofType: typeName, for: saveOperation)
        }
        else
        {
            try write(to: url, ofType: typeName)
        }
        updateChangeCount( [.saveOperation                  : .changeCleared,
                            .saveAsOperation                : .changeCleared,
                            .saveToOperation                : .changeCleared,
                            .autosaveElsewhereOperation     : .changeAutosaved,
                            .autosaveInPlaceOperation       : .changeAutosaved,
                            .autosaveAsOperation            : .changeAutosaved][saveOperation] ?? .changeCleared)
        updateChangeCount(.changeCleared)
    }
    
    override var shouldRunSavePanelWithAccessoryView: Bool {
        get {
            return docGroup == .playlist
        }
    }
    
    override func makeWindowControllers() {
        let type = [ k.Helium, k.Playlist ][docGroup.rawValue]
        let identifier = String(format: "%@Controller", type)
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        
        let controller = storyboard.instantiateController(withIdentifier: identifier) as! NSWindowController
        self.addWindowController(controller)
        docController.addDocument(self)
    }
}
