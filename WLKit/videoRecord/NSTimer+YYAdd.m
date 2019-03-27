//
//  NSTimer+YYAdd.m
//  JSCoreDemo
//
//  Created by 16071995 on 2019/3/27.
//  Copyright © 2019 wanglei. All rights reserved.
//

#import "NSTimer+YYAdd.h"

@implementation NSTimer (YYAdd)

+ (void)yy_execBlock:(NSTimer *)timer {
    if ([timer userInfo]) {
        void (^block)(NSTimer *tim) = (void(^)(NSTimer *tim))[timer userInfo];
        block(timer);
    }
}

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds block:(void (^)(NSTimer *timer))block repeats:(BOOL)repeats {
    return [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(yy_execBlock:) userInfo:block repeats:repeats];
}

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)seconds block:(void (^)(NSTimer *timer))block repeats:(BOOL)repeats {
//    return [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(yy_execBlock:) userInfo:block repeats:repeats];
    return [NSTimer timerWithTimeInterval:seconds target:self selector:@selector(yy_execBlock:) userInfo:block repeats:repeats];
}

@end
