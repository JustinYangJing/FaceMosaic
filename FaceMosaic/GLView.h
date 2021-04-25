//
//  GLView.h
//  FaceMosaic
//
//  Created by JustinYang on 2021/4/19.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface GLView : UIView
-(void)setBlurRadius:(int)radius pixelSize:(CGSize)size;
-(void)renderCVImageBuffer:(CVPixelBufferRef )pixelBuf normalsFaceBounds:(NSArray *)bounds;

@end

NS_ASSUME_NONNULL_END
