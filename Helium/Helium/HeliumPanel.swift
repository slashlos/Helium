//
//  Panel.swift
//  Helium
//
//  Created by shdwprince on 8/10/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//

import Foundation
import Cocoa

// Sugar
extension NSPoint {
    static func - (left: NSPoint, right: NSPoint) -> NSPoint {
        return NSPoint(x: left.x - right.x, y: left.y - right.y)
    }
}

internal struct PanelSettings {
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
    
    static let autoHideTitle = Setup<Bool>("rawAutoHideTitle", value: false)
    static let disabledFullScreenFloat = Setup<Bool>("disabledFullScreenFloat", value: false)
    static let windowTitle = Setup<String>("windowTitle", value: "Helium")
    static let windowStyle = Setup<Int>("windowStyle", value: 0)
    static let opacityPercentage = Setup<Int>("opacityPercentage", value: 60)
    
    // See values in HeliumPanelController.TranslucencyPreference
    static let translucencyPreference = Setup<Int>("rawTranslucencyPreference", value: 0)
}

class HeliumPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // nil when not dragging
    var previousMouseLocation: NSPoint?
    
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            // If modifier key was released, dragging should be disabled
            if !event.modifierFlags.contains(.command) {
                previousMouseLocation = nil
            }
        case .leftMouseDown:
            if event.modifierFlags.contains(.command) {
                previousMouseLocation = event.locationInWindow
            }
        case .leftMouseUp:
            previousMouseLocation = nil
        case .leftMouseDragged:
            if let previousMouseLocation = previousMouseLocation {
                let delta = previousMouseLocation - event.locationInWindow
                let newOrigin = self.frame.origin - delta
                self.setFrameOrigin(newOrigin)
                return // don't pass event to super
            }
        default:
            break
        }
        
        super.sendEvent(event)
    }
    
}
