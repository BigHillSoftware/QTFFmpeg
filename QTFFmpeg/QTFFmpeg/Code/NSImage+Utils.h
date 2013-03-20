//
//  NSImage+Utils.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/19/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (Utils)

+ (NSImage *)imageFromCGImage:(CGImageRef)cgImageRef;
- (CGImageRef)CGImage;

@end
