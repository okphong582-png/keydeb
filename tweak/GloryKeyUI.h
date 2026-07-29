#import <UIKit/UIKit.h>

@interface GloryKeyUI : UIView <UITextFieldDelegate>

+ (void)showIfNeededOnWindow:(UIWindow *)window;
+ (BOOL)isActivated;

@end
