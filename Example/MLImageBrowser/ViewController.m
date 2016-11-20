//
//  ViewController.m
//  MLImageBrowser
//
//  Created by molon on 2016/11/21.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "ViewController.h"
#import <MLImageBrowser.h>
#import <UIImageView+WebCache.h>

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
    
    //建立9个图片view
    self.smallPics = @[
                           @"http://ww1.sinaimg.cn/thumb180/006mwaFnjw1f9wlmdp6usg30bc06e7wh.gif",
                           @"http://ww1.sinaimg.cn/thumb180/006mwaFnjw1f9wlmej3tcg30bc06eng2.gif",
                           @"http://ww1.sinaimg.cn/thumb180/006mwaFnjw1f9wlmfd9trg30bc06ekaq.gif",
                           @"http://ww1.sinaimg.cn/thumb180/006mwaFnjw1f9wlmg6ioqg30bc06etqk.gif",
//                           @"",
//                           @"",
//                           @"",
//                           @"",
//                           @"",
                           ];

    self.largePics = @[
                           @"http://ww1.sinaimg.cn/mw690/006mwaFnjw1f9wlmdp6usg30bc06e7wh.gif",
                           @"http://ww1.sinaimg.cn/mw690/006mwaFnjw1f9wlmej3tcg30bc06eng2.gif",
                           @"http://ww1.sinaimg.cn/mw690/006mwaFnjw1f9wlmfd9trg30bc06ekaq.gif",
                           @"http://ww1.sinaimg.cn/mw690/006mwaFnjw1f9wlmg6ioqg30bc06etqk.gif",
//                           @"",
//                           @"",
//                           @"",
//                           @"",
//                           @"",
                           ];
    
    
    for (NSInteger i=0; i<self.smallPics.count; i++) {
        UIImageView *imgV = [UIImageView new];
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
