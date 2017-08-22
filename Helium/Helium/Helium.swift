//
//  Helium.swift
//  Helium
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright © 2017 Jaden Geller. All rights reserved.
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
        self.time = (plist[k.time] as AnyObject).timeInterval ?? 0.0
        self.rank = (plist[k.rank] as AnyObject).intValue ?? 0
        self.rect = (plist[k.rect] as AnyObject).rectValue ?? NSZeroRect
        self.label = (plist[k.label] as AnyObject).boolValue ?? false
        self.hover = (plist[k.hover] as AnyObject).boolValue ?? false
        self.alpha = (plist[k.alpha] as AnyObject).floatValue ?? 0.6
        self.trans = (plist[k.trans] as AnyObject).intValue ?? 0
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

    var playlists: Dictionary<String, Any>
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
    }

    func updateURL(to url: URL, ofType typeName: String) {
        if typeName == "h3w" {
            if let dict = NSDictionary(contentsOf: url) {
                var items: [PlayItem] = [PlayItem]()
                for (key,list) in dict {
                    for item in list as! [Dictionary<String,Any>] {
                        let playitem = PlayItem.init(with: item )
                        items.append(playitem)
                    }
                    var playname = key as! String
                    var nbr = 0
                    while true {
                        if playlists[playname] == nil
                        {
                            break
                        }
                        else
                        {
                            nbr += 1
                            playname = String(format: "%@%@", key as! String,
                                              (nbr == 0 ? "" : String(format: "-%ld", nbr)))
                        }
                    }
                    playlists[playname] = items
                }
            }
        }
        else
        {
            fileType = url.pathExtension
            fileURL = url
        }
        self.save(self)
    }
    
    override init() {
        // Add your subclass-specific initialization here.

        playlists = Dictionary<String, Any>()
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
            return NSApp.applicationIconImage
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
        
        switch typeName {
        case "DocumentType":
            if let playArray = UserDefaults.standard.array(forKey: UserSettings.Playlists.default) {
                for playlist in playArray {
                    let play = playlist as! Dictionary<String,AnyObject>
                    let items = play[k.list] as! [Dictionary <String,AnyObject>]
                    var list : [PlayItem] = [PlayItem]()
                    for playitem in items {
                        let item = PlayItem.init(with: playitem)
                        list.append(item)
                    }
                    let name = play[k.name] as? String
                    if let items = playlists[name!] {
                        for item in items as! [PlayItem] {
                            list.append(item)
                        }
                    }
                    playlists[name!] = list
                }
                break
            }
            
        case "h3w":
            if let dict = NSDictionary(contentsOf: url) {
                let playarray = dict.value(forKey: UserSettings.Playlists.default)
                for playlist in playarray as! [Dictionary<String, Any>] {
                    let play = playlist as Dictionary<String,AnyObject>
                    let items = play[k.list] as! [Dictionary <String,AnyObject>]
                    var list : [PlayItem] = [PlayItem]()
                    for playitem in items {
                        let item = PlayItem.init(with: playitem)
                        list.append(item)
                    }
                    let name = play[k.name] as? String
                    if let items = playlists[name!] {
                        for item in items as! [PlayItem] {
                            list.append(item)
                        }
                    }
                    playlists[name!] = list
                }

                if let fileURL = dict.value(forKey: "fileURL") {
                    self.fileURL = URL(string: (fileURL as! String).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!
                    self.fileType = self.fileURL?.pathExtension
                    break;
                }
            }
            
            //  Since we didn't have a fileURL use url given
            self.fileType = typeName
            self.fileURL = url
            break

        default:
            //  Record url and type, caller will load via notification

            do {
                self.makeWindowControllers()
                NSDocumentController.shared().addDocument(self)

                if let hwc = self.windowControllers.first {
                    hwc.window?.orderFront(self)
                    (hwc.contentViewController as! WebViewController).loadURL(url: url)
                }
                self.fileURL = url
                self.fileType = url.pathExtension
                break
            }
        }
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        switch typeName {
        case "DocumentType":
            if let playArray = UserDefaults.standard.array(forKey: UserSettings.Playlists.default) {
                
                for playlist in playArray {
                    let play = playlist as! Dictionary<String,AnyObject>
                    let items = play[k.list] as! [Dictionary <String,AnyObject>]
                    var list : [PlayItem] = [PlayItem]()
                    for playitem in items {
                        let item = PlayItem.init(with: playitem)
                        list.append(item)
                    }
                    let name = play[k.name] as? String
                    
                    playlists[name!] = list
                }
            }

            self.fileType = url.pathExtension
            self.fileURL = url
            break

        case "h3w":
            // MARK: TODO write playlist and histories with default keys but also save current value
            if let dict = NSDictionary(contentsOf: url) {
                if let playArray = dict.value(forKey: UserSettings.Playlists.default) {
                    for playlist in playArray as! [AnyObject] {
                        let play = playlist as! Dictionary<String,AnyObject>
                        let items = play[k.list] as! [Dictionary <String,AnyObject>]
                        var list : [PlayItem] = [PlayItem]()
                        for playitem in items {
                            let item = PlayItem.init(with: playitem)
                            list.append(item)
                        }
                        let name = play[k.name] as? String
                        if let items = playlists[name!] {
                            for item in items as! [PlayItem] {
                                list.append(item)
                            }
                        }
                        playlists[name!] = list
                    }
                }
                
                if let document = dict.value(forKey: "document") {
                    self.restoreSettings(with: document as! Dictionary<String,Any>)
                    break;
                }
            }
            break
            
        default:
            Swift.print("nyi \(typeName)")
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
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
        switch typeName {
        case "h3w":
            let dict = NSDictionary.init()
            for (name,playitem) in playlists {
                let item = (playitem as! PlayItem).dictionary()
                dict.setValue(item, forKey: name)
            }
            dict.write(to: url, atomically: true)
            break
            
        default:
            //  "DocumentType" writter to user defaults play items dictionary
            var lists = UserDefaults.standard.dictionary(forKey: UserSettings.Playitems.default) ?? NSDictionary.init() as! [String : Any]
            for (name,list) in playlists {
                var items = [Dictionary<String,Any>]()
                for item in list as! [PlayItem] {
                    items.append(item.dictionary())
                }
                lists[name] = items
            }
            
            //  Cache ourselves too
            let item = self.dictionary()
            lists[self.displayName] = item
            
            UserDefaults.standard.set(lists, forKey: UserSettings.Playlists.default)
            UserDefaults.standard.synchronize()
        }
        self.updateChangeCount(.changeCleared)
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
        
        //  Close down any observations before closure
        controller.window?.delegate = controller as? NSWindowDelegate
        self.settings.rect.value = (controller.window?.frame)!
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
