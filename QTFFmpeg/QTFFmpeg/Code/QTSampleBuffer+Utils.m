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

#pragma mark - FFmpeg methods

- (int64_t)FFmpegPTSWithStartingPresentationTime:(QTTime)startingTime timeBaseDen:(int)timeBaseDen;
{
    QTTime currentTime = self.presentationTime;
    long netTimeValue = currentTime.timeValue - startingTime.timeValue;
    long whole = netTimeValue / currentTime.timeScale;
    long mod = netTimeValue % currentTime.timeScale;
    double timeBaseScale = (double)timeBaseDen / (double)currentTime.timeScale;
    int64_t ffmpegTime = (whole * timeBaseDen) + ((double)mod * timeBaseScale);
    
    //NSLog(@"FFmpeg presentation time: %lld", ffmpegTime);
    return ffmpegTime;
}

- (int64_t)FFmpegDTSWithStartingDecodeTime:(QTTime)startingTime timeBaseDen:(int)timeBaseDen;
{
    QTTime currentTime = self.decodeTime;
    long netTimeValue = currentTime.timeValue - startingTime.timeValue;
    long whole = netTimeValue / currentTime.timeScale;
    long mod = netTimeValue % currentTime.timeScale;
    double timeBaseScale = (double)timeBaseDen / (double)currentTime.timeScale;
    int64_t ffmpegTime = (whole * timeBaseDen) + ((double)mod * timeBaseScale);
    
    //NSLog(@"FFmpeg decode time: %lld", ffmpegTime);
    return ffmpegTime;
}

- (int64_t)FFmpegDurationWithTimeBaseDen:(int)timeBaseDen;
{
    long whole = self.duration.timeValue / self.duration.timeScale;
    long mod = self.duration.timeValue % self.duration.timeScale;
    double timeBaseScale = (double)timeBaseDen / (double)self.duration.timeScale;
    int64_t ffmpegTime = (whole * timeBaseDen) + ((double)mod * timeBaseScale);
    
    //NSLog(@"FFmpeg duration time: %lld", ffmpegTime);
    return ffmpegTime;
}

#pragma mark - Log output

- (void)logInfo;
{
    NSLog(@"Sample buffer: %@", self.formatDescription.localizedFormatSummary);
    NSLog(@"Sample buffer: Sample rate:  %f", self.sampleRate);
    NSLog(@"Sample buffer: Bytes per packet:  %d", self.bytesPerPacket);
    NSLog(@"Sample buffer: Frames per packet:  %d", self.framesPerPacket);
    NSLog(@"Sample buffer: Bytes per frame:  %d", self.bytesPerFrame);
    NSLog(@"Sample buffer: Channels per frame: %d", self.channelsPerFrame);
    NSLog(@"Sample buffer: Bits per channel: %d", self.bitsPerChannel);
    NSLog(@"Sample buffer: Number of samples: %ld", (unsigned long)self.numberOfSamples);
    NSLog(@"Sample buffer: Is float? %@", self.isFloat ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is big endian? %@", self.isBigEndian ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is little endian? %@", self.isLittleEndian ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is non-mixable? %@", self.isNonMixable ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is aligned high? %@", self.isAlignedHigh ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is packed? %@", self.isPacked ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is non-interleaved? %@", self.isNonInterleaved ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is interleaved? %@", self.isInterleaved ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is signed integer? %@", self.isSignedInteger ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Is unsigned integer? %@", self.isUnsignedInteger ? @"YES" : @"NO");
    NSLog(@"Sample buffer: Decode time: %lld", self.decodeTime.timeValue);
    NSLog(@"Sample buffer: Decode time scale: %ld", self.decodeTime.timeScale);
    NSLog(@"Sample buffer: Presentation time: %lld", self.presentationTime.timeValue);
    NSLog(@"Sample buffer: Presentation time scale: %ld", self.presentationTime.timeScale);
    NSLog(@"Sample buffer: Duration time: %lld", self.duration.timeValue);
    NSLog(@"Sample buffer: Duration time scale: %ld", self.duration.timeScale);
}

@end
