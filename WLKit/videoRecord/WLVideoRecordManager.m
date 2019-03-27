//
//  WLVideoRecordManager.m
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/26.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import "WLVideoRecordManager.h"
#import "WLVideoRecordCamera.h"
#import "WLAudioRecordMicrophone.h"
#import "WLVideoRecordWriter.h"
#import "NSTimer+YYAdd.h"

@interface WLVideoRecordManager()<WLVideoRecordCameraDelegate,WLAudioRecordMicrophoneDelegate,WLVideoRecordWriterDelegate>
{
    dispatch_semaphore_t screenShotSema;//截屏信号量
}

/**
 摄像头
 */
@property (nonatomic, strong)           WLVideoRecordCamera                     *camera;

/**
 麦克风
 */
@property (nonatomic, strong)           WLAudioRecordMicrophone                 *microphone;

/**
 录制器
 */
@property (nonatomic, strong)           WLVideoRecordWriter                     *assetWriter;

/**
 视频数据信息
 */
@property (nonatomic, assign)           CMFormatDescriptionRef                  outputVideoFormatDescription;

/**
 音频数据信息
 */
@property (nonatomic, assign)           CMFormatDescriptionRef                  outputAudioFormatDescription;

/**
 录制时长
 */
@property (nonatomic, assign)           NSTimeInterval                          recordDuration;

/**
 录制时长定时器
 */
@property (nonatomic, strong)           NSTimer                                 *progressTimer;

/**
 是否应该截屏
 */
@property (nonatomic, assign)           BOOL                                    shouldGetScreenShot;

/**
 截屏图片
 */
@property (nonatomic, strong)           UIImage                                 *screenShot;

/**
 是否处于preview状态
 */
@property (nonatomic, assign)           BOOL                                    isPreviewing;

@end

@implementation WLVideoRecordManager

#pragma mark - public methods

- (void)startPreview {
    
    //获取相机和麦克风权限
    dispatch_group_t authorityGroup = dispatch_group_create();
    dispatch_queue_t authorityQueue = dispatch_queue_create("WLVideoRecordManager.authority.queue", DISPATCH_QUEUE_CONCURRENT);
    __block BOOL  isReadyForAudio = NO;
    __block BOOL  isReadyForVideo = NO;
    dispatch_group_enter(authorityGroup);
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            isReadyForAudio = YES;
        }else{
            isReadyForAudio = NO;
        }
        dispatch_group_leave(authorityGroup);
    }];
    dispatch_group_enter(authorityGroup);
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted) {
            isReadyForVideo = YES;
        }else{
            isReadyForVideo = NO;
        }
        dispatch_group_leave(authorityGroup);
    }];
    
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(authorityGroup, authorityQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isReadyForAudio && isReadyForVideo) {
                [weakSelf.camera startPreview];
                [weakSelf.microphone startCaptureAudio];
                weakSelf.isPreviewing = YES;
            }
        });
    });
    
}

- (void)stopPreview {
    
    if (self.recordStatus == WLVideoRecordStatusRecording || !self.isPreviewing) {
        return;
    }
    
    [self.camera stopPreview];
    [self.microphone stopCaptureAudio];
    self.isPreviewing = NO;
    
}

- (void)startRecord {
    
    if (!self.isPreviewing) {
        return;
    }
    
    [self.assetWriter addVideoTrackWithSourceFormatDescription:self.outputVideoFormatDescription transform:CGAffineTransformIdentity settings:self.camera.videoCompressingSettings];
    [self.assetWriter addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription settings:self.microphone.audioCompressingSettings];
    
    [self.assetWriter startRecord];
}

- (void)stopRecord {
    
    [self.assetWriter stopRecord];
    
}

- (UIImage *)screenShot {
    
    screenShotSema = dispatch_semaphore_create(0);
    self.shouldGetScreenShot = YES;
    
    dispatch_semaphore_wait(screenShotSema, DISPATCH_TIME_FOREVER);
    
    return self.screenShot;
    
}

#pragma mark - private methods

/**
 根据帧数据获取uiimage
 
 @param buffer 帧数据
 */
- (UIImage *)takePhoto:(CMSampleBufferRef)buffer {
    
    if (!CMSampleBufferIsValid(buffer)) {
        return nil;
    }
    
    //kCVPixelFormatType_32BGRA 必须使用下面这种的转image方式才能成功
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    //UIImage *image = [UIImage imageWithCGImage:quartzImage];
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:UIImageOrientationUp];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return image;
    
}

#pragma mark - WLVideoRecordCameraDelegate,WLAudioRecordMicrophoneDelegate

- (void)videoCaptureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    //获取每一帧图像信息
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferRef resultPixelBufffer = pixelBuffer;
    
    @synchronized (self) {
        if (self.shouldGetScreenShot) {
            self.screenShot = [self takePhoto:sampleBuffer];
            self.shouldGetScreenShot = NO;
            dispatch_semaphore_signal(screenShotSema);
        }
    }
    
    //视频录制信息
    if (!self.outputVideoFormatDescription) {
        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &(_outputVideoFormatDescription));
    }
    @synchronized (self) {
        if (self.recordStatus == WLVideoRecordStatusRecording) {
            [self.assetWriter appendVideoSampleBuffer:sampleBuffer];
        }
    }
}

- (void)audioCaptureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (_outputAudioFormatDescription) {
        CFRelease(_outputAudioFormatDescription);
        _outputAudioFormatDescription = NULL;
    }
    _outputAudioFormatDescription = CFRetain(CMSampleBufferGetFormatDescription(sampleBuffer));
    @synchronized (self) {
        if (self.recordStatus == WLVideoRecordStatusRecording) {
            [self.assetWriter appendAudioSampleBuffer:sampleBuffer];
        }
    }
}

#pragma mark - WLVideoRecordWriterDelegate

- (void)WLVideoRecordWriterDidFinishPreparingRecord:(WLVideoRecordWriter *)writer {
    _recordStatus = WLVideoRecordStatusRecording;
    
    __weak typeof(self) weakSelf = self;
    self.recordDuration = 0;
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 block:^(NSTimer * _Nonnull timer) {
        [weakSelf refreshDuration];
    } repeats:YES];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoRecordManager:statusIsChange:)]) {
        [self.delegate videoRecordManager:self statusIsChange:_recordStatus];
    }
}

- (void)refreshDuration {
    self.recordDuration += 0.05;
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoRecordManager:recordDuration:)]) {
        [self.delegate videoRecordManager:self recordDuration:self.recordDuration];
    }
}

- (void)WLVideoRecordWriter:(WLVideoRecordWriter *)writer didFailWithError:(NSError *)error {
    _recordStatus = WLVideoRecordStatusFailed;
    _assetWriter = nil;
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoRecordManager:statusIsChange:)]) {
        [self.delegate videoRecordManager:self statusIsChange:_recordStatus];
    }
    [self.progressTimer invalidate];
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoRecordManager:recordDuration:)]) {
        [self.delegate videoRecordManager:self recordDuration:0];
    }
}

- (void)WLVideoRecordWriterDidFinishRecord:(WLVideoRecordWriter *)writer {
    _recordStatus = WLVideoRecordStatusFinished;
    _assetWriter = nil;
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoRecordManager:statusIsChange:)]) {
        [self.delegate videoRecordManager:self statusIsChange:_recordStatus];
    }
    [self.progressTimer invalidate];
}

#pragma mark - setter methods

- (void)setPreview:(UIView *)preview {
    
    if (preview && [preview isKindOfClass:[UIView class]]) {
        self.camera.previewLayer.frame = preview.bounds;
        [preview.layer addSublayer:self.camera.previewLayer];
    }
    
}

- (void)setFrontCamera:(BOOL)frontCamera {
    self.camera.devicePosition = frontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
}

- (void)setTorch:(BOOL)torch {
    self.camera.torch = torch;
}

- (void)setIsOutputYUV:(BOOL)isOutputYUV {
    self.camera.isOutputYUV = isOutputYUV;
}

- (void)setOutputPath:(NSString *)outputPath {
    _outputPath = outputPath;
    
}

#pragma mark - getter methods

- (BOOL)isOutputYUV {
    return self.camera.isOutputYUV;
}

- (BOOL)frontCamera {
    return self.camera.devicePosition == AVCaptureDevicePositionFront;
}

- (BOOL)torch {
    return self.camera.torch;
}

- (WLVideoRecordCamera *)camera {
    if (!_camera) {
        _camera = [[WLVideoRecordCamera alloc] init];
        _camera.cameraDelegate = self;
    }
    return _camera;
}

- (WLAudioRecordMicrophone *)microphone {
    if (!_microphone) {
        _microphone = [[WLAudioRecordMicrophone alloc] init];
        _microphone.delegate = self;
    }
    return _microphone;
}

- (WLVideoRecordWriter *)assetWriter {
    if (!_assetWriter) {
        _assetWriter = [[WLVideoRecordWriter alloc] initWithURL:[NSURL fileURLWithPath:self.outputPath] withDelegate:self];
    }
    return _assetWriter;
}

@end
