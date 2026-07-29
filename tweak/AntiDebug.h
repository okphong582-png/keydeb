#import <Foundation/Foundation.h>

@interface AntiDebug : NSObject

+ (void)applyAntiDebug;
+ (BOOL)isDebuggerAttached;

@end
