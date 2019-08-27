//
//  ValueTransformers.swift
//  Helium
//
//  Created by Carlos D. Santiago on 4/21/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation

// Convert a numeric to an HMS string and back
class hmsTransformer: ValueTransformer {
    
    // flag indicating transformation is read-write
    internal override class func allowsReverseTransformation() -> Bool {
        return true
    }

    // by default returns value
    internal override func transformedValue(_ value: Any?) -> Any? {
        guard var secs : TimeInterval = value as? TimeInterval, secs > 0 else { return nil }
        let h = Int(secs / 3600)
        secs -= TimeInterval(h*3600)
        let m = Int(secs / 60)
        secs -= TimeInterval(m*60)
        
        //    return optional hms components
        return String(format:"%@%@%02.f",
                      (h > 0 ? String(format:"%d:",h) : ""),
                      (m > 0 ? String(format:"%02d:",m) : ""),
                      secs)
    }

    // by default raises an exception if +allowsReverseTransformation returns NO and otherwise invokes transformedValue:
    internal override func reverseTransformedValue(_ value: Any?) -> Any? {
        return value
    }
}

class rectTransformer: ValueTransformer {
    
    // flag indicating transformation is read-write
    internal override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    // by default returns value
    internal override func transformedValue(_ value: Any?) -> Any? {
        if let rect : NSRect = value as? NSRect {
            return NSStringFromRect(rect)
        }
        return nil
    }
    
    // by default raises an exception if +allowsReverseTransformation returns NO and otherwise invokes transformedValue:
    internal override func reverseTransformedValue(_ value: Any?) -> Any? {
        if let rect: String = value as? String {
            return NSRectFromString(rect)
        }
        return value
    }
}

