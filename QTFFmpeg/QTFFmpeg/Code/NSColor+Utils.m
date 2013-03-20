//
//  NSColor+Utils.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/19/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "NSColor+Utils.h"
#import "NSImage+Utils.h"


@implementation NSColor (Utils)

+ (NSColor *)colorWithCGColorRef:(CGColorRef)CGColorRef;
{
    if (CGColorRef == NULL)
    {
        return nil;
    }
    
    return [NSColor colorWithCIColor:[CIColor colorWithCGColor:CGColorRef]];
}

static void drawCGImagePattern (void *info, CGContextRef context)
{
    CGImageRef image = info;
    
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
}

static void releasePatternInfo (void *info)
{
    CFRelease(info);
}

- (CGColorRef)newCGColorRef;
{
    if ([[self colorSpaceName] isEqualToString:NSPatternColorSpace])
    {
        CGImageRef patternImage = [[self patternImage] CGImage];
        if (!patternImage)
            return NULL;
        
        // bridge a bit to trick Clang into not complaining about the unbalanced
        // retain below -- the image gets released in releasePatternInfo()
        id patternObj = (__bridge id)patternImage;
        
        size_t width = CGImageGetWidth(patternImage);
        size_t height = CGImageGetHeight(patternImage);
        
        CGRect patternBounds = CGRectMake(0, 0, width, height);
        CGPatternRef pattern = CGPatternCreate(
                                               (__bridge_retained void *)patternObj,
                                               patternBounds,
                                               CGAffineTransformIdentity,
                                               width,
                                               height,
                                               kCGPatternTilingConstantSpacingMinimalDistortion,
                                               YES,
                                               &(CGPatternCallbacks){
                                                   .version = 0,
                                                   .drawPattern = &drawCGImagePattern,
                                                   .releaseInfo = &releasePatternInfo
                                               }
                                               );
        
        CGColorSpaceRef colorSpaceRef = CGColorSpaceCreatePattern(NULL);
        
        CGColorRef result = CGColorCreateWithPattern(colorSpaceRef, pattern, (CGFloat[]){ 1.0 });
        
        CGColorSpaceRelease(colorSpaceRef);
        CGPatternRelease(pattern);
        
        return result;
    }
    
    NSColorSpace *colorSpace = [NSColorSpace genericRGBColorSpace];
    NSColor *color = [self colorUsingColorSpace:colorSpace];
    
    NSInteger count = [color numberOfComponents];
    CGFloat components[count];
    [color getComponents:components];
    
    CGColorSpaceRef colorSpaceRef = colorSpace.CGColorSpace;
    CGColorRef result = CGColorCreate(colorSpaceRef, components);
    
    return result;
}

@end
