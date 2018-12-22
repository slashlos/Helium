//
//  AppDelegate.h
//  XHelium
//
//  Created by Carlos D. Santiago on 9/2/18.
//  Copyright © 2018 Carlos D Santiago. All rights reserved.
//
//	https://en.atjason.com/Cocoa/SwiftCocoa_Auto%20Launch%20at%20Login.html

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
	IBOutlet NSWindow * preferenceWindow;
	IBOutlet NSButton * loginAutoStartButton;
	Boolean loginAutoStartAtLaunch;
}

@property (retain) IBOutlet NSWindow * preferenceWindow;
@property (retain) IBOutlet NSButton * loginAutoStartButton;
@property (assign) Boolean loginAutoStartAtLaunch;
@end
