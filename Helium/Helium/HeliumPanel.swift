//
//  Panel.swift
//  Helium
//
//  Created by shdwprince on 8/10/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation
import Cocoa

// Sugar
extension NSPoint {
    static func - (left: NSPoint, right: NSPoint) -> NSPoint {
        return NSPoint(x: left.x - right.x, y: left.y - right.y)
    }
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
            if !event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                previousMouseLocation = nil
            }
        case .leftMouseDown:
            if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
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

class PlaylistsPanel : NSPanel {
    
}

//  Offset a window from the current app key window
extension NSWindow {
    
    var titlebarHeight : CGFloat {
        if self.styleMask.contains(.fullSizeContentView), let svHeight = self.standardWindowButton(.closeButton)?.superview?.frame.height {
            return svHeight
        }

        let contentHeight = contentRect(forFrameRect: frame).height
        let titlebarHeight = frame.height - contentHeight
        return titlebarHeight > k.TitleNormal ? k.TitleUtility : titlebarHeight
    }
    
    func offsetFromKeyWindow() {
        if let keyWindow = NSApp.keyWindow {
            self.offsetFromWindow(keyWindow)
        }
        else
        if let mainWindow = NSApp.mainWindow {
            self.offsetFromWindow(mainWindow)
        }
    }

    func offsetFromWindow(_ theWindow: NSWindow) {
        let titleHeight = theWindow.titlebarHeight
        let oldRect = theWindow.frame
        let newRect = self.frame
        
        //	Offset this window from the window by title height pixels to right, just below
        //	either the title bar or the toolbar accounting for incons and/or text.
        
        let x = oldRect.origin.x + k.TitleNormal
        var y = oldRect.origin.y + (oldRect.size.height - newRect.size.height) - titleHeight
        
        if let toolbar = theWindow.toolbar {
            if toolbar.isVisible {
                let item = theWindow.toolbar?.visibleItems?.first
                let size = item?.maxSize
                
                if ((size?.height)! > CGFloat(0)) {
                    y -= (k.ToolbarItemSpacer + (size?.height)!);
                }
                else
                {
                    y -= k.ToolbarItemHeight;
                }
                if theWindow.toolbar?.displayMode == .iconAndLabel {
                    y -= (k.ToolbarItemSpacer + k.ToolbarTextHeight);
                }
                y -= k.ToolbarItemSpacer;
            }
        }
        
        self.setFrameOrigin(NSMakePoint(x,y))
    }
    
    func overlayWindow(_ theWindow: NSWindow) {
        let oldRect = theWindow.frame
        let newRect = self.frame
//        let titleHeight = theWindow.isFloatingPanel ? k.TitleUtility : k.TitleNormal
        
        //    Overlay this window over the chosen window
        
        let x = oldRect.origin.x
        var y = oldRect.origin.y + (oldRect.size.height - newRect.size.height)
        
        if let toolbar = theWindow.toolbar {
            if toolbar.isVisible {
                let item = theWindow.toolbar?.visibleItems?.first
                let size = item?.maxSize
                
                if ((size?.height)! > CGFloat(0)) {
                    y -= (k.ToolbarItemSpacer + (size?.height)!);
                }
                else
                {
                    y -= k.ToolbarItemHeight;
                }
                if theWindow.toolbar?.displayMode == .iconAndLabel {
                    y -= (k.ToolbarItemSpacer + k.ToolbarTextHeight);
                }
                y -= k.ToolbarItemSpacer;
            }
        }
        self.setFrameOrigin(NSMakePoint(x,y))
    }

}
