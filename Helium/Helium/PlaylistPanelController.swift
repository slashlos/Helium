//
//  PlaylistPanelController.swift
//  Helium
//
//  Created by Carlos D. Santiago on 2/15/17.
//  Copyright (c) 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation

class PlaylistPanelController : NSWindowController {
    
    fileprivate var panel: NSPanel! {
        get {
            return (self.window as! NSPanel)
        }
    }

}
