//
//  NSView+BackgroundColor.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/19/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "NSView+BackgroundColor.h"
#import <QuartzCore/QuartzCore.h>
#import "NSColor+Utils.h"

@implementation NSView (BackgroundColor)

- (void)setBGColor:(NSColor *)color;
{
    CALayer *layer = [CALayer layer];
    
    CGColorRef colorRef = [color newCGColorRef];
    layer.backgroundColor = colorRef;
    [self setLayer:layer];
    [self setWantsLayer:YES];
    CFRelease(colorRef);
}

- (void)setBGColorWithPatternImage:(NSImage *)image;
{
    NSColor *color = [NSColor colorWithPatternImage:image];
    [self setBGColor:color];
}

- (void)setBGColorWithPatternImageNamed:(NSString *)imageName;
{
    NSImage *image = [NSImage imageNamed:imageName];
    [self setBGColorWithPatternImage:image];
}

- (void)setBGColorWithPatternImageFile:(NSString *)imagePath;
{
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
    [self setBGColorWithPatternImage:image];
}

@end
