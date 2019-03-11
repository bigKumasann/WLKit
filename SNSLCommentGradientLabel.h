//
//  SNSLCommentGradientLabel.h
//  SNSL
//
//  Created by 16071995 on 2019/3/6.
//  Copyright © 2019 suning. All rights reserved.
//

#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface SNSLCommentGradientLabel : UIView

@property(nullable, nonatomic,copy)   NSString           *text;            // default is nil
@property(null_resettable, nonatomic,strong) UIFont      *font;            // default is nil (system font 17 plain)
@property(null_resettable, nonatomic,strong) UIColor     *textColor;       // default is nil (text draws black)
@property(nonatomic)        NSTextAlignment    textAlignment;   // default is NSTextAlignmentNatural (before iOS 9, the default was NSTextAlignmentLeft)
@property(nonatomic)        NSLineBreakMode    lineBreakMode;

/**
 渐变背景起始颜色
 */
@property (nonatomic, strong)               UIColor                     *startColor;

/**
 渐变背景终点色
 */
@property (nonatomic, strong)               UIColor                     *endColor;

@end

NS_ASSUME_NONNULL_END
