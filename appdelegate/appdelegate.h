#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomDelegate : NSObject
+ (void)load; // load is called before even main() is run (as part of objc class registration)
@end

NS_ASSUME_NONNULL_END