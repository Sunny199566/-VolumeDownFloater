#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

// HID 函数指针定义
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef CFTypeRef IOHIDEventSystemClientRef;
typedef IOHIDEventRef (*IOHIDEventCreateKeyboardEvent_t)(CFAllocatorRef, AbsoluteTime, uint16_t, uint16_t, Boolean, uint32_t);
typedef IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreate_t)(CFAllocatorRef);
typedef void (*IOHIDEventSystemClientDispatchEvent_t)(IOHIDEventSystemClientRef, IOHIDEventRef);

// 模拟音量减
void simulateVolumeDown(void) {
    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!handle) return;

    IOHIDEventCreateKeyboardEvent_t createEvent = (IOHIDEventCreateKeyboardEvent_t)dlsym(handle, "IOHIDEventCreateKeyboardEvent");
    IOHIDEventSystemClientCreate_t createClient = (IOHIDEventSystemClientCreate_t)dlsym(handle, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEvent_t dispatchEvent = (IOHIDEventSystemClientDispatchEvent_t)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");

    if (createEvent && createClient && dispatchEvent) {
        // 0x0C = Consumer Page, 0xEA = Volume Down
        IOHIDEventRef event = createEvent(kCFAllocatorDefault, mach_absolute_time(), 0x0C, 0xEA, true, 0);
        if (event) {
            IOHIDEventSystemClientRef client = createClient(kCFAllocatorDefault);
            if (client) {
                dispatchEvent(client, event);
                CFRelease(client);
            }
            CFRelease(event);
        }
    }
    dlclose(handle);
}

@interface FloatWindow : UIWindow
@end

@implementation FloatWindow
// 确保悬浮窗能响应触摸事件
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
    
    // 创建高阶层级的全屏透明窗口
    self.window = [[FloatWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.windowLevel = UIWindowLevelStatusBar + 100;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.rootViewController = [UIViewController new];
    self.window.hidden = NO;

    // 创建悬浮球按钮
    self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatBtn.frame = CGRectMake(20, 150, 60, 60);
    self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.8];
    self.floatBtn.layer.cornerRadius = 30;
    self.floatBtn.layer.masksToBounds = YES;
    [self.floatBtn setTitle:@"音量-" forState:UIControlStateNormal];
    [self.floatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // 绑定点击事件
    [self.floatBtn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
    // 绑定拖拽事件
    [self.floatBtn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
    
    [self.window.rootViewController.view addSubview:self.floatBtn];
    return YES;
}

- (void)btnTapped {
    // 点击时触发音量减
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
