//
//  Helium.swift
//  Helium
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright (c) 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation
import QuickLook

class PlayList : NSObject {
    var name : String = k.list
    var list : Array <PlayItem> = Array()
    
    override init() {
        name = k.list
        list = Array <PlayItem> ()
        super.init()
    }
    
    init(name:String, list:Array <PlayItem>) {
        self.name = name
        self.list = list
        super.init()
    }
    
    func listCount() -> Int {
        return list.count
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [String] {
        return ["com.helium.playlist"]
    }
    
    func pasteboardPropertyList(forType type: String) -> Any? {
        if type == "com.helium.playlist" {
            return [name, list]
        }
        else
        {
            Swift.print("pasteboardPropertyList:\(type) unknown")
            return nil
        }
    }
    
    func dictionary() -> Dictionary<String,[Any]> {
        var plist: Dictionary<String,[Any]> = Dictionary()
        var items: [Any] = Array()
        for item in list {
            items.append(item.dictionary)
        }
        plist[name] = items
        return plist
    }
}

class PlayItem : NSObject, NSCoding {
    var name : String = k.item
    var link : URL = URL.init(string: "http://")!
    var time : TimeInterval
    var rank : Int
    var rect : NSRect
    var label: Bool
    var hover: Bool
    var alpha: Float
    var trans: Int
    
    override init() {
        name = k.item
        link = URL.init(string: "http://")!
        time = 0.0
        rank = 0
        rect = NSZeroRect
        label = false
        hover = false
        alpha = 0.6
        trans = 0
        super.init()
    }
    init(name:String, link:URL, time:TimeInterval, rank:Int) {
        self.name = name
        self.link = link
        self.time = time
        self.rank = rank
        self.rect = NSZeroRect
        self.label = false
        self.hover = false
        self.alpha = 0.6
        self.trans = 0
        super.init()
    }
    init(name:String, link:URL, time:TimeInterval, rank:Int, rect:NSRect, label:Bool, hover:Bool, alpha:Float, trans: Int) {
        self.name = name
        self.link = link
        self.time = time
        self.rank = rank
        self.rect = rect
        self.label = label
        self.hover = hover
        self.alpha = alpha
        self.trans = trans
        super.init()
    }
    init(with dictionary: Dictionary<String,Any>) {
        let plist = dictionary as NSDictionary
        self.name = plist[k.name] as! String
        self.link = URL.init(string: plist[k.link] as! String)!
        self.time = (plist[k.time] as AnyObject).doubleValue ?? 0.0
        self.rank = (plist[k.rank] as AnyObject).intValue ?? 0
        self.rect = (plist[k.rect] as AnyObject).rectValue ?? NSZeroRect
        self.label = (plist[k.label] as AnyObject).boolValue ?? false
        self.hover = (plist[k.hover] as AnyObject).boolValue ?? false
        self.alpha = (plist[k.alpha] as AnyObject).floatValue ?? 0.6
        self.trans = (plist[k.trans] as AnyObject).intValue ?? 0
        super.init()
        self.refresh()
    }
    func refresh() {
        if time == 0.0, let appDelegate = NSApp.delegate {
            if let attr = (appDelegate as! AppDelegate).metadataDictionaryForFileAt(link.path) {
                time = attr[kMDItemDurationSeconds] as? Double ?? 0.0
            }
        }
        if rect == NSZeroRect,
            let lists = UserDefaults.standard.dictionary(forKey: UserSettings.Playitems.default),
            let plist: Dictionary<String,Any> = lists[link.absoluteString] as? Dictionary<String, Any> {
            self.rect = NSRectFromString(plist[k.rect] as! String) 
        }
    }
    override var description : String {
        return String(format: "%@: %p '%@'", self.className, self, name)
    }
    
    required convenience init(coder: NSCoder) {
        let name = coder.decodeObject(forKey: k.name) as! String
        let link = URL.init(string: coder.decodeObject(forKey: k.link) as! String)
        let time = coder.decodeDouble(forKey: k.time)
        let rank = coder.decodeInteger(forKey: k.rank)
        let rect = NSRectFromString(coder.decodeObject(forKey: k.rect) as! String)
        let label = coder.decodeBool(forKey: k.label)
        let hover = coder.decodeBool(forKey: k.hover)
        let alpha = coder.decodeFloat(forKey: k.alpha)
        let trans = coder.decodeInteger(forKey: k.trans)
        self.init(name: name, link: link!, time: time, rank: rank, rect: rect,
                  label: label, hover: hover, alpha: alpha, trans: trans)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: k.name)
        coder.encode(link, forKey: k.link)
        coder.encode(time, forKey: k.time)
        coder.encode(rank, forKey: k.rank)
        coder.encode(NSStringFromRect(rect), forKey: k.rect)
        coder.encode(label, forKey: k.label)
        coder.encode(hover, forKey: k.hover)
        coder.encode(alpha, forKey: k.alpha)
        coder.encode(trans, forKey: k.trans)
    }
    
    func dictionary() -> Dictionary<String,Any> {
        var dict: Dictionary<String,Any> = Dictionary()
        dict[k.name] = name
        dict[k.link] = link.absoluteString
        dict[k.time] = time
        dict[k.rank] =  rank
        dict[k.rect] = NSStringFromRect(rect)
        dict[k.label] = label
        dict[k.hover] = hover
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
    let windowURL = Setup<URL>("windowURL", value: URL.init(string: "http://")!)
    let rank = Setup<Int>("rank", value: 0)
    let time = Setup<TimeInterval>("time", value: 0.0)
    let rect = Setup<NSRect>("frame", value: NSMakeRect(0, 0, 0, 0))
    
    // See values in HeliumPanelController.TranslucencyPreference
    let translucencyPreference = Setup<HeliumPanelController.TranslucencyPreference>("rawTranslucencyPreference", value: .never)
}

class HeliumDocumentController : NSDocumentController {
    override func makeDocument(for urlOrNil: URL?, withContentsOf contentsURL: URL, ofType typeName: String) throws -> NSDocument {
        var doc: Document
        do {
            doc = try Document.init(contentsOf: contentsURL, ofType: contentsURL.pathExtension)
            if (urlOrNil != nil) {
                doc.fileURL = urlOrNil
                doc.fileType = urlOrNil?.pathExtension
            }
        } catch let error {
            NSApp.presentError(error)
            doc = try Document.init(contentsOf: contentsURL, ofType: contentsURL.pathExtension)
        }
        return doc
    }
}

class Document : NSDocument {

    var settings: Settings
    
    func dictionary() -> Dictionary<String,Any> {
        var dict: Dictionary<String,Any> = Dictionary()
        dict[k.name] = self.displayName
        dict[k.link] = self.fileURL?.absoluteString
        dict[k.time] = settings.time.value
        dict[k.rank] = settings.rank.value
        dict[k.rect] = NSStringFromRect(settings.rect.value)
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
        item.time = self.settings.time.value
        item.rank = self.settings.rank.value
        item.rect = self.settings.rect.value
        item.label = self.settings.autoHideTitle.value
        item.hover = self.settings.disabledFullScreenFloat.value
        item.alpha = Float(self.settings.opacityPercentage.value)
        item.trans = self.settings.translucencyPreference.value.rawValue
        item.refresh()
        return item
    }
    
    func restoreSettings(with dictionary: Dictionary<String,Any>) {
        let plist = dictionary as NSDictionary
        self.displayName = dictionary[k.name] as! String
        self.fileURL = URL.init(string: plist[k.link] as! String)!
        self.settings.time.value = (plist[k.time] as AnyObject).timeInterval ?? 0.0
        self.settings.rank.value = (plist[k.rank] as AnyObject).intValue ?? 0
        self.settings.rect.value = (plist[k.rect] as AnyObject).rectValue ?? NSZeroRect
        self.settings.autoHideTitle.value = (plist[k.label] as AnyObject).boolValue ?? false
        self.settings.disabledFullScreenFloat.value = (plist[k.hover] as AnyObject).boolValue ?? false
        self.settings.opacityPercentage.value = (plist[k.alpha] as AnyObject).intValue ?? 60
        self.settings.translucencyPreference.value = HeliumPanelController.TranslucencyPreference(rawValue: (plist[k.trans] as AnyObject).intValue ?? 0)!

        if self.settings.time.value == 0.0 {
            let appDelegate = NSApp.delegate as! AppDelegate
            let attr = appDelegate.metadataDictionaryForFileAt((self.fileURL?.path)!)
            if let secs = attr?[kMDItemDurationSeconds] {
                self.settings.time.value = secs as! TimeInterval
            }
        }
        if self.settings.rect.value == NSZeroRect,
            let lists = UserDefaults.standard.dictionary(forKey: UserSettings.Playitems.default),
            let playitem: PlayItem = lists[(self.fileURL?.absoluteString)!] as? PlayItem {
            self.settings.rect.value = playitem.rect
        }
    }
    
    func update(to url: URL, ofType typeName: String) {
        if let dict = NSDictionary(contentsOf: url) {
            if let item = dict.value(forKey: "settings") {
                self.restoreSettings(with: item as! Dictionary<String,Any> )
            }
        }
        fileType = typeName
        fileURL = url
        self.save(self)
    }
    
    func update(with item: PlayItem, ofType typeName: String) {
        self.restoreSettings(with: item.dictionary())
        self.update(to: item.link, ofType: typeName)
        self.save(self)
    }
    
    override init() {
        settings = Settings()
        super.init()
    }
    
    override class func autosavesInPlace() -> Bool {
        return false
    }

    var displayImage: NSImage? {
        get {
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

    convenience init(contentsOf url: URL, ofType typeName: String) throws {
        self.init()
        self.update(to: url, ofType: typeName)
        
        //  Record url and type, caller will load via notification
        do {
            self.makeWindowControllers()
            NSDocumentController.shared().addDocument(self)

            if let hwc = self.windowControllers.first {
                hwc.window?.orderFront(self)
                (hwc.contentViewController as! WebViewController).loadURL(url: url)
            }
        }
    }
    
    convenience init(withPlayitem item: PlayItem) throws {
        self.init()
        self.update(with: item, ofType: item.link.pathExtension)

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
    
    @IBAction override func save(_ sender: (Any)?) {
        if fileURL != nil {
            do {
                try self.write(to: fileURL!, ofType: fileType!)
            } catch let error {
                NSApp.presentError(error)
            }
        }
    }
    
    override func write(to url: URL, ofType typeName: String) throws {
        //  When a document is written, update in global play items
        if var lists = UserDefaults.standard.dictionary(forKey: UserSettings.Playitems.default) {
            lists[url.absoluteString] = self.dictionary()
            UserDefaults.standard.set(lists, forKey: UserSettings.Playitems.default)
            UserDefaults.standard.synchronize()
            self.updateChangeCount(.changeCleared)
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
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "HeliumController") as! NSWindowController
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
        self.save(self)
    }

    @IBAction func newDocument(_ sender: AnyObject) {
        let dc = NSDocumentController.shared()
        let doc = Document.init()
        doc.makeWindowControllers()
        dc.addDocument(doc)
        let wc = doc.windowControllers.first
        let window : NSPanel = wc!.window as! NSPanel as NSPanel

        //  Close down any observations before closure
        window.delegate = wc as? NSWindowDelegate
        self.settings.rect.value = window.frame
        window.makeKeyAndOrderFront(sender)
    }
    
}
