//
//  LoginItemAutoStart.swift
//  Helium
//
//  Created by Carlos D. Santiago on 9/2/18.
//  Copyright © 2018 Carlos D. Santiago. All rights reserved.
//
//	https://en.atjason.com/Cocoa/SwiftCocoa_Auto%20Launch%20at%20Login.html

import Cocoa
import ServiceManagement

class MainWindowController: NSWindowController {
	
	@IBAction func set(sender: NSButton) {
		let appBundleIdentifier = "com.slashlos.XHelium"
		let autoLaunch = (sender.state == OnState)
		
		if SMLoginItemSetEnabled(appBundleIdentifier as CFString, autoLaunch) {
			if autoLaunch {
				NSLog("Successfully add login item.")
			} else {
				NSLog("Successfully remove login item.")
			}
			
		} else {
			NSLog("Failed to add login item.")
		}
	}
}
