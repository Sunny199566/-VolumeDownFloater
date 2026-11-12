#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

// --- 以下是必须的底层定义，绝对不能漏 ---
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
            // 模拟按下
            IOHIDEventRef downEvent = createEvent(kCFAllocatorDefault, mach_absolute_time(), 0x0C, 0xEA, true, 0);
            if (downEvent) {
                if (setSender) setSender(downEvent, 0xDEFACEDBEEFFECE5);
                dispatchEvent(client, downEvent);
                CFRelease(downEvent);
            }
            
            // 模拟抬起
            IOHIDEventRef upEvent = createEvent(kCFAllocatorDefault, mach_absolute_time(), 0x0C, 0xEA, false, 0);
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
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 兼容 iOS 13+ 的多场景 (修复全局悬浮问题)
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
    
    // 极致提升窗口层级，覆盖所有 App
    self.window.windowLevel = UIWindowLevelAlert + 1000;
    self.window.backgroundColor = [UIColor clearColor];
    
    UIViewController *rootVC = [UIViewController new];
    self.window.rootViewController = rootVC;
    self.window.hidden = NO;

    self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatBtn.frame = CGRectMake(20, 150, 60, 60);
    self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.8];
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