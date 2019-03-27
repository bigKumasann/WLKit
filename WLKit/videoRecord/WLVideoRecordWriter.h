//
//  WLVideoRecordWriter.h
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/26.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMFormatDescription.h>
#import <CoreMedia/CMSampleBuffer.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WLVideoRecordWriterStatusIdle,
    WLVideoRecordWriterStatusPreparingToRecord,
    WLVideoRecordWriterStatusRecording,
    WLVideoRecordWriterStatusFinishRecordStep1,
    WLVideoRecordWriterStatusFinishRecordStep2,
    WLVideoRecordWriterStatusFinishRecord,
    WLVideoRecordWriterStatusRecordFailed,
} WLVideoRecordWriterStatus;

@class WLVideoRecordWriter;

@protocol WLVideoRecordWriterDelegate <NSObject>

@optional

/**
 录制前的准备工作结束的回调

 @param writer
 */
- (void)WLVideoRecordWriterDidFinishPreparingRecord:(WLVideoRecordWriter *)writer;

/**
 录制失败的回调

 @param writer
 @param error 报错信息
 */
- (void)WLVideoRecordWriter:(WLVideoRecordWriter *)writer didFailWithError:(NSError *)error;

/**
 录制结束的回调

 @param writer
 */
- (void)WLVideoRecordWriterDidFinishRecord:(WLVideoRecordWriter *)writer;

@end

@interface WLVideoRecordWriter : NSObject

@property (nonatomic, weak)             id<WLVideoRecordWriterDelegate>             writeDelegate;

/**
 构造方法

 @param url 视频存储路径
 @param delegate 委托
 @return 实例对象
 */
- (instancetype)initWithURL:(NSURL *)url withDelegate:(id<WLVideoRecordWriterDelegate>)delegate;

/**
 开始录制
 */
- (void)startRecord;

/**
 结束录制
 */
- (void)stopRecord;

/**
 写入视频数据

 @param buffer 视频数据
 */
- (void)appendVideoSampleBuffer:(CMSampleBufferRef)buffer;

/**
 写入音频数据

 @param buffer 音频数据
 */
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)buffer;

/**
 添加视频数据的相关信息

 @param formatDescription 描述
 @param transform 缩放
 @param videoSettings 配置
 */
- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings;

/**
 添加音频数据的相关信息

 @param formatDescription 描述
 @param audioSettings 配置
 */
- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings;

@end

NS_ASSUME_NONNULL_END
