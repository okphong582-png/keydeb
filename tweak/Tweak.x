#import <UIKit/UIKit.h>
#import "GloryKeyUI.h"
#import "AntiDebug.h"

%ctor {
    // Chỉ kích hoạt tweak cho các ứng dụng người dùng, bỏ qua SpringBoard và các daemon hệ thống
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleIdentifier || 
        [bundleIdentifier hasPrefix:@"com.apple."] || 
        [bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        return;
    }
    
    // 1. Kích hoạt chống gỡ lỗi (anti-debugging) cực mạnh ngay khi load tweak
    [AntiDebug applyAntiDebug];
    
    // 2. Đăng ký hiển thị UI khóa ứng dụng sau khi ứng dụng hoàn tất khởi chạy
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
            } else {
                // Thử lại lần cuối sau 1.0s nếu các window khởi tạo chậm
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UIWindow *retryWindow = [UIApplication sharedApplication].keyWindow ?: [[[UIApplication sharedApplication] delegate] window];
                    if (retryWindow) {
                        [GloryKeyUI showIfNeededOnWindow:retryWindow];
                    }
                });
            }
        });
    }];
}
