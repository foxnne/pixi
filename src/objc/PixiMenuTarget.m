#import <AppKit/AppKit.h>

/* Called from Zig when a native menu item is chosen. Zig exports this and sets a pending action. */
extern void PixiNativeMenuAction(int id);

@interface PixiMenuTarget : NSObject
- (void)openFolder:(id)sender;
- (void)openFiles:(id)sender;
- (void)save:(id)sender;
@end

@implementation PixiMenuTarget
- (void)openFolder:(id)sender { (void)sender; PixiNativeMenuAction(0); }
- (void)openFiles:(id)sender  { (void)sender; PixiNativeMenuAction(1); }
- (void)save:(id)sender      { (void)sender; PixiNativeMenuAction(2); }
@end

/* So Zig can get the SEL for setAction: without linking the Objective-C runtime directly. */
void *PixiGetSelector(const char *name) {
    return (void *)sel_registerName(name);
}
