#import "GloryKeyUI.h"
#import "AntiDebug.h"
#import <CommonCrypto/CommonDigest.h>

@interface GloryKeyUI ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITextField *keyTextField;
@property (nonatomic, strong) UIButton *activateButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end

@implementation GloryKeyUI

+ (NSString *)hashString:(NSString *)string {
    const char *str = [string UTF8String];
    if (!str) return @"";
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
}

+ (BOOL)isActivated {
    // Chống gỡ lỗi ngay lập tức khi kiểm tra trạng thái
    if ([AntiDebug isDebuggerAttached]) {
        return NO;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval expiry = [defaults doubleForKey:@"glory_key_expiry"];
    NSString *storedSig = [defaults stringForKey:@"glory_key_signature"];
    
    if (!storedSig || expiry <= 0) {
        return NO;
    }
    
    // Kiểm tra hết hạn
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now > expiry) {
        return NO;
    }
    
    // Tính lại signature bảo mật
    NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"unknown_device";
    NSString *rawStr = [NSString stringWithFormat:@"%@_%.0f_GloryStoreSuperSecretSalt2026!", uuid, expiry];
    NSString *computedSig = [self hashString:rawStr];
    
    return [computedSig isEqualToString:storedSig];
}

+ (void)showIfNeededOnWindow:(UIWindow *)window {
    if (![self isActivated]) {
        // Chạy trên luồng chính
        dispatch_async(dispatch_get_main_queue(), ^{
            GloryKeyUI *keyUI = [[GloryKeyUI alloc] initWithFrame:window.bounds];
            [window addSubview:keyUI];
            [window bringSubviewToFront:keyUI];
        });
    }
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // 1. Hiệu ứng Blur mờ toàn bộ ứng dụng phía sau (Glassmorphism)
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurEffectView.frame = self.bounds;
    blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:blurEffectView];
    
    // 2. Container Panel trung tâm
    CGFloat width = MIN(self.bounds.size.width - 40, 340);
    CGFloat height = 300;
    self.containerView = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width - width)/2, (self.bounds.size.height - height)/2, width, height)];
    self.containerView.backgroundColor = [UIColor colorWithRed:0.03 green:0.05 blue:0.12 alpha:0.8];
    self.containerView.layer.cornerRadius = 20;
    self.containerView.layer.borderWidth = 1.5;
    // Viền màu xanh neon mờ ảo
    self.containerView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.6 blue:1.0 alpha:0.7].CGColor;
    
    // Đổ bóng phát sáng (Neon Glow)
    self.containerView.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.6 blue:1.0 alpha:0.9].CGColor;
    self.containerView.layer.shadowOffset = CGSizeZero;
    self.containerView.layer.shadowOpacity = 0.8;
    self.containerView.layer.shadowRadius = 15;
    self.containerView.layer.masksToBounds = NO;
    
    [self addSubview:self.containerView];
    
    // 3. Tiêu đề GloryStore
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 25, width - 20, 35)];
    titleLabel.text = @"GLORYSTORE";
    titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:26] ?: [UIFont boldSystemFontOfSize:26];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    // Hiệu ứng đổ bóng chữ neon
    titleLabel.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:1.0].CGColor;
    titleLabel.layer.shadowOffset = CGSizeZero;
    titleLabel.layer.shadowRadius = 8;
    titleLabel.layer.shadowOpacity = 0.8;
    [self.containerView addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 60, width - 20, 20)];
    subtitleLabel.text = @"HỆ SINH THÁI KEY BẢO MẬT";
    subtitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor colorWithRed:0.5 green:0.7 blue:1.0 alpha:0.8];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.containerView addSubview:subtitleLabel];
    
    // 4. TextField nhập Key
    self.keyTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 105, width - 40, 48)];
    self.keyTextField.backgroundColor = [UIColor colorWithRed:0.05 green:0.08 blue:0.18 alpha:0.9];
    self.keyTextField.textColor = [UIColor whiteColor];
    self.keyTextField.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:16] ?: [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    self.keyTextField.textAlignment = NSTextAlignmentCenter;
    self.keyTextField.layer.cornerRadius = 12;
    self.keyTextField.layer.borderWidth = 1.0;
    self.keyTextField.layer.borderColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.8 alpha:0.5].CGColor;
    self.keyTextField.placeholder = @"NHẬP MÃ KÍCH HOẠT...";
    
    // Đổi màu placeholder chữ xám xanh
    UIColor *placeholderColor = [UIColor colorWithRed:0.4 green:0.5 blue:0.7 alpha:0.6];
    self.keyTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.keyTextField.placeholder attributes:@{NSForegroundColorAttributeName: placeholderColor}];
    
    self.keyTextField.delegate = self;
    self.keyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyTextField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    [self.containerView addSubview:self.keyTextField];
    
    // 5. Nút Kích hoạt
    self.activateButton = [[UIButton alloc] initWithFrame:CGRectMake(20, 170, width - 40, 48)];
    self.activateButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    [self.activateButton setTitle:@"KÍCH HOẠT THIẾT BỊ" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    self.activateButton.layer.cornerRadius = 12;
    self.activateButton.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.8].CGColor;
    self.activateButton.layer.shadowOffset = CGSizeMake(0, 3);
    self.activateButton.layer.shadowOpacity = 0.5;
    self.activateButton.layer.shadowRadius = 8;
    [self.activateButton addTarget:self action:@selector(handleActivation) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.activateButton];
    
    // 6. Nhãn trạng thái / Lỗi
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 235, width - 40, 40)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.containerView addSubview:self.statusLabel];
    
    // 7. Vòng xoay Loading
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.center = self.activateButton.center;
    self.spinner.hidesWhenStopped = YES;
    [self.containerView addSubview:self.spinner];
    
    // Lắng nghe bàn phím để căn chỉnh UI
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // Ẩn bàn phím khi chạm ra ngoài
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self addGestureRecognizer:tap];
}

- (void)dismissKeyboard {
    [self endEditing:YES];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    CGFloat containerBottom = self.containerView.frame.origin.y + self.containerView.frame.size.height;
    CGFloat keyboardTop = self.bounds.size.height - keyboardFrame.size.height;
    
    if (containerBottom > keyboardTop) {
        [UIView animateWithDuration:0.3 animations:^{
            CGRect frame = self.containerView.frame;
            frame.origin.y = keyboardTop - frame.size.height - 10;
            self.containerView.frame = frame;
        }];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self.containerView.frame;
        frame.origin.y = (self.bounds.size.height - frame.size.height) / 2;
        self.containerView.frame = frame;
    }];
}

- (void)handleActivation {
    NSString *inputKey = [self.keyTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (inputKey.length == 0) {
        self.statusLabel.text = @"Vui lòng nhập mã kích hoạt.";
        self.statusLabel.textColor = [UIColor systemRedColor];
        return;
    }
    
    // Chạy anti-debug trước khi kết nối
    if ([AntiDebug isDebuggerAttached]) {
        self.statusLabel.text = @"Phát hiện Debugger! Ứng dụng sẽ tự động đóng.";
        self.statusLabel.textColor = [UIColor systemRedColor];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
        return;
    }
    
    // Hiển thị trạng thái Loading
    [self.spinner startAnimating];
    self.activateButton.alpha = 0.0;
    self.statusLabel.text = @"Đang kiểm tra key trên máy chủ...";
    self.statusLabel.textColor = [UIColor whiteColor];
    
    // Gọi API Firebase Realtime Database
    // Cấu trúc URL: https://appchatai-313e3-default-rtdb.firebaseio.com/keys/<key>.json
    NSString *urlString = [NSString stringWithFormat:@"https://appchatai-313e3-default-rtdb.firebaseio.com/keys/%@.json", inputKey];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.activateButton.alpha = 1.0;
            
            if (error) {
                self.statusLabel.text = [NSString stringWithFormat:@"Lỗi kết nối: %@", error.localizedDescription];
                self.statusLabel.textColor = [UIColor systemRedColor];
                return;
            }
            
            if (!data) {
                self.statusLabel.text = @"Không nhận được phản hồi từ máy chủ.";
                self.statusLabel.textColor = [UIColor systemRedColor];
                return;
            }
            
            NSError *jsonError = nil;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            // Nếu key không tồn tại trên Firebase, API sẽ trả về null (NSNull)
            if (jsonError || jsonObject == nil || [jsonObject isKindOfClass:[NSNull class]]) {
                self.statusLabel.text = @"Mã kích hoạt không chính xác hoặc đã hết hạn.";
                self.statusLabel.textColor = [UIColor systemRedColor];
                return;
            }
            
            if ([jsonObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *keyData = (NSDictionary *)jsonObject;
                NSInteger duration = [keyData[@"duration"] integerValue];
                if (duration <= 0) duration = 1; // Mặc định 1 ngày nếu lỗi
                
                self.statusLabel.text = @"Mã chính xác! Đang cấu hình thiết bị...";
                self.statusLabel.textColor = [UIColor systemGreenColor];
                
                // Thực hiện XÓA key ngay lập tức khỏi Firebase RTDB
                [self deleteKeyFromServer:inputKey duration:duration];
            } else {
                self.statusLabel.text = @"Dữ liệu máy chủ không hợp lệ.";
                self.statusLabel.textColor = [UIColor systemRedColor];
            }
        });
    }];
    [task resume];
}

- (void)deleteKeyFromServer:(NSString *)key duration:(NSInteger)duration {
    NSString *urlString = [NSString stringWithFormat:@"https://appchatai-313e3-default-rtdb.firebaseio.com/keys/%@.json", key];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"DELETE";
    
    NSURLSessionDataTask *deleteTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                // Kể cả khi không xóa được do mạng, ta vẫn lưu key hoặc retry để đảm bảo trải nghiệm người dùng
                NSLog(@"Lỗi xóa key trên Firebase: %@", error.localizedDescription);
            }
            
            // Kích hoạt thành công: tính hạn sử dụng và lưu xuống cục bộ
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval expiry = now + (duration * 24 * 3600); // duration tính theo ngày
            
            NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"unknown_device";
            NSString *rawStr = [NSString stringWithFormat:@"%@_%.0f_GloryStoreSuperSecretSalt2026!", uuid, expiry];
            NSString *signature = [GloryKeyUI hashString:rawStr];
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setDouble:expiry forKey:@"glory_key_expiry"];
            [defaults setObject:signature forKey:@"glory_key_signature"];
            [defaults synchronize];
            
            // Hiển thị thông báo thành công và tắt giao diện sau 1 giây
            self.statusLabel.text = [NSString stringWithFormat:@"Kích hoạt thành công %@ ngày! Cảm ơn bạn.", @(duration)];
            self.statusLabel.textColor = [UIColor systemGreenColor];
            
            [UIView animateWithDuration:0.5 delay:1.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.alpha = 0.0;
            } completion:^(BOOL finished) {
                [self removeFromSuperview];
            }];
        });
    }];
    [deleteTask resume];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self handleActivation];
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
