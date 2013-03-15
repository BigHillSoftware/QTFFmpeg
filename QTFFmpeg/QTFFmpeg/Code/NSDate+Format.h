//
//  NSDate+Format.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSDate (Format)

- (NSString *)stringWithFormat:(NSString *)dateFormat;
- (NSString *)stringWithQTFFFormat;

@end
