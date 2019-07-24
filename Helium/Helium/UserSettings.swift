//
//  UserSettings.swift
//  Helium
//
//  Created by Christian Hoffmann on 10/31/15.
//  Copyright © 2015 Jaden Geller. All rights reserved.
//  Copyright (c) 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation

internal struct UserSettings {
    internal class Setting<T> {
        private let key: String
        private let defaultValue: T
        
        init(_ userDefaultsKey: String, defaultValue: T) {
            self.key = userDefaultsKey
            self.defaultValue = defaultValue
        }
        
        var keyPath: String {
            get {
                return self.key
            }
        }
        var `default`: T {
            get {
                return self.defaultValue
            }
        }
        var value: T {
            get {
                return self.get()
            }
            set (value) {
                self.set(value)
                //  Inform all interested parties
                NotificationCenter.default.post(name: Notification.Name(rawValue: self.keyPath), object: nil)
            }
        }
        
        private func get() -> T {
            if let value = UserDefaults.standard.object(forKey: self.key) as? T {
                return value
            } else {
                // Sets default value if failed
                set(self.defaultValue)
                return self.defaultValue
            }
        }
        
        private func set(_ value: T) {
            UserDefaults.standard.set(value as Any, forKey: self.key)
        }
    }
    
    //  Global Defaults keys
    static let DisabledMagicURLs = Setting<Bool>("disabledMagicURLs", defaultValue: false)
    static let CreateNewWindows = Setting<Bool>("createNewWindows", defaultValue: false)
    static let PlaylistThrottle = Setting<Int>("playlistThrottle", defaultValue: 32)

    static let HomePageURL = Setting<String>(
        "homePageURL",
//      defaultValue: "https://cdn.rawgit.com/JadenGeller/Helium/master/helium_start.html"
//      defaultValue: "https://cdn.rawgit.com/slashlos/Helium/master/helium_start.html"
        defaultValue: "https://slashlos.github.io/Helium/helium_start.html"
    )
    static let ReleaseNotesURL = Setting<String>(
        "releaseNotesURL",
        defaultValue: "https://slashlos.github.io/Helium/Help/index.html"
    )
    static let HomePageName = Setting<String>("homePageName", defaultValue: "helium_start")
    
    static let UserAgent = Setting<String>(
        "userAgent",
/*10.11*/        defaultValue: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_5) AppleWebKit/601.6.17 (KHTML, like Gecko) Version/9.1.1 Safari/601.6.17"
//10.12//        defaultValue: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/603.3.8 (KHTML, like Gecko) Version/10.12 Safari/603.3.8"
//10.13//        defaultValue: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/604.5.6 (KHTML, like Gecko) Version/11.0.3 Safari/604.5.6"// Safari

        // swiftlint:disable:previous line_length
    )

    //  User Defaults keys
    static let HistoryName  = Setting<String>("historyName", defaultValue:"History")
    static let HistoryKeep  = Setting<Int>("historyKeep", defaultValue:2048)
    static let HistoryList  = Setting<String>("historyList", defaultValue:"histories")
    static let HideAppMenu  = Setting<Bool>("hideAppMenu", defaultValue: false)
    static let HideZoomIcon = Setting<Bool>("hideZoomIcon", defaultValue: true)
    static let AutoHideTitle = Setting<Bool>("autoHideTitle", defaultValue: false)
    static let AutoSaveDocs = Setting<Bool>("autoSaveDocs", defaultValue: true)
    
    //  Search provider - must match k struct, menu item tags
    static let Search = Setting<Int>("search", defaultValue: 1) // Google
    static let Searches = Setting<Array<String>>("searches", defaultValue: [String]())
    
    //  Developer setting(s)
    static let DeveloperExtrasEnabled = Setting<Bool>("developerExtrasEnabled", defaultValue: false)
}
