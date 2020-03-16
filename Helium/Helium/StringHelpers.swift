//
//  StringHelpers.swift
//  Helium
//
//  Created by Samuel Beek on 16/03/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//  Copyright © 2017-2019 Carlos D. Santiago. All rights reserved.
//

import Foundation
import CoreAudioKit

//https://stackoverflow.com/questions/21789770/determine-mime-type-from-nsdata
extension Data {
    private static let mimeTypeSignatures: [UInt8 : String] = [
        0xFF : "image/jpeg",
        0x89 : "image/png",
        0x47 : "image/gif",
        0x49 : "image/tiff",
        0x4D : "image/tiff",
        0x25 : "application/pdf",
        0xD0 : "application/vnd",
        0x46 : "text/plain",
        ]

    var mimeType: String {
        var c: UInt8 = 0
        copyBytes(to: &c, count: 1)
        return Data.mimeTypeSignatures[c] ?? "application/octet-stream"
    }
}

extension String {
    func replacePrefix(_ prefix: String, replacement: String) -> String {
        if hasPrefix(prefix) {
            return replacement + suffix(from: prefix.endIndex)
        }
        else {
            return self
        }
    }
    
    func indexOf(_ target: String) -> Int {
        let range = self.range(of: target)
        if let range = range {
            return self.distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }

    func isValidURL() -> Bool {
        guard let urlComponents = URLComponents.init(string: self), urlComponents.host != nil, urlComponents.url != nil else { return false }
        
        return true
        ///let urlRegEx = "((afp:file|https|http|smb)()://)((\\w|-)+)(([.]|[/])((\\w|-)+))+"
        ///let predicate = NSPredicate(format:"SELF MATCHES %@", argumentArray:[urlRegEx])
        
        ///return predicate.evaluate(with: self)
    }
}

// From http://nshipster.com/nsregularexpression/
extension String {
    /// An `NSRange` that represents the full range of the string.
    var nsrange: NSRange {
        return NSRange(location: 0, length: utf16.count)
    }
    
    /// Returns a substring with the given `NSRange`,
    /// or `nil` if the range can't be converted.
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self)
            else { return nil }
        return self[range]
    }
    
    /// Returns a range equivalent to the given `NSRange`,
    /// or `nil` if the range can't be converted.
    func range(from nsrange: NSRange) -> Range<String.Index>? {
        return Range(nsrange, in: self)
    }
}

extension String {
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }
    
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
}

// From https://stackoverflow.com/questions/45562662/how-can-i-use-string-slicing-subscripts-in-swift-4
extension String {
    subscript(value: NSRange) -> Substring {
        return self[value.lowerBound..<value.upperBound]
    }
}

extension String {
    subscript(value: CountableClosedRange<Int>) -> Substring {
        get {
            return self[index(at: value.lowerBound)...index(at: value.upperBound)]
        }
    }
    
    subscript(value: CountableRange<Int>) -> Substring {
        get {
            return self[index(at: value.lowerBound)..<index(at: value.upperBound)]
        }
    }
    
    subscript(value: PartialRangeUpTo<Int>) -> Substring {
        get {
            return self[..<index(at: value.upperBound)]
        }
    }
    
    subscript(value: PartialRangeThrough<Int>) -> Substring {
        get {
            return self[...index(at: value.upperBound)]
        }
    }
    
    subscript(value: PartialRangeFrom<Int>) -> Substring {
        get {
            return self[index(at: value.lowerBound)...]
        }
    }
    
    func index(at offset: Int) -> String.Index {
        return index(startIndex, offsetBy: offset)
    }
}

// From https://stackoverflow.com/questions/27624331/unique-values-of-array-in-swift
extension Array where Element : Hashable {
    var unique: [Element] {
        return Array(Set(self))
    }
}

// From https://stackoverflow.com/questions/31093678/how-to-get-rid-of-array-brackets-while-printing/31093744#31093744
extension Sequence {
    var list: String {
        return map { "\($0)" }.joined(separator: ", ")
    }
    var listing: String {
        return map { "\($0)" }.joined(separator: "\n")
    }
}

// From https://stackoverflow.com/questions/12837965/converting-nsdictionary-to-xml
/*
extension Any {
    func xmlString() -> String {
        if let booleanValue = (self as? Bool) {
            return String(format: (booleanValue ? "true" : "false"))
        }
        else
        if let intValue = (self as? Int) {
            return String(format: "%d", intValue)
        }
        else
        if let floatValue = (self as? Float) {
            return String(format: "%f", floatValue)
        }
        else
        if let doubleValue = (self as? Double) {
            return String(format: "%f", doubleValue)
        }
        else
        {
            return String(format: "<%@>", self)
        }
    }
}
*/
func toLiteral(_ value: Any) -> String {
    if let booleanValue = (value as? Bool) {
        return String(format: (booleanValue ? "1" : "0"))
    }
    else
    if let intValue = (value as? Int) {
        return String(format: "%d", intValue)
    }
    else
    if let floatValue = (value as? Float) {
        return String(format: "%f", floatValue)
    }
    else
    if let doubleValue = (value as? Double) {
        return String(format: "%f", doubleValue)
    }
    else
    if let stringValue = (value as? String) {
        return stringValue
    }
    else
    if let dictValue: Dictionary<AnyHashable,Any> = (value as? Dictionary<AnyHashable,Any>)
    {
        return dictValue.xmlString(withElement: "Dictionary", isFirstElement: false)
    }
    else
    {
        return ((value as AnyObject).description)
    }
}

extension Array {
    func xmlString(withElement element: String, isFirstElemenet: Bool) -> String {
        var xml = String.init()

        xml.append(String(format: "<%@>\n", element))
        self.forEach { (value) in
            if let array: Array<Any> = (value as? Array<Any>) {
                xml.append(array.xmlString(withElement: "Array", isFirstElemenet: false))
            }
            else
            if let dict: Dictionary<AnyHashable,Any> = (value as? Dictionary<AnyHashable,Any>) {
                xml.append(dict.xmlString(withElement: "Dictionary", isFirstElement: false))
            }
            else
            {/*
                if let booleanValue = (value as? Bool) {
                    xml.append(String(format: (booleanValue ? "true" : "false")))
                }
                else
                if let intValue = (value as? Int) {
                    xml.append(String(format: "%d", intValue))
                }
                else
                if let floatValue = (value as? Float) {
                    xml.append(String(format: "%f", floatValue))
                }
                else
                if let doubleValue = (value as? Double) {
                    xml.append(String(format: "%f", doubleValue))
                }
                else
                {
                    xml.append(String(format: "<%@>", value as! CVarArg))
                }*/
                Swift.print("value: \(value)")
                xml.append(toLiteral(value))
            }
        }
        xml.append(String(format: "<%@>\n", element))

        return xml
    }
}
    
extension Dictionary {
    //  Return an XML string from the dictionary
    func xmlString(withElement element: String, isFirstElement: Bool) -> String {
        var xml = String.init()
        
        if isFirstElement { xml.append("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n") }
        
        xml.append(String(format: "<%@>\n", element))
        for node in self.keys {
            let value = self[node]
            
            if let array: Array<Any> = (value as? Array<Any>) {
                xml.append(array.xmlString(withElement: node as! String, isFirstElemenet: false))
            }
            else
            if let dict: Dictionary<AnyHashable,Any> = (value as? Dictionary<AnyHashable,Any>) {
                xml.append(dict.xmlString(withElement: node as! String, isFirstElement: false))
            }
            else
            {
                xml.append(String(format: "<%@>", node as! CVarArg))
                xml.append(toLiteral(value as Any))
                xml.append(String(format: "</%@>\n", node as! CVarArg))
            }
        }
                
        xml.append(String(format: "</%@>\n", element))

        return xml
    }
    func xmlHTMLString(withElement element: String, isFirstElement: Bool) -> String {
        let xml = self.xmlString(withElement: element, isFirstElement: isFirstElement)
        
        return xml.replacingOccurrences(of: "&", with: "&amp", options: .literal, range: nil)
    }
}

extension NSString {
    class func string(fromAsset: String) -> String {
        let asset = NSDataAsset.init(name: fromAsset)
        let data = NSData.init(data: (asset?.data)!)
        let text = String.init(data: data as Data, encoding: String.Encoding.utf8)
        
        return text!
    }
}

extension NSAttributedString {
    class func string(fromAsset: String) -> NSAttributedString {
        let asset = NSDataAsset.init(name: fromAsset)
        let data = NSData.init(data: (asset?.data)!)
        var text : NSAttributedString
        do {
            text = try NSAttributedString.init(data: data as Data, options:[NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            return text
        } catch {
            let chars = String.init(data: data as Data, encoding: String.Encoding.utf8)
            text = NSAttributedString.init(string: chars!)
            return text
        }
    }
}

extension NSString {
    class func timeAndDate() -> String {
        let dateFMT = DateFormatter()
        dateFMT.locale = Locale(identifier: "en_US_POSIX")
        dateFMT.dateFormat = "yyMMdd"
        let timeFMT = DateFormatter()
        timeFMT.locale = Locale(identifier: "en_US_POSIX")
        timeFMT.dateFormat = "HHmmss"
        let now = Date()

        return String(format: "%@:%@", dateFMT.string(from: now), timeFMT.string(from: now))
    }
}

//  https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex-string-in-swift
extension Data {
    private static let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }

    public func hexEncodedString() -> String {
        return String(self.reduce(into: "".unicodeScalars, { (result, value) in
            result.append(Data.hexAlphabet[Int(value/16)])
            result.append(Data.hexAlphabet[Int(value%16)])
        }))
    }
}

//  https://codereview.stackexchange.com/questions/135424/hex-string-to-bytes-nsdata?newreg=06dfe1d5b9964b928631538c9e48d421
extension String {
    func dataFromHexString() -> Data? {

        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt16) -> UInt8? {
            switch(u) {
            case 0x30 ... 0x39:
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:
                return UInt8(u - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(u - 0x61 + 10)
            default:
                return nil
            }
        }

        let utf16 = self.utf16
        guard let data = NSMutableData(capacity: utf16.count/2) else { return nil }

        var i = utf16.startIndex
        while i != utf16.endIndex {
            guard
                let hi = decodeNibble(u: utf16[i]),
                let lo = decodeNibble(u: utf16[index(i, offsetBy: 1, limitedBy: utf16.endIndex)!])
            else {
                return nil
            }
            var value = hi << 4 + lo
            data.append(&value, length: 1)
            i = index(i, offsetBy: 2, limitedBy: utf16.endIndex)!
        }
        return data as Data
    }
}

struct UAHelpers {
    static func isValidUA(uaString: String) -> Bool {
        // From https://stackoverflow.com/questions/20569000/regex-for-http-user-agent
        let regex = try! NSRegularExpression(pattern: ".+?[/\\s][\\d.]+")
        return (regex.firstMatch(in: uaString, range: uaString.nsrange) != nil)
    }
}
