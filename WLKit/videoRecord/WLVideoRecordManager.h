//
//  WLVideoRecordManager.h
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/26.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WLVideoRecordStatusIdle,
    WLVideoRecordStatusRecording,
    WLVideoRecordStatusFailed,
    WLVideoRecordStatusFinished,
} WLVideoRecordStatus;

@class WLVideoRecordManager;

@protocol WLVideoRecordManagerDelegate <NSObject>

@optional

/**
 视频录制过程中状态改变的回调

 @param manager 录制器
 @param status 状态
 */
- (void)videoRecordManager:(WLVideoRecordManager *)manager statusIsChange:(WLVideoRecordStatus)status;

/**
 视频录制时长的回调

 @param manager 录制器
 @param duration 时长
 */
- (void)videoRecordManager:(WLVideoRecordManager *)manager recordDuration:(double)duration;

@end

@interface WLVideoRecordManager : NSObject

@property (nonatomic, weak)                 id<WLVideoRecordManagerDelegate>    delegate;

/**
 设置视频预览层
 */
@property (nonatomic, strong)               UIView                      *preview;

/**
 是否是前置摄像头
 */
@property (nonatomic, assign)               BOOL                        frontCamera;

/**
 闪光灯
 */
@property (nonatomic, assign)               BOOL                        torch;

/**
 输出的帧格式是否需要yuv 默认为NO
 */
@property (nonatomic, assign)               BOOL                        isOutputYUV;

/**
 视频文件输出路径
 */
@property (nonatomic, copy)                 NSString                    *outputPath;

/**
 录制状态
 */
@property (nonatomic, readonly, assign)     WLVideoRecordStatus         recordStatus;

/**
 开始预览
 */
- (void)startPreview;

/**
 结束预览
 */
- (void)stopPreview;

/**
 开始录制
 */
- (void)startRecord;

/**
 停止录制
 */
- (void)stopRecord;

/**
 截屏方法

 @return 图片
 */
- (UIImage *)screenShot;

@end

NS_ASSUME_NONNULL_END
