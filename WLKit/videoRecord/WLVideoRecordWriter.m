//
//  WLVideoRecordWriter.m
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/26.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import "WLVideoRecordWriter.h"
#import <AVFoundation/AVFoundation.h>

@interface WLVideoRecordWriter()

/**
 写入器
 */
@property (nonatomic, strong)               AVAssetWriter                           *writer;

/**
 写数据队列  串行队列
 */
@property (nonatomic, strong)               dispatch_queue_t                        writeQueue;

/**
 回调队列   串行队列
 */
@property (nonatomic, strong)               dispatch_queue_t                        callbackQueue;

/**
 视频输入
 */
@property (nonatomic, strong)               AVAssetWriterInput                      *videoInput;

/**
 音频输入
 */
@property (nonatomic, strong)               AVAssetWriterInput                      *audioInput;

/**
 视频描述信息
 */
@property (nonatomic, assign)               CMFormatDescriptionRef                  videoFormatDescription;

/**
 音频描述信息
 */
@property (nonatomic, assign)               CMFormatDescriptionRef                  audioFormatDescription;

/**
 视频内容配置信息
 */
@property (nonatomic, copy)                 NSDictionary                            *videoSettingDic;

/**
 音频内容配置信息
 */
@property (nonatomic, copy)                 NSDictionary                            *audioSettingDic;

/**
 视频缩放大小
 */
@property (nonatomic, assign)               CGAffineTransform                       videoTrackTransform;

/**
 是否开始写入文件
 */
@property (nonatomic, assign)               BOOL                                    haveStartedWrite;

/**
 录制状态
 */
@property (nonatomic, assign)               WLVideoRecordWriterStatus               status;

/**
 视频文件地址
 */
@property (nonatomic, copy)                 NSURL                                   *fileURL;

/**
 是否允许写入音频，当视频写入失败时要停止写入音频 否则会导致音轨不同步
 */
@property (nonatomic, assign)               BOOL                                    allowWriteAudio;

@end

@implementation WLVideoRecordWriter

- (instancetype)initWithURL:(NSURL *)url withDelegate:(id<WLVideoRecordWriterDelegate>)delegate {
    
    if (![url.absoluteString hasPrefix:@"file"]) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        self.writeQueue = dispatch_queue_create("WLVideoRecordWriter.writer.queue", DISPATCH_QUEUE_SERIAL);
        self.callbackQueue = dispatch_queue_create("WLVideoRecordWriter.writer.callbackqueue", DISPATCH_QUEUE_SERIAL);
        self.writeDelegate = delegate;
        self.fileURL = url;
        self.videoTrackTransform = CGAffineTransformIdentity;
        self.status = WLVideoRecordWriterStatusIdle;
        self.allowWriteAudio = YES;
    }
    
    return self;
}

- (void)dealloc {
    if (_audioFormatDescription) {
        CFRelease(_audioFormatDescription);
    }
    
    if (_videoFormatDescription) {
        CFRelease(_videoFormatDescription);
    }
}

#pragma mark - 数据传入

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)buffer {
    [self appendSampleBuffer:buffer withType:AVMediaTypeVideo];
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)buffer {
    if (self.allowWriteAudio) {
        [self appendSampleBuffer:buffer withType:AVMediaTypeAudio];
    }
}

- (void)appendSampleBuffer:(CMSampleBufferRef)buffer withType:(NSString *)mediaType {
    
    if (buffer == NULL) {
        return;
    }
    
    @synchronized (self) {
        if (self.status != WLVideoRecordWriterStatusRecording) {
            return;
        }
    }
    
    CFRetain(buffer);
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.writeQueue, ^{
        
        @synchronized (weakSelf) {
            if (weakSelf.status > WLVideoRecordWriterStatusFinishRecordStep1) {
                CFRelease(buffer);
                return;
            }
        }
        
        if (!weakSelf.haveStartedWrite) {
            CMTime time = CMSampleBufferGetPresentationTimeStamp(buffer);
            [weakSelf.writer startSessionAtSourceTime:time];
            weakSelf.haveStartedWrite = YES;
        }
        
        AVAssetWriterInput *input = mediaType == AVMediaTypeVideo ? self.videoInput : self.audioInput;
        if (input.isReadyForMoreMediaData) {
            BOOL isSuccess = [input appendSampleBuffer:buffer];
            if (!isSuccess) {
                weakSelf.allowWriteAudio = NO;
                NSError *error = weakSelf.writer.error;
                [weakSelf transitionToStatus:WLVideoRecordWriterStatusRecordFailed error:error];
            } else {
                weakSelf.allowWriteAudio = YES;
            }
        }
        CFRelease(buffer);
    });
    
    
}

#pragma mark - public methods

- (void)startRecord {
    
    if (self.status != WLVideoRecordWriterStatusIdle || self.status == WLVideoRecordWriterStatusFinishRecord || self.status == WLVideoRecordWriterStatusRecordFailed) {
        return;
    }
    
    [self transitionToStatus:WLVideoRecordWriterStatusPreparingToRecord error:nil];
    
    @synchronized (self) {
        NSError *error;
        self.writer = [AVAssetWriter assetWriterWithURL:self.fileURL fileType:AVFileTypeMPEG4 error:&error];
        
        if (!error && self.videoFormatDescription) {
            [self setupAssetWriterVideoInputWithSourceFormatDescription:self.videoFormatDescription transform:self.videoTrackTransform settings:self.videoSettingDic error:&error];
        }
        
        if (!error && self.audioFormatDescription) {
            [self setupAssetWriterAudioInputWithSourceFormatDescription:self.audioFormatDescription settings:self.audioSettingDic error:&error];
        }
        
        if (!error) {
            BOOL isSuccess = [self.writer startWriting];
            if (!isSuccess) {
                error = self.writer.error;
            }
        }
        
        if (!error) {
            [self transitionToStatus:WLVideoRecordWriterStatusRecording error:nil];
        } else {
            [self transitionToStatus:WLVideoRecordWriterStatusRecordFailed error:error];
        }
        
    }
    
}

- (void)stopRecord {
    
    if (self.status != WLVideoRecordWriterStatusRecording) {
        return;
    }
    
    [self transitionToStatus:WLVideoRecordWriterStatusFinishRecordStep1 error:nil];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.writeQueue, ^{
        @synchronized (weakSelf) {
            
            if (weakSelf.status != WLVideoRecordWriterStatusFinishRecordStep1) {
                return;
            }
            
            //设置status为WLVideoRecordWriterStatusFinishRecordStep2 防止在停止录制时还有音视频数据被写入文件中
            [weakSelf transitionToStatus:WLVideoRecordWriterStatusFinishRecordStep2 error:nil];
            
        }
        
        [weakSelf.writer finishWritingWithCompletionHandler:^{
            
            NSError *error = weakSelf.writer.error;
            weakSelf.haveStartedWrite = NO;
            
            if (error) {
                [weakSelf transitionToStatus:WLVideoRecordWriterStatusRecordFailed error:error];
            } else {
                [weakSelf transitionToStatus:WLVideoRecordWriterStatusFinishRecord error:nil];
            }
            
            dispatch_semaphore_signal(sema);
            
        }];
        
    });
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
}

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings {
    
    if (formatDescription == NULL) {
        return;
    }
    
    @synchronized (self) {
        
        if (self.status != WLVideoRecordWriterStatusIdle) {
            return;
        }
        
        if (_videoFormatDescription) {
            return;
        }
        
        _videoFormatDescription = formatDescription;
        _videoTrackTransform = transform;
        self.videoSettingDic = videoSettings;
        
    }
    
}

- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings {
    
    if (formatDescription == NULL) {
        return;
    }
    
    @synchronized (self) {
        
        if (self.status != WLVideoRecordWriterStatusIdle) {
            return;
        }
        
        if (_audioFormatDescription) {
            return;
        }
        
        _audioFormatDescription = formatDescription;
        self.audioSettingDic = audioSettings;
        
    }
    
}

#pragma mark - private methods

- (void)transitionToStatus:(WLVideoRecordWriterStatus)status error:(NSError *)error{
    
    BOOL shouldNotifyDelegate = NO;
    
    if (self.status != status) {
        
        if (status == WLVideoRecordWriterStatusRecordFailed || status == WLVideoRecordWriterStatusFinishRecord) {
            shouldNotifyDelegate = YES;
            __weak typeof(self) weakSelf = self;
            dispatch_async(self.writeQueue, ^{
                [weakSelf releaseAssetWriteAndInputs];
                if (status == WLVideoRecordWriterStatusRecordFailed) {
                    [[NSFileManager defaultManager] removeItemAtURL:weakSelf.fileURL error:nil];
                }
            });
        } else if (status == WLVideoRecordWriterStatusRecording) {
            shouldNotifyDelegate = YES;
        }
        
        self.status = status;
        
    }
    
    if (shouldNotifyDelegate) {
        
        __weak typeof(self) weakSelf = self;
        
        dispatch_async(self.callbackQueue, ^{
            //保证在主线程回调
            dispatch_async(dispatch_get_main_queue(), ^{
                switch (weakSelf.status) {
                    case WLVideoRecordWriterStatusRecordFailed:
                        [weakSelf.writeDelegate WLVideoRecordWriter:weakSelf didFailWithError:error];
                        break;
                    case WLVideoRecordWriterStatusRecording:
                        [weakSelf.writeDelegate WLVideoRecordWriterDidFinishPreparingRecord:weakSelf];
                        break;
                    case WLVideoRecordWriterStatusFinishRecord:
                        [weakSelf.writeDelegate WLVideoRecordWriterDidFinishRecord:weakSelf];
                        break;
                    default:
                        break;
                }
            });
        });
        
        
    }
    
}

- (void)releaseAssetWriteAndInputs {
    _writer = nil;
    _videoInput = nil;
    _audioInput = nil;
}

//设置音频输入给avassetwriter
- (BOOL)setupAssetWriterAudioInputWithSourceFormatDescription:(CMFormatDescriptionRef)audioFormatDescription settings:(NSDictionary *)audioSettings error:(NSError **)errorOut {
    if (!audioSettings) {
        audioSettings = @{ AVFormatIDKey : @(kAudioFormatMPEG4AAC) };
    }
    
    if ([self.writer canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio]) {
        self.audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings sourceFormatHint:audioFormatDescription];
        self.audioInput.expectsMediaDataInRealTime = YES;
        
        if ([self.writer canAddInput:self.audioInput]) {
            [self.writer addInput:self.audioInput];
        }
        else {
            if (errorOut) {
                *errorOut = [[self class] cannotSetupInputError];
            }
            return NO;
        }
    }
    else {
        if (errorOut) {
            *errorOut = [[self class] cannotSetupInputError];
        }
        return NO;
    }
    
    return YES;
}

//给avassetwriter设置视频输入
- (BOOL)setupAssetWriterVideoInputWithSourceFormatDescription:(CMFormatDescriptionRef)videoFormatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings error:(NSError **)errorOut {
    if (!videoSettings) {
        float bitsPerPixel;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(videoFormatDescription);
        int numPixels = dimensions.width * dimensions.height;
        int bitsPerSecond;
        
        
        // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
        if (numPixels < (640 * 480)) {
            bitsPerPixel = 4.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
        }
        else {
            bitsPerPixel = 10.1; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetHigh.
        }
        
        bitsPerSecond = numPixels * bitsPerPixel;
        
        NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                                 AVVideoExpectedSourceFrameRateKey : @(30),
                                                 AVVideoMaxKeyFrameIntervalKey : @(30) };
        
        videoSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                           AVVideoWidthKey : @(dimensions.width),
                           AVVideoHeightKey : @(dimensions.height),
                           AVVideoCompressionPropertiesKey : compressionProperties };
    }
    
    if ([_writer canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo]) {
        self.videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings sourceFormatHint:videoFormatDescription];
        self.videoInput.expectsMediaDataInRealTime = YES;
        self.videoInput.transform = transform;
        
        if ([self.writer canAddInput:_videoInput]) {
            [self.writer addInput:self.videoInput];
        }
        else {
            if (errorOut) {
                *errorOut = [[self class] cannotSetupInputError];
            }
            return NO;
        }
    }
    else {
        if (errorOut) {
            *errorOut = [[self class] cannotSetupInputError];
        }
        return NO;
    }
    
    return YES;
}

+ (NSError *)cannotSetupInputError {
    NSString *localizedDescription = NSLocalizedString(@"Recording cannot be started", nil);
    NSString *localizedFailureReason = NSLocalizedString(@"Cannot setup asset writer input.", nil);
    NSDictionary *errorDict = @{ NSLocalizedDescriptionKey : localizedDescription,
                                 NSLocalizedFailureReasonErrorKey : localizedFailureReason };
    return [NSError errorWithDomain:@"com.apple.dts.samplecode" code:0 userInfo:errorDict];
}

@end
