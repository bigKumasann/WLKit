//
//  WLAudioRecordMicrophone.m
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/26.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import "WLAudioRecordMicrophone.h"

@interface WLAudioRecordMicrophone()<AVCaptureAudioDataOutputSampleBufferDelegate>

/**
 音频采集任务
 */
@property (nonatomic, strong)               AVCaptureSession                                *audioSession;

/**
 音频采集设备
 */
@property (nonatomic, strong)               AVCaptureDevice                                 *audioDevice;

/**
 音频输入对象
 */
@property (nonatomic, strong)               AVCaptureDeviceInput                            *audioInput;

/**
 音频输出
 */
@property (nonatomic, strong)               AVCaptureAudioDataOutput                        *audioOutput;

@end

@implementation WLAudioRecordMicrophone

#pragma mark - 初始化配置

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _callbackQueue = dispatch_queue_create("WLAudioRecord.Microphone.queue", DISPATCH_QUEUE_SERIAL);
        [self setupCaptureSession];
    }
    
    return self;
}

- (void)setupCaptureSession {
    
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioOutput setSampleBufferDelegate:self queue:_callbackQueue];
    
    [self.audioSession beginConfiguration];
    
    if ([self.audioSession canAddInput:self.audioInput]) {
        [self.audioSession addInput:self.audioInput];
    }
    
    if ([self.audioSession canAddOutput:self.audioOutput]) {
        [self.audioSession addOutput:self.audioOutput];
    }
    
    [self.audioSession commitConfiguration];
    
    _audioConnection = [self.audioOutput connectionWithMediaType:AVMediaTypeAudio];
    self.audioCompressingSettings = [self.audioOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
    
}

#pragma mark - public methods

- (void)startCaptureAudio {
    [self.audioSession startRunning];
}

- (void)stopCaptureAudio {
    [self.audioSession stopRunning];
}

#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (self.delegate && [self.delegate respondsToSelector:@selector(audioCaptureOutput:didOutputSampleBuffer:fromConnection:)]) {
        [self.delegate audioCaptureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

#pragma mark - getter methods

- (AVCaptureSession *)audioSession {
    if (!_audioSession) {
        _audioSession = [[AVCaptureSession alloc] init];
    }
    return _audioSession;
}

- (AVCaptureDevice *)audioDevice {
    if (!_audioDevice) {
        _audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    }
    return _audioDevice;
}

- (AVCaptureDeviceInput *)audioInput {
    if (!_audioInput) {
        NSError *error;
        _audioInput = [AVCaptureDeviceInput deviceInputWithDevice:self.audioDevice error:&error];
    }
    return _audioInput;
}

@end
