//
//  ViewController.m
//  MLImageBrowser
//
//  Created by molon on 2016/11/21.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "ViewController.h"
#import <MLImageBrowser/MLImageBrowser.h>
#import <SDWebImage/UIImageView+WebCache.h>

#define kBaseTag 100
@interface ViewController ()

@property (nonatomic, strong) NSArray *smallPics;
@property (nonatomic, strong) NSArray *largePics;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.title = @"MLImageBrowser";
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Clear Cache" style:UIBarButtonItemStylePlain target:self action:@selector(clearCache)];
    
//    self.smallPics = @[
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/1.jpg?imageView2/2/w/200",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/2.jpg?imageView2/2/w/200",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/3.jpg?imageView2/2/w/200",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/4.jpg?imageView2/2/w/200",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/5.jpg?imageView2/2/w/200",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/6.jpg?imageView2/2/w/200",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/7.jpg?imageView2/2/w/200",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/8.jpg?imageView2/2/w/200",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/9.jpg?imageView2/2/w/200",
//                       ];
//    
//    self.largePics = @[
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/1.jpg",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/2.jpg",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/3.jpg",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/4.jpg",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/5.jpg",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/6.jpg",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/7.jpg",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/8.jpg",
//                       @"http://77g7ef.com1.z0.glb.clouddn.com/9.jpg",
//                       ];
    
    self.smallPics = @[
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q1.jpg?imageView2/2/w/200",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q2.jpg?imageView2/2/w/200",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q3.jpg?imageView2/2/w/200",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q4.jpg?imageView2/2/w/200",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q5.jpg?imageView2/2/w/200",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q6.jpg?imageView2/2/w/200",
                       ];
    
    self.largePics = @[
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q1.jpg",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q2.jpg",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q3.jpg",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q4.jpg",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q5.jpg",
                       @"http://77g7ef.com1.z0.glb.clouddn.com/q6.jpg",
                       ];
    
    //    self.smallPics = @[
    //                           @"http://ww1.sinaimg.cn/thumb180/006mwaFnjw1f9wlmdp6usg30bc06e7wh.gif",
    //                           @"http://ww1.sinaimg.cn/thumb180/006mwaFnjw1f9wlmej3tcg30bc06eng2.gif",
    //                           @"http://ww1.sinaimg.cn/thumb180/006mwaFnjw1f9wlmfd9trg30bc06ekaq.gif",
    //                           @"http://ww1.sinaimg.cn/thumb180/006mwaFnjw1f9wlmg6ioqg30bc06etqk.gif",
    //                           ];
    //
    //    self.largePics = @[
    //                           @"http://ww1.sinaimg.cn/mw690/006mwaFnjw1f9wlmdp6usg30bc06e7wh.gif",
    //                           @"http://ww1.sinaimg.cn/mw690/006mwaFnjw1f9wlmej3tcg30bc06eng2.gif",
    //                           @"http://ww1.sinaimg.cn/mw690/006mwaFnjw1f9wlmfd9trg30bc06ekaq.gif",
    //                           @"http://ww1.sinaimg.cn/mw690/006mwaFnjw1f9wlmg6ioqg30bc06etqk.gif",
    //                           ];
    
    for (NSInteger i=0; i<self.smallPics.count; i++) {
        UIImageView *imgV = [UIImageView new];
        imgV.clipsToBounds = YES;
        imgV.contentMode = UIViewContentModeScaleAspectFill;
        [imgV sd_setImageWithURL:[NSURL URLWithString:self.smallPics[i]]];
        imgV.tag = kBaseTag + i;
        imgV.backgroundColor = [UIColor colorWithWhite:0.865 alpha:1.000];
        imgV.userInteractionEnabled = YES;
        [imgV addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap:)]];
        
        [self.view addSubview:imgV];
    }
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - layout
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
#define kSpace 5.0f
#define kCountOneLine 3
    CGFloat side = (self.view.frame.size.width-kSpace*2)/kCountOneLine-kSpace*2;
    
    CGFloat baseY = 80.0f;
    CGFloat baseX = kSpace*2;
    for (NSInteger i=0; i<self.smallPics.count; i++) {
        UIView *v = [self.view viewWithTag:kBaseTag+i];
        v.frame = CGRectMake(baseX, baseY, side, side);
        
        baseX = baseX+side+kSpace*2;
        if (baseX>self.view.frame.size.width) {
            baseX = kSpace*2;
            baseY+=side+kSpace*2;
        }
    }
}

#pragma mark - event
- (void)clearCache {
    [[SDImageCache sharedImageCache]clearDisk];
    [[SDImageCache sharedImageCache]clearMemory];
}

- (void)tap:(UITapGestureRecognizer*)ges {
    NSInteger index = ges.view.tag-kBaseTag;

    MLImageBrowser *bl = [MLImageBrowser new];
    NSMutableArray *its = [NSMutableArray arrayWithCapacity:self.smallPics.count];
    for (NSInteger i=0; i<self.smallPics.count; i++) {
        [its addObject:[MLImageBrowserItem itemWithThumbView:[self.view viewWithTag:kBaseTag+i] largeImageURL:self.largePics[i]]];
    }
    [bl presentWithItems:its atIndex:index onWindowLevel:UIWindowLevelNormal animated:YES completion:nil];
}

@end
