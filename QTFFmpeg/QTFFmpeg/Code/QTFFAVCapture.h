//
//  QTFFAVCapture.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QTKit/QTKit.h>


@interface QTFFAVCapture : NSObject

@property (nonatomic, readonly) QTCaptureDevice *videoCaptureDevice;
@property (nonatomic, readonly) QTCaptureSession *videoCaptureSession;
@property (nonatomic, readonly) QTCaptureDeviceInput *videoCaptureDeviceInput;
@property (nonatomic, readonly) QTCaptureDecompressedVideoOutput *videoCaptureOutput;

@property (nonatomic, readonly) QTCaptureDevice *audioCaptureDevice;
@property (nonatomic, readonly) QTCaptureSession *audioCaptureSession;
@property (nonatomic, readonly) QTCaptureDeviceInput *audioCaptureDeviceInput;
@property (nonatomic, readonly) QTCaptureDecompressedAudioOutput *audioCaptureOutput;

#pragma mark - Audio Devices

+ (NSArray *)availableAudioCaptureDevices;
+ (QTCaptureDevice *)defaultAudioCaptureDevice;

#pragma mark - Audio Capture

- (QTCaptureSession *)startAudioCaptureWithDevice:(QTCaptureDevice *)device
                                         delegate:(id)delegate
                                            error:(NSError **)error;
- (void)stopAudioCapture;

- (int)currentAudioCaptureDeviceNumberOfChannels;

#pragma mark - Video Devices

+ (NSArray *)availableVideoCaptureDevices:(BOOL)includeBuiltInCamera;
+ (QTCaptureDevice *)defaultVideoCaptureDevice:(BOOL)includeBuiltInCamera;;
+ (BOOL)isBuiltInCameraDevice:(QTCaptureDevice *)device;

#pragma mark - Video Capture

- (QTCaptureSession *)startVideoCaptureWithDevice:(QTCaptureDevice *)device
                                         delegate:(id)delegate
                                            error:(NSError **)error;

- (void)stopVideoCapture;

@end
