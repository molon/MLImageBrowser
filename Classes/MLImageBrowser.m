//
//  MLImageBrowser.m
//  MLImageBrowser
//
//  Created by molon on 2016/11/3.
//  Copyright © 2016年 molon. All rights reserved.
//

#import "MLImageBrowser.h"

static inline CGPoint _kCenterOfScrollView(UIScrollView *scrollView) {
    CGFloat offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width)?
    (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0;
    CGFloat offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height)?
    (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0;
    return CGPointMake(scrollView.contentSize.width * 0.5 + offsetX,
                       scrollView.contentSize.height * 0.5 + offsetY);
}

static inline void _kAddFadeTransitionForLayer(CALayer *layer) {
    CATransition *animation = [CATransition animation];
    animation.duration = .15f;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.type = kCATransitionFade;
    [layer addAnimation:animation forKey:nil];
}

static inline CGRect _kConvertBoundsFromViewToViewOrWindow(UIView *bView,UIView *view) {
    CGRect rect = bView.bounds;
    if (!view) {
        if ([bView isKindOfClass:[UIWindow class]]) {
            return [((UIWindow *)bView) convertRect:rect toWindow:nil];
        } else {
            return [bView convertRect:rect toView:nil];
        }
    }
    
    UIWindow *from = [bView isKindOfClass:[UIWindow class]] ? (id)bView : bView.window;
    UIWindow *to = [view isKindOfClass:[UIWindow class]] ? (id)view : view.window;
    if (!from || !to) return [bView convertRect:rect toView:view];
    if (from == to) return [bView convertRect:rect toView:view];
    rect = [bView convertRect:rect toView:from];
    rect = [to convertRect:rect fromWindow:from];
    rect = [view convertRect:rect fromView:to];
    return rect;
}

#define _ml_image_browser_dispatch_main_sync_safe(block)\
    if ([NSThread isMainThread]) {\
    block();\
    } else {\
    dispatch_sync(dispatch_get_main_queue(), block);\
    }

#define kPadding 20.0f
#define kAnimateDuration 0.25f
#define kMinMaximumZoomScale 2.5f
#define kAnimateScaleForSelf 1.10f //没有缩略图的时候的自身scale动画值
#define kMLImageBrowserCollectionViewCellPanOverstepHeight 80.0f

@interface MLImageBrowserItem()

@property (nonatomic, strong) UIView *thumbView;
@property (nonatomic, strong) NSURL *largeImageURL;
@property (nonatomic, strong) UIImage *largeImage;
@property (nonatomic, assign) BOOL originalHidden;

@end

@implementation MLImageBrowserItem

- (UIImage*)thumbImage {
    if ([_thumbView respondsToSelector:@selector(image)]) {
        return ((UIImageView *)_thumbView).image;
    }else if ([_thumbView isKindOfClass:NSClassFromString(@"_ASDisplayView")]){
        id node = [_thumbView valueForKey:@"asyncdisplaykit_node"];
        if ([node respondsToSelector:@selector(image)]) {
            return [node valueForKey:@"image"];
        }
    }
    return nil;
}

- (void)setThumbView:(UIView *)thumbView {
    _thumbView = thumbView;
    
    _originalHidden = thumbView.hidden;
}

+ (instancetype)itemWithThumbView:(UIImageView*)thumbView largeImageURL:(NSURL*)largeImageURL largeImage:(UIImage*)largeImage {
    MLImageBrowserItem *item = [self new];
    item.thumbView = thumbView;
    item.largeImageURL = largeImageURL;
    item.largeImage = largeImage;
    return item;
}

+ (instancetype)itemWithThumbView:(UIImageView*)thumbView largeImageURL:(NSURL*)largeImageURL {
    return [self itemWithThumbView:thumbView largeImageURL:largeImageURL largeImage:nil];
}

@end

@interface _MLImageBrowserViewController : UIViewController
@end

@implementation _MLImageBrowserViewController

#pragma mark Rotations
- (UIViewController *)_viewControllerDecidingAboutRotations {
    //keyWindow的话可能是UIAlert产生的，其又会要求这里去给予合适的UIInterfaceOrientationMask等值，就会产生死循环。
    //所以我们只能用AppDelegate的初始window
    UIWindow *window = [UIApplication sharedApplication].delegate.window;
    UIViewController *rootViewController = window.rootViewController;
    SEL viewControllerForSupportedInterfaceOrientationsSelector = NSSelectorFromString(@"_viewControllerForSupportedInterfaceOrientations");
    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        UIViewController *viewController = [rootViewController performSelector:viewControllerForSupportedInterfaceOrientationsSelector];
#pragma clang diagnostic pop
        return viewController?viewController:rootViewController;
    } @catch (NSException *exception) {
        return rootViewController;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    UIViewController *viewControllerToAsk = [self _viewControllerDecidingAboutRotations];
    UIInterfaceOrientationMask supportedOrientations = UIInterfaceOrientationMaskAll;
    if (viewControllerToAsk && viewControllerToAsk != self) {
        supportedOrientations = [viewControllerToAsk supportedInterfaceOrientations];
    }
    
    return supportedOrientations;
}

- (BOOL)shouldAutorotate {
    UIViewController *viewControllerToAsk = [self _viewControllerDecidingAboutRotations];
    BOOL shouldAutorotate = YES;
    if (viewControllerToAsk && viewControllerToAsk != self) {
        shouldAutorotate = [viewControllerToAsk shouldAutorotate];
    }
    return shouldAutorotate;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    UIViewController *viewControllerToAsk = [self _viewControllerDecidingAboutRotations];
    BOOL shouldAutorotate = YES;
    if (viewControllerToAsk && viewControllerToAsk != self) {
        shouldAutorotate = [viewControllerToAsk shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
    }
    return shouldAutorotate;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end

typedef NS_ENUM(NSUInteger, _MLImageBrowserLoadingShapeLayerState) {
    _MLImageBrowserLoadingShapeStateLayerHidden = 0, //消失状态
    _MLImageBrowserLoadingShapeStateLayerRotate, //旋转状态
    _MLImageBrowserLoadingShapeStateLayerProgress, //进度状态
};

@interface _MLImageBrowserLoadingShapeLayer : CAShapeLayer

@property (nonatomic, assign) CGFloat progress;

@property (nonatomic, assign) _MLImageBrowserLoadingShapeLayerState state;

@end

@implementation _MLImageBrowserLoadingShapeLayer

- (instancetype)init {
    self = [super init];
    if (self) {
#define kSideLength 25.0f
        self.frame = CGRectMake(0, 0, kSideLength, kSideLength);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:kSideLength/2];
        self.path = path.CGPath;
        self.fillColor = [UIColor clearColor].CGColor;
        self.strokeColor = [UIColor colorWithWhite:1.000 alpha:0.803].CGColor;//[UIColor colorWithWhite:0.236 alpha:1.000].CGColor;
        self.lineWidth = 3.0f;
        self.lineCap = kCALineCapSquare;
        self.strokeStart = 0;
        self.strokeEnd = 0;
        
        self.state = _MLImageBrowserLoadingShapeStateLayerHidden;
    }
    return self;
}

- (void)setProgress:(CGFloat)progress {
    progress = fmin(1.0f, progress);
    progress = fmax(0.0f, progress);
    _progress = progress;
    
    if (progress>0.05f) { //在比较短的时候还是rotate吧，用户感知较为强烈点
        self.state = _MLImageBrowserLoadingShapeStateLayerProgress;
    }else{
        self.state = _MLImageBrowserLoadingShapeStateLayerRotate;
    }
}

- (void)setState:(_MLImageBrowserLoadingShapeLayerState)state {
    BOOL stateChange = _state!=state;
    
    _state = state;
    
    void (^changeStokeEndBlock)(CGFloat) = ^(CGFloat strokeEnd) {
        if (stateChange) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
        }
        self.strokeEnd = strokeEnd;
        if (stateChange) {
            [CATransaction commit];
        }
    };
    
    switch (state) {
        case _MLImageBrowserLoadingShapeStateLayerHidden:
        {
            [self removeAllAnimations];
            self.hidden = YES;
            changeStokeEndBlock(0.0f);
        }
            break;
        case _MLImageBrowserLoadingShapeStateLayerRotate:
        {
            if (!stateChange) {
                return;
            }
            
            [self removeAllAnimations];
            self.hidden = NO;
            changeStokeEndBlock(1.0f/3.0f);
            
            CABasicAnimation* rotate = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            rotate.fillMode = kCAFillModeForwards;
            [rotate setToValue: [NSNumber numberWithFloat:M_PI/2]];
            rotate.repeatCount = FLT_MAX;
            rotate.duration = 0.25f;
            rotate.cumulative = TRUE;
            rotate.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
            [self addAnimation:rotate forKey:@"rotateAnimation"];
        }
            break;
        case _MLImageBrowserLoadingShapeStateLayerProgress:
        {
            [self removeAllAnimations];
            self.hidden = NO;
            changeStokeEndBlock(_progress);
        }
            break;
        default:
            break;
    }
}

@end

typedef NS_ENUM(NSUInteger, MLImageBrowserCollectionViewCellScrollDirection) {
    MLImageBrowserCollectionViewCellScrollDirectionNone = 0,
    MLImageBrowserCollectionViewCellScrollDirectionTop,
    MLImageBrowserCollectionViewCellScrollDirectionBottom,
};

@interface MLImageBrowserCollectionViewCell : UICollectionViewCell<UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *imageContainerView; //需要这个去辅助定位
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *errorTipsLabel;
@property (nonatomic, strong) _MLImageBrowserLoadingShapeLayer *loadingLayer;

@property (nonatomic, strong) MLImageBrowserItem *item;

@property (nonatomic, strong) id<MLImageBrowserLoaderProtocol> imageLoader;

//这个主要是怕在动画过程当中，更新布局产生了异常画面，而在动画结束之后一定要记得还原此值以强制更新布局
@property (nonatomic, assign) BOOL disableUpdateImageViewFrame;

@property (nonatomic, copy) void(^didClickBlock)(MLImageBrowserItem *item);
@property (nonatomic, copy) void(^didPanOverstepBlock)(MLImageBrowserItem *item,MLImageBrowserCollectionViewCellScrollDirection direction);
@property (nonatomic, copy) void(^pullingBlock)(MLImageBrowserItem *item,CGFloat progress);

@end

@implementation MLImageBrowserCollectionViewCell {
    MLImageBrowserCollectionViewCellScrollDirection _scrollDirection;
    CGPoint _lastContentOffset;
    BOOL _isImageLoaded;
    id _loaderIdentifier;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _scrollView = ({
            UIScrollView *scrollView = [UIScrollView new];
            scrollView.delegate = self;
            scrollView.bouncesZoom = YES;
            scrollView.alwaysBounceVertical = YES;
            scrollView;
        });
        _imageView = ({
            UIImageView *imageView = [UIImageView new];
            imageView.clipsToBounds = YES;
            imageView.backgroundColor = [UIColor clearColor];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView;
        });
        _imageContainerView = ({
            UIView *v = [UIView new];
            v.backgroundColor = [UIColor clearColor];
            v;
        });
        _loadingLayer = [_MLImageBrowserLoadingShapeLayer layer];
        _errorTipsLabel = ({
            UILabel *tipsLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 120, 30)];
            tipsLabel.layer.cornerRadius = 3.0f;
            tipsLabel.font = [UIFont systemFontOfSize:13.0f];
            tipsLabel.textColor = [UIColor whiteColor];
            tipsLabel.backgroundColor = [UIColor blackColor];
            tipsLabel.textAlignment = NSTextAlignmentCenter;
            tipsLabel.text = @"加载大图失败";
            tipsLabel.clipsToBounds = YES;
            tipsLabel.alpha = .8f;
            tipsLabel.hidden = YES;
            tipsLabel;
        });
        
        [self.contentView addSubview:_scrollView];
        [_scrollView addSubview:_imageContainerView];
        [_imageContainerView addSubview:_imageView];
        [self.contentView.layer addSublayer:_loadingLayer];
        [self.contentView addSubview:_errorTipsLabel];
        
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [self.scrollView addGestureRecognizer:doubleTap];
        
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
        singleTap.delaysTouchesBegan = YES;
        singleTap.numberOfTapsRequired = 1;
        [singleTap requireGestureRecognizerToFail:doubleTap];
        [self addGestureRecognizer:singleTap];
    }
    return self;
}

#pragma mark - layout
- (void)layoutSubviews {
    [super layoutSubviews];
    
    _scrollView.frame = self.contentView.bounds;
    _errorTipsLabel.center = CGPointMake(self.frame.size.width/2.0f, self.frame.size.height/2.0f);
    _loadingLayer.frame = CGRectMake((self.frame.size.width-_loadingLayer.frame.size.width)/2.0f, (self.frame.size.height-_loadingLayer.frame.size.height)/2.0f, _loadingLayer.frame.size.width, _loadingLayer.frame.size.height);
    
    [self updateImageViewFrame];
}

- (void)updateImageViewFrame {
    if (_disableUpdateImageViewFrame) {
        return;
    }
    
    //执行下面的frame计算之前需要重置一下缩放
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.zoomScale = _scrollView.minimumZoomScale;
    
    CGRect frame = _scrollView.frame;
    if (_imageView.image&&_imageView.image.size.width>0&&_imageView.image.size.height>0) {
        CGRect imageFrame = CGRectMake(0, 0, _imageView.image.size.width, _imageView.image.size.height);
        
        CGFloat ratio = frame.size.width/imageFrame.size.width; //找到区域和图像宽度的比，让图像保证满宽度优先
        imageFrame.size.height = imageFrame.size.height*ratio;
        imageFrame.size.width = frame.size.width;
        
        //设置scrollView的空间大小和图像位置
        _scrollView.contentSize = imageFrame.size;
        CGPoint center = _kCenterOfScrollView(_scrollView);
        _imageContainerView.frame = CGRectMake(center.x-imageFrame.size.width/2.0f, center.y-imageFrame.size.height/2.0f, imageFrame.size.width, imageFrame.size.height);
        
        //根据图片大小找到其合适的maximumZoomScale
        //例如最小的maximumZoomScale设置为2.5f,但是实际上这个值可能会引起图片达到之后还有屏幕空隙，所以再大点体验才好
        CGFloat maxZoomScale = frame.size.height/imageFrame.size.height;
        maxZoomScale = frame.size.width/imageFrame.size.width>maxZoomScale?frame.size.width/imageFrame.size.width:maxZoomScale;
        maxZoomScale = fmax(kMinMaximumZoomScale, maxZoomScale);
        
        //设置maximumZoomScale
        _scrollView.maximumZoomScale = _isImageLoaded?maxZoomScale:_scrollView.minimumZoomScale;
    }else{
        //和上面一样也要设置下空间和图像位置
        _scrollView.contentSize = frame.size;
        frame.origin = CGPointZero;
        _imageContainerView.frame = frame;
        
        //和上面一样，也要重新设置下maximumZoomScale
        _scrollView.maximumZoomScale = _scrollView.minimumZoomScale;
    }
    _imageView.frame = _imageContainerView.bounds;
}

#pragma mark - setter
- (void)setItem:(MLImageBrowserItem *)item {
    _item = item;
    
    //cancel current load
    if (_loaderIdentifier) {
        [_imageLoader cancelImageLoadForIdentifier:_loaderIdentifier];
        _loaderIdentifier = nil;
    }
    
    _errorTipsLabel.hidden = YES;
    
    if (item.largeImage) {
        _imageView.image = item.largeImage;
        _isImageLoaded = YES;
        [self updateImageViewFrame];
    }else if (item.largeImageURL) {
        _loadingLayer.state = _MLImageBrowserLoadingShapeStateLayerRotate;
        
        //placeholder
        _imageView.image = [item thumbImage];
        
        //load
        __weak __typeof__(self) weak_self = self;
        _loaderIdentifier = [_imageLoader loadImageWithURL:item.largeImageURL progress:^(CGFloat progress) {
            __typeof__(self) self = weak_self;
            if (!self) return;
            
            _ml_image_browser_dispatch_main_sync_safe(^{
                self.loadingLayer.progress = progress;
            });
        } completed:^(UIImage * _Nonnull image, NSError * _Nonnull error) {
            __typeof__(self) self = weak_self;
            if (!self) return;
            
            _ml_image_browser_dispatch_main_sync_safe(^{
                self.loadingLayer.state = _MLImageBrowserLoadingShapeStateLayerHidden;
                if (image&&!error) {
                    self.imageView.image = image;
                    [self.imageView setNeedsLayout];
                
                    _isImageLoaded = YES;
                    [self updateImageViewFrame];
                }else{
                    self.errorTipsLabel.hidden = NO;
                }
            });
        }];
        
        [self updateImageViewFrame];
    }else{
        _imageView.image = [item thumbImage];
        _isImageLoaded = YES;
        [self updateImageViewFrame];
    }
    
    //TODO:对于长图其实有必要加一个记录contentOffset的需求，但是加了之后触发其的时机就需要考虑下，否则影响动画效果
    _scrollView.contentOffset = CGPointZero;
}

- (void)setDisableUpdateImageViewFrame:(BOOL)disableUpdateImageViewFrame {
    _disableUpdateImageViewFrame = disableUpdateImageViewFrame;
    
    if (!disableUpdateImageViewFrame) {
        //立即执行一次
        [self updateImageViewFrame];
    }
}

#pragma mark - UIScrollViewDelegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageContainerView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    _imageContainerView.center = _kCenterOfScrollView(scrollView);
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    [UIView animateWithDuration:kAnimateDuration animations:^{
        view.center = _kCenterOfScrollView(scrollView);
        [self updatePullingProgress];
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat contentOffsetY = _scrollView.contentOffset.y;
    if (_lastContentOffset.y>contentOffsetY) {
        _scrollDirection = MLImageBrowserCollectionViewCellScrollDirectionBottom;
    }else if (_lastContentOffset.y<contentOffsetY) {
        _scrollDirection = MLImageBrowserCollectionViewCellScrollDirectionTop;
    }else{
        _scrollDirection = MLImageBrowserCollectionViewCellScrollDirectionNone;
    }
    _lastContentOffset = _scrollView.contentOffset;
    
    [self updatePullingProgress];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    //非常规大小时候不执行以下
    if (_scrollView.zoomScale!=_scrollView.minimumZoomScale) {
        return;
    }
    
    //检测是否处于顶部过度拖曳状态,且方向为上
    CGFloat offsetY = (_scrollView.contentOffset.y * -1) - _scrollView.contentInset.top;
    if (offsetY>kMLImageBrowserCollectionViewCellPanOverstepHeight
        &&_scrollDirection==MLImageBrowserCollectionViewCellScrollDirectionBottom) {
        if (self.didPanOverstepBlock) {
            self.didPanOverstepBlock(_item,_scrollDirection);
        }
        return;
    }
    
    //检测是否处于底部过度拖曳状态，且方向为下
    CGFloat bottomContentOffsetY = _scrollView.contentSize.height+_scrollView.contentInset.bottom-_scrollView.frame.size.height;
    bottomContentOffsetY = fmax(bottomContentOffsetY, -_scrollView.contentInset.top);
    offsetY = _scrollView.contentOffset.y-bottomContentOffsetY;
    if (offsetY>kMLImageBrowserCollectionViewCellPanOverstepHeight
        &&_scrollDirection==MLImageBrowserCollectionViewCellScrollDirectionTop) {
        if (self.didPanOverstepBlock) {
            self.didPanOverstepBlock(_item,_scrollDirection);
        }
        return;
    }
}

#pragma mark - tap
- (void)handleDoubleTap:(UITapGestureRecognizer *)tap {
    if (_scrollView.minimumZoomScale==_scrollView.maximumZoomScale) {
        return;
    }
    CGPoint touchPoint = [tap locationInView:_imageView];
    if (_scrollView.zoomScale == _scrollView.minimumZoomScale) { //除去最小的时候双击最大，其他时候都还原成最小
        CGFloat xsize = self.frame.size.width / _scrollView.maximumZoomScale;
        CGFloat ysize = self.frame.size.height / _scrollView.maximumZoomScale;
        [_scrollView zoomToRect:CGRectMake(touchPoint.x - xsize/2.0f, touchPoint.y - ysize/2.0f, xsize, ysize) animated:YES];
    } else {
        [_scrollView setZoomScale:_scrollView.minimumZoomScale animated:YES]; //还原
    }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)tap {
    if (self.didClickBlock) {
        self.didClickBlock(_item);
    }
}

#pragma mark - other or helper
- (void)prepareForReuse {
    [super prepareForReuse];
    
    _lastContentOffset = _scrollView.contentOffset = CGPointZero;
    _scrollDirection = MLImageBrowserCollectionViewCellScrollDirectionNone;
    _isImageLoaded = NO;
    
    self.disableUpdateImageViewFrame = NO;
    
    _loadingLayer.state = _MLImageBrowserLoadingShapeStateLayerHidden;
    _errorTipsLabel.hidden = YES;
}

- (void)showProgressLayer:(BOOL)show {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _loadingLayer.opacity = show?1.0f:0.0f;
    [CATransaction commit];
}

- (void)updatePullingProgress {
    //检测是否处于顶部拖曳状态
    CGFloat offsetY = (_scrollView.contentOffset.y * -1) - _scrollView.contentInset.top;
    CGFloat progress = 0.0f;
    if (offsetY<=0) {
        //检测是否处于底部拖曳状态
        CGFloat bottomContentOffsetY = _scrollView.contentSize.height+_scrollView.contentInset.bottom-_scrollView.frame.size.height;
        bottomContentOffsetY = fmax(bottomContentOffsetY, -_scrollView.contentInset.top);
        offsetY = _scrollView.contentOffset.y-bottomContentOffsetY;
    }
    if (offsetY>0) {
        progress = fmin(1.0f, offsetY/(self.frame.size.height/3.0f));
    }
    if (self.pullingBlock) {
        self.pullingBlock(_item,progress);
    }
}

@end

@interface MLImageBrowser()<UICollectionViewDelegate,UICollectionViewDataSource>

@property (nonatomic, strong) NSArray *items;

@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic, strong) UICollectionView *collectionView;

@property (nonatomic, strong) UIView *bottomContainerView;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UIButton *saveButton;

@property (nonatomic, strong) UIView *hudView;
@property (nonatomic, strong) UIActivityIndicatorView *hudIndicatorView;

@end

@implementation MLImageBrowser {
    BOOL _ignorePull;
    BOOL _isPresented;
    UIWindow *_actionWindow;
    NSInteger _lastPage;
    id<MLImageBrowserLoaderProtocol> _imageLoader;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _dimmingView = ({
            UIView *v = [UIView new];
            v.backgroundColor = [UIColor blackColor];
            v;
        });
        _collectionView = ({
            UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
            layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
            layout.minimumLineSpacing = kPadding;
            layout.minimumInteritemSpacing = 0.0f;
            layout.sectionInset = UIEdgeInsetsMake(0, kPadding/2.0f, 0, kPadding/2.0f);
            
            UICollectionView *collectionView = [[UICollectionView alloc]initWithFrame:self.bounds collectionViewLayout:layout];
            collectionView.backgroundColor = [UIColor clearColor];
            collectionView.delegate = self;
            collectionView.dataSource = self;
            collectionView.scrollsToTop = NO;
            collectionView.showsHorizontalScrollIndicator = NO;
            collectionView.showsVerticalScrollIndicator = NO;
            collectionView.directionalLockEnabled = YES;
            collectionView.pagingEnabled = YES;
            collectionView.delaysContentTouches = NO;
            collectionView.canCancelContentTouches = YES;
            
            [collectionView registerClass:[MLImageBrowserCollectionViewCell class] forCellWithReuseIdentifier:NSStringFromClass([MLImageBrowserCollectionViewCell class])];
            
            collectionView;
        });
        _bottomContainerView = [UIView new];
        _pageLabel = ({
            UILabel *label = [UILabel new];
            label.textColor = [UIColor colorWithWhite:1.000 alpha:.80f];
            label.font = [UIFont systemFontOfSize:15.0f];
            label.textAlignment = NSTextAlignmentCenter;
            label;
        });
        _saveButton = ({
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.backgroundColor = [UIColor colorWithWhite:0.115 alpha:0.798];
            button.titleLabel.font = [UIFont systemFontOfSize:13.0f];
            button.layer.cornerRadius = 2.0f;
            button.layer.borderColor = [UIColor colorWithWhite:0.756 alpha:0.599].CGColor;
            button.layer.borderWidth = 1.0f/[UIScreen mainScreen].scale;
            [button setTitleColor:[UIColor colorWithWhite:1.000 alpha:0.805] forState:UIControlStateNormal];
            [button addTarget:self action:@selector(downloadImageToSystemBrowser:) forControlEvents:UIControlEventTouchUpInside];
            [button setTitle:@"保存" forState:UIControlStateNormal];
            button;
        });
        _hudView = ({
            UIView *v = [UIView new];
            v.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.604];
            v.hidden = YES;
            v;
        });
        _hudIndicatorView = ({
            UIActivityIndicatorView *v = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            [v startAnimating];
            v;
        });
        
        [self addSubview:_dimmingView];
        [self addSubview:_collectionView];
        [_bottomContainerView addSubview:_pageLabel];
        [_bottomContainerView addSubview:_saveButton];
        [self addSubview:_bottomContainerView];
        
        [_hudView addSubview:_hudIndicatorView];
        [self addSubview:_hudView];
        
        self.dimmingViewAlpha = 1.0f;
        self.displaySaveButton = YES;
    }
    return self;
}

#pragma mark - collectionView
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MLImageBrowserCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([MLImageBrowserCollectionViewCell class]) forIndexPath:indexPath];
    cell.imageLoader = _imageLoader;
    cell.item = _items[indexPath.row];
    __weak __typeof__(self) weak_self = self;
    if (!cell.didClickBlock) {
        [cell setDidClickBlock:^(MLImageBrowserItem *it) {
            __typeof__(self) self = weak_self;
            [self dismissWithAnimted:YES completion:nil];
        }];
    }
    if (!cell.didPanOverstepBlock) {
        [cell setDidPanOverstepBlock:^(MLImageBrowserItem *it,MLImageBrowserCollectionViewCellScrollDirection direction) {
            __typeof__(self) self = weak_self;
            self->_ignorePull = YES;
            [self dismissToDirection:direction];
        }];
    }
    if (!cell.pullingBlock) {
        [cell setPullingBlock:^(MLImageBrowserItem *it, CGFloat progress) {
            __typeof__(self) self = weak_self;
            if (self->_ignorePull) {
                return;
            }
            self.dimmingView.alpha = self.dimmingViewAlpha-progress*self.dimmingViewAlpha;
        }];
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(self.frame.size.width, self.frame.size.height);
}

#pragma mark - layout
- (void)layoutSubviews {
    [super layoutSubviews];
    
    _dimmingView.frame = self.bounds;
    
    CGRect newCollectionViewFrame = CGRectMake(-kPadding/2.0f, 0, self.frame.size.width+kPadding, self.frame.size.height);
    if (!CGRectEqualToRect(newCollectionViewFrame, _collectionView.frame)) {
        NSInteger oldIndex = [self currentPage];
        _collectionView.frame = newCollectionViewFrame;
        [_collectionView.collectionViewLayout invalidateLayout];
        
        //这里可能contentOffset就在一个异常位置不动了，我们需要主动矫正下
        [_collectionView setContentOffset:CGPointMake(oldIndex*_collectionView.frame.size.width, 0)];
    }
    
#define kBottomContainerViewHeight 28.0f
    _bottomContainerView.frame = CGRectMake(0, self.frame.size.height-15.0f-kBottomContainerViewHeight, self.frame.size.width, kBottomContainerViewHeight);
    
#define kSaveButtonWidth 50.0f
    _saveButton.frame = CGRectMake(_bottomContainerView.frame.size.width-15.0f-kSaveButtonWidth, 0, kSaveButtonWidth, _bottomContainerView.frame.size.height);
    
#define kPageLabelHMargin 10.0f
    _pageLabel.frame = CGRectMake(kPageLabelHMargin, 0, self.frame.size.width-kPageLabelHMargin*2, _bottomContainerView.frame.size.height);
    
    _hudView.frame = self.bounds;
    _hudIndicatorView.center = CGPointMake(_hudView.frame.size.width/2.0f, _hudView.frame.size.height/2.0f);
}

#pragma mark - call
- (void)presentWithLoader:(id<MLImageBrowserLoaderProtocol>)loader items:(NSArray*)items atIndex:(NSInteger)index onWindowLevel:(UIWindowLevel)windowLevel animated:(BOOL)animated completion:(nullable void (^)(void))completion {
    NSAssert(loader, @"downloader cant be nil");
    NSAssert(!_isPresented, @"只可present一次");
    NSAssert(windowLevel>=UIWindowLevelNormal, @"windowLevel must >= UIWindowLevelNormal ");
    NSAssert(index>=0&&index<items.count, @"must 0<=index<items.count");
    if (!loader||index<0||index>=items.count) {
        return;
    }
    _imageLoader = loader;
    
    windowLevel = MAX(UIWindowLevelNormal, windowLevel);
    
    //设置items
    _items = items;
    
    //记录原缩略图的原hidden状态
    for (MLImageBrowserItem *it in _items) {
        it.originalHidden = it.thumbView.hidden;
    }
    
    _isPresented = NO;
    self.hidden = YES; //在完全准备好之前不需要显示，否则可能会引起闪烁
    
    //建立windowLevel的window，添加自身，并且持有它
    _MLImageBrowserViewController *vc = [_MLImageBrowserViewController new];
    vc.view = self;
    
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.hidden = NO;
    window.windowLevel = windowLevel;
    window.rootViewController = vc;
    _actionWindow = window;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    //开始做动画准备处理
    NSTimeInterval duration = animated?kAnimateDuration:0.0f;
    MLImageBrowserItem *item = _items[index];
    
    //由于collectionView的特性必须reload完毕之后再做操作
    [_collectionView performBatchUpdates:^{
        [_collectionView reloadData];
        [_collectionView setContentOffset:CGPointMake(index*_collectionView.frame.size.width, 0)];
    } completion:^(BOOL finished) {
        self.userInteractionEnabled = NO;
        self.hidden = NO;
        if (item.thumbView.window) {
            //做图像放大动画以及背景色隐现动画
            MLImageBrowserCollectionViewCell *cell = (MLImageBrowserCollectionViewCell*)[_collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
            
            CGRect thumbViewFrame = _kConvertBoundsFromViewToViewOrWindow(item.thumbView, cell.imageContainerView);
            cell.imageView.frame = thumbViewFrame;
            
            _dimmingView.alpha = 0.0f;
            item.thumbView.hidden = YES;
            [cell showProgressLayer:NO];
            [self displayBottomContainer:NO];
            cell.disableUpdateImageViewFrame = YES;
            [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
                _dimmingView.alpha = _dimmingViewAlpha;
                cell.imageView.frame = cell.imageContainerView.bounds;
            } completion:^(BOOL finished) {
                item.thumbView.hidden = item.originalHidden;
                [cell showProgressLayer:YES];
                [self displayBottomContainer:YES];
                cell.disableUpdateImageViewFrame = NO;
                
                self.userInteractionEnabled = YES;
                _isPresented = YES;
                [self updatePageDisplay];
                if (completion) {
                    completion();
                }
            }];
        }else{
            //做隐现动画
            self.alpha = 0.0f;
            [self.layer setValue:@(kAnimateScaleForSelf) forKeyPath:@"transform.scale"];
            [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.alpha = 1.0f;
                [self.layer setValue:@(1.0f) forKeyPath:@"transform.scale"];
            } completion:^(BOOL finished) {
                self.userInteractionEnabled = YES;
                _isPresented = YES;
                [self updatePageDisplay];
                if (completion) {
                    completion();
                }
            }];
        }
    }];
}

- (void)dismissWithAnimted:(BOOL)animated completion:(void (^)(void))completion {
    _isPresented = NO;
    
    NSInteger currentPage = [self currentPage];
    
    NSTimeInterval duration = animated?kAnimateDuration:0.0f;
    MLImageBrowserItem *item = _items[currentPage];
    
    self.userInteractionEnabled = NO;
    if (item.thumbView.window) {
        MLImageBrowserCollectionViewCell *cell = (MLImageBrowserCollectionViewCell*)[_collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:currentPage inSection:0]];
        
        CGRect thumbViewFrame = [item.thumbView convertRect:item.thumbView.bounds toView:cell.imageContainerView];
        
        item.thumbView.hidden = YES;
        [cell showProgressLayer:NO];
        [self displayBottomContainer:NO];
        cell.disableUpdateImageViewFrame = YES;
        [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
            _dimmingView.alpha = 0.0f;
            cell.imageView.frame = thumbViewFrame;
        } completion:^(BOOL finished) {
            item.thumbView.hidden = item.originalHidden;
            //这样不会引起闪烁，否则有可能
            dispatch_async(dispatch_get_main_queue(), ^{
                [self afterDismiss];
                
                if (completion) {
                    completion();
                }
            });
        }];
    }else{
        //直接做隐出动画
        [UIView animateWithDuration:kAnimateDuration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
            self.alpha = 0.0f;
            [self.layer setValue:@(kAnimateScaleForSelf) forKeyPath:@"transform.scale"];
        } completion:^(BOOL finished) {
            [self afterDismiss];
            
            if (completion) {
                completion();
            }
        }];
    }
}

- (void)dismissToDirection:(MLImageBrowserCollectionViewCellScrollDirection)direction {
    _isPresented = NO;
    
    NSInteger currentPage = [self currentPage];
    MLImageBrowserItem *item = _items[currentPage];
    
    MLImageBrowserCollectionViewCell *cell = (MLImageBrowserCollectionViewCell*)[_collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:currentPage inSection:0]];
    
    self.userInteractionEnabled = NO;
    cell.scrollView.bounces = NO;
    [cell showProgressLayer:NO];
    [self displayBottomContainer:NO];
    [UIView animateWithDuration:kAnimateDuration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
        CGRect frame = cell.scrollView.frame;
        if (direction==MLImageBrowserCollectionViewCellScrollDirectionBottom) {
            frame.origin.y = cell.scrollView.superview.frame.origin.y+cell.scrollView.superview.frame.size.height;
        }else{
            frame.origin.y = cell.scrollView.superview.frame.origin.y-frame.size.height;
        }
        cell.scrollView.frame = frame;
        _dimmingView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [self afterDismiss];
    }];
    
    //缩略图加个隐现效果
    item.thumbView.hidden = item.originalHidden;
    item.thumbView.alpha = 0.0f;
    [UIView animateWithDuration:kAnimateDuration animations:^{
        item.thumbView.alpha = 1.0f;
    }];
}

#pragma mark - helper
- (void)afterDismiss {
    [self removeFromSuperview];
    _actionWindow.windowLevel = UIWindowLevelNormal-1;
    [_actionWindow removeFromSuperview];
    [_actionWindow resignKeyWindow];
    _actionWindow.hidden = YES;
    _actionWindow.rootViewController = nil;
    _actionWindow = nil;
}

- (NSInteger)currentPage {
    NSInteger page = _collectionView.contentOffset.x / _collectionView.frame.size.width + 0.5f;
    page = MIN(page, _items.count-1);
    page = MAX(0, page);
    return page;
}

- (void)updatePageDisplay {
    NSInteger currentPage = [self currentPage];
    _pageLabel.hidden = _items.count<=1;
    _pageLabel.text = [NSString stringWithFormat:@"%ld/%ld",(long)(currentPage+1),(long)_items.count];
    
    if (_isPresented) {
        //这里有这个判断是因为此方法在collectionView第一次reload之前就会执行，若此时就hide缩略图view的话在大图从其位置显示之前是空白的有闪烁的感觉，毕竟reload可能需要一点点时间。
        //所以我们就直接在present没结束之前不进行此处理
        for (NSInteger i=0; i<_items.count; i++) {
            MLImageBrowserItem *it = _items[i];
            it.thumbView.hidden = (i==currentPage)?YES:it.originalHidden;
        }
    }
}

- (void)displayBottomContainer:(BOOL)display {
    _bottomContainerView.hidden = !display;
    
    _kAddFadeTransitionForLayer(_bottomContainerView.layer);
}

- (void)showHud:(BOOL)show {
    _hudView.hidden = !show;
    
    _kAddFadeTransitionForLayer(_hudView.layer);
}

#pragma mark - scroll
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSInteger currentPage = [self currentPage];
    if (_lastPage!=currentPage) {
        _lastPage = currentPage;
        [self updatePageDisplay];
    }
}

#pragma mark - download to system browser
- (void)downloadImageToSystemBrowser:(UIButton*)sender {
    [self showHud:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger currentPage = [self currentPage];
        MLImageBrowserItem *item = _items[currentPage];
        
        if (item.largeImage) {
            UIImageWriteToSavedPhotosAlbum(item.largeImage, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
        }else if (item.largeImageURL) {
            //取得image
            __weak __typeof__(self) weak_self = self;
            [_imageLoader loadImageWithURL:item.largeImageURL progress:nil completed:^(UIImage * _Nonnull image, NSError * _Nonnull error) {
                __typeof__(self) self = weak_self;
                if (!self) return;
                
                _ml_image_browser_dispatch_main_sync_safe(^{
                    if (image&&!error) {
                        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
                    }else{
                        //下载失败
                        [[[UIAlertView alloc]initWithTitle:@"" message:@"图片下载失败，无法保存" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles: nil]show];
                        [self showHud:NO];
                    }
                });
            }];
        }else{
            UIImage *thumbImage = [item thumbImage];
            if (thumbImage) {
                UIImageWriteToSavedPhotosAlbum(thumbImage, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
            }else{
                [self showHud:YES];
            }
        }
    });
}

// 指定回调方法
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self showHud:NO];
    
    [[[UIAlertView alloc]initWithTitle:@"" message:error?@"保存图片失败，请检查是否开启访问权限":@"已保存至相册" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles: nil]show];
}

#pragma mark - setter
- (void)setDimmingViewAlpha:(CGFloat)dimmingViewAlpha {
    NSAssert(!_isPresented, @"setDimmingViewAlpha: only can be excuted before presenting");
    _dimmingViewAlpha = dimmingViewAlpha;
    
    _dimmingView.alpha = dimmingViewAlpha;
}

- (void)setDisplaySaveButton:(BOOL)displaySaveButton {
    _displaySaveButton = displaySaveButton;
    
    _saveButton.hidden = !displaySaveButton;
}

@end
