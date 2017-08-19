//
//  Helium.swift
//  Helium
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright © 2017 Jaden Geller. All rights reserved.
//

import Foundation
import QuickLook

class PlayItem : NSObject {
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
    
    override var description : String {
        return String(format: "%@: %p '%@'", self.className, self, name)
    }
    
    required convenience init(coder: NSCoder) {
        let name = coder.decodeObject(forKey: "name") as! String
        let link = URL.init(string: coder.decodeObject(forKey: "link") as! String)
        let time = coder.decodeDouble(forKey: "time")
        let rank = coder.decodeInteger(forKey: "rank")
        let rect = NSRectFromString(coder.decodeObject(forKey: "rect") as! String)
        let label = coder.decodeBool(forKey: "label")
        let hover = coder.decodeBool(forKey: "hover")
        let alpha = coder.decodeFloat(forKey: "alpha")
        let trans = coder.decodeInteger(forKey: "trans")
        self.init(name: name, link: link!, time: time, rank: rank, rect: rect, label: label, hover: hover, alpha: alpha, trans: trans)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(link, forKey: "link")
        coder.encode(time, forKey: "time")
        coder.encode(rank, forKey: "rank")
        coder.encode(NSStringFromRect(rect), forKey: "rect")
        coder.encode(label, forKey: "label")
        coder.encode(hover, forKey: "hover")
        coder.encode(alpha, forKey: "alpha")
        coder.encode(trans, forKey: "trans")
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
    
    func updateURL(to url: URL, ofType typeName: String) {
        if typeName == "h2w" {
            if let dict = NSDictionary(contentsOf: url) {
                if let playArray = dict.value(forKey: UserSettings.Playlists.default) {
                    for playlist in playArray as! [AnyObject] {
                       let play = playlist as! Dictionary<String,AnyObject>
                        let items = play[k.list] as! [Dictionary <String,AnyObject>]
                        var list : [PlayItem] = [PlayItem]()
                        for playitem in items {
                            let item = playitem as Dictionary <String,AnyObject>
                            let name = item[k.name] as! String
                            let path = item[k.link] as! String
                            let time = item[k.time] as? TimeInterval
                            let link = URL.init(string: path)
                            let rank = item[k.rank] as! Int
                            let temp = PlayItem(name:name, link:link!, time:time!, rank:rank)
                            
                            // Non-visible (tableView) cells
                            temp.rect = item[k.rect]?.rectValue ?? NSZeroRect
                            temp.label = item[k.label]?.boolValue ?? false
                            temp.hover = item[k.hover]?.boolValue ?? false
                            temp.alpha = item[k.alpha]?.floatValue ?? 0.6
                            temp.trans = item[k.trans]?.intValue ?? 0
                            
                            list.append(temp)
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
                if let urlString = dict.value(forKey: "fileURL") {
                    self.fileURL = URL(string: (urlString as AnyObject).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!
                    self.fileType = self.fileURL?.pathExtension
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
                        let item = playitem as Dictionary <String,AnyObject>
                        let name = item[k.name] as! String
                        let path = item[k.link] as! String
                        let time = item[k.time] as? TimeInterval
                        let link = URL.init(string: path)
                        let rank = item[k.rank] as! Int
                        let temp = PlayItem(name:name, link:link!, time:time!, rank:rank)
                        
                        // Non-visible (tableView) cells
                        temp.rect = item[k.rect]?.rectValue ?? NSZeroRect
                        temp.label = item[k.label]?.boolValue ?? false
                        temp.hover = item[k.hover]?.boolValue ?? false
                        temp.alpha = item[k.alpha]?.floatValue ?? 0.6
                        temp.trans = item[k.trans]?.intValue ?? 0

                        list.append(temp)
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
            
        case "h2w":
            if let dict = NSDictionary(contentsOf: url) {
                if let playArray = dict.value(forKey: UserSettings.Playlists.default) {
                    for playlist in playArray as! [AnyObject] {
                        let play = playlist as! Dictionary<String,AnyObject>
                        let items = play[k.list] as! [Dictionary <String,AnyObject>]
                        var list : [PlayItem] = [PlayItem]()
                        for playitem in items {
                            let item = playitem as Dictionary <String,AnyObject>
                            let name = item[k.name] as! String
                            let path = item[k.link] as! String
                            let time = item[k.time] as? TimeInterval
                            let link = URL.init(string: path)
                            let rank = item[k.rank] as! Int
                            let temp = PlayItem(name:name, link:link!, time:time!, rank:rank)
                            
                            // Non-visible (tableView) cells
                            temp.rect = item[k.rect]?.rectValue ?? NSZeroRect
                            temp.label = item[k.label]?.boolValue ?? false
                            temp.hover = item[k.hover]?.boolValue ?? false
                            temp.alpha = item[k.alpha]?.floatValue ?? 0.6
                            temp.trans = item[k.trans]?.intValue ?? 0
                            
                            list.append(temp)
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
                        let item = playitem as Dictionary <String,AnyObject>
                        let name = item[k.name] as! String
                        let path = item[k.link] as! String
                        let time = item[k.time] as? TimeInterval
                        let link = URL.init(string: path)
                        let rank = item[k.rank] as! Int
                        let temp = PlayItem(name:name, link:link!, time:time!, rank:rank)
                        
                        // Non-visible (tableView) cells
                        temp.rect = item[k.rect]?.rectValue ?? NSZeroRect
                        temp.label = item[k.label]?.boolValue ?? false
                        temp.hover = item[k.hover]?.boolValue ?? false
                        temp.alpha = item[k.alpha]?.floatValue ?? 0.6
                        temp.trans = item[k.trans]?.intValue ?? 0
                        
                        list.append(temp)
                    }
                    let name = play[k.name] as? String
                    
                    playlists[name!] = list
                }
            }

            self.fileType = url.pathExtension
            self.fileURL = url
            break

        case "h2w":
            // MARK: TODO write playlist and histories with default keys but also save current value
            if let dict = NSDictionary(contentsOf: url) {
                if let playArray = dict.value(forKey: UserSettings.Playlists.default) {
                    for playlist in playArray as! [AnyObject] {
                        let play = playlist as! Dictionary<String,AnyObject>
                        let items = play[k.list] as! [Dictionary <String,AnyObject>]
                        var list : [PlayItem] = [PlayItem]()
                        for playitem in items {
                            let item = playitem as Dictionary <String,AnyObject>
                            let name = item[k.name] as! String
                            let path = item[k.link] as! String
                            let time = item[k.time] as? TimeInterval
                            let link = URL.init(string: path)
                            let rank = item[k.rank] as! Int
                            let temp = PlayItem(name:name, link:link!, time:time!, rank:rank)
                            
                            // Non-visible (tableView) cells
                            temp.rect = item[k.rect]?.rectValue ?? NSZeroRect
                            temp.label = item[k.label]?.boolValue ?? false
                            temp.hover = item[k.hover]?.boolValue ?? false
                            temp.alpha = item[k.alpha]?.floatValue ?? 0.6
                            temp.trans = item[k.trans]?.intValue ?? 0
                            
                            list.append(temp)
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
                
                if let fileURL = dict.value(forKey: "fileURL") {
                    self.fileURL = URL(string: (fileURL as! String).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!
                    self.fileType = self.fileURL?.pathExtension
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
        case "h2w":
            let dict = NSDictionary.init()
            dict.setValue(playlists, forKey: UserSettings.Playlists.default)
            dict.write(to: url, atomically: true)
            break
            
        default:
            //  "DocumentType" writter to user defaults play items dictionary
            var playitems = UserDefaults.standard.dictionary(forKey: UserSettings.Playitems.default)

            for key in playlists.keys {
                for playitem in playlists[key] as! [PlayItem] {
                    let rect = settings.rect.value as NSRect
                    let item : [String:AnyObject] = [k.name  : playitem.name as String as AnyObject,
                                                     k.link  : playitem.link.absoluteString as AnyObject,
                                                     k.time  : playitem.time as AnyObject,
                                                     k.rank  : playitem.rank as AnyObject,
                                                     k.rect  : rect as AnyObject,
                                                     k.label : playitem.label as AnyObject,
                                                     k.hover : playitem.hover as AnyObject,
                                                     k.alpha : playitem.alpha as AnyObject,
                                                     k.trans : playitem.trans as AnyObject]
                    playitems?[playitem.name] = item
                }
            }
            
            //  Cache ourselves too
            let rect = settings.rect.value as NSRect
            let item : [String:AnyObject] = [k.name  : self.displayName as AnyObject,
                                             k.link  : self.fileURL!.absoluteString as AnyObject,
                                             k.time  : settings.time.value as AnyObject,
                                             k.rank  : settings.rank.value as AnyObject,
                                             k.rect  : NSStringFromRect(rect) as AnyObject,
                                             k.label : settings.autoHideTitle.value as AnyObject,
                                             k.hover : settings.disabledFullScreenFloat.value as AnyObject,
                                             k.alpha : settings.opacityPercentage.value as AnyObject,
                                             k.trans : settings.translucencyPreference.value.rawValue as AnyObject]
            playitems?[self.displayName] = item
            
            UserDefaults.standard.set(playitems, forKey: UserSettings.Playitems.default)
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
