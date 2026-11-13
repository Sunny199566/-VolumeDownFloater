#import <UIKit/UIKit.h>

// 动态声明系统的设置类，这样就不需要去找私有头文件了
@interface PSListController : UIViewController
@property (nonatomic, retain) NSArray *specifiers;
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
@end

@interface RootListController : PSListController
@end

@implementation RootListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
@end