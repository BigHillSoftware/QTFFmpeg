//
//  QTFFAVStreamer.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "QTFFAVStreamer.h"
#include <libavutil/opt.h>
#include <libswresample/swresample.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#import "NSError+Utils.h"
#import "QTFFAppLog.h"
#import "QTFFAVConfig.h"
#import "QTSampleBuffer+Utils.h"


@interface QTFFAVStreamer()
{
    AVFormatContext *_avOutputFormatContext;
    AVOutputFormat *_avOutputFormat;
    
    // audio variables
    AVStream *_audioStream;
    AVFrame *_streamAudioFrame;
    BOOL _hasAudioCodecCapDelay;
    
    // audio source data variables
    int _sourceNumberOfChannels;
    int64_t _sourceChannelLayout;
    int _sourceSampleRate;
    enum AVSampleFormat _sourceSampleFormat;
    int _sourceNumberOfSamples;
    int _sourceLineSize;
    uint8_t **_sourceData;
    
    // audio destination data variables
    int _destinationNumberOfChannels;
    int64_t _destinationChannelLayout;
    int _destinationSampleRate;
    enum AVSampleFormat _destinationSampleFormat;
    int _destinationNumberOfSamples;
    int _destinationLineSize;
    uint8_t **_destinationData;
    
    // audio resampler context
    struct SwrContext *_resamplerCtx;
    
    // audio encoding
    double _audioTimeBaseUnit;
    BOOL _hasFirstSampleBufferAudioFrame;
    QTTime _firstSampleBufferAudioFramePresentationTime;
    int64_t _capturedAudioFramePts;
    
    // video variables
    AVStream *_videoStream;
    AVFrame *_inputVideoFrame;
    AVFrame *_lastStreamVideoFrame;
    AVFrame *_currentStreamVideoFrame;
    
    // image convert context
    struct SwsContext *_imgConvertCtx;
    
    // video encoding
    double _videoTimeBaseUnit;
    BOOL _hasFirstSampleBufferVideoFrame;
    double _firstSampleBufferVideoFramePresentationTime;
    int64_t _capturedVideoFramePts;
    
    // output
    AVPacket _avPacket;
}

@end


@implementation QTFFAVStreamer

#pragma mark - Initialization

- (id)init;
{
    self = [super init];
    
    if (self)
    {
        // audio source data variables
        _sourceNumberOfChannels = -1;
        _sourceChannelLayout = -1;
        _sourceSampleRate = -1;
        _sourceSampleFormat = -1;
        _sourceNumberOfSamples = -1;
        _sourceLineSize = -1;
        _sourceData = NULL;
        
        // audio destination data variables
        _destinationNumberOfChannels = -1;
        _destinationChannelLayout = -1;
        _destinationSampleRate = -1;
        _destinationSampleFormat = -1;
        _destinationNumberOfSamples = -1;
        _destinationLineSize = -1;
        _destinationData = NULL;
    }
    
    return self;
}

#pragma mark - Stream opening and closing

- (BOOL)openStream:(NSError **)error;
{
    @synchronized(self)
    {
        if (! _isStreaming)
        {
            // get the config
            QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
            
            if (! (config.shouldStreamAudio || config.shouldStreamVideo))
            {
                if (error)
                {
                    NSString *message = @"Neither audio nor video was specified to be streamed, no stream opened.";
                    
                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                 code:QTFFErrorCode_VideoStreamingError
                                          description:message];
                }
                
                return NO;
            }
            else
            {
                // log the stream name
                NSString *avContent = config.shouldStreamAudio ? (config.shouldStreamVideo ? @"audio/video" : @"audio only") : (config.shouldStreamVideo ? @"video only" : @"NULL");
                NSString *avOutputType = config.streamOutputStreamType == QTFFStreamTypeFile ? @"file" : @"network";
                QTFFAppLog(@"Opening %@ %@ stream: %@", avContent, avOutputType, config.streamOutputStreamName);
                
                if ([self loadLibraries:error])
                {
                    if ([self createOutputFormatContext:error])
                    {
                        if (config.shouldStreamAudio)
                        {
                            if (! [self createAudioStream:error])
                            {
                                // failed, error already set
                                
                                return NO;
                            }
                            
                            _hasFirstSampleBufferAudioFrame = NO;
                            //_firstSampleBufferAudioFramePresentationTime = {};
                            _capturedAudioFramePts = -1;
                        }
                        
                        if (config.shouldStreamVideo)
                        {
                            if (! [self createVideoStream:error])
                            {
                                // failed, error already set
                                
                                return NO;
                            }
                            
                            _hasFirstSampleBufferVideoFrame = NO;
                            _firstSampleBufferVideoFramePresentationTime = 0.0;
                            _capturedVideoFramePts = -1;
                        }
                        
                        // create the options dictionary, add the appropriate headers
                        AVDictionary *options = NULL;
                        
                        const char *cStreamName = [config.streamOutputStreamName UTF8String];
                        
                        int returnVal = avio_open2(&_avOutputFormatContext->pb, cStreamName, AVIO_FLAG_READ_WRITE, nil, &options);
                        
                        if (returnVal != 0)
                        {
                            if (error)
                            {
                                NSString *message = [NSString stringWithFormat:@"Unable to open the stream output: %@, error: %d", config.streamOutputStreamName, returnVal];
                                
                                *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                             code:QTFFErrorCode_VideoStreamingError
                                                      description:message];
                            }
                            
                            return NO;
                        }
                        
                        // some formats want stream headers to be separate
                        if(_avOutputFormatContext->oformat->flags & AVFMT_GLOBALHEADER)
                        {
                            if (config.shouldStreamAudio)
                            {
                                _audioStream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
                            }
                            
                            if (config.shouldStreamVideo)
                            {
                                _videoStream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
                            }
                        }
                        
                        // write the header
                        returnVal = avformat_write_header(_avOutputFormatContext, NULL);
                        if (returnVal != 0)
                        {
                            if (error)
                            {
                                *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                             code:QTFFErrorCode_VideoStreamingError
                                                      description:[NSString stringWithFormat:@"Unable to write the stream header, error: %d", returnVal]];
                            }
                            
                            return NO;
                        }
                        
                        av_init_packet(&_avPacket);
                        
                        _isStreaming = YES;
                        
                        // everything succeeded
                        
                        return YES;
                    }
                    else
                    {
                        // output format context creation failed, error already set
                        
                        return NO;
                    }
                }
                else
                {
                    // load libraries failed, error already set
                    
                    return NO;
                }
            }
        }
        else
        {
            // already streaming
            
            return YES;
        }
    }
}

- (BOOL)loadLibraries:(NSError **)error;
{
    // initialize the error
    if (error)
    {
        *error = nil;
    }
    
    // initialize libavcodec, and register all codecs and formats
    av_register_all();
    
    // get the config
    QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
    
    if (config.streamOutputStreamType == QTFFStreamTypeNetwork)
    {
        // initialize libavformat network capabilities
        int returnVal = avformat_network_init();
        if (returnVal != 0)
        {
            if (error)
            {
                NSString *message = [NSString stringWithFormat:@"Unable to initialize streaming networking library, error: %d", returnVal];
                
                *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                             code:QTFFErrorCode_VideoStreamingError
                                      description:message];
            }
            
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)createOutputFormatContext:(NSError **)error;
{
    // get the config
    QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
    
    // create the output format
    const char *cStreamName = [config.streamOutputStreamName UTF8String];
    const char *cFileNameExt = [config.streamOutputFilenameExtension UTF8String];
    const char *cMimeType = [config.streamOutputMIMEType UTF8String];
    
    _avOutputFormat = av_guess_format(cStreamName, cFileNameExt, cMimeType);
    
    if (! _avOutputFormat)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                         code:QTFFErrorCode_VideoStreamingError
                                  description:@"Unable to initialize the output stream handler format."];
        }
        
        return NO;
    }
    
    if (config.streamOutputStreamType == QTFFStreamTypeNetwork)
    {
        // set the no file flag so that the properties get set appropriately
        _avOutputFormat->flags = AVFMT_NOFILE;
    }
    
    // create the format context
    int returnVal = avformat_alloc_output_context2(&_avOutputFormatContext, _avOutputFormat, cFileNameExt, cStreamName);
    if (returnVal != 0)
    {
        if (error)
        {
            NSString *message = [NSString stringWithFormat:@"Unable to initialize the output format, error: %d", returnVal];
            
            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                         code:QTFFErrorCode_VideoStreamingError
                                  description:message];
        }
        
        return NO;
    }
    
    return YES;
}

- (BOOL)createAudioStream:(NSError **)error;
{
    // create the audio stream
    _audioStream = nil;
    
    // get the config
    QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
    
    _avOutputFormat->audio_codec = config.audioCodecID;
    const AVCodec *audioCodec = avcodec_find_encoder(_avOutputFormat->audio_codec);
    
    //QTFFAppLog(@"Audio codec: %s", audioCodec->name);
    
    _audioStream = avformat_new_stream(_avOutputFormatContext, audioCodec);
    
    if (! _audioStream)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                         code:QTFFErrorCode_VideoStreamingError
                                  description:[NSString stringWithFormat:@"Unable to create a new audio stream with codec: %u", _avOutputFormat->audio_codec]];
        }
        
        return NO;
    }
    
    AVCodecContext *audioCodecCtx = _audioStream->codec;
    
    // set codec settings
    audioCodecCtx->codec_type = AVMEDIA_TYPE_AUDIO;
    
    int bitRate = config.audioCodecBitRatePreferredKbps * 1000;
    audioCodecCtx->bit_rate = bitRate;
    
    audioCodecCtx->sample_rate = config.audioCodecSampleRate;
    audioCodecCtx->channels = config.audioCodecNumberOfChannels;
    audioCodecCtx->channel_layout = av_get_default_channel_layout(config.audioCodecNumberOfChannels);
    audioCodecCtx->sample_fmt = config.audioCodecSampleFormat;
    audioCodecCtx->time_base.num = 1;
    audioCodecCtx->time_base.den = config.audioCodecSampleRate;
    
    if (avcodec_open2(audioCodecCtx, audioCodec, NULL) < 0)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                         code:QTFFErrorCode_VideoStreamingError
                                  description:@"Could not open audio codec."];
        }
        
        return NO;
    }
    
    //QTFFAppLog(@"Audio codec frame size: %d", audioCodecCtx->frame_size);
    
    _hasAudioCodecCapDelay = audioCodecCtx->codec->capabilities & CODEC_CAP_DELAY;
    _audioTimeBaseUnit = ((double)audioCodecCtx->time_base.num / (double)audioCodecCtx->time_base.den);
    
    // initialize the output audio frame
    _streamAudioFrame = avcodec_alloc_frame();
    
    return YES;
}

- (void)closeAudioStream;
{
    if (_audioStream)
    {
        if (_hasAudioCodecCapDelay)
        {
            // flush the audio codec
            
            // get the codec context
            AVCodecContext *codecCtx = _audioStream->codec;
            int gotPacket;
            
            do {
                _avPacket.data = NULL;
                _avPacket.size = 0;
                gotPacket = 0;
                
                int returnVal = avcodec_encode_audio2(codecCtx, &_avPacket, NULL, &gotPacket);
                
                if (returnVal != 0)
                {
                    QTFFAppLog(@"Unable to flush the audio frame, error: %d", returnVal);
                    break;
                }
                
                // if a packet was returned, write it to the network stream. The codec may take several calls before returning a packet.
                // only when there is a full packet returned for streaming should writing be attempted.
                if (gotPacket == 1)
                {
                    //if (! _hasCodecCapDelay)
                    //{
                    _avPacket.pts = av_rescale_q(_capturedAudioFramePts, codecCtx->time_base, _audioStream->time_base);
                    _avPacket.dts = _avPacket.pts;
                    //}
                    
                    //QTFFAppLog(@"Pre-writing audio pts: %lld", _avPacket.pts);
                    
                    _avPacket.flags |= AV_PKT_FLAG_KEY;
                    _avPacket.stream_index = _audioStream->index;
                    
                    // write the frame
                    returnVal = av_interleaved_write_frame(_avOutputFormatContext, &_avPacket);
                    //returnVal = av_write_frame(_avOutputFormatContext, &_avPacket);
                    
                    if (returnVal != 0)
                    {
                        QTFFAppLog(@"Unable to write the flushed audio frame to the stream, error: %d", returnVal);
                        
                        // release the packet
                        av_free_packet(&_avPacket);
                        
                        break;
                    }
                    
                    // release the packet
                    av_free_packet(&_avPacket);
                }
            } while (gotPacket == 1);
        }
        
        // release resources
        [self releaseAudioMemory];
        
        avcodec_close(_audioStream->codec);
    }
    
    if (_streamAudioFrame)
    {
        av_frame_free(&_streamAudioFrame);
    }
}

- (BOOL)createVideoStream:(NSError **)error;
{
    // create the video stream
    _videoStream = nil;
    if (_avOutputFormat->video_codec == CODEC_ID_NONE)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                         code:QTFFErrorCode_VideoStreamingError
                                  description:@"Unable to create a new video stream, required codec unknown."];
        }
        
        return NO;
    }
    
    const AVCodec *videoCodec = avcodec_find_encoder(_avOutputFormat->video_codec);
    _videoStream = avformat_new_stream(_avOutputFormatContext, videoCodec);
    
    if (! _videoStream)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                         code:QTFFErrorCode_VideoStreamingError
                                  description:[NSString stringWithFormat:@"Unable to create a new video stream with codec: %u", _avOutputFormat->video_codec]];
        }
        
        return NO;
    }
    
    // get the config
    QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
    
    // set codec settings
    int bitRate = config.videoCodecBitRatePreferredKbps * 1000;
    
    AVCodecContext *videoCodecCtx = _videoStream->codec;
    videoCodecCtx->pix_fmt = config.videoCodecPixelFormat;
    videoCodecCtx->gop_size = config.videoCodecGOPSize;
    videoCodecCtx->width = config.videoCodecFrameWidth;
    videoCodecCtx->height = config.videoCodecFrameHeight;
    videoCodecCtx->bit_rate = bitRate;
    videoCodecCtx->time_base.den = config.videoCodecFrameRate;
    videoCodecCtx->time_base.num = 1;
    _videoTimeBaseUnit = ((double)videoCodecCtx->time_base.num / (double)videoCodecCtx->time_base.den);
    
    // open the video codec
    if (avcodec_open2(videoCodecCtx, videoCodec, NULL) < 0)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                         code:QTFFErrorCode_VideoStreamingError
                                  description:@"Could not open video codec."];
        }
        
        return NO;
    }
    
    // initialize the input video frame
    _inputVideoFrame = [self videoFrameWithPixelFormat:config.videoInputPixelFormat
                                                 width:videoCodecCtx->width
                                                height:videoCodecCtx->height];
    
    // initialize the output video frame
    _currentStreamVideoFrame = [self videoFrameWithPixelFormat:videoCodecCtx->pix_fmt
                                                         width:videoCodecCtx->width
                                                        height:videoCodecCtx->height];
    
    _lastStreamVideoFrame = [self videoFrameWithPixelFormat:videoCodecCtx->pix_fmt
                                                      width:videoCodecCtx->width
                                                     height:videoCodecCtx->height];
    
    return YES;
}

- (void)closeVideoStream;
{
    sws_freeContext(_imgConvertCtx);
    
    if (_videoStream)
    {
        avcodec_close(_videoStream->codec);
    }
    
    if (_inputVideoFrame)
    {
        av_frame_free(&_inputVideoFrame);
    }
    
    if (_lastStreamVideoFrame)
    {
        av_frame_free(&_lastStreamVideoFrame);
    }
    
    if (_currentStreamVideoFrame)
    {
        av_frame_free(&_currentStreamVideoFrame);
    }
}

- (BOOL)closeStream:(NSError **)error;
{
    @synchronized(self)
    {
        if (_isStreaming)
        {
            // flip the streaming flag
            _isStreaming = NO;
            
            // get the config
            QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
            
            NSString *avContent = config.shouldStreamAudio ? (config.shouldStreamVideo ? @"audio/video" : @"audio only") : (config.shouldStreamVideo ? @"video only" : @"NULL");
            NSString *avOutputType = config.streamOutputStreamType == QTFFStreamTypeFile ? @"file" : @"network";
            QTFFAppLog(@"Closing %@ %@ stream: %@", avContent, avOutputType, config.streamOutputStreamName);
            
            // initialize the error
            if (error)
            {
                *error = nil;
            }
            
            // cleanup the audio stream
            if (config.shouldStreamAudio)
            {
                [self closeAudioStream];
            }
            
            // cleanup the video stream
            if (config.shouldStreamVideo)
            {
                [self closeVideoStream];
            }
            
            // write the trailer
            QTFFAppLog(@"Writing the stream trailer.");
            int returnVal = av_write_trailer(_avOutputFormatContext);
            
            // close the io
            avio_closep(&_avOutputFormatContext->pb);
            
            // free the packet
            av_free_packet(&_avPacket);
            
            // free the context
            avformat_free_context(_avOutputFormatContext);
            _avOutputFormatContext = nil;
            _avOutputFormat = nil;
            
            if (returnVal != 0)
            {
                if (error)
                {
                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                 code:QTFFErrorCode_VideoStreamingError
                                          description:[NSString stringWithFormat:@"Unable to write the video stream trailer, error: %d", returnVal]];
                }
                
                return NO;
            }
        }
    }
    
    return YES;
}

#pragma mark - Frame streaming

- (BOOL)streamAudioFrame:(QTSampleBuffer *)sampleBuffer
                   error:(NSError **)error;
{
    @synchronized(self)
    {
        // get the config
        QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
        
        if (config.shouldStreamAudio)
        {
            if (_isStreaming)
            {
                // get the codec context
                AVCodecContext *codecCtx = _audioStream->codec;
                
                // source data variables
                
                // determine sample format
                enum AVSampleFormat sourceSampleFormat;
                
                //[sampleBuffer logInfo];
                
                if (sampleBuffer.isFloat)
                {
                    sourceSampleFormat = AV_SAMPLE_FMT_FLTP;
                }
                else
                {
                    if (sampleBuffer.isSignedInteger)
                    {
                        sourceSampleFormat = AV_SAMPLE_FMT_S32P;
                    }
                    else
                    {
                        if (error)
                        {
                            NSString *description = @"Incompatible input sample format.";
                            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                         code:QTFFErrorCode_VideoStreamingError
                                                  description:description];
                        }
                        
                        return NO;
                    }
                }
                
                int returnVal;
                
                if (codecCtx->channels != sampleBuffer.channelsPerFrame)
                {
                    codecCtx->channels = sampleBuffer.channelsPerFrame;
                    codecCtx->channel_layout = av_get_default_channel_layout(_sourceNumberOfChannels);
                }
                
                if (_sourceNumberOfChannels != sampleBuffer.channelsPerFrame ||
                    _sourceSampleRate != sampleBuffer.sampleRate ||
                    _sourceSampleFormat != sourceSampleFormat ||
                    _sourceNumberOfSamples != (int)(sampleBuffer.numberOfSamples))
                {                    
                    // release existing resources
                    [self releaseAudioMemory];
                    
                    // set source data variables
                    _sourceNumberOfChannels = sampleBuffer.channelsPerFrame;
                    _sourceChannelLayout = av_get_default_channel_layout(_sourceNumberOfChannels);
                    _sourceSampleRate = sampleBuffer.sampleRate;
                    _sourceSampleFormat = sourceSampleFormat;
                    _sourceNumberOfSamples = (int)(sampleBuffer.numberOfSamples);
                    _sourceLineSize = 0;
                    _sourceData = NULL;
                    
                    // allocate the source samples buffer
                    returnVal = av_samples_alloc_array_and_samples(&_sourceData,
                                                                   &_sourceLineSize,
                                                                   _sourceNumberOfChannels,
                                                                   _sourceNumberOfSamples,
                                                                   _sourceSampleFormat,
                                                                   0);
                    
                    if (returnVal < 0)
                    {
                        if (error)
                        {
                            NSString *description = [NSString stringWithFormat:@"Unable to allocate source samples, error: %d", returnVal];
                            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                         code:QTFFErrorCode_VideoStreamingError
                                                  description:description];
                        }
                        
                        // release resources
                        [self releaseAudioMemory];
                        
                        return NO;
                    }
                    
                    // set destination data variables
                    _destinationNumberOfChannels = codecCtx->channels;
                    _destinationChannelLayout = codecCtx->channel_layout;
                    _destinationSampleRate = codecCtx->sample_rate;
                    _destinationSampleFormat = codecCtx->sample_fmt;
                    _destinationLineSize = 0;
                    _destinationData = NULL;
                    
                    _resamplerCtx = swr_alloc_set_opts(NULL,
                                                       _destinationChannelLayout,
                                                       _destinationSampleFormat,
                                                       _destinationSampleRate,
                                                       _sourceChannelLayout,
                                                       _sourceSampleFormat,
                                                       _sourceSampleRate,
                                                       0,
                                                       NULL);
                    
                    if (_resamplerCtx == NULL)
                    {
                        if (error)
                        {
                            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                         code:QTFFErrorCode_VideoStreamingError
                                                  description:@"Unable to create the resampler context for the audio frame."];
                        }
                        
                        // release resources
                        [self releaseAudioMemory];
                        
                        return NO;
                    }
                    
                    // initialize the resampling context
                    returnVal = swr_init(_resamplerCtx);
                    
                    if (returnVal < 0)
                    {
                        if (error)
                        {
                            NSString *description = [NSString stringWithFormat:@"Unable to init the resampler context, error: %d", returnVal];
                            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                         code:QTFFErrorCode_VideoStreamingError
                                                  description:description];
                        }
                        
                        // release resources
                        [self releaseAudioMemory];
                        
                        return NO;
                    }
                    
                    _destinationNumberOfSamples = (int)av_rescale_rnd(swr_get_delay(_resamplerCtx, _sourceSampleRate) + _sourceNumberOfSamples, _destinationSampleRate, _sourceSampleRate, AV_ROUND_UP);
                    //QTFFAppLog(@"Calculated destination samples: %d, codec destination samples: %d", _destinationNumberOfSamples, codecCtx->frame_size);
                                        
                    // allocate the destination samples buffer
                    returnVal = av_samples_alloc_array_and_samples(&_destinationData,
                                                                   &_destinationLineSize,
                                                                   _destinationNumberOfChannels,
                                                                   _destinationNumberOfSamples,
                                                                   _destinationSampleFormat,
                                                                   0);
                    
                    if (returnVal < 0)
                    {
                        if (error)
                        {
                            NSString *description = [NSString stringWithFormat:@"Unable to allocate destination samples, error: %d", returnVal];
                            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                         code:QTFFErrorCode_VideoStreamingError
                                                  description:description];
                        }
                        
                        // release resources
                        [self releaseAudioMemory];
                        
                        return NO;
                    }
                }
                
                // assign source data
                AudioBufferList *tempAudioBufferList = [sampleBuffer audioBufferListWithOptions:0];
                
                for (uint j = 0; j < _sourceNumberOfChannels; j++)
                {
                    float *channelData = (float *)_sourceData[j];
                    float *captureBuffer = tempAudioBufferList->mBuffers[j].mData;
                    
                    for (uint i = 0; i < _sourceNumberOfSamples; i++)
                    {
                        channelData[i] = captureBuffer[i];
                    }
                }
                
                // convert to destination format
                returnVal = swr_convert(_resamplerCtx,
                                        _destinationData,
                                        _destinationNumberOfSamples,
                                        (const uint8_t **)_sourceData,
                                        _sourceNumberOfSamples);
                
                if (returnVal < 0)
                {
                    if (error)
                    {
                        NSString *description = [NSString stringWithFormat:@"Resampling failed, error: %d", returnVal];
                        *error = [NSError errorWithDomain:QTFFVideoErrorDomain code:QTFFErrorCode_VideoStreamingError description:description];
                    }
                    
                    // release resources
                    [self releaseAudioMemory];
                    
                    return NO;
                }
                
                // calcuate the pts from last pts to the current presentation time
                
                if (! _hasFirstSampleBufferAudioFrame)
                {
                    _hasFirstSampleBufferAudioFrame = YES;
                    _firstSampleBufferAudioFramePresentationTime = sampleBuffer.presentationTime;
                    _capturedAudioFramePts = 0;
                }
                else
                {
                    _capturedAudioFramePts = [sampleBuffer FFmpegPTSWithStartingPresentationTime:_firstSampleBufferAudioFramePresentationTime timeBaseDen:codecCtx->time_base.den];
                }
                
                //QTFFAppLog(@"Captured audio frame pts: %lld", _capturedAudioFramePts);
                //long duration = [sampleBuffer FFmpegDurationWithTimeBaseDen:codecCtx->time_base.den];
                //QTFFAppLog(@"Captured audio frame duration: %ld", duration);
                
                int sampleIndex = 0;
                int frameNumberOfSamples = 0;
                int totalNumberOfSamplesLeftToEncode = _destinationNumberOfSamples;
                
                while (totalNumberOfSamplesLeftToEncode > 0)
                {
                    if (totalNumberOfSamplesLeftToEncode < codecCtx->frame_size)
                    {
                        frameNumberOfSamples = totalNumberOfSamplesLeftToEncode;
                    }
                    else
                    {
                        frameNumberOfSamples = codecCtx->frame_size;
                    }
                    
                    int bufferSize = av_samples_get_buffer_size(&_destinationLineSize,
                                                                _destinationNumberOfChannels,
                                                                frameNumberOfSamples,
                                                                _destinationSampleFormat,
                                                                0);
                    
                    _streamAudioFrame->nb_samples = frameNumberOfSamples;
                    _streamAudioFrame->format = codecCtx->sample_fmt;
                    _streamAudioFrame->channel_layout = codecCtx->channel_layout;
                    _streamAudioFrame->channels = codecCtx->channels;
                    _streamAudioFrame->sample_rate = codecCtx->sample_rate;
                    
                    float *sampleData = (float *)_destinationData[0];
                    returnVal = avcodec_fill_audio_frame(_streamAudioFrame,
                                                         _streamAudioFrame->channels,
                                                         _streamAudioFrame->format,
                                                         //                                                     (const uint8_t *)_destinationData[0],
                                                         (const uint8_t *)&sampleData[sampleIndex],
                                                         bufferSize,
                                                         0);
                    
                    if (returnVal < 0)
                    {
                        if (error)
                        {
                            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                         code:QTFFErrorCode_VideoStreamingError
                                                  description:[NSString stringWithFormat:@"Unable to fill the audio frame with captured audio data, error: %d", returnVal]];
                        }
                        
                        // release resources
                        [self releaseAudioMemory];
                        
                        return NO;
                    }
                    
                    //QTFFAppLog(@"Encoding audio, # samples: %d, # samples left in this buffer (after these) to encode: %d", frameNumberOfSamples, totalNumberOfSamplesLeftToEncode - frameNumberOfSamples);
                    
                    // encode the audio frame, fill a packet for streaming
                    _avPacket.data = NULL;
                    _avPacket.size = 0;
                    int gotPacket;
                    
                    _capturedAudioFramePts += sampleIndex;
                    _avPacket.pts = _capturedAudioFramePts;
                    _avPacket.dts = _avPacket.pts;
                    _avPacket.duration = frameNumberOfSamples;
                    //_avPacket.duration = (double)duration * ((double)frameNumberOfSamples / (double)sampleBuffer.numberOfSamples);
                
                    //QTFFAppLog(@"Pre-encoding audio pts: %lld", _avPacket.pts);
                    //QTFFAppLog(@"Pre-encoding audio duration: %d", _avPacket.duration);
                    
                    // encode the audio
                    returnVal = avcodec_encode_audio2(codecCtx, &_avPacket, _streamAudioFrame, &gotPacket);
                    
                    //                QTFFAppLog(@"Codec context frame size: %d", codecCtx->frame_size);
                    //                QTFFAppLog(@"Frame number of samples: %d", _streamAudioFrame->nb_samples);
                    
                    if (returnVal != 0)
                    {
                        if (error)
                        {
                            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                         code:QTFFErrorCode_VideoStreamingError
                                                  description:[NSString stringWithFormat:@"Unable to encode the audio frame, error: %d", returnVal]];
                        }
                        
                        // release resources
                        [self releaseAudioMemory];
                        
                        return NO;
                    }
                    
                    // if a packet was returned, write it to the network stream. The codec may take several calls before returning a packet.
                    // only when there is a full packet returned for streaming should writing be attempted.
                    if (gotPacket == 1)
                    {
                        //if (! _hasCodecCapDelay)
                        //{
                        _avPacket.pts = av_rescale_q(_capturedAudioFramePts, codecCtx->time_base, _audioStream->time_base);
                        _avPacket.dts = _avPacket.pts;
                        //}
                        
                        //QTFFAppLog(@"Pre-writing audio pts: %lld", _avPacket.pts);
                        
                        _avPacket.flags |= AV_PKT_FLAG_KEY;
                        _avPacket.stream_index = _audioStream->index;
                        
                        // write the frame
                        returnVal = av_interleaved_write_frame(_avOutputFormatContext, &_avPacket);
                        //returnVal = av_write_frame(_avOutputFormatContext, &_avPacket);
                        
                        if (returnVal != 0)
                        {
                            if (error)
                            {
                                *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                             code:QTFFErrorCode_VideoStreamingError
                                                      description:[NSString stringWithFormat:@"Unable to write the audio frame to the stream, error: %d", returnVal]];
                            }
                            
                            // release resources
                            [self releaseAudioMemory];
                            
                            // release the packet
                            av_free_packet(&_avPacket);
                            
                            return NO;
                        }
                        
                        // release the packet
                        av_free_packet(&_avPacket);
                    }
                    
                    sampleIndex += frameNumberOfSamples;
                    totalNumberOfSamplesLeftToEncode -= frameNumberOfSamples;
                }
                
                return YES;
            }
            else
            {
                // not streaming at all, so treat as fine.
                
                return YES;
            }
        }
        else
        {
            // not streaming audio, so treat as fine
            
            return YES;
        }
    }
}

- (BOOL)streamVideoFrame:(CVImageBufferRef)frameBuffer
            sampleBuffer:(QTSampleBuffer *)sampleBuffer
                   error:(NSError **)error;
{
    @synchronized(self)
    {
        // get the config
        QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
        
        if (config.shouldStreamVideo)
        {
            if (_isStreaming)
            {
                // initialize the error
                if (error)
                {
                    *error = nil;
                }
                
                // lock the address of the frame pixel buffer
                CVPixelBufferLockBaseAddress(frameBuffer, 0);
                
                // get the frame's width and height
                int width = (int)CVPixelBufferGetWidth(frameBuffer);
                int height = (int)CVPixelBufferGetHeight(frameBuffer);
                
                unsigned char *frameBufferBaseAddress = (unsigned char *)CVPixelBufferGetBaseAddress(frameBuffer);
                
                // Do something with the raw pixels here
                CVPixelBufferUnlockBaseAddress(frameBuffer, 0);
                
                AVCodecContext *codecCtx = _videoStream->codec;
                
                // must stream a YUV420P picture, so convert the frame if needed
                static int sws_flags = SWS_BICUBIC;
                
                // create a convert context if necessary
                _imgConvertCtx = sws_getCachedContext(_imgConvertCtx,
                                                      width,
                                                      height,
                                                      config.videoInputPixelFormat,
                                                      codecCtx->width,
                                                      codecCtx->height,
                                                      codecCtx->pix_fmt,
                                                      sws_flags,
                                                      NULL,
                                                      NULL,
                                                      NULL);
                
                if (_imgConvertCtx == NULL)
                {
                    if (error)
                    {
                        *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                     code:QTFFErrorCode_VideoStreamingError
                                              description:@"Unable to create the image conversion context for the video frame."];
                    }
                    
                    return NO;
                }
                
                // take the input buffer and fill the input frame
                int returnVal = avpicture_fill((AVPicture*)_inputVideoFrame, frameBufferBaseAddress, config.videoInputPixelFormat, width, height);
                
                if (returnVal < 0)
                {
                    if (error)
                    {
                        *error = [NSError errorWithDomain:QTFFVideoErrorDomain code:QTFFErrorCode_VideoStreamingError description:[NSString stringWithFormat:@"Unable to fill the pre-conversion video frame with captured image data, error: %d", returnVal]];
                    }
                    
                    return NO;
                }
                
                // convert the input frame to an output frame for streaming
                sws_scale(_imgConvertCtx, (const u_int8_t* const*)_inputVideoFrame->data, _inputVideoFrame->linesize,
                          0, codecCtx->height, _currentStreamVideoFrame->data, _currentStreamVideoFrame->linesize);
                
                // calcuate the pts from last pts to the current presentation time
                
                // current presentation time
                double currentCapturedVideoFramePresentationTime = 0.0;
                
                if (! _hasFirstSampleBufferVideoFrame)
                {
                    _hasFirstSampleBufferVideoFrame = YES;
                    _firstSampleBufferVideoFramePresentationTime = (double)sampleBuffer.presentationTime.timeValue / (double)sampleBuffer.presentationTime.timeScale;
                }
                else
                {
                    currentCapturedVideoFramePresentationTime = ((double)sampleBuffer.presentationTime.timeValue / (double)sampleBuffer.presentationTime.timeScale) - _firstSampleBufferVideoFramePresentationTime;
                }
                
                int numberOfNewFramesToBeInserted = 0;
                int numberOfOldFramesToBeInserted = 0;
                
                double lastCapturedVideoFramePresentationTime = _capturedVideoFramePts * _videoTimeBaseUnit;
                
                // calculate old frames to be inserted
                numberOfOldFramesToBeInserted = MAX(0, (int)((currentCapturedVideoFramePresentationTime - lastCapturedVideoFramePresentationTime) / _videoTimeBaseUnit) - 1);
                
                // calculate new frames to be inserted
                double durationTime = (double)sampleBuffer.duration.timeValue / (double)sampleBuffer.duration.timeScale;
                numberOfNewFramesToBeInserted = (int)(durationTime / _videoTimeBaseUnit);
                
                int totalNumberOfFramesToBeInserted = numberOfOldFramesToBeInserted + numberOfNewFramesToBeInserted;
                
                //QTFFAppLog(@"Encoding %d old video frames", numberOfOldFramesToBeInserted);
                //QTFFAppLog(@"Encoding %d new video frames", numberOfNewFramesToBeInserted);
                
                for (int i = 0; i < totalNumberOfFramesToBeInserted; i++)
                {
                    // encode the video frame, fill a packet for streaming
                    _avPacket.data = NULL;
                    _avPacket.size = 0;
                    int gotPacket;
                    
                    _avPacket.pts = ++_capturedVideoFramePts;
                    _avPacket.dts = _avPacket.pts;
                    
                    //QTFFAppLog(@"Pre-encoding video pts: %lld", _capturedVideoFramePts);
                    
                    // set the frame to use
                    AVFrame *theFrame = i < numberOfOldFramesToBeInserted ? _lastStreamVideoFrame : _currentStreamVideoFrame;
                    
                    // encoding
                    returnVal = avcodec_encode_video2(codecCtx, &_avPacket, theFrame, &gotPacket);
                    
                    if (returnVal != 0)
                    {
                        if (error)
                        {
                            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                         code:QTFFErrorCode_VideoStreamingError
                                                  description:[NSString stringWithFormat:@"Unable to encode the video frame, error: %d", returnVal]];
                        }
                        
                        return NO;
                    }
                    
                    // if a packet was returned, write it to the network stream. The codec may take several calls before returning a packet.
                    // only when there is a full packet returned for streaming should writing be attempted.
                    if (gotPacket == 1)
                    {
                        if (codecCtx->coded_frame->pts != AV_NOPTS_VALUE)
                        {
                            _avPacket.pts = av_rescale_q(codecCtx->coded_frame->pts, codecCtx->time_base, _videoStream->time_base);
                        }
                        
                        _avPacket.dts = _avPacket.pts;
                        
                        if(codecCtx->coded_frame->key_frame)
                        {
                            _avPacket.flags |= AV_PKT_FLAG_KEY;
                        }
                        
                        _avPacket.stream_index= _videoStream->index;
                        
                        //QTFFAppLog(@"Pre-writing video pts: %lld", _avPacket.pts);
                        
                        // write the frame
                        returnVal = av_interleaved_write_frame(_avOutputFormatContext, &_avPacket);
                        //returnVal = av_write_frame(_avOutputFormatContext, &_avPacket);
                        
                        if (returnVal != 0)
                        {
                            if (error)
                            {
                                *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                             code:QTFFErrorCode_VideoStreamingError
                                                      description:[NSString stringWithFormat:@"Unable to write the video frame to the stream, error: %d", returnVal]];
                            }
                            
                            // release the packet
                            av_free_packet(&_avPacket);
                            
                            return NO;
                        }
                        
                        // release the packet
                        av_free_packet(&_avPacket);
                    }
                }
                
                AVFrame *tempFrame = _lastStreamVideoFrame;
                _lastStreamVideoFrame = _currentStreamVideoFrame;
                _currentStreamVideoFrame = tempFrame;
                
                return YES;
            }
            else
            {
                // not streaming at all, so treat as fine.
                
                return YES;
            }
        }
        else
        {
            // not streaming video, so treat as fine
            
            return YES;
        }
    }
}

#pragma mark - Helpers

- (AVFrame *)videoFrameWithPixelFormat:(enum AVPixelFormat)pixelFormat width:(int)width height:(int)height;
{
    AVFrame *frame;
    uint8_t *frameBuffer;
    int size;
    
    frame = avcodec_alloc_frame();
    
    if (frame)
    {
        size = avpicture_get_size(pixelFormat, width, height);
        frameBuffer = av_malloc(size);
        
        if (! frameBuffer) {
            av_freep(frameBuffer);
            return nil;
        }
        
        avpicture_fill((AVPicture *)frame, frameBuffer, pixelFormat, width, height);
    }
    else
    {
        QTFFAppLog(@"Can't allocate video frame.");
    }
    
    return frame;
}

- (void)releaseAudioMemory;
{
    // release the source data
    if (_sourceData)
    {
        av_freep(&_sourceData[0]);
    }
    av_freep(&_sourceData);
    
    // audio source data variables
    _sourceNumberOfChannels = -1;
    _sourceChannelLayout = -1;
    _sourceSampleRate = -1;
    _sourceSampleFormat = -1;
    _sourceNumberOfSamples = -1;
    _sourceLineSize = -1;
    _sourceData = NULL;
    
    // release the destination data
    if (_destinationData)
    {
        av_freep(&_destinationData[0]);
    }
    av_freep(&_destinationData);
    
    // audio destination data variables
    _destinationNumberOfChannels = -1;
    _destinationChannelLayout = -1;
    _destinationSampleRate = -1;
    _destinationSampleFormat = -1;
    _destinationNumberOfSamples = -1;
    _destinationLineSize = -1;
    _destinationData = NULL;
    
    // release the resampler context
    swr_free(&_resamplerCtx);
}

@end
