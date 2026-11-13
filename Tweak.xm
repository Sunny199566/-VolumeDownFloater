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
            
            // 按下
            IOHIDEventRef downEvent = createEvent(kCFAllocatorDefault, timestamp, 0x0C, 0xEA, true, 0);
            if (downEvent) {
                dispatchEvent(client, downEvent);
                CFRelease(downEvent);
            }
            
            usleep(50000); // 延时 50 毫秒
            
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

@interface FloaterManager : NSObject
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIButton *floatBtn;
@property (strong, nonatomic) UIImpactFeedbackGenerator *hapticGenerator; // 点击震动
@property (strong, nonatomic) UINotificationFeedbackGenerator *notifyGenerator; // 状态切换震动
@property (nonatomic, assign) BOOL isActive; // 新增：当前是否开启
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
        
        CGFloat btnSize = 60.0;
        
        if (@available(iOS 13.0, *)) {
            if (windowScene) {
                self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
            }
        }
        if (!self.window) {
            self.window = [[UIWindow alloc] initWithFrame:CGRectMake(20, 150, btnSize, btnSize)];
        }
        
        self.window.frame = CGRectMake(20, 150, btnSize, btnSize);
        self.window.windowLevel = UIWindowLevelAlert + 2000;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.rootViewController = [UIViewController new];
        self.window.rootViewController.view.backgroundColor = [UIColor clearColor];
        self.window.hidden = NO;

        // 初始化震动引擎
        self.hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [self.hapticGenerator prepare];
        
        self.notifyGenerator = [[UINotificationFeedbackGenerator alloc] init];
        [self.notifyGenerator prepare];
        
        // 默认开启状态
        self.isActive = YES;

        // 创建悬浮球
        self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatBtn.frame = self.window.rootViewController.view.bounds;
        self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9]; // 默认红色
        self.floatBtn.layer.cornerRadius = btnSize / 2.0;
        self.floatBtn.layer.masksToBounds = YES;
        [self.floatBtn setTitle:@"音量-" forState:UIControlStateNormal];
        
        // 1. 单击手势（触发脚本）
        [self.floatBtn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // 2. 长按手势（切换开关）
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.5; // 按住 0.5 秒触发
        [self.floatBtn addGestureRecognizer:longPress];
        
        // 3. 拖拽手势
        [self.floatBtn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
        
        [self.window.rootViewController.view addSubview:self.floatBtn];
    });
}

- (void)btnTapped {
    // 如果开关是关闭状态，直接返回，不执行任何操作
    if (!self.isActive) return;

    [self.hapticGenerator impactOccurred];
    [self.hapticGenerator prepare]; 
    simulateVolumeDown();
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // 切换状态
        self.isActive = !self.isActive;
        
        if (self.isActive) {
            // 开启状态：恢复红色，轻震一下
            self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
            [self.notifyGenerator notificationOccurred:UINotificationFeedbackTypeSuccess];
        } else {
            // 关闭状态：变成半透明灰色，重震一下（警告感）
            self.floatBtn.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
            [self.notifyGenerator notificationOccurred:UINotificationFeedbackTypeWarning];
        }
        [self.notifyGenerator prepare];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.window];
    CGPoint newCenter = CGPointMake(self.window.center.x + translation.x, self.window.center.y + translation.y);
    
    CGFloat btnRadius = self.window.bounds.size.width / 2.0;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    CGFloat padding = 10.0;
    CGFloat minX = btnRadius + padding;
    CGFloat maxX = screenWidth - btnRadius - padding;
    CGFloat minY = btnRadius + 50.0;
    CGFloat maxY = screenHeight - btnRadius - 30.0;
    
    newCenter.x = MAX(minX, MIN(newCenter.x, maxX));
    newCenter.y = MAX(minY, MIN(newCenter.y, maxY));
    
    self.window.center = newCenter;
    [pan setTranslation:CGPointZero inView:self.window];
}
@end

__attribute__((constructor)) static void initFloater() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FloaterManager sharedInstance] setup];
    });
}