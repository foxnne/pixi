#import <AppKit/AppKit.h>

/* Called from Zig when a native menu item is chosen. Zig exports this and sets a pending action. */
extern void PixiNativeMenuAction(int id);

@interface PixiMenuTarget : NSObject
- (void)openFolder:(id)sender;
- (void)openFiles:(id)sender;
- (void)save:(id)sender;
- (void)copy:(id)sender;
- (void)paste:(id)sender;
- (void)undo:(id)sender;
- (void)redo:(id)sender;
- (void)transform:(id)sender;
- (void)toggleExplorer:(id)sender;
- (void)showDvuiDemo:(id)sender;
@end

@implementation PixiMenuTarget
- (void)openFolder:(id)sender     { (void)sender; PixiNativeMenuAction(0); }
- (void)openFiles:(id)sender     { (void)sender; PixiNativeMenuAction(1); }
- (void)save:(id)sender          { (void)sender; PixiNativeMenuAction(2); }
- (void)copy:(id)sender          { (void)sender; PixiNativeMenuAction(3); }
- (void)paste:(id)sender         { (void)sender; PixiNativeMenuAction(4); }
- (void)undo:(id)sender          { (void)sender; PixiNativeMenuAction(5); }
- (void)redo:(id)sender         { (void)sender; PixiNativeMenuAction(6); }
- (void)transform:(id)sender     { (void)sender; PixiNativeMenuAction(7); }
- (void)toggleExplorer:(id)sender { (void)sender; PixiNativeMenuAction(8); }
- (void)showDvuiDemo:(id)sender  { (void)sender; PixiNativeMenuAction(9); }
@end

/* So Zig can get the SEL for setAction: without linking the Objective-C runtime directly. */
void *PixiGetSelector(const char *name) {
    return (void *)sel_registerName(name);
}
