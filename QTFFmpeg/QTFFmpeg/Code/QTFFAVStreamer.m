//
//  QTFFAVStreamer.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "QTFFAVStreamer.h"
#include <libavutil/opt.h>
//#include <libavutil/channel_layout.h>
//#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#import "NSError+Utils.h"
#import "QTFFAppLog.h"
#import "QTFFAVConfig.h"


@interface QTFFAVStreamer()
{
    AVFormatContext *_avOutputFormatContext;
    AVOutputFormat *_avOutputFormat;
    AVStream *_videoStream;
    AVStream *_audioStream;
    AVFrame *_inputVideoFrame;
    AVFrame *_streamVideoFrame;
    //AVFrame *_inputAudioFrame;
    AVFrame *_streamAudioFrame;
    
    BOOL _isStreaming;
}

@end


@implementation QTFFAVStreamer

#pragma mark - Stream opening and closing

- (BOOL)openStream:(NSError **)error;
{
    @synchronized(self)
    {
        if (! _isStreaming)
        {
            // get the config
            QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
            
            QTFFAppLog(@"Opening video stream: %@ of type: %@", config.streamOutputStreamName, config.streamOutputStreamType == QTFFStreamTypeFile ? @"File" : @"Network");
            
            if ([self loadLibraries:error])
            {
                if ([self createOutputFormatContext:error])
                {
                    if ([self createVideoStream:error])
                    {
                        if ([self createAudioStream:error])
                        {
                            // create the options dictionary, add the appropriate headers
                            AVDictionary *options = NULL;
                            
                            const char *cStreamName = [config.streamOutputStreamName UTF8String];
                            
                            int returnVal = avio_open2(&_avOutputFormatContext->pb, cStreamName, AVIO_FLAG_READ_WRITE, nil, &options);
                            
                            if (returnVal != 0)
                            {
                                if (error)
                                {
                                    NSString *message = [NSString stringWithFormat:@"Unable to open a connection to the stream URL %@, error: %d", config.streamOutputStreamName, returnVal];
                                    
                                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                                 code:QTFFErrorCode_VideoStreamingError description:message];
                                }
                                
                                return NO;
                            }
                            
                            // some formats want stream headers to be separate
                            if(_avOutputFormatContext->oformat->flags & AVFMT_GLOBALHEADER)
                            {
                                _videoStream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
                                _audioStream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
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
                            
                            _isStreaming = YES;
                            
                            return YES;
                        }
                    }
                }
            }
            
            return NO;
        }
        
        return YES;
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
    videoCodecCtx->time_base.num = 1;
    videoCodecCtx->time_base.den = config.videoCodecFramesPerSecond;
    
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
    _streamVideoFrame = [self videoFrameWithPixelFormat:videoCodecCtx->pix_fmt
                                                  width:videoCodecCtx->width
                                                 height:videoCodecCtx->height];
    
    return YES;
}

- (BOOL)createAudioStream:(NSError **)error;
{
    // create the audio stream
    _audioStream = nil;
    if (_avOutputFormat->audio_codec == CODEC_ID_NONE)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                         code:QTFFErrorCode_VideoStreamingError
                                  description:@"Unable to create a new audio stream, required codec unknown."];
        }
        
        return NO;
    }
    
    const AVCodec *audioCodec = avcodec_find_encoder(_avOutputFormat->audio_codec);
    
    QTFFAppLog(@"Audio codec: %s", audioCodec->name);
    
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
    
    // get the config
    QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
    
    // set codec settings
    // Bit rate = (sampling rate) × (bit depth) × (number of channels)
    int bitRate = config.audioCodecBitRatePreferredKbps * 1000;
    
    audioCodecCtx->bit_rate = bitRate;
    audioCodecCtx->sample_rate = config.audioCodecSampleRate;
    audioCodecCtx->channel_layout = config.audioCodecChannelLayout;
    audioCodecCtx->channels = config.audioCodecNumberOfChannels;
    audioCodecCtx->sample_fmt = config.audioCodecSampleFormat;
    audioCodecCtx->codec_type = AVMEDIA_TYPE_AUDIO;
    
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
    
    // initialize the input audio frame
    //_inputAudioFrame = [self audioFrame];
    
    // initialize the output audio frame
    _streamAudioFrame = [self newAudioFrame];
    
    return YES;
}

- (BOOL)closeStream:(NSError **)error;
{
    @synchronized(self)
    {
        if (_isStreaming)
        {
            // get the config
            QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
            
            QTFFAppLog(@"Closing the video stream: %@", config.streamOutputStreamName);
            
            // initialize the error
            if (error)
            {
                *error = nil;
            }
            
            // write the trailer
            QTFFAppLog(@"Writing the video stream trailer.");
            int returnVal = av_write_trailer(_avOutputFormatContext);
            
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
                
                _isStreaming = NO;
                
                return NO;
            }
            
            _isStreaming = NO;
            return YES;
        }
    }
    
    return YES;
}

#pragma mark - Frame creation

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
            av_free(frameBuffer);
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

- (AVFrame *)newAudioFrame;
{
    /* frame containing input raw audio */
    AVFrame *frame = avcodec_alloc_frame();
    
    if (frame)
    {
        AVCodecContext *audioCodecCtx = _audioStream->codec;
        frame->nb_samples = audioCodecCtx->frame_size;
        frame->format = audioCodecCtx->sample_fmt;
        frame->channel_layout = audioCodecCtx->channel_layout;
    }
    else
    {
        QTFFAppLog(@"Can't allocate audio frame.");
    }
    
    return frame;
}

#pragma mark - Frame streaming

- (BOOL)streamVideoFrame:(CVImageBufferRef)frameBuffer
        presentationTime:(NSInteger)presentationTime
              decodeTime:(NSInteger)decodeTime
                   error:(NSError **)error;
{
    @synchronized(self)
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
            static struct SwsContext *imgConvertCtx;
            static int sws_flags = SWS_BICUBIC;
            
            // get the config
            QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
            
            // create a convert context if necessary
            if (imgConvertCtx == NULL)
            {
                imgConvertCtx = sws_getContext(width,
                                               height,
                                               config.videoInputPixelFormat,
                                               codecCtx->width,
                                               codecCtx->height,
                                               codecCtx->pix_fmt,
                                               sws_flags,
                                               NULL,
                                               NULL,
                                               NULL);
                
                if (imgConvertCtx == NULL)
                {
                    if (error)
                    {
                        *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                     code:QTFFErrorCode_VideoStreamingError
                                              description:@"Unable to create the image conversion context for the video frame."];
                    }
                    
                    return NO;
                }
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
            sws_scale(imgConvertCtx, (const u_int8_t* const*)_inputVideoFrame->data, _inputVideoFrame->linesize,
                      0, codecCtx->height, _streamVideoFrame->data, _streamVideoFrame->linesize);
            
            // encode the video frame, fill a packet for streaming
            AVPacket avPacket;
            av_init_packet(&avPacket);
            avPacket.data = NULL;
            avPacket.size = 0;
            int gotPacket;
            
            // encoding
            returnVal = avcodec_encode_video2(_videoStream->codec, &avPacket, _streamVideoFrame, &gotPacket);
            
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
                
                if (_videoStream->codec->coded_frame->pts != AV_NOPTS_VALUE)
                {
                    avPacket.pts = av_rescale_q(_videoStream->codec->coded_frame->pts, _videoStream->codec->time_base, _videoStream->time_base);
                }
                
                avPacket.dts = avPacket.pts;
                
                if(_videoStream->codec->coded_frame->key_frame)
                {
                    avPacket.flags |= AV_PKT_FLAG_KEY;
                }
                
                // write the frame
                returnVal = av_interleaved_write_frame(_avOutputFormatContext, &avPacket);
                //returnVal = av_write_frame(_avOutputFormatContext, &avPacket);
                
                if (returnVal != 0)
                {
                    if (error)
                    {
                        *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                     code:QTFFErrorCode_VideoStreamingError
                                              description:[NSString stringWithFormat:@"Unable to write the video frame to the stream, error: %d", returnVal]];
                    }
                    
                    av_free_packet(&avPacket);
                    
                    return NO;
                }
                
                av_free_packet(&avPacket);
            }
            
            return YES;
        }
    }
    
    return NO;
}

int alloc_samples_array_and_data(uint8_t ***data,
                                 int *linesize,
                                 int nb_channels,
                                 int nb_samples,
                                 enum AVSampleFormat sample_fmt,
                                 int align)
{
    int nb_planes = av_sample_fmt_is_planar(sample_fmt) ? nb_channels : 1;
    
    *data = av_malloc(sizeof(*data) * nb_planes);
    if (!*data)
        return AVERROR(ENOMEM);
    return av_samples_alloc(*data, linesize, nb_channels,
                            nb_samples, sample_fmt, align);
}

static int get_format_from_sample_fmt(const char **fmt,
                                      enum AVSampleFormat sample_fmt)
{
    int i;
    struct sample_fmt_entry {
        enum AVSampleFormat sample_fmt; const char *fmt_be, *fmt_le;
    } sample_fmt_entries[] = {
        { AV_SAMPLE_FMT_U8,  "u8",    "u8"    },
        { AV_SAMPLE_FMT_S16, "s16be", "s16le" },
        { AV_SAMPLE_FMT_S32, "s32be", "s32le" },
        { AV_SAMPLE_FMT_FLT, "f32be", "f32le" },
        { AV_SAMPLE_FMT_DBL, "f64be", "f64le" },
    };
    *fmt = NULL;
    
    for (i = 0; i < FF_ARRAY_ELEMS(sample_fmt_entries); i++) {
        struct sample_fmt_entry *entry = &sample_fmt_entries[i];
        if (sample_fmt == entry->sample_fmt) {
            *fmt = AV_NE(entry->fmt_be, entry->fmt_le);
            return 0;
        }
    }
    
    fprintf(stderr,
            "Sample format %s not supported as output format\n",
            av_get_sample_fmt_name(sample_fmt));
    return AVERROR(EINVAL);
}

- (BOOL)streamAudioFrame:(QTSampleBuffer *)sampleBuffer
                   error:(NSError **)error;
{
    @synchronized(self)
    {
        if (_isStreaming)
        {
            // get the codec context
            AVCodecContext *codecCtx = _audioStream->codec;
            
            // get the config
            QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
            
            // source variables
            int64_t sourceChannelLayout = config.audioInputChannelLayout;
            int sourceSampleRate = config.audioInputSampleRate;
            enum AVSampleFormat sourceSampleFormat = config.audioInputSampleFormat;
            int sourceNumberOfChannels = av_get_channel_layout_nb_channels(sourceChannelLayout);
            int sourceLineSize = 0;
            int sourceNumberOfSamples = (int)(sampleBuffer.numberOfSamples);
            
            //int size = 100 * sizeof(char);
            //char *buff = malloc(size);
            //char *name = av_get_sample_fmt_string(buff, size, sourceSampleFormat);
            //QTFFAppLog(@"Source sample format: %s", name);
            
            //void *bytes = sampleBuffer.bytesForAllSamples;
            //uint8_t **sourceData = (uint8_t **)&bytes;
            //uint8_t **sourceData = (uint8_t **)&rawAudioData;
            uint8_t **sourceData = NULL;
            
            // destination variables
            int64_t destinationChannelLayout = codecCtx->channel_layout;
            int destinationSampleRate = codecCtx->sample_rate;
            enum AVSampleFormat destinationSampleFormat = codecCtx->sample_fmt;
            int destinationNumberOfChannels = codecCtx->channels;
            int destinationNumberOfSamples = codecCtx->frame_size;

            //name = av_get_sample_fmt_string(buff, size, destinationSampleFormat);
            //QTFFAppLog(@"Destination sample format: %s", name);

            int destinationLineSize = 0;
            uint8_t **destinationData = NULL;
            
            // resample the audio to convert to a format that FFmpeg can use
            
            // allocate a resampler context
            static struct SwrContext *resamplerCtx;
            resamplerCtx = swr_alloc_set_opts(NULL,
                                              destinationChannelLayout,
                                              destinationSampleFormat,
                                              destinationSampleRate,
                                              sourceChannelLayout,
                                              sourceSampleFormat,
                                              sourceSampleRate,
                                              0,
                                              NULL);
            
            if (resamplerCtx == NULL)
            {
                if (error)
                {
                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                 code:QTFFErrorCode_VideoStreamingError
                                          description:@"Unable to create the resampler context for the audio frame."];
                }
                
                return NO;
            }
            
            // initialize the resampling context
            int returnVal = swr_init(resamplerCtx);
            
            if (returnVal < 0)
            {
                if (error)
                {
                    NSString *description = [NSString stringWithFormat:@"Unable to init the resampler context, error: %d", returnVal];
                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                 code:QTFFErrorCode_VideoStreamingError
                                          description:description];
                }
                
                return NO;
            }
            
            // allocate the source samples buffer
            returnVal = alloc_samples_array_and_data(&sourceData,
                                                     &sourceLineSize,
                                                     sourceNumberOfChannels,
                                                     sourceNumberOfSamples,
                                                     sourceSampleFormat,
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
                
                return NO;
            }
            
            // allocate the destination samples buffer
            returnVal = alloc_samples_array_and_data(&destinationData,
                                                     &destinationLineSize,
                                                     destinationNumberOfChannels,
                                                     destinationNumberOfSamples,
                                                     destinationSampleFormat,
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
                
                free(sourceData);

                return NO;
            }
            
            // fill the source samples buffer
            //float *qtbuffer = sampleBuffer.bytesForAllSamples;
            
            AudioBufferList *tempAudioBufferList = [sampleBuffer audioBufferListWithOptions:0];
            float *rawAudioData = av_malloc((int)sampleBuffer.lengthForAllSamples * sizeof(float));
            const float *ch1Ptr, *ch2Ptr;
            ch1Ptr = (const float *)tempAudioBufferList->mBuffers[0].mData,
            ch2Ptr = (const float *)tempAudioBufferList->mBuffers[1].mData;
            
            //QTFFAppLog(@"Length for all samples: %d", (int)sampleBuffer.lengthForAllSamples);
            //QTFFAppLog(@"Number of buffers = %d", tempAudioBufferList->mNumberBuffers);
            
            for (NSInteger i = 0; i < sampleBuffer.numberOfSamples; i++)
            {
                //QTFFAppLog(@"Sample %d value: %f", (int)i, *b1Ptr);
                *rawAudioData++ = *ch1Ptr++;
                *rawAudioData++ = *ch2Ptr++;
            }
            
            returnVal = av_samples_fill_arrays(sourceData,
                                               &sourceLineSize,
                                               //(const uint8_t *)&qtbuffer,
                                               (const uint8_t *)&rawAudioData,
                                               sourceNumberOfChannels,
                                               sourceNumberOfSamples,
                                               sourceSampleFormat,
                                               0);
            
            //QTFFAppLog(@"Source line size = %d", sourceLineSize);
            
            if (returnVal < 0)
            {
                if (error)
                {
                    NSString *description = [NSString stringWithFormat:@"Unable to fill the sample array with captured audio data, error: %d", returnVal];
                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain code:QTFFErrorCode_VideoStreamingError description:description];
                }
                
                free(sourceData);
                free(destinationData);
                
                return NO;
            }
            
            // convert to destination format
            returnVal = swr_convert(resamplerCtx,
                                    destinationData,
                                    destinationNumberOfSamples,
                                    (const uint8_t **)sourceData,
                                    sourceNumberOfSamples);
            
            if (returnVal < 0)
            {
                if (error)
                {
                    NSString *description = [NSString stringWithFormat:@"Resampling failed, error: %d", returnVal];
                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain code:QTFFErrorCode_VideoStreamingError description:description];
                }
                
                free(sourceData);
                free(destinationData);
                
                return NO;
            }
            
            int buffer_size = av_samples_get_buffer_size(&destinationLineSize, codecCtx->channels, codecCtx->frame_size, codecCtx->sample_fmt, 0);
            //QTFFAppLog(@"Buffer size: %d", buffer_size);
            
            returnVal = avcodec_fill_audio_frame(_streamAudioFrame,
                                                 codecCtx->channels,
                                                 codecCtx->sample_fmt,
                                                 (const uint8_t*)&destinationData[0],
                                                 buffer_size,
                                                 0);
            
            if (returnVal < 0)
            {
                if (error)
                {
                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                 code:QTFFErrorCode_VideoStreamingError
                                          description:[NSString stringWithFormat:@"Unable to fill the audio frame with captured audio data, error: %d", returnVal]];
                }
                
                free(sourceData);
                free(destinationData);

                return NO;
            }
            
            // encode the audio frame, fill a packet for streaming
            AVPacket avPacket;
            av_init_packet(&avPacket);
            avPacket.data = NULL;
            avPacket.size = 0;
            int gotPacket;
            
            // encode the audio
            returnVal = avcodec_encode_audio2(_audioStream->codec, &avPacket, _streamAudioFrame, &gotPacket);
            
            if (returnVal != 0)
            {
                if (error)
                {
                    *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                 code:QTFFErrorCode_VideoStreamingError
                                          description:[NSString stringWithFormat:@"Unable to encode the audio frame, error: %d", returnVal]];
                }
                
                return NO;
                
                free(sourceData);
                free(destinationData);
            }
            
            // if a packet was returned, write it to the network stream. The codec may take several calls before returning a packet.
            // only when there is a full packet returned for streaming should writing be attempted.
            if (gotPacket == 1)
            {
                if (_audioStream->codec->coded_frame->pts != AV_NOPTS_VALUE)
                {
                    avPacket.pts = av_rescale_q(_audioStream->codec->coded_frame->pts, _audioStream->codec->time_base, _audioStream->time_base);
                }
                
                avPacket.dts = avPacket.pts;
                
                //if(_audioStream->codec->coded_frame->key_frame)
                //{
                avPacket.flags |= AV_PKT_FLAG_KEY;
                //}
                avPacket.stream_index = _audioStream->index;
                
                // write the frame
                returnVal = av_interleaved_write_frame(_avOutputFormatContext, &avPacket);
                //returnVal = av_write_frame(_avOutputFormatContext, &avPacket);
                
                if (returnVal != 0)
                {
                    if (error)
                    {
                        *error = [NSError errorWithDomain:QTFFVideoErrorDomain
                                                     code:QTFFErrorCode_VideoStreamingError
                                              description:[NSString stringWithFormat:@"Unable to write the audio frame to the stream, error: %d", returnVal]];
                    }

                    av_free_packet(&avPacket);

                    free(sourceData);
                    free(destinationData);
                    
                    return NO;
                }
                
                av_free_packet(&avPacket);
            }
            
            free(sourceData);
            free(destinationData);

            return YES;
        }
    }
    
    return NO;
}

@end
