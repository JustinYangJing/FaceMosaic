//
//  ViewController.m
//  MosaicWithGPUImage
//
//  Created by JustinYang on 2021/4/24.
//

#import "ViewController.h"
#import "GPUImage/GPUImage.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    GPUImagePicture *pic = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"frame_ori.jpg"]];
    GPUImageGaussianBlurFilter *filter = [[GPUImageGaussianBlurFilter alloc] init];
    filter.blurRadiusInPixels = 30;
    GPUImageView *view = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:view];
    
    [pic addTarget:filter];
    [filter addTarget:view];
    [pic processImage];
    
    
}


@end
