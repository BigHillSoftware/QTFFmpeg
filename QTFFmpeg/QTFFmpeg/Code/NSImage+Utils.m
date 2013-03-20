//
//  NSImage+Utils.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/19/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "NSImage+Utils.h"
#import <CoreGraphics/CoreGraphics.h>


@implementation NSImage (Utils)

+ (NSImage *)imageFromCGImage:(CGImageRef)cgImageRef;
{
    return [[NSImage alloc] initWithCGImage:cgImageRef size:CGSizeZero];
}

- (CGImageRef)CGImage;
{
    return [self CGImageForProposedRect:NULL context:[NSGraphicsContext currentContext] hints:nil];
}

@end
