//
//  NSDate+Format.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "NSDate+Format.h"


NSString *const kQTFFDateFormat = @"yyyy-MM-dd HH:mm:ss Z";


@implementation NSDate (Format)

- (NSString *)stringWithFormat:(NSString *)dateFormat;
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:dateFormat];
    return [formatter stringFromDate:self];
}

- (NSString *)stringWithQTFFFormat;
{
    return [self stringWithFormat:kQTFFDateFormat];
}

@end
