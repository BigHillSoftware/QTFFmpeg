//
//  QTFFAVStreamer.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QTKit/QTKit.h>


@interface QTFFAVStreamer : NSObject

@property (nonatomic, readonly) BOOL isStreaming;

#pragma mark - Stream opening and closing

- (BOOL)openStream:(NSError **)error;

- (BOOL)closeStream:(NSError **)error;

#pragma mark - Frame streaming

- (BOOL)streamVideoFrame:(CVImageBufferRef)frameBuffer
            sampleBuffer:(QTSampleBuffer *)sampleBuffer
                   error:(NSError **)error;

- (BOOL)streamAudioFrame:(QTSampleBuffer *)sampleBuffer
                   error:(NSError **)error;

@end
