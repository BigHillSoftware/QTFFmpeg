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
#import "NSView+BackgroundColor.h"
#import "QTFFAVConfig.h"

#define CODE_EXIT                           1000


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
    BOOL _isStreaming;
}

@end


@implementation QTFFAVViewController

#pragma mark - Initialization

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self)
    {
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
    _isStreaming = NO;
    
    // create the capture object
    _avCapture = [[QTFFAVCapture alloc] init];
    
    // create the streamer
    _avStreamer = [[QTFFAVStreamer alloc] init];
}

#pragma mark - Popup display

- (BOOL)displayVideoPopup;
{
    // get shared app state
    QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
    
    // get the devices
    _availableVideoCaptureDevices = [QTFFAVCapture availableVideoCaptureDevices:config.videoCaptureIncludeInternalCamera];
    
    if ([_availableVideoCaptureDevices count] == 0)
    {
        // must have a video capture device, so fail
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert setMessageText:@"No Video Capture Devices Detected"];
        [alert setInformativeText:@"Unable to detect any video capture devices attached to your computer. Please exit, connect a video capture device, and try again."];
        [alert addButtonWithTitle:@"Exit"];
        
        [alert beginSheetModalForWindow:self.view.window
                          modalDelegate:self
                         didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                            contextInfo:nil];
        
        return NO;
    }
    else
    {
        // video capture device(s) found, continue
        
        //remove all devices from the popup
        [_availableVideoCaptureDevicesPopUpButton removeAllItems];
        
        // get the default device, find its index for selection
        QTCaptureDevice *device = [QTFFAVCapture defaultVideoCaptureDevice:config.videoCaptureIncludeInternalCamera];
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
        
        // update the format description
        [self displayVideoFormatText];
        
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
        
        [alert beginSheetModalForWindow:self.view.window
                          modalDelegate:self
                         didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                            contextInfo:nil];
        
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
        
        // update the format description
        [self displayAudioFormatText];
        
        return YES;
    }
}

- (void)displayVideoFormatText;
{
    NSString *descriptionText = @"";
    
    QTCaptureDevice *device = [_availableVideoCaptureDevices objectAtIndex:[_availableVideoCaptureDevicesPopUpButton indexOfSelectedItem]];
    
    NSArray *formatDescriptions = [device formatDescriptions];
    BOOL hasPrevious = NO;
    for (QTFormatDescription *description in formatDescriptions)
    {
        if (hasPrevious)
        {
            descriptionText = [descriptionText stringByAppendingString:@"\n"];
        }
        
        descriptionText = [descriptionText stringByAppendingFormat:@"∙ %@", [description localizedFormatSummary]];
        hasPrevious = YES;
    }
    
    _deviceSupportedVideoFormatTextField.stringValue = descriptionText;
}

- (void)displayAudioFormatText;
{
    NSString *descriptionText = @"";
    
    QTCaptureDevice *device = [_availableAudioCaptureDevices objectAtIndex:[_availableAudioCaptureDevicesPopUpButton indexOfSelectedItem]];
    
    NSArray *formatDescriptions = [device formatDescriptions];
    BOOL hasPrevious = NO;
    for (QTFormatDescription *description in formatDescriptions)
    {
        if (hasPrevious)
        {
            descriptionText = [descriptionText stringByAppendingString:@"\n"];
        }
        
        descriptionText = [descriptionText stringByAppendingFormat:@"∙ %@", [description localizedFormatSummary]];
        hasPrevious = YES;
    }
    
    _deviceSupportedAudioFormatTextField.stringValue = descriptionText;
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
                    [_streamingButton setEnabled:YES];
                }
            }
        }
    }
}

- (void)stopProcessing;
{
    if (_isStreaming)
    {
        [self stopStreaming];
    }
    
    if (_isCapturingVideo)
    {
        [self stopVideoCapture];
    }
    
    if (_isCapturingAudio)
    {
        [self stopAudioCapture];
    }
}

#pragma mark - Video capture

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
            NSString *message = [NSString stringWithFormat:@"Video capture starting failed with error: %@", [error localizedDescription]];
            QTFFAppLog(@"%@", message);
            
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setAlertStyle:NSWarningAlertStyle];
            [alert setMessageText:@"Video Capture Failed"];
            [alert setInformativeText:message];
            [alert addButtonWithTitle:@"Exit"];
            
            [alert beginSheetModalForWindow:self.view.window
                              modalDelegate:self
                             didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                                contextInfo:nil];
            
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

#pragma mark - Video streaming

- (BOOL)startVideoStreaming;
{
    if (! _isStreamingVideo)
    {
        // get the config
        QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
        
        // start the stream
        QTFFAppLog(@"Starting video streaming to URL: %@", config.streamOutputStreamName);
        
        NSError *error = nil;
        BOOL success = [_avStreamer openStream:&error];
        
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

- (void)streamVideoFrame:(CVImageBufferRef)videoFrame
            sampleBuffer:(QTSampleBuffer *)sampleBuffer;
{
    if (_isStreamingVideo)
    {
        NSError *error = nil;
        
        BOOL success = [_avStreamer streamVideoFrame:videoFrame
                                        sampleBuffer:sampleBuffer
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

#pragma mark - Audio capture

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
            NSString *message = [NSString stringWithFormat:@"Audio capture starting failed with error: %@", [error localizedDescription]];
            QTFFAppLog(@"%@", message);
            
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setAlertStyle:NSWarningAlertStyle];
            [alert setMessageText:@"Audio Capture Failed"];
            [alert setInformativeText:message];
            [alert addButtonWithTitle:@"Exit"];
            
            [alert beginSheetModalForWindow:self.view.window
                              modalDelegate:self
                             didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                                contextInfo:nil];
            
            QTFFAppLog(@"%@", message);
            
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

- (void)updateAudioLevels; //:(NSTimer *)timer
{
	// Get the mean audio level from the movie file output's audio connections
	
	float totalDecibels = 0.0;
	
	NSUInteger i = 0;
	NSUInteger numberOfPowerLevels = 0;	// Keep track of the total number of power levels in order to take the mean
    
    NSArray *connections = [_avCapture.audioCaptureDeviceInput connections];
	for (i = 0; i < [connections count]; i++)
    {
        QTCaptureConnection *connection = [connections objectAtIndex:i];
		
		if ([[connection mediaType] isEqualToString:QTMediaTypeSound])
        {
			NSArray *powerLevels = [connection attributeForKey:QTCaptureConnectionAudioAveragePowerLevelsAttribute];
			NSUInteger j, powerLevelCount = [powerLevels count];
			
			for (j = 0; j < powerLevelCount; j++)
            {
				NSNumber *decibels = [powerLevels objectAtIndex:j];
				totalDecibels += [decibels floatValue];
				numberOfPowerLevels++;
			}
		}
	}
	
	if (numberOfPowerLevels > 0)
    {
		[_audioLevelMeter setFloatValue:(pow(10., 0.05 * (totalDecibels / (float)numberOfPowerLevels)) * 20.0)];
	}
    else
    {
		[_audioLevelMeter setFloatValue:0];
	}
}

#pragma mark - Audio Streaming

- (BOOL)startAudioStreaming;
{
    if (! _isStreamingAudio)
    {
        // get the config
        QTFFAVConfig *config = [QTFFAVConfig sharedConfig];
        
        QTFFAppLog(@"Starting audio streaming to URL: %@", config.streamOutputStreamName);
        
        _isStreamingAudio = YES;
        
        QTFFAppLog(@"Audio streaming started successfully.");
    }
    
    return YES;
}

- (void)streamAudioFrame:(QTSampleBuffer *)sampleBuffer;
{
    if (_isStreamingAudio)
    {
        NSError *error = nil;
        
        BOOL success = [_avStreamer streamAudioFrame:sampleBuffer error:&error];
        
        if (success)
        {
            //QTFFAppLog(@"Audio frame streaming succeeded.");
        }
        else
        {
            QTFFAppLog(@"Audio frame streaming failed with error: %@", [error localizedDescription]);
        }
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

#pragma mark - Streaming

- (void)startStreaming;
{
    if (! _isStreaming)
    {
        if ([self startVideoStreaming])
        {
            if ([self startAudioStreaming])
            {
                // set UI state
                [_availableVideoCaptureDevicesPopUpButton setEnabled:NO];
                [_availableAudioCaptureDevicesPopUpButton setEnabled:NO];
                _streamingButton.title = @"Stop Streaming";
                
                // set streaming state
                _isStreaming = YES;
            }
        }
    }
}

- (void)stopStreaming;
{
    if (_isStreaming)
    {
        [self stopVideoStreaming];
        [self stopAudioStreaming];
        
        // set UI state
        [_availableVideoCaptureDevicesPopUpButton setEnabled:YES];
        [_availableAudioCaptureDevicesPopUpButton setEnabled:YES];
        _streamingButton.title = @"Start Streaming";
        
        // set streaming state
        _isStreaming = NO;
    }
}

#pragma mark - QTCaptureDecompressedaAudioOutputDelegate Methods

- (void)captureOutput:(QTCaptureOutput *)captureOutput didOutputAudioSampleBuffer:(QTSampleBuffer *)sampleBuffer fromConnection:(QTCaptureConnection *)connection;
{
    if (_isStreamingAudio)
    {
        _capturedAudioFormatTextField.stringValue = [NSString stringWithFormat:@"∙ %@", [sampleBuffer.formatDescription localizedFormatSummary]];
        [self streamAudioFrame:sampleBuffer];
    }
    
    [self performSelectorOnMainThread:@selector(updateAudioLevels) withObject:nil waitUntilDone:NO];
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
        _capturedVideoFormatTextField.stringValue = [NSString stringWithFormat:@"∙ %@", [sampleBuffer.formatDescription localizedFormatSummary]];
        [self streamVideoFrame:videoFrame sampleBuffer:sampleBuffer];
    }
}

#pragma mark - NSAlert delegate methods

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    QTFFAppLog(@"Alert return code: %ld", returnCode);
    
    switch (returnCode)
    {
        case CODE_EXIT:
            QTFFAppLog(@"Terminating app.");
            [[NSApplication sharedApplication] terminate:self];
            break;
            
        default:
            break;
    }
}

#pragma mark - Actions

- (IBAction)availableVideoCaptureDevicesPopupButtonItemSelected:(id)sender;
{
    QTFFAppLog(@"Video capture device selected: %@", _availableVideoCaptureDevicesPopUpButton.title);
    
    NSInteger indexOfSelectedItem = _availableVideoCaptureDevicesPopUpButton.indexOfSelectedItem;
    
    if (indexOfSelectedItem != _lastSelectedVideoCaptureDeviceIndex)
    {
        // load restart video
        [self performSelectorOnMainThread:@selector(restartVideoCapture) withObject:nil waitUntilDone:NO];
    }
    
    _lastSelectedVideoCaptureDeviceIndex = indexOfSelectedItem;
    
    // update the format description
    [self displayVideoFormatText];
}

- (IBAction)availableAudioCaptureDevicesPopupButtonItemSelected:(id)sender;
{
    QTFFAppLog(@"Audio capture device selected: %@", _availableAudioCaptureDevicesPopUpButton.title);
    
    NSInteger indexOfSelectedItem = _availableAudioCaptureDevicesPopUpButton.indexOfSelectedItem;
    
    if (indexOfSelectedItem != _lastSelectedAudioCaptureDeviceIndex)
    {
        // load restart video
        [self performSelectorOnMainThread:@selector(restartAudioCapture) withObject:nil waitUntilDone:NO];
    }
    
    _lastSelectedAudioCaptureDeviceIndex = indexOfSelectedItem;
    
    // update the format description
    [self displayAudioFormatText];
}

- (IBAction)streamingButtonSelected:(id)sender;
{
    if (_isStreaming)
    {
        [self stopStreaming];
    }
    else
    {
        [self startStreaming];
    }
}

@end
