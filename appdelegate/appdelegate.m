#import "appdelegate.h"
#import <objc/runtime.h>

// part of your application
extern void forward_load_message(const char * filename); 

@implementation CustomDelegate

+ (void)load{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Class class = objc_getClass("GLFWApplicationDelegate");
	
		[CustomDelegate swizzle:class src:@selector(application:openFile:) tgt:@selector(swz_application:openFile:)];
		[CustomDelegate swizzle:class src:@selector(application:openFiles:) tgt:@selector(swz_application:openFiles:)];
	});
}

+ (void) swizzle:(Class) original_c src:(SEL)original_s tgt:(SEL)target_s{
	Class target_c = [CustomDelegate class];
	Method originalMethod = class_getInstanceMethod(original_c, original_s);
	Method swizzledMethod = class_getInstanceMethod(target_c, target_s);

	BOOL didAddMethod =
	class_addMethod(original_c,
					original_s,
					method_getImplementation(swizzledMethod),
					method_getTypeEncoding(swizzledMethod));

	if (didAddMethod) {
		class_replaceMethod(original_c,
							target_s,
							method_getImplementation(originalMethod),
							method_getTypeEncoding(originalMethod));
	} else {
		method_exchangeImplementations(originalMethod, swizzledMethod);
	}
}

- (BOOL)swz_application:(NSApplication *)sender openFile:(NSString *)filename{
	forward_load_message(filename.UTF8String);
}

- (void)swz_application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames{
	forward_load_message(filenames.firstObject.UTF8String);
}

@end