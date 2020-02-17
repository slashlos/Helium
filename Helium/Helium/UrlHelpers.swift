//
//  UrlHelpers.swift
//  Helium
//
//  Created by Viktor Oreshkin on 9.5.17.
//  Copyright © 2017 Jaden Geller. All rights reserved.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation

struct UrlHelpers {
    //   Prepends `http://` if scheme no scheme was found
    static func ensureScheme(_ urlString: String) -> String {
        guard let scheme = URL.init(string: urlString)?.scheme, scheme.count > 0 else {
            return "http://" + urlString
        }
        
        return urlString
    }
    
    // https://mathiasbynens.be/demo/url-regex
    static func isValidUA(urlString: String) -> Bool {
        // swiftlint:disable:next force_try
        if urlString.lowercased().hasPrefix("file:"), let url = URL.init(string: urlString) {
            return FileManager.default.fileExists(atPath:url.path)
        }

        let regex = try! NSRegularExpression(pattern: "^(https?://)[^\\s/$.?#].[^\\s]*$")
        return (regex.firstMatch(in: urlString, range: urlString.nsrange) != nil)
    }
}

// MARK: - Magic Handlers
extension UrlHelpers {
    static func doMagic(_ url: URL) -> URL? {
        //  Skip file urls
        if url.isFileURL { return url }
        return UrlHelpers.Magic(url).newUrl
    }
    
    static func doMagic(stringURL: String) -> URL? {
        let stringURL = UrlHelpers.ensureScheme(stringURL)
        if let url = URL(string: stringURL) {
            return UrlHelpers.doMagic(url)
        } else {
            return nil
        }
    }
    
    class Magic {
        fileprivate var modified: URLComponents
        fileprivate var converted: Bool = false
        public var newUrl: URL? {
            return self.converted ? self.modified.url : nil
        }
        
        fileprivate let url: URL
        fileprivate let urlString: String
        
        init(_ url: URL) {
            self.url = url
            self.urlString = url.absoluteString
            
            self.modified = URLComponents()
            self.modified.scheme = url.scheme
            
            // Paranoind check
            if url.host != nil {
                self.converted = self.hYouTube() ||
                    self.hTwitch() ||
                    self.hVimeo() ||
                    self.hYouku() ||
                    self.hDailyMotion()
            }
        }
    }
}

// MARK: Generic Handler Factory - just replaces prefix
extension UrlHelpers.Magic {
    fileprivate static func genericHandlerFactory(prefix: String, replacement: String) -> ((UrlHelpers.Magic) -> Bool) {
        return { (instance: UrlHelpers.Magic) in
            if instance.urlString.hasPrefix(prefix) {
                let urlStringModified = instance.urlString.replacePrefix(prefix, replacement: replacement)
                if let newComponents = URLComponents(string: urlStringModified) {
                    instance.modified = newComponents
                    return true
                }
            }
            return false
        }
    }
}

// MARK: Youku Handler
extension UrlHelpers.Magic {
    private static let YoukuClosure = UrlHelpers.Magic.genericHandlerFactory(
        prefix: "http://v.youku.com/v_show/id_",
        replacement: "http://player.youku.com/embed/")
    
    fileprivate func hYouku() -> Bool {
        return UrlHelpers.Magic.YoukuClosure(self)
    }
}

// MARK: DailyMotion Handler
extension UrlHelpers.Magic {
    private static let DailyMotionShort = UrlHelpers.Magic.genericHandlerFactory(
        prefix: "http://www.dailymotion.com/video/",
        replacement: "http://www.dailymotion.com/embed/video/")
    
    private static let DailyMotionLong = UrlHelpers.Magic.genericHandlerFactory(
        prefix: "http://dai.ly/video/",
        replacement: "http://www.dailymotion.com/embed/video/")
    
    fileprivate func hDailyMotion() -> Bool {
        return UrlHelpers.Magic.DailyMotionLong(self) ||
            UrlHelpers.Magic.DailyMotionShort(self)
    }
}

// MARK: Twitch.tv Handler
extension UrlHelpers.Magic {
    fileprivate func hTwitch() -> Bool {
        // swiftlint:disable:next force_try
        let TwitchRegExp = try! NSRegularExpression(pattern: "https?://(?:www\\.)?twitch\\.tv/([\\w\\d\\_]+)(?:/(\\d+))?")
        
        if let match = TwitchRegExp.firstMatch(in: urlString, range: urlString.nsrange),
            let channel = urlString.substring(with:match.range(at: 1)) {
            var magicd = false
            switch channel {
            case "directory", "products", "p", "user":
                break
            case "videos":
                if let idString = urlString.substring(with:match.range(at: 2)) {
                    modified.query = "html5&video=v" + idString
                    magicd = true
                }
            default:
                modified.query = "html5&channel=" + channel
                magicd = true
            }
            
            if magicd {
                // Enforce https
                modified.scheme = "https"
                modified.host = "player.twitch.tv"
            }
            
            return magicd
        }
        
        return false
    }
}

// MARK: Vimeo Handler
extension UrlHelpers.Magic {
    fileprivate func hVimeo() -> Bool {
        // Enforce https
        let urlStringModified = self.urlString.replacingOccurrences(
            of: "(?:https?://)?(?:www\\.)?vimeo\\.com/(\\d+)",
            with: "https://player.vimeo.com/video/$1",
            options: .regularExpression)
        
        if urlStringModified != self.urlString, let newComponents = URLComponents(string: urlStringModified) {
            self.modified = newComponents
            
            return true
        }
        
        return false
    }
}

// MARK: YouTube Handler
extension UrlHelpers.Magic {
    fileprivate func hYouTube() -> Bool {
        // (video id) (hours)?(minutes)?(seconds)
        // swiftlint:disable:next force_try line_length
        let YTRegExp = try! NSRegularExpression(pattern: "(?:https?://)?(?:www\\.)?(?:youtube\\.com/watch\\?v=|youtu.be/)([\\w\\_\\-]+)(?:[&?]t=(?:(\\d+)h)?(?:(\\d+)m)?(?:(\\d+)s?))?")
        
        if let match = YTRegExp.firstMatch(in: self.urlString, range: self.urlString.nsrange) {
            // Enforce https
            self.modified.scheme = "https"
            self.modified.host = "youtube.com"
            self.modified.path = "/embed/" + self.urlString.substring(with: match.range(at: 1))!
            
            var start = 0
            var multiplier = 60 * 60
            for idx in 2...4 {
                if let tStr = self.urlString.substring(with: match.range(at: idx)), let tInt = Int(tStr) {
                    start += tInt * multiplier
                }
                multiplier /= 60
            }
            if start != 0 {
                self.modified.query = "start=" + String(start)
            }
            
            return true
        }
        
        return false
    }
}

//  read back webloc contents
extension URL {
//  https://medium.com/@francishart/swift-how-to-determine-file-type-4c46fc2afce
    func hasHTMLContent() -> Bool {
        let type = self.pathExtension as CFString
        let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, type, nil)
        
        return UTTypeConformsTo((uti?.takeRetainedValue())!, kUTTypeHTML)
    }
    
    var webloc : URL? {
        get {
            do {
                let data = try Data.init(contentsOf: self) as Data
                let dict = try PropertyListSerialization.propertyList(from:data, options: [], format: nil) as! [String:Any]
                if let urlString = dict["URL"] as? String, let webloc = URL.init(string: urlString) {
                    return webloc
                }
            }
            catch
            {
            }
            return nil
        }
    }
    
    var resourceSpecifier: String {
        get {
            let nrl : NSURL = self as NSURL
            return nrl.resourceSpecifier ?? self.absoluteString
        }
    }
    var simpleSpecifier: String {
        get {
            let str = self.resourceSpecifier
            return str[2..<str.count]
        }
    }
}

extension String {
    var webloc : URL? {
        get {
            if let url = URL.init(string: self) {
                return url
            }
            else
            if let dict : Dictionary = self.propertyList() as? [String:Any] {
                let urlString = dict["URL"] as! String
                if let url = URL.init(string: urlString) {
                    return url
                }
            }
            return nil
        }
    }
}
