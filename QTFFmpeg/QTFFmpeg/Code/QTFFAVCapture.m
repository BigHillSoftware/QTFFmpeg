//
//  QTFFAVCapture.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "QTFFAVCapture.h"
#import "QTFFAVConfig.h"


static NSString * const kBuiltInVideoCamera = @"FaceTime HD Camera (Built-in)";


@interface QTFFAVCapture()
{
}

@end


@implementation QTFFAVCapture

#pragma mark - Audio Devices

+ (NSArray *)availableAudioCaptureDevices;
{
    NSMutableArray *devices = [NSMutableArray array];
    
    // get all the available capture devices of type sound
    [devices addObjectsFromArray:[QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeSound]];
    
    // get all the available capture devices of type muxed
    [devices addObjectsFromArray:[QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeMuxed]];
    
    return devices;
}

+ (QTCaptureDevice *)defaultAudioCaptureDevice;
{
    // try to get a default device of type sound
    QTCaptureDevice *device = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeSound];
    
    if (! device)
    {
        // try to get a default device of type muxed
        device = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeMuxed];
    }
    
    return device;
}

#pragma mark - Audio Capture

- (void)initAudioState;
{
    _audioCaptureDevice = nil;
    _audioCaptureSession = nil;
    _audioCaptureDeviceInput = nil;
    _audioCaptureOutput = nil;
}

- (QTCaptureSession *)startAudioCaptureWithDevice:(QTCaptureDevice *)device
                                         delegate:(id)delegate
                                            error:(NSError **)error;
{
    error = nil;
    BOOL success = [device open:error];
    
    if (success)
    {
        // Create the capture session
        _audioCaptureSession = [[QTCaptureSession alloc] init];
        
        // create the device input
        _audioCaptureDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice:device];
        
        // add the input to the session
        error = nil;
        success = [_audioCaptureSession addInput:_audioCaptureDeviceInput error:error];
        
        if (success)
        {
            // create the output device
            _audioCaptureOutput = [[QTCaptureDecompressedAudioOutput alloc] init];
            _audioCaptureOutput.delegate = delegate;
            
            error = nil;
            success = [_audioCaptureSession addOutput:_audioCaptureOutput error:error];
            
            if (success)
            {
                // start the capture session
                [_audioCaptureSession startRunning];
            }
        }
    }
    
    if (success)
    {
        error = nil;
        return _audioCaptureSession;
    }
    else
    {
        // error should already be set
        [self initAudioState];
        return nil;
    }
}

- (void)stopAudioCapture;
{
    [_audioCaptureSession stopRunning];
    
    if ([[_audioCaptureDeviceInput device] isOpen])
    {
        [[_audioCaptureDeviceInput device] close];
    }
    
    [self initAudioState];
}

#pragma mark - Video Devices

+ (NSArray *)availableVideoCaptureDevices:(BOOL)includeBuiltInCamera;
{
    NSMutableArray *devices = [NSMutableArray array];
    
    // get all the available capture devices of type video
    [devices addObjectsFromArray:[QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeVideo]];
    
    // get all the available capture devices of type muxed
    [devices addObjectsFromArray:[QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeMuxed]];
    
    if (! includeBuiltInCamera)
    {
        // not all devices are allowed, remove the internal camera from the available capture devices
        for (QTCaptureDevice *device in devices)
        {
            if ([self isBuiltInCameraDevice:device])
            {
                [devices removeObject:device];
                break;
            }
        }
    }
    
    return devices;
}

+ (QTCaptureDevice *)defaultVideoCaptureDevice:(BOOL)includeBuiltInCamera;
{
    // try to get a default device of type video
    QTCaptureDevice *device = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeVideo];
    
    if (! device || (! includeBuiltInCamera && [self isBuiltInCameraDevice:device]))
    {
        // try to get a default device of type muxed
        device = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeMuxed];
        
        if ([self isBuiltInCameraDevice:device])
        {
            device = nil;
        }
    }
    
    return device;
}

+ (BOOL)isBuiltInCameraDevice:(QTCaptureDevice *)device;
{
    NSString *title = [device localizedDisplayName];
    return [title isEqualToString:kBuiltInVideoCamera];
}

#pragma mark - Video Capture

- (void)initVideoState;
{
    _videoCaptureDevice = nil;
    _videoCaptureSession = nil;
    _videoCaptureDeviceInput = nil;
    _videoCaptureOutput = nil;
}

- (QTCaptureSession *)startVideoCaptureWithDevice:(QTCaptureDevice *)device
                                         delegate:(id)delegate
                                            error:(NSError **)error;
{
    error = nil;
    BOOL success = [device open:error];
    
    if (success)
    {
        // Create the capture session
        _videoCaptureSession = [[QTCaptureSession alloc] init];
        
        // create the device input
        _videoCaptureDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice:device];
        
        // add the input to the session
        error = nil;
        success = [_videoCaptureSession addInput:_videoCaptureDeviceInput error:error];
        
        if (success)
        {
            // create the output device
            _videoCaptureOutput = [[QTCaptureDecompressedVideoOutput alloc] init];
            _videoCaptureOutput.delegate = delegate;
            
            // get shared app state
            QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
            
            NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
            
            if (config.videoCaptureSetPixelBufferSize)
            {
                [attributes setValue:[NSNumber numberWithDouble:config.videoCapturePixelBufferWidth]
                              forKey:(id)kCVPixelBufferWidthKey];
                
                [attributes setValue:[NSNumber numberWithDouble:config.videoCapturePixelBufferHeight]
                              forKey:(id)kCVPixelBufferHeightKey];
            }
            
            if (config.videoCaptureSetPixelBufferFormatType)
            {
                [attributes setValue:[NSNumber numberWithUnsignedLong:config.videoCapturePixelBufferFormatType]
                              forKey:(id)kCVPixelBufferPixelFormatTypeKey];
            }
            
            [_videoCaptureOutput setPixelBufferAttributes:attributes];
            
            [_videoCaptureOutput setAutomaticallyDropsLateVideoFrames:config.videoCaptureDropLateFrames];
            [_videoCaptureOutput setMinimumVideoFrameInterval:config.videoCaptureFrameInterval];
            
            success = [_videoCaptureSession addOutput:_videoCaptureOutput error:error];
            
            if (success)
            {
                // start the capture session
                [_videoCaptureSession startRunning];
            }
        }
    }
    
    if (success)
    {
        error = nil;
        return _videoCaptureSession;
    }
    else
    {
        // error should already be set
        [self initVideoState];
        return nil;
    }
}

- (void)stopVideoCapture;
{
    [_videoCaptureSession stopRunning];
    
    if ([[_videoCaptureDeviceInput device] isOpen])
    {
        [[_videoCaptureDeviceInput device] close];
    }
    
    [self initVideoState];
}

@end
