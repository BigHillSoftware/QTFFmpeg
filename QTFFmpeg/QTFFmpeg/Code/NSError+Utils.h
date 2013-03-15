//
//  NSError+Utils.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#define QTFFGeneralErrorDomain                                               @"com.bighillsoftware"
#define QTFFVideoErrorDomain                                                 @"com.bighillsoftware.Video"

#define QTFFErrorCode_NotAnError                                             0
#define QTFFErrorCode_General                                                1
#define QTFFErrorCode_VideoStreamingError                                    2


@interface NSError (Utils)

#pragma mark - Initialization

+ (NSError *)errorWithDomain:(NSString *)domain
						code:(int)code
				 description:(NSString *)description;

+ (NSError *)errorWithDomain:(NSString *)domain
						code:(int)code
				 description:(NSString *)description
			   failureReason:(NSString *)failureReason
		  recoverySuggestion:(NSString *)recoverySuggestion
             recoveryOptions:(NSArray *)recoveryOptions;

@end
