//
//  QTFFAppLogFile.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QTFFAppLogFile : NSObject

#pragma mark - Shared instance

+ (QTFFAppLogFile *)sharedAppLogFile;

#pragma mark - Log file management

- (BOOL)newLogFile;
- (void)closeLogFile;

#pragma mark - Logging

- (BOOL)log:(NSString *)message;

@end
