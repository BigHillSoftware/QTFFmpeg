//
//  NSColor+Utils.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/19/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSColor (Utils)

+ (NSColor *)colorWithCGColorRef:(CGColorRef)CGColorRef;
- (CGColorRef)newCGColorRef;

@end
