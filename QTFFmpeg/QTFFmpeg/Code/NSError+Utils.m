//
//  NSError+Utils.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "NSError+Utils.h"

@implementation NSError (Utils)

#pragma mark - Initialization

+ (NSError *)errorWithDomain:(NSString *)domain
						code:(int)code
				 description:(NSString *)description;
{
    return [NSError errorWithDomain:domain
                               code:code
                        description:description
                      failureReason:nil
                 recoverySuggestion:nil
                    recoveryOptions:nil];
}

+ (NSError *)errorWithDomain:(NSString *)domain
						code:(int)code
				 description:(NSString *)description
			   failureReason:(NSString *)failureReason
		  recoverySuggestion:(NSString *)recoverySuggestion
             recoveryOptions:(NSArray *)recoveryOptions;
{
    domain = domain ? domain : QTFFGeneralErrorDomain;
    code = (code > QTFFErrorCode_NotAnError) ? code : QTFFErrorCode_General;
    description = description ? description : @"";
    failureReason = failureReason ? failureReason : @"";
    recoverySuggestion = recoverySuggestion ? recoverySuggestion : @"";
    recoveryOptions = recoveryOptions ? recoveryOptions : [NSArray array];
    
    NSArray *objArray = [NSArray arrayWithObjects:
                         description,
                         failureReason,
                         recoverySuggestion,
                         recoveryOptions,
                         nil];
    
    NSArray *keyArray = [NSArray arrayWithObjects:
                         NSLocalizedDescriptionKey,
                         NSLocalizedFailureReasonErrorKey,
                         NSLocalizedRecoverySuggestionErrorKey,
                         NSLocalizedRecoveryOptionsErrorKey,
                         nil];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjects:objArray
                                                         forKeys:keyArray];
    
    return [[NSError alloc] initWithDomain:domain
                                      code:code
                                  userInfo:userInfo];
}

@end
