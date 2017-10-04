//
//  SinGL.h
//  shake-picture
//
//  Created by suntongmian on 2017/10/4.
//  Copyright © 2017年 Pili Engineering, Qiniu Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface SinGL : UIView

- (void)renderBuffer:(CVPixelBufferRef)pixelBuffer;

@end
