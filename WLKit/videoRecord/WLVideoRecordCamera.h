//
//  WLVideoRecordCamera.h
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/26.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WLVideoRecordCameraDelegate <NSObject>

@optional

- (void)videoCaptureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

@end

@interface WLVideoRecordCamera : NSObject

@property (nonatomic, weak)         id<WLVideoRecordCameraDelegate>                         cameraDelegate;

/**
 视频预览的图层
 */
@property (nonatomic, strong)       AVCaptureVideoPreviewLayer                              *previewLayer;

/**
 摄像头 前置/后置  默认后置
 */
@property (nonatomic, assign)       AVCaptureDevicePosition                                 devicePosition;

/**
 输出的帧格式是否需要yuv 默认为NO
 */
@property (nonatomic, assign)       BOOL                                                    isOutputYUV;

/**
 帧率 默认25
 */
@property (nonatomic, assign)       int                                                     iFPS;

/**
 打开前置摄像头时是否对帧做镜像处理 默认yes
 */
@property (nonatomic, assign)       BOOL                                                    needVideoMirrored;

/**
 AVCaptureSession用来建立和维护AVCaptureInput和AVCaptureOutput之间的连接的
 */
@property (nonatomic, strong, readonly)     AVCaptureConnection                             *videoConnection;

/**
 视频分辨率 默认1280
 */
@property (nonatomic, copy)         NSString                                                *sessionPreset;

/**
 视频方向 默认AVCaptureVideoOrientationPortrait
 */
@property (nonatomic, assign)       AVCaptureVideoOrientation                               videoOrientation;

/**
 视频设置
 */
@property (nonatomic, strong)       NSDictionary                                            *videoCompressingSettings;

/**
 任务是否处于暂停状态  默认为YES
 */
@property (nonatomic, assign, readonly)     BOOL                                            sessionPaused;

/**
 闪光灯是否打开  默认NO
 */
@property (nonatomic, assign)       BOOL                                                    torch;

/**
 开始采集视频信息
 */
- (void)startPreview;

/**
 结束采集视频信息
 */
- (void)stopPreview;

@end

NS_ASSUME_NONNULL_END
