//
//  QTSampleBuffer+Utils.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/26/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "QTSampleBuffer+Utils.h"


@implementation QTSampleBuffer (Utils)

#pragma mark - Properties

- (AudioStreamBasicDescription)audioStreamBasicDescription;
{
    QTFormatDescription *formatDescription = [self formatDescription];
    NSValue *ASBDValue = [formatDescription attributeForKey:QTFormatDescriptionAudioStreamBasicDescriptionAttribute];
    AudioStreamBasicDescription audioStreamBasicDescription = {0};
    [ASBDValue getValue:&audioStreamBasicDescription];
    
    return audioStreamBasicDescription;
}

- (int)formatID;
{
    return self.audioStreamBasicDescription.mFormatID;
}

- (int)formatFlags;
{
    return self.audioStreamBasicDescription.mFormatFlags;
}

- (float)sampleRate;
{
    return self.audioStreamBasicDescription.mSampleRate;
}

- (int)bytesPerPacket;
{
    return self.audioStreamBasicDescription.mBytesPerPacket;
}

- (int)framesPerPacket;
{
    return self.audioStreamBasicDescription.mFramesPerPacket;
}

- (int)bytesPerFrame;
{
    return self.audioStreamBasicDescription.mBytesPerFrame;
}

- (int)channelsPerFrame;
{
    return self.audioStreamBasicDescription.mChannelsPerFrame;
}

- (int)bitsPerChannel;
{
    return self.audioStreamBasicDescription.mBitsPerChannel;
}

- (BOOL)isFloat;
{
    return (self.formatFlags & kAudioFormatFlagIsFloat) == kAudioFormatFlagIsFloat;
}

- (BOOL)isBigEndian;
{
    return (self.formatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagIsBigEndian;
}

- (BOOL)isLittleEndian;
{
    return ! self.isBigEndian;
}

- (BOOL)isNonMixable;
{
    return (self.formatFlags & kAudioFormatFlagIsNonMixable) == kAudioFormatFlagIsNonMixable;
}

- (BOOL)isAlignedHigh;
{
    return (self.formatFlags & kAudioFormatFlagIsAlignedHigh) == kAudioFormatFlagIsAlignedHigh;
}

- (BOOL)isPacked;
{
    return (self.formatFlags & kAudioFormatFlagIsPacked) == kAudioFormatFlagIsPacked;
}

- (BOOL)isNonInterleaved;
{
    return (self.formatFlags & kAudioFormatFlagIsNonInterleaved) == kAudioFormatFlagIsNonInterleaved;
}

- (BOOL)isInterleaved;
{
    return ! self.isNonInterleaved;
}

- (BOOL)isSignedInteger;
{
    return (self.formatFlags & kAudioFormatFlagIsSignedInteger) == kAudioFormatFlagIsSignedInteger;
}

- (BOOL)isUnsignedInteger;
{
    return ! (self.isFloat || self.isSignedInteger);
}

@end
