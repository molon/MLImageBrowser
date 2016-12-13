//
//  SDWebImageLoaderForMLImageBrowser.h
//  MLImageBrowser
//
//  Created by molon on 2016/12/13.
//  Copyright © 2016年 molon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MLImageBrowser.h>
#import <SDWebImage/SDWebImageManager.h>

@interface SDWebImageLoaderForMLImageBrowser : NSObject<MLImageBrowserLoaderProtocol>

+ (instancetype)sharedInstance;

@end
