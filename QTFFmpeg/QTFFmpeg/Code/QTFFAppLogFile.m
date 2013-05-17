//
//  QTFFAppLogFile.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "QTFFAppLogFile.h"
#import "NSFileManager+Utils.h"
#import "NSDate+Format.h"

#define LOG_FILENAME_DATE_FORMAT @"yyyyMMdd_HHmmss"


static QTFFAppLogFile *_sharedAppLogFile;


@interface QTFFAppLogFile()
{
    NSFileHandle *_fileHandle;
}

@end


@implementation QTFFAppLogFile

#pragma mark - Shared instance

+ (QTFFAppLogFile *)sharedAppLogFile;
{
    if (! _sharedAppLogFile)
    {
        _sharedAppLogFile = [[QTFFAppLogFile alloc] init];
        [_sharedAppLogFile logFirstMessage];
    }
    
    return _sharedAppLogFile;
}

#pragma mark - Memory management

- (void)dealloc;
{
    [self closeLogFile];
}

#pragma mark - Log file management

- (NSString *)newFilePath;
{
    NSString *appSupportDir = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString *appName = [NSBundle mainBundle].bundleIdentifier;
    NSString *dateString = [[NSDate date] stringWithFormat:LOG_FILENAME_DATE_FORMAT];
    NSString *filename = [appSupportDir stringByAppendingFormat:@"/%@-%@.log", appName, dateString];
    
    return filename;
}

- (BOOL)newLogFile;
{
    [self closeLogFile];
    
    NSString *filePath = [self newFilePath];
    
    BOOL success = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    
    if (success)
    {
#ifdef DEBUG
        NSLog(@"Log file created: %@", filePath);
#endif
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    }
    
    return _fileHandle != nil;
}

- (void)closeLogFile;
{
    if (_fileHandle)
    {
        [_fileHandle closeFile];
        _fileHandle = nil;
    }
}

#pragma mark - Logging

- (BOOL)logFirstMessage;
{
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    
    NSString *appName = [infoDict objectForKey:@"CFBundleName"];
    NSString *version = [infoDict objectForKey:@"CFBundleShortVersionString"]; // example: 1.0.0
    NSString *buildNumber = [infoDict objectForKey:@"CFBundleVersion"]; // example: 42
    NSString *message = [NSString stringWithFormat:@"%@, version: %@, build: %@\n", appName, version, buildNumber];
    
    return [_sharedAppLogFile log:message];
}

- (BOOL)log:(NSString *)message;
{
    @synchronized(self)
    {
        if (! _fileHandle)
        {
            [self newLogFile];
        }
        
        if (! _fileHandle)
        {
            return NO;
        }
        else
        {
            NSString *dateString = [[NSDate date] stringWithFormat:LOG_FILENAME_DATE_FORMAT];
            NSString *fullMessage = [NSString stringWithFormat:@"[%@] %@\n", dateString, message];
            NSData *fullMessageData = [fullMessage dataUsingEncoding:NSUTF8StringEncoding];
            [_fileHandle writeData:fullMessageData];
            [_fileHandle synchronizeFile];
            
            return YES;
        }
    }
}

@end
