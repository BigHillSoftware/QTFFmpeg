//
//  AppDelegate.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "QTFFAppLog.h"


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // window config
    [_window setAspectRatio:CGSizeMake(16.0, 9.0)];
    
    [_avViewController startProcessing];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
{
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [_window orderOut:self];
    
    QTFFAppLog(@"App terminated.");
}

#pragma mark - Events

// Handle window closing notifications for your device input

- (BOOL)windowShouldClose:(id)sender;
{
    [_avViewController stopProcessing];

    [[NSApplication sharedApplication] terminate:self];
    
    return YES;
}


@end
