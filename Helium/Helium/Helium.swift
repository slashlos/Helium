//
//  Helium.swift
//  Helium
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright © 2017 Jaden Geller. All rights reserved.
//

import Foundation

class PlayItem : NSObject {
    var name : String = k.item
    var link : URL = URL.init(string: "http://")!
    var time : TimeInterval
    var rank : Int
    
    override init() {
        name = k.item
        link = URL.init(string: "http://")!
        time = 0.0
        rank = 0
        super.init()
    }
    init(name:String, link:URL, time:TimeInterval, rank:Int) {
        self.name = name
        self.link = link
        self.time = time
        self.rank = rank
        super.init()
    }
    override var description : String {
        return String(format: "%@: %p '%@'", self.className, self, name)
    }
}

class PlayList: NSObject {
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
}

class Document : NSDocument {

    var playlists: Dictionary<String, Any>
    
    override init() {
        // Add your subclass-specific initialization here.

        playlists = Dictionary<String, Any>()
        if let playArray = UserDefaults.standard.array(forKey: UserSettings.Playlists.keyPath) {
            
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
                    list.append(temp)
                }
                let name = play[k.name] as? String
                
                playlists[name!] = list
            }
        }

        super.init()
    }
    
    override class func autosavesInPlace() -> Bool {
        return false
    }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "HeliumController") as! HeliumPanelController
        self.addWindowController(controller)
        
        //  Close down any observations before closure
        controller.window?.delegate = controller
    }
    
    override func data(ofType typeName: String) throws -> Data {
        let data = try PropertyListSerialization.data(fromPropertyList: playlists, format: PropertyListSerialization.PropertyListFormat.xml, options: 0)

        //let data = PropertyListSerialization.data(fromPropertyList: playlists, format: xmlFormat_v1_0, options: 0)
        if data.count > 0 {
            return data
        }

        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        let list = try! PropertyListSerialization.propertyList(from:data, options: [], format: nil) as! [String:Any]
        if list.count > 0 {
            playlists = list
        }

        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from url: URL, ofType typeName: String) throws {
        let data = try Data.init(contentsOf: url)
        do {
            try! self.read(from: data, ofType: typeName)
        }
        
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
    
}
