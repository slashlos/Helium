//
//  AppDelegate.m
//  XHelium
//
//  Created by Carlos D. Santiago on 9/2/18.
//  Copyright © 2018 Carlos D Santiago. All rights reserved.
//
//	https://en.atjason.com/Cocoa/SwiftCocoa_Auto%20Launch%20at%20Login.html
//
//	Require explicit user action to alter preference value, no defaults bindings.

#import <Foundation/Foundation.h>

#import "AppDelegate.h"

static NSString * LoginAutoStartAtLaunchKeypath = @"loginAutoStartAtLaunch";

@interface AppDelegate ()
@end

@implementation AppDelegate
@synthesize preferenceWindow;
@synthesize loginAutoStartButton;
@synthesize loginAutoStartAtLaunch;

- (IBAction)showPreferenceWindow:(id)sender
{
	[preferenceWindow makeKeyAndOrderFront:sender];
}

- (IBAction)setPreferences:(id)sender
{
	NSUserDefaults * prefs = [NSUserDefaults standardUserDefaults];
	
	[prefs setBool:loginAutoStartAtLaunch forKey:LoginAutoStartAtLaunchKeypath];
	[prefs synchronize];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	NSUserDefaults * prefs = [NSUserDefaults standardUserDefaults];
	
	self.loginAutoStartAtLaunch = [prefs boolForKey: LoginAutoStartAtLaunchKeypath];
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
	[NSApp terminate:self];
	
	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSAppleEventDescriptor * event = [NSAppleEventDescriptor currentProcessDescriptor];
	
	//  We were started as a login item startup save this
	Boolean launchedAsLogInItem = event.eventID == kAEOpenApplication &&
		[event paramDescriptorForKeyword: keyAEPropData].enumCodeValue == keyAELaunchedAsLogInItem;

	//	We're started via a login item, then segue to our main app
	if (launchedAsLogInItem)
	{
		NSArray *pathComponents = [[[NSBundle mainBundle] bundlePath] pathComponents];
		pathComponents = [pathComponents subarrayWithRange:NSMakeRange(0, [pathComponents count] - 4)];
		
		NSString *path = [NSString pathWithComponents:pathComponents];
		[[NSWorkspace sharedWorkspace] launchApplication:path];
		[NSApp terminate:nil];
	}

	//	View/window defining Helium autostart preference via XHelium.
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

@end
