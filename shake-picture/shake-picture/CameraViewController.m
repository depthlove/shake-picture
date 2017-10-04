//
//  CameraViewController.m
//  shake-picture
//
//  Created by suntongmian on 2017/10/4.
//  Copyright © 2017年 Pili Engineering, Qiniu Inc. All rights reserved.
//

#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "SinGL.h"

@interface CameraViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession                *captureSession;
    AVCaptureDevice                 *captureDevice;
    AVCaptureDeviceInput            *captureDeviceInput;
    AVCaptureVideoDataOutput        *captureVideoDataOutput;
    AVCaptureConnection             *videoCaptureConnection;
    AVCaptureVideoPreviewLayer      *previewLayer;
    dispatch_queue_t                 encodeQueue;
    BOOL                             isVideoPortrait;
    CGSize                           captureVideoSize;
    
    SinGL                           *sinGL;
}
@end

@implementation CameraViewController

- (CGSize)getVideoSize:(NSString *)sessionPreset isVideoPortrait:(BOOL)isVideoPortrait {
    CGSize size = CGSizeZero;
    if ([sessionPreset isEqualToString:AVCaptureSessionPresetMedium]) {
        if (isVideoPortrait)
            size = CGSizeMake(360, 480);
        else
            size = CGSizeMake(480, 360);
    } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset1920x1080]) {
        if (isVideoPortrait)
            size = CGSizeMake(1080, 1920);
        else
            size = CGSizeMake(1920, 1080);
    } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset1280x720]) {
        if (isVideoPortrait)
            size = CGSizeMake(720, 1280);
        else
            size = CGSizeMake(1280, 720);
    } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset640x480]) {
        if (isVideoPortrait)
            size = CGSizeMake(480, 640);
        else
            size = CGSizeMake(640, 480);
    }
    
    return size;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    encodeQueue = dispatch_queue_create(DISPATCH_QUEUE_SERIAL, NULL);

    #pragma mark -- set capture settings
    isVideoPortrait = YES;
    AVCaptureSessionPreset sessionPreset = AVCaptureSessionPreset1280x720;
    captureVideoSize = [self getVideoSize:sessionPreset isVideoPortrait:isVideoPortrait];

    #pragma mark -- AVCaptureSession init
    captureSession = [[AVCaptureSession alloc] init];
    captureSession.sessionPreset = sessionPreset;

    captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSError *error = nil;
    captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];

    if([captureSession canAddInput:captureDeviceInput])
    [captureSession addInput:captureDeviceInput];
    else
    NSLog(@"Error: %@", error);

    dispatch_queue_t outputQueue = dispatch_queue_create("outputQueue", NULL);

    captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureVideoDataOutput setSampleBufferDelegate:self queue:outputQueue];

    // nv12
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
                              kCVPixelBufferPixelFormatTypeKey,
                              nil];

    captureVideoDataOutput.videoSettings = settings;
    captureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES;

    if ([captureSession canAddOutput:captureVideoDataOutput]) {
        [captureSession addOutput:captureVideoDataOutput];
    }

    // 保存Connection，用于在SampleBufferDelegate中判断数据来源（是Video/Audio？）
    videoCaptureConnection = [captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    if (isVideoPortrait) {
        videoCaptureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else {
        videoCaptureConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    }

    #pragma mark -- AVCaptureVideoPreviewLayer init
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    previewLayer.frame = self.view.layer.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; // 设置预览时的视频缩放方式
    [[previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationPortrait]; // 设置视频的朝向
    [self.view.layer addSublayer:previewLayer];

    #pragma mark -- Button init
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(15, self.view.frame.size.height - 50 - 15, 50, 50);
    CGFloat lineWidth = backButton.frame.size.width * 0.12f;
    backButton.layer.cornerRadius = backButton.frame.size.width / 2;
    backButton.layer.borderColor = [UIColor whiteColor].CGColor;
    backButton.layer.borderWidth = lineWidth;
    [backButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [backButton setTitle:@"返回" forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(backButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
    
    #pragma mark -- Sin
    sinGL = [[SinGL alloc] initWithFrame:CGRectMake(0, 0, 180, 320)];
    [self.view addSubview:sinGL];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [captureSession startRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [captureSession stopRunning];
}

#pragma mark --  返回
- (void)backButtonEvent:(id)sender {
    dispatch_sync(encodeQueue, ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark --  AVCaptureVideo(Audio)DataOutputSampleBufferDelegate method
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    dispatch_sync(encodeQueue, ^{
        if (connection == videoCaptureConnection) {
            CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            CMTime ptsTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
            CGFloat pts = CMTimeGetSeconds(ptsTime);
            
            [sinGL renderBuffer:pixelBuffer];
        }
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    
}

@end
