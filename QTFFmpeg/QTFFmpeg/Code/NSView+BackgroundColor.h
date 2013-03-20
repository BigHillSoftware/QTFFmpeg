//
//  NSView+BackgroundColor.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/19/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSView (BackgroundColor)

- (void)setBGColor:(NSColor *)color;
- (void)setBGColorWithPatternImage:(NSImage *)image;
- (void)setBGColorWithPatternImageNamed:(NSString *)imageName;
- (void)setBGColorWithPatternImageFile:(NSString *)imagePath;

@end
