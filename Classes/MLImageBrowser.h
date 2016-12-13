//
//  MLImageBrowser.h
//  MLImageBrowser
//
//  Created by molon on 2016/11/3.
//  Copyright © 2016年 molon. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MLImageBrowserLoaderProtocol <NSObject>

- (id)loadImageWithURL:(NSURL *)url progress:(void(^)(CGFloat progress))progressBlock completed:(void(^)(UIImage *image, NSError *error))completedBlock;

- (void)cancelImageLoadForIdentifier:(id)loadIdentifier;

@end

@interface MLImageBrowserItem : NSObject

@property (nullable, nonatomic, strong, readonly) UIView *thumbView;
@property (nullable, nonatomic, strong, readonly) NSURL *largeImageURL;
@property (nullable, nonatomic, strong, readonly) UIImage *largeImage;

+ (instancetype)itemWithThumbView:(nullable UIImageView*)thumbView largeImageURL:(nullable NSURL*)largeImageURL largeImage:(nullable UIImage*)largeImage;

+ (instancetype)itemWithThumbView:(nullable UIImageView*)thumbView largeImageURL:(nullable NSURL*)largeImageURL;

@end

@interface MLImageBrowser : UIView

/**
 default 1.0f
 */
@property (nonatomic, assign) CGFloat dimmingViewAlpha;

/**
 default YES
 */
@property (nonatomic, assign) BOOL displaySaveButton;

- (void)presentWithLoader:(id<MLImageBrowserLoaderProtocol>)loader items:(NSArray*)items atIndex:(NSInteger)index onWindowLevel:(UIWindowLevel)windowLevel animated:(BOOL)animated completion:(nullable void (^)(void))completion;

- (void)dismissWithAnimted:(BOOL)animated completion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
