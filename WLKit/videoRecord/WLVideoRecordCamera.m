//
//  WLVideoRecordCamera.m
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/26.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import "WLVideoRecordCamera.h"

@interface WLVideoRecordCamera()<AVCaptureVideoDataOutputSampleBufferDelegate>

/**
 帧操作队列
 */
@property (nonatomic, strong)           dispatch_queue_t                    bufferQueue;

/**
 视频session
 */
@property (nonatomic, strong)           AVCaptureSession                    *videoSession;

/**
 视频录入设备
 */
@property (nonatomic, strong)           AVCaptureDevice                     *videoDevice;

/**
 采集设备输入端
 */
@property (nonatomic, strong)           AVCaptureDeviceInput                *inputDevice;

/**
 视频数据的输出端
 */
@property (nonatomic, strong)           AVCaptureVideoDataOutput            *dataOutput;

@end

@implementation WLVideoRecordCamera

- (id)init {
    self = [super init];
    
    if (self) {
        _bufferQueue = dispatch_queue_create("wlVieoRecord.camera.queue", DISPATCH_QUEUE_SERIAL);
        _devicePosition = AVCaptureDevicePositionBack;
        _isOutputYUV = NO;
        _needVideoMirrored = YES;
        _iFPS = 25;
        _videoOrientation = AVCaptureVideoOrientationPortrait;
        _sessionPreset = AVCaptureSessionPreset1280x720;
        _sessionPaused = YES;
        
        [self setupConfiguration];
        
    }
    
    return self;
}

#pragma mark - public methods

- (void)startPreview {
    [self.videoSession startRunning];
    _sessionPaused = NO;
}

- (void)stopPreview {
    [self.videoSession stopRunning];
    _sessionPaused = YES;
}

#pragma mark - setter methods

- (void)setIsOutputYUV:(BOOL)isOutputYUV {
    if (_isOutputYUV != isOutputYUV) {
        _isOutputYUV = isOutputYUV;
        int iCVPixelFormatType = _isOutputYUV ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_32BGRA;
        self.dataOutput = [self getDataOutputWithPixelFormatType:iCVPixelFormatType];
        _sessionPaused = YES;
        [self.videoSession beginConfiguration];
        //设置输出
        if ([self.videoSession canAddOutput:self.dataOutput]) {
            [self.videoSession addOutput:self.dataOutput];
        }
        [self.videoSession commitConfiguration];
        _sessionPaused = NO;
    }
}

- (void)setIFPS:(int)iFPS {
    if (_iFPS != iFPS) {
        _iFPS = iFPS;
        _sessionPaused = YES;
        [self.videoSession beginConfiguration];
        //设置帧率
        if ([self.videoDevice lockForConfiguration:nil]) {
            CMTime time = CMTimeMake(1, _iFPS);
            self.videoDevice.activeVideoMaxFrameDuration = time;
            self.videoDevice.activeVideoMinFrameDuration = time;
            [self.videoDevice unlockForConfiguration];
        }
        [self.videoSession commitConfiguration];
        _sessionPaused = NO;
    }
}

- (void)setDevicePosition:(AVCaptureDevicePosition)devicePosition {
    if (_devicePosition != devicePosition && devicePosition != AVCaptureDevicePositionUnspecified) {
        
        AVCaptureDevice *device = [self cameraDeviceWithPosition:devicePosition];
        NSError *error = nil;
        AVCaptureDeviceInput *inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (!inputDevice || error) {
            return;
        }
        
        _sessionPaused = YES;
        [self.videoSession beginConfiguration];
        [self.videoSession removeInput:self.inputDevice];
        if ([self.videoSession canAddInput:inputDevice]) {
            [self.videoSession addInput:inputDevice];
            self.videoDevice = device;
            _devicePosition = devicePosition;
            self.inputDevice = inputDevice;
        }
        
        //镜像图片，前置摄像头时最好设置成YES
        if ([_videoConnection isVideoMirroringSupported] && _devicePosition == AVCaptureDevicePositionFront && self.needVideoMirrored) {
            [_videoConnection setVideoMirrored:YES];
        } else {
            [_videoConnection setVideoMirrored:NO];
        }
        
        [self.videoSession commitConfiguration];
        _sessionPaused = NO;
    }
}

- (void)setSessionPreset:(NSString *)sessionPreset {
    if (sessionPreset && _videoSession) {
        
        _sessionPaused = YES;
        
        [self.videoSession beginConfiguration];
        
        //设置分辨率
        if ([self.videoSession canSetSessionPreset:sessionPreset]) {
            [self.videoSession setSessionPreset:sessionPreset];
            _sessionPreset = sessionPreset;
        }
        
        if (self.iFPS > 0) {
            //设置帧率
            if ([self.videoDevice lockForConfiguration:nil]) {
                CMTime time = CMTimeMake(1, self.iFPS);
                self.videoDevice.activeVideoMaxFrameDuration = time;
                self.videoDevice.activeVideoMinFrameDuration = time;
                [self.videoDevice unlockForConfiguration];
            }
        }
        
        [self.videoSession commitConfiguration];
        
        _sessionPaused = NO;
        
    }
}

- (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation {
    if (videoOrientation != _videoOrientation) {
        _sessionPaused = YES;
        
        [self.videoSession beginConfiguration];
        
        if ([_videoConnection isVideoOrientationSupported]) {
            [_videoConnection setVideoOrientation:videoOrientation];
            _videoOrientation = videoOrientation;
        }
        
        [self.videoSession commitConfiguration];
        
        _sessionPaused = NO;
        
    }
}

- (void)setNeedVideoMirrored:(BOOL)needVideoMirrored {
    if (needVideoMirrored != _needVideoMirrored) {
        _needVideoMirrored = needVideoMirrored;
        _sessionPaused = YES;
        [self.videoSession beginConfiguration];
        //镜像图片，前置摄像头时最好设置成YES
        if ([_videoConnection isVideoMirroringSupported] && self.devicePosition == AVCaptureDevicePositionFront) {
            [_videoConnection setVideoMirrored:_needVideoMirrored];
        }
        [self.videoSession commitConfiguration];
        _sessionPaused = NO;
    }
}

- (void)setTorch:(BOOL)torch {
    if ([self.videoDevice hasTorch]) {
        if ([self.videoDevice lockForConfiguration:nil]) {
            if (torch) {
                [self.videoDevice setTorchMode:AVCaptureTorchModeOn];
            } else {
                [self.videoDevice setTorchMode:AVCaptureTorchModeOff];
            }
        }
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (self.cameraDelegate && [self.cameraDelegate respondsToSelector:@selector(videoCaptureOutput:didOutputSampleBuffer:fromConnection:)]) {
        [self.cameraDelegate videoCaptureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

#pragma mark - custom methods

- (void)setupConfiguration {
    
    int iCVPixelFormatType = self.isOutputYUV ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_32BGRA;
    
    self.dataOutput = [self getDataOutputWithPixelFormatType:iCVPixelFormatType];
    
    [self.videoSession beginConfiguration];
    
    //设置分辨率
    if ([self.videoSession canSetSessionPreset:self.sessionPreset]) {
        [self.videoSession setSessionPreset:self.sessionPreset];
    }
    
    //设置帧率
    if ([self.videoDevice lockForConfiguration:nil]) {
        CMTime time = CMTimeMake(1, self.iFPS);
        self.videoDevice.activeVideoMaxFrameDuration = time;
        self.videoDevice.activeVideoMinFrameDuration = time;
        [self.videoDevice unlockForConfiguration];
    }
    
    //设置输入
    if ([self.videoSession canAddInput:self.inputDevice]) {
        [self.videoSession addInput:self.inputDevice];
    }
    
    //设置输出
    if ([self.videoSession canAddOutput:self.dataOutput]) {
        [self.videoSession addOutput:self.dataOutput];
    }
    
    _videoConnection = [self.dataOutput connectionWithMediaType:AVMediaTypeVideo];
    if ([_videoConnection isVideoOrientationSupported]) {
        [_videoConnection setVideoOrientation:self.videoOrientation];
    }
    //镜像图片，前置摄像头时最好设置成YES
    if ([_videoConnection isVideoMirroringSupported] && self.devicePosition == AVCaptureDevicePositionFront && self.needVideoMirrored) {
        [_videoConnection setVideoMirrored:YES];
    }
    
    [self.videoSession commitConfiguration];
    
    self.videoCompressingSettings = [[self.dataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] copy];
    
}

//根据压缩格式创建一个摄像头数据输出对象
- (AVCaptureVideoDataOutput *)getDataOutputWithPixelFormatType:(OSType)pixelFormatType {
    AVCaptureVideoDataOutput * dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES];
    NSDictionary * settingDic = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:pixelFormatType]
                                                            forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [dataOutput setVideoSettings:settingDic];
    [dataOutput setSampleBufferDelegate:self queue:self.bufferQueue];
    return dataOutput;
}

//获取前置或后置摄像头
- (AVCaptureDevice *)cameraDeviceWithPosition:(AVCaptureDevicePosition)position
{
    AVCaptureDevice *deviceRet = nil;
    if (position != AVCaptureDevicePositionUnspecified) {
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if ([device position] == position) {
                deviceRet = device;
                break;
            }
        }
    }
    return deviceRet;
}

#pragma mark - getter methods

- (AVCaptureSession *)videoSession {
    if (!_videoSession) {
        _videoSession = [[AVCaptureSession alloc] init];
    }
    return _videoSession;
}

- (AVCaptureDevice *)videoDevice {
    if (!_videoDevice) {
        _videoDevice = [self cameraDeviceWithPosition:_devicePosition];
    }
    return _videoDevice;
}

- (AVCaptureDeviceInput *)inputDevice {
    if (!_inputDevice) {
        NSError *error = nil;
        _inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:&error];
    }
    return _inputDevice;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    if (!_previewLayer) {
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.videoSession];
    }
    return _previewLayer;
}

- (BOOL)torch {
    return self.videoDevice.isTorchActive;
}

@end
