#import <UIKit/UIKit.h>

// 动态声明系统的设置类
@interface PSListController : UIViewController
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
@end

// 这里加上大括号，声明 _specifiers 变量
@interface RootListController : PSListController {
    NSArray *_specifiers;
}
@end

@implementation RootListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
@end