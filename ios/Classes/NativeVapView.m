#import "NativeVapView.h"
#import "UIView+VAP.h"
#import "QGVAPWrapView.h"
#import "FetchResourceModel.h"
#import <Flutter/Flutter.h>

@interface NativeVapView : NSObject <FlutterPlatformView, VAPWrapViewDelegate>

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;

@end

@interface VapContainerView : UIView
@property (nonatomic, copy, nullable) void (^onLayoutChanged)(void);
@end

@implementation VapContainerView

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.onLayoutChanged) self.onLayoutChanged();
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.onLayoutChanged) self.onLayoutChanged();
}

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
    NSString *_pendingPath;
    QGVAPWrapView *_wrapView;
    BOOL playStatus;
    FlutterMethodChannel *_methodChannel;
    NSArray<FetchResourceModel *> *_fetchResources;
    id _args;
}
- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    self = [super init];
    _args = args;
    if (self) {
        playStatus = NO;
        _view = [[VapContainerView alloc] initWithFrame:frame];
        __weak typeof(self) weakSelfForLayout = self;
        _view.onLayoutChanged = ^{
            [weakSelfForLayout startPendingPlaybackIfReady];
        };
        

        
        //        [_view addvi];

        NSString *scaleType = args[@"scaleType"];
//        if([scaleType isEqualToString:@"FIT_CENTER"]){
////            [_wrapView setContentMode:QGVAPWrapViewContentModeAspectFit];
//            _wrapView.contentMode = QGVAPWrapViewContentModeAspectFit;
//        }else if([scaleType isEqualToString:@"FIT_XY"]){
////            [_wrapView setContentMode:QGVAPWrapViewContentModeAspectFill];
//            _wrapView.contentMode = QGVAPWrapViewContentModeAspectFill;
//
//        }else{
////            [_wrapView setContentMode:QGVAPWrapViewContentModeScaleToFill];
//            _wrapView.contentMode = QGVAPWrapViewContentModeScaleToFill;
//        }
//        _wrapView.contentMode = QGVAPWrapViewContentModeAspectFit;
//        _wrapView.autoDestoryAfterFinish = YES;

//        _wrapView.center = _view.center;
//        _wrapView.hwd_renderByOpenGL = YES;
//        [_view addSubview:_wrapView];
        // Initialize MethodChannel with a static name
        NSString *methodChannelName = [NSString stringWithFormat: @"flutter_vap_controller_%lld" ,viewId];

        _methodChannel = [FlutterMethodChannel methodChannelWithName:methodChannelName binaryMessenger:messenger];
        __weak typeof(self) weakSelf = self;
        [_methodChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
            [weakSelf handleMethodCall:call result:result];
        }];
//        [_methodChannel invokeMethod:scaleType arguments:scaleType];

        
    }
    return self;
}
// - (instancetype)initWithFrame:(CGRect)frame
//                viewIdentifier:(int64_t)viewId
//                     arguments:(id _Nullable)args
//               binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
//     self = [super init];
//     if (self) {
//         playStatus = NO;
//         _view = [[VapContainerView alloc] initWithFrame:frame];
        __weak typeof(self) weakSelfForLayout = self;
        _view.onLayoutChanged = ^{
            [weakSelfForLayout startPendingPlaybackIfReady];
        };

//         // Initialize MethodChannel
//         NSString *methodChannelName = [NSString stringWithFormat:@"flutter_vap_controller_%lld", viewId];
//         _methodChannel = [FlutterMethodChannel methodChannelWithName:methodChannelName binaryMessenger:messenger];
//         [_methodChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
//             [self handleMethodCall:call result:result];
//         }];

//         // Initialize EventChannel
//         NSString *eventChannelName = [NSString stringWithFormat:@"flutter_vap_event_channel_%lld", viewId];
//         _eventChannel = [FlutterEventChannel eventChannelWithName:eventChannelName binaryMessenger:messenger];
//         __weak typeof(self) weakSelf = self;
//         [_eventChannel setStreamHandler:self];
//     }
//     return self;
// }

#pragma mark - FlutterPlatformView

- (UIView *)view {
    return _view;
}



#pragma mark - Method Call Handling

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"playPath" isEqualToString:call.method]) {
        NSString *path = call.arguments[@"path"];
        if (path) {
            [self playByPath:path withResult:result];
        } else {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                                       message:@"Path is null"
                                       details:nil]);
        }
    } else if ([@"playAsset" isEqualToString:call.method]) {
        NSString *asset = call.arguments[@"asset"];
        if (asset) {
//            NSString *assetPath = [[NSBundle mainBundle] pathForResource:asset ofType:nil];
            NSString *flutterAssetsPath = [[NSBundle mainBundle] pathForResource:@"flutter_assets" ofType:nil];
            
                NSString *assetPath = [flutterAssetsPath stringByAppendingPathComponent:asset];
            
                NSLog(@"Asset path: %@", assetPath);
            
            
            
            if (assetPath) {
                [self playByPath:assetPath withResult:result];
            } else {
                result([FlutterError errorWithCode:@"ASSET_NOT_FOUND"
                                           message:@"Asset not found"
                                           details:nil]);
            }
        } else {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                                       message:@"Asset is null"
                                       details:nil]);
        }
    } else if ([@"stop" isEqualToString:call.method]) {
        [self stopPlayback];
        result(nil);
    } else if ([@"setFetchResource" isEqualToString:call.method]){
        NSString *rawJson = (NSString *) call.arguments;
        _fetchResources = [FetchResourceModel fromRawJsonArray:rawJson];
        result(nil);
    }else {
        result(FlutterMethodNotImplemented);
    }
    
    
}

#pragma mark - Playback Control

- (void)playByPath:(NSString *)path withResult:(FlutterResult)result {
    if (playStatus) {
        result([FlutterError errorWithCode:@"ALREADY_PLAYING"
                                   message:@"A video is already playing"
                                   details:nil]);
        return;
    }

    playStatus = YES;
    _pendingPath = path;
    result(nil);
    [self startPendingPlaybackIfReady];
}

// Flutter creates the view with CGRectZero and QGVAPWrapView sizes itself from its bounds only once at start
- (void)startPendingPlaybackIfReady {
    if (!_pendingPath || !_view.window || CGRectIsEmpty(_view.bounds)) {
        return;
    }
    NSString *path = _pendingPath;
    _pendingPath = nil;

    _wrapView = [[QGVAPWrapView alloc] initWithFrame:_view.bounds];
    _wrapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _wrapView.contentMode = QGVAPWrapViewContentModeAspectFit;
    _wrapView.autoDestoryAfterFinish = YES;

    [_view addSubview:_wrapView];
    [_wrapView vapWrapView_playHWDMP4:path repeatCount:0 delegate:self];
}

- (void)stopPlayback {
    _pendingPath = nil;
    if (_wrapView) {
        [_wrapView removeFromSuperview];
        _wrapView = nil;
    }
    playStatus = NO;

}

#pragma mark - VAPWrapViewDelegate

- (void)vapWrap_viewDidStartPlayMP4:(VAPView *)container {
    playStatus = YES;

    // Notify Flutter that playback has started
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_methodChannel invokeMethod:@"onStart" arguments:@{@"status" : @"start"}];
    });

}

- (void)vapWrap_viewDidFailPlayMP4:(NSError *)error {
    playStatus = NO;
    dispatch_async(dispatch_get_main_queue(), ^{

    [self->_methodChannel invokeMethod:@"onFailed" arguments:@{
        @"status": @"failure",
        @"errorMsg": error.localizedDescription ?: @"Unknown error"
}];
    });

}

- (void)vapWrap_viewDidStopPlayMP4:(NSInteger)lastFrameIndex view:(VAPView *)container {
    playStatus = NO;
}

- (void)vapWrap_viewDidFinishPlayMP4:(NSInteger)totalFrameCount view:(VAPView *)container {
    playStatus = NO;
    dispatch_async(dispatch_get_main_queue(), ^{

    [self->_methodChannel invokeMethod:@"onComplete" arguments:@{@"status" : @"complete"}];
    });

}

- (NSString *)vapWrapview_contentForVapTag:(NSString *)tag resource:(QGVAPSourceInfo *)info{
    for(FetchResourceModel *model in _fetchResources){
        if([model.tag isEqualToString:tag]){
            NSLog(@"%@", [[@"vapWrapview_contentForVapTaging:" stringByAppendingString:tag] stringByAppendingString:model.resource]);
            return model.resource;
        }
    }
    return nil;
}

- (void)vapWrapView_loadVapImageWithURL:(NSString *)urlStr context:(NSDictionary *)context completion:(VAPImageCompletionBlock)completionBlock{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [UIImage imageWithContentsOfFile:urlStr];
        completionBlock(image,nil,urlStr);
    });
}

@end
