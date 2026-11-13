#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

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
    
    self.window = [[FloatWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.windowLevel = UIWindowLevelAlert + 2000;
    self.window.backgroundColor = [UIColor clearColor];
    
    UIViewController *rootVC = [UIViewController new];
    self.window.rootViewController = rootVC;
    self.window.hidden = NO;

    self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatBtn.frame = CGRectMake(20, 150, 60, 60);
    self.floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9];
    self.floatBtn.layer.cornerRadius = 30;
    self.floatBtn.layer.masksToBounds = YES;
    [self.floatBtn setTitle:@"音量-" forState:UIControlStateNormal];
    [self.floatBtn addTarget:self action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.floatBtn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
    
    [rootVC.view addSubview:self.floatBtn];
    return YES;
}

- (void)btnTapped {
    // 利用 MPVolumeView 触发系统级的音量修改，这会自然产生 HID 事件！
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    UISlider *volumeSlider = nil;
    for (UIView *view in [volumeView subviews]) {
        if ([view isKindOfClass:[UISlider class]]) {
            volumeSlider = (UISlider *)view;
            break;
        }
    }
    if (volumeSlider) {
        float newVolume = volumeSlider.value - (1.0 / 16.0); // 降低一格
        if (newVolume < 0) newVolume = 0;
        [volumeSlider setValue:newVolume animated:YES];
        [volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
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