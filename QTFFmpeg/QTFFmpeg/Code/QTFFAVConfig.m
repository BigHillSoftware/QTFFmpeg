//
//  QTFFAVConfig.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/19/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "QTFFAVConfig.h"
#include <libavutil/channel_layout.h>
#include <libavcodec/avcodec.h>
#import "NSFileManager+Utils.h"

#define VIDEO_CAPTURE_INCLUDE_INTERNAL_CAMERA                   YES
#define VIDEO_CAPTURE_DROP_LATE_FRAMES                          NO
#define VIDEO_CAPTURE_FRAME_RATE                                30.0
#define VIDEO_CAPTURE_SET_PIXEL_BUFFER_SIZE                     YES
#define VIDEO_CAPTURE_PIXEL_BUFFER_WIDTH                        384.0
#define VIDEO_CAPTURE_PIXEL_BUFFER_HEIGHT                       216.0
#define VIDEO_CAPTURE_SET_PIXEL_BUFFER_FORMAT_TYPE              YES
#define VIDEO_CAPTURE_PIXEL_BUFFER_FORMAT_TYPE                  kCVPixelFormatType_422YpCbCr8

#define SHOULD_STREAM_AUDIO                                     YES
#define SHOULD_STREAM_VIDEO                                     NO

#define STREAM_OUTPUT_STREAM_TYPE                               QTFFStreamTypeFile
#define STREAM_OUTPUT_STREAM_NAME                               @"Output.flv"
//#define STREAM_OUTPUT_STREAM_TYPE                               QTFFStreamTypeNetwork
//#define STREAM_OUTPUT_STREAM_NAME                               @"rtmp://localhost:8086/live/Output.flv"
#define STREAM_OUTPUT_FILENAME_EXTENSION                        @"flv"
#define STREAM_OUTPUT_MIME_TYPE                                 @"video/x-flv"

#define VIDEO_INPUT_PIXEL_FORMAT                                AV_PIX_FMT_UYVY422

#define VIDEO_CODEC_PIXEL_FORMAT                                AV_PIX_FMT_YUV420P
#define VIDEO_CODEC_GOP_SIZE                                    15
#define VIDEO_CODEC_BIT_RATE_PREFERRED_KBPS                     372

#define VIDEO_CODEC_FRAME_RATE                                  30
#define VIDEO_CODEC_FRAME_WIDTH                                 352
#define VIDEO_CODEC_FRAME_HEIGHT                                264

//#define AUDIO_INPUT_SAMPLE_RATE                                 44100
//#define AUDIO_INPUT_CHANNEL_LAYOUT                              AV_CH_LAYOUT_STEREO
//#define AUDIO_INPUT_NUMBER_OF_CHANNELS                          2
#define AUDIO_INPUT_SAMPLE_FORMAT                               AV_SAMPLE_FMT_FLTP

#define AUDIO_CODEC_BIT_RATE_PREFERRED_KBPS                     128
//#define AUDIO_CODEC_SAMPLE_RATE                                 44100
#define AUDIO_CODEC_SAMPLE_RATE                                 96000
#define AUDIO_CODEC_CHANNEL_LAYOUT                              AV_CH_LAYOUT_STEREO
#define AUDIO_CODEC_NUMBER_OF_CHANNELS                          2

//#define AUDIO_CODEC_SAMPLE_FORMAT                               AV_SAMPLE_FMT_S16
#define AUDIO_CODEC_SAMPLE_FORMAT                               AV_SAMPLE_FMT_FLTP


static QTFFAVConfig *_sharedInstance;


@implementation QTFFAVConfig

#pragma mark - Shared singleton

+ (QTFFAVConfig *)sharedConfig;
{
    if (! _sharedInstance)
    {
        _sharedInstance = [[QTFFAVConfig alloc] init];
    }
    
    return _sharedInstance;
}

#pragma mark - Initialization 

- (id)init;
{
    self = [super init];
    
    if (self)
    {
        _videoCaptureIncludeInternalCamera = VIDEO_CAPTURE_INCLUDE_INTERNAL_CAMERA;
        _videoCaptureDropLateFrames = VIDEO_CAPTURE_DROP_LATE_FRAMES;
        _videoCaptureFrameRate = VIDEO_CAPTURE_FRAME_RATE;
        _videoCaptureSetPixelBufferSize = VIDEO_CAPTURE_SET_PIXEL_BUFFER_SIZE;
        _videoCapturePixelBufferWidth = VIDEO_CAPTURE_PIXEL_BUFFER_WIDTH;
        _videoCapturePixelBufferHeight = VIDEO_CAPTURE_PIXEL_BUFFER_HEIGHT;
        _videoCaptureSetPixelBufferFormatType = VIDEO_CAPTURE_SET_PIXEL_BUFFER_FORMAT_TYPE;
        _videoCapturePixelBufferFormatType = VIDEO_CAPTURE_PIXEL_BUFFER_FORMAT_TYPE;
        
        _shouldStreamAudio = SHOULD_STREAM_AUDIO;
        _shouldStreamVideo = SHOULD_STREAM_VIDEO;

        NSString *desktopDirectory;
        
        _streamOutputStreamType = STREAM_OUTPUT_STREAM_TYPE;
        _streamOutputFilenameExtension = STREAM_OUTPUT_FILENAME_EXTENSION;
        _streamOutputMIMEType = STREAM_OUTPUT_MIME_TYPE;
        
        switch (_streamOutputStreamType)
        {
            case QTFFStreamTypeFile:
                desktopDirectory = [[[NSFileManager alloc] init] desktopDirectory];
                _streamOutputStreamName = [desktopDirectory stringByAppendingPathComponent:STREAM_OUTPUT_STREAM_NAME];
                break;
                
            case QTFFStreamTypeNetwork:
                _streamOutputStreamName = STREAM_OUTPUT_STREAM_NAME;
                break;
                
            default:
                desktopDirectory = [[[NSFileManager alloc] init] desktopDirectory];
                _streamOutputStreamName = [desktopDirectory stringByAppendingPathComponent:STREAM_OUTPUT_STREAM_NAME];
                break;
        }
        
        _videoInputPixelFormat = VIDEO_INPUT_PIXEL_FORMAT;
        
        _videoCodecPixelFormat = VIDEO_CODEC_PIXEL_FORMAT;
        _videoCodecGOPSize = VIDEO_CODEC_GOP_SIZE;
        _videoCodecBitRatePreferredKbps = VIDEO_CODEC_BIT_RATE_PREFERRED_KBPS;
        _videoCodecFrameRate = VIDEO_CODEC_FRAME_RATE;
        _videoCodecFrameWidth = VIDEO_CODEC_FRAME_WIDTH;
        _videoCodecFrameHeight = VIDEO_CODEC_FRAME_HEIGHT;
        
        //_audioInputSampleRate = AUDIO_INPUT_SAMPLE_RATE;
        //_audioInputChannelLayout = AUDIO_INPUT_CHANNEL_LAYOUT;
        //_audioInputNumberOfChannels = AUDIO_INPUT_NUMBER_OF_CHANNELS;
        _audioInputSampleFormat = AUDIO_INPUT_SAMPLE_FORMAT;
        
        _audioCodecBitRatePreferredKbps = AUDIO_CODEC_BIT_RATE_PREFERRED_KBPS;
        _audioCodecSampleRate = AUDIO_CODEC_SAMPLE_RATE;
        _audioCodecChannelLayout = AUDIO_CODEC_CHANNEL_LAYOUT;
        _audioCodecNumberOfChannels = AUDIO_CODEC_NUMBER_OF_CHANNELS;
        _audioCodecSampleFormat = AUDIO_CODEC_SAMPLE_FORMAT;
    }
    
    return self;
}

#pragma mark - Properties

- (NSTimeInterval)videoCaptureFrameInterval;
{
    return 1.0 / _videoCaptureFrameRate;
}

@end
