//
//  QTFFAVViewController.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>


@interface QTFFAVViewController : NSViewController

@property (nonatomic, assign) IBOutlet QTCaptureView *videoCaptureView;
@property (nonatomic, assign) IBOutlet NSPopUpButton *availableVideoCaptureDevicesPopUpButton;
@property (nonatomic, assign) IBOutlet NSPopUpButton *availableAudioCaptureDevicesPopUpButton;
@property (nonatomic, assign) IBOutlet NSLevelIndicator	*audioLevelMeter;
@property (nonatomic, assign) IBOutlet NSTextField *deviceSupportedVideoFormatTextField;
@property (nonatomic, assign) IBOutlet NSTextField *deviceSupportedAudioFormatTextField;
@property (nonatomic, assign) IBOutlet NSTextField *capturedVideoFormatTextField;
@property (nonatomic, assign) IBOutlet NSTextField *capturedAudioFormatTextField;
@property (nonatomic, assign) IBOutlet NSButton *streamingButton;

#pragma mark - Actions

- (IBAction)availableVideoCaptureDevicesPopupButtonItemSelected:(id)sender;
- (IBAction)availableAudioCaptureDevicesPopupButtonItemSelected:(id)sender;
- (IBAction)streamingButtonSelected:(id)sender;

#pragma mark - Processing control

- (void)startProcessing;
- (void)stopProcessing;

@end
