//
//  QTFFAVViewController.m
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import "QTFFAVViewController.h"
#import "QTFFAVCapture.h"
#import "QTFFAVStreamer.h"
#import "QTFFAppLog.h"

#define INCLUDE_INTERNAL_VIDEO_CAMERA       YES
#define VIDEO_FRAME_WIDTH                   384.0
#define VIDEO_FRAME_HEIGHT                  216.0
#define VIDEO_FRAME_SIZE                    CGSizeMake(VIDEO_FRAME_WIDTH, VIDEO_FRAME_HEIGHT)
#define VIDEO_FRAMES_PER_SECOND             24
#define VIDEO_FRAME_PIXEL_FORMAT            kCVPixelFormatType_422YpCbCr8
#define VIDEO_DROP_LATE_FRAMES              YES


@interface QTFFAVViewController ()
{
    // av capture objects
    NSArray *_availableVideoCaptureDevices;
    NSArray *_availableAudioCaptureDevices;
    NSInteger _lastSelectedVideoCaptureDeviceIndex;
    NSInteger _lastSelectedAudioCaptureDeviceIndex;
    QTFFAVCapture *_avCapture;
    QTFFAVStreamer *_avStreamer;
    
    // state
    BOOL _isCapturingVideo;
    BOOL _isCapturingAudio;
    BOOL _isStreamingVideo;
    BOOL _isStreamingAudio;
}

@end


@implementation QTFFAVViewController

#pragma mark - Initialization

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)awakeFromNib;
{
    _isCapturingVideo = NO;
    _isCapturingAudio = NO;
    _isStreamingVideo = NO;
    _isStreamingAudio = NO;
}

#pragma mark - Popup display

- (BOOL)displayVideoPopup;
{
    // get the devices
    _availableVideoCaptureDevices = [QTFFAVCapture availableVideoCaptureDevices:INCLUDE_INTERNAL_VIDEO_CAMERA];
    
    if ([_availableVideoCaptureDevices count] == 0)
    {
        // must have a video capture device, so fail
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert setMessageText:@"No Video Capture Devices Detected"];
        [alert setInformativeText:@"Unable to detect any video capture devices attached to your computer. Please exit, connect a video capture device, and try again."];
        [alert addButtonWithTitle:@"Exit"];
        
        [self.delegate showAlert:alert
                     modalWindow:self.view.window
                   modalDelegate:self
                     endSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                     contextInfo:nil
                 restoreIfPaused:YES];
        
        return NO;
    }
    else
    {
        // video capture device(s) found, continue
        
        //remove all devices from the popup
        [_availableVideoCaptureDevicesPopUpButton removeAllItems];
        
        // get the default device, find its index for selection
        QTCaptureDevice *device = [QTFFAVCapture defaultVideoCaptureDevice:INCLUDE_INTERNAL_VIDEO_CAMERA];
        NSInteger index = [_availableVideoCaptureDevices indexOfObject:device];
        
        if (index == NSNotFound)
        {
            index = 0;
        }
        
        // load the device titles into the popup
        QTFFAppLog(@"Detected video capture devices:");
        int deviceCount = 1;
        for (QTCaptureDevice *device in _availableVideoCaptureDevices)
        {
            NSString *title = [device localizedDisplayName];
            [_availableVideoCaptureDevicesPopUpButton addItemWithTitle:title];
            
            QTFFAppLog(@"  %d) [%@], format descriptions:", deviceCount, title);
            
            NSArray *formatDescriptions = [device formatDescriptions];
            
            for (QTFormatDescription *description in formatDescriptions)
            {
                NSLog(@"      ∙ %@", [description localizedFormatSummary]);
            }
            
            deviceCount++;
        }
        
        // select the default index
        _lastSelectedVideoCaptureDeviceIndex = index;
        [_availableVideoCaptureDevicesPopUpButton selectItemAtIndex:index];
        
        return YES;
    }
}

- (BOOL)displayAudioPopup;
{
    // get the devices
    _availableAudioCaptureDevices = [QTFFAVCapture availableAudioCaptureDevices];
    
    if ([_availableAudioCaptureDevices count] == 0)
    {
        // must have an audio capture device, so fail
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert setMessageText:@"No Audio Capture Devices Detected"];
        [alert setInformativeText:@"Unable to detect any audio capture devices attached to your computer. Please exit, connect an audio capture device, and try again."];
        [alert addButtonWithTitle:@"Exit"];
        
        [self.delegate showAlert:alert
                     modalWindow:self.view.window
                   modalDelegate:self
                     endSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                     contextInfo:nil
                 restoreIfPaused:YES];
        
        return NO;
    }
    else
    {
        // audio capture device(s) found, continue
        
        //remove all devices from the popup
        [_availableAudioCaptureDevicesPopUpButton removeAllItems];
        
        // get the default device, find its index for selection
        QTCaptureDevice *device = [QTFFAVCapture defaultAudioCaptureDevice];
        NSInteger index = [_availableAudioCaptureDevices indexOfObject:device];
        
        if (index == NSNotFound)
        {
            index = 0;
        }
        
        // load the device titles into the popup
        QTFFAppLog(@"Detected audio capture devices:");
        int deviceCount = 1;
        for (QTCaptureDevice *device in _availableAudioCaptureDevices)
        {
            NSString *title = [device localizedDisplayName];
            [_availableAudioCaptureDevicesPopUpButton addItemWithTitle:title];
            
            QTFFAppLog(@"  %d) [%@], format descriptions:", deviceCount, title);
            
            NSArray *formatDescriptions = [device formatDescriptions];
            
            for (QTFormatDescription *description in formatDescriptions)
            {
                NSLog(@"      ∙ %@", [description localizedFormatSummary]);
            }
            
            deviceCount++;
        }
        
        // select the default index
        _lastSelectedAudioCaptureDeviceIndex = index;
        [_availableAudioCaptureDevicesPopUpButton selectItemAtIndex:index];
        
        return YES;
    }
}

#pragma mark - Processing control

- (void)startProcessing;
{
    // detect available cameras
    if ([self displayVideoPopup])
    {
        // detect available audio devices
        if ([self displayAudioPopup])
        {
            // start video
            if ([self startVideoCapture])
            {
                // start audio
                if ([self startAudioCapture])
                {
                    // enable the start test button
                    [_startStreamingButton setEnabled:YES];
                }
            }
        }
    }
    
}

#pragma mark - Video

- (BOOL)startVideoCapture;
{
    if (! _isCapturingVideo)
    {
        NSError *error = nil;
        
        // get the device associated with the selected index
        QTCaptureDevice *device = [_availableVideoCaptureDevices objectAtIndex:_availableVideoCaptureDevicesPopUpButton.indexOfSelectedItem];
        
        QTFFAppLog(@"Starting video capture with device: %@", [device localizedDisplayName]);
        
        // start the video capture session
        QTCaptureSession *captureSession = [_avCapture startVideoCaptureWithDevice:device
                                                                   pixelFormatType:VIDEO_FRAME_PIXEL_FORMAT
                                                                         frameSize:VIDEO_FRAME_SIZE
                                                                         frameRate:(1.0/VIDEO_FRAMES_PER_SECOND)
                                                               dropLateVideoFrames:VIDEO_DROP_LATE_FRAMES
                                                                          delegate:self
                                                                             error:&error];
        
        if (captureSession)
        {
            QTFFAppLog(@"Video capture started successfully.");
            
            // set the capture session for the video views
            [_videoCaptureView setCaptureSession:captureSession];
            
            _isCapturingVideo = YES;
            return YES;
        }
        else
        {
            QTFFAppLog(@"Video capture starting failed with error: %@", [error localizedDescription]);
            _isCapturingVideo = NO;
            return NO;
        }
    }
    else
    {
        return YES;
    }
}

- (void)stopVideoCapture;
{
    if (_isCapturingVideo)
    {
        QTFFAppLog(@"Stopping video capture...");
        _isCapturingVideo = NO;
        [_avCapture stopVideoCapture];
        QTFFAppLog(@"Video capture stopped.");
    }
}

- (void)restartVideoCapture;
{
    [self stopVideoCapture];
    [self startVideoCapture];
}

- (void)publishVideo;
{
    if ([self startVideoStreaming])
    {
        if ([self startAudioStreaming])
        {
        }
    }
}

- (BOOL)startVideoStreamingToURL:(NSString *)URLString;
{
    if (! _isStreamingVideo)
    {
        // construct the stream name
        NSString *URI = [_provisionedStream.archiveURI stringByReplacingOccurrencesOfString:@"archive" withString:@"live"];
        NSString *streamName = [NSString stringWithFormat:@"%@/%@/%@", URI, _provisionedStream.streamName, _provisionedStream.filename];
        
        // start the stream
        QTFFAppLog(@"Starting video streaming to URL: %@", streamName);
        
        NSError *error = nil;
        BOOL success = [_avStreamer openStream:streamName error:&error];
        
        if (success)
        {
            QTFFAppLog(@"Video streaming started successfully.");
            _isStreamingVideo = YES;
            return YES;
        }
        else
        {
            QTFFAppLog(@"Video streaming starting failed with error: %@", [error localizedDescription]);
            _isStreamingVideo = NO;
            return NO;
        }
    }
    
    return YES;
}

- (void)streamVideoFrame:(CVImageBufferRef)videoFrame;
{
    if (_isStreamingVideo)
    {
        NSError *error = nil;
        
        BOOL success = [_avStreamer streamVideoFrame:videoFrame
                                       presentationTime:0
                                             decodeTime:0
                                                  error:&error];
        
        if (success)
        {
            //QTFFAppLog(@"Frame streaming succeeded.");
        }
        else
        {
            QTFFAppLog(@"Frame streaming failed with error: %@", [error localizedDescription]);
        }
    }
}

- (BOOL)stopVideoStreaming;
{
    if (_isStreamingVideo)
    {
        NSError *error = nil;
        BOOL success = [_avStreamer closeStream:&error];
        
        if (success)
        {
            QTFFAppLog(@"Video streaming closed successfully.");
            _isStreamingVideo = NO;
            return YES;
        }
        else
        {
            QTFFAppLog(@"Video streaming closing failed with error: %@", [error localizedDescription]);
            _isStreamingVideo = NO;
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Audio

- (BOOL)startAudioCapture;
{
    if (! _isCapturingAudio)
    {
        NSError *error = nil;
        
        // get the device associated with the selected index
        QTCaptureDevice *device = [_availableAudioCaptureDevices objectAtIndex:_availableAudioCaptureDevicesPopUpButton.indexOfSelectedItem];
        
        QTFFAppLog(@"Starting audio capture with device: %@", [device localizedDisplayName]);
        
        // start the audio capture session
        QTCaptureSession *captureSession = [_avCapture startAudioCaptureWithDevice:device
                                                                          delegate:self
                                                                             error:&error];
        
        if (captureSession)
        {
            QTFFAppLog(@"Audio capture started successfully.");
            _isCapturingAudio = YES;
            return YES;
        }
        else
        {
            QTFFAppLog(@"Audio capture starting failed with error: %@", [error localizedDescription]);
            _isCapturingAudio = NO;
            return NO;
        }
    }
    else
    {
        return YES;
    }
}

- (void)stopAudioCapture;
{
    if (_isCapturingAudio)
    {
        QTFFAppLog(@"Stopping audio capture...");
        _isCapturingAudio = NO;
        [_avCapture stopAudioCapture];
        QTFFAppLog(@"Audio capture stopped.");
    }
}

- (void)restartAudioCapture;
{
    [self stopAudioCapture];
    [self startAudioCapture];
}

- (BOOL)startAudioStreaming;
{
    if (! _isStreamingAudio)
    {
        QTFFAppLog(@"Starting audio streaming to URL: %@", _avStreamer.streamName);
        
        _isStreamingAudio = YES;
        
        QTFFAppLog(@"Audio streaming started successfully.");
    }
    
    return YES;
}

- (void)streamAudioFrame:(QTSampleBuffer *)sampleBuffer;
{
    if (_isStreamingAudio)
    {
        /*
         NSError *error = nil;
         
         BOOL success = [_videoStreamer streamAudioFrame:sampleBuffer
         error:&error];
         
         if (success)
         {
         //QTFFAppLog(@"Audio frame streaming succeeded.");
         }
         else
         {
         QTFFAppLog(@"Audio frame streaming failed with error: %@", [error localizedDescription]);
         }
         */
    }
}


- (BOOL)stopAudioStreaming;
{
    if (_isStreamingAudio)
    {
        NSError *error = nil;
        //BOOL success = [_videoStreamer closeStream:&error];
        BOOL success = YES;
        
        if (success)
        {
            QTFFAppLog(@"Audio streaming closed successfully.");
            _isStreamingAudio = NO;
            return YES;
        }
        else
        {
            QTFFAppLog(@"Audio streaming closing failed with error: %@", [error localizedDescription]);
            _isStreamingAudio = YES;
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - QTCaptureDecompressedaAudioOutputDelegate Methods

- (void)captureOutput:(QTCaptureOutput *)captureOutput didOutputAudioSampleBuffer:(QTSampleBuffer *)sampleBuffer fromConnection:(QTCaptureConnection *)connection;
{
    if (_isStreamingAudio)
    {
        [self streamAudioFrame:sampleBuffer];
    }
}

#pragma mark - QTCaptureDecompressedVideoOutputDelegate Methods

- (void)captureOutput:(QTCaptureOutput *)captureOutput didDropVideoFrameWithSampleBuffer:(QTSampleBuffer *)sampleBuffer fromConnection:(QTCaptureConnection *)connection;
{
    // do nothing
}

- (void)captureOutput:(QTCaptureOutput *)captureOutput
  didOutputVideoFrame:(CVImageBufferRef)videoFrame
     withSampleBuffer:(QTSampleBuffer *)sampleBuffer
       fromConnection:(QTCaptureConnection *)connection;
{
    if (_isStreamingVideo)
    {
        [self streamVideoFrame:videoFrame];
    }
}

@end
