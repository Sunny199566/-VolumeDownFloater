#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, AVPictureInPictureControllerDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) AVPictureInPictureController *pipController;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = rootVC;
    self.window.hidden = NO;

    // 设置后台音频会话，保证画中画不被杀
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];

    // 生成一个透明的 1 像素视频用来欺骗系统
    NSString *videoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"blank.mp4"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        // 此处为空白视频的基础数据（极简生成或直接使用本地的文件）
        NSData *blankVideoData = [[NSData alloc] initWithBase64EncodedString:@"AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAs1tZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NCByMzEwOCAzMWUxOWY5IC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyMyAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbAABAAAAEm1vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAAAAAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAHYdHJhawAAAFx0a2hkAAAAAwAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAABAAAAAQAAAAAAJGVkdHMAAAAcZWxzdAAAAAAAAAABAAAB2AAAAAAAAQAAAAABUG1kaWEAAAAgbWRoZAAAAAAAAAAAAAAAAAAAu4AAAfQAFccQAAAAADRoZGxyAAAAAAAAAAB2aWRlAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADG1pbmYAAAAkdm1oZAAAAAEAAAAAAAAAAAAAACBkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAABBzdGJsAAAAEHN0c2QAAAAAAAAAAQAAABBzdHRzAAAAAAAAAAEAAAABAAAAAQAAABxzdHNjAAAAAAAAAAEAAAABAAAAAQAAAAEAAAAUc3RzegAAAAAAAAAFAAAAAQAAABRzdGNvAAAAAAAAAAEAAAAwAAAAYnVkdGEAAABabWV0YQAAAAAAAAAhaGRscgAAAAAAAAAAbWRpcmFwcGwAAAAAAAAAAAAAAAAtaWxzdAAAACWpdG9vAAAAHWRhdGEAAAABAAAAAExhdmY2MC4xNi4xMDA=" options:NSDataBase64DecodingIgnoreUnknownCharacters];
        [blankVideoData writeToFile:videoPath atomically:YES];
    }

    // 创建播放器
    self.player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:videoPath]];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = CGRectMake(0, 0, 1, 1);
    [rootVC.view.layer addSublayer:self.playerLayer];

    // 开启画中画
    if ([AVPictureInPictureController isPictureInPictureSupported]) {
        self.pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.playerLayer];
        self.pipController.delegate = self;
        // 允许画中画自动开启
        if (@available(iOS 14.2, *)) {
            self.pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
        }
        [self.player play];
        [self.pipController startPictureInPicture];
    }

    // 监听画中画的“播放/暂停”按钮点击事件（完美解决点击延迟）
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    [commandCenter.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        // 当你在微信里点击画中画上的暂停按钮时，触发这里！
        [self simulateVolumeDown];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self simulateVolumeDown];
        return MPRemoteCommandHandlerStatusSuccess;
    }];

    return YES;
}

- (void)simulateVolumeDown {
    // 调节系统音量
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    UISlider *volumeSlider = nil;
    for (UIView *view in [volumeView subviews]) {
        if ([view isKindOfClass:[UISlider class]]) {
            volumeSlider = (UISlider *)view;
            break;
        }
    }
    if (volumeSlider) {
        float newVolume = volumeSlider.value - (1.0 / 16.0);
        if (newVolume < 0) newVolume = 0;
        [volumeSlider setValue:newVolume animated:YES];
        [volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}