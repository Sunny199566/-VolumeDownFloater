#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <AVFoundation/AVFoundation.h>

// --- 底层定义 ---
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef CFTypeRef IOHIDEventSystemClientRef;

typedef IOHIDEventRef (*IOHIDEventCreateKeyboardEvent_t)(CFAllocatorRef, uint64_t, uint16_t, uint16_t, Boolean, uint32_t);
typedef IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreate_t)(CFAllocatorRef);
typedef void (*IOHIDEventSystemClientDispatchEvent_t)(IOHIDEventSystemClientRef, IOHIDEventRef);
typedef void (*IOHIDEventSetSenderID_t)(IOHIDEventRef, uint64_t);

void simulateVolumeDown(void) {
    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!handle) return;

    IOHIDEventCreateKeyboardEvent_t createEvent = (IOHIDEventCreateKeyboardEvent_t)dlsym(handle, "IOHIDEventCreateKeyboardEvent");
    IOHIDEventSystemClientCreate_t createClient = (IOHIDEventSystemClientCreate_t)dlsym(handle, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEvent_t dispatchEvent = (IOHIDEventSystemClientDispatchEvent_t)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
    IOHIDEventSetSenderID_t setSender = (IOHIDEventSetSenderID_t)dlsym(handle, "IOHIDEventSetSenderID");

    if (createEvent && createClient && dispatchEvent) {
        IOHIDEventSystemClientRef client = createClient(kCFAllocatorDefault);
        if (client) {
            uint64_t timestamp = mach_absolute_time();
            
            // 按下
            IOHIDEventRef downEvent = createEvent(kCFAllocatorDefault, timestamp, 0x0C, 0xEA, true, 0);
            if (downEvent) {
                if (setSender) setSender(downEvent, 0xDEFACEDBEEFFECE5); // 伪装发送者
                dispatchEvent(client, downEvent);
                CFRelease(downEvent);
            }
            
            // 抬起
            IOHIDEventRef upEvent = createEvent(kCFAllocatorDefault, timestamp, 0x0C, 0xEA, false, 0);
            if (upEvent) {
                if (setSender) setSender(upEvent, 0xDEFACEDBEEFFECE5);
                dispatchEvent(client, upEvent);
                CFRelease(upEvent);
            }
            CFRelease(client);
        }
    }
    dlclose(handle);
}

@interface FloatWindow : UIWindow
@end

@implementation FloatWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return view == self ? nil : view;
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) FloatWindow *window;
@property (strong, nonatomic) UIButton *floatBtn;
@property (strong, nonatomic) AVAudioPlayer *silentPlayer;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 1. 开启静音后台保活，防止系统杀进程导致悬浮窗消失
    NSError *sessionError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&sessionError];
    [[AVAudioSession sharedInstance] setActive:YES error:&sessionError];
    
    // 创建一个只有 0.1 秒的静音文件循环播放
    NSString *soundFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"silence.caf"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:soundFilePath]) {
        NSData *emptyData = [[NSData alloc] initWithBase64EncodedString:@"UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=" options:NSDataBase64DecodingIgnoreUnknownCharacters];
        [emptyData writeToFile:soundFilePath atomically:YES];
    }
    self.silentPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundFilePath] error:nil];
    self.silentPlayer.numberOfLoops = -1;
    [self.silentPlayer play];

    // 2. 创建悬浮窗
    UIWindowScene *windowScene = nil;
    for (UIScene *scene in application.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            windowScene = (UIWindowScene *)scene;
            break;
        }
    }
    
    if (@available(iOS 13.0, *)) {
        if (windowScene) {
            self.window = [[FloatWindow alloc] initWithWindowScene:windowScene];
        } else {
            self.window = [[FloatWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
    } else {
        self.window = [[FloatWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    // 极高窗口层级
    self.window.windowLevel = UIWindowLevelAlert + 2000;
    self.window.backgroundColor = [UIColor clearColor];
    
    UIViewController *rootVC = [UIViewController new];
    self.window.rootViewController = rootVC;
    self.window.hidden = NO;

    // 3. 创建悬浮球
    self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatBtn.frame = CGRectMake(20, 150, 60, 60);
    self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
    self.floatBtn.layer.cornerRadius = 30;
    self.floatBtn.layer.masksToBounds = YES;
    [self.floatBtn setTitle:@"音量-" forState:UIControlStateNormal];
    [self.floatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [self.floatBtn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.floatBtn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
    
    [rootVC.view addSubview:self.floatBtn];
    return YES;
}

- (void)btnTapped {
    simulateVolumeDown();
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.window];
    self.floatBtn.center = CGPointMake(self.floatBtn.center.x + translation.x, self.floatBtn.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.window];
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}