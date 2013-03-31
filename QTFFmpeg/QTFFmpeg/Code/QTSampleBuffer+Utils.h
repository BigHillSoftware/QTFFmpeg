//
//  QTSampleBuffer+Utils.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/26/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <QTKit/QTKit.h>


@interface QTSampleBuffer (Utils)

@property (nonatomic, readonly) AudioStreamBasicDescription audioStreamBasicDescription;
@property (nonatomic, readonly) int formatID;
@property (nonatomic, readonly) int formatFlags;
@property (nonatomic, readonly) float sampleRate;
@property (nonatomic, readonly) int bytesPerPacket;
@property (nonatomic, readonly) int framesPerPacket;
@property (nonatomic, readonly) int bytesPerFrame;
@property (nonatomic, readonly) int channelsPerFrame;
@property (nonatomic, readonly) int bitsPerChannel;
@property (nonatomic, readonly) BOOL isFloat;
@property (nonatomic, readonly) BOOL isBigEndian;
@property (nonatomic, readonly) BOOL isLittleEndian;
@property (nonatomic, readonly) BOOL isNonMixable;
@property (nonatomic, readonly) BOOL isAlignedHigh;
@property (nonatomic, readonly) BOOL isPacked;
@property (nonatomic, readonly) BOOL isNonInterleaved;
@property (nonatomic, readonly) BOOL isInterleaved;
@property (nonatomic, readonly) BOOL isSignedInteger;
@property (nonatomic, readonly) BOOL isUnsignedInteger;

@end
