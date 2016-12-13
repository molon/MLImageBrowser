//
//  SDWebImageLoaderForMLImageBrowser.m
//  MLImageBrowser
//
//  Created by molon on 2016/12/13.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "SDWebImageLoaderForMLImageBrowser.h"

@implementation SDWebImageLoaderForMLImageBrowser

+ (instancetype)sharedInstance {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc]init];
    });
    return instance;
}

- (id)loadImageWithURL:(NSURL *)url progress:(void(^)(CGFloat progress))progressBlock completed:(void(^)(UIImage *image, NSError *error))completedBlock {
    return [[SDWebImageManager sharedManager] downloadImageWithURL:url options:SDWebImageRetryFailed progress:^(NSInteger receivedSize, NSInteger expectedSize) {
        dispatch_main_sync_safe(^{
            progressBlock((CGFloat)receivedSize / expectedSize);
        });
    } completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        dispatch_main_sync_safe(^{
            if (!finished) {
                return;
            }
            if (completedBlock && finished) {
                completedBlock(image, error);
            }
        });
    }];
}

- (void)cancelImageLoadForIdentifier:(id)loadIdentifier {
    if (!loadIdentifier) {
        return;
    }
    
    NSAssert([[loadIdentifier class] conformsToProtocol:@protocol(SDWebImageOperation)], @"Unexpected image download identifier");
    id<SDWebImageOperation> downloadOperation = loadIdentifier;
    [downloadOperation cancel];
}

@end
