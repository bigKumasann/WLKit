//
//  WLAudioRecordMicrophone.h
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/26.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WLAudioRecordMicrophoneDelegate <NSObject>

@optional

- (void)audioCaptureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

@end

@interface WLAudioRecordMicrophone : NSObject

@property (nonatomic, weak)             id<WLAudioRecordMicrophoneDelegate>                             delegate;

/**
 音频信息回调队列
 */
@property (nonatomic, readonly)         dispatch_queue_t                                                callbackQueue;

/**
 AVCaptureSession用来建立和维护AVCaptureInput和AVCaptureOutput之间的连接的
 */
@property (nonatomic, readonly)         AVCaptureConnection                                             *audioConnection;

/**
 音频配置信息
 */
@property (nonatomic, strong)           NSDictionary                                                    *audioCompressingSettings;

/**
 开始采集音频
 */
- (void)startCaptureAudio;

/**
 停止采集音频
 */
- (void)stopCaptureAudio;

@end

NS_ASSUME_NONNULL_END
