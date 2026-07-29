#import <UIKit/UIKit.h>
#import "GloryKeyUI.h"
#import "AntiDebug.h"

// Biến kiểm soát xem có kích hoạt cho ứng dụng hiện tại hay không
static BOOL shouldApplyTweak = NO;

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (shouldApplyTweak && ![GloryKeyUI isActivated]) {
        [GloryKeyUI showIfNeededOnWindow:self];
    }
}
%end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!shouldApplyTweak) return;
    
    NSString *className = NSStringFromClass([self class]);
    // Bỏ qua lớp giao diện của Tweak và các lớp nhập liệu hệ thống
    if ([className containsString:@"GloryKey"] || 
        [className containsString:@"UIInputWindow"] || 
        [className containsString:@"CompatInputSanitizer"]) {
        return;
    }
    
    if (![GloryKeyUI isActivated]) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [[[UIApplication sharedApplication] delegate] window];
        if (window) {
            [GloryKeyUI showIfNeededOnWindow:window];
        }
    }
}
%end

%ctor {
    // Chỉ kích hoạt tweak cho các ứng dụng người dùng, bỏ qua SpringBoard và các daemon hệ thống
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleIdentifier || 
        [bundleIdentifier hasPrefix:@"com.apple."] || 
        [bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        return;
    }
    
    shouldApplyTweak = YES;
    
    // 1. Kích hoạt chống gỡ lỗi (anti-debugging) cực mạnh ngay khi load tweak
    [AntiDebug applyAntiDebug];
    
    // 2. Đăng ký hiển thị UI khóa ứng dụng sau khi ứng dụng hoàn tất khởi chạy (đề phòng nếu window được tạo trước khi hook kịp ăn)
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = nil;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *windowScene = (UIWindowScene *)scene;
                        for (UIWindow *w in windowScene.windows) {
                            if (w.isKeyWindow) {
                                window = w;
                                break;
                            }
                        }
                    }
                    if (window) break;
                }
            }
            
            if (!window) {
                window = [UIApplication sharedApplication].keyWindow;
            }
            if (!window) {
                window = [[UIApplication sharedApplication] delegate].window;
            }
            
            if (window) {
                [GloryKeyUI showIfNeededOnWindow:window];
            }
        });
    }];
}
