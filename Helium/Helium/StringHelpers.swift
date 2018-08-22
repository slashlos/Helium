//
//  StringHelpers.swift
//  Helium
//
//  Created by Samuel Beek on 16/03/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//

import Foundation
import CoreAudioKit

extension String {
    func replacePrefix(_ prefix: String, replacement: String) -> String {
        if hasPrefix(prefix) {
            return replacement + substring(from: prefix.endIndex)
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
        
        let urlRegEx = "((file|https|http)()://)((\\w|-)+)(([.]|[/])((\\w|-)+))+"
        let predicate = NSPredicate(format:"SELF MATCHES %@", argumentArray:[urlRegEx])
        
        return predicate.evaluate(with: self)
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
    func substring(with nsrange: NSRange) -> String? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return self[range]
    }
    
    /// Returns a range equivalent to the given `NSRange`,
    /// or `nil` if the range can't be converted.
    func range(from nsrange: NSRange) -> Range<Index>? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return range
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
    class func string(fromAsset: String) -> String {
        let asset = NSDataAsset.init(name: fromAsset)
        let data = NSData.init(data: (asset?.data)!)
        let text = String.init(data: data as Data, encoding: String.Encoding.utf8)
        
        return text!
    }
}

struct UAHelpers {
    static func isValid(uaString: String) -> Bool {
        // From https://stackoverflow.com/questions/20569000/regex-for-http-user-agent
        let regex = try! NSRegularExpression(pattern: ".+?[/\\s][\\d.]+")
        return (regex.firstMatch(in: uaString, range: uaString.nsrange) != nil)
    }
}
