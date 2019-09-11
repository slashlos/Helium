//
//  Helium.swift
//  Helium
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation
import QuickLook

// Document type
struct DocType : OptionSet {
    let rawValue: Int

    static let helium       = DocType(rawValue: 0)
    static let release      = DocType(rawValue: 1)
    static let playlist     = DocType(rawValue: 2)
}
let docHelium : ViewOptions = []

//  Global static strings
struct k {
    static let Helium = "Helium"
    static let helium = "helium"
    static let about = "about"
    static let docIcon = "docIcon"
    static let Playlists = "Playlists"
    static let playlists = "playlists"
    static let Playitems = "Playitems"
    static let playitems = "playitems"
    static let Settings = "settings"
    static let Custom = "Custom"
    static let webloc = "webloc"
    static let h3w = "h3w"
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

let docTypes = [k.Helium, k.Release, k.Playlists]

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
        return self.item(name) != nil
    }
    func item(_ name: String) -> PlayList? {
        for play in self {
            if play.name == name {
                return play
            }
        }
        return nil
    }
}

extension Array where Element:PlayItem {
    func has(_ name: String) -> Bool {
        return self.item(name) != nil
    }
    func item(_ name: String) -> PlayItem? {
        for item in self {
            if item.link.absoluteString == name {
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

class PlayList : NSObject, NSCoding, NSCopying, NSPasteboardWriting, NSPasteboardReading {
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate

    //  Keep playlist names unique
    @objc dynamic var name : String = k.list {
        didSet {
            if appDelegate.playlists.item(name) != self {
                name = oldValue

                //  tell controller we have reverted this edit
                let notif = Notification(name: Notification.Name(rawValue: "BadPlayListName"), object: self)
                NotificationCenter.default.post(notif)
            }
        }
    }
    @objc dynamic var list : Array <PlayItem> = Array()
    @objc dynamic var date : TimeInterval
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
        var suffix = 0

        //  Make sure new items have unique name
        while appDelegate.playlists.has(name) {
            suffix += 1
            name = String(format: "%@%@ %d", test, temp as CVarArg, suffix)
        }
        
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
        for item in list {
            items.append(item.dictionary())
        }
        dict[k.name] = name
        dict[k.list] = items
        dict[k.date] = date
        return dict
    }
    convenience init(with dictionary: Dictionary<String,Any>) {
        self.init()
        
        self.update(with: dictionary)
    }
    func update(with dictionary: Dictionary<String,Any>) {
        if let name : String = dictionary[k.name] as? String, name != self.name {
            self.name = name
        }
        if let plists : [Dictionary<String,Any>] = dictionary[k.list] as? [Dictionary<String,Any>] {
            
            for plist in plists {
                if let item : PlayItem = list.item(plist[k.link] as! String) {
                    item.update(with: plist)
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
    required convenience init(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        Swift.print("type: \(type.rawValue)")
        guard type == NSPasteboard.PasteboardType(rawValue: PlayList.className()) else {
            self.init()
            
            let dict = NSKeyedUnarchiver.unarchiveObject(with: propertyList as! Data)
            self.update(with: dict as! Dictionary<String, Any>)
            return
        }
        
        let item = NSKeyedUnarchiver.unarchiveObject(with: propertyList as! Data)
        Swift.print("item: \(String(describing: item))")
        self.init(item as! PlayList)
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [NSPasteboard.PasteboardType(rawValue: PlayList.className()),
                NSPasteboard.PasteboardType(rawValue: PlayList.className() + ".dict")]
    }
    
    // MARK:- Pasteboard Writing
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        guard type == NSPasteboard.PasteboardType(rawValue: PlayList.className()) else {
            return NSKeyedArchiver.archivedData(withRootObject: self.dictionary())
        }
        
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [NSPasteboard.PasteboardType(rawValue: PlayList.className()),
                NSPasteboard.PasteboardType(rawValue: PlayList.className() + ".dict")]
    }
}

class PlayItem : NSObject, NSCoding, NSCopying, NSPasteboardWriting, NSPasteboardReading {
    @objc dynamic var name : String = k.item
    @objc dynamic var link : URL = URL.init(string: "http://")!
    @objc dynamic var time : TimeInterval
    @objc dynamic var date : TimeInterval
    @objc dynamic var rank : Int
    @objc dynamic var rect : NSRect
    @objc dynamic var plays : Int
    @objc dynamic var label: Bool
    @objc dynamic var hover: Bool
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

    // MARK:- Functions
    override init() {
        name = k.item + "#"
        link = URL.init(string: "http://")!
        time = 0.0
        date = Date().timeIntervalSinceReferenceDate
        rank = 0
        rect = NSZeroRect
        plays = 0
        label = false
        hover = false
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
        self.label = false
        self.hover = false
        self.alpha = 60
        self.trans = 0
        self.agent = UserSettings.UserAgent.value
        self.tabby = false
        super.init()
    }
    init(name:String, link:URL, date:TimeInterval, time:TimeInterval, rank:Int, rect:NSRect, plays:Int, label:Bool, hover:Bool, alpha:Int, trans: Int, agent: String, asTab: Bool) {
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
        if let label : Bool = dictionary[k.label] as? Bool, label != self.label  {
            self.label  = label
        }
        if let hover : Bool = dictionary[k.hover] as? Bool, hover != self.hover {
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
        dict[k.label] = label ? 1 : 0
        dict[k.hover] = hover ? 1 : 0
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
        let label = coder.decodeBool(forKey: k.label)
        let hover = coder.decodeBool(forKey: k.hover)
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
    required convenience init(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        Swift.print("type: \(type.rawValue)")
        guard type == NSPasteboard.PasteboardType(rawValue: PlayItem.className()) else {
            self.init()

            let dict = NSKeyedUnarchiver.unarchiveObject(with: propertyList as! Data)
            self.update(with: dict as! Dictionary<String, Any>)
            return
        }
        
        let item = NSKeyedUnarchiver.unarchiveObject(with: propertyList as! Data)
        Swift.print("item: \(String(describing: item))")
        self.init(item as! PlayItem)
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [NSPasteboard.PasteboardType(rawValue: PlayItem.className()),
                NSPasteboard.PasteboardType(rawValue: PlayItem.className() + ".dict")]
    }
    
    // MARK:- Pasteboard Writing
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        Swift.print("plist: \(type.rawValue)")
        guard type == NSPasteboard.PasteboardType(rawValue: PlayItem.className()) else {
           return NSKeyedArchiver.archivedData(withRootObject: self.dictionary())
        }
        
        return NSKeyedArchiver.archivedData(withRootObject: self.copy())
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        Swift.print("wtypes: [\(PlayItem.className()), \(PlayItem.className()).dict]")
        return [NSPasteboard.PasteboardType(rawValue: PlayItem.className()),
                NSPasteboard.PasteboardType(rawValue: PlayItem.className() + ".dict")]
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
    
    let autoHideTitle = Setup<Bool>("autoHideTitle", value: UserSettings.AutoHideTitle.value)
    let disabledFullScreenFloat = Setup<Bool>("disabledFullScreenFloat", value: false)
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
            let typeName = contentsURL.isFileURL && contentsURL.pathExtension == k.h3w ? k.Playlists : typeName
            doc = try Document.init(contentsOf: contentsURL, ofType: typeName)
            doc.showWindows()
        } catch let error {
            NSApp.presentError(error)
            doc = try Document.init(contentsOf: contentsURL)
        }
        
        return doc
    }

    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> Document {
        var doc: Document
        do {
            doc = try self.makeDocument(for: url, withContentsOf: url, ofType: typeName)
        } catch let error {
            NSApp.presentError(error)
            doc = Document.init()
            doc.update(to: url)
        }
        return doc
    }
    
    class override func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        (NSApp.delegate as! AppDelegate).documentsToRestore = true
        
        super.restoreWindow(withIdentifier: identifier, state: state, completionHandler: completionHandler)
    }
}

class Document : NSDocument {

    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    var dc : NSDocumentController {
        get {
            return NSDocumentController.shared
        }
    }
    var defaults = UserDefaults.standard
    var autoSaveDocs : Bool {
        get {
            return UserSettings.AutoSaveDocs.value
        }
    }
    var settings: Settings
    var docType : DocType
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
                return URL.init(string: UserSettings.HomePageURL.value)
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
        dict[k.label] = settings.autoHideTitle.value
        dict[k.hover] = settings.disabledFullScreenFloat.value
        dict[k.alpha] = settings.opacityPercentage.value
        dict[k.trans] = settings.translucencyPreference.value.rawValue as AnyObject
        dict[k.agent] = settings.customUserAgent.value
        dict[k.tabby] = settings.tabby.value
        return dict
    }
    
    func playitem() -> PlayItem {
        let item = PlayItem.init()
        item.name = self.displayName
        item.link = self.fileURL!
        item.date = self.settings.date.value
        item.time = self.settings.time.value
        item.rank = self.settings.rank.value
        item.rect = self.settings.rect.value
        item.plays = self.settings.plays.value
        item.label = self.settings.autoHideTitle.value
        item.hover = self.settings.disabledFullScreenFloat.value
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
        if let label : Bool = dictionary[k.label] as? Bool, label != self.settings.autoHideTitle.value  {
            self.settings.autoHideTitle.value = label
        }
        if let hover : Bool = dictionary[k.hover] as? Bool, hover != self.settings.disabledFullScreenFloat.value {
            self.settings.disabledFullScreenFloat.value = hover
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
        self.fileType = url.isFileURL ? url.pathExtension : nil
        self.fileURL = url
        
        if let dict = defaults.dictionary(forKey: url.absoluteString) {
            let item = PlayItem.init(with: dict)
            
            if item.rect != NSZeroRect {
                self.settings.rect.value = item.rect
             }
        }
    }
    func update(with item: PlayItem) {
        self.restoreSettings(with: item.dictionary())
        self.update(to: item.link)
    }
    
    override init() {
        settings = Settings()
        docType = .helium
        super.init()
    }
    
    override class var autosavesInPlace: Bool {
        return false
    }
    
    override func defaultDraftName() -> String {
        return docType == .playlist ? k.Playlists : k.Helium
    }

    var displayImage: NSImage? {
        get {
            switch docType {
            case .playlist:
                let tmpImage = NSImage.init(named: "docIcon")
                let appImage = tmpImage?.resize(w: 32, h: 32)
                return appImage

            case .release:
                let tmpImage = NSImage.init(named: "appIcon")
                let appImage = tmpImage?.resize(w: 32, h: 32)
                return appImage
                
            default:
                if (self.fileURL?.isFileURL) != nil {
                    let size = NSMakeSize(CGFloat(kTitleNormal), CGFloat(kTitleNormal))
                    
                    let tmp = QLThumbnailImageCreate(kCFAllocatorDefault, self.fileURL! as CFURL , size, nil)
                    if let tmpImage = tmp?.takeUnretainedValue() {
                        let tmpIcon = NSImage(cgImage: tmpImage, size: size)
                        return tmpIcon
                    }
                }
                let tmpImage = NSImage.init(named: k.docIcon)
                let docImage = tmpImage?.resize(w: 32, h: 32)
                return docImage
            }
        }
    }
    override var displayName: String! {
        get {
            if (self.fileURL?.isFileURL) != nil {
                if let justTheName = super.displayName  {
                    return (justTheName as NSString).deletingPathExtension
                }
            }
            //  This includes playlists
            return super.displayName
        }
        set (newName) {
            super.displayName = newName
        }
    }

    convenience init(contentsOf url: URL) throws {
        do {
            try self.init(contentsOf: url, ofType: k.Helium)
        }
    }
    convenience init(contentsOf url: URL, ofType typeName: String) throws {
        self.init()

        if url.pathExtension == k.webloc, let webURL = url.webloc {
            fileURL = webURL
        }
        else
        {
            fileURL = url
        }
        self.fileType = fileURL?.pathExtension
        
        //  Record url and type, caller will load via notification
        do {
            self.makeWindowController(typeName)
            dc.addDocument(self)
            
            //  Defer custom setups until we have a webView
            if [k.Custom, k.Playlists,k.ReleaseNotes].contains(typeName) { return }

            //  If we were seen before then restore settings
            if let hpc = heliumPanelController {
                if let fileURL = fileURL, let dict = defaults.dictionary(forKey: fileURL.absoluteString) {
                    self.restoreSettings(with: dict)
                    hpc.willUpdateTranslucency()
                    hpc.willUpdateAlpha()
                }
                
                if settings.rect.value != NSZeroRect, let window = hpc.window {
                    window.setFrame(settings.rect.value, display: true)
                }

                hpc.window?.orderFront(self)
                hpc.webView?.next(url: fileURL!)
            }
        }
    }
    
    convenience init(type typeName: String) throws {
        self.init()
        
        do {
            self.makeWindowController(typeName)
        }
    }
    
    convenience init(withPlayitem item: PlayItem) throws {
        self.init()
        self.update(with: item)

        //  Record url and type, caller will load via notification
        do {
            let url = item.link
            self.makeWindowControllers()
            
            if let hwc = self.windowControllers.first {
                hwc.window?.orderFront(self)
                (hwc.contentViewController as! WebViewController).loadURL(url: url)
                if item.rect != NSZeroRect {
                    hwc.window?.setFrameOrigin(item.rect.origin)
                }
            }
        }
    }
    
    @objc @IBAction override func save(_ sender: (Any)?) {
        guard fileURL != nil, fileURL?.scheme != k.about, docType != .release else {
            return
        }
        
        do {
            if docType == .helium {
                try self.write(to: fileURL!, ofType: fileType!)
            }
            else
            if docType == .playlist {
                if let url = self.url, url.isFileURL {
                    let type = docTypes[docType.rawValue]
                    try self.writeSafely(to: url, ofType: type, for: .saveOperation)
                }
            }
         } catch let error {
            NSApp.presentError(error)
        }
    }
    
    func cacheSettings(_ url : URL) {
        
        //  soft update fileURL to cache if needed
        if self.url != url { self.fileURL = url }
        defaults.set(self.dictionary(), forKey: url.absoluteString)
        if !autoSaveDocs { self.updateChangeCount(.changeDone) }
        defaults.synchronize()
        
        //  Update UI (red dot in close button) immediately
        guard self.docType == .helium else { return }
        if let hpc = heliumPanelController, let hoverBar = hpc.hoverBar {
            hoverBar.closeButton?.setNeedsDisplay()
        }
    }
        
    override func write(to url: URL, ofType typeName: String) throws {
        cacheSettings(url)
        
        //  When a document is written, update in global play items
        self.updateChangeCount(.changeCleared)
        UserDefaults.standard.synchronize()

        //  Update UI (red dot in close button) immediately
        if let hpc = heliumPanelController, let hoverBar = hpc.hoverBar {
            hoverBar.closeButton?.setNeedsDisplay()
        }
    }
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        do {
            guard docType == .playlist else {
                try self.write(to: fileURL!, ofType: fileType!)
                return
            }

            try self.write(to: url, ofType: typeName)
            self.updateChangeCount(.changeCleared)
        } catch let error {
            NSApp.presentError(error)
        }
    }
    
    override var shouldRunSavePanelWithAccessoryView: Bool {
        get {
            return docType != .playlist
        }
    }
    
    //MARK:- Actions
    override func makeWindowControllers() {
        makeWindowController(k.Helium)
    }
    func makeWindowController(_ typeName: String) {
        let typeName = typeName == "Any" ? k.Helium : typeName
        let identifier = String(format: "%@Controller", typeName)
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        
        self.docType = DocType(rawValue: [ k.Helium, k.Release, k.Playlists ].firstIndex(of: typeName)!)
        
        let controller = storyboard.instantiateController(withIdentifier: identifier) as! NSWindowController
        self.addWindowController(controller)
        dc.addDocument(self)
        
        if docType == .playlist {
            let pvc : PlaylistViewController = controller.contentViewController as! PlaylistViewController
            
            if let url = self.url, url.pathExtension == k.h3w, let dict = NSDictionary(contentsOf: url) as? Dictionary<String,Any> {
                var playlists = [PlayList]()
                
                for (name,plist) in dict {
                    guard let items = plist as? [Dictionary<String,Any>] else { continue }
                    var list : [PlayItem] = [PlayItem]()
                    for pitem in items {
                        let item = PlayItem.init(with: pitem)
                        list.append(item)
                    }
                    let playlist = PlayList.init(name: name, list: list)
                    playlists.append(playlist)
                }
                
                pvc.playlists.append(contentsOf: playlists)
            }
            else
            {
                pvc.playlists.append(contentsOf: appDelegate.playlists)
            }

            NSApp.addWindowsItem(controller.window!, title: self.displayName, filename: false)
        }
 
        //  Relocate to origin if any
        if let window = controller.window {
            controller.window?.offsetFromKeyWindow()

            if self.settings.rect.value != NSZeroRect {
                window.setFrameOrigin(self.settings.rect.value.origin)
            }
        }
    }
    var heliumPanelController : HeliumPanelController? {
        get {
            guard let hpc : HeliumPanelController = windowControllers.first as? HeliumPanelController else { return nil }
            return hpc
        }
    }
}
