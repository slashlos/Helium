//
//  Helium.swift
//  Helium
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright (c) 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation
import QuickLook

//  Global static strings
struct k {
    static let Playlists = "playlists"
    static let Playitems = "playitems"
    static let Settings = "settings"
    static let Custom = "Custom"
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
    static let view = "view"
    static let fini = "finish"
    static let vers = "vers"
    static let data = "data"
    static let TitleUtility: CGFloat = 16.0
    static let TitleNormal: CGFloat = 22.0
    static let ToolbarItemHeight: CGFloat = 48.0
    static let ToolbarItemSpacer: CGFloat = 4.0
    static let ToolbarTextHeight: CGFloat = 12.0
    static let ToolbarlessSpacer: CGFloat = 4.0
    static let docHelium = 0
    static let docRelease = 1
    static let docPlaylists = 2
    static let docReleaseName = "Helium Release Notes"
    static let docPlaylistsName = "Helium Playlists"
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

class PlayList : NSObject,NSCoding {
    //  Keep playlist names unique
    var name : String = k.list {
        didSet {
            if let appDelegate: AppDelegate = NSApp.delegate as? AppDelegate {
                //  Do not allow duplicate
                if appDelegate.playlists.item(name) != self {
                    name = oldValue

                    //  tell controller we have reverted this edit
                    let notif = Notification(name: Notification.Name(rawValue: "BadPlayListName"), object: self)
                    NotificationCenter.default.post(notif)
                }
            }
        }
    }
    var list : Array <PlayItem> = Array()
    var date : TimeInterval
    var tally: Int {
        get {
            return self.list.count
        }
    }
    var plays: Int {
        get {
            var plays = 0
            for item in self.list {
                plays += item.plays
            }
            return plays
        }
    }
    dynamic var shiftKeyDown : Bool {
        get {
            return (NSApp.delegate as! AppDelegate).shiftKeyDown
        }
    }
    var tooltip : String {
        get {
            if shiftKeyDown {
                return String(format: "%ld play(s)", self.plays)
            }
            else
            {
                return String(format: "%ld item(s)", self.list.count)
            }
        }
    }
    override var description: String {
        get {
            return String(format: "<%@: %p '%@' %ld item(s)", self.className, self, self.name, list.count)
        }
    }
    
    override init() {
        date = Date().timeIntervalSinceReferenceDate
        super.init()

        var suffix = 0
        list = Array <PlayItem> ()
        let temp = NSString(format:"%p",self) as String
        name = String(format:"play#%@%@", temp.suffix(4) as CVarArg, (suffix > 0 ? String(format:" %d",suffix) : ""))
 
        //  Make sure new items have unique name
        if let appDelegate: AppDelegate = NSApp.delegate as? AppDelegate {
            while appDelegate.playlists.has(name) {
                suffix += 1
                name = String(format:"play#%@%@", temp.suffix(4) as CVarArg, (suffix > 0 ? String(format:" %d",suffix) : ""))
            }
        }
        
        //  watch shift key changes affecting our playlist
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shiftKeyDown(_:)),
            name: NSNotification.Name(rawValue: "shiftKeyDown"),
            object: nil)
    }
    
    internal func shiftKeyDown(_ note: Notification) {
        let keyPaths = ["tooltip"]
        for keyPath in (keyPaths)
        {
            self.willChangeValue(forKey: keyPath)
        }
        
        for keyPath in (keyPaths)
        {
            self.didChangeValue(forKey: keyPath)
        }
    }
    
    convenience init(name:String, list:Array <PlayItem>) {
        self.init()

        self.list = list
        self.name = name
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [String] {
        return ["com.helium.playlist"]
    }
    
    func pasteboardPropertyList(forType type: String) -> Any? {
        if type == "com.helium.playlist" {
            return [name, list, date]
        }
        else
        {
            Swift.print("pasteboardPropertyList:\(type) unknown")
            return nil
        }
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
    
    required convenience init(coder: NSCoder) {
        let name = coder.decodeObject(forKey: k.name) as! String
        let list = coder.decodeObject(forKey: k.list) as! [PlayItem]
        let date = coder.decodeDouble(forKey: k.date)
        self.init(name: name, list: list)
        self.date = date
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

    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: k.name)
        coder.encode(list, forKey: k.list)
        coder.encode(date, forKey: k.date)
    }
}

class PlayItem : NSObject, NSCoding {
    var name : String = k.item
    var link : URL = URL.init(string: "http://")!
    var time : TimeInterval
    var date : TimeInterval
    var rank : Int
    var rect : NSRect
    var plays : Int
    var label: Bool
    var hover: Bool
    var alpha: Int
    var trans: Int
    var temp : String {
        get {
            return link.absoluteString
        }
        set (value) {
            link = URL.init(string: value)!
        }
    }
    
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
        super.init()
        
        let temp = NSString(format:"%p",self) as String
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
        super.init()
    }
    init(name:String, link:URL, date:TimeInterval, time:TimeInterval, rank:Int, rect:NSRect, plays:Int, label:Bool, hover:Bool, alpha:Int, trans: Int) {
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
    }
    override var description : String {
        return String(format: "%@: %p '%@'", self.className, self, name)
    }
    
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
        self.init(name: name, link: link!, date: date, time: time, rank: rank, rect: rect,
                  plays: plays, label: label, hover: hover, alpha: alpha, trans: trans)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: k.name)
        coder.encode(link, forKey: k.link)
        coder.encode(date, forKey: k.date)
        coder.encode(time, forKey: k.time)
        coder.encode(rank, forKey: k.rank)
        coder.encode(NSStringFromRect(rect), forKey: k.rect)
        coder.encode(plays, forKey: k.plays)
        coder.encode(label, forKey: k.label)
        coder.encode(hover, forKey: k.hover)
        coder.encode(alpha, forKey: k.alpha)
        coder.encode(trans, forKey: k.trans)
    }
    
    func dictionary() -> Dictionary<String,Any> {
        var dict = Dictionary<String,Any>()
        dict[k.name] = name
        dict[k.link] = link.absoluteString
        dict[k.date] = date
        dict[k.time] = time
        dict[k.plays] = plays
        dict[k.rank] =  rank
        dict[k.rect] = NSStringFromRect(rect)
        dict[k.plays] = plays
        dict[k.label] = label ? 1 : 0
        dict[k.hover] = hover ? 1 : 0
        dict[k.alpha] = alpha
        dict[k.trans] = trans
        return dict
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
    
    let autoHideTitle = Setup<Bool>("autoHideTitle", value: false)
    let disabledFullScreenFloat = Setup<Bool>("disabledFullScreenFloat", value: false)
    let opacityPercentage = Setup<Int>("opacityPercentage", value: 60)
    let rank = Setup<Int>(k.rank, value: 0)
    let date = Setup<TimeInterval>(k.date, value: Date().timeIntervalSinceReferenceDate)
    let time = Setup<TimeInterval>(k.time, value: 0.0)
    let rect = Setup<NSRect>(k.rect, value: NSMakeRect(0, 0, 0, 0))
    let plays = Setup<Int>(k.plays, value: 0)
    
    // See values in HeliumPanelController.TranslucencyPreference
    let translucencyPreference = Setup<HeliumPanelController.TranslucencyPreference>("rawTranslucencyPreference", value: .never)
}

class HeliumDocumentController : NSDocumentController {
    override func makeDocument(for urlOrNil: URL?, withContentsOf contentsURL: URL, ofType typeName: String) throws -> NSDocument {
        var doc: Document
        do {
            doc = try Document.init(contentsOf: contentsURL)
            if (urlOrNil != nil) {
                doc.fileURL = urlOrNil
                doc.fileType = urlOrNil?.pathExtension
            }
        } catch let error {
            NSApp.presentError(error)
            doc = try Document.init(contentsOf: contentsURL)
        }
        return doc
    }

    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
        var doc: Document
        do {
            doc = try self.makeDocument(for: url, withContentsOf: url, ofType: typeName) as! Document
        } catch let error {
            NSApp.presentError(error)
            doc = Document.init()
            doc.update(to: url)
        }
        return doc
    }
}

class Document : NSDocument {

    var defaults = UserDefaults.standard
    var autoSaveDocs : Bool {
        get {
            return UserSettings.AutoSaveDocs.value
        }
    }
    var settings: Settings
    var docType : Int
    var url : URL? {
        get {
            if let url = self.fileURL
            {
                return url
            }
            else
            if let webView = self.windowControllers.first?.contentViewController?.view.subviews.first, webView.isKind(of: MyWebView.self)
            {
                return (webView as! MyWebView).url
            }
            else
            {
                return URL.init(string: UserSettings.homePageURL.default)
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
        return item
    }
    
    func restoreSettings(with dictionary: Dictionary<String,Any>) {
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
        if let rect = dictionary[k.rect] as? NSRect, rect != self.settings.rect.value {
            self.settings.rect.value = rect
        }
        if let plays : Int = dictionary[k.plays] as? Int, plays != self.settings.plays.value {
            self.settings.plays.value = plays
        }
        if let label : Bool = dictionary[k.label] as? Bool, label != self.settings.autoHideTitle.value  {
            self.settings.autoHideTitle.value  = label
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
            let appDelegate = NSApp.delegate as! AppDelegate
            let attr = appDelegate.metadataDictionaryForFileAt((self.fileURL?.path)!)
            if let secs = attr?[kMDItemDurationSeconds] {
                self.settings.time.value = secs as! TimeInterval
            }
        }
        if self.settings.rect.value == NSZeroRect, let fileURL = self.fileURL, let dict = defaults.dictionary(forKey: fileURL.absoluteString) {
            if let rect = dict[k.rect] as? NSRect, rect != self.settings.rect.value {
                self.settings.rect.value = rect
            }
        }
    }
    
    func update(to url: URL) {
        if url.pathExtension == "h3w", let dict = NSDictionary(contentsOf: url) {
            if let item = dict.value(forKey: k.Settings) {
                self.restoreSettings(with: item as! Dictionary<String,Any> )
            }
            
            if let plays = dict.value(forKey: k.Playlists) {
                Swift.print("plays \(plays)")
            }
            
            if let items = dict.value(forKey: k.Playitems) {
                Swift.print("items \(items)")
            }
        }

        self.fileType = url.pathExtension
        self.fileURL = url
        self.docType = k.docHelium
        
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
        docType = k.docHelium
        super.init()
    }
    
    override class func autosavesInPlace() -> Bool {
        return false
    }

    var displayImage: NSImage? {
        get {
            switch docType {
            case k.docPlaylists, k.docRelease:
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
                let tmpImage = NSImage.init(named: "docIcon")
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
            return super.displayName
        }
        set (newName) {
            super.displayName = newName
        }
    }

    convenience init(contentsOf url: URL) throws {
        do {
            try self.init(contentsOf: url, ofType: "Helium")
        }
    }
    convenience init(contentsOf url: URL, ofType typeName: String) throws {
        self.init()
        self.docType = (typeName == k.Playlists ? k.docPlaylists : k.docHelium)

        //  Read webloc url contents
        if url.path.hasSuffix("webloc"), let webURL = url.webloc {
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
            NSDocumentController.shared().addDocument(self)
            
            //  Defer custom setups until we have a webView
            if typeName == k.Custom { return }

            //  Playlists in its view controller
            //  nothing to do for playlists here
            if typeName == k.Playlists { return }
            
            //  If we were seen before then restore settings
            if let hwc = self.windowControllers.first {
                if let dict = defaults.dictionary(forKey: (fileURL?.absoluteString)!) {
                    self.restoreSettings(with: dict)
                    (hwc as! HeliumPanelController).willUpdateTranslucency()
                    (hwc as! HeliumPanelController).willUpdateAlpha()
                }
                
                if settings.rect.value != NSZeroRect, let window = hwc.window {
                    window.setFrame(settings.rect.value, display: true)
                }

                hwc.window?.orderFront(self)
                (hwc.contentViewController as! WebViewController).loadURL(url: fileURL!)
            }
        }
    }
    
    convenience init(withPlayitem item: PlayItem) throws {
        self.init()
        self.update(with: item)

        //  Record url and type, caller will load via notification
        do {
            let url = item.link
            self.makeWindowControllers()
            NSDocumentController.shared().addDocument(self)
            
            if let hwc = self.windowControllers.first {
                hwc.window?.orderFront(self)
                (hwc.contentViewController as! WebViewController).loadURL(url: url)
                if item.rect != NSZeroRect {
                    hwc.window?.setFrameOrigin(item.rect.origin)
                }
            }
        }
    }
    
    convenience init(withPlaylists item: [PlayList]) throws {
        
        do {
            let homeURL = URL.init(string: UserSettings.homePageURL.value)!
            try self.init(contentsOf: homeURL, ofType: k.Playlists)
        }
    }
    
    @IBAction override func save(_ sender: (Any)?) {
        guard fileURL != nil, fileURL?.scheme != "about" else {
            return
        }
        
        do {
            try self.write(to: fileURL!, ofType: fileType!)
        } catch let error {
            NSApp.presentError(error)
        }
    }
    
    func cacheSettings(_ url : URL) {
        
        //  soft update fileURL to cache if needed
        if self.url != url { self.fileURL = url }
        defaults.set(self.dictionary(), forKey: url.absoluteString)
        if !autoSaveDocs { self.updateChangeCount(.changeDone) }
        
        //  Update UI (red dot in close button) immediately
        if let hwc = self.windowControllers.first, let hoverBar = (hwc as! HeliumPanelController).hoverBar {
            hoverBar.closeButton?.setNeedsDisplay()
        }
    }
        
    override func write(to url: URL, ofType typeName: String) throws {
        cacheSettings(url)
        
        //  When a document is written, update in global play items
        self.updateChangeCount(.changeCleared)
        UserDefaults.standard.synchronize()

        //  Update UI (red dot in close button) immediately
        if let hwc = self.windowControllers.first, let hoverBar = (hwc as! HeliumPanelController).hoverBar {
            hoverBar.closeButton?.setNeedsDisplay()
        }
    }
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSSaveOperationType) throws {
        do {
            try self.write(to: url, ofType: typeName)
        } catch let error {
            NSApp.presentError(error)
        }
    }
    //MARK:- Actions
    override func makeWindowControllers() {
        makeWindowController("Helium")
    }
    func makeWindowController(_ typeName: String) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = (docType == k.docPlaylists || typeName == k.Playlists)
            ? "PlaylistPanelController"
            : String(format: "%@Controller", typeName)
        
        let controller = storyboard.instantiateController(withIdentifier: identifier) as! NSWindowController
        self.addWindowController(controller)
        
        //  Delegate will close down any observations before closure
        controller.window?.delegate = controller as? NSWindowDelegate
        
        //  Relocate to origin if any
        if self.settings.rect.value != NSZeroRect, let window = controller.window {
            window.setFrameOrigin(self.settings.rect.value.origin)
        }
        else
        {
            controller.window?.offsetFromKeyWindow()
        }
    }

}
