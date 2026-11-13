#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

// 底层 HID 事件定义
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef CFTypeRef IOHIDEventSystemClientRef;
typedef IOHIDEventRef (*IOHIDEventCreateKeyboardEvent_t)(CFAllocatorRef, uint64_t, uint16_t, uint16_t, Boolean, uint32_t);
typedef IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreate_t)(CFAllocatorRef);
typedef void (*IOHIDEventSystemClientDispatchEvent_t)(IOHIDEventSystemClientRef, IOHIDEventRef);

void simulateVolumeDown(void) {
    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!handle) return;

    IOHIDEventCreateKeyboardEvent_t createEvent = (IOHIDEventCreateKeyboardEvent_t)dlsym(handle, "IOHIDEventCreateKeyboardEvent");
    IOHIDEventSystemClientCreate_t createClient = (IOHIDEventSystemClientCreate_t)dlsym(handle, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEvent_t dispatchEvent = (IOHIDEventSystemClientDispatchEvent_t)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");

    if (createEvent && createClient && dispatchEvent) {
        IOHIDEventSystemClientRef client = createClient(kCFAllocatorDefault);
        if (client) {
            uint64_t timestamp = mach_absolute_time();
            
            // 按下 (Consumer Page 0x0C, Usage 0xEA)
            IOHIDEventRef downEvent = createEvent(kCFAllocatorDefault, timestamp, 0x0C, 0xEA, true, 0);
            if (downEvent) {
                dispatchEvent(client, downEvent);
                CFRelease(downEvent);
            }
            
            usleep(50000); // 50毫秒延时
            
            // 抬起
            IOHIDEventRef upEvent = createEvent(kCFAllocatorDefault, timestamp, 0x0C, 0xEA, false, 0);
            if (upEvent) {
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

@interface FloaterManager : NSObject
@property (strong, nonatomic) FloatWindow *window;
@property (strong, nonatomic) UIButton *floatBtn;
+ (instancetype)sharedInstance;
- (void)setup;
@end

@implementation FloaterManager

+ (instancetype)sharedInstance {
    static FloaterManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FloaterManager alloc] init];
    });
    return instance;
}

- (void)setup {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                windowScene = (UIWindowScene *)scene;
                break;
            }
        }
        
        if (@available(iOS 13.0, *)) {
            if (windowScene) {
                self.window = [[FloatWindow alloc] initWithWindowScene:windowScene];
            }
        }
        if (!self.window) {
            self.window = [[FloatWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        
        self.window.windowLevel = UIWindowLevelAlert + 2000;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.rootViewController = [UIViewController new];
        self.window.hidden = NO;

        self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatBtn.frame = CGRectMake(20, 150, 60, 60);
        self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
        self.floatBtn.layer.cornerRadius = 30;
        self.floatBtn.layer.masksToBounds = YES;
        [self.floatBtn setTitle:@"音量-" forState:UIControlStateNormal];
        [self.floatBtn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.floatBtn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
        
        [self.window.rootViewController.view addSubview:self.floatBtn];
    });
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

// 构造函数：在注入到 SpringBoard 时自动执行
__attribute__((constructor)) static void initFloater() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FloaterManager sharedInstance] setup];
    });
}