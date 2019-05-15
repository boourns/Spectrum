/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Main entry point to the FilterDemo application.
*/

#import "AppDelegate.h"
#import "ViewController.h"

static dispatch_once_t onceToken;

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification {
    
    dispatch_once(&onceToken, ^{
        NSApplication *app = [NSApplication sharedApplication];
        app.mainWindow.delegate = (ViewController *)app.mainWindow.contentViewController;
    });
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
