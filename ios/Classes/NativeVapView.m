#import "NativeVapView.h"
#import "UIView+VAP.h"
#import "QGVAPConfigModel.h"
#import "FetchResourceModel.h"
#import <Flutter/Flutter.h>

// Flutter creates the platform view with CGRectZero and lays it out later, so the
// playing view is aspect-fitted on every layout pass instead of once at start.
@interface VapContainerView : UIView
@property (nonatomic, strong, nullable) UIView *vapView;
@property (nonatomic, assign) CGSize videoSize;
@end

@implementation VapContainerView

- (void)layoutSubviews {
    [super layoutSubviews];
    UIView *vapView = self.vapView;
    if (!vapView) return;
    CGSize bounds = self.bounds.size;
    CGSize video = self.videoSize;
    if (bounds.width <= 0 || bounds.height <= 0 || video.width <= 0 || video.height <= 0) {
        vapView.frame = CGRectZero;
        return;
    }
    CGFloat scale = MIN(bounds.width / video.width, bounds.height / video.height);
    CGSize size = CGSizeMake(video.width * scale, video.height * scale);
    vapView.frame = CGRectMake((bounds.width - size.width) / 2, (bounds.height - size.height) / 2, size.width, size.height);
}

@end

@interface NativeVapView : NSObject <FlutterPlatformView, HWDMP4PlayDelegate>

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;

@end

@implementation NativeVapViewFactory {
    NSObject<FlutterPluginRegistrar> *_registrar;
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    self = [super init];
    if (self) {
        _registrar = registrar;
    }
    return self;
}

- (NSObject<FlutterMessageCodec> *)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame
                                    viewIdentifier:(int64_t)viewId
                                         arguments:(id _Nullable)args {
    return [[NativeVapView alloc] initWithFrame:frame
                                 viewIdentifier:viewId
                                      arguments:args
                                binaryMessenger:_registrar.messenger];
}

@end

@implementation NativeVapView {
    VapContainerView *_view;
    FlutterMethodChannel *_methodChannel;
    NSArray<FetchResourceModel *> *_fetchResources;
    UIView *_playingView;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    self = [super init];
    if (self) {
        _view = [[VapContainerView alloc] initWithFrame:frame];
        NSString *channelName = [NSString stringWithFormat:@"flutter_vap_controller_%lld", viewId];
        _methodChannel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
        __weak typeof(self) weakSelf = self;
        [_methodChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
            [weakSelf handleMethodCall:call result:result];
        }];
    }
    return self;
}

- (UIView *)view {
    return _view;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([@"playPath" isEqualToString:call.method]) {
        NSString *path = call.arguments[@"path"];
        if (!path) {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENT" message:@"Path is null" details:nil]);
            return;
        }
        [self playByPath:path withResult:result];
    } else if ([@"playAsset" isEqualToString:call.method]) {
        NSString *asset = call.arguments[@"asset"];
        if (!asset) {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENT" message:@"Asset is null" details:nil]);
            return;
        }
        NSString *flutterAssets = [[NSBundle mainBundle] pathForResource:@"flutter_assets" ofType:nil];
        [self playByPath:[flutterAssets stringByAppendingPathComponent:asset] withResult:result];
    } else if ([@"stop" isEqualToString:call.method]) {
        [self stopPlayback];
        result(nil);
    } else if ([@"setFetchResource" isEqualToString:call.method]) {
        _fetchResources = [FetchResourceModel fromRawJsonArray:(NSString *)call.arguments];
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

#pragma mark - Playback (main thread)

- (void)playByPath:(NSString *)path withResult:(FlutterResult)result {
    if (_playingView) {
        result([FlutterError errorWithCode:@"ALREADY_PLAYING" message:@"A video is already playing" details:nil]);
        return;
    }
    UIView *vapView = [[UIView alloc] initWithFrame:CGRectZero];
    _playingView = vapView;
    _view.videoSize = CGSizeZero;
    _view.vapView = vapView;
    [_view addSubview:vapView];
    [vapView playHWDMP4:path repeatCount:0 delegate:self];
    result(nil);
}

- (void)stopPlayback {
    UIView *vapView = _playingView;
    [self detachPlayingView:vapView];
    [vapView stopHWDMP4];
}

// Detaching first makes every later callback from this view a no-op.
- (void)detachPlayingView:(UIView *)vapView {
    if (!vapView || vapView != _playingView) return;
    [vapView removeFromSuperview];
    _view.vapView = nil;
    _playingView = nil;
}

- (void)finishPlayingView:(UIView *)vapView event:(NSString *)event arguments:(NSDictionary *)arguments {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (vapView != self->_playingView) return;
        [self detachPlayingView:vapView];
        [self->_methodChannel invokeMethod:event arguments:arguments];
    });
}

#pragma mark - HWDMP4PlayDelegate (background thread)

- (BOOL)shouldStartPlayMP4:(VAPView *)container config:(QGVAPConfigModel *)config {
    CGSize videoSize = config.info.size;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (container != self->_playingView) return;
        self->_view.videoSize = videoSize;
        [self->_view setNeedsLayout];
        [self->_view layoutIfNeeded];
    });
    return YES;
}

- (void)viewDidStartPlayMP4:(VAPView *)container {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (container != self->_playingView) return;
        [self->_methodChannel invokeMethod:@"onStart" arguments:@{@"status": @"start"}];
    });
}

- (void)viewDidFinishPlayMP4:(NSInteger)totalFrameCount view:(VAPView *)container {
    [self finishPlayingView:container event:@"onComplete" arguments:@{@"status": @"complete"}];
}

// Reached without DidFinish/DidFail when QGVAPlayer gives up (incompatible version, view left the window, ...)
- (void)viewDidStopPlayMP4:(NSInteger)lastFrameIndex view:(VAPView *)container {
    [self finishPlayingView:container event:@"onFailed" arguments:@{@"status": @"failure", @"errorMsg": @"stopped before finishing"}];
}

- (void)viewDidFailPlayMP4:(NSError *)error {
    NSString *message = error.localizedDescription ?: @"Unknown error";
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *vapView = self->_playingView;
        if (!vapView) return;
        [self detachPlayingView:vapView];
        [self->_methodChannel invokeMethod:@"onFailed" arguments:@{@"status": @"failure", @"errorMsg": message}];
    });
}

- (NSString *)contentForVapTag:(NSString *)tag resource:(QGVAPSourceInfo *)info {
    for (FetchResourceModel *model in _fetchResources) {
        if ([model.tag isEqualToString:tag]) return model.resource;
    }
    return nil;
}

- (void)loadVapImageWithURL:(NSString *)urlStr context:(NSDictionary *)context completion:(VAPImageCompletionBlock)completionBlock {
    dispatch_async(dispatch_get_main_queue(), ^{
        completionBlock([UIImage imageWithContentsOfFile:urlStr], nil, urlStr);
    });
}

@end
