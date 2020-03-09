//
//  PlaylistPanelController.swift
//  Helium
//
//  Created by Carlos D. Santiago on 2/15/17.
//  Copyright © 2017-2020 Carlos D. Santiago. All rights reserved.
//

import Foundation

class PlaylistPanelController : NSWindowController,NSWindowDelegate {
    
    fileprivate var panel: NSPanel! {
        get {
            return (self.window as! NSPanel)
        }
    }
    fileprivate var pvc: PlaylistViewController {
        get {
            return (self.window?.contentViewController as! PlaylistViewController)
        }
    }

    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        return (document?.displayName)!
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        //  Switch to playlist view windowShouldClose() on close
        panel.delegate = pvc
        panel.isFloatingPanel = true
        
        //  Relocate to origin if any
        panel.windowController?.shouldCascadeWindows = true///.offsetFromKeyWindow()
    }
}
