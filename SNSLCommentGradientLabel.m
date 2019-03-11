//
//  SNSLCommentGradientLabel.m
//  SNSL
//
//  Created by 16071995 on 2019/3/6.
//  Copyright © 2019 suning. All rights reserved.
//

#import "SNSLCommentGradientLabel.h"
#import "Masonry.h"
#import "WLKitHeader.h"

@interface SNSLCommentGradientLabel()

/**
 标签名称
 */
@property (nonatomic, strong)               UILabel                     *titleLabel;

/**
 渐变层背景
 */
@property (nonatomic, strong)               CAGradientLayer             *gradientLayer;

@end

@implementation SNSLCommentGradientLabel

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self addSubview:self.titleLabel];
        [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(self);
            make.left.equalTo(self).offset(Get375Width(3.0f));
            make.right.equalTo(self).offset(-Get375Width(3.0f));
        }];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self addSubview:self.titleLabel];
        [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(self);
            make.left.equalTo(self).offset(Get375Width(3.0f));
            make.right.equalTo(self).offset(-Get375Width(3.0f));
        }];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setUpGradientLayer];
    
}

- (void)setUpGradientLayer {
    
    if (self.gradientLayer) {
        [self.gradientLayer removeFromSuperlayer];
        self.gradientLayer = nil;
    }
    
    if (NotNilAndNull(self.startColor) && NotNilAndNull(self.endColor)) {
        CAGradientLayer *layer = [CAGradientLayer layer];
        layer.frame = self.bounds;
        layer.colors = @[(id)self.startColor.CGColor,(id)self.endColor.CGColor];
        layer.locations = @[@0.0,@1.0];
        layer.startPoint = CGPointMake(0, 0.5);
        layer.endPoint = CGPointMake(1, 0.5);
        [self.layer insertSublayer:layer below:self.titleLabel.layer];
        self.gradientLayer = layer;
    }
    
}

#pragma mark - setter methods

- (void)setFont:(UIFont *)font {
    self.titleLabel.font = font;
}

- (void)setText:(NSString *)text {
    self.titleLabel.text = text;
}

- (void)setTextColor:(UIColor *)textColor {
    self.titleLabel.textColor = textColor;
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    self.titleLabel.textAlignment = textAlignment;
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    self.titleLabel.lineBreakMode = lineBreakMode;
}

#pragma mark - getter methods

- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] init];
    }
    return _titleLabel;
}

@end
