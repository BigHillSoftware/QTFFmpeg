//
//  QTFFAVConfig.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/19/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <libavutil/samplefmt.h>


typedef enum
{
    QTFFStreamTypeFile = 0,
    QTFFStreamTypeNetwork = 1
} QTFFStreamType;


@interface QTFFAVConfig : NSObject


@property (nonatomic, assign) BOOL videoCaptureIncludeInternalCamera;
@property (nonatomic, assign) BOOL videoCaptureDropLateFrames;
@property (nonatomic, assign) NSInteger videoCaptureFrameRate;
@property (nonatomic, readonly) NSTimeInterval videoCaptureFrameInterval;
@property (nonatomic, assign) BOOL videoCaptureSetPixelBufferSize;
@property (nonatomic, assign) CGFloat videoCapturePixelBufferWidth;
@property (nonatomic, assign) CGFloat videoCapturePixelBufferHeight;
@property (nonatomic, assign) BOOL videoCaptureSetPixelBufferFormatType;
@property (nonatomic, assign) NSUInteger videoCapturePixelBufferFormatType;

@property (nonatomic, assign) BOOL shouldStreamAudio;
@property (nonatomic, assign) BOOL shouldStreamVideo;

@property (nonatomic, assign) QTFFStreamType streamOutputStreamType;
@property (nonatomic, strong) NSString *streamOutputStreamName;
@property (nonatomic, strong) NSString *streamOutputFilenameExtension;
@property (nonatomic, strong) NSString *streamOutputMIMEType;

@property (nonatomic, assign) enum AVPixelFormat videoInputPixelFormat;

@property (nonatomic, assign) enum AVPixelFormat videoCodecPixelFormat;
@property (nonatomic, assign) int videoCodecGOPSize;
@property (nonatomic, assign) int videoCodecBitRatePreferredKbps;
@property (nonatomic, assign) int videoCodecFrameRate;
@property (nonatomic, assign) int videoCodecFrameWidth;
@property (nonatomic, assign) int videoCodecFrameHeight;

//@property (nonatomic, assign) int audioInputSampleRate;
//@property (nonatomic, assign) int audioInputChannelLayout;
//@property (nonatomic, assign) int audioInputNumberOfChannels;
@property (nonatomic, assign) enum AVSampleFormat audioInputSampleFormat;

@property (nonatomic, assign) enum AVCodecID audioCodecID;
@property (nonatomic, assign) int audioCodecBitRatePreferredKbps;
@property (nonatomic, assign) int audioCodecSampleRate;
//@property (nonatomic, assign) int audioCodecChannelLayout;
@property (nonatomic, assign) int audioCodecNumberOfChannels;
@property (nonatomic, assign) enum AVSampleFormat audioCodecSampleFormat;

#pragma - Shared singleton

+ (QTFFAVConfig *)sharedConfig;

@end
