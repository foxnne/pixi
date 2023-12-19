// THIS FILE HAS BEEN AUTO-GENERATED USING THE 'DEAR BINDINGS' GENERATOR METADATA.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

// Help:
// - Read FAQ at http://dearimgui.com/faq
// - Newcomers, read 'Programmer guide' in imgui.cpp for notes on how to setup Dear ImGui in your codebase.
// - Call and read ImGui::ShowDemoWindow() in imgui_demo.cpp. All applications in examples/ are doing that.
// Read imgui.cpp for details, links and comments.

// Resources:
// - FAQ                   http://dearimgui.com/faq
// - Homepage              https://github.com/ocornut/imgui
// - Releases & changelog  https://github.com/ocornut/imgui/releases
// - Gallery               https://github.com/ocornut/imgui/issues/6478 (please post your screenshots/video there!)
// - Wiki                  https://github.com/ocornut/imgui/wiki (lots of good stuff there)
// - Getting Started       https://github.com/ocornut/imgui/wiki/Getting-Started
// - Glossary              https://github.com/ocornut/imgui/wiki/Glossary
// - Issues & support      https://github.com/ocornut/imgui/issues
// - Tests & Automation    https://github.com/ocornut/imgui_test_engine

// Getting Started?
// - Read https://github.com/ocornut/imgui/wiki/Getting-Started
// - For first-time users having issues compiling/linking/running/loading fonts:
//   please post in https://github.com/ocornut/imgui/discussions if you cannot find a solution in resources above.

// zig fmt: off
const std = @import("std");
const c = @cImport({
    @cInclude("stdarg.h");
});
pub const backends = struct {
    pub const mach = @import("imgui_mach.zig");
};

pub const VERSION = "1.89.9";
pub const VERSION_NUM = 18990;
pub const PAYLOAD_TYPE_COLOR_3F = "_COL3F";   // float[3]: Standard type for colors, without alpha. User code may use this type.
pub const PAYLOAD_TYPE_COLOR_4F = "_COL4F";   // float[4]: Standard type for colors. User code may use this type.
pub const UNICODE_CODEPOINT_INVALID = 0xFFFD; // Invalid Unicode code point (standard value).
pub const UNICODE_CODEPOINT_MAX = 0xFFFF;     // Maximum Unicode code point supported by this build.
pub const COL32_R_SHIFT = 0;
pub const COL32_G_SHIFT = 8;
pub const COL32_B_SHIFT = 16;
pub const COL32_A_SHIFT = 24;
pub const COL32_A_MASK = 0xFF000000;
pub const DRAWLIST_TEX_LINES_WIDTH_MAX = 63;

//-----------------------------------------------------------------------------
// Enumerations
//-----------------------------------------------------------------------------

// Flags for ImGui::Begin()
// (Those are per-window flags. There are shared flags in ImGuiIO: io.ConfigWindowsResizeFromEdges and io.ConfigWindowsMoveFromTitleBarOnly)
pub const WindowFlags_None = 0;
pub const WindowFlags_NoTitleBar = 1;                    // Disable title-bar
pub const WindowFlags_NoResize = 2;                      // Disable user resizing with the lower-right grip
pub const WindowFlags_NoMove = 4;                        // Disable user moving the window
pub const WindowFlags_NoScrollbar = 8;                   // Disable scrollbars (window can still scroll with mouse or programmatically)
pub const WindowFlags_NoScrollWithMouse = 16;            // Disable user vertically scrolling with mouse wheel. On child window, mouse wheel will be forwarded to the parent unless NoScrollbar is also set.
pub const WindowFlags_NoCollapse = 32;                   // Disable user collapsing window by double-clicking on it. Also referred to as Window Menu Button (e.g. within a docking node).
pub const WindowFlags_AlwaysAutoResize = 64;             // Resize every window to its content every frame
pub const WindowFlags_NoBackground = 128;                // Disable drawing background color (WindowBg, etc.) and outside border. Similar as using SetNextWindowBgAlpha(0.0f).
pub const WindowFlags_NoSavedSettings = 256;             // Never load/save settings in .ini file
pub const WindowFlags_NoMouseInputs = 512;               // Disable catching mouse, hovering test with pass through.
pub const WindowFlags_MenuBar = 1024;                    // Has a menu-bar
pub const WindowFlags_HorizontalScrollbar = 2048;        // Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
pub const WindowFlags_NoFocusOnAppearing = 4096;         // Disable taking focus when transitioning from hidden to visible state
pub const WindowFlags_NoBringToFrontOnFocus = 8192;      // Disable bringing window to front when taking focus (e.g. clicking on it or programmatically giving it focus)
pub const WindowFlags_AlwaysVerticalScrollbar = 16384;   // Always show vertical scrollbar (even if ContentSize.y < Size.y)
pub const WindowFlags_AlwaysHorizontalScrollbar = 32768; // Always show horizontal scrollbar (even if ContentSize.x < Size.x)
pub const WindowFlags_AlwaysUseWindowPadding = 65536;    // Ensure child windows without border uses style.WindowPadding (ignored by default for non-bordered child windows, because more convenient)
pub const WindowFlags_NoNavInputs = 262144;              // No gamepad/keyboard navigation within the window
pub const WindowFlags_NoNavFocus = 524288;               // No focusing toward this window with gamepad/keyboard navigation (e.g. skipped by CTRL+TAB)
pub const WindowFlags_UnsavedDocument = 1048576;         // Display a dot next to the title. When used in a tab/docking context, tab is selected when clicking the X + closure is not assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
pub const WindowFlags_NoDocking = 2097152;               // Disable docking of this window
pub const WindowFlags_NoNav = 786432;
pub const WindowFlags_NoDecoration = 43;
pub const WindowFlags_NoInputs = 786944;
// [Internal]
pub const WindowFlags_NavFlattened = 8388608;            // [BETA] On child window: allow gamepad/keyboard navigation to cross over parent border to this child or between sibling child windows.
pub const WindowFlags_ChildWindow = 16777216;            // Don't use! For internal use by BeginChild()
pub const WindowFlags_Tooltip = 33554432;                // Don't use! For internal use by BeginTooltip()
pub const WindowFlags_Popup = 67108864;                  // Don't use! For internal use by BeginPopup()
pub const WindowFlags_Modal = 134217728;                 // Don't use! For internal use by BeginPopupModal()
pub const WindowFlags_ChildMenu = 268435456;             // Don't use! For internal use by BeginMenu()
pub const WindowFlags_DockNodeHost = 536870912;          // Don't use! For internal use by Begin()/NewFrame()

// Flags for ImGui::InputText()
// (Those are per-item flags. There are shared flags in ImGuiIO: io.ConfigInputTextCursorBlink and io.ConfigInputTextEnterKeepActive)
pub const InputTextFlags_None = 0;
pub const InputTextFlags_CharsDecimal = 1;           // Allow 0123456789.+-*/
pub const InputTextFlags_CharsHexadecimal = 2;       // Allow 0123456789ABCDEFabcdef
pub const InputTextFlags_CharsUppercase = 4;         // Turn a..z into A..Z
pub const InputTextFlags_CharsNoBlank = 8;           // Filter out spaces, tabs
pub const InputTextFlags_AutoSelectAll = 16;         // Select entire text when first taking mouse focus
pub const InputTextFlags_EnterReturnsTrue = 32;      // Return 'true' when Enter is pressed (as opposed to every time the value was modified). Consider looking at the IsItemDeactivatedAfterEdit() function.
pub const InputTextFlags_CallbackCompletion = 64;    // Callback on pressing TAB (for completion handling)
pub const InputTextFlags_CallbackHistory = 128;      // Callback on pressing Up/Down arrows (for history handling)
pub const InputTextFlags_CallbackAlways = 256;       // Callback on each iteration. User code may query cursor position, modify text buffer.
pub const InputTextFlags_CallbackCharFilter = 512;   // Callback on character inputs to replace or discard them. Modify 'EventChar' to replace or discard, or return 1 in callback to discard.
pub const InputTextFlags_AllowTabInput = 1024;       // Pressing TAB input a '\t' character into the text field
pub const InputTextFlags_CtrlEnterForNewLine = 2048; // In multi-line mode, unfocus with Enter, add new line with Ctrl+Enter (default is opposite: unfocus with Ctrl+Enter, add line with Enter).
pub const InputTextFlags_NoHorizontalScroll = 4096;  // Disable following the cursor horizontally
pub const InputTextFlags_AlwaysOverwrite = 8192;     // Overwrite mode
pub const InputTextFlags_ReadOnly = 16384;           // Read-only mode
pub const InputTextFlags_Password = 32768;           // Password mode, display all characters as '*'
pub const InputTextFlags_NoUndoRedo = 65536;         // Disable undo/redo. Note that input text owns the text data while active, if you want to provide your own undo/redo stack you need e.g. to call ClearActiveID().
pub const InputTextFlags_CharsScientific = 131072;   // Allow 0123456789.+-*/eE (Scientific notation input)
pub const InputTextFlags_CallbackResize = 262144;    // Callback on buffer capacity changes request (beyond 'buf_size' parameter value), allowing the string to grow. Notify when the string wants to be resized (for string types which hold a cache of their Size). You will be provided a new BufSize in the callback and NEED to honor it. (see misc/cpp/imgui_stdlib.h for an example of using this)
pub const InputTextFlags_CallbackEdit = 524288;      // Callback on any edit (note that InputText() already returns true on edit, the callback is useful mainly to manipulate the underlying buffer while focus is active)
pub const InputTextFlags_EscapeClearsAll = 1048576;  // Escape key clears content if not empty, and deactivate otherwise (contrast to default behavior of Escape to revert)

// Flags for ImGui::TreeNodeEx(), ImGui::CollapsingHeader*()
pub const TreeNodeFlags_None = 0;
pub const TreeNodeFlags_Selected = 1;                // Draw as selected
pub const TreeNodeFlags_Framed = 2;                  // Draw frame with background (e.g. for CollapsingHeader)
pub const TreeNodeFlags_AllowOverlap = 4;            // Hit testing to allow subsequent widgets to overlap this one
pub const TreeNodeFlags_NoTreePushOnOpen = 8;        // Don't do a TreePush() when open (e.g. for CollapsingHeader) = no extra indent nor pushing on ID stack
pub const TreeNodeFlags_NoAutoOpenOnLog = 16;        // Don't automatically and temporarily open node when Logging is active (by default logging will automatically open tree nodes)
pub const TreeNodeFlags_DefaultOpen = 32;            // Default node to be open
pub const TreeNodeFlags_OpenOnDoubleClick = 64;      // Need double-click to open node
pub const TreeNodeFlags_OpenOnArrow = 128;           // Only open when clicking on the arrow part. If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set, single-click arrow or double-click all box to open.
pub const TreeNodeFlags_Leaf = 256;                  // No collapsing, no arrow (use as a convenience for leaf nodes).
pub const TreeNodeFlags_Bullet = 512;                // Display a bullet instead of arrow. IMPORTANT: node can still be marked open/close if you don't set the _Leaf flag!
pub const TreeNodeFlags_FramePadding = 1024;         // Use FramePadding (even for an unframed text node) to vertically align text baseline to regular widget height. Equivalent to calling AlignTextToFramePadding().
pub const TreeNodeFlags_SpanAvailWidth = 2048;       // Extend hit box to the right-most edge, even if not framed. This is not the default in order to allow adding other items on the same line. In the future we may refactor the hit system to be front-to-back, allowing natural overlaps and then this can become the default.
pub const TreeNodeFlags_SpanFullWidth = 4096;        // Extend hit box to the left-most and right-most edges (bypass the indented area).
pub const TreeNodeFlags_NavLeftJumpsBackHere = 8192; // (WIP) Nav: left direction may move to this TreeNode() from any of its child (items submitted between TreeNode and TreePop)
//ImGuiTreeNodeFlags_NoScrollOnOpen     = 1 << 14,  // FIXME: TODO: Disable automatic scroll on TreePop() if node got just open and contents is not visible
pub const TreeNodeFlags_CollapsingHeader = 26;

// Flags for OpenPopup*(), BeginPopupContext*(), IsPopupOpen() functions.
// - To be backward compatible with older API which took an 'int mouse_button = 1' argument, we need to treat
//   small flags values as a mouse button index, so we encode the mouse button in the first few bits of the flags.
//   It is therefore guaranteed to be legal to pass a mouse button index in ImGuiPopupFlags.
// - For the same reason, we exceptionally default the ImGuiPopupFlags argument of BeginPopupContextXXX functions to 1 instead of 0.
//   IMPORTANT: because the default parameter is 1 (==ImGuiPopupFlags_MouseButtonRight), if you rely on the default parameter
//   and want to use another flag, you need to pass in the ImGuiPopupFlags_MouseButtonRight flag explicitly.
// - Multiple buttons currently cannot be combined/or-ed in those functions (we could allow it later).
pub const PopupFlags_None = 0;
pub const PopupFlags_MouseButtonLeft = 0;          // For BeginPopupContext*(): open on Left Mouse release. Guaranteed to always be == 0 (same as ImGuiMouseButton_Left)
pub const PopupFlags_MouseButtonRight = 1;         // For BeginPopupContext*(): open on Right Mouse release. Guaranteed to always be == 1 (same as ImGuiMouseButton_Right)
pub const PopupFlags_MouseButtonMiddle = 2;        // For BeginPopupContext*(): open on Middle Mouse release. Guaranteed to always be == 2 (same as ImGuiMouseButton_Middle)
pub const PopupFlags_MouseButtonMask_ = 31;
pub const PopupFlags_MouseButtonDefault_ = 1;
pub const PopupFlags_NoOpenOverExistingPopup = 32; // For OpenPopup*(), BeginPopupContext*(): don't open if there's already a popup at the same level of the popup stack
pub const PopupFlags_NoOpenOverItems = 64;         // For BeginPopupContextWindow(): don't return true when hovering items, only when hovering empty space
pub const PopupFlags_AnyPopupId = 128;             // For IsPopupOpen(): ignore the ImGuiID parameter and test for any popup.
pub const PopupFlags_AnyPopupLevel = 256;          // For IsPopupOpen(): search/test at any level of the popup stack (default test in the current level)
pub const PopupFlags_AnyPopup = 384;

// Flags for ImGui::Selectable()
pub const SelectableFlags_None = 0;
pub const SelectableFlags_DontClosePopups = 1;  // Clicking this doesn't close parent popup window
pub const SelectableFlags_SpanAllColumns = 2;   // Selectable frame can span all columns (text will still fit in current column)
pub const SelectableFlags_AllowDoubleClick = 4; // Generate press events on double clicks too
pub const SelectableFlags_Disabled = 8;         // Cannot be selected, display grayed out text
pub const SelectableFlags_AllowOverlap = 16;    // (WIP) Hit testing to allow subsequent widgets to overlap this one

// Flags for ImGui::BeginCombo()
pub const ComboFlags_None = 0;
pub const ComboFlags_PopupAlignLeft = 1; // Align the popup toward the left by default
pub const ComboFlags_HeightSmall = 2;    // Max ~4 items visible. Tip: If you want your combo popup to be a specific size you can use SetNextWindowSizeConstraints() prior to calling BeginCombo()
pub const ComboFlags_HeightRegular = 4;  // Max ~8 items visible (default)
pub const ComboFlags_HeightLarge = 8;    // Max ~20 items visible
pub const ComboFlags_HeightLargest = 16; // As many fitting items as possible
pub const ComboFlags_NoArrowButton = 32; // Display on the preview box without the square arrow button
pub const ComboFlags_NoPreview = 64;     // Display only a square arrow button
pub const ComboFlags_HeightMask_ = 30;

// Flags for ImGui::BeginTabBar()
pub const TabBarFlags_None = 0;
pub const TabBarFlags_Reorderable = 1;                  // Allow manually dragging tabs to re-order them + New tabs are appended at the end of list
pub const TabBarFlags_AutoSelectNewTabs = 2;            // Automatically select new tabs when they appear
pub const TabBarFlags_TabListPopupButton = 4;           // Disable buttons to open the tab list popup
pub const TabBarFlags_NoCloseWithMiddleMouseButton = 8; // Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You can still repro this behavior on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
pub const TabBarFlags_NoTabListScrollingButtons = 16;   // Disable scrolling buttons (apply when fitting policy is ImGuiTabBarFlags_FittingPolicyScroll)
pub const TabBarFlags_NoTooltip = 32;                   // Disable tooltips when hovering a tab
pub const TabBarFlags_FittingPolicyResizeDown = 64;     // Resize tabs when they don't fit
pub const TabBarFlags_FittingPolicyScroll = 128;        // Add scroll buttons when tabs don't fit
pub const TabBarFlags_FittingPolicyMask_ = 192;
pub const TabBarFlags_FittingPolicyDefault_ = 64;

// Flags for ImGui::BeginTabItem()
pub const TabItemFlags_None = 0;
pub const TabItemFlags_UnsavedDocument = 1;              // Display a dot next to the title + tab is selected when clicking the X + closure is not assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
pub const TabItemFlags_SetSelected = 2;                  // Trigger flag to programmatically make the tab selected when calling BeginTabItem()
pub const TabItemFlags_NoCloseWithMiddleMouseButton = 4; // Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You can still repro this behavior on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
pub const TabItemFlags_NoPushId = 8;                     // Don't call PushID(tab->ID)/PopID() on BeginTabItem()/EndTabItem()
pub const TabItemFlags_NoTooltip = 16;                   // Disable tooltip for the given tab
pub const TabItemFlags_NoReorder = 32;                   // Disable reordering this tab or having another tab cross over this tab
pub const TabItemFlags_Leading = 64;                     // Enforce the tab position to the left of the tab bar (after the tab list popup button)
pub const TabItemFlags_Trailing = 128;                   // Enforce the tab position to the right of the tab bar (before the scrolling buttons)

// Flags for ImGui::BeginTable()
// - Important! Sizing policies have complex and subtle side effects, much more so than you would expect.
//   Read comments/demos carefully + experiment with live demos to get acquainted with them.
// - The DEFAULT sizing policies are:
//    - Default to ImGuiTableFlags_SizingFixedFit    if ScrollX is on, or if host window has ImGuiWindowFlags_AlwaysAutoResize.
//    - Default to ImGuiTableFlags_SizingStretchSame if ScrollX is off.
// - When ScrollX is off:
//    - Table defaults to ImGuiTableFlags_SizingStretchSame -> all Columns defaults to ImGuiTableColumnFlags_WidthStretch with same weight.
//    - Columns sizing policy allowed: Stretch (default), Fixed/Auto.
//    - Fixed Columns (if any) will generally obtain their requested width (unless the table cannot fit them all).
//    - Stretch Columns will share the remaining width according to their respective weight.
//    - Mixed Fixed/Stretch columns is possible but has various side-effects on resizing behaviors.
//      The typical use of mixing sizing policies is: any number of LEADING Fixed columns, followed by one or two TRAILING Stretch columns.
//      (this is because the visible order of columns have subtle but necessary effects on how they react to manual resizing).
// - When ScrollX is on:
//    - Table defaults to ImGuiTableFlags_SizingFixedFit -> all Columns defaults to ImGuiTableColumnFlags_WidthFixed
//    - Columns sizing policy allowed: Fixed/Auto mostly.
//    - Fixed Columns can be enlarged as needed. Table will show a horizontal scrollbar if needed.
//    - When using auto-resizing (non-resizable) fixed columns, querying the content width to use item right-alignment e.g. SetNextItemWidth(-FLT_MIN) doesn't make sense, would create a feedback loop.
//    - Using Stretch columns OFTEN DOES NOT MAKE SENSE if ScrollX is on, UNLESS you have specified a value for 'inner_width' in BeginTable().
//      If you specify a value for 'inner_width' then effectively the scrolling space is known and Stretch or mixed Fixed/Stretch columns become meaningful again.
// - Read on documentation at the top of imgui_tables.cpp for details.
// Features
pub const TableFlags_None = 0;
pub const TableFlags_Resizable = 1;                     // Enable resizing columns.
pub const TableFlags_Reorderable = 2;                   // Enable reordering columns in header row (need calling TableSetupColumn() + TableHeadersRow() to display headers)
pub const TableFlags_Hideable = 4;                      // Enable hiding/disabling columns in context menu.
pub const TableFlags_Sortable = 8;                      // Enable sorting. Call TableGetSortSpecs() to obtain sort specs. Also see ImGuiTableFlags_SortMulti and ImGuiTableFlags_SortTristate.
pub const TableFlags_NoSavedSettings = 16;              // Disable persisting columns order, width and sort settings in the .ini file.
pub const TableFlags_ContextMenuInBody = 32;            // Right-click on columns body/contents will display table context menu. By default it is available in TableHeadersRow().
// Decorations
pub const TableFlags_RowBg = 64;                        // Set each RowBg color with ImGuiCol_TableRowBg or ImGuiCol_TableRowBgAlt (equivalent of calling TableSetBgColor with ImGuiTableBgFlags_RowBg0 on each row manually)
pub const TableFlags_BordersInnerH = 128;               // Draw horizontal borders between rows.
pub const TableFlags_BordersOuterH = 256;               // Draw horizontal borders at the top and bottom.
pub const TableFlags_BordersInnerV = 512;               // Draw vertical borders between columns.
pub const TableFlags_BordersOuterV = 1024;              // Draw vertical borders on the left and right sides.
pub const TableFlags_BordersH = 384;                    // Draw horizontal borders.
pub const TableFlags_BordersV = 1536;                   // Draw vertical borders.
pub const TableFlags_BordersInner = 640;                // Draw inner borders.
pub const TableFlags_BordersOuter = 1280;               // Draw outer borders.
pub const TableFlags_Borders = 1920;                    // Draw all borders.
pub const TableFlags_NoBordersInBody = 2048;            // [ALPHA] Disable vertical borders in columns Body (borders will always appear in Headers). -> May move to style
pub const TableFlags_NoBordersInBodyUntilResize = 4096; // [ALPHA] Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers). -> May move to style
// Sizing Policy (read above for defaults)
pub const TableFlags_SizingFixedFit = 8192;             // Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching contents width.
pub const TableFlags_SizingFixedSame = 16384;           // Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching the maximum contents width of all columns. Implicitly enable ImGuiTableFlags_NoKeepColumnsVisible.
pub const TableFlags_SizingStretchProp = 24576;         // Columns default to _WidthStretch with default weights proportional to each columns contents widths.
pub const TableFlags_SizingStretchSame = 32768;         // Columns default to _WidthStretch with default weights all equal, unless overridden by TableSetupColumn().
// Sizing Extra Options
pub const TableFlags_NoHostExtendX = 65536;             // Make outer width auto-fit to columns, overriding outer_size.x value. Only available when ScrollX/ScrollY are disabled and Stretch columns are not used.
pub const TableFlags_NoHostExtendY = 131072;            // Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit). Only available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.
pub const TableFlags_NoKeepColumnsVisible = 262144;     // Disable keeping column always minimally visible when ScrollX is off and table gets too small. Not recommended if columns are resizable.
pub const TableFlags_PreciseWidths = 524288;            // Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.
// Clipping
pub const TableFlags_NoClip = 1048576;                  // Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with TableSetupScrollFreeze().
// Padding
pub const TableFlags_PadOuterX = 2097152;               // Default if BordersOuterV is on. Enable outermost padding. Generally desirable if you have headers.
pub const TableFlags_NoPadOuterX = 4194304;             // Default if BordersOuterV is off. Disable outermost padding.
pub const TableFlags_NoPadInnerX = 8388608;             // Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off).
// Scrolling
pub const TableFlags_ScrollX = 16777216;                // Enable horizontal scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size. Changes default sizing policy. Because this creates a child window, ScrollY is currently generally recommended when using ScrollX.
pub const TableFlags_ScrollY = 33554432;                // Enable vertical scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size.
// Sorting
pub const TableFlags_SortMulti = 67108864;              // Hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).
pub const TableFlags_SortTristate = 134217728;          // Allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).
// [Internal] Combinations and masks
pub const TableFlags_SizingMask_ = 57344;

// Flags for ImGui::TableSetupColumn()
// Input configuration flags
pub const TableColumnFlags_None = 0;
pub const TableColumnFlags_Disabled = 1;                 // Overriding/master disable flag: hide column, won't show in context menu (unlike calling TableSetColumnEnabled() which manipulates the user accessible state)
pub const TableColumnFlags_DefaultHide = 2;              // Default as a hidden/disabled column.
pub const TableColumnFlags_DefaultSort = 4;              // Default as a sorting column.
pub const TableColumnFlags_WidthStretch = 8;             // Column will stretch. Preferable with horizontal scrolling disabled (default if table sizing policy is _SizingStretchSame or _SizingStretchProp).
pub const TableColumnFlags_WidthFixed = 16;              // Column will not stretch. Preferable with horizontal scrolling enabled (default if table sizing policy is _SizingFixedFit and table is resizable).
pub const TableColumnFlags_NoResize = 32;                // Disable manual resizing.
pub const TableColumnFlags_NoReorder = 64;               // Disable manual reordering this column, this will also prevent other columns from crossing over this column.
pub const TableColumnFlags_NoHide = 128;                 // Disable ability to hide/disable this column.
pub const TableColumnFlags_NoClip = 256;                 // Disable clipping for this column (all NoClip columns will render in a same draw command).
pub const TableColumnFlags_NoSort = 512;                 // Disable ability to sort on this field (even if ImGuiTableFlags_Sortable is set on the table).
pub const TableColumnFlags_NoSortAscending = 1024;       // Disable ability to sort in the ascending direction.
pub const TableColumnFlags_NoSortDescending = 2048;      // Disable ability to sort in the descending direction.
pub const TableColumnFlags_NoHeaderLabel = 4096;         // TableHeadersRow() will not submit label for this column. Convenient for some small columns. Name will still appear in context menu.
pub const TableColumnFlags_NoHeaderWidth = 8192;         // Disable header text width contribution to automatic column width.
pub const TableColumnFlags_PreferSortAscending = 16384;  // Make the initial sort direction Ascending when first sorting on this column (default).
pub const TableColumnFlags_PreferSortDescending = 32768; // Make the initial sort direction Descending when first sorting on this column.
pub const TableColumnFlags_IndentEnable = 65536;         // Use current Indent value when entering cell (default for column 0).
pub const TableColumnFlags_IndentDisable = 131072;       // Ignore current Indent value when entering cell (default for columns > 0). Indentation changes _within_ the cell will still be honored.
// Output status flags, read-only via TableGetColumnFlags()
pub const TableColumnFlags_IsEnabled = 16777216;         // Status: is enabled == not hidden by user/api (referred to as "Hide" in _DefaultHide and _NoHide) flags.
pub const TableColumnFlags_IsVisible = 33554432;         // Status: is visible == is enabled AND not clipped by scrolling.
pub const TableColumnFlags_IsSorted = 67108864;          // Status: is currently part of the sort specs
pub const TableColumnFlags_IsHovered = 134217728;        // Status: is hovered by mouse
// [Internal] Combinations and masks
pub const TableColumnFlags_WidthMask_ = 24;
pub const TableColumnFlags_IndentMask_ = 196608;
pub const TableColumnFlags_StatusMask_ = 251658240;
pub const TableColumnFlags_NoDirectResize_ = 1073741824; // [Internal] Disable user resizing this column directly (it may however we resized indirectly from its left edge)

// Flags for ImGui::TableNextRow()
pub const TableRowFlags_None = 0;
pub const TableRowFlags_Headers = 1; // Identify header row (set default background color + width of its contents accounted differently for auto column width)

// Enum for ImGui::TableSetBgColor()
// Background colors are rendering in 3 layers:
//  - Layer 0: draw with RowBg0 color if set, otherwise draw with ColumnBg0 if set.
//  - Layer 1: draw with RowBg1 color if set, otherwise draw with ColumnBg1 if set.
//  - Layer 2: draw with CellBg color if set.
// The purpose of the two row/columns layers is to let you decide if a background color change should override or blend with the existing color.
// When using ImGuiTableFlags_RowBg on the table, each row has the RowBg0 color automatically set for odd/even rows.
// If you set the color of RowBg0 target, your color will override the existing RowBg0 color.
// If you set the color of RowBg1 or ColumnBg1 target, your color will blend over the RowBg0 color.
pub const TableBgTarget_None = 0;
pub const TableBgTarget_RowBg0 = 1; // Set row background color 0 (generally used for background, automatically set when ImGuiTableFlags_RowBg is used)
pub const TableBgTarget_RowBg1 = 2; // Set row background color 1 (generally used for selection marking)
pub const TableBgTarget_CellBg = 3; // Set cell background color (top-most color)

// Flags for ImGui::IsWindowFocused()
pub const FocusedFlags_None = 0;
pub const FocusedFlags_ChildWindows = 1;        // Return true if any children of the window is focused
pub const FocusedFlags_RootWindow = 2;          // Test from root window (top most parent of the current hierarchy)
pub const FocusedFlags_AnyWindow = 4;           // Return true if any window is focused. Important: If you are trying to tell how to dispatch your low-level inputs, do NOT use this. Use 'io.WantCaptureMouse' instead! Please read the FAQ!
pub const FocusedFlags_NoPopupHierarchy = 8;    // Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
pub const FocusedFlags_DockHierarchy = 16;      // Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
pub const FocusedFlags_RootAndChildWindows = 3;

// Flags for ImGui::IsItemHovered(), ImGui::IsWindowHovered()
// Note: if you are trying to check whether your mouse should be dispatched to Dear ImGui or to your app, you should use 'io.WantCaptureMouse' instead! Please read the FAQ!
// Note: windows with the ImGuiWindowFlags_NoInputs flag are ignored by IsWindowHovered() calls.
pub const HoveredFlags_None = 0;                           // Return true if directly over the item/window, not obstructed by another window, not obstructed by an active popup or modal blocking inputs under them.
pub const HoveredFlags_ChildWindows = 1;                   // IsWindowHovered() only: Return true if any children of the window is hovered
pub const HoveredFlags_RootWindow = 2;                     // IsWindowHovered() only: Test from root window (top most parent of the current hierarchy)
pub const HoveredFlags_AnyWindow = 4;                      // IsWindowHovered() only: Return true if any window is hovered
pub const HoveredFlags_NoPopupHierarchy = 8;               // IsWindowHovered() only: Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
pub const HoveredFlags_DockHierarchy = 16;                 // IsWindowHovered() only: Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
pub const HoveredFlags_AllowWhenBlockedByPopup = 32;       // Return true even if a popup window is normally blocking access to this item/window
//ImGuiHoveredFlags_AllowWhenBlockedByModal     = 1 << 6,   // Return true even if a modal popup window is normally blocking access to this item/window. FIXME-TODO: Unavailable yet.
pub const HoveredFlags_AllowWhenBlockedByActiveItem = 128; // Return true even if an active item is blocking access to this item/window. Useful for Drag and Drop patterns.
pub const HoveredFlags_AllowWhenOverlappedByItem = 256;    // IsItemHovered() only: Return true even if the item uses AllowOverlap mode and is overlapped by another hoverable item.
pub const HoveredFlags_AllowWhenOverlappedByWindow = 512;  // IsItemHovered() only: Return true even if the position is obstructed or overlapped by another window.
pub const HoveredFlags_AllowWhenDisabled = 1024;           // IsItemHovered() only: Return true even if the item is disabled
pub const HoveredFlags_NoNavOverride = 2048;               // IsItemHovered() only: Disable using gamepad/keyboard navigation state when active, always query mouse
pub const HoveredFlags_AllowWhenOverlapped = 768;
pub const HoveredFlags_RectOnly = 928;
pub const HoveredFlags_RootAndChildWindows = 3;
// Tooltips mode
// - typically used in IsItemHovered() + SetTooltip() sequence.
// - this is a shortcut to pull flags from 'style.HoverFlagsForTooltipMouse' or 'style.HoverFlagsForTooltipNav' where you can reconfigure desired behavior.
//   e.g. 'TooltipHoveredFlagsForMouse' defaults to 'ImGuiHoveredFlags_Stationary | ImGuiHoveredFlags_DelayShort'.
// - for frequently actioned or hovered items providing a tooltip, you want may to use ImGuiHoveredFlags_ForTooltip (stationary + delay) so the tooltip doesn't show too often.
// - for items which main purpose is to be hovered, or items with low affordance, or in less consistent apps, prefer no delay or shorter delay.
pub const HoveredFlags_ForTooltip = 4096;                  // Shortcut for standard flags when using IsItemHovered() + SetTooltip() sequence.
// (Advanced) Mouse Hovering delays.
// - generally you can use ImGuiHoveredFlags_ForTooltip to use application-standardized flags.
// - use those if you need specific overrides.
pub const HoveredFlags_Stationary = 8192;                  // Require mouse to be stationary for style.HoverStationaryDelay (~0.15 sec) _at least one time_. After this, can move on same item/window. Using the stationary test tends to reduces the need for a long delay.
pub const HoveredFlags_DelayNone = 16384;                  // IsItemHovered() only: Return true immediately (default). As this is the default you generally ignore this.
pub const HoveredFlags_DelayShort = 32768;                 // IsItemHovered() only: Return true after style.HoverDelayShort elapsed (~0.15 sec) (shared between items) + requires mouse to be stationary for style.HoverStationaryDelay (once per item).
pub const HoveredFlags_DelayNormal = 65536;                // IsItemHovered() only: Return true after style.HoverDelayNormal elapsed (~0.40 sec) (shared between items) + requires mouse to be stationary for style.HoverStationaryDelay (once per item).
pub const HoveredFlags_NoSharedDelay = 131072;             // IsItemHovered() only: Disable shared delay system where moving from one item to the next keeps the previous timer for a short time (standard for tooltips with long delays)

// Flags for ImGui::DockSpace(), shared/inherited by child nodes.
// (Some flags can be applied to individual nodes directly)
// FIXME-DOCK: Also see ImGuiDockNodeFlagsPrivate_ which may involve using the WIP and internal DockBuilder api.
pub const DockNodeFlags_None = 0;
pub const DockNodeFlags_KeepAliveOnly = 1;          // Shared       // Don't display the dockspace node but keep it alive. Windows docked into this dockspace node won't be undocked.
//ImGuiDockNodeFlags_NoCentralNode              = 1 << 1,   // Shared       // Disable Central Node (the node which can stay empty)
pub const DockNodeFlags_NoDockingInCentralNode = 4; // Shared       // Disable docking inside the Central Node, which will be always kept empty.
pub const DockNodeFlags_PassthruCentralNode = 8;    // Shared       // Enable passthru dockspace: 1) DockSpace() will render a ImGuiCol_WindowBg background covering everything excepted the Central Node when empty. Meaning the host window should probably use SetNextWindowBgAlpha(0.0f) prior to Begin() when using this. 2) When Central Node is empty: let inputs pass-through + won't display a DockingEmptyBg background. See demo for details.
pub const DockNodeFlags_NoSplit = 16;               // Shared/Local // Disable splitting the node into smaller nodes. Useful e.g. when embedding dockspaces into a main root one (the root one may have splitting disabled to reduce confusion). Note: when turned off, existing splits will be preserved.
pub const DockNodeFlags_NoResize = 32;              // Shared/Local // Disable resizing node using the splitter/separators. Useful with programmatically setup dockspaces.
pub const DockNodeFlags_AutoHideTabBar = 64;        // Shared/Local // Tab bar will automatically hide when there is a single window in the dock node.

// Flags for ImGui::BeginDragDropSource(), ImGui::AcceptDragDropPayload()
pub const DragDropFlags_None = 0;
// BeginDragDropSource() flags
pub const DragDropFlags_SourceNoPreviewTooltip = 1;     // Disable preview tooltip. By default, a successful call to BeginDragDropSource opens a tooltip so you can display a preview or description of the source contents. This flag disables this behavior.
pub const DragDropFlags_SourceNoDisableHover = 2;       // By default, when dragging we clear data so that IsItemHovered() will return false, to avoid subsequent user code submitting tooltips. This flag disables this behavior so you can still call IsItemHovered() on the source item.
pub const DragDropFlags_SourceNoHoldToOpenOthers = 4;   // Disable the behavior that allows to open tree nodes and collapsing header by holding over them while dragging a source item.
pub const DragDropFlags_SourceAllowNullID = 8;          // Allow items such as Text(), Image() that have no unique identifier to be used as drag source, by manufacturing a temporary identifier based on their window-relative position. This is extremely unusual within the dear imgui ecosystem and so we made it explicit.
pub const DragDropFlags_SourceExtern = 16;              // External source (from outside of dear imgui), won't attempt to read current item/window info. Will always return true. Only one Extern source can be active simultaneously.
pub const DragDropFlags_SourceAutoExpirePayload = 32;   // Automatically expire the payload if the source cease to be submitted (otherwise payloads are persisting while being dragged)
// AcceptDragDropPayload() flags
pub const DragDropFlags_AcceptBeforeDelivery = 1024;    // AcceptDragDropPayload() will returns true even before the mouse button is released. You can then call IsDelivery() to test if the payload needs to be delivered.
pub const DragDropFlags_AcceptNoDrawDefaultRect = 2048; // Do not draw the default highlight rectangle when hovering over target.
pub const DragDropFlags_AcceptNoPreviewTooltip = 4096;  // Request hiding the BeginDragDropSource tooltip from the BeginDragDropTarget site.
pub const DragDropFlags_AcceptPeekOnly = 3072;          // For peeking ahead and inspecting the payload before delivery.

// A primary data type
pub const DataType_S8 = 0;     // signed char / char (with sensible compilers)
pub const DataType_U8 = 1;     // unsigned char
pub const DataType_S16 = 2;    // short
pub const DataType_U16 = 3;    // unsigned short
pub const DataType_S32 = 4;    // int
pub const DataType_U32 = 5;    // unsigned int
pub const DataType_S64 = 6;    // long long / __int64
pub const DataType_U64 = 7;    // unsigned long long / unsigned __int64
pub const DataType_Float = 8;  // float
pub const DataType_Double = 9; // double
pub const DataType_COUNT = 10;

// A cardinal direction
pub const Dir_None = -1;
pub const Dir_Left = 0;
pub const Dir_Right = 1;
pub const Dir_Up = 2;
pub const Dir_Down = 3;
pub const Dir_COUNT = 4;

// A sorting direction
pub const SortDirection_None = 0;
pub const SortDirection_Ascending = 1;  // Ascending = 0->9, A->Z etc.
pub const SortDirection_Descending = 2; // Descending = 9->0, Z->A etc.

// A key identifier (ImGuiKey_XXX or ImGuiMod_XXX value): can represent Keyboard, Mouse and Gamepad values.
// All our named keys are >= 512. Keys value 0 to 511 are left unused as legacy native/opaque key values (< 1.87).
// Since >= 1.89 we increased typing (went from int to enum), some legacy code may need a cast to ImGuiKey.
// Read details about the 1.87 and 1.89 transition : https://github.com/ocornut/imgui/issues/4921
// Note that "Keys" related to physical keys and are not the same concept as input "Characters", the later are submitted via io.AddInputCharacter().
// Keyboard
pub const Key_None = 0;
pub const Key_Tab = 512;                 // == ImGuiKey_NamedKey_BEGIN
pub const Key_LeftArrow = 513;
pub const Key_RightArrow = 514;
pub const Key_UpArrow = 515;
pub const Key_DownArrow = 516;
pub const Key_PageUp = 517;
pub const Key_PageDown = 518;
pub const Key_Home = 519;
pub const Key_End = 520;
pub const Key_Insert = 521;
pub const Key_Delete = 522;
pub const Key_Backspace = 523;
pub const Key_Space = 524;
pub const Key_Enter = 525;
pub const Key_Escape = 526;
pub const Key_LeftCtrl = 527;
pub const Key_LeftShift = 528;
pub const Key_LeftAlt = 529;
pub const Key_LeftSuper = 530;
pub const Key_RightCtrl = 531;
pub const Key_RightShift = 532;
pub const Key_RightAlt = 533;
pub const Key_RightSuper = 534;
pub const Key_Menu = 535;
pub const Key_0 = 536;
pub const Key_1 = 537;
pub const Key_2 = 538;
pub const Key_3 = 539;
pub const Key_4 = 540;
pub const Key_5 = 541;
pub const Key_6 = 542;
pub const Key_7 = 543;
pub const Key_8 = 544;
pub const Key_9 = 545;
pub const Key_A = 546;
pub const Key_B = 547;
pub const Key_C = 548;
pub const Key_D = 549;
pub const Key_E = 550;
pub const Key_F = 551;
pub const Key_G = 552;
pub const Key_H = 553;
pub const Key_I = 554;
pub const Key_J = 555;
pub const Key_K = 556;
pub const Key_L = 557;
pub const Key_M = 558;
pub const Key_N = 559;
pub const Key_O = 560;
pub const Key_P = 561;
pub const Key_Q = 562;
pub const Key_R = 563;
pub const Key_S = 564;
pub const Key_T = 565;
pub const Key_U = 566;
pub const Key_V = 567;
pub const Key_W = 568;
pub const Key_X = 569;
pub const Key_Y = 570;
pub const Key_Z = 571;
pub const Key_F1 = 572;
pub const Key_F2 = 573;
pub const Key_F3 = 574;
pub const Key_F4 = 575;
pub const Key_F5 = 576;
pub const Key_F6 = 577;
pub const Key_F7 = 578;
pub const Key_F8 = 579;
pub const Key_F9 = 580;
pub const Key_F10 = 581;
pub const Key_F11 = 582;
pub const Key_F12 = 583;
pub const Key_Apostrophe = 584;          // '
pub const Key_Comma = 585;               // ,
pub const Key_Minus = 586;               // -
pub const Key_Period = 587;              // .
pub const Key_Slash = 588;               // /
pub const Key_Semicolon = 589;           // ;
pub const Key_Equal = 590;               // =
pub const Key_LeftBracket = 591;         // [
pub const Key_Backslash = 592;           // \ (this text inhibit multiline comment caused by backslash)
pub const Key_RightBracket = 593;        // ]
pub const Key_GraveAccent = 594;         // `
pub const Key_CapsLock = 595;
pub const Key_ScrollLock = 596;
pub const Key_NumLock = 597;
pub const Key_PrintScreen = 598;
pub const Key_Pause = 599;
pub const Key_Keypad0 = 600;
pub const Key_Keypad1 = 601;
pub const Key_Keypad2 = 602;
pub const Key_Keypad3 = 603;
pub const Key_Keypad4 = 604;
pub const Key_Keypad5 = 605;
pub const Key_Keypad6 = 606;
pub const Key_Keypad7 = 607;
pub const Key_Keypad8 = 608;
pub const Key_Keypad9 = 609;
pub const Key_KeypadDecimal = 610;
pub const Key_KeypadDivide = 611;
pub const Key_KeypadMultiply = 612;
pub const Key_KeypadSubtract = 613;
pub const Key_KeypadAdd = 614;
pub const Key_KeypadEnter = 615;
pub const Key_KeypadEqual = 616;
// Gamepad (some of those are analog values, 0.0f to 1.0f)                          // NAVIGATION ACTION
// (download controller mapping PNG/PSD at http://dearimgui.com/controls_sheets)
pub const Key_GamepadStart = 617;        // Menu (Xbox)      + (Switch)   Start/Options (PS)
pub const Key_GamepadBack = 618;         // View (Xbox)      - (Switch)   Share (PS)
pub const Key_GamepadFaceLeft = 619;     // X (Xbox)         Y (Switch)   Square (PS)        // Tap: Toggle Menu. Hold: Windowing mode (Focus/Move/Resize windows)
pub const Key_GamepadFaceRight = 620;    // B (Xbox)         A (Switch)   Circle (PS)        // Cancel / Close / Exit
pub const Key_GamepadFaceUp = 621;       // Y (Xbox)         X (Switch)   Triangle (PS)      // Text Input / On-screen Keyboard
pub const Key_GamepadFaceDown = 622;     // A (Xbox)         B (Switch)   Cross (PS)         // Activate / Open / Toggle / Tweak
pub const Key_GamepadDpadLeft = 623;     // D-pad Left                                       // Move / Tweak / Resize Window (in Windowing mode)
pub const Key_GamepadDpadRight = 624;    // D-pad Right                                      // Move / Tweak / Resize Window (in Windowing mode)
pub const Key_GamepadDpadUp = 625;       // D-pad Up                                         // Move / Tweak / Resize Window (in Windowing mode)
pub const Key_GamepadDpadDown = 626;     // D-pad Down                                       // Move / Tweak / Resize Window (in Windowing mode)
pub const Key_GamepadL1 = 627;           // L Bumper (Xbox)  L (Switch)   L1 (PS)            // Tweak Slower / Focus Previous (in Windowing mode)
pub const Key_GamepadR1 = 628;           // R Bumper (Xbox)  R (Switch)   R1 (PS)            // Tweak Faster / Focus Next (in Windowing mode)
pub const Key_GamepadL2 = 629;           // L Trig. (Xbox)   ZL (Switch)  L2 (PS) [Analog]
pub const Key_GamepadR2 = 630;           // R Trig. (Xbox)   ZR (Switch)  R2 (PS) [Analog]
pub const Key_GamepadL3 = 631;           // L Stick (Xbox)   L3 (Switch)  L3 (PS)
pub const Key_GamepadR3 = 632;           // R Stick (Xbox)   R3 (Switch)  R3 (PS)
pub const Key_GamepadLStickLeft = 633;   // [Analog]                                         // Move Window (in Windowing mode)
pub const Key_GamepadLStickRight = 634;  // [Analog]                                         // Move Window (in Windowing mode)
pub const Key_GamepadLStickUp = 635;     // [Analog]                                         // Move Window (in Windowing mode)
pub const Key_GamepadLStickDown = 636;   // [Analog]                                         // Move Window (in Windowing mode)
pub const Key_GamepadRStickLeft = 637;   // [Analog]
pub const Key_GamepadRStickRight = 638;  // [Analog]
pub const Key_GamepadRStickUp = 639;     // [Analog]
pub const Key_GamepadRStickDown = 640;   // [Analog]
// Aliases: Mouse Buttons (auto-submitted from AddMouseButtonEvent() calls)
// - This is mirroring the data also written to io.MouseDown[], io.MouseWheel, in a format allowing them to be accessed via standard key API.
pub const Key_MouseLeft = 641;
pub const Key_MouseRight = 642;
pub const Key_MouseMiddle = 643;
pub const Key_MouseX1 = 644;
pub const Key_MouseX2 = 645;
pub const Key_MouseWheelX = 646;
pub const Key_MouseWheelY = 647;
// [Internal] Reserved for mod storage
pub const Key_ReservedForModCtrl = 648;
pub const Key_ReservedForModShift = 649;
pub const Key_ReservedForModAlt = 650;
pub const Key_ReservedForModSuper = 651;
pub const Key_COUNT = 652;
// Keyboard Modifiers (explicitly submitted by backend via AddKeyEvent() calls)
// - This is mirroring the data also written to io.KeyCtrl, io.KeyShift, io.KeyAlt, io.KeySuper, in a format allowing
//   them to be accessed via standard key API, allowing calls such as IsKeyPressed(), IsKeyReleased(), querying duration etc.
// - Code polling every key (e.g. an interface to detect a key press for input mapping) might want to ignore those
//   and prefer using the real keys (e.g. ImGuiKey_LeftCtrl, ImGuiKey_RightCtrl instead of ImGuiMod_Ctrl).
// - In theory the value of keyboard modifiers should be roughly equivalent to a logical or of the equivalent left/right keys.
//   In practice: it's complicated; mods are often provided from different sources. Keyboard layout, IME, sticky keys and
//   backends tend to interfere and break that equivalence. The safer decision is to relay that ambiguity down to the end-user...
pub const Mod_None = 0;
pub const Mod_Ctrl = 4096;               // Ctrl
pub const Mod_Shift = 8192;              // Shift
pub const Mod_Alt = 16384;               // Option/Menu
pub const Mod_Super = 32768;             // Cmd/Super/Windows
pub const Mod_Shortcut = 2048;           // Alias for Ctrl (non-macOS) _or_ Super (macOS).
pub const Mod_Mask_ = 63488;             // 5-bits
// [Internal] Prior to 1.87 we required user to fill io.KeysDown[512] using their own native index + the io.KeyMap[] array.
// We are ditching this method but keeping a legacy path for user code doing e.g. IsKeyPressed(MY_NATIVE_KEY_CODE)
// If you need to iterate all keys (for e.g. an input mapper) you may use ImGuiKey_NamedKey_BEGIN..ImGuiKey_NamedKey_END.
pub const Key_NamedKey_BEGIN = 512;
pub const Key_NamedKey_END = 652;
pub const Key_NamedKey_COUNT = 140;
pub const Key_KeysData_SIZE = 140;       // Size of KeysData[]: only hold named keys
pub const Key_KeysData_OFFSET = 512;     // Accesses to io.KeysData[] must use (key - ImGuiKey_KeysData_OFFSET) index.

// Configuration flags stored in io.ConfigFlags. Set by user/application.
pub const ConfigFlags_None = 0;
pub const ConfigFlags_NavEnableKeyboard = 1;           // Master keyboard navigation enable flag. Enable full Tabbing + directional arrows + space/enter to activate.
pub const ConfigFlags_NavEnableGamepad = 2;            // Master gamepad navigation enable flag. Backend also needs to set ImGuiBackendFlags_HasGamepad.
pub const ConfigFlags_NavEnableSetMousePos = 4;        // Instruct navigation to move the mouse cursor. May be useful on TV/console systems where moving a virtual mouse is awkward. Will update io.MousePos and set io.WantSetMousePos=true. If enabled you MUST honor io.WantSetMousePos requests in your backend, otherwise ImGui will react as if the mouse is jumping around back and forth.
pub const ConfigFlags_NavNoCaptureKeyboard = 8;        // Instruct navigation to not set the io.WantCaptureKeyboard flag when io.NavActive is set.
pub const ConfigFlags_NoMouse = 16;                    // Instruct imgui to clear mouse position/buttons in NewFrame(). This allows ignoring the mouse information set by the backend.
pub const ConfigFlags_NoMouseCursorChange = 32;        // Instruct backend to not alter mouse cursor shape and visibility. Use if the backend cursor changes are interfering with yours and you don't want to use SetMouseCursor() to change mouse cursor. You may want to honor requests from imgui by reading GetMouseCursor() yourself instead.
// [BETA] Docking
pub const ConfigFlags_DockingEnable = 64;              // Docking enable flags.
// [BETA] Viewports
// When using viewports it is recommended that your default value for ImGuiCol_WindowBg is opaque (Alpha=1.0) so transition to a viewport won't be noticeable.
pub const ConfigFlags_ViewportsEnable = 1024;          // Viewport enable flags (require both ImGuiBackendFlags_PlatformHasViewports + ImGuiBackendFlags_RendererHasViewports set by the respective backends)
pub const ConfigFlags_DpiEnableScaleViewports = 16384; // [BETA: Don't use] FIXME-DPI: Reposition and resize imgui windows when the DpiScale of a viewport changed (mostly useful for the main viewport hosting other window). Note that resizing the main window itself is up to your application.
pub const ConfigFlags_DpiEnableScaleFonts = 32768;     // [BETA: Don't use] FIXME-DPI: Request bitmap-scaled fonts to match DpiScale. This is a very low-quality workaround. The correct way to handle DPI is _currently_ to replace the atlas and/or fonts in the Platform_OnChangedViewport callback, but this is all early work in progress.
// User storage (to allow your backend/engine to communicate to code that may be shared between multiple projects. Those flags are NOT used by core Dear ImGui)
pub const ConfigFlags_IsSRGB = 1048576;                // Application is SRGB-aware.
pub const ConfigFlags_IsTouchScreen = 2097152;         // Application is using a touch screen instead of a mouse.

// Backend capabilities flags stored in io.BackendFlags. Set by imgui_impl_xxx or custom backend.
pub const BackendFlags_None = 0;
pub const BackendFlags_HasGamepad = 1;                 // Backend Platform supports gamepad and currently has one connected.
pub const BackendFlags_HasMouseCursors = 2;            // Backend Platform supports honoring GetMouseCursor() value to change the OS cursor shape.
pub const BackendFlags_HasSetMousePos = 4;             // Backend Platform supports io.WantSetMousePos requests to reposition the OS mouse position (only used if ImGuiConfigFlags_NavEnableSetMousePos is set).
pub const BackendFlags_RendererHasVtxOffset = 8;       // Backend Renderer supports ImDrawCmd::VtxOffset. This enables output of large meshes (64K+ vertices) while still using 16-bit indices.
// [BETA] Viewports
pub const BackendFlags_PlatformHasViewports = 1024;    // Backend Platform supports multiple viewports.
pub const BackendFlags_HasMouseHoveredViewport = 2048; // Backend Platform supports calling io.AddMouseViewportEvent() with the viewport under the mouse. IF POSSIBLE, ignore viewports with the ImGuiViewportFlags_NoInputs flag (Win32 backend, GLFW 3.30+ backend can do this, SDL backend cannot). If this cannot be done, Dear ImGui needs to use a flawed heuristic to find the viewport under.
pub const BackendFlags_RendererHasViewports = 4096;    // Backend Renderer supports multiple viewports.

// Enumeration for PushStyleColor() / PopStyleColor()
pub const Col_Text = 0;
pub const Col_TextDisabled = 1;
pub const Col_WindowBg = 2;               // Background of normal windows
pub const Col_ChildBg = 3;                // Background of child windows
pub const Col_PopupBg = 4;                // Background of popups, menus, tooltips windows
pub const Col_Border = 5;
pub const Col_BorderShadow = 6;
pub const Col_FrameBg = 7;                // Background of checkbox, radio button, plot, slider, text input
pub const Col_FrameBgHovered = 8;
pub const Col_FrameBgActive = 9;
pub const Col_TitleBg = 10;
pub const Col_TitleBgActive = 11;
pub const Col_TitleBgCollapsed = 12;
pub const Col_MenuBarBg = 13;
pub const Col_ScrollbarBg = 14;
pub const Col_ScrollbarGrab = 15;
pub const Col_ScrollbarGrabHovered = 16;
pub const Col_ScrollbarGrabActive = 17;
pub const Col_CheckMark = 18;
pub const Col_SliderGrab = 19;
pub const Col_SliderGrabActive = 20;
pub const Col_Button = 21;
pub const Col_ButtonHovered = 22;
pub const Col_ButtonActive = 23;
pub const Col_Header = 24;                // Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
pub const Col_HeaderHovered = 25;
pub const Col_HeaderActive = 26;
pub const Col_Separator = 27;
pub const Col_SeparatorHovered = 28;
pub const Col_SeparatorActive = 29;
pub const Col_ResizeGrip = 30;            // Resize grip in lower-right and lower-left corners of windows.
pub const Col_ResizeGripHovered = 31;
pub const Col_ResizeGripActive = 32;
pub const Col_Tab = 33;                   // TabItem in a TabBar
pub const Col_TabHovered = 34;
pub const Col_TabActive = 35;
pub const Col_TabUnfocused = 36;
pub const Col_TabUnfocusedActive = 37;
pub const Col_DockingPreview = 38;        // Preview overlay color when about to docking something
pub const Col_DockingEmptyBg = 39;        // Background color for empty node (e.g. CentralNode with no window docked into it)
pub const Col_PlotLines = 40;
pub const Col_PlotLinesHovered = 41;
pub const Col_PlotHistogram = 42;
pub const Col_PlotHistogramHovered = 43;
pub const Col_TableHeaderBg = 44;         // Table header background
pub const Col_TableBorderStrong = 45;     // Table outer and header borders (prefer using Alpha=1.0 here)
pub const Col_TableBorderLight = 46;      // Table inner borders (prefer using Alpha=1.0 here)
pub const Col_TableRowBg = 47;            // Table row background (even rows)
pub const Col_TableRowBgAlt = 48;         // Table row background (odd rows)
pub const Col_TextSelectedBg = 49;
pub const Col_DragDropTarget = 50;        // Rectangle highlighting a drop target
pub const Col_NavHighlight = 51;          // Gamepad/keyboard: current highlighted item
pub const Col_NavWindowingHighlight = 52; // Highlight window when using CTRL+TAB
pub const Col_NavWindowingDimBg = 53;     // Darken/colorize entire screen behind the CTRL+TAB window list, when active
pub const Col_ModalWindowDimBg = 54;      // Darken/colorize entire screen behind a modal window, when one is active
pub const Col_COUNT = 55;

// Enumeration for PushStyleVar() / PopStyleVar() to temporarily modify the ImGuiStyle structure.
// - The enum only refers to fields of ImGuiStyle which makes sense to be pushed/popped inside UI code.
//   During initialization or between frames, feel free to just poke into ImGuiStyle directly.
// - Tip: Use your programming IDE navigation facilities on the names in the _second column_ below to find the actual members and their description.
//   In Visual Studio IDE: CTRL+comma ("Edit.GoToAll") can follow symbols in comments, whereas CTRL+F12 ("Edit.GoToImplementation") cannot.
//   With Visual Assist installed: ALT+G ("VAssistX.GoToImplementation") can also follow symbols in comments.
// - When changing this enum, you need to update the associated internal table GStyleVarInfo[] accordingly. This is where we link enum values to members offset/type.
// Enum name --------------------- // Member in ImGuiStyle structure (see ImGuiStyle for descriptions)
pub const StyleVar_Alpha = 0;                    // float     Alpha
pub const StyleVar_DisabledAlpha = 1;            // float     DisabledAlpha
pub const StyleVar_WindowPadding = 2;            // ImVec2    WindowPadding
pub const StyleVar_WindowRounding = 3;           // float     WindowRounding
pub const StyleVar_WindowBorderSize = 4;         // float     WindowBorderSize
pub const StyleVar_WindowMinSize = 5;            // ImVec2    WindowMinSize
pub const StyleVar_WindowTitleAlign = 6;         // ImVec2    WindowTitleAlign
pub const StyleVar_ChildRounding = 7;            // float     ChildRounding
pub const StyleVar_ChildBorderSize = 8;          // float     ChildBorderSize
pub const StyleVar_PopupRounding = 9;            // float     PopupRounding
pub const StyleVar_PopupBorderSize = 10;         // float     PopupBorderSize
pub const StyleVar_FramePadding = 11;            // ImVec2    FramePadding
pub const StyleVar_FrameRounding = 12;           // float     FrameRounding
pub const StyleVar_FrameBorderSize = 13;         // float     FrameBorderSize
pub const StyleVar_ItemSpacing = 14;             // ImVec2    ItemSpacing
pub const StyleVar_ItemInnerSpacing = 15;        // ImVec2    ItemInnerSpacing
pub const StyleVar_IndentSpacing = 16;           // float     IndentSpacing
pub const StyleVar_CellPadding = 17;             // ImVec2    CellPadding
pub const StyleVar_ScrollbarSize = 18;           // float     ScrollbarSize
pub const StyleVar_ScrollbarRounding = 19;       // float     ScrollbarRounding
pub const StyleVar_GrabMinSize = 20;             // float     GrabMinSize
pub const StyleVar_GrabRounding = 21;            // float     GrabRounding
pub const StyleVar_TabRounding = 22;             // float     TabRounding
pub const StyleVar_ButtonTextAlign = 23;         // ImVec2    ButtonTextAlign
pub const StyleVar_SelectableTextAlign = 24;     // ImVec2    SelectableTextAlign
pub const StyleVar_SeparatorTextBorderSize = 25; // float  SeparatorTextBorderSize
pub const StyleVar_SeparatorTextAlign = 26;      // ImVec2    SeparatorTextAlign
pub const StyleVar_SeparatorTextPadding = 27;    // ImVec2    SeparatorTextPadding
pub const StyleVar_DockingSeparatorSize = 28;    // float     DockingSeparatorSize
pub const StyleVar_COUNT = 29;

// Flags for InvisibleButton() [extended in imgui_internal.h]
pub const ButtonFlags_None = 0;
pub const ButtonFlags_MouseButtonLeft = 1;     // React on left mouse button (default)
pub const ButtonFlags_MouseButtonRight = 2;    // React on right mouse button
pub const ButtonFlags_MouseButtonMiddle = 4;   // React on center mouse button
// [Internal]
pub const ButtonFlags_MouseButtonMask_ = 7;
pub const ButtonFlags_MouseButtonDefault_ = 1;

// Flags for ColorEdit3() / ColorEdit4() / ColorPicker3() / ColorPicker4() / ColorButton()
pub const ColorEditFlags_None = 0;
pub const ColorEditFlags_NoAlpha = 2;                 //              // ColorEdit, ColorPicker, ColorButton: ignore Alpha component (will only read 3 components from the input pointer).
pub const ColorEditFlags_NoPicker = 4;                //              // ColorEdit: disable picker when clicking on color square.
pub const ColorEditFlags_NoOptions = 8;               //              // ColorEdit: disable toggling options menu when right-clicking on inputs/small preview.
pub const ColorEditFlags_NoSmallPreview = 16;         //              // ColorEdit, ColorPicker: disable color square preview next to the inputs. (e.g. to show only the inputs)
pub const ColorEditFlags_NoInputs = 32;               //              // ColorEdit, ColorPicker: disable inputs sliders/text widgets (e.g. to show only the small preview color square).
pub const ColorEditFlags_NoTooltip = 64;              //              // ColorEdit, ColorPicker, ColorButton: disable tooltip when hovering the preview.
pub const ColorEditFlags_NoLabel = 128;               //              // ColorEdit, ColorPicker: disable display of inline text label (the label is still forwarded to the tooltip and picker).
pub const ColorEditFlags_NoSidePreview = 256;         //              // ColorPicker: disable bigger color preview on right side of the picker, use small color square preview instead.
pub const ColorEditFlags_NoDragDrop = 512;            //              // ColorEdit: disable drag and drop target. ColorButton: disable drag and drop source.
pub const ColorEditFlags_NoBorder = 1024;             //              // ColorButton: disable border (which is enforced by default)
// User Options (right-click on widget to change some of them).
pub const ColorEditFlags_AlphaBar = 65536;            //              // ColorEdit, ColorPicker: show vertical alpha bar/gradient in picker.
pub const ColorEditFlags_AlphaPreview = 131072;       //              // ColorEdit, ColorPicker, ColorButton: display preview as a transparent color over a checkerboard, instead of opaque.
pub const ColorEditFlags_AlphaPreviewHalf = 262144;   //              // ColorEdit, ColorPicker, ColorButton: display half opaque / half checkerboard, instead of opaque.
pub const ColorEditFlags_HDR = 524288;                //              // (WIP) ColorEdit: Currently only disable 0.0f..1.0f limits in RGBA edition (note: you probably want to use ImGuiColorEditFlags_Float flag as well).
pub const ColorEditFlags_DisplayRGB = 1048576;        // [Display]    // ColorEdit: override _display_ type among RGB/HSV/Hex. ColorPicker: select any combination using one or more of RGB/HSV/Hex.
pub const ColorEditFlags_DisplayHSV = 2097152;        // [Display]    // "
pub const ColorEditFlags_DisplayHex = 4194304;        // [Display]    // "
pub const ColorEditFlags_Uint8 = 8388608;             // [DataType]   // ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0..255.
pub const ColorEditFlags_Float = 16777216;            // [DataType]   // ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0.0f..1.0f floats instead of 0..255 integers. No round-trip of value via integers.
pub const ColorEditFlags_PickerHueBar = 33554432;     // [Picker]     // ColorPicker: bar for Hue, rectangle for Sat/Value.
pub const ColorEditFlags_PickerHueWheel = 67108864;   // [Picker]     // ColorPicker: wheel for Hue, triangle for Sat/Value.
pub const ColorEditFlags_InputRGB = 134217728;        // [Input]      // ColorEdit, ColorPicker: input and output data in RGB format.
pub const ColorEditFlags_InputHSV = 268435456;        // [Input]      // ColorEdit, ColorPicker: input and output data in HSV format.
// Defaults Options. You can set application defaults using SetColorEditOptions(). The intent is that you probably don't want to
// override them in most of your calls. Let the user choose via the option menu and/or call SetColorEditOptions() once during startup.
pub const ColorEditFlags_DefaultOptions_ = 177209344;
// [Internal] Masks
pub const ColorEditFlags_DisplayMask_ = 7340032;
pub const ColorEditFlags_DataTypeMask_ = 25165824;
pub const ColorEditFlags_PickerMask_ = 100663296;
pub const ColorEditFlags_InputMask_ = 402653184;

// Flags for DragFloat(), DragInt(), SliderFloat(), SliderInt() etc.
// We use the same sets of flags for DragXXX() and SliderXXX() functions as the features are the same and it makes it easier to swap them.
// (Those are per-item flags. There are shared flags in ImGuiIO: io.ConfigDragClickToInputText)
pub const SliderFlags_None = 0;
pub const SliderFlags_AlwaysClamp = 16;          // Clamp value to min/max bounds when input manually with CTRL+Click. By default CTRL+Click allows going out of bounds.
pub const SliderFlags_Logarithmic = 32;          // Make the widget logarithmic (linear otherwise). Consider using ImGuiSliderFlags_NoRoundToFormat with this if using a format-string with small amount of digits.
pub const SliderFlags_NoRoundToFormat = 64;      // Disable rounding underlying value to match precision of the display format string (e.g. %.3f values are rounded to those 3 digits)
pub const SliderFlags_NoInput = 128;             // Disable CTRL+Click or Enter key allowing to input text directly into the widget
pub const SliderFlags_InvalidMask_ = 1879048207; // [Internal] We treat using those bits as being potentially a 'float power' argument from the previous API that has got miscast to this enum, and will trigger an assert if needed.

// Identify a mouse button.
// Those values are guaranteed to be stable and we frequently use 0/1 directly. Named enums provided for convenience.
pub const MouseButton_Left = 0;
pub const MouseButton_Right = 1;
pub const MouseButton_Middle = 2;
pub const MouseButton_COUNT = 5;

// Enumeration for GetMouseCursor()
// User code may request backend to display given cursor by calling SetMouseCursor(), which is why we have some cursors that are marked unused here
pub const MouseCursor_None = -1;
pub const MouseCursor_Arrow = 0;
pub const MouseCursor_TextInput = 1;  // When hovering over InputText, etc.
pub const MouseCursor_ResizeAll = 2;  // (Unused by Dear ImGui functions)
pub const MouseCursor_ResizeNS = 3;   // When hovering over a horizontal border
pub const MouseCursor_ResizeEW = 4;   // When hovering over a vertical border or a column
pub const MouseCursor_ResizeNESW = 5; // When hovering over the bottom-left corner of a window
pub const MouseCursor_ResizeNWSE = 6; // When hovering over the bottom-right corner of a window
pub const MouseCursor_Hand = 7;       // (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
pub const MouseCursor_NotAllowed = 8; // When hovering something with disallowed interaction. Usually a crossed circle.
pub const MouseCursor_COUNT = 9;

// Enumeration for AddMouseSourceEvent() actual source of Mouse Input data.
// Historically we use "Mouse" terminology everywhere to indicate pointer data, e.g. MousePos, IsMousePressed(), io.AddMousePosEvent()
// But that "Mouse" data can come from different source which occasionally may be useful for application to know about.
// You can submit a change of pointer type using io.AddMouseSourceEvent().
pub const MouseSource_Mouse = 0;       // Input is coming from an actual mouse.
pub const MouseSource_TouchScreen = 1; // Input is coming from a touch screen (no hovering prior to initial press, less precise initial press aiming, dual-axis wheeling possible).
pub const MouseSource_Pen = 2;         // Input is coming from a pressure/magnetic pen (often used in conjunction with high-sampling rates).
pub const MouseSource_COUNT = 3;

// Enumeration for ImGui::SetWindow***(), SetNextWindow***(), SetNextItem***() functions
// Represent a condition.
// Important: Treat as a regular enum! Do NOT combine multiple values using binary operators! All the functions above treat 0 as a shortcut to ImGuiCond_Always.
pub const Cond_None = 0;         // No condition (always set the variable), same as _Always
pub const Cond_Always = 1;       // No condition (always set the variable), same as _None
pub const Cond_Once = 2;         // Set the variable once per runtime session (only the first call will succeed)
pub const Cond_FirstUseEver = 4; // Set the variable if the object/window has no persistently saved data (no entry in .ini file)
pub const Cond_Appearing = 8;    // Set the variable if the object/window is appearing after being hidden/inactive (or the first time)

// Flags for ImDrawList functions
// (Legacy: bit 0 must always correspond to ImDrawFlags_Closed to be backward compatible with old API using a bool. Bits 1..3 must be unused)
pub const DrawFlags_None = 0;
pub const DrawFlags_Closed = 1;                    // PathStroke(), AddPolyline(): specify that shape should be closed (Important: this is always == 1 for legacy reason)
pub const DrawFlags_RoundCornersTopLeft = 16;      // AddRect(), AddRectFilled(), PathRect(): enable rounding top-left corner only (when rounding > 0.0f, we default to all corners). Was 0x01.
pub const DrawFlags_RoundCornersTopRight = 32;     // AddRect(), AddRectFilled(), PathRect(): enable rounding top-right corner only (when rounding > 0.0f, we default to all corners). Was 0x02.
pub const DrawFlags_RoundCornersBottomLeft = 64;   // AddRect(), AddRectFilled(), PathRect(): enable rounding bottom-left corner only (when rounding > 0.0f, we default to all corners). Was 0x04.
pub const DrawFlags_RoundCornersBottomRight = 128; // AddRect(), AddRectFilled(), PathRect(): enable rounding bottom-right corner only (when rounding > 0.0f, we default to all corners). Wax 0x08.
pub const DrawFlags_RoundCornersNone = 256;        // AddRect(), AddRectFilled(), PathRect(): disable rounding on all corners (when rounding > 0.0f). This is NOT zero, NOT an implicit flag!
pub const DrawFlags_RoundCornersTop = 48;
pub const DrawFlags_RoundCornersBottom = 192;
pub const DrawFlags_RoundCornersLeft = 80;
pub const DrawFlags_RoundCornersRight = 160;
pub const DrawFlags_RoundCornersAll = 240;
pub const DrawFlags_RoundCornersDefault_ = 240;    // Default to ALL corners if none of the _RoundCornersXX flags are specified.
pub const DrawFlags_RoundCornersMask_ = 496;

// Flags for ImDrawList instance. Those are set automatically by ImGui:: functions from ImGuiIO settings, and generally not manipulated directly.
// It is however possible to temporarily alter flags between calls to ImDrawList:: functions.
pub const DrawListFlags_None = 0;
pub const DrawListFlags_AntiAliasedLines = 1;       // Enable anti-aliased lines/borders (*2 the number of triangles for 1.0f wide line or lines thin enough to be drawn using textures, otherwise *3 the number of triangles)
pub const DrawListFlags_AntiAliasedLinesUseTex = 2; // Enable anti-aliased lines/borders using textures when possible. Require backend to render with bilinear filtering (NOT point/nearest filtering).
pub const DrawListFlags_AntiAliasedFill = 4;        // Enable anti-aliased edge around filled shapes (rounded rectangles, circles).
pub const DrawListFlags_AllowVtxOffset = 8;         // Can emit 'VtxOffset > 0' to allow large meshes. Set when 'ImGuiBackendFlags_RendererHasVtxOffset' is enabled.

// Flags for ImFontAtlas build
pub const FontAtlasFlags_None = 0;
pub const FontAtlasFlags_NoPowerOfTwoHeight = 1; // Don't round the height to next power of two
pub const FontAtlasFlags_NoMouseCursors = 2;     // Don't build software mouse cursors into the atlas (save a little texture memory)
pub const FontAtlasFlags_NoBakedLines = 4;       // Don't build thick line textures into the atlas (save a little texture memory, allow support for point/nearest filtering). The AntiAliasedLinesUseTex features uses them, otherwise they will be rendered using polygons (more expensive for CPU/GPU).

// Flags stored in ImGuiViewport::Flags, giving indications to the platform backends.
pub const ViewportFlags_None = 0;
pub const ViewportFlags_IsPlatformWindow = 1;       // Represent a Platform Window
pub const ViewportFlags_IsPlatformMonitor = 2;      // Represent a Platform Monitor (unused yet)
pub const ViewportFlags_OwnedByApp = 4;             // Platform Window: Was created/managed by the user application? (rather than our backend)
pub const ViewportFlags_NoDecoration = 8;           // Platform Window: Disable platform decorations: title bar, borders, etc. (generally set all windows, but if ImGuiConfigFlags_ViewportsDecoration is set we only set this on popups/tooltips)
pub const ViewportFlags_NoTaskBarIcon = 16;         // Platform Window: Disable platform task bar icon (generally set on popups/tooltips, or all windows if ImGuiConfigFlags_ViewportsNoTaskBarIcon is set)
pub const ViewportFlags_NoFocusOnAppearing = 32;    // Platform Window: Don't take focus when created.
pub const ViewportFlags_NoFocusOnClick = 64;        // Platform Window: Don't take focus when clicked on.
pub const ViewportFlags_NoInputs = 128;             // Platform Window: Make mouse pass through so we can drag this window while peaking behind it.
pub const ViewportFlags_NoRendererClear = 256;      // Platform Window: Renderer doesn't need to clear the framebuffer ahead (because we will fill it entirely).
pub const ViewportFlags_NoAutoMerge = 512;          // Platform Window: Avoid merging this window into another host window. This can only be set via ImGuiWindowClass viewport flags override (because we need to now ahead if we are going to create a viewport in the first place!).
pub const ViewportFlags_TopMost = 1024;             // Platform Window: Display on top (for tooltips only).
pub const ViewportFlags_CanHostOtherWindows = 2048; // Viewport can host multiple imgui windows (secondary viewports are associated to a single window). // FIXME: In practice there's still probably code making the assumption that this is always and only on the MainViewport. Will fix once we add support for "no main viewport".
// Output status flags (from Platform)
pub const ViewportFlags_IsMinimized = 4096;         // Platform Window: Window is minimized, can skip render. When minimized we tend to avoid using the viewport pos/size for clipping window or testing if they are contained in the viewport.
pub const ViewportFlags_IsFocused = 8192;           // Platform Window: Window is focused (last call to Platform_GetWindowFocus() returned true)

//-----------------------------------------------------------------------------
// Types
//-----------------------------------------------------------------------------

// Enumerations
// - We don't use strongly typed enums much because they add constraints (can't extend in private code, can't store typed in bit fields, extra casting on iteration)
// - Tip: Use your programming IDE navigation facilities on the names in the _central column_ below to find the actual flags/enum lists!
//   In Visual Studio IDE: CTRL+comma ("Edit.GoToAll") can follow symbols in comments, whereas CTRL+F12 ("Edit.GoToImplementation") cannot.
//   With Visual Assist installed: ALT+G ("VAssistX.GoToImplementation") can also follow symbols in comments.
pub const Key = c_int;                                                                     // -> enum ImGuiKey              // Enum: A key identifier (ImGuiKey_XXX or ImGuiMod_XXX value)
pub const MouseSource = c_int;                                                             // -> enum ImGuiMouseSource      // Enum; A mouse input source identifier (Mouse, TouchScreen, Pen)
pub const Col = c_int;                                                                     // -> enum ImGuiCol_             // Enum: A color identifier for styling
pub const Cond = c_int;                                                                    // -> enum ImGuiCond_            // Enum: A condition for many Set*() functions
pub const DataType = c_int;                                                                // -> enum ImGuiDataType_        // Enum: A primary data type
pub const Dir = c_int;                                                                     // -> enum ImGuiDir_             // Enum: A cardinal direction
pub const MouseButton = c_int;                                                             // -> enum ImGuiMouseButton_     // Enum: A mouse button identifier (0=left, 1=right, 2=middle)
pub const MouseCursor = c_int;                                                             // -> enum ImGuiMouseCursor_     // Enum: A mouse cursor shape
pub const SortDirection = c_int;                                                           // -> enum ImGuiSortDirection_   // Enum: A sorting direction (ascending or descending)
pub const StyleVar = c_int;                                                                // -> enum ImGuiStyleVar_        // Enum: A variable identifier for styling
pub const TableBgTarget = c_int;                                                           // -> enum ImGuiTableBgTarget_   // Enum: A color target for TableSetBgColor()
// Flags (declared as int for compatibility with old C++, to allow using as flags without overhead, and to not pollute the top of this file)
// - Tip: Use your programming IDE navigation facilities on the names in the _central column_ below to find the actual flags/enum lists!
//   In Visual Studio IDE: CTRL+comma ("Edit.GoToAll") can follow symbols in comments, whereas CTRL+F12 ("Edit.GoToImplementation") cannot.
//   With Visual Assist installed: ALT+G ("VAssistX.GoToImplementation") can also follow symbols in comments.
pub const DrawFlags = c_int;                                                               // -> enum ImDrawFlags_          // Flags: for ImDrawList functions
pub const DrawListFlags = c_int;                                                           // -> enum ImDrawListFlags_      // Flags: for ImDrawList instance
pub const FontAtlasFlags = c_int;                                                          // -> enum ImFontAtlasFlags_     // Flags: for ImFontAtlas build
pub const BackendFlags = c_int;                                                            // -> enum ImGuiBackendFlags_    // Flags: for io.BackendFlags
pub const ButtonFlags = c_int;                                                             // -> enum ImGuiButtonFlags_     // Flags: for InvisibleButton()
pub const ColorEditFlags = c_int;                                                          // -> enum ImGuiColorEditFlags_  // Flags: for ColorEdit4(), ColorPicker4() etc.
pub const ConfigFlags = c_int;                                                             // -> enum ImGuiConfigFlags_     // Flags: for io.ConfigFlags
pub const ComboFlags = c_int;                                                              // -> enum ImGuiComboFlags_      // Flags: for BeginCombo()
pub const DockNodeFlags = c_int;                                                           // -> enum ImGuiDockNodeFlags_   // Flags: for DockSpace()
pub const DragDropFlags = c_int;                                                           // -> enum ImGuiDragDropFlags_   // Flags: for BeginDragDropSource(), AcceptDragDropPayload()
pub const FocusedFlags = c_int;                                                            // -> enum ImGuiFocusedFlags_    // Flags: for IsWindowFocused()
pub const HoveredFlags = c_int;                                                            // -> enum ImGuiHoveredFlags_    // Flags: for IsItemHovered(), IsWindowHovered() etc.
pub const InputTextFlags = c_int;                                                          // -> enum ImGuiInputTextFlags_  // Flags: for InputText(), InputTextMultiline()
pub const KeyChord = c_int;                                                                // -> ImGuiKey | ImGuiMod_XXX    // Flags: for storage only for now: an ImGuiKey optionally OR-ed with one or more ImGuiMod_XXX values.
pub const PopupFlags = c_int;                                                              // -> enum ImGuiPopupFlags_      // Flags: for OpenPopup*(), BeginPopupContext*(), IsPopupOpen()
pub const SelectableFlags = c_int;                                                         // -> enum ImGuiSelectableFlags_ // Flags: for Selectable()
pub const SliderFlags = c_int;                                                             // -> enum ImGuiSliderFlags_     // Flags: for DragFloat(), DragInt(), SliderFloat(), SliderInt() etc.
pub const TabBarFlags = c_int;                                                             // -> enum ImGuiTabBarFlags_     // Flags: for BeginTabBar()
pub const TabItemFlags = c_int;                                                            // -> enum ImGuiTabItemFlags_    // Flags: for BeginTabItem()
pub const TableFlags = c_int;                                                              // -> enum ImGuiTableFlags_      // Flags: For BeginTable()
pub const TableColumnFlags = c_int;                                                        // -> enum ImGuiTableColumnFlags_// Flags: For TableSetupColumn()
pub const TableRowFlags = c_int;                                                           // -> enum ImGuiTableRowFlags_   // Flags: For TableNextRow()
pub const TreeNodeFlags = c_int;                                                           // -> enum ImGuiTreeNodeFlags_   // Flags: for TreeNode(), TreeNodeEx(), CollapsingHeader()
pub const ViewportFlags = c_int;                                                           // -> enum ImGuiViewportFlags_   // Flags: for ImGuiViewport
pub const WindowFlags = c_int;                                                             // -> enum ImGuiWindowFlags_     // Flags: for Begin(), BeginChild()
pub const TextureID = ?*anyopaque;                                                         // Default: store a pointer or an integer fitting in a pointer (most renderer backends are ok with that)
pub const DrawIdx = c_ushort;                                                              // Default: 16-bit (for maximum compatibility with renderer backends)
// Scalar data types
pub const ID = c_uint;                                                                     // A unique ID used by widgets (typically the result of hashing a stack of string)
pub const S8 = c_char;                                                                     // 8-bit signed integer
pub const U8 = c_char;                                                                     // 8-bit unsigned integer
pub const S16 = c_short;                                                                   // 16-bit signed integer
pub const U16 = c_ushort;                                                                  // 16-bit unsigned integer
pub const S32 = c_int;                                                                     // 32-bit signed integer == int
pub const U32 = c_uint;                                                                    // 32-bit unsigned integer (often used to store packed colors)
pub const S64 = c_longlong;                                                                // 64-bit signed integer
pub const U64 = c_ulonglong;                                                               // 64-bit unsigned integer
// Character types
// (we generally use UTF-8 encoded string in the API. This is storage specifically for a decoded character used for keyboard input and display)
pub const Wchar16 = c_ushort;                                                              // A single decoded U16 character/code point. We encode them as multi bytes UTF-8 when used in strings.
pub const Wchar32 = c_uint;                                                                // A single decoded U32 character/code point. We encode them as multi bytes UTF-8 when used in strings.
pub const Wchar = Wchar16;
// Callback and functions types
pub const InputTextCallback = ?*const fn (?*InputTextCallbackData) callconv(.C) c_int;     // Callback function for ImGui::InputText()
pub const SizeCallback = ?*const fn (?*SizeCallbackData) callconv(.C) void;                // Callback function for ImGui::SetNextWindowSizeConstraints()
pub const MemAllocFunc = ?*const fn (usize, ?*anyopaque) callconv(.C) ?*anyopaque;         // Function signature for ImGui::SetAllocatorFunctions()
pub const MemFreeFunc = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void;           // Function signature for ImGui::SetAllocatorFunctions()
pub const DrawCallback = ?*const fn (?*const DrawList, ?*const DrawCmd) callconv(.C) void;

//-----------------------------------------------------------------------------
// Structs
//-----------------------------------------------------------------------------

pub fn Vector(comptime T: type) type {
    return extern struct {
        size: c_int,
        capacity: c_int,
        data: [*]T,
    };
}

pub const DrawListSharedData = extern struct {
     // Data shared among multiple draw lists (typically owned by parent ImGui context, but you may create one yourself)
};

pub const FontBuilderIO = extern struct {
     // Opaque interface to a font builder (stb_truetype or FreeType).
};

pub const Context = extern struct {
     // Dear ImGui context (opaque structure, unless including imgui_internal.h)
};

pub const Vec2 = extern struct {
    x: f32,
    y: f32,
};

// ImVec4: 4D vector used to store clipping rectangles, colors etc. [Compile-time configurable type]
pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const Style = extern struct {
    alpha: f32,                                  // Global alpha applies to everything in Dear ImGui.
    disabled_alpha: f32,                         // Additional alpha multiplier applied by BeginDisabled(). Multiply over current value of Alpha.
    window_padding: Vec2,                        // Padding within a window.
    window_rounding: f32,                        // Radius of window corners rounding. Set to 0.0f to have rectangular windows. Large values tend to lead to variety of artifacts and are not recommended.
    window_border_size: f32,                     // Thickness of border around windows. Generally set to 0.0f or 1.0f. (Other values are not well tested and more CPU/GPU costly).
    window_min_size: Vec2,                       // Minimum window size. This is a global setting. If you want to constrain individual windows, use SetNextWindowSizeConstraints().
    window_title_align: Vec2,                    // Alignment for title bar text. Defaults to (0.0f,0.5f) for left-aligned,vertically centered.
    window_menu_button_position: Dir,            // Side of the collapsing/docking button in the title bar (None/Left/Right). Defaults to ImGuiDir_Left.
    child_rounding: f32,                         // Radius of child window corners rounding. Set to 0.0f to have rectangular windows.
    child_border_size: f32,                      // Thickness of border around child windows. Generally set to 0.0f or 1.0f. (Other values are not well tested and more CPU/GPU costly).
    popup_rounding: f32,                         // Radius of popup window corners rounding. (Note that tooltip windows use WindowRounding)
    popup_border_size: f32,                      // Thickness of border around popup/tooltip windows. Generally set to 0.0f or 1.0f. (Other values are not well tested and more CPU/GPU costly).
    frame_padding: Vec2,                         // Padding within a framed rectangle (used by most widgets).
    frame_rounding: f32,                         // Radius of frame corners rounding. Set to 0.0f to have rectangular frame (used by most widgets).
    frame_border_size: f32,                      // Thickness of border around frames. Generally set to 0.0f or 1.0f. (Other values are not well tested and more CPU/GPU costly).
    item_spacing: Vec2,                          // Horizontal and vertical spacing between widgets/lines.
    item_inner_spacing: Vec2,                    // Horizontal and vertical spacing between within elements of a composed widget (e.g. a slider and its label).
    cell_padding: Vec2,                          // Padding within a table cell. CellPadding.y may be altered between different rows.
    touch_extra_padding: Vec2,                   // Expand reactive bounding box for touch-based system where touch position is not accurate enough. Unfortunately we don't sort widgets so priority on overlap will always be given to the first widget. So don't grow this too much!
    indent_spacing: f32,                         // Horizontal indentation when e.g. entering a tree node. Generally == (FontSize + FramePadding.x*2).
    columns_min_spacing: f32,                    // Minimum horizontal spacing between two columns. Preferably > (FramePadding.x + 1).
    scrollbar_size: f32,                         // Width of the vertical scrollbar, Height of the horizontal scrollbar.
    scrollbar_rounding: f32,                     // Radius of grab corners for scrollbar.
    grab_min_size: f32,                          // Minimum width/height of a grab box for slider/scrollbar.
    grab_rounding: f32,                          // Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.
    log_slider_deadzone: f32,                    // The size in pixels of the dead-zone around zero on logarithmic sliders that cross zero.
    tab_rounding: f32,                           // Radius of upper corners of a tab. Set to 0.0f to have rectangular tabs.
    tab_border_size: f32,                        // Thickness of border around tabs.
    tab_min_width_for_close_button: f32,         // Minimum width for close button to appear on an unselected tab when hovered. Set to 0.0f to always show when hovering, set to FLT_MAX to never show close button unless selected.
    color_button_position: Dir,                  // Side of the color button in the ColorEdit4 widget (left/right). Defaults to ImGuiDir_Right.
    button_text_align: Vec2,                     // Alignment of button text when button is larger than text. Defaults to (0.5f, 0.5f) (centered).
    selectable_text_align: Vec2,                 // Alignment of selectable text. Defaults to (0.0f, 0.0f) (top-left aligned). It's generally important to keep this left-aligned if you want to lay multiple items on a same line.
    separator_text_border_size: f32,             // Thickkness of border in SeparatorText()
    separator_text_align: Vec2,                  // Alignment of text within the separator. Defaults to (0.0f, 0.5f) (left aligned, center).
    separator_text_padding: Vec2,                // Horizontal offset of text from each edge of the separator + spacing on other axis. Generally small values. .y is recommended to be == FramePadding.y.
    display_window_padding: Vec2,                // Window position are clamped to be visible within the display area or monitors by at least this amount. Only applies to regular windows.
    display_safe_area_padding: Vec2,             // If you cannot see the edges of your screen (e.g. on a TV) increase the safe area padding. Apply to popups/tooltips as well regular windows. NB: Prefer configuring your TV sets correctly!
    docking_separator_size: f32,                 // Thickness of resizing border between docked windows
    mouse_cursor_scale: f32,                     // Scale software rendered mouse cursor (when io.MouseDrawCursor is enabled). We apply per-monitor DPI scaling over this scale. May be removed later.
    anti_aliased_lines: bool,                    // Enable anti-aliased lines/borders. Disable if you are really tight on CPU/GPU. Latched at the beginning of the frame (copied to ImDrawList).
    anti_aliased_lines_use_tex: bool,            // Enable anti-aliased lines/borders using textures where possible. Require backend to render with bilinear filtering (NOT point/nearest filtering). Latched at the beginning of the frame (copied to ImDrawList).
    anti_aliased_fill: bool,                     // Enable anti-aliased edges around filled shapes (rounded rectangles, circles, etc.). Disable if you are really tight on CPU/GPU. Latched at the beginning of the frame (copied to ImDrawList).
    curve_tessellation_tol: f32,                 // Tessellation tolerance when using PathBezierCurveTo() without a specific number of segments. Decrease for highly tessellated curves (higher quality, more polygons), increase to reduce quality.
    circle_tessellation_max_error: f32,          // Maximum error (in pixels) allowed when using AddCircle()/AddCircleFilled() or drawing rounded corner rectangles with no explicit segment count specified. Decrease for higher quality but more geometry.
    colors: [Col_COUNT]Vec4,
    // Behaviors
    // (It is possible to modify those fields mid-frame if specific behavior need it, unlike e.g. configuration fields in ImGuiIO)
    hover_stationary_delay: f32,                 // Delay for IsItemHovered(ImGuiHoveredFlags_Stationary). Time required to consider mouse stationary.
    hover_delay_short: f32,                      // Delay for IsItemHovered(ImGuiHoveredFlags_DelayShort). Usually used along with HoverStationaryDelay.
    hover_delay_normal: f32,                     // Delay for IsItemHovered(ImGuiHoveredFlags_DelayNormal). "
    hover_flags_for_tooltip_mouse: HoveredFlags, // Default flags when using IsItemHovered(ImGuiHoveredFlags_ForTooltip) or BeginItemTooltip()/SetItemTooltip() while using mouse.
    hover_flags_for_tooltip_nav: HoveredFlags,   // Default flags when using IsItemHovered(ImGuiHoveredFlags_ForTooltip) or BeginItemTooltip()/SetItemTooltip() while using keyboard/gamepad.
    pub const scaleAllSizes = ImGuiStyle_ScaleAllSizes;
};

// [Internal] Storage used by IsKeyDown(), IsKeyPressed() etc functions.
// If prior to 1.87 you used io.KeysDownDuration[] (which was marked as internal), you should use GetKeyData(key)->DownDuration and *NOT* io.KeysData[key]->DownDuration.
pub const KeyData = extern struct {
    down: bool,              // True for if key is down
    down_duration: f32,      // Duration the key has been down (<0.0f: not pressed, 0.0f: just pressed, >0.0f: time held)
    down_duration_prev: f32, // Last frame duration the key has been down
    analog_value: f32,       // 0.0f..1.0f for gamepad values
};

pub const IO = extern struct {
    config_flags: ConfigFlags,                                                              // = 0              // See ImGuiConfigFlags_ enum. Set by user/application. Gamepad/keyboard navigation options, etc.
    backend_flags: BackendFlags,                                                            // = 0              // See ImGuiBackendFlags_ enum. Set by backend (imgui_impl_xxx files or custom backend) to communicate features supported by the backend.
    display_size: Vec2,                                                                     // <unset>          // Main display size, in pixels (generally == GetMainViewport()->Size). May change every frame.
    delta_time: f32,                                                                        // = 1.0f/60.0f     // Time elapsed since last frame, in seconds. May change every frame.
    ini_saving_rate: f32,                                                                   // = 5.0f           // Minimum time between saving positions/sizes to .ini file, in seconds.
    ini_filename: ?[*:0]const u8,                                                           // = "imgui.ini"    // Path to .ini file (important: default "imgui.ini" is relative to current working dir!). Set NULL to disable automatic .ini loading/saving or if you want to manually call LoadIniSettingsXXX() / SaveIniSettingsXXX() functions.
    log_filename: ?[*:0]const u8,                                                           // = "imgui_log.txt"// Path to .log file (default parameter to ImGui::LogToFile when no file is specified).
    user_data: ?*anyopaque,                                                                 // = NULL           // Store your own data.
    fonts: ?*FontAtlas,                                                                     // <auto>           // Font atlas: load, rasterize and pack one or more fonts into a single texture.
    font_global_scale: f32,                                                                 // = 1.0f           // Global scale all fonts
    font_allow_user_scaling: bool,                                                          // = false          // Allow user scaling text of individual window with CTRL+Wheel.
    font_default: ?*Font,                                                                   // = NULL           // Font to use on NewFrame(). Use NULL to uses Fonts->Fonts[0].
    display_framebuffer_scale: Vec2,                                                        // = (1, 1)         // For retina display or other situations where window coordinates are different from framebuffer coordinates. This generally ends up in ImDrawData::FramebufferScale.
    // Docking options (when ImGuiConfigFlags_DockingEnable is set)
    config_docking_no_split: bool,                                                          // = false          // Simplified docking mode: disable window splitting, so docking is limited to merging multiple windows together into tab-bars.
    config_docking_with_shift: bool,                                                        // = false          // Enable docking with holding Shift key (reduce visual noise, allows dropping in wider space)
    config_docking_always_tab_bar: bool,                                                    // = false          // [BETA] [FIXME: This currently creates regression with auto-sizing and general overhead] Make every single floating window display within a docking node.
    config_docking_transparent_payload: bool,                                               // = false          // [BETA] Make window or viewport transparent when docking and only display docking boxes on the target viewport. Useful if rendering of multiple viewport cannot be synced. Best used with ConfigViewportsNoAutoMerge.
    // Viewport options (when ImGuiConfigFlags_ViewportsEnable is set)
    config_viewports_no_auto_merge: bool,                                                   // = false;         // Set to make all floating imgui windows always create their own viewport. Otherwise, they are merged into the main host viewports when overlapping it. May also set ImGuiViewportFlags_NoAutoMerge on individual viewport.
    config_viewports_no_task_bar_icon: bool,                                                // = false          // Disable default OS task bar icon flag for secondary viewports. When a viewport doesn't want a task bar icon, ImGuiViewportFlags_NoTaskBarIcon will be set on it.
    config_viewports_no_decoration: bool,                                                   // = true           // Disable default OS window decoration flag for secondary viewports. When a viewport doesn't want window decorations, ImGuiViewportFlags_NoDecoration will be set on it. Enabling decoration can create subsequent issues at OS levels (e.g. minimum window size).
    config_viewports_no_default_parent: bool,                                               // = false          // Disable default OS parenting to main viewport for secondary viewports. By default, viewports are marked with ParentViewportId = <main_viewport>, expecting the platform backend to setup a parent/child relationship between the OS windows (some backend may ignore this). Set to true if you want the default to be 0, then all viewports will be top-level OS windows.
    // Miscellaneous options
    mouse_draw_cursor: bool,                                                                // = false          // Request ImGui to draw a mouse cursor for you (if you are on a platform without a mouse cursor). Cannot be easily renamed to 'io.ConfigXXX' because this is frequently used by backend implementations.
    config_mac_osxbehaviors: bool,                                                          // = defined(__APPLE__) // OS X style: Text editing cursor movement using Alt instead of Ctrl, Shortcuts using Cmd/Super instead of Ctrl, Line/Text Start and End using Cmd+Arrows instead of Home/End, Double click selects by word instead of selecting whole text, Multi-selection in lists uses Cmd/Super instead of Ctrl.
    config_input_trickle_event_queue: bool,                                                 // = true           // Enable input queue trickling: some types of events submitted during the same frame (e.g. button down + up) will be spread over multiple frames, improving interactions with low framerates.
    config_input_text_cursor_blink: bool,                                                   // = true           // Enable blinking cursor (optional as some users consider it to be distracting).
    config_input_text_enter_keep_active: bool,                                              // = false          // [BETA] Pressing Enter will keep item active and select contents (single-line only).
    config_drag_click_to_input_text: bool,                                                  // = false          // [BETA] Enable turning DragXXX widgets into text input with a simple mouse click-release (without moving). Not desirable on devices without a keyboard.
    config_windows_resize_from_edges: bool,                                                 // = true           // Enable resizing of windows from their edges and from the lower-left corner. This requires (io.BackendFlags & ImGuiBackendFlags_HasMouseCursors) because it needs mouse cursor feedback. (This used to be a per-window ImGuiWindowFlags_ResizeFromAnySide flag)
    config_windows_move_from_title_bar_only: bool,                                          // = false       // Enable allowing to move windows only when clicking on their title bar. Does not apply to windows without a title bar.
    config_memory_compact_timer: f32,                                                       // = 60.0f          // Timer (in seconds) to free transient windows/tables memory buffers when unused. Set to -1.0f to disable.
    // Inputs Behaviors
    // (other variables, ones which are expected to be tweaked within UI code, are exposed in ImGuiStyle)
    mouse_double_click_time: f32,                                                           // = 0.30f          // Time for a double-click, in seconds.
    mouse_double_click_max_dist: f32,                                                       // = 6.0f           // Distance threshold to stay in to validate a double-click, in pixels.
    mouse_drag_threshold: f32,                                                              // = 6.0f           // Distance threshold before considering we are dragging.
    key_repeat_delay: f32,                                                                  // = 0.275f         // When holding a key/button, time before it starts repeating, in seconds (for buttons in Repeat mode, etc.).
    key_repeat_rate: f32,                                                                   // = 0.050f         // When holding a key/button, rate at which it repeats, in seconds.
    // Tools to test correct Begin/End and BeginChild/EndChild behaviors.
    // Presently Begin()/End() and BeginChild()/EndChild() needs to ALWAYS be called in tandem, regardless of return value of BeginXXX()
    // This is inconsistent with other BeginXXX functions and create confusion for many users.
    // We expect to update the API eventually. In the meanwhile we provide tools to facilitate checking user-code behavior.
    config_debug_begin_return_value_once: bool,                                             // = false          // First-time calls to Begin()/BeginChild() will return false. NEEDS TO BE SET AT APPLICATION BOOT TIME if you don't want to miss windows.
    config_debug_begin_return_value_loop: bool,                                             // = false          // Some calls to Begin()/BeginChild() will return false. Will cycle through window depths then repeat. Suggested use: add "io.ConfigDebugBeginReturnValue = io.KeyShift" in your main loop then occasionally press SHIFT. Windows should be flickering while running.
    // Option to deactivate io.AddFocusEvent(false) handling. May facilitate interactions with a debugger when focus loss leads to clearing inputs data.
    // Backends may have other side-effects on focus loss, so this will reduce side-effects but not necessary remove all of them.
    // Consider using e.g. Win32's IsDebuggerPresent() as an additional filter (or see ImOsIsDebuggerPresent() in imgui_test_engine/imgui_te_utils.cpp for a Unix compatible version).
    config_debug_ignore_focus_loss: bool,                                                   // = false          // Ignore io.AddFocusEvent(false), consequently not calling io.ClearInputKeys() in input processing.
    // Option to audit .ini data
    config_debug_ini_settings: bool,                                                        // = false          // Save .ini data with extra comments (particularly helpful for Docking, but makes saving slower)
    // Optional: Platform/Renderer backend name (informational only! will be displayed in About Window) + User data for backend/wrappers to store their own stuff.
    backend_platform_name: ?[*:0]const u8,                                                  // = NULL
    backend_renderer_name: ?[*:0]const u8,                                                  // = NULL
    backend_platform_user_data: ?*anyopaque,                                                // = NULL           // User data for platform backend
    backend_renderer_user_data: ?*anyopaque,                                                // = NULL           // User data for renderer backend
    backend_language_user_data: ?*anyopaque,                                                // = NULL           // User data for non C++ programming language backend
    // Optional: Access OS clipboard
    // (default to use native Win32 clipboard on Windows, otherwise uses a private clipboard. Override to access OS clipboard on other architectures)
    get_clipboard_text_fn: ?*const fn (?*anyopaque) callconv(.C) ?[*:0]const u8,
    set_clipboard_text_fn: ?*const fn (?*anyopaque, ?[*:0]const u8) callconv(.C) void,
    clipboard_user_data: ?*anyopaque,
    // Optional: Notify OS Input Method Editor of the screen position of your cursor for text input position (e.g. when using Japanese/Chinese IME on Windows)
    // (default to use native imm32 api on Windows)
    set_platform_ime_data_fn: ?*const fn (?*Viewport, ?*PlatformImeData) callconv(.C) void,
    // Optional: Platform locale
    platform_locale_decimal_point: Wchar,                                                   // '.'              // [Experimental] Configure decimal point e.g. '.' or ',' useful for some languages (e.g. German), generally pulled from *localeconv()->decimal_point
    want_capture_mouse: bool,                                                               // Set when Dear ImGui will use mouse inputs, in this case do not dispatch them to your main game/application (either way, always pass on mouse inputs to imgui). (e.g. unclicked mouse is hovering over an imgui window, widget is active, mouse was clicked over an imgui window, etc.).
    want_capture_keyboard: bool,                                                            // Set when Dear ImGui will use keyboard inputs, in this case do not dispatch them to your main game/application (either way, always pass keyboard inputs to imgui). (e.g. InputText active, or an imgui window is focused and navigation is enabled, etc.).
    want_text_input: bool,                                                                  // Mobile/console: when set, you may display an on-screen keyboard. This is set by Dear ImGui when it wants textual keyboard input to happen (e.g. when a InputText widget is active).
    want_set_mouse_pos: bool,                                                               // MousePos has been altered, backend should reposition mouse on next frame. Rarely used! Set only when ImGuiConfigFlags_NavEnableSetMousePos flag is enabled.
    want_save_ini_settings: bool,                                                           // When manual .ini load/save is active (io.IniFilename == NULL), this will be set to notify your application that you can call SaveIniSettingsToMemory() and save yourself. Important: clear io.WantSaveIniSettings yourself after saving!
    nav_active: bool,                                                                       // Keyboard/Gamepad navigation is currently allowed (will handle ImGuiKey_NavXXX events) = a window is focused and it doesn't use the ImGuiWindowFlags_NoNavInputs flag.
    nav_visible: bool,                                                                      // Keyboard/Gamepad navigation is visible and allowed (will handle ImGuiKey_NavXXX events).
    framerate: f32,                                                                         // Estimate of application framerate (rolling average over 60 frames, based on io.DeltaTime), in frame per second. Solely for convenience. Slow applications may not want to use a moving average or may want to reset underlying buffers occasionally.
    metrics_render_vertices: c_int,                                                         // Vertices output during last call to Render()
    metrics_render_indices: c_int,                                                          // Indices output during last call to Render() = number of triangles * 3
    metrics_render_windows: c_int,                                                          // Number of visible windows
    metrics_active_windows: c_int,                                                          // Number of active windows
    metrics_active_allocations: c_int,                                                      // Number of active allocations, updated by MemAlloc/MemFree based on current context. May be off if you have multiple imgui contexts.
    mouse_delta: Vec2,                                                                      // Mouse delta. Note that this is zero if either current or previous position are invalid (-FLT_MAX,-FLT_MAX), so a disappearing/reappearing mouse won't have a huge delta.
    ctx: ?*Context,                                                                         // Parent UI context (needs to be set explicitly by parent).
    // Main Input State
    // (this block used to be written by backend, since 1.87 it is best to NOT write to those directly, call the AddXXX functions above instead)
    // (reading from those variables is fair game, as they are extremely unlikely to be moving anywhere)
    mouse_pos: Vec2,                                                                        // Mouse position, in pixels. Set to ImVec2(-FLT_MAX, -FLT_MAX) if mouse is unavailable (on another screen, etc.)
    mouse_down: [5]bool,                                                                    // Mouse buttons: 0=left, 1=right, 2=middle + extras (ImGuiMouseButton_COUNT == 5). Dear ImGui mostly uses left and right buttons. Other buttons allow us to track if the mouse is being used by your application + available to user as a convenience via IsMouse** API.
    mouse_wheel: f32,                                                                       // Mouse wheel Vertical: 1 unit scrolls about 5 lines text. >0 scrolls Up, <0 scrolls Down. Hold SHIFT to turn vertical scroll into horizontal scroll.
    mouse_wheel_h: f32,                                                                     // Mouse wheel Horizontal. >0 scrolls Left, <0 scrolls Right. Most users don't have a mouse with a horizontal wheel, may not be filled by all backends.
    mouse_source: MouseSource,                                                              // Mouse actual input peripheral (Mouse/TouchScreen/Pen).
    mouse_hovered_viewport: ID,                                                             // (Optional) Modify using io.AddMouseViewportEvent(). With multi-viewports: viewport the OS mouse is hovering. If possible _IGNORING_ viewports with the ImGuiViewportFlags_NoInputs flag is much better (few backends can handle that). Set io.BackendFlags |= ImGuiBackendFlags_HasMouseHoveredViewport if you can provide this info. If you don't imgui will infer the value using the rectangles and last focused time of the viewports it knows about (ignoring other OS windows).
    key_ctrl: bool,                                                                         // Keyboard modifier down: Control
    key_shift: bool,                                                                        // Keyboard modifier down: Shift
    key_alt: bool,                                                                          // Keyboard modifier down: Alt
    key_super: bool,                                                                        // Keyboard modifier down: Cmd/Super/Windows
    // Other state maintained from data above + IO function calls
    key_mods: KeyChord,                                                                     // Key mods flags (any of ImGuiMod_Ctrl/ImGuiMod_Shift/ImGuiMod_Alt/ImGuiMod_Super flags, same as io.KeyCtrl/KeyShift/KeyAlt/KeySuper but merged into flags. DOES NOT CONTAINS ImGuiMod_Shortcut which is pretranslated). Read-only, updated by NewFrame()
    keys_data: [Key_KeysData_SIZE]KeyData,                                                  // Key state for all known keys. Use IsKeyXXX() functions to access this.
    want_capture_mouse_unless_popup_close: bool,                                            // Alternative to WantCaptureMouse: (WantCaptureMouse == true && WantCaptureMouseUnlessPopupClose == false) when a click over void is expected to close a popup.
    mouse_pos_prev: Vec2,                                                                   // Previous mouse position (note that MouseDelta is not necessary == MousePos-MousePosPrev, in case either position is invalid)
    mouse_clicked_pos: [5]Vec2,                                                             // Position at time of clicking
    mouse_clicked_time: [5]f64,                                                             // Time of last click (used to figure out double-click)
    mouse_clicked: [5]bool,                                                                 // Mouse button went from !Down to Down (same as MouseClickedCount[x] != 0)
    mouse_double_clicked: [5]bool,                                                          // Has mouse button been double-clicked? (same as MouseClickedCount[x] == 2)
    mouse_clicked_count: [5]U16,                                                            // == 0 (not clicked), == 1 (same as MouseClicked[]), == 2 (double-clicked), == 3 (triple-clicked) etc. when going from !Down to Down
    mouse_clicked_last_count: [5]U16,                                                       // Count successive number of clicks. Stays valid after mouse release. Reset after another click is done.
    mouse_released: [5]bool,                                                                // Mouse button went from Down to !Down
    mouse_down_owned: [5]bool,                                                              // Track if button was clicked inside a dear imgui window or over void blocked by a popup. We don't request mouse capture from the application if click started outside ImGui bounds.
    mouse_down_owned_unless_popup_close: [5]bool,                                           // Track if button was clicked inside a dear imgui window.
    mouse_wheel_request_axis_swap: bool,                                                    // On a non-Mac system, holding SHIFT requests WheelY to perform the equivalent of a WheelX event. On a Mac system this is already enforced by the system.
    mouse_down_duration: [5]f32,                                                            // Duration the mouse button has been down (0.0f == just clicked)
    mouse_down_duration_prev: [5]f32,                                                       // Previous time the mouse button has been down
    mouse_drag_max_distance_abs: [5]Vec2,                                                   // Maximum distance, absolute, on each axis, of how much mouse has traveled from the clicking point
    mouse_drag_max_distance_sqr: [5]f32,                                                    // Squared maximum distance of how much mouse has traveled from the clicking point (used for moving thresholds)
    pen_pressure: f32,                                                                      // Touch/Pen pressure (0.0f to 1.0f, should be >0.0f only when MouseDown[0] == true). Helper storage currently unused by Dear ImGui.
    app_focus_lost: bool,                                                                   // Only modify via AddFocusEvent()
    app_accepting_events: bool,                                                             // Only modify via SetAppAcceptingEvents()
    backend_using_legacy_key_arrays: S8,                                                    // -1: unknown, 0: using AddKeyEvent(), 1: using legacy io.KeysDown[]
    backend_using_legacy_nav_input_array: bool,                                             // 0: using AddKeyAnalogEvent(), 1: writing to legacy io.NavInputs[] directly
    input_queue_surrogate: Wchar16,                                                         // For AddInputCharacterUTF16()
    input_queue_characters: Vector(Wchar),                                                  // Queue of _characters_ input (obtained by platform backend). Fill using AddInputCharacter() helper.
    // Input Functions
    pub const addKeyEvent = ImGuiIO_AddKeyEvent;                         // Queue a new key down/up event. Key should be "translated" (as in, generally ImGuiKey_A matches the key end-user would use to emit an 'A' character)
    pub const addKeyAnalogEvent = ImGuiIO_AddKeyAnalogEvent;             // Queue a new key down/up event for analog values (e.g. ImGuiKey_Gamepad_ values). Dead-zones should be handled by the backend.
    pub const addMousePosEvent = ImGuiIO_AddMousePosEvent;               // Queue a mouse position update. Use -FLT_MAX,-FLT_MAX to signify no mouse (e.g. app not focused and not hovered)
    pub const addMouseButtonEvent = ImGuiIO_AddMouseButtonEvent;         // Queue a mouse button change
    pub const addMouseWheelEvent = ImGuiIO_AddMouseWheelEvent;           // Queue a mouse wheel update. wheel_y<0: scroll down, wheel_y>0: scroll up, wheel_x<0: scroll right, wheel_x>0: scroll left.
    pub const addMouseSourceEvent = ImGuiIO_AddMouseSourceEvent;         // Queue a mouse source change (Mouse/TouchScreen/Pen)
    pub const addMouseViewportEvent = ImGuiIO_AddMouseViewportEvent;     // Queue a mouse hovered viewport. Requires backend to set ImGuiBackendFlags_HasMouseHoveredViewport to call this (for multi-viewport support).
    pub const addFocusEvent = ImGuiIO_AddFocusEvent;                     // Queue a gain/loss of focus for the application (generally based on OS/platform focus of your window)
    pub const addInputCharacter = ImGuiIO_AddInputCharacter;             // Queue a new character input
    pub const addInputCharacterUTF16 = ImGuiIO_AddInputCharacterUTF16;   // Queue a new character input from a UTF-16 character, it can be a surrogate
    pub const addInputCharactersUTF8 = ImGuiIO_AddInputCharactersUTF8;   // Queue a new characters input from a UTF-8 string
    pub const setKeyEventNativeData = ImGuiIO_SetKeyEventNativeData;     // Implied native_legacy_index = -1
    pub const setKeyEventNativeDataEx = ImGuiIO_SetKeyEventNativeDataEx; // [Optional] Specify index for legacy <1.87 IsKeyXXX() functions with native indices + specify native keycode, scancode.
    pub const setAppAcceptingEvents = ImGuiIO_SetAppAcceptingEvents;     // Set master flag for accepting key/mouse/text events (default to true). Useful if you have native dialog boxes that are interrupting your application loop/refresh, and you want to disable events being queued while your app is frozen.
    pub const clearEventsQueue = ImGuiIO_ClearEventsQueue;               // Clear all incoming events.
    pub const clearInputKeys = ImGuiIO_ClearInputKeys;                   // Clear current keyboard/mouse/gamepad state + current frame text input buffer. Equivalent to releasing all keys/buttons.
};

// Shared state of InputText(), passed as an argument to your callback when a ImGuiInputTextFlags_Callback* flag is used.
// The callback function should return 0 by default.
// Callbacks (follow a flag name and see comments in ImGuiInputTextFlags_ declarations for more details)
// - ImGuiInputTextFlags_CallbackEdit:        Callback on buffer edit (note that InputText() already returns true on edit, the callback is useful mainly to manipulate the underlying buffer while focus is active)
// - ImGuiInputTextFlags_CallbackAlways:      Callback on each iteration
// - ImGuiInputTextFlags_CallbackCompletion:  Callback on pressing TAB
// - ImGuiInputTextFlags_CallbackHistory:     Callback on pressing Up/Down arrows
// - ImGuiInputTextFlags_CallbackCharFilter:  Callback on character inputs to replace or discard them. Modify 'EventChar' to replace or discard, or return 1 in callback to discard.
// - ImGuiInputTextFlags_CallbackResize:      Callback on buffer capacity changes request (beyond 'buf_size' parameter value), allowing the string to grow.
pub const InputTextCallbackData = extern struct {
    ctx: ?*Context,             // Parent UI context
    event_flag: InputTextFlags, // One ImGuiInputTextFlags_Callback*    // Read-only
    flags: InputTextFlags,      // What user passed to InputText()      // Read-only
    user_data: ?*anyopaque,     // What user passed to InputText()      // Read-only
    // Arguments for the different callback events
    // - To modify the text buffer in a callback, prefer using the InsertChars() / DeleteChars() function. InsertChars() will take care of calling the resize callback if necessary.
    // - If you know your edits are not going to resize the underlying buffer allocation, you may modify the contents of 'Buf[]' directly. You need to update 'BufTextLen' accordingly (0 <= BufTextLen < BufSize) and set 'BufDirty'' to true so InputText can update its internal state.
    event_char: Wchar,          // Character input                      // Read-write   // [CharFilter] Replace character with another one, or set to zero to drop. return 1 is equivalent to setting EventChar=0;
    event_key: Key,             // Key pressed (Up/Down/TAB)            // Read-only    // [Completion,History]
    buf: ?[*:0]const u8,        // Text buffer                          // Read-write   // [Resize] Can replace pointer / [Completion,History,Always] Only write to pointed data, don't replace the actual pointer!
    buf_text_len: c_int,        // Text length (in bytes)               // Read-write   // [Resize,Completion,History,Always] Exclude zero-terminator storage. In C land: == strlen(some_text), in C++ land: string.length()
    buf_size: c_int,            // Buffer size (in bytes) = capacity+1  // Read-only    // [Resize,Completion,History,Always] Include zero-terminator storage. In C land == ARRAYSIZE(my_char_array), in C++ land: string.capacity()+1
    buf_dirty: bool,            // Set if you modify Buf/BufTextLen!    // Write        // [Completion,History,Always]
    cursor_pos: c_int,          //                                      // Read-write   // [Completion,History,Always]
    selection_start: c_int,     //                                      // Read-write   // [Completion,History,Always] == to SelectionEnd when no selection)
    selection_end: c_int,       //                                      // Read-write   // [Completion,History,Always]
    pub const deleteChars = ImGuiInputTextCallbackData_DeleteChars;
    pub const insertChars = ImGuiInputTextCallbackData_InsertChars;
    pub const selectAll = ImGuiInputTextCallbackData_SelectAll;
    pub const clearSelection = ImGuiInputTextCallbackData_ClearSelection;
    pub const hasSelection = ImGuiInputTextCallbackData_HasSelection;
};

// Resizing callback data to apply custom constraint. As enabled by SetNextWindowSizeConstraints(). Callback is called during the next Begin().
// NB: For basic min/max size constraint on each axis you don't need to use the callback! The SetNextWindowSizeConstraints() parameters are enough.
pub const SizeCallbackData = extern struct {
    user_data: ?*anyopaque, // Read-only.   What user passed to SetNextWindowSizeConstraints(). Generally store an integer or float in here (need reinterpret_cast<>).
    pos: Vec2,              // Read-only.   Window position, for reference.
    current_size: Vec2,     // Read-only.   Current window size.
    desired_size: Vec2,     // Read-write.  Desired size, based on user's mouse position. Write to this field to restrain resizing.
};

// [ALPHA] Rarely used / very advanced uses only. Use with SetNextWindowClass() and DockSpace() functions.
// Important: the content of this class is still highly WIP and likely to change and be refactored
// before we stabilize Docking features. Please be mindful if using this.
// Provide hints:
// - To the platform backend via altered viewport flags (enable/disable OS decoration, OS task bar icons, etc.)
// - To the platform backend for OS level parent/child relationships of viewport.
// - To the docking system for various options and filtering.
pub const WindowClass = extern struct {
    class_id: ID,                                 // User data. 0 = Default class (unclassed). Windows of different classes cannot be docked with each others.
    parent_viewport_id: ID,                       // Hint for the platform backend. -1: use default. 0: request platform backend to not parent the platform. != 0: request platform backend to create a parent<>child relationship between the platform windows. Not conforming backends are free to e.g. parent every viewport to the main viewport or not.
    viewport_flags_override_set: ViewportFlags,   // Viewport flags to set when a window of this class owns a viewport. This allows you to enforce OS decoration or task bar icon, override the defaults on a per-window basis.
    viewport_flags_override_clear: ViewportFlags, // Viewport flags to clear when a window of this class owns a viewport. This allows you to enforce OS decoration or task bar icon, override the defaults on a per-window basis.
    tab_item_flags_override_set: TabItemFlags,    // [EXPERIMENTAL] TabItem flags to set when a window of this class gets submitted into a dock node tab bar. May use with ImGuiTabItemFlags_Leading or ImGuiTabItemFlags_Trailing.
    dock_node_flags_override_set: DockNodeFlags,  // [EXPERIMENTAL] Dock node flags to set when a window of this class is hosted by a dock node (it doesn't have to be selected!)
    docking_always_tab_bar: bool,                 // Set to true to enforce single floating windows of this class always having their own docking node (equivalent of setting the global io.ConfigDockingAlwaysTabBar)
    docking_allow_unclassed: bool,                // Set to true to allow windows of this class to be docked/merged with an unclassed window. // FIXME-DOCK: Move to DockNodeFlags override?
};

// Data payload for Drag and Drop operations: AcceptDragDropPayload(), GetDragDropPayload()
pub const Payload = extern struct {
    // Members
    data: ?*anyopaque,       // Data (copied and owned by dear imgui)
    data_size: c_int,        // Data size
    // [Internal]
    source_id: ID,           // Source item id
    source_parent_id: ID,    // Source parent id (if available)
    data_frame_count: c_int, // Data timestamp
    data_type: [32+1]c_char, // Data type tag (short user-supplied string, 32 characters max)
    preview: bool,           // Set when AcceptDragDropPayload() was called and mouse has been hovering the target item (nb: handle overlapping drag targets)
    delivery: bool,          // Set when AcceptDragDropPayload() was called and mouse button is released over the target item.
    pub const clear = ImGuiPayload_Clear;
    pub const isDataType = ImGuiPayload_IsDataType;
    pub const isPreview = ImGuiPayload_IsPreview;
    pub const isDelivery = ImGuiPayload_IsDelivery;
};

// Sorting specification for one column of a table (sizeof == 12 bytes)
pub const TableColumnSortSpecs = extern struct {
    column_user_id: ID,            // User id of the column (if specified by a TableSetupColumn() call)
    column_index: S16,             // Index of the column
    sort_order: S16,               // Index within parent ImGuiTableSortSpecs (always stored in order starting from 0, tables sorted on a single criteria will always have a 0 here)
    sort_direction: SortDirection, // ImGuiSortDirection_Ascending or ImGuiSortDirection_Descending (you can use this or SortSign, whichever is more convenient for your sort function)
};

// Sorting specifications for a table (often handling sort specs for a single column, occasionally more)
// Obtained by calling TableGetSortSpecs().
// When 'SpecsDirty == true' you can sort your data. It will be true with sorting specs have changed since last call, or the first time.
// Make sure to set 'SpecsDirty = false' after sorting, else you may wastefully sort your data every frame!
pub const TableSortSpecs = extern struct {
    specs: ?[*]const TableColumnSortSpecs, // Pointer to sort spec array.
    specs_count: c_int,                    // Sort spec count. Most often 1. May be > 1 when ImGuiTableFlags_SortMulti is enabled. May be == 0 when ImGuiTableFlags_SortTristate is enabled.
    specs_dirty: bool,                     // Set to true when specs have changed since last time! Use this to sort again, then clear the flag.
};

// [Internal]
pub const TextFilter_ImGuiTextRange = extern struct {
    b: ?[*:0]const u8,
    e: ?[*:0]const u8,
};

// Helper: Parse and apply text filters. In format "aaaaa[,bbbb][,ccccc]"
pub const TextFilter = extern struct {
    input_buf: [256]c_char,
    filters: Vector(TextFilter_ImGuiTextRange),
    count_grep: c_int,
    pub const imGuiTextRange_empty = ImGuiTextFilter_ImGuiTextRange_empty;
    pub const imGuiTextRange_split = ImGuiTextFilter_ImGuiTextRange_split;
    pub const draw = ImGuiTextFilter_Draw;                                 // Helper calling InputText+Build
    pub const passFilter = ImGuiTextFilter_PassFilter;
    pub const build = ImGuiTextFilter_Build;
    pub const clear = ImGuiTextFilter_Clear;
    pub const isActive = ImGuiTextFilter_IsActive;
};

// Helper: Growable text buffer for logging/accumulating text
// (this could be called 'ImGuiTextBuilder' / 'ImGuiStringBuilder')
pub const TextBuffer = extern struct {
    buf: Vector(u8),
    pub const begin = ImGuiTextBuffer_begin;
    pub const end = ImGuiTextBuffer_end;           // Buf is zero-terminated, so end() will point on the zero-terminator
    pub const size = ImGuiTextBuffer_size;
    pub const empty = ImGuiTextBuffer_empty;
    pub const clear = ImGuiTextBuffer_clear;
    pub const reserve = ImGuiTextBuffer_reserve;
    pub const c_str = ImGuiTextBuffer_c_str;
    pub const append = ImGuiTextBuffer_append;
    pub const appendf = ImGuiTextBuffer_appendf;
    pub const appendfv = ImGuiTextBuffer_appendfv;
};

// [Internal]
pub const Storage_ImGuiStoragePair = extern struct {
    key: ID,
    __anonymous_type0: __anonymous_type0,
};

pub const __anonymous_type0 = extern struct {
    val_i: c_int,
    val_f: f32,
    val_p: ?*anyopaque,
};

// Helper: Key->Value storage
// Typically you don't have to worry about this since a storage is held within each Window.
// We use it to e.g. store collapse state for a tree (Int 0/1)
// This is optimized for efficient lookup (dichotomy into a contiguous buffer) and rare insertion (typically tied to user interactions aka max once a frame)
// You can use it as custom user storage for temporary values. Declare your own storage if, for example:
// - You want to manipulate the open/close state of a particular sub-tree in your interface (tree node uses Int 0/1 to store their state).
// - You want to store custom debug data easily without adding or editing structures in your code (probably not efficient, but convenient)
// Types are NOT stored, so it is up to you to make sure your Key don't collide with different types.
pub const Storage = extern struct {
    data: Vector(Storage_ImGuiStoragePair),
    // - Get***() functions find pair, never add/allocate. Pairs are sorted so a query is O(log N)
    // - Set***() functions find pair, insertion on demand if missing.
    // - Sorted insertion is costly, paid once. A typical frame shouldn't need to insert any new pair.
    pub const clear = ImGuiStorage_Clear;
    pub const getInt = ImGuiStorage_GetInt;
    pub const setInt = ImGuiStorage_SetInt;
    pub const getBool = ImGuiStorage_GetBool;
    pub const setBool = ImGuiStorage_SetBool;
    pub const getFloat = ImGuiStorage_GetFloat;
    pub const setFloat = ImGuiStorage_SetFloat;
    pub const getVoidPtr = ImGuiStorage_GetVoidPtr;         // default_val is NULL
    pub const setVoidPtr = ImGuiStorage_SetVoidPtr;
    // - Get***Ref() functions finds pair, insert on demand if missing, return pointer. Useful if you intend to do Get+Set.
    // - References are only valid until a new value is added to the storage. Calling a Set***() function or a Get***Ref() function invalidates the pointer.
    // - A typical use case where this is convenient for quick hacking (e.g. add storage during a live Edit&Continue session if you can't modify existing struct)
    //      float* pvar = ImGui::GetFloatRef(key); ImGui::SliderFloat("var", pvar, 0, 100.0f); some_var += *pvar;
    pub const getIntRef = ImGuiStorage_GetIntRef;
    pub const getBoolRef = ImGuiStorage_GetBoolRef;
    pub const getFloatRef = ImGuiStorage_GetFloatRef;
    pub const getVoidPtrRef = ImGuiStorage_GetVoidPtrRef;
    // Use on your own storage if you know only integer are being stored (open/close all tree nodes)
    pub const setAllInt = ImGuiStorage_SetAllInt;
    // For quicker full rebuild of a storage (instead of an incremental one), you may add all your contents and then sort once.
    pub const buildSortByKey = ImGuiStorage_BuildSortByKey;
};

// Helper: Manually clip large list of items.
// If you have lots evenly spaced items and you have random access to the list, you can perform coarse
// clipping based on visibility to only submit items that are in view.
// The clipper calculates the range of visible items and advance the cursor to compensate for the non-visible items we have skipped.
// (Dear ImGui already clip items based on their bounds but: it needs to first layout the item to do so, and generally
//  fetching/submitting your own data incurs additional cost. Coarse clipping using ImGuiListClipper allows you to easily
//  scale using lists with tens of thousands of items without a problem)
// Usage:
//   ImGuiListClipper clipper;
//   clipper.Begin(1000);         // We have 1000 elements, evenly spaced.
//   while (clipper.Step())
//       for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
//           ImGui::Text("line number %d", i);
// Generally what happens is:
// - Clipper lets you process the first element (DisplayStart = 0, DisplayEnd = 1) regardless of it being visible or not.
// - User code submit that one element.
// - Clipper can measure the height of the first element
// - Clipper calculate the actual range of elements to display based on the current clipping rectangle, position the cursor before the first visible element.
// - User code submit visible elements.
// - The clipper also handles various subtleties related to keyboard/gamepad navigation, wrapping etc.
pub const ListClipper = extern struct {
    ctx: ?*Context,         // Parent UI context
    display_start: c_int,   // First item to display, updated by each call to Step()
    display_end: c_int,     // End of items to display (exclusive)
    items_count: c_int,     // [Internal] Number of items
    items_height: f32,      // [Internal] Height of item after a first step and item submission can calculate it
    start_pos_y: f32,       // [Internal] Cursor position at the time of Begin() or after table frozen rows are all processed
    temp_data: ?*anyopaque, // [Internal] Internal data
    pub const begin = ImGuiListClipper_Begin;
    pub const end = ImGuiListClipper_End;                                 // Automatically called on the last call of Step() that returns false.
    pub const step = ImGuiListClipper_Step;                               // Call until it returns false. The DisplayStart/DisplayEnd fields will be set and you can process/draw those items.
    // Call IncludeItemByIndex() or IncludeItemsByIndex() *BEFORE* first call to Step() if you need a range of items to not be clipped, regardless of their visibility.
    // (Due to alignment / padding of certain items it is possible that an extra item may be included on either end of the display range).
    pub const includeItemByIndex = ImGuiListClipper_IncludeItemByIndex;
    pub const includeItemsByIndex = ImGuiListClipper_IncludeItemsByIndex; // item_end is exclusive e.g. use (42, 42+1) to make item 42 never clipped.
};

// Helper: ImColor() implicitly converts colors to either ImU32 (packed 4x1 byte) or ImVec4 (4x1 float)
// Prefer using IM_COL32() macros if you want a guaranteed compile-time ImU32 for usage with ImDrawList API.
// **Avoid storing ImColor! Store either u32 of ImVec4. This is not a full-featured color class. MAY OBSOLETE.
// **None of the ImGui API are using ImColor directly but you can use it as a convenience to pass colors in either ImU32 or ImVec4 formats. Explicitly cast to ImU32 or ImVec4 if needed.
pub const Color = extern struct {
    value: Vec4,
    // FIXME-OBSOLETE: May need to obsolete/cleanup those helpers.
    pub const setHSV = ImColor_SetHSV;
    pub const hSV = ImColor_HSV;
};

// Typically, 1 command = 1 GPU draw call (unless command is a callback)
// - VtxOffset: When 'io.BackendFlags & ImGuiBackendFlags_RendererHasVtxOffset' is enabled,
//   this fields allow us to render meshes larger than 64K vertices while keeping 16-bit indices.
//   Backends made for <1.71. will typically ignore the VtxOffset fields.
// - The ClipRect/TextureId/VtxOffset fields must be contiguous as we memcmp() them together (this is asserted for).
pub const DrawCmd = extern struct {
    clip_rect: Vec4,                 // 4*4  // Clipping rectangle (x1, y1, x2, y2). Subtract ImDrawData->DisplayPos to get clipping rectangle in "viewport" coordinates
    texture_id: TextureID,           // 4-8  // User-provided texture ID. Set by user in ImfontAtlas::SetTexID() for fonts or passed to Image*() functions. Ignore if never using images or multiple fonts atlas.
    vtx_offset: c_uint,              // 4    // Start offset in vertex buffer. ImGuiBackendFlags_RendererHasVtxOffset: always 0, otherwise may be >0 to support meshes larger than 64K vertices with 16-bit indices.
    idx_offset: c_uint,              // 4    // Start offset in index buffer.
    elem_count: c_uint,              // 4    // Number of indices (multiple of 3) to be rendered as triangles. Vertices are stored in the callee ImDrawList's vtx_buffer[] array, indices in idx_buffer[].
    user_callback: DrawCallback,     // 4-8  // If != NULL, call the function instead of rendering the vertices. clip_rect and texture_id will be set normally.
    user_callback_data: ?*anyopaque, // 4-8  // The draw callback code can access this.
    // Since 1.83: returns ImTextureID associated with this draw call. Warning: DO NOT assume this is always same as 'TextureId' (we will change this function for an upcoming feature)
    pub const getTexID = ImDrawCmd_GetTexID;
};

pub const DrawVert = extern struct {
    pos: Vec2,
    uv: Vec2,
    col: U32,
};

// [Internal] For use by ImDrawList
pub const DrawCmdHeader = extern struct {
    clip_rect: Vec4,
    texture_id: TextureID,
    vtx_offset: c_uint,
};

// [Internal] For use by ImDrawListSplitter
pub const DrawChannel = extern struct {
    _cmd_buffer: Vector(DrawCmd),
    _idx_buffer: Vector(DrawIdx),
};

// Split/Merge functions are used to split the draw list into different layers which can be drawn into out of order.
// This is used by the Columns/Tables API, so items of each column can be batched together in a same draw call.
pub const DrawListSplitter = extern struct {
    _current: c_int,                // Current channel number (0)
    _count: c_int,                  // Number of active channels (1+)
    _channels: Vector(DrawChannel), // Draw channels (not resized down so _Count might be < Channels.Size)
    pub const clear = ImDrawListSplitter_Clear;                         // Do not clear Channels[] so our allocations are reused next frame
    pub const clearFreeMemory = ImDrawListSplitter_ClearFreeMemory;
    pub const split = ImDrawListSplitter_Split;
    pub const merge = ImDrawListSplitter_Merge;
    pub const setCurrentChannel = ImDrawListSplitter_SetCurrentChannel;
};

// Draw command list
// This is the low-level list of polygons that ImGui:: functions are filling. At the end of the frame,
// all command lists are passed to your ImGuiIO::RenderDrawListFn function for rendering.
// Each dear imgui window contains its own ImDrawList. You can use ImGui::GetWindowDrawList() to
// access the current window draw list and draw custom primitives.
// You can interleave normal ImGui:: calls and adding primitives to the current draw list.
// In single viewport mode, top-left is == GetMainViewport()->Pos (generally 0,0), bottom-right is == GetMainViewport()->Pos+Size (generally io.DisplaySize).
// You are totally free to apply whatever transformation matrix to want to the data (depending on the use of the transformation you may want to apply it to ClipRect as well!)
// Important: Primitives are always added to the list and not culled (culling is done at higher-level by ImGui:: functions), if you use this API a lot consider coarse culling your drawn objects.
pub const DrawList = extern struct {
    // This is what you have to render
    cmd_buffer: Vector(DrawCmd),          // Draw commands. Typically 1 command = 1 GPU draw call, unless the command is a callback.
    idx_buffer: Vector(DrawIdx),          // Index buffer. Each command consume ImDrawCmd::ElemCount of those
    vtx_buffer: Vector(DrawVert),         // Vertex buffer.
    flags: DrawListFlags,                 // Flags, you may poke into these to adjust anti-aliasing settings per-primitive.
    // [Internal, used while building lists]
    _vtx_current_idx: c_uint,             // [Internal] generally == VtxBuffer.Size unless we are past 64K vertices, in which case this gets reset to 0.
    _data: ?*DrawListSharedData,          // Pointer to shared draw data (you can use ImGui::GetDrawListSharedData() to get the one from current ImGui context)
    _owner_name: ?[*:0]const u8,          // Pointer to owner window's name for debugging
    _vtx_write_ptr: ?[*]DrawVert,         // [Internal] point within VtxBuffer.Data after each add command (to avoid using the ImVector<> operators too much)
    _idx_write_ptr: ?[*]DrawIdx,          // [Internal] point within IdxBuffer.Data after each add command (to avoid using the ImVector<> operators too much)
    _clip_rect_stack: Vector(Vec4),       // [Internal]
    _texture_id_stack: Vector(TextureID), // [Internal]
    _path: Vector(Vec2),                  // [Internal] current path building
    _cmd_header: DrawCmdHeader,           // [Internal] template of active commands. Fields should match those of CmdBuffer.back().
    _splitter: DrawListSplitter,          // [Internal] for channels api (note: prefer using your own persistent instance of ImDrawListSplitter!)
    _fringe_scale: f32,                   // [Internal] anti-alias fringe is scaled by this value, this helps to keep things sharp while zooming at vertex buffer content
    pub const pushClipRect = ImDrawList_PushClipRect;                              // Render-level scissoring. This is passed down to your render function but not used for CPU-side coarse clipping. Prefer using higher-level ImGui::PushClipRect() to affect logic (hit-testing and widget culling)
    pub const pushClipRectFullScreen = ImDrawList_PushClipRectFullScreen;
    pub const popClipRect = ImDrawList_PopClipRect;
    pub const pushTextureID = ImDrawList_PushTextureID;
    pub const popTextureID = ImDrawList_PopTextureID;
    pub const getClipRectMin = ImDrawList_GetClipRectMin;
    pub const getClipRectMax = ImDrawList_GetClipRectMax;
    // Primitives
    // - Filled shapes must always use clockwise winding order. The anti-aliasing fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
    // - For rectangular primitives, "p_min" and "p_max" represent the upper-left and lower-right corners.
    // - For circle primitives, use "num_segments == 0" to automatically calculate tessellation (preferred).
    //   In older versions (until Dear ImGui 1.77) the AddCircle functions defaulted to num_segments == 12.
    //   In future versions we will use textures to provide cheaper and higher-quality circles.
    //   Use AddNgon() and AddNgonFilled() functions if you need to guarantee a specific number of sides.
    pub const addLine = ImDrawList_AddLine;                                        // Implied thickness = 1.0f
    pub const addLineEx = ImDrawList_AddLineEx;
    pub const addRect = ImDrawList_AddRect;                                        // Implied rounding = 0.0f, flags = 0, thickness = 1.0f
    pub const addRectEx = ImDrawList_AddRectEx;                                    // a: upper-left, b: lower-right (== upper-left + size)
    pub const addRectFilled = ImDrawList_AddRectFilled;                            // Implied rounding = 0.0f, flags = 0
    pub const addRectFilledEx = ImDrawList_AddRectFilledEx;                        // a: upper-left, b: lower-right (== upper-left + size)
    pub const addRectFilledMultiColor = ImDrawList_AddRectFilledMultiColor;
    pub const addQuad = ImDrawList_AddQuad;                                        // Implied thickness = 1.0f
    pub const addQuadEx = ImDrawList_AddQuadEx;
    pub const addQuadFilled = ImDrawList_AddQuadFilled;
    pub const addTriangle = ImDrawList_AddTriangle;                                // Implied thickness = 1.0f
    pub const addTriangleEx = ImDrawList_AddTriangleEx;
    pub const addTriangleFilled = ImDrawList_AddTriangleFilled;
    pub const addCircle = ImDrawList_AddCircle;                                    // Implied num_segments = 0, thickness = 1.0f
    pub const addCircleEx = ImDrawList_AddCircleEx;
    pub const addCircleFilled = ImDrawList_AddCircleFilled;
    pub const addNgon = ImDrawList_AddNgon;                                        // Implied thickness = 1.0f
    pub const addNgonEx = ImDrawList_AddNgonEx;
    pub const addNgonFilled = ImDrawList_AddNgonFilled;
    pub const addText = ImDrawList_AddText;                                        // Implied text_end = NULL
    pub const addTextEx = ImDrawList_AddTextEx;
    pub const addTextImFontPtr = ImDrawList_AddTextImFontPtr;                      // Implied text_end = NULL, wrap_width = 0.0f, cpu_fine_clip_rect = NULL
    pub const addTextImFontPtrEx = ImDrawList_AddTextImFontPtrEx;
    pub const addPolyline = ImDrawList_AddPolyline;
    pub const addConvexPolyFilled = ImDrawList_AddConvexPolyFilled;
    pub const addBezierCubic = ImDrawList_AddBezierCubic;                          // Cubic Bezier (4 control points)
    pub const addBezierQuadratic = ImDrawList_AddBezierQuadratic;                  // Quadratic Bezier (3 control points)
    // Image primitives
    // - Read FAQ to understand what ImTextureID is.
    // - "p_min" and "p_max" represent the upper-left and lower-right corners of the rectangle.
    // - "uv_min" and "uv_max" represent the normalized texture coordinates to use for those corners. Using (0,0)->(1,1) texture coordinates will generally display the entire texture.
    pub const addImage = ImDrawList_AddImage;                                      // Implied uv_min = ImVec2(0, 0), uv_max = ImVec2(1, 1), col = IM_COL32_WHITE
    pub const addImageEx = ImDrawList_AddImageEx;
    pub const addImageQuad = ImDrawList_AddImageQuad;                              // Implied uv1 = ImVec2(0, 0), uv2 = ImVec2(1, 0), uv3 = ImVec2(1, 1), uv4 = ImVec2(0, 1), col = IM_COL32_WHITE
    pub const addImageQuadEx = ImDrawList_AddImageQuadEx;
    pub const addImageRounded = ImDrawList_AddImageRounded;
    // Stateful path API, add points then finish with PathFillConvex() or PathStroke()
    // - Filled shapes must always use clockwise winding order. The anti-aliasing fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
    pub const pathClear = ImDrawList_PathClear;
    pub const pathLineTo = ImDrawList_PathLineTo;
    pub const pathLineToMergeDuplicate = ImDrawList_PathLineToMergeDuplicate;
    pub const pathFillConvex = ImDrawList_PathFillConvex;
    pub const pathStroke = ImDrawList_PathStroke;
    pub const pathArcTo = ImDrawList_PathArcTo;
    pub const pathArcToFast = ImDrawList_PathArcToFast;                            // Use precomputed angles for a 12 steps circle
    pub const pathBezierCubicCurveTo = ImDrawList_PathBezierCubicCurveTo;          // Cubic Bezier (4 control points)
    pub const pathBezierQuadraticCurveTo = ImDrawList_PathBezierQuadraticCurveTo;  // Quadratic Bezier (3 control points)
    pub const pathRect = ImDrawList_PathRect;
    // Advanced
    pub const addCallback = ImDrawList_AddCallback;                                // Your rendering function must check for 'UserCallback' in ImDrawCmd and call the function instead of rendering triangles.
    pub const addDrawCmd = ImDrawList_AddDrawCmd;                                  // This is useful if you need to forcefully create a new draw call (to allow for dependent rendering / blending). Otherwise primitives are merged into the same draw-call as much as possible
    pub const cloneOutput = ImDrawList_CloneOutput;                                // Create a clone of the CmdBuffer/IdxBuffer/VtxBuffer.
    // Advanced: Channels
    // - Use to split render into layers. By switching channels to can render out-of-order (e.g. submit FG primitives before BG primitives)
    // - Use to minimize draw calls (e.g. if going back-and-forth between multiple clipping rectangles, prefer to append into separate channels then merge at the end)
    // - This API shouldn't have been in ImDrawList in the first place!
    //   Prefer using your own persistent instance of ImDrawListSplitter as you can stack them.
    //   Using the ImDrawList::ChannelsXXXX you cannot stack a split over another.
    pub const channelsSplit = ImDrawList_ChannelsSplit;
    pub const channelsMerge = ImDrawList_ChannelsMerge;
    pub const channelsSetCurrent = ImDrawList_ChannelsSetCurrent;
    // Advanced: Primitives allocations
    // - We render triangles (three vertices)
    // - All primitives needs to be reserved via PrimReserve() beforehand.
    pub const primReserve = ImDrawList_PrimReserve;
    pub const primUnreserve = ImDrawList_PrimUnreserve;
    pub const primRect = ImDrawList_PrimRect;                                      // Axis aligned rectangle (composed of two triangles)
    pub const primRectUV = ImDrawList_PrimRectUV;
    pub const primQuadUV = ImDrawList_PrimQuadUV;
    pub const primWriteVtx = ImDrawList_PrimWriteVtx;
    pub const primWriteIdx = ImDrawList_PrimWriteIdx;
    pub const primVtx = ImDrawList_PrimVtx;                                        // Write vertex with unique index
    // [Internal helpers]
    pub const resetForNewFrame = ImDrawList__ResetForNewFrame;
    pub const clearFreeMemory = ImDrawList__ClearFreeMemory;
    pub const popUnusedDrawCmd = ImDrawList__PopUnusedDrawCmd;
    pub const tryMergeDrawCmds = ImDrawList__TryMergeDrawCmds;
    pub const onChangedClipRect = ImDrawList__OnChangedClipRect;
    pub const onChangedTextureID = ImDrawList__OnChangedTextureID;
    pub const onChangedVtxOffset = ImDrawList__OnChangedVtxOffset;
    pub const calcCircleAutoSegmentCount = ImDrawList__CalcCircleAutoSegmentCount;
    pub const pathArcToFastEx = ImDrawList__PathArcToFastEx;
    pub const pathArcToN = ImDrawList__PathArcToN;
};

// All draw data to render a Dear ImGui frame
// (NB: the style and the naming convention here is a little inconsistent, we currently preserve them for backward compatibility purpose,
// as this is one of the oldest structure exposed by the library! Basically, ImDrawList == CmdList)
pub const DrawData = extern struct {
    valid: bool,                  // Only valid after Render() is called and before the next NewFrame() is called.
    cmd_lists_count: c_int,       // Number of ImDrawList* to render
    total_idx_count: c_int,       // For convenience, sum of all ImDrawList's IdxBuffer.Size
    total_vtx_count: c_int,       // For convenience, sum of all ImDrawList's VtxBuffer.Size
    cmd_lists: Vector(*DrawList), // Array of ImDrawList* to render. The ImDrawLists are owned by ImGuiContext and only pointed to from here.
    display_pos: Vec2,            // Top-left position of the viewport to render (== top-left of the orthogonal projection matrix to use) (== GetMainViewport()->Pos for the main viewport, == (0.0) in most single-viewport applications)
    display_size: Vec2,           // Size of the viewport to render (== GetMainViewport()->Size for the main viewport, == io.DisplaySize in most single-viewport applications)
    framebuffer_scale: Vec2,      // Amount of pixels for each unit of DisplaySize. Based on io.DisplayFramebufferScale. Generally (1,1) on normal display, (2,2) on OSX with Retina display.
    owner_viewport: ?*Viewport,   // Viewport carrying the ImDrawData instance, might be of use to the renderer (generally not).
    pub const clear = ImDrawData_Clear;
    pub const addDrawList = ImDrawData_AddDrawList;             // Helper to add an external draw list into an existing ImDrawData.
    pub const deIndexAllBuffers = ImDrawData_DeIndexAllBuffers; // Helper to convert all buffers from indexed to non-indexed, in case you cannot render indexed. Note: this is slow and most likely a waste of resources. Always prefer indexed rendering!
    pub const scaleClipRects = ImDrawData_ScaleClipRects;       // Helper to scale the ClipRect field of each ImDrawCmd. Use if your final output buffer is at a different scale than Dear ImGui expects, or if there is a difference between your window resolution and framebuffer resolution.
};

pub const FontConfig = extern struct {
    font_data: ?*anyopaque,         //          // TTF/OTF data
    font_data_size: c_int,          //          // TTF/OTF data size
    font_data_owned_by_atlas: bool, // true     // TTF/OTF data ownership taken by the container ImFontAtlas (will delete memory itself).
    font_no: c_int,                 // 0        // Index of font within TTF/OTF file
    size_pixels: f32,               //          // Size in pixels for rasterizer (more or less maps to the resulting font height).
    oversample_h: c_int,            // 2        // Rasterize at higher quality for sub-pixel positioning. Note the difference between 2 and 3 is minimal. You can reduce this to 1 for large glyphs save memory. Read https://github.com/nothings/stb/blob/master/tests/oversample/README.md for details.
    oversample_v: c_int,            // 1        // Rasterize at higher quality for sub-pixel positioning. This is not really useful as we don't use sub-pixel positions on the Y axis.
    pixel_snap_h: bool,             // false    // Align every glyph to pixel boundary. Useful e.g. if you are merging a non-pixel aligned font with the default font. If enabled, you can set OversampleH/V to 1.
    glyph_extra_spacing: Vec2,      // 0, 0     // Extra spacing (in pixels) between glyphs. Only X axis is supported for now.
    glyph_offset: Vec2,             // 0, 0     // Offset all glyphs from this font input.
    glyph_ranges: ?[*]const Wchar,  // NULL     // THE ARRAY DATA NEEDS TO PERSIST AS LONG AS THE FONT IS ALIVE. Pointer to a user-provided list of Unicode range (2 value per range, values are inclusive, zero-terminated list).
    glyph_min_advance_x: f32,       // 0        // Minimum AdvanceX for glyphs, set Min to align font icons, set both Min/Max to enforce mono-space font
    glyph_max_advance_x: f32,       // FLT_MAX  // Maximum AdvanceX for glyphs
    merge_mode: bool,               // false    // Merge into previous ImFont, so you can combine multiple inputs font into one ImFont (e.g. ASCII font + icons + Japanese glyphs). You may want to use GlyphOffset.y when merge font of different heights.
    font_builder_flags: c_uint,     // 0        // Settings for custom font builder. THIS IS BUILDER IMPLEMENTATION DEPENDENT. Leave as zero if unsure.
    rasterizer_multiply: f32,       // 1.0f     // Brighten (>1.0f) or darken (<1.0f) font output. Brightening small fonts may be a good workaround to make them more readable.
    ellipsis_char: Wchar,           // -1       // Explicitly specify unicode codepoint of ellipsis character. When fonts are being merged first specified ellipsis will be used.
    // [Internal]
    name: [40]c_char,               // Name (strictly to ease debugging)
    dst_font: ?*Font,
};

// Hold rendering data for one glyph.
// (Note: some language parsers may fail to convert the 31+1 bitfield members, in this case maybe drop store a single u32 or we can rework this)
pub const FontGlyph = extern struct {
    colored: c_uint,   // Flag to indicate glyph is colored and should generally ignore tinting (make it usable with no shift on little-endian as this is used in loops)
    visible: c_uint,   // Flag to indicate glyph has no visible pixels (e.g. space). Allow early out when rendering.
    codepoint: c_uint, // 0x0000..0x10FFFF
    advance_x: f32,    // Distance to next character (= data from font + ImFontConfig::GlyphExtraSpacing.x baked in)
    x0: f32,           // Glyph corners
    y0: f32,           // Glyph corners
    x1: f32,           // Glyph corners
    y1: f32,           // Glyph corners
    u0: f32,           // Texture coordinates
    v0: f32,           // Texture coordinates
    u1: f32,           // Texture coordinates
    v1: f32,           // Texture coordinates
};

// Helper to build glyph ranges from text/string data. Feed your application strings/characters to it then call BuildRanges().
// This is essentially a tightly packed of vector of 64k booleans = 8KB storage.
pub const FontGlyphRangesBuilder = extern struct {
    used_chars: Vector(U32), // Store 1-bit per Unicode code point (0=unused, 1=used)
    pub const clear = ImFontGlyphRangesBuilder_Clear;
    pub const getBit = ImFontGlyphRangesBuilder_GetBit;           // Get bit n in the array
    pub const setBit = ImFontGlyphRangesBuilder_SetBit;           // Set bit n in the array
    pub const addChar = ImFontGlyphRangesBuilder_AddChar;         // Add character
    pub const addText = ImFontGlyphRangesBuilder_AddText;         // Add string (each character of the UTF-8 string are added)
    pub const addRanges = ImFontGlyphRangesBuilder_AddRanges;     // Add ranges, e.g. builder.AddRanges(ImFontAtlas::GetGlyphRangesDefault()) to force add all of ASCII/Latin+Ext
    pub const buildRanges = ImFontGlyphRangesBuilder_BuildRanges; // Output new ranges (ImVector_Construct()/ImVector_Destruct() can be used to safely construct out_ranges)
};

// See ImFontAtlas::AddCustomRectXXX functions.
pub const FontAtlasCustomRect = extern struct {
    width: c_ushort,      // Input    // Desired rectangle dimension
    height: c_ushort,     // Input    // Desired rectangle dimension
    x: c_ushort,          // Output   // Packed position in Atlas
    y: c_ushort,          // Output   // Packed position in Atlas
    glyph_id: c_uint,     // Input    // For custom font glyphs only (ID < 0x110000)
    glyph_advance_x: f32, // Input    // For custom font glyphs only: glyph xadvance
    glyph_offset: Vec2,   // Input    // For custom font glyphs only: glyph display offset
    font: ?*Font,         // Input    // For custom font glyphs only: target font
    pub const isPacked = ImFontAtlasCustomRect_IsPacked;
};

// Load and rasterize multiple TTF/OTF fonts into a same texture. The font atlas will build a single texture holding:
//  - One or more fonts.
//  - Custom graphics data needed to render the shapes needed by Dear ImGui.
//  - Mouse cursor shapes for software cursor rendering (unless setting 'Flags |= ImFontAtlasFlags_NoMouseCursors' in the font atlas).
// It is the user-code responsibility to setup/build the atlas, then upload the pixel data into a texture accessible by your graphics api.
//  - Optionally, call any of the AddFont*** functions. If you don't call any, the default font embedded in the code will be loaded for you.
//  - Call GetTexDataAsAlpha8() or GetTexDataAsRGBA32() to build and retrieve pixels data.
//  - Upload the pixels data into a texture within your graphics system (see imgui_impl_xxxx.cpp examples)
//  - Call SetTexID(my_tex_id); and pass the pointer/identifier to your texture in a format natural to your graphics API.
//    This value will be passed back to you during rendering to identify the texture. Read FAQ entry about ImTextureID for more details.
// Common pitfalls:
// - If you pass a 'glyph_ranges' array to AddFont*** functions, you need to make sure that your array persist up until the
//   atlas is build (when calling GetTexData*** or Build()). We only copy the pointer, not the data.
// - Important: By default, AddFontFromMemoryTTF() takes ownership of the data. Even though we are not writing to it, we will free the pointer on destruction.
//   You can set font_cfg->FontDataOwnedByAtlas=false to keep ownership of your data and it won't be freed,
// - Even though many functions are suffixed with "TTF", OTF data is supported just as well.
// - This is an old API and it is currently awkward for those and various other reasons! We will address them in the future!
pub const FontAtlas = extern struct {
    flags: FontAtlasFlags,                              // Build flags (see ImFontAtlasFlags_)
    tex_id: TextureID,                                  // User data to refer to the texture once it has been uploaded to user's graphic systems. It is passed back to you during rendering via the ImDrawCmd structure.
    tex_desired_width: c_int,                           // Texture width desired by user before Build(). Must be a power-of-two. If have many glyphs your graphics API have texture size restrictions you may want to increase texture width to decrease height.
    tex_glyph_padding: c_int,                           // Padding between glyphs within texture in pixels. Defaults to 1. If your rendering method doesn't rely on bilinear filtering you may set this to 0 (will also need to set AntiAliasedLinesUseTex = false).
    locked: bool,                                       // Marked as Locked by ImGui::NewFrame() so attempt to modify the atlas will assert.
    user_data: ?*anyopaque,                             // Store your own atlas related user-data (if e.g. you have multiple font atlas).
    // [Internal]
    // NB: Access texture data via GetTexData*() calls! Which will setup a default font for you.
    tex_ready: bool,                                    // Set when texture was built matching current font input
    tex_pixels_use_colors: bool,                        // Tell whether our texture data is known to use colors (rather than just alpha channel), in order to help backend select a format.
    tex_pixels_alpha8: ?[*]c_char,                      // 1 component per pixel, each component is unsigned 8-bit. Total size = TexWidth * TexHeight
    tex_pixels_rgba32: ?[*]c_uint,                      // 4 component per pixel, each component is unsigned 8-bit. Total size = TexWidth * TexHeight * 4
    tex_width: c_int,                                   // Texture width calculated during Build().
    tex_height: c_int,                                  // Texture height calculated during Build().
    tex_uv_scale: Vec2,                                 // = (1.0f/TexWidth, 1.0f/TexHeight)
    tex_uv_white_pixel: Vec2,                           // Texture coordinates to a white pixel
    fonts: Vector(*Font),                               // Hold all the fonts returned by AddFont*. Fonts[0] is the default font upon calling ImGui::NewFrame(), use ImGui::PushFont()/PopFont() to change the current font.
    custom_rects: Vector(FontAtlasCustomRect),          // Rectangles for packing custom texture data into the atlas.
    config_data: Vector(FontConfig),                    // Configuration data
    tex_uv_lines: [DRAWLIST_TEX_LINES_WIDTH_MAX+1]Vec4, // UVs for baked anti-aliased lines
    // [Internal] Font builder
    font_builder_io: ?*const FontBuilderIO,             // Opaque interface to a font builder (default to stb_truetype, can be changed to use FreeType by defining IMGUI_ENABLE_FREETYPE).
    font_builder_flags: c_uint,                         // Shared flags (for all fonts) for custom font builder. THIS IS BUILD IMPLEMENTATION DEPENDENT. Per-font override is also available in ImFontConfig.
    // [Internal] Packing data
    pack_id_mouse_cursors: c_int,                       // Custom texture rectangle ID for white pixel and mouse cursors
    pack_id_lines: c_int,                               // Custom texture rectangle ID for baked anti-aliased lines
    pub const addFont = ImFontAtlas_AddFont;
    pub const addFontDefault = ImFontAtlas_AddFontDefault;
    pub const addFontFromFileTTF = ImFontAtlas_AddFontFromFileTTF;
    pub const addFontFromMemoryTTF = ImFontAtlas_AddFontFromMemoryTTF;                                   // Note: Transfer ownership of 'ttf_data' to ImFontAtlas! Will be deleted after destruction of the atlas. Set font_cfg->FontDataOwnedByAtlas=false to keep ownership of your data and it won't be freed.
    pub const addFontFromMemoryCompressedTTF = ImFontAtlas_AddFontFromMemoryCompressedTTF;               // 'compressed_font_data' still owned by caller. Compress with binary_to_compressed_c.cpp.
    pub const addFontFromMemoryCompressedBase85TTF = ImFontAtlas_AddFontFromMemoryCompressedBase85TTF;   // 'compressed_font_data_base85' still owned by caller. Compress with binary_to_compressed_c.cpp with -base85 parameter.
    pub const clearInputData = ImFontAtlas_ClearInputData;                                               // Clear input data (all ImFontConfig structures including sizes, TTF data, glyph ranges, etc.) = all the data used to build the texture and fonts.
    pub const clearTexData = ImFontAtlas_ClearTexData;                                                   // Clear output texture data (CPU side). Saves RAM once the texture has been copied to graphics memory.
    pub const clearFonts = ImFontAtlas_ClearFonts;                                                       // Clear output font data (glyphs storage, UV coordinates).
    pub const clear = ImFontAtlas_Clear;                                                                 // Clear all input and output.
    // Build atlas, retrieve pixel data.
    // User is in charge of copying the pixels into graphics memory (e.g. create a texture with your engine). Then store your texture handle with SetTexID().
    // The pitch is always = Width * BytesPerPixels (1 or 4)
    // Building in RGBA32 format is provided for convenience and compatibility, but note that unless you manually manipulate or copy color data into
    // the texture (e.g. when using the AddCustomRect*** api), then the RGB pixels emitted will always be white (~75% of memory/bandwidth waste.
    pub const build = ImFontAtlas_Build;                                                                 // Build pixels data. This is called automatically for you by the GetTexData*** functions.
    pub const getTexDataAsAlpha8 = ImFontAtlas_GetTexDataAsAlpha8;                                       // 1 byte per-pixel
    pub const getTexDataAsRGBA32 = ImFontAtlas_GetTexDataAsRGBA32;                                       // 4 bytes-per-pixel
    pub const isBuilt = ImFontAtlas_IsBuilt;                                                             // Bit ambiguous: used to detect when user didn't build texture but effectively we should check TexID != 0 except that would be backend dependent...
    pub const setTexID = ImFontAtlas_SetTexID;
    // Helpers to retrieve list of common Unicode ranges (2 value per range, values are inclusive, zero-terminated list)
    // NB: Make sure that your string are UTF-8 and NOT in your local code page.
    // Read https://github.com/ocornut/imgui/blob/master/docs/FONTS.md/#about-utf-8-encoding for details.
    // NB: Consider using ImFontGlyphRangesBuilder to build glyph ranges from textual data.
    pub const getGlyphRangesDefault = ImFontAtlas_GetGlyphRangesDefault;                                 // Basic Latin, Extended Latin
    pub const getGlyphRangesGreek = ImFontAtlas_GetGlyphRangesGreek;                                     // Default + Greek and Coptic
    pub const getGlyphRangesKorean = ImFontAtlas_GetGlyphRangesKorean;                                   // Default + Korean characters
    pub const getGlyphRangesJapanese = ImFontAtlas_GetGlyphRangesJapanese;                               // Default + Hiragana, Katakana, Half-Width, Selection of 2999 Ideographs
    pub const getGlyphRangesChineseFull = ImFontAtlas_GetGlyphRangesChineseFull;                         // Default + Half-Width + Japanese Hiragana/Katakana + full set of about 21000 CJK Unified Ideographs
    pub const getGlyphRangesChineseSimplifiedCommon = ImFontAtlas_GetGlyphRangesChineseSimplifiedCommon; // Default + Half-Width + Japanese Hiragana/Katakana + set of 2500 CJK Unified Ideographs for common simplified Chinese
    pub const getGlyphRangesCyrillic = ImFontAtlas_GetGlyphRangesCyrillic;                               // Default + about 400 Cyrillic characters
    pub const getGlyphRangesThai = ImFontAtlas_GetGlyphRangesThai;                                       // Default + Thai characters
    pub const getGlyphRangesVietnamese = ImFontAtlas_GetGlyphRangesVietnamese;                           // Default + Vietnamese characters
    // You can request arbitrary rectangles to be packed into the atlas, for your own purposes.
    // - After calling Build(), you can query the rectangle position and render your pixels.
    // - If you render colored output, set 'atlas->TexPixelsUseColors = true' as this may help some backends decide of prefered texture format.
    // - You can also request your rectangles to be mapped as font glyph (given a font + Unicode point),
    //   so you can render e.g. custom colorful icons and use them as regular glyphs.
    // - Read docs/FONTS.md for more details about using colorful icons.
    // - Note: this API may be redesigned later in order to support multi-monitor varying DPI settings.
    pub const addCustomRectRegular = ImFontAtlas_AddCustomRectRegular;
    pub const addCustomRectFontGlyph = ImFontAtlas_AddCustomRectFontGlyph;
    pub const getCustomRectByIndex = ImFontAtlas_GetCustomRectByIndex;
    // [Internal]
    pub const calcCustomRectUV = ImFontAtlas_CalcCustomRectUV;
    pub const getMouseCursorTexData = ImFontAtlas_GetMouseCursorTexData;
};

// Font runtime data and rendering
// ImFontAtlas automatically loads a default embedded font for you when you call GetTexDataAsAlpha8() or GetTexDataAsRGBA32().
pub const Font = extern struct {
    // Members: Hot ~20/24 bytes (for CalcTextSize)
    index_advance_x: Vector(f32),                           // 12-16 // out //            // Sparse. Glyphs->AdvanceX in a directly indexable way (cache-friendly for CalcTextSize functions which only this this info, and are often bottleneck in large UI).
    fallback_advance_x: f32,                                // 4     // out // = FallbackGlyph->AdvanceX
    font_size: f32,                                         // 4     // in  //            // Height of characters/line, set during loading (don't change after loading)
    // Members: Hot ~28/40 bytes (for CalcTextSize + render loop)
    index_lookup: Vector(Wchar),                            // 12-16 // out //            // Sparse. Index glyphs by Unicode code-point.
    glyphs: Vector(FontGlyph),                              // 12-16 // out //            // All glyphs.
    fallback_glyph: ?*const FontGlyph,                      // 4-8   // out // = FindGlyph(FontFallbackChar)
    // Members: Cold ~32/40 bytes
    container_atlas: ?*FontAtlas,                           // 4-8   // out //            // What we has been loaded into
    config_data: ?*const FontConfig,                        // 4-8   // in  //            // Pointer within ContainerAtlas->ConfigData
    config_data_count: c_short,                             // 2     // in  // ~ 1        // Number of ImFontConfig involved in creating this font. Bigger than 1 when merging multiple font sources into one ImFont.
    fallback_char: Wchar,                                   // 2     // out // = FFFD/'?' // Character used if a glyph isn't found.
    ellipsis_char: Wchar,                                   // 2     // out // = '...'/'.'// Character used for ellipsis rendering.
    ellipsis_char_count: c_short,                           // 1     // out // 1 or 3
    ellipsis_width: f32,                                    // 4     // out               // Width
    ellipsis_char_step: f32,                                // 4     // out               // Step between characters when EllipsisCount > 0
    dirty_lookup_tables: bool,                              // 1     // out //
    scale: f32,                                             // 4     // in  // = 1.f      // Base font scale, multiplied by the per-window font scale which you can adjust with SetWindowFontScale()
    ascent: f32,                                            // 4+4   // out //            // Ascent: distance from top to bottom of e.g. 'A' [0..FontSize]
    descent: f32,                                           // 4+4   // out //            // Ascent: distance from top to bottom of e.g. 'A' [0..FontSize]
    metrics_total_surface: c_int,                           // 4     // out //            // Total surface in pixels to get an idea of the font rasterization/texture cost (not exact, we approximate the cost of padding between glyphs)
    used4k_pages_map: [(UNICODE_CODEPOINT_MAX+1)/4096/8]U8, // 2 bytes if ImWchar=ImWchar16, 34 bytes if ImWchar==ImWchar32. Store 1-bit for each block of 4K codepoints that has one active glyph. This is mainly used to facilitate iterations across all used codepoints.
    pub const findGlyph = ImFont_FindGlyph;
    pub const findGlyphNoFallback = ImFont_FindGlyphNoFallback;
    pub const getCharAdvance = ImFont_GetCharAdvance;
    pub const isLoaded = ImFont_IsLoaded;
    pub const getDebugName = ImFont_GetDebugName;
    // 'max_width' stops rendering after a certain width (could be turned into a 2d size). FLT_MAX to disable.
    // 'wrap_width' enable automatic word-wrapping across multiple lines to fit into given width. 0.0f to disable.
    pub const calcTextSizeA = ImFont_CalcTextSizeA;                 // Implied text_end = NULL, remaining = NULL
    pub const calcTextSizeAEx = ImFont_CalcTextSizeAEx;             // utf8
    pub const calcWordWrapPositionA = ImFont_CalcWordWrapPositionA;
    pub const renderChar = ImFont_RenderChar;
    pub const renderText = ImFont_RenderText;
    // [Internal] Don't use!
    pub const buildLookupTable = ImFont_BuildLookupTable;
    pub const clearOutputData = ImFont_ClearOutputData;
    pub const growIndex = ImFont_GrowIndex;
    pub const addGlyph = ImFont_AddGlyph;
    pub const addRemapChar = ImFont_AddRemapChar;                   // Makes 'dst' character/glyph points to 'src' character/glyph. Currently needs to be called AFTER fonts have been built.
    pub const setGlyphVisible = ImFont_SetGlyphVisible;
    pub const isGlyphRangeUnused = ImFont_IsGlyphRangeUnused;
};

// - Currently represents the Platform Window created by the application which is hosting our Dear ImGui windows.
// - With multi-viewport enabled, we extend this concept to have multiple active viewports.
// - In the future we will extend this concept further to also represent Platform Monitor and support a "no main platform window" operation mode.
// - About Main Area vs Work Area:
//   - Main Area = entire viewport.
//   - Work Area = entire viewport minus sections used by main menu bars (for platform windows), or by task bar (for platform monitor).
//   - Windows are generally trying to stay within the Work Area of their host viewport.
pub const Viewport = extern struct {
    id: ID,                           // Unique identifier for the viewport
    flags: ViewportFlags,             // See ImGuiViewportFlags_
    pos: Vec2,                        // Main Area: Position of the viewport (Dear ImGui coordinates are the same as OS desktop/native coordinates)
    size: Vec2,                       // Main Area: Size of the viewport.
    work_pos: Vec2,                   // Work Area: Position of the viewport minus task bars, menus bars, status bars (>= Pos)
    work_size: Vec2,                  // Work Area: Size of the viewport minus task bars, menu bars, status bars (<= Size)
    dpi_scale: f32,                   // 1.0f = 96 DPI = No extra scale.
    parent_viewport_id: ID,           // (Advanced) 0: no parent. Instruct the platform backend to setup a parent/child relationship between platform windows.
    draw_data: ?*DrawData,            // The ImDrawData corresponding to this viewport. Valid after Render() and until the next call to NewFrame().
    // Platform/Backend Dependent Data
    // Our design separate the Renderer and Platform backends to facilitate combining default backends with each others.
    // When our create your own backend for a custom engine, it is possible that both Renderer and Platform will be handled
    // by the same system and you may not need to use all the UserData/Handle fields.
    // The library never uses those fields, they are merely storage to facilitate backend implementation.
    renderer_user_data: ?*anyopaque,  // void* to hold custom data structure for the renderer (e.g. swap chain, framebuffers etc.). generally set by your Renderer_CreateWindow function.
    platform_user_data: ?*anyopaque,  // void* to hold custom data structure for the OS / platform (e.g. windowing info, render context). generally set by your Platform_CreateWindow function.
    platform_handle: ?*anyopaque,     // void* for FindViewportByPlatformHandle(). (e.g. suggested to use natural platform handle such as HWND, GLFWWindow*, SDL_Window*)
    platform_handle_raw: ?*anyopaque, // void* to hold lower-level, platform-native window handle (under Win32 this is expected to be a HWND, unused for other platforms), when using an abstraction layer like GLFW or SDL (where PlatformHandle would be a SDL_Window*)
    platform_window_created: bool,    // Platform window has been created (Platform_CreateWindow() has been called). This is false during the first frame where a viewport is being created.
    platform_request_move: bool,      // Platform window requested move (e.g. window was moved by the OS / host window manager, authoritative position will be OS window position)
    platform_request_resize: bool,    // Platform window requested resize (e.g. window was resized by the OS / host window manager, authoritative size will be OS window size)
    platform_request_close: bool,     // Platform window requested closure (e.g. window was moved by the OS / host window manager, e.g. pressing ALT-F4)
    // Helpers
    pub const getCenter = ImGuiViewport_GetCenter;
    pub const getWorkCenter = ImGuiViewport_GetWorkCenter;
};

// (Optional) Access via ImGui::GetPlatformIO()
pub const PlatformIO = extern struct {
    // Platform function --------------------------------------------------- Called by -----
    platform_create_window: ?*const fn (?*Viewport) callconv(.C) void,                               // . . U . .  // Create a new platform window for the given viewport
    platform_destroy_window: ?*const fn (?*Viewport) callconv(.C) void,                              // N . U . D  //
    platform_show_window: ?*const fn (?*Viewport) callconv(.C) void,                                 // . . U . .  // Newly created windows are initially hidden so SetWindowPos/Size/Title can be called on them before showing the window
    platform_set_window_pos: ?*const fn (?*Viewport, Vec2) callconv(.C) void,                        // . . U . .  // Set platform window position (given the upper-left corner of client area)
    platform_get_window_pos: ?*const fn (?*Viewport) callconv(.C) Vec2,                              // N . . . .  //
    platform_set_window_size: ?*const fn (?*Viewport, Vec2) callconv(.C) void,                       // . . U . .  // Set platform window client area size (ignoring OS decorations such as OS title bar etc.)
    platform_get_window_size: ?*const fn (?*Viewport) callconv(.C) Vec2,                             // N . . . .  // Get platform window client area size
    platform_set_window_focus: ?*const fn (?*Viewport) callconv(.C) void,                            // N . . . .  // Move window to front and set input focus
    platform_get_window_focus: ?*const fn (?*Viewport) callconv(.C) bool,                            // . . U . .  //
    platform_get_window_minimized: ?*const fn (?*Viewport) callconv(.C) bool,                        // N . . . .  // Get platform window minimized state. When minimized, we generally won't attempt to get/set size and contents will be culled more easily
    platform_set_window_title: ?*const fn (?*Viewport, ?[*:0]const u8) callconv(.C) void,            // . . U . .  // Set platform window title (given an UTF-8 string)
    platform_set_window_alpha: ?*const fn (?*Viewport, f32) callconv(.C) void,                       // . . U . .  // (Optional) Setup global transparency (not per-pixel transparency)
    platform_update_window: ?*const fn (?*Viewport) callconv(.C) void,                               // . . U . .  // (Optional) Called by UpdatePlatformWindows(). Optional hook to allow the platform backend from doing general book-keeping every frame.
    platform_render_window: ?*const fn (?*Viewport, ?*anyopaque) callconv(.C) void,                  // . . . R .  // (Optional) Main rendering (platform side! This is often unused, or just setting a "current" context for OpenGL bindings). 'render_arg' is the value passed to RenderPlatformWindowsDefault().
    platform_swap_buffers: ?*const fn (?*Viewport, ?*anyopaque) callconv(.C) void,                   // . . . R .  // (Optional) Call Present/SwapBuffers (platform side! This is often unused!). 'render_arg' is the value passed to RenderPlatformWindowsDefault().
    platform_get_window_dpi_scale: ?*const fn (?*Viewport) callconv(.C) f32,                         // N . . . .  // (Optional) [BETA] FIXME-DPI: DPI handling: Return DPI scale for this viewport. 1.0f = 96 DPI.
    platform_on_changed_viewport: ?*const fn (?*Viewport) callconv(.C) void,                         // . F . . .  // (Optional) [BETA] FIXME-DPI: DPI handling: Called during Begin() every time the viewport we are outputting into changes, so backend has a chance to swap fonts to adjust style.
    platform_create_vk_surface: ?*const fn (?*Viewport, U64, ?*anyopaque, ?*U64) callconv(.C) c_int, // (Optional) For a Vulkan Renderer to call into Platform code (since the surface creation needs to tie them both).
    // (Optional) Renderer functions (e.g. DirectX, OpenGL, Vulkan)
    renderer_create_window: ?*const fn (?*Viewport) callconv(.C) void,                               // . . U . .  // Create swap chain, frame buffers etc. (called after Platform_CreateWindow)
    renderer_destroy_window: ?*const fn (?*Viewport) callconv(.C) void,                              // N . U . D  // Destroy swap chain, frame buffers etc. (called before Platform_DestroyWindow)
    renderer_set_window_size: ?*const fn (?*Viewport, Vec2) callconv(.C) void,                       // . . U . .  // Resize swap chain, frame buffers etc. (called after Platform_SetWindowSize)
    renderer_render_window: ?*const fn (?*Viewport, ?*anyopaque) callconv(.C) void,                  // . . . R .  // (Optional) Clear framebuffer, setup render target, then render the viewport->DrawData. 'render_arg' is the value passed to RenderPlatformWindowsDefault().
    renderer_swap_buffers: ?*const fn (?*Viewport, ?*anyopaque) callconv(.C) void,                   // . . . R .  // (Optional) Call Present/SwapBuffers. 'render_arg' is the value passed to RenderPlatformWindowsDefault().
    // (Optional) Monitor list
    // - Updated by: app/backend. Update every frame to dynamically support changing monitor or DPI configuration.
    // - Used by: dear imgui to query DPI info, clamp popups/tooltips within same monitor and not have them straddle monitors.
    monitors: Vector(PlatformMonitor),
    // Viewports list (the list is updated by calling ImGui::EndFrame or ImGui::Render)
    // (in the future we will attempt to organize this feature to remove the need for a "main viewport")
    viewports: Vector(*Viewport),                                                                    // Main viewports, followed by all secondary viewports.
};

// (Optional) This is required when enabling multi-viewport. Represent the bounds of each connected monitor/display and their DPI.
// We use this information for multiple DPI support + clamping the position of popups and tooltips so they don't straddle multiple monitors.
pub const PlatformMonitor = extern struct {
    main_pos: Vec2,               // Coordinates of the area displayed on this monitor (Min = upper left, Max = bottom right)
    main_size: Vec2,              // Coordinates of the area displayed on this monitor (Min = upper left, Max = bottom right)
    work_pos: Vec2,               // Coordinates without task bars / side bars / menu bars. Used to avoid positioning popups/tooltips inside this region. If you don't have this info, please copy the value for MainPos/MainSize.
    work_size: Vec2,              // Coordinates without task bars / side bars / menu bars. Used to avoid positioning popups/tooltips inside this region. If you don't have this info, please copy the value for MainPos/MainSize.
    dpi_scale: f32,               // 1.0f = 96 DPI
    platform_handle: ?*anyopaque, // Backend dependant data (e.g. HMONITOR, GLFWmonitor*, SDL Display Index, NSScreen*)
};

// (Optional) Support for IME (Input Method Editor) via the io.SetPlatformImeDataFn() function.
pub const PlatformImeData = extern struct {
    want_visible: bool,     // A widget wants the IME to be visible
    input_pos: Vec2,        // Position of the input cursor
    input_line_height: f32, // Line height
};

//-----------------------------------------------------------------------------
// API functions
//-----------------------------------------------------------------------------

pub fn setZigAllocator(allocator: *std.mem.Allocator) void {
    setAllocatorFunctions(zigAlloc, zigFree, allocator);
}
// Context creation and access
// - Each context create its own ImFontAtlas by default. You may instance one yourself and pass it to CreateContext() to share a font atlas between contexts.
// - DLL users: heaps and globals are not shared across DLL boundaries! You will need to call SetCurrentContext() + SetAllocatorFunctions()
//   for each static/DLL boundary you are calling from. Read "Context and Memory Allocators" section of imgui.cpp for details.
pub const createContext = ImGui_CreateContext;
pub const destroyContext = ImGui_DestroyContext;                                               // NULL = destroy current context
pub const getCurrentContext = ImGui_GetCurrentContext;
pub const setCurrentContext = ImGui_SetCurrentContext;
// Main
pub const getIO = ImGui_GetIO;                                                                 // access the IO structure (mouse/keyboard/gamepad inputs, time, various configuration options/flags)
pub const getStyle = ImGui_GetStyle;                                                           // access the Style structure (colors, sizes). Always use PushStyleCol(), PushStyleVar() to modify style mid-frame!
pub const newFrame = ImGui_NewFrame;                                                           // start a new Dear ImGui frame, you can submit any command from this point until Render()/EndFrame().
pub const endFrame = ImGui_EndFrame;                                                           // ends the Dear ImGui frame. automatically called by Render(). If you don't need to render data (skipping rendering) you may call EndFrame() without Render()... but you'll have wasted CPU already! If you don't need to render, better to not create any windows and not call NewFrame() at all!
pub const render = ImGui_Render;                                                               // ends the Dear ImGui frame, finalize the draw data. You can then get call GetDrawData().
pub const getDrawData = ImGui_GetDrawData;                                                     // valid after Render() and until the next call to NewFrame(). this is what you have to render.
// Demo, Debug, Information
pub const showDemoWindow = ImGui_ShowDemoWindow;                                               // create Demo window. demonstrate most ImGui features. call this to learn about the library! try to make it always available in your application!
pub const showMetricsWindow = ImGui_ShowMetricsWindow;                                         // create Metrics/Debugger window. display Dear ImGui internals: windows, draw commands, various internal state, etc.
pub const showDebugLogWindow = ImGui_ShowDebugLogWindow;                                       // create Debug Log window. display a simplified log of important dear imgui events.
pub const showStackToolWindow = ImGui_ShowStackToolWindow;                                     // create Stack Tool window. hover items with mouse to query information about the source of their unique ID.
pub const showAboutWindow = ImGui_ShowAboutWindow;                                             // create About window. display Dear ImGui version, credits and build/system information.
pub const showStyleEditor = ImGui_ShowStyleEditor;                                             // add style editor block (not a window). you can pass in a reference ImGuiStyle structure to compare to, revert to and save to (else it uses the default style)
pub const showStyleSelector = ImGui_ShowStyleSelector;                                         // add style selector block (not a window), essentially a combo listing the default styles.
pub const showFontSelector = ImGui_ShowFontSelector;                                           // add font selector block (not a window), essentially a combo listing the loaded fonts.
pub const showUserGuide = ImGui_ShowUserGuide;                                                 // add basic help/info block (not a window): how to manipulate ImGui as an end-user (mouse/keyboard controls).
pub const getVersion = ImGui_GetVersion;                                                       // get the compiled version string e.g. "1.80 WIP" (essentially the value for IMGUI_VERSION from the compiled version of imgui.cpp)
// Styles
pub const styleColorsDark = ImGui_StyleColorsDark;                                             // new, recommended style (default)
pub const styleColorsLight = ImGui_StyleColorsLight;                                           // best used with borders and a custom, thicker font
pub const styleColorsClassic = ImGui_StyleColorsClassic;                                       // classic imgui style
// Windows
// - Begin() = push window to the stack and start appending to it. End() = pop window from the stack.
// - Passing 'bool* p_open != NULL' shows a window-closing widget in the upper-right corner of the window,
//   which clicking will set the boolean to false when clicked.
// - You may append multiple times to the same window during the same frame by calling Begin()/End() pairs multiple times.
//   Some information such as 'flags' or 'p_open' will only be considered by the first call to Begin().
// - Begin() return false to indicate the window is collapsed or fully clipped, so you may early out and omit submitting
//   anything to the window. Always call a matching End() for each Begin() call, regardless of its return value!
//   [Important: due to legacy reason, this is inconsistent with most other functions such as BeginMenu/EndMenu,
//    BeginPopup/EndPopup, etc. where the EndXXX call should only be called if the corresponding BeginXXX function
//    returned true. Begin and BeginChild are the only odd ones out. Will be fixed in a future update.]
// - Note that the bottom of window stack always contains a window called "Debug".
pub const begin = ImGui_Begin;
pub const end = ImGui_End;
// Child Windows
// - Use child windows to begin into a self-contained independent scrolling/clipping regions within a host window. Child windows can embed their own child.
// - For each independent axis of 'size': ==0.0f: use remaining host window size / >0.0f: fixed size / <0.0f: use remaining window size minus abs(size) / Each axis can use a different mode, e.g. ImVec2(0,400).
// - BeginChild() returns false to indicate the window is collapsed or fully clipped, so you may early out and omit submitting anything to the window.
//   Always call a matching EndChild() for each BeginChild() call, regardless of its return value.
//   [Important: due to legacy reason, this is inconsistent with most other functions such as BeginMenu/EndMenu,
//    BeginPopup/EndPopup, etc. where the EndXXX call should only be called if the corresponding BeginXXX function
//    returned true. Begin and BeginChild are the only odd ones out. Will be fixed in a future update.]
pub const beginChild = ImGui_BeginChild;
pub const beginChildID = ImGui_BeginChildID;
pub const endChild = ImGui_EndChild;
// Windows Utilities
// - 'current window' = the window we are appending into while inside a Begin()/End() block. 'next window' = next window we will Begin() into.
pub const isWindowAppearing = ImGui_IsWindowAppearing;
pub const isWindowCollapsed = ImGui_IsWindowCollapsed;
pub const isWindowFocused = ImGui_IsWindowFocused;                                             // is current window focused? or its root/child, depending on flags. see flags for options.
pub const isWindowHovered = ImGui_IsWindowHovered;                                             // is current window hovered (and typically: not blocked by a popup/modal)? see flags for options. NB: If you are trying to check whether your mouse should be dispatched to imgui or to your app, you should use the 'io.WantCaptureMouse' boolean for that! Please read the FAQ!
pub const getWindowDrawList = ImGui_GetWindowDrawList;                                         // get draw list associated to the current window, to append your own drawing primitives
pub const getWindowDpiScale = ImGui_GetWindowDpiScale;                                         // get DPI scale currently associated to the current window's viewport.
pub const getWindowPos = ImGui_GetWindowPos;                                                   // get current window position in screen space (note: it is unlikely you need to use this. Consider using current layout pos instead, GetScreenCursorPos())
pub const getWindowSize = ImGui_GetWindowSize;                                                 // get current window size (note: it is unlikely you need to use this. Consider using GetScreenCursorPos() and e.g. GetContentRegionAvail() instead)
pub const getWindowWidth = ImGui_GetWindowWidth;                                               // get current window width (shortcut for GetWindowSize().x)
pub const getWindowHeight = ImGui_GetWindowHeight;                                             // get current window height (shortcut for GetWindowSize().y)
pub const getWindowViewport = ImGui_GetWindowViewport;                                         // get viewport currently associated to the current window.
// Window manipulation
// - Prefer using SetNextXXX functions (before Begin) rather that SetXXX functions (after Begin).
pub const setNextWindowPos = ImGui_SetNextWindowPos;                                           // Implied pivot = ImVec2(0, 0)
pub const setNextWindowPosEx = ImGui_SetNextWindowPosEx;                                       // set next window position. call before Begin(). use pivot=(0.5f,0.5f) to center on given point, etc.
pub const setNextWindowSize = ImGui_SetNextWindowSize;                                         // set next window size. set axis to 0.0f to force an auto-fit on this axis. call before Begin()
pub const setNextWindowSizeConstraints = ImGui_SetNextWindowSizeConstraints;                   // set next window size limits. use -1,-1 on either X/Y axis to preserve the current size. Sizes will be rounded down. Use callback to apply non-trivial programmatic constraints.
pub const setNextWindowContentSize = ImGui_SetNextWindowContentSize;                           // set next window content size (~ scrollable client area, which enforce the range of scrollbars). Not including window decorations (title bar, menu bar, etc.) nor WindowPadding. set an axis to 0.0f to leave it automatic. call before Begin()
pub const setNextWindowCollapsed = ImGui_SetNextWindowCollapsed;                               // set next window collapsed state. call before Begin()
pub const setNextWindowFocus = ImGui_SetNextWindowFocus;                                       // set next window to be focused / top-most. call before Begin()
pub const setNextWindowScroll = ImGui_SetNextWindowScroll;                                     // set next window scrolling value (use < 0.0f to not affect a given axis).
pub const setNextWindowBgAlpha = ImGui_SetNextWindowBgAlpha;                                   // set next window background color alpha. helper to easily override the Alpha component of ImGuiCol_WindowBg/ChildBg/PopupBg. you may also use ImGuiWindowFlags_NoBackground.
pub const setNextWindowViewport = ImGui_SetNextWindowViewport;                                 // set next window viewport
pub const setWindowPos = ImGui_SetWindowPos;                                                   // (not recommended) set current window position - call within Begin()/End(). prefer using SetNextWindowPos(), as this may incur tearing and side-effects.
pub const setWindowSize = ImGui_SetWindowSize;                                                 // (not recommended) set current window size - call within Begin()/End(). set to ImVec2(0, 0) to force an auto-fit. prefer using SetNextWindowSize(), as this may incur tearing and minor side-effects.
pub const setWindowCollapsed = ImGui_SetWindowCollapsed;                                       // (not recommended) set current window collapsed state. prefer using SetNextWindowCollapsed().
pub const setWindowFocus = ImGui_SetWindowFocus;                                               // (not recommended) set current window to be focused / top-most. prefer using SetNextWindowFocus().
pub const setWindowFontScale = ImGui_SetWindowFontScale;                                       // [OBSOLETE] set font scale. Adjust IO.FontGlobalScale if you want to scale all windows. This is an old API! For correct scaling, prefer to reload font + rebuild ImFontAtlas + call style.ScaleAllSizes().
pub const setWindowPosStr = ImGui_SetWindowPosStr;                                             // set named window position.
pub const setWindowSizeStr = ImGui_SetWindowSizeStr;                                           // set named window size. set axis to 0.0f to force an auto-fit on this axis.
pub const setWindowCollapsedStr = ImGui_SetWindowCollapsedStr;                                 // set named window collapsed state
pub const setWindowFocusStr = ImGui_SetWindowFocusStr;                                         // set named window to be focused / top-most. use NULL to remove focus.
// Content region
// - Retrieve available space from a given point. GetContentRegionAvail() is frequently useful.
// - Those functions are bound to be redesigned (they are confusing, incomplete and the Min/Max return values are in local window coordinates which increases confusion)
pub const getContentRegionAvail = ImGui_GetContentRegionAvail;                                 // == GetContentRegionMax() - GetCursorPos()
pub const getContentRegionMax = ImGui_GetContentRegionMax;                                     // current content boundaries (typically window boundaries including scrolling, or current column boundaries), in windows coordinates
pub const getWindowContentRegionMin = ImGui_GetWindowContentRegionMin;                         // content boundaries min for the full window (roughly (0,0)-Scroll), in window coordinates
pub const getWindowContentRegionMax = ImGui_GetWindowContentRegionMax;                         // content boundaries max for the full window (roughly (0,0)+Size-Scroll) where Size can be overridden with SetNextWindowContentSize(), in window coordinates
// Windows Scrolling
// - Any change of Scroll will be applied at the beginning of next frame in the first call to Begin().
// - You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this delay, as an alternative to using SetScrollX()/SetScrollY().
pub const getScrollX = ImGui_GetScrollX;                                                       // get scrolling amount [0 .. GetScrollMaxX()]
pub const getScrollY = ImGui_GetScrollY;                                                       // get scrolling amount [0 .. GetScrollMaxY()]
pub const setScrollX = ImGui_SetScrollX;                                                       // set scrolling amount [0 .. GetScrollMaxX()]
pub const setScrollY = ImGui_SetScrollY;                                                       // set scrolling amount [0 .. GetScrollMaxY()]
pub const getScrollMaxX = ImGui_GetScrollMaxX;                                                 // get maximum scrolling amount ~~ ContentSize.x - WindowSize.x - DecorationsSize.x
pub const getScrollMaxY = ImGui_GetScrollMaxY;                                                 // get maximum scrolling amount ~~ ContentSize.y - WindowSize.y - DecorationsSize.y
pub const setScrollHereX = ImGui_SetScrollHereX;                                               // adjust scrolling amount to make current cursor position visible. center_x_ratio=0.0: left, 0.5: center, 1.0: right. When using to make a "default/current item" visible, consider using SetItemDefaultFocus() instead.
pub const setScrollHereY = ImGui_SetScrollHereY;                                               // adjust scrolling amount to make current cursor position visible. center_y_ratio=0.0: top, 0.5: center, 1.0: bottom. When using to make a "default/current item" visible, consider using SetItemDefaultFocus() instead.
pub const setScrollFromPosX = ImGui_SetScrollFromPosX;                                         // adjust scrolling amount to make given position visible. Generally GetCursorStartPos() + offset to compute a valid position.
pub const setScrollFromPosY = ImGui_SetScrollFromPosY;                                         // adjust scrolling amount to make given position visible. Generally GetCursorStartPos() + offset to compute a valid position.
// Parameters stacks (shared)
pub const pushFont = ImGui_PushFont;                                                           // use NULL as a shortcut to push default font
pub const popFont = ImGui_PopFont;
pub const pushStyleColor = ImGui_PushStyleColor;                                               // modify a style color. always use this if you modify the style after NewFrame().
pub const pushStyleColorImVec4 = ImGui_PushStyleColorImVec4;
pub const popStyleColor = ImGui_PopStyleColor;                                                 // Implied count = 1
pub const popStyleColorEx = ImGui_PopStyleColorEx;
pub const pushStyleVar = ImGui_PushStyleVar;                                                   // modify a style float variable. always use this if you modify the style after NewFrame().
pub const pushStyleVarImVec2 = ImGui_PushStyleVarImVec2;                                       // modify a style ImVec2 variable. always use this if you modify the style after NewFrame().
pub const popStyleVar = ImGui_PopStyleVar;                                                     // Implied count = 1
pub const popStyleVarEx = ImGui_PopStyleVarEx;
pub const pushTabStop = ImGui_PushTabStop;                                                     // == tab stop enable. Allow focusing using TAB/Shift-TAB, enabled by default but you can disable it for certain widgets
pub const popTabStop = ImGui_PopTabStop;
pub const pushButtonRepeat = ImGui_PushButtonRepeat;                                           // in 'repeat' mode, Button*() functions return repeated true in a typematic manner (using io.KeyRepeatDelay/io.KeyRepeatRate setting). Note that you can call IsItemActive() after any Button() to tell if the button is held in the current frame.
pub const popButtonRepeat = ImGui_PopButtonRepeat;
// Parameters stacks (current window)
pub const pushItemWidth = ImGui_PushItemWidth;                                                 // push width of items for common large "item+label" widgets. >0.0f: width in pixels, <0.0f align xx pixels to the right of window (so -FLT_MIN always align width to the right side).
pub const popItemWidth = ImGui_PopItemWidth;
pub const setNextItemWidth = ImGui_SetNextItemWidth;                                           // set width of the _next_ common large "item+label" widget. >0.0f: width in pixels, <0.0f align xx pixels to the right of window (so -FLT_MIN always align width to the right side)
pub const calcItemWidth = ImGui_CalcItemWidth;                                                 // width of item given pushed settings and current cursor position. NOT necessarily the width of last item unlike most 'Item' functions.
pub const pushTextWrapPos = ImGui_PushTextWrapPos;                                             // push word-wrapping position for Text*() commands. < 0.0f: no wrapping; 0.0f: wrap to end of window (or column); > 0.0f: wrap at 'wrap_pos_x' position in window local space
pub const popTextWrapPos = ImGui_PopTextWrapPos;
// Style read access
// - Use the ShowStyleEditor() function to interactively see/edit the colors.
pub const getFont = ImGui_GetFont;                                                             // get current font
pub const getFontSize = ImGui_GetFontSize;                                                     // get current font size (= height in pixels) of current font with current scale applied
pub const getFontTexUvWhitePixel = ImGui_GetFontTexUvWhitePixel;                               // get UV coordinate for a while pixel, useful to draw custom shapes via the ImDrawList API
pub const getColorU32 = ImGui_GetColorU32;                                                     // Implied alpha_mul = 1.0f
pub const getColorU32Ex = ImGui_GetColorU32Ex;                                                 // retrieve given style color with style alpha applied and optional extra alpha multiplier, packed as a 32-bit value suitable for ImDrawList
pub const getColorU32ImVec4 = ImGui_GetColorU32ImVec4;                                         // retrieve given color with style alpha applied, packed as a 32-bit value suitable for ImDrawList
pub const getColorU32ImU32 = ImGui_GetColorU32ImU32;                                           // retrieve given color with style alpha applied, packed as a 32-bit value suitable for ImDrawList
pub const getStyleColorVec4 = ImGui_GetStyleColorVec4;                                         // retrieve style color as stored in ImGuiStyle structure. use to feed back into PushStyleColor(), otherwise use GetColorU32() to get style color with style alpha baked in.
// Cursor / Layout
// - By "cursor" we mean the current output position.
// - The typical widget behavior is to output themselves at the current cursor position, then move the cursor one line down.
// - You can call SameLine() between widgets to undo the last carriage return and output at the right of the preceding widget.
// - Attention! We currently have inconsistencies between window-local and absolute positions we will aim to fix with future API:
//    Window-local coordinates:   SameLine(), GetCursorPos(), SetCursorPos(), GetCursorStartPos(), GetContentRegionMax(), GetWindowContentRegion*(), PushTextWrapPos()
//    Absolute coordinate:        GetCursorScreenPos(), SetCursorScreenPos(), all ImDrawList:: functions.
pub const separator = ImGui_Separator;                                                         // separator, generally horizontal. inside a menu bar or in horizontal layout mode, this becomes a vertical separator.
pub const sameLine = ImGui_SameLine;                                                           // Implied offset_from_start_x = 0.0f, spacing = -1.0f
pub const sameLineEx = ImGui_SameLineEx;                                                       // call between widgets or groups to layout them horizontally. X position given in window coordinates.
pub const newLine = ImGui_NewLine;                                                             // undo a SameLine() or force a new line when in a horizontal-layout context.
pub const spacing = ImGui_Spacing;                                                             // add vertical spacing.
pub const dummy = ImGui_Dummy;                                                                 // add a dummy item of given size. unlike InvisibleButton(), Dummy() won't take the mouse click or be navigable into.
pub const indent = ImGui_Indent;                                                               // Implied indent_w = 0.0f
pub const indentEx = ImGui_IndentEx;                                                           // move content position toward the right, by indent_w, or style.IndentSpacing if indent_w <= 0
pub const unindent = ImGui_Unindent;                                                           // Implied indent_w = 0.0f
pub const unindentEx = ImGui_UnindentEx;                                                       // move content position back to the left, by indent_w, or style.IndentSpacing if indent_w <= 0
pub const beginGroup = ImGui_BeginGroup;                                                       // lock horizontal starting position
pub const endGroup = ImGui_EndGroup;                                                           // unlock horizontal starting position + capture the whole group bounding box into one "item" (so you can use IsItemHovered() or layout primitives such as SameLine() on whole group, etc.)
pub const getCursorPos = ImGui_GetCursorPos;                                                   // cursor position in window coordinates (relative to window position)
pub const getCursorPosX = ImGui_GetCursorPosX;                                                 //   (some functions are using window-relative coordinates, such as: GetCursorPos, GetCursorStartPos, GetContentRegionMax, GetWindowContentRegion* etc.
pub const getCursorPosY = ImGui_GetCursorPosY;                                                 //    other functions such as GetCursorScreenPos or everything in ImDrawList::
pub const setCursorPos = ImGui_SetCursorPos;                                                   //    are using the main, absolute coordinate system.
pub const setCursorPosX = ImGui_SetCursorPosX;                                                 //    GetWindowPos() + GetCursorPos() == GetCursorScreenPos() etc.)
pub const setCursorPosY = ImGui_SetCursorPosY;                                                 //
pub const getCursorStartPos = ImGui_GetCursorStartPos;                                         // initial cursor position in window coordinates
pub const getCursorScreenPos = ImGui_GetCursorScreenPos;                                       // cursor position in absolute coordinates (useful to work with ImDrawList API). generally top-left == GetMainViewport()->Pos == (0,0) in single viewport mode, and bottom-right == GetMainViewport()->Pos+Size == io.DisplaySize in single-viewport mode.
pub const setCursorScreenPos = ImGui_SetCursorScreenPos;                                       // cursor position in absolute coordinates
pub const alignTextToFramePadding = ImGui_AlignTextToFramePadding;                             // vertically align upcoming text baseline to FramePadding.y so that it will align properly to regularly framed items (call if you have text on a line before a framed item)
pub const getTextLineHeight = ImGui_GetTextLineHeight;                                         // ~ FontSize
pub const getTextLineHeightWithSpacing = ImGui_GetTextLineHeightWithSpacing;                   // ~ FontSize + style.ItemSpacing.y (distance in pixels between 2 consecutive lines of text)
pub const getFrameHeight = ImGui_GetFrameHeight;                                               // ~ FontSize + style.FramePadding.y * 2
pub const getFrameHeightWithSpacing = ImGui_GetFrameHeightWithSpacing;                         // ~ FontSize + style.FramePadding.y * 2 + style.ItemSpacing.y (distance in pixels between 2 consecutive lines of framed widgets)
// ID stack/scopes
// Read the FAQ (docs/FAQ.md or http://dearimgui.com/faq) for more details about how ID are handled in dear imgui.
// - Those questions are answered and impacted by understanding of the ID stack system:
//   - "Q: Why is my widget not reacting when I click on it?"
//   - "Q: How can I have widgets with an empty label?"
//   - "Q: How can I have multiple widgets with the same label?"
// - Short version: ID are hashes of the entire ID stack. If you are creating widgets in a loop you most likely
//   want to push a unique identifier (e.g. object pointer, loop index) to uniquely differentiate them.
// - You can also use the "Label##foobar" syntax within widget label to distinguish them from each others.
// - In this header file we use the "label"/"name" terminology to denote a string that will be displayed + used as an ID,
//   whereas "str_id" denote a string that is only used as an ID and not normally displayed.
pub const pushID = ImGui_PushID;                                                               // push string into the ID stack (will hash string).
pub const pushIDStr = ImGui_PushIDStr;                                                         // push string into the ID stack (will hash string).
pub const pushIDPtr = ImGui_PushIDPtr;                                                         // push pointer into the ID stack (will hash pointer).
pub const pushIDInt = ImGui_PushIDInt;                                                         // push integer into the ID stack (will hash integer).
pub const popID = ImGui_PopID;                                                                 // pop from the ID stack.
pub const getID = ImGui_GetID;                                                                 // calculate unique ID (hash of whole ID stack + given parameter). e.g. if you want to query into ImGuiStorage yourself
pub const getIDStr = ImGui_GetIDStr;
pub const getIDPtr = ImGui_GetIDPtr;
// Widgets: Text
pub const textUnformatted = ImGui_TextUnformatted;                                             // Implied text_end = NULL
pub const textUnformattedEx = ImGui_TextUnformattedEx;                                         // raw text without formatting. Roughly equivalent to Text("%s", text) but: A) doesn't require null terminated string if 'text_end' is specified, B) it's faster, no memory copy is done, no buffer size limits, recommended for long chunks of text.
pub const text = ImGui_Text;                                                                   // formatted text
pub const textV = ImGui_TextV;
pub const textColored = ImGui_TextColored;                                                     // shortcut for PushStyleColor(ImGuiCol_Text, col); Text(fmt, ...); PopStyleColor();
pub const textColoredV = ImGui_TextColoredV;
pub const textDisabled = ImGui_TextDisabled;                                                   // shortcut for PushStyleColor(ImGuiCol_Text, style.Colors[ImGuiCol_TextDisabled]); Text(fmt, ...); PopStyleColor();
pub const textDisabledV = ImGui_TextDisabledV;
pub const textWrapped = ImGui_TextWrapped;                                                     // shortcut for PushTextWrapPos(0.0f); Text(fmt, ...); PopTextWrapPos();. Note that this won't work on an auto-resizing window if there's no other widgets to extend the window width, yoy may need to set a size using SetNextWindowSize().
pub const textWrappedV = ImGui_TextWrappedV;
pub const labelText = ImGui_LabelText;                                                         // display text+label aligned the same way as value+label widgets
pub const labelTextV = ImGui_LabelTextV;
pub const bulletText = ImGui_BulletText;                                                       // shortcut for Bullet()+Text()
pub const bulletTextV = ImGui_BulletTextV;
pub const separatorText = ImGui_SeparatorText;                                                 // currently: formatted text with an horizontal line
// Widgets: Main
// - Most widgets return true when the value has been changed or when pressed/selected
// - You may also use one of the many IsItemXXX functions (e.g. IsItemActive, IsItemHovered, etc.) to query widget state.
pub const button = ImGui_Button;                                                               // Implied size = ImVec2(0, 0)
pub const buttonEx = ImGui_ButtonEx;                                                           // button
pub const smallButton = ImGui_SmallButton;                                                     // button with FramePadding=(0,0) to easily embed within text
pub const invisibleButton = ImGui_InvisibleButton;                                             // flexible button behavior without the visuals, frequently useful to build custom behaviors using the public api (along with IsItemActive, IsItemHovered, etc.)
pub const arrowButton = ImGui_ArrowButton;                                                     // square button with an arrow shape
pub const checkbox = ImGui_Checkbox;
pub const checkboxFlagsIntPtr = ImGui_CheckboxFlagsIntPtr;
pub const checkboxFlagsUintPtr = ImGui_CheckboxFlagsUintPtr;
pub const radioButton = ImGui_RadioButton;                                                     // use with e.g. if (RadioButton("one", my_value==1)) { my_value = 1; }
pub const radioButtonIntPtr = ImGui_RadioButtonIntPtr;                                         // shortcut to handle the above pattern when value is an integer
pub const progressBar = ImGui_ProgressBar;
pub const bullet = ImGui_Bullet;                                                               // draw a small circle + keep the cursor on the same line. advance cursor x position by GetTreeNodeToLabelSpacing(), same distance that TreeNode() uses
// Widgets: Images
// - Read about ImTextureID here: https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples
pub const image = ImGui_Image;                                                                 // Implied uv0 = ImVec2(0, 0), uv1 = ImVec2(1, 1), tint_col = ImVec4(1, 1, 1, 1), border_col = ImVec4(0, 0, 0, 0)
pub const imageEx = ImGui_ImageEx;
pub const imageButton = ImGui_ImageButton;                                                     // Implied uv0 = ImVec2(0, 0), uv1 = ImVec2(1, 1), bg_col = ImVec4(0, 0, 0, 0), tint_col = ImVec4(1, 1, 1, 1)
pub const imageButtonEx = ImGui_ImageButtonEx;
// Widgets: Combo Box (Dropdown)
// - The BeginCombo()/EndCombo() api allows you to manage your contents and selection state however you want it, by creating e.g. Selectable() items.
// - The old Combo() api are helpers over BeginCombo()/EndCombo() which are kept available for convenience purpose. This is analogous to how ListBox are created.
pub const beginCombo = ImGui_BeginCombo;
pub const endCombo = ImGui_EndCombo;                                                           // only call EndCombo() if BeginCombo() returns true!
pub const comboChar = ImGui_ComboChar;                                                         // Implied popup_max_height_in_items = -1
pub const comboCharEx = ImGui_ComboCharEx;
pub const combo = ImGui_Combo;                                                                 // Implied popup_max_height_in_items = -1
pub const comboEx = ImGui_ComboEx;                                                             // Separate items with \0 within a string, end item-list with \0\0. e.g. "One\0Two\0Three\0"
pub const comboCallback = ImGui_ComboCallback;                                                 // Implied popup_max_height_in_items = -1
pub const comboCallbackEx = ImGui_ComboCallbackEx;
// Widgets: Drag Sliders
// - CTRL+Click on any drag box to turn them into an input box. Manually input values aren't clamped by default and can go off-bounds. Use ImGuiSliderFlags_AlwaysClamp to always clamp.
// - For all the Float2/Float3/Float4/Int2/Int3/Int4 versions of every function, note that a 'float v[X]' function argument is the same as 'float* v',
//   the array syntax is just a way to document the number of elements that are expected to be accessible. You can pass address of your first element out of a contiguous set, e.g. &myvector.x
// - Adjust format string to decorate the value with a prefix, a suffix, or adapt the editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs; "Biscuit: %.0f" -> Biscuit: 1; etc.
// - Format string may also be set to NULL or use the default format ("%f" or "%d").
// - Speed are per-pixel of mouse movement (v_speed=0.2f: mouse needs to move by 5 pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed is Max(v_speed, minimum_step_at_given_precision).
// - Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual input can override those limits if ImGuiSliderFlags_AlwaysClamp is not used.
// - Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
// - We use the same sets of flags for DragXXX() and SliderXXX() functions as the features are the same and it makes it easier to swap them.
// - Legacy: Pre-1.78 there are DragXXX() function signatures that take a final `float power=1.0f' argument instead of the `ImGuiSliderFlags flags=0' argument.
//   If you get a warning converting a float to ImGuiSliderFlags, read https://github.com/ocornut/imgui/issues/3361
pub const dragFloat = ImGui_DragFloat;                                                         // Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", flags = 0
pub const dragFloatEx = ImGui_DragFloatEx;                                                     // If v_min >= v_max we have no bound
pub const dragFloat2 = ImGui_DragFloat2;                                                       // Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", flags = 0
pub const dragFloat2Ex = ImGui_DragFloat2Ex;
pub const dragFloat3 = ImGui_DragFloat3;                                                       // Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", flags = 0
pub const dragFloat3Ex = ImGui_DragFloat3Ex;
pub const dragFloat4 = ImGui_DragFloat4;                                                       // Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", flags = 0
pub const dragFloat4Ex = ImGui_DragFloat4Ex;
pub const dragFloatRange2 = ImGui_DragFloatRange2;                                             // Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", format_max = NULL, flags = 0
pub const dragFloatRange2Ex = ImGui_DragFloatRange2Ex;
pub const dragInt = ImGui_DragInt;                                                             // Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", flags = 0
pub const dragIntEx = ImGui_DragIntEx;                                                         // If v_min >= v_max we have no bound
pub const dragInt2 = ImGui_DragInt2;                                                           // Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", flags = 0
pub const dragInt2Ex = ImGui_DragInt2Ex;
pub const dragInt3 = ImGui_DragInt3;                                                           // Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", flags = 0
pub const dragInt3Ex = ImGui_DragInt3Ex;
pub const dragInt4 = ImGui_DragInt4;                                                           // Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", flags = 0
pub const dragInt4Ex = ImGui_DragInt4Ex;
pub const dragIntRange2 = ImGui_DragIntRange2;                                                 // Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", format_max = NULL, flags = 0
pub const dragIntRange2Ex = ImGui_DragIntRange2Ex;
pub const dragScalar = ImGui_DragScalar;                                                       // Implied v_speed = 1.0f, p_min = NULL, p_max = NULL, format = NULL, flags = 0
pub const dragScalarEx = ImGui_DragScalarEx;
pub const dragScalarN = ImGui_DragScalarN;                                                     // Implied v_speed = 1.0f, p_min = NULL, p_max = NULL, format = NULL, flags = 0
pub const dragScalarNEx = ImGui_DragScalarNEx;
// Widgets: Regular Sliders
// - CTRL+Click on any slider to turn them into an input box. Manually input values aren't clamped by default and can go off-bounds. Use ImGuiSliderFlags_AlwaysClamp to always clamp.
// - Adjust format string to decorate the value with a prefix, a suffix, or adapt the editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs; "Biscuit: %.0f" -> Biscuit: 1; etc.
// - Format string may also be set to NULL or use the default format ("%f" or "%d").
// - Legacy: Pre-1.78 there are SliderXXX() function signatures that take a final `float power=1.0f' argument instead of the `ImGuiSliderFlags flags=0' argument.
//   If you get a warning converting a float to ImGuiSliderFlags, read https://github.com/ocornut/imgui/issues/3361
pub const sliderFloat = ImGui_SliderFloat;                                                     // Implied format = "%.3f", flags = 0
pub const sliderFloatEx = ImGui_SliderFloatEx;                                                 // adjust format to decorate the value with a prefix or a suffix for in-slider labels or unit display.
pub const sliderFloat2 = ImGui_SliderFloat2;                                                   // Implied format = "%.3f", flags = 0
pub const sliderFloat2Ex = ImGui_SliderFloat2Ex;
pub const sliderFloat3 = ImGui_SliderFloat3;                                                   // Implied format = "%.3f", flags = 0
pub const sliderFloat3Ex = ImGui_SliderFloat3Ex;
pub const sliderFloat4 = ImGui_SliderFloat4;                                                   // Implied format = "%.3f", flags = 0
pub const sliderFloat4Ex = ImGui_SliderFloat4Ex;
pub const sliderAngle = ImGui_SliderAngle;                                                     // Implied v_degrees_min = -360.0f, v_degrees_max = +360.0f, format = "%.0f deg", flags = 0
pub const sliderAngleEx = ImGui_SliderAngleEx;
pub const sliderInt = ImGui_SliderInt;                                                         // Implied format = "%d", flags = 0
pub const sliderIntEx = ImGui_SliderIntEx;
pub const sliderInt2 = ImGui_SliderInt2;                                                       // Implied format = "%d", flags = 0
pub const sliderInt2Ex = ImGui_SliderInt2Ex;
pub const sliderInt3 = ImGui_SliderInt3;                                                       // Implied format = "%d", flags = 0
pub const sliderInt3Ex = ImGui_SliderInt3Ex;
pub const sliderInt4 = ImGui_SliderInt4;                                                       // Implied format = "%d", flags = 0
pub const sliderInt4Ex = ImGui_SliderInt4Ex;
pub const sliderScalar = ImGui_SliderScalar;                                                   // Implied format = NULL, flags = 0
pub const sliderScalarEx = ImGui_SliderScalarEx;
pub const sliderScalarN = ImGui_SliderScalarN;                                                 // Implied format = NULL, flags = 0
pub const sliderScalarNEx = ImGui_SliderScalarNEx;
pub const vSliderFloat = ImGui_VSliderFloat;                                                   // Implied format = "%.3f", flags = 0
pub const vSliderFloatEx = ImGui_VSliderFloatEx;
pub const vSliderInt = ImGui_VSliderInt;                                                       // Implied format = "%d", flags = 0
pub const vSliderIntEx = ImGui_VSliderIntEx;
pub const vSliderScalar = ImGui_VSliderScalar;                                                 // Implied format = NULL, flags = 0
pub const vSliderScalarEx = ImGui_VSliderScalarEx;
// Widgets: Input with Keyboard
// - If you want to use InputText() with std::string or any custom dynamic string type, see misc/cpp/imgui_stdlib.h and comments in imgui_demo.cpp.
// - Most of the ImGuiInputTextFlags flags are only useful for InputText() and not for InputFloatX, InputIntX, InputDouble etc.
pub const inputText = ImGui_InputText;                                                         // Implied callback = NULL, user_data = NULL
pub const inputTextEx = ImGui_InputTextEx;
pub const inputTextMultiline = ImGui_InputTextMultiline;                                       // Implied size = ImVec2(0, 0), flags = 0, callback = NULL, user_data = NULL
pub const inputTextMultilineEx = ImGui_InputTextMultilineEx;
pub const inputTextWithHint = ImGui_InputTextWithHint;                                         // Implied callback = NULL, user_data = NULL
pub const inputTextWithHintEx = ImGui_InputTextWithHintEx;
pub const inputFloat = ImGui_InputFloat;                                                       // Implied step = 0.0f, step_fast = 0.0f, format = "%.3f", flags = 0
pub const inputFloatEx = ImGui_InputFloatEx;
pub const inputFloat2 = ImGui_InputFloat2;                                                     // Implied format = "%.3f", flags = 0
pub const inputFloat2Ex = ImGui_InputFloat2Ex;
pub const inputFloat3 = ImGui_InputFloat3;                                                     // Implied format = "%.3f", flags = 0
pub const inputFloat3Ex = ImGui_InputFloat3Ex;
pub const inputFloat4 = ImGui_InputFloat4;                                                     // Implied format = "%.3f", flags = 0
pub const inputFloat4Ex = ImGui_InputFloat4Ex;
pub const inputInt = ImGui_InputInt;                                                           // Implied step = 1, step_fast = 100, flags = 0
pub const inputIntEx = ImGui_InputIntEx;
pub const inputInt2 = ImGui_InputInt2;
pub const inputInt3 = ImGui_InputInt3;
pub const inputInt4 = ImGui_InputInt4;
pub const inputDouble = ImGui_InputDouble;                                                     // Implied step = 0.0, step_fast = 0.0, format = "%.6f", flags = 0
pub const inputDoubleEx = ImGui_InputDoubleEx;
pub const inputScalar = ImGui_InputScalar;                                                     // Implied p_step = NULL, p_step_fast = NULL, format = NULL, flags = 0
pub const inputScalarEx = ImGui_InputScalarEx;
pub const inputScalarN = ImGui_InputScalarN;                                                   // Implied p_step = NULL, p_step_fast = NULL, format = NULL, flags = 0
pub const inputScalarNEx = ImGui_InputScalarNEx;
// Widgets: Color Editor/Picker (tip: the ColorEdit* functions have a little color square that can be left-clicked to open a picker, and right-clicked to open an option menu.)
// - Note that in C++ a 'float v[X]' function argument is the _same_ as 'float* v', the array syntax is just a way to document the number of elements that are expected to be accessible.
// - You can pass the address of a first float element out of a contiguous structure, e.g. &myvector.x
pub const colorEdit3 = ImGui_ColorEdit3;
pub const colorEdit4 = ImGui_ColorEdit4;
pub const colorPicker3 = ImGui_ColorPicker3;
pub const colorPicker4 = ImGui_ColorPicker4;
pub const colorButton = ImGui_ColorButton;                                                     // Implied size = ImVec2(0, 0)
pub const colorButtonEx = ImGui_ColorButtonEx;                                                 // display a color square/button, hover for details, return true when pressed.
pub const setColorEditOptions = ImGui_SetColorEditOptions;                                     // initialize current options (generally on application startup) if you want to select a default format, picker type, etc. User will be able to change many settings, unless you pass the _NoOptions flag to your calls.
// Widgets: Trees
// - TreeNode functions return true when the node is open, in which case you need to also call TreePop() when you are finished displaying the tree node contents.
pub const treeNode = ImGui_TreeNode;
pub const treeNodeStr = ImGui_TreeNodeStr;                                                     // helper variation to easily decorelate the id from the displayed string. Read the FAQ about why and how to use ID. to align arbitrary text at the same level as a TreeNode() you can use Bullet().
pub const treeNodePtr = ImGui_TreeNodePtr;                                                     // "
pub const treeNodeV = ImGui_TreeNodeV;
pub const treeNodeVPtr = ImGui_TreeNodeVPtr;
pub const treeNodeEx = ImGui_TreeNodeEx;
pub const treeNodeExStr = ImGui_TreeNodeExStr;
pub const treeNodeExPtr = ImGui_TreeNodeExPtr;
pub const treeNodeExV = ImGui_TreeNodeExV;
pub const treeNodeExVPtr = ImGui_TreeNodeExVPtr;
pub const treePush = ImGui_TreePush;                                                           // ~ Indent()+PushId(). Already called by TreeNode() when returning true, but you can call TreePush/TreePop yourself if desired.
pub const treePushPtr = ImGui_TreePushPtr;                                                     // "
pub const treePop = ImGui_TreePop;                                                             // ~ Unindent()+PopId()
pub const getTreeNodeToLabelSpacing = ImGui_GetTreeNodeToLabelSpacing;                         // horizontal distance preceding label when using TreeNode*() or Bullet() == (g.FontSize + style.FramePadding.x*2) for a regular unframed TreeNode
pub const collapsingHeader = ImGui_CollapsingHeader;                                           // if returning 'true' the header is open. doesn't indent nor push on ID stack. user doesn't have to call TreePop().
pub const collapsingHeaderBoolPtr = ImGui_CollapsingHeaderBoolPtr;                             // when 'p_visible != NULL': if '*p_visible==true' display an additional small close button on upper right of the header which will set the bool to false when clicked, if '*p_visible==false' don't display the header.
pub const setNextItemOpen = ImGui_SetNextItemOpen;                                             // set next TreeNode/CollapsingHeader open state.
// Widgets: Selectables
// - A selectable highlights when hovered, and can display another color when selected.
// - Neighbors selectable extend their highlight bounds in order to leave no gap between them. This is so a series of selected Selectable appear contiguous.
pub const selectable = ImGui_Selectable;                                                       // Implied selected = false, flags = 0, size = ImVec2(0, 0)
pub const selectableEx = ImGui_SelectableEx;                                                   // "bool selected" carry the selection state (read-only). Selectable() is clicked is returns true so you can modify your selection state. size.x==0.0: use remaining width, size.x>0.0: specify width. size.y==0.0: use label height, size.y>0.0: specify height
pub const selectableBoolPtr = ImGui_SelectableBoolPtr;                                         // Implied size = ImVec2(0, 0)
pub const selectableBoolPtrEx = ImGui_SelectableBoolPtrEx;                                     // "bool* p_selected" point to the selection state (read-write), as a convenient helper.
// Widgets: List Boxes
// - This is essentially a thin wrapper to using BeginChild/EndChild with some stylistic changes.
// - The BeginListBox()/EndListBox() api allows you to manage your contents and selection state however you want it, by creating e.g. Selectable() or any items.
// - The simplified/old ListBox() api are helpers over BeginListBox()/EndListBox() which are kept available for convenience purpose. This is analoguous to how Combos are created.
// - Choose frame width:   size.x > 0.0f: custom  /  size.x < 0.0f or -FLT_MIN: right-align   /  size.x = 0.0f (default): use current ItemWidth
// - Choose frame height:  size.y > 0.0f: custom  /  size.y < 0.0f or -FLT_MIN: bottom-align  /  size.y = 0.0f (default): arbitrary default height which can fit ~7 items
pub const beginListBox = ImGui_BeginListBox;                                                   // open a framed scrolling region
pub const endListBox = ImGui_EndListBox;                                                       // only call EndListBox() if BeginListBox() returned true!
pub const listBox = ImGui_ListBox;
pub const listBoxCallback = ImGui_ListBoxCallback;                                             // Implied height_in_items = -1
pub const listBoxCallbackEx = ImGui_ListBoxCallbackEx;
// Widgets: Data Plotting
// - Consider using ImPlot (https://github.com/epezent/implot) which is much better!
pub const plotLines = ImGui_PlotLines;                                                         // Implied values_offset = 0, overlay_text = NULL, scale_min = FLT_MAX, scale_max = FLT_MAX, graph_size = ImVec2(0, 0), stride = sizeof(float)
pub const plotLinesEx = ImGui_PlotLinesEx;
pub const plotLinesCallback = ImGui_PlotLinesCallback;                                         // Implied values_offset = 0, overlay_text = NULL, scale_min = FLT_MAX, scale_max = FLT_MAX, graph_size = ImVec2(0, 0)
pub const plotLinesCallbackEx = ImGui_PlotLinesCallbackEx;
pub const plotHistogram = ImGui_PlotHistogram;                                                 // Implied values_offset = 0, overlay_text = NULL, scale_min = FLT_MAX, scale_max = FLT_MAX, graph_size = ImVec2(0, 0), stride = sizeof(float)
pub const plotHistogramEx = ImGui_PlotHistogramEx;
pub const plotHistogramCallback = ImGui_PlotHistogramCallback;                                 // Implied values_offset = 0, overlay_text = NULL, scale_min = FLT_MAX, scale_max = FLT_MAX, graph_size = ImVec2(0, 0)
pub const plotHistogramCallbackEx = ImGui_PlotHistogramCallbackEx;
// Widgets: Menus
// - Use BeginMenuBar() on a window ImGuiWindowFlags_MenuBar to append to its menu bar.
// - Use BeginMainMenuBar() to create a menu bar at the top of the screen and append to it.
// - Use BeginMenu() to create a menu. You can call BeginMenu() multiple time with the same identifier to append more items to it.
// - Not that MenuItem() keyboardshortcuts are displayed as a convenience but _not processed_ by Dear ImGui at the moment.
pub const beginMenuBar = ImGui_BeginMenuBar;                                                   // append to menu-bar of current window (requires ImGuiWindowFlags_MenuBar flag set on parent window).
pub const endMenuBar = ImGui_EndMenuBar;                                                       // only call EndMenuBar() if BeginMenuBar() returns true!
pub const beginMainMenuBar = ImGui_BeginMainMenuBar;                                           // create and append to a full screen menu-bar.
pub const endMainMenuBar = ImGui_EndMainMenuBar;                                               // only call EndMainMenuBar() if BeginMainMenuBar() returns true!
pub const beginMenu = ImGui_BeginMenu;                                                         // Implied enabled = true
pub const beginMenuEx = ImGui_BeginMenuEx;                                                     // create a sub-menu entry. only call EndMenu() if this returns true!
pub const endMenu = ImGui_EndMenu;                                                             // only call EndMenu() if BeginMenu() returns true!
pub const menuItem = ImGui_MenuItem;                                                           // Implied shortcut = NULL, selected = false, enabled = true
pub const menuItemEx = ImGui_MenuItemEx;                                                       // return true when activated.
pub const menuItemBoolPtr = ImGui_MenuItemBoolPtr;                                             // return true when activated + toggle (*p_selected) if p_selected != NULL
// Tooltips
// - Tooltips are windows following the mouse. They do not take focus away.
// - A tooltip window can contain items of any types. SetTooltip() is a shortcut for the 'if (BeginTooltip()) { Text(...); EndTooltip(); }' idiom.
pub const beginTooltip = ImGui_BeginTooltip;                                                   // begin/append a tooltip window.
pub const endTooltip = ImGui_EndTooltip;                                                       // only call EndTooltip() if BeginTooltip()/BeginItemTooltip() returns true!
pub const setTooltip = ImGui_SetTooltip;                                                       // set a text-only tooltip. Often used after a ImGui::IsItemHovered() check. Override any previous call to SetTooltip().
pub const setTooltipV = ImGui_SetTooltipV;
// Tooltips: helpers for showing a tooltip when hovering an item
// - BeginItemTooltip() is a shortcut for the 'if (IsItemHovered(ImGuiHoveredFlags_Tooltip) && BeginTooltip())' idiom.
// - SetItemTooltip() is a shortcut for the 'if (IsItemHovered(ImGuiHoveredFlags_Tooltip)) { SetTooltip(...); }' idiom.
// - Where 'ImGuiHoveredFlags_Tooltip' itself is a shortcut to use 'style.HoverFlagsForTooltipMouse' or 'style.HoverFlagsForTooltipNav' depending on active input type. For mouse it defaults to 'ImGuiHoveredFlags_Stationary | ImGuiHoveredFlags_DelayShort'.
pub const beginItemTooltip = ImGui_BeginItemTooltip;                                           // begin/append a tooltip window if preceding item was hovered.
pub const setItemTooltip = ImGui_SetItemTooltip;                                               // set a text-only tooltip if preceeding item was hovered. override any previous call to SetTooltip().
pub const setItemTooltipV = ImGui_SetItemTooltipV;
// Popups: begin/end functions
//  - BeginPopup(): query popup state, if open start appending into the window. Call EndPopup() afterwards. ImGuiWindowFlags are forwarded to the window.
//  - BeginPopupModal(): block every interaction behind the window, cannot be closed by user, add a dimming background, has a title bar.
pub const beginPopup = ImGui_BeginPopup;                                                       // return true if the popup is open, and you can start outputting to it.
pub const beginPopupModal = ImGui_BeginPopupModal;                                             // return true if the modal is open, and you can start outputting to it.
pub const endPopup = ImGui_EndPopup;                                                           // only call EndPopup() if BeginPopupXXX() returns true!
// Popups: open/close functions
//  - OpenPopup(): set popup state to open. ImGuiPopupFlags are available for opening options.
//  - If not modal: they can be closed by clicking anywhere outside them, or by pressing ESCAPE.
//  - CloseCurrentPopup(): use inside the BeginPopup()/EndPopup() scope to close manually.
//  - CloseCurrentPopup() is called by default by Selectable()/MenuItem() when activated (FIXME: need some options).
//  - Use ImGuiPopupFlags_NoOpenOverExistingPopup to avoid opening a popup if there's already one at the same level. This is equivalent to e.g. testing for !IsAnyPopupOpen() prior to OpenPopup().
//  - Use IsWindowAppearing() after BeginPopup() to tell if a window just opened.
//  - IMPORTANT: Notice that for OpenPopupOnItemClick() we exceptionally default flags to 1 (== ImGuiPopupFlags_MouseButtonRight) for backward compatibility with older API taking 'int mouse_button = 1' parameter
pub const openPopup = ImGui_OpenPopup;                                                         // call to mark popup as open (don't call every frame!).
pub const openPopupID = ImGui_OpenPopupID;                                                     // id overload to facilitate calling from nested stacks
pub const openPopupOnItemClick = ImGui_OpenPopupOnItemClick;                                   // helper to open popup when clicked on last item. Default to ImGuiPopupFlags_MouseButtonRight == 1. (note: actually triggers on the mouse _released_ event to be consistent with popup behaviors)
pub const closeCurrentPopup = ImGui_CloseCurrentPopup;                                         // manually close the popup we have begin-ed into.
// Popups: open+begin combined functions helpers
//  - Helpers to do OpenPopup+BeginPopup where the Open action is triggered by e.g. hovering an item and right-clicking.
//  - They are convenient to easily create context menus, hence the name.
//  - IMPORTANT: Notice that BeginPopupContextXXX takes ImGuiPopupFlags just like OpenPopup() and unlike BeginPopup(). For full consistency, we may add ImGuiWindowFlags to the BeginPopupContextXXX functions in the future.
//  - IMPORTANT: Notice that we exceptionally default their flags to 1 (== ImGuiPopupFlags_MouseButtonRight) for backward compatibility with older API taking 'int mouse_button = 1' parameter, so if you add other flags remember to re-add the ImGuiPopupFlags_MouseButtonRight.
pub const beginPopupContextItem = ImGui_BeginPopupContextItem;                                 // Implied str_id = NULL, popup_flags = 1
pub const beginPopupContextItemEx = ImGui_BeginPopupContextItemEx;                             // open+begin popup when clicked on last item. Use str_id==NULL to associate the popup to previous item. If you want to use that on a non-interactive item such as Text() you need to pass in an explicit ID here. read comments in .cpp!
pub const beginPopupContextWindow = ImGui_BeginPopupContextWindow;                             // Implied str_id = NULL, popup_flags = 1
pub const beginPopupContextWindowEx = ImGui_BeginPopupContextWindowEx;                         // open+begin popup when clicked on current window.
pub const beginPopupContextVoid = ImGui_BeginPopupContextVoid;                                 // Implied str_id = NULL, popup_flags = 1
pub const beginPopupContextVoidEx = ImGui_BeginPopupContextVoidEx;                             // open+begin popup when clicked in void (where there are no windows).
// Popups: query functions
//  - IsPopupOpen(): return true if the popup is open at the current BeginPopup() level of the popup stack.
//  - IsPopupOpen() with ImGuiPopupFlags_AnyPopupId: return true if any popup is open at the current BeginPopup() level of the popup stack.
//  - IsPopupOpen() with ImGuiPopupFlags_AnyPopupId + ImGuiPopupFlags_AnyPopupLevel: return true if any popup is open.
pub const isPopupOpen = ImGui_IsPopupOpen;                                                     // return true if the popup is open.
// Tables
// - Full-featured replacement for old Columns API.
// - See Demo->Tables for demo code. See top of imgui_tables.cpp for general commentary.
// - See ImGuiTableFlags_ and ImGuiTableColumnFlags_ enums for a description of available flags.
// The typical call flow is:
// - 1. Call BeginTable(), early out if returning false.
// - 2. Optionally call TableSetupColumn() to submit column name/flags/defaults.
// - 3. Optionally call TableSetupScrollFreeze() to request scroll freezing of columns/rows.
// - 4. Optionally call TableHeadersRow() to submit a header row. Names are pulled from TableSetupColumn() data.
// - 5. Populate contents:
//    - In most situations you can use TableNextRow() + TableSetColumnIndex(N) to start appending into a column.
//    - If you are using tables as a sort of grid, where every column is holding the same type of contents,
//      you may prefer using TableNextColumn() instead of TableNextRow() + TableSetColumnIndex().
//      TableNextColumn() will automatically wrap-around into the next row if needed.
//    - IMPORTANT: Comparatively to the old Columns() API, we need to call TableNextColumn() for the first column!
//    - Summary of possible call flow:
//        --------------------------------------------------------------------------------------------------------
//        TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
//        TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
//                          TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
//        TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
//        --------------------------------------------------------------------------------------------------------
// - 5. Call EndTable()
pub const beginTable = ImGui_BeginTable;                                                       // Implied outer_size = ImVec2(0.0f, 0.0f), inner_width = 0.0f
pub const beginTableEx = ImGui_BeginTableEx;
pub const endTable = ImGui_EndTable;                                                           // only call EndTable() if BeginTable() returns true!
pub const tableNextRow = ImGui_TableNextRow;                                                   // Implied row_flags = 0, min_row_height = 0.0f
pub const tableNextRowEx = ImGui_TableNextRowEx;                                               // append into the first cell of a new row.
pub const tableNextColumn = ImGui_TableNextColumn;                                             // append into the next column (or first column of next row if currently in last column). Return true when column is visible.
pub const tableSetColumnIndex = ImGui_TableSetColumnIndex;                                     // append into the specified column. Return true when column is visible.
// Tables: Headers & Columns declaration
// - Use TableSetupColumn() to specify label, resizing policy, default width/weight, id, various other flags etc.
// - Use TableHeadersRow() to create a header row and automatically submit a TableHeader() for each column.
//   Headers are required to perform: reordering, sorting, and opening the context menu.
//   The context menu can also be made available in columns body using ImGuiTableFlags_ContextMenuInBody.
// - You may manually submit headers using TableNextRow() + TableHeader() calls, but this is only useful in
//   some advanced use cases (e.g. adding custom widgets in header row).
// - Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when scrolled.
pub const tableSetupColumn = ImGui_TableSetupColumn;                                           // Implied init_width_or_weight = 0.0f, user_id = 0
pub const tableSetupColumnEx = ImGui_TableSetupColumnEx;
pub const tableSetupScrollFreeze = ImGui_TableSetupScrollFreeze;                               // lock columns/rows so they stay visible when scrolled.
pub const tableHeadersRow = ImGui_TableHeadersRow;                                             // submit all headers cells based on data provided to TableSetupColumn() + submit context menu
pub const tableHeader = ImGui_TableHeader;                                                     // submit one header cell manually (rarely used)
// Tables: Sorting & Miscellaneous functions
// - Sorting: call TableGetSortSpecs() to retrieve latest sort specs for the table. NULL when not sorting.
//   When 'sort_specs->SpecsDirty == true' you should sort your data. It will be true when sorting specs have
//   changed since last call, or the first time. Make sure to set 'SpecsDirty = false' after sorting,
//   else you may wastefully sort your data every frame!
// - Functions args 'int column_n' treat the default value of -1 as the same as passing the current column index.
pub const tableGetSortSpecs = ImGui_TableGetSortSpecs;                                         // get latest sort specs for the table (NULL if not sorting).  Lifetime: don't hold on this pointer over multiple frames or past any subsequent call to BeginTable().
pub const tableGetColumnCount = ImGui_TableGetColumnCount;                                     // return number of columns (value passed to BeginTable)
pub const tableGetColumnIndex = ImGui_TableGetColumnIndex;                                     // return current column index.
pub const tableGetRowIndex = ImGui_TableGetRowIndex;                                           // return current row index.
pub const tableGetColumnName = ImGui_TableGetColumnName;                                       // return "" if column didn't have a name declared by TableSetupColumn(). Pass -1 to use current column.
pub const tableGetColumnFlags = ImGui_TableGetColumnFlags;                                     // return column flags so you can query their Enabled/Visible/Sorted/Hovered status flags. Pass -1 to use current column.
pub const tableSetColumnEnabled = ImGui_TableSetColumnEnabled;                                 // change user accessible enabled/disabled state of a column. Set to false to hide the column. User can use the context menu to change this themselves (right-click in headers, or right-click in columns body with ImGuiTableFlags_ContextMenuInBody)
pub const tableSetBgColor = ImGui_TableSetBgColor;                                             // change the color of a cell, row, or column. See ImGuiTableBgTarget_ flags for details.
// Legacy Columns API (prefer using Tables!)
// - You can also use SameLine(pos_x) to mimic simplified columns.
pub const columns = ImGui_Columns;                                                             // Implied count = 1, id = NULL, border = true
pub const columnsEx = ImGui_ColumnsEx;
pub const nextColumn = ImGui_NextColumn;                                                       // next column, defaults to current row or next row if the current row is finished
pub const getColumnIndex = ImGui_GetColumnIndex;                                               // get current column index
pub const getColumnWidth = ImGui_GetColumnWidth;                                               // get column width (in pixels). pass -1 to use current column
pub const setColumnWidth = ImGui_SetColumnWidth;                                               // set column width (in pixels). pass -1 to use current column
pub const getColumnOffset = ImGui_GetColumnOffset;                                             // get position of column line (in pixels, from the left side of the contents region). pass -1 to use current column, otherwise 0..GetColumnsCount() inclusive. column 0 is typically 0.0f
pub const setColumnOffset = ImGui_SetColumnOffset;                                             // set position of column line (in pixels, from the left side of the contents region). pass -1 to use current column
pub const getColumnsCount = ImGui_GetColumnsCount;
// Tab Bars, Tabs
// - Note: Tabs are automatically created by the docking system (when in 'docking' branch). Use this to create tab bars/tabs yourself.
pub const beginTabBar = ImGui_BeginTabBar;                                                     // create and append into a TabBar
pub const endTabBar = ImGui_EndTabBar;                                                         // only call EndTabBar() if BeginTabBar() returns true!
pub const beginTabItem = ImGui_BeginTabItem;                                                   // create a Tab. Returns true if the Tab is selected.
pub const endTabItem = ImGui_EndTabItem;                                                       // only call EndTabItem() if BeginTabItem() returns true!
pub const tabItemButton = ImGui_TabItemButton;                                                 // create a Tab behaving like a button. return true when clicked. cannot be selected in the tab bar.
pub const setTabItemClosed = ImGui_SetTabItemClosed;                                           // notify TabBar or Docking system of a closed tab/window ahead (useful to reduce visual flicker on reorderable tab bars). For tab-bar: call after BeginTabBar() and before Tab submissions. Otherwise call with a window name.
// Docking
// [BETA API] Enable with io.ConfigFlags |= ImGuiConfigFlags_DockingEnable.
// Note: You can use most Docking facilities without calling any API. You DO NOT need to call DockSpace() to use Docking!
// - Drag from window title bar or their tab to dock/undock. Hold SHIFT to disable docking/undocking.
// - Drag from window menu button (upper-left button) to undock an entire node (all windows).
// - When io.ConfigDockingWithShift == true, you instead need to hold SHIFT to _enable_ docking/undocking.
// About dockspaces:
// - Use DockSpaceOverViewport() to create an explicit dock node covering the screen or a specific viewport.
//   This is often used with ImGuiDockNodeFlags_PassthruCentralNode to make it transparent.
// - Use DockSpace() to create an explicit dock node _within_ an existing window. See Docking demo for details.
// - Important: Dockspaces need to be submitted _before_ any window they can host. Submit it early in your frame!
// - Important: Dockspaces need to be kept alive if hidden, otherwise windows docked into it will be undocked.
//   e.g. if you have multiple tabs with a dockspace inside each tab: submit the non-visible dockspaces with ImGuiDockNodeFlags_KeepAliveOnly.
pub const dockSpace = ImGui_DockSpace;                                                         // Implied size = ImVec2(0, 0), flags = 0, window_class = NULL
pub const dockSpaceEx = ImGui_DockSpaceEx;
pub const dockSpaceOverViewport = ImGui_DockSpaceOverViewport;                                 // Implied viewport = NULL, flags = 0, window_class = NULL
pub const dockSpaceOverViewportEx = ImGui_DockSpaceOverViewportEx;
pub const setNextWindowDockID = ImGui_SetNextWindowDockID;                                     // set next window dock id
pub const setNextWindowClass = ImGui_SetNextWindowClass;                                       // set next window class (control docking compatibility + provide hints to platform backend via custom viewport flags and platform parent/child relationship)
pub const getWindowDockID = ImGui_GetWindowDockID;
pub const isWindowDocked = ImGui_IsWindowDocked;                                               // is current window docked into another window?
// Logging/Capture
// - All text output from the interface can be captured into tty/file/clipboard. By default, tree nodes are automatically opened during logging.
pub const logToTTY = ImGui_LogToTTY;                                                           // start logging to tty (stdout)
pub const logToFile = ImGui_LogToFile;                                                         // start logging to file
pub const logToClipboard = ImGui_LogToClipboard;                                               // start logging to OS clipboard
pub const logFinish = ImGui_LogFinish;                                                         // stop logging (close file, etc.)
pub const logButtons = ImGui_LogButtons;                                                       // helper to display buttons for logging to tty/file/clipboard
pub const logText = ImGui_LogText;                                                             // pass text data straight to log (without being displayed)
pub const logTextV = ImGui_LogTextV;
// Drag and Drop
// - On source items, call BeginDragDropSource(), if it returns true also call SetDragDropPayload() + EndDragDropSource().
// - On target candidates, call BeginDragDropTarget(), if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
// - If you stop calling BeginDragDropSource() the payload is preserved however it won't have a preview tooltip (we currently display a fallback "..." tooltip, see #1725)
// - An item can be both drag source and drop target.
pub const beginDragDropSource = ImGui_BeginDragDropSource;                                     // call after submitting an item which may be dragged. when this return true, you can call SetDragDropPayload() + EndDragDropSource()
pub const setDragDropPayload = ImGui_SetDragDropPayload;                                       // type is a user defined string of maximum 32 characters. Strings starting with '_' are reserved for dear imgui internal types. Data is copied and held by imgui. Return true when payload has been accepted.
pub const endDragDropSource = ImGui_EndDragDropSource;                                         // only call EndDragDropSource() if BeginDragDropSource() returns true!
pub const beginDragDropTarget = ImGui_BeginDragDropTarget;                                     // call after submitting an item that may receive a payload. If this returns true, you can call AcceptDragDropPayload() + EndDragDropTarget()
pub const acceptDragDropPayload = ImGui_AcceptDragDropPayload;                                 // accept contents of a given type. If ImGuiDragDropFlags_AcceptBeforeDelivery is set you can peek into the payload before the mouse button is released.
pub const endDragDropTarget = ImGui_EndDragDropTarget;                                         // only call EndDragDropTarget() if BeginDragDropTarget() returns true!
pub const getDragDropPayload = ImGui_GetDragDropPayload;                                       // peek directly into the current payload from anywhere. may return NULL. use ImGuiPayload::IsDataType() to test for the payload type.
// Disabling [BETA API]
// - Disable all user interactions and dim items visuals (applying style.DisabledAlpha over current colors)
// - Those can be nested but it cannot be used to enable an already disabled section (a single BeginDisabled(true) in the stack is enough to keep everything disabled)
// - BeginDisabled(false) essentially does nothing useful but is provided to facilitate use of boolean expressions. If you can avoid calling BeginDisabled(False)/EndDisabled() best to avoid it.
pub const beginDisabled = ImGui_BeginDisabled;
pub const endDisabled = ImGui_EndDisabled;
// Clipping
// - Mouse hovering is affected by ImGui::PushClipRect() calls, unlike direct calls to ImDrawList::PushClipRect() which are render only.
pub const pushClipRect = ImGui_PushClipRect;
pub const popClipRect = ImGui_PopClipRect;
// Focus, Activation
// - Prefer using "SetItemDefaultFocus()" over "if (IsWindowAppearing()) SetScrollHereY()" when applicable to signify "this is the default item"
pub const setItemDefaultFocus = ImGui_SetItemDefaultFocus;                                     // make last item the default focused item of a window.
pub const setKeyboardFocusHere = ImGui_SetKeyboardFocusHere;                                   // Implied offset = 0
pub const setKeyboardFocusHereEx = ImGui_SetKeyboardFocusHereEx;                               // focus keyboard on the next widget. Use positive 'offset' to access sub components of a multiple component widget. Use -1 to access previous widget.
// Overlapping mode
pub const setNextItemAllowOverlap = ImGui_SetNextItemAllowOverlap;                             // allow next item to be overlapped by a subsequent item. Useful with invisible buttons, selectable, treenode covering an area where subsequent items may need to be added. Note that both Selectable() and TreeNode() have dedicated flags doing this.
// Item/Widgets Utilities and Query Functions
// - Most of the functions are referring to the previous Item that has been submitted.
// - See Demo Window under "Widgets->Querying Status" for an interactive visualization of most of those functions.
pub const isItemHovered = ImGui_IsItemHovered;                                                 // is the last item hovered? (and usable, aka not blocked by a popup, etc.). See ImGuiHoveredFlags for more options.
pub const isItemActive = ImGui_IsItemActive;                                                   // is the last item active? (e.g. button being held, text field being edited. This will continuously return true while holding mouse button on an item. Items that don't interact will always return false)
pub const isItemFocused = ImGui_IsItemFocused;                                                 // is the last item focused for keyboard/gamepad navigation?
pub const isItemClicked = ImGui_IsItemClicked;                                                 // Implied mouse_button = 0
pub const isItemClickedEx = ImGui_IsItemClickedEx;                                             // is the last item hovered and mouse clicked on? (**)  == IsMouseClicked(mouse_button) && IsItemHovered()Important. (**) this is NOT equivalent to the behavior of e.g. Button(). Read comments in function definition.
pub const isItemVisible = ImGui_IsItemVisible;                                                 // is the last item visible? (items may be out of sight because of clipping/scrolling)
pub const isItemEdited = ImGui_IsItemEdited;                                                   // did the last item modify its underlying value this frame? or was pressed? This is generally the same as the "bool" return value of many widgets.
pub const isItemActivated = ImGui_IsItemActivated;                                             // was the last item just made active (item was previously inactive).
pub const isItemDeactivated = ImGui_IsItemDeactivated;                                         // was the last item just made inactive (item was previously active). Useful for Undo/Redo patterns with widgets that require continuous editing.
pub const isItemDeactivatedAfterEdit = ImGui_IsItemDeactivatedAfterEdit;                       // was the last item just made inactive and made a value change when it was active? (e.g. Slider/Drag moved). Useful for Undo/Redo patterns with widgets that require continuous editing. Note that you may get false positives (some widgets such as Combo()/ListBox()/Selectable() will return true even when clicking an already selected item).
pub const isItemToggledOpen = ImGui_IsItemToggledOpen;                                         // was the last item open state toggled? set by TreeNode().
pub const isAnyItemHovered = ImGui_IsAnyItemHovered;                                           // is any item hovered?
pub const isAnyItemActive = ImGui_IsAnyItemActive;                                             // is any item active?
pub const isAnyItemFocused = ImGui_IsAnyItemFocused;                                           // is any item focused?
pub const getItemID = ImGui_GetItemID;                                                         // get ID of last item (~~ often same ImGui::GetID(label) beforehand)
pub const getItemRectMin = ImGui_GetItemRectMin;                                               // get upper-left bounding rectangle of the last item (screen space)
pub const getItemRectMax = ImGui_GetItemRectMax;                                               // get lower-right bounding rectangle of the last item (screen space)
pub const getItemRectSize = ImGui_GetItemRectSize;                                             // get size of last item
// Viewports
// - Currently represents the Platform Window created by the application which is hosting our Dear ImGui windows.
// - In 'docking' branch with multi-viewport enabled, we extend this concept to have multiple active viewports.
// - In the future we will extend this concept further to also represent Platform Monitor and support a "no main platform window" operation mode.
pub const getMainViewport = ImGui_GetMainViewport;                                             // return primary/default viewport. This can never be NULL.
// Background/Foreground Draw Lists
pub const getBackgroundDrawList = ImGui_GetBackgroundDrawList;                                 // get background draw list for the viewport associated to the current window. this draw list will be the first rendering one. Useful to quickly draw shapes/text behind dear imgui contents.
pub const getForegroundDrawList = ImGui_GetForegroundDrawList;                                 // get foreground draw list for the viewport associated to the current window. this draw list will be the last rendered one. Useful to quickly draw shapes/text over dear imgui contents.
pub const getBackgroundDrawListImGuiViewportPtr = ImGui_GetBackgroundDrawListImGuiViewportPtr; // get background draw list for the given viewport. this draw list will be the first rendering one. Useful to quickly draw shapes/text behind dear imgui contents.
pub const getForegroundDrawListImGuiViewportPtr = ImGui_GetForegroundDrawListImGuiViewportPtr; // get foreground draw list for the given viewport. this draw list will be the last rendered one. Useful to quickly draw shapes/text over dear imgui contents.
// Miscellaneous Utilities
pub const isRectVisibleBySize = ImGui_IsRectVisibleBySize;                                     // test if rectangle (of given size, starting from cursor position) is visible / not clipped.
pub const isRectVisible = ImGui_IsRectVisible;                                                 // test if rectangle (in screen space) is visible / not clipped. to perform coarse clipping on user's side.
pub const getTime = ImGui_GetTime;                                                             // get global imgui time. incremented by io.DeltaTime every frame.
pub const getFrameCount = ImGui_GetFrameCount;                                                 // get global imgui frame count. incremented by 1 every frame.
pub const getDrawListSharedData = ImGui_GetDrawListSharedData;                                 // you may use this when creating your own ImDrawList instances.
pub const getStyleColorName = ImGui_GetStyleColorName;                                         // get a string corresponding to the enum value (for display, saving, etc.).
pub const setStateStorage = ImGui_SetStateStorage;                                             // replace current window storage with our own (if you want to manipulate it yourself, typically clear subsection of it)
pub const getStateStorage = ImGui_GetStateStorage;
pub const beginChildFrame = ImGui_BeginChildFrame;                                             // helper to create a child window / scrolling region that looks like a normal widget frame
pub const endChildFrame = ImGui_EndChildFrame;                                                 // always call EndChildFrame() regardless of BeginChildFrame() return values (which indicates a collapsed/clipped window)
// Text Utilities
pub const calcTextSize = ImGui_CalcTextSize;                                                   // Implied text_end = NULL, hide_text_after_double_hash = false, wrap_width = -1.0f
pub const calcTextSizeEx = ImGui_CalcTextSizeEx;
// Color Utilities
pub const colorConvertU32ToFloat4 = ImGui_ColorConvertU32ToFloat4;
pub const colorConvertFloat4ToU32 = ImGui_ColorConvertFloat4ToU32;
pub const colorConvertRGBtoHSV = ImGui_ColorConvertRGBtoHSV;
pub const colorConvertHSVtoRGB = ImGui_ColorConvertHSVtoRGB;
// Inputs Utilities: Keyboard/Mouse/Gamepad
// - the ImGuiKey enum contains all possible keyboard, mouse and gamepad inputs (e.g. ImGuiKey_A, ImGuiKey_MouseLeft, ImGuiKey_GamepadDpadUp...).
// - before v1.87, we used ImGuiKey to carry native/user indices as defined by each backends. About use of those legacy ImGuiKey values:
//  - without IMGUI_DISABLE_OBSOLETE_KEYIO (legacy support): you can still use your legacy native/user indices (< 512) according to how your backend/engine stored them in io.KeysDown[], but need to cast them to ImGuiKey.
//  - with    IMGUI_DISABLE_OBSOLETE_KEYIO (this is the way forward): any use of ImGuiKey will assert with key < 512. GetKeyIndex() is pass-through and therefore deprecated (gone if IMGUI_DISABLE_OBSOLETE_KEYIO is defined).
pub const isKeyDown = ImGui_IsKeyDown;                                                         // is key being held.
pub const isKeyPressed = ImGui_IsKeyPressed;                                                   // Implied repeat = true
pub const isKeyPressedEx = ImGui_IsKeyPressedEx;                                               // was key pressed (went from !Down to Down)? if repeat=true, uses io.KeyRepeatDelay / KeyRepeatRate
pub const isKeyReleased = ImGui_IsKeyReleased;                                                 // was key released (went from Down to !Down)?
pub const getKeyPressedAmount = ImGui_GetKeyPressedAmount;                                     // uses provided repeat rate/delay. return a count, most often 0 or 1 but might be >1 if RepeatRate is small enough that DeltaTime > RepeatRate
pub const getKeyName = ImGui_GetKeyName;                                                       // [DEBUG] returns English name of the key. Those names a provided for debugging purpose and are not meant to be saved persistently not compared.
pub const setNextFrameWantCaptureKeyboard = ImGui_SetNextFrameWantCaptureKeyboard;             // Override io.WantCaptureKeyboard flag next frame (said flag is left for your application to handle, typically when true it instructs your app to ignore inputs). e.g. force capture keyboard when your widget is being hovered. This is equivalent to setting "io.WantCaptureKeyboard = want_capture_keyboard"; after the next NewFrame() call.
// Inputs Utilities: Mouse specific
// - To refer to a mouse button, you may use named enums in your code e.g. ImGuiMouseButton_Left, ImGuiMouseButton_Right.
// - You can also use regular integer: it is forever guaranteed that 0=Left, 1=Right, 2=Middle.
// - Dragging operations are only reported after mouse has moved a certain distance away from the initial clicking position (see 'lock_threshold' and 'io.MouseDraggingThreshold')
pub const isMouseDown = ImGui_IsMouseDown;                                                     // is mouse button held?
pub const isMouseClicked = ImGui_IsMouseClicked;                                               // Implied repeat = false
pub const isMouseClickedEx = ImGui_IsMouseClickedEx;                                           // did mouse button clicked? (went from !Down to Down). Same as GetMouseClickedCount() == 1.
pub const isMouseReleased = ImGui_IsMouseReleased;                                             // did mouse button released? (went from Down to !Down)
pub const isMouseDoubleClicked = ImGui_IsMouseDoubleClicked;                                   // did mouse button double-clicked? Same as GetMouseClickedCount() == 2. (note that a double-click will also report IsMouseClicked() == true)
pub const getMouseClickedCount = ImGui_GetMouseClickedCount;                                   // return the number of successive mouse-clicks at the time where a click happen (otherwise 0).
pub const isMouseHoveringRect = ImGui_IsMouseHoveringRect;                                     // Implied clip = true
pub const isMouseHoveringRectEx = ImGui_IsMouseHoveringRectEx;                                 // is mouse hovering given bounding rect (in screen space). clipped by current clipping settings, but disregarding of other consideration of focus/window ordering/popup-block.
pub const isMousePosValid = ImGui_IsMousePosValid;                                             // by convention we use (-FLT_MAX,-FLT_MAX) to denote that there is no mouse available
pub const isAnyMouseDown = ImGui_IsAnyMouseDown;                                               // [WILL OBSOLETE] is any mouse button held? This was designed for backends, but prefer having backend maintain a mask of held mouse buttons, because upcoming input queue system will make this invalid.
pub const getMousePos = ImGui_GetMousePos;                                                     // shortcut to ImGui::GetIO().MousePos provided by user, to be consistent with other calls
pub const getMousePosOnOpeningCurrentPopup = ImGui_GetMousePosOnOpeningCurrentPopup;           // retrieve mouse position at the time of opening popup we have BeginPopup() into (helper to avoid user backing that value themselves)
pub const isMouseDragging = ImGui_IsMouseDragging;                                             // is mouse dragging? (if lock_threshold < -1.0f, uses io.MouseDraggingThreshold)
pub const getMouseDragDelta = ImGui_GetMouseDragDelta;                                         // return the delta from the initial clicking position while the mouse button is pressed or was just released. This is locked and return 0.0f until the mouse moves past a distance threshold at least once (if lock_threshold < -1.0f, uses io.MouseDraggingThreshold)
pub const resetMouseDragDelta = ImGui_ResetMouseDragDelta;                                     // Implied button = 0
pub const resetMouseDragDeltaEx = ImGui_ResetMouseDragDeltaEx;                                 //
pub const getMouseCursor = ImGui_GetMouseCursor;                                               // get desired mouse cursor shape. Important: reset in ImGui::NewFrame(), this is updated during the frame. valid before Render(). If you use software rendering by setting io.MouseDrawCursor ImGui will render those for you
pub const setMouseCursor = ImGui_SetMouseCursor;                                               // set desired mouse cursor shape
pub const setNextFrameWantCaptureMouse = ImGui_SetNextFrameWantCaptureMouse;                   // Override io.WantCaptureMouse flag next frame (said flag is left for your application to handle, typical when true it instucts your app to ignore inputs). This is equivalent to setting "io.WantCaptureMouse = want_capture_mouse;" after the next NewFrame() call.
// Clipboard Utilities
// - Also see the LogToClipboard() function to capture GUI into clipboard, or easily output text data to the clipboard.
pub const getClipboardText = ImGui_GetClipboardText;
pub const setClipboardText = ImGui_SetClipboardText;
// Settings/.Ini Utilities
// - The disk functions are automatically called if io.IniFilename != NULL (default is "imgui.ini").
// - Set io.IniFilename to NULL to load/save manually. Read io.WantSaveIniSettings description about handling .ini saving manually.
// - Important: default value "imgui.ini" is relative to current working dir! Most apps will want to lock this to an absolute path (e.g. same path as executables).
pub const loadIniSettingsFromDisk = ImGui_LoadIniSettingsFromDisk;                             // call after CreateContext() and before the first call to NewFrame(). NewFrame() automatically calls LoadIniSettingsFromDisk(io.IniFilename).
pub const loadIniSettingsFromMemory = ImGui_LoadIniSettingsFromMemory;                         // call after CreateContext() and before the first call to NewFrame() to provide .ini data from your own data source.
pub const saveIniSettingsToDisk = ImGui_SaveIniSettingsToDisk;                                 // this is automatically called (if io.IniFilename is not empty) a few seconds after any modification that should be reflected in the .ini file (and also by DestroyContext).
pub const saveIniSettingsToMemory = ImGui_SaveIniSettingsToMemory;                             // return a zero-terminated string with the .ini data which you can save by your own mean. call when io.WantSaveIniSettings is set, then save data by your own mean and clear io.WantSaveIniSettings.
// Debug Utilities
pub const debugTextEncoding = ImGui_DebugTextEncoding;
pub const debugCheckVersionAndDataLayout = ImGui_DebugCheckVersionAndDataLayout;               // This is called by IMGUI_CHECKVERSION() macro.
// Memory Allocators
// - Those functions are not reliant on the current context.
// - DLL users: heaps and globals are not shared across DLL boundaries! You will need to call SetCurrentContext() + SetAllocatorFunctions()
//   for each static/DLL boundary you are calling from. Read "Context and Memory Allocators" section of imgui.cpp for more details.
pub const setAllocatorFunctions = ImGui_SetAllocatorFunctions;
pub const getAllocatorFunctions = ImGui_GetAllocatorFunctions;
pub const memAlloc = ImGui_MemAlloc;
pub const memFree = ImGui_MemFree;
// (Optional) Platform/OS interface for multi-viewport support
// Read comments around the ImGuiPlatformIO structure for more details.
// Note: You may use GetWindowViewport() to get the current viewport of the current window.
pub const getPlatformIO = ImGui_GetPlatformIO;                                                 // platform/renderer functions, for backend to setup + viewports list.
pub const updatePlatformWindows = ImGui_UpdatePlatformWindows;                                 // call in main loop. will call CreateWindow/ResizeWindow/etc. platform functions for each secondary viewport, and DestroyWindow for each inactive viewport.
pub const renderPlatformWindowsDefault = ImGui_RenderPlatformWindowsDefault;                   // Implied platform_render_arg = NULL, renderer_render_arg = NULL
pub const renderPlatformWindowsDefaultEx = ImGui_RenderPlatformWindowsDefaultEx;               // call in main loop. will call RenderWindow/SwapBuffers platform functions for each secondary viewport which doesn't have the ImGuiViewportFlags_Minimized flag set. May be reimplemented by user for custom rendering needs.
pub const destroyPlatformWindows = ImGui_DestroyPlatformWindows;                               // call DestroyWindow platform functions for all viewports. call from backend Shutdown() if you need to close platform windows before imgui shutdown. otherwise will be called by DestroyContext().
pub const findViewportByID = ImGui_FindViewportByID;                                           // this is a helper for backends.
pub const findViewportByPlatformHandle = ImGui_FindViewportByPlatformHandle;                   // this is a helper for backends. the type platform_handle is decided by the backend (e.g. HWND, MyWindow*, GLFWwindow* etc.)
pub const vector_Construct = ImVector_Construct;                                               // Construct a zero-size ImVector<> (of any type). This is primarily useful when calling ImFontGlyphRangesBuilder_BuildRanges()
pub const vector_Destruct = ImVector_Destruct;                                                 // Destruct an ImVector<> (of any type). Important: Frees the vector memory but does not call destructors on contained objects (if they have them)
pub const getKeyIndex = ImGui_GetKeyIndex;

//-----------------------------------------------------------------------------
// Extern declarations
//-----------------------------------------------------------------------------

extern fn ImGui_CreateContext(shared_font_atlas: ?*FontAtlas) ?*Context;
extern fn ImGui_DestroyContext(ctx: ?*Context) void;
extern fn ImGui_GetCurrentContext() ?*Context;
extern fn ImGui_SetCurrentContext(ctx: ?*Context) void;
extern fn ImGui_GetIO() *IO;
extern fn ImGui_GetStyle() *Style;
extern fn ImGui_NewFrame() void;
extern fn ImGui_EndFrame() void;
extern fn ImGui_Render() void;
extern fn ImGui_GetDrawData() ?*DrawData;
extern fn ImGui_ShowDemoWindow(p_open: ?*bool) void;
extern fn ImGui_ShowMetricsWindow(p_open: ?*bool) void;
extern fn ImGui_ShowDebugLogWindow(p_open: ?*bool) void;
extern fn ImGui_ShowStackToolWindow(p_open: ?*bool) void;
extern fn ImGui_ShowAboutWindow(p_open: ?*bool) void;
extern fn ImGui_ShowStyleEditor(ref: ?*Style) void;
extern fn ImGui_ShowStyleSelector(label: ?[*:0]const u8) bool;
extern fn ImGui_ShowFontSelector(label: ?[*:0]const u8) void;
extern fn ImGui_ShowUserGuide() void;
extern fn ImGui_GetVersion() ?[*:0]const u8;
extern fn ImGui_StyleColorsDark(dst: ?*Style) void;
extern fn ImGui_StyleColorsLight(dst: ?*Style) void;
extern fn ImGui_StyleColorsClassic(dst: ?*Style) void;
extern fn ImGui_Begin(name: ?[*:0]const u8, p_open: ?*bool, flags: WindowFlags) bool;
extern fn ImGui_End() void;
extern fn ImGui_BeginChild(str_id: ?[*:0]const u8, size: Vec2, border: bool, flags: WindowFlags) bool;
extern fn ImGui_BeginChildID(id: ID, size: Vec2, border: bool, flags: WindowFlags) bool;
extern fn ImGui_EndChild() void;
extern fn ImGui_IsWindowAppearing() bool;
extern fn ImGui_IsWindowCollapsed() bool;
extern fn ImGui_IsWindowFocused(flags: FocusedFlags) bool;
extern fn ImGui_IsWindowHovered(flags: HoveredFlags) bool;
extern fn ImGui_GetWindowDrawList() ?*DrawList;
extern fn ImGui_GetWindowDpiScale() f32;
extern fn ImGui_GetWindowPos() Vec2;
extern fn ImGui_GetWindowSize() Vec2;
extern fn ImGui_GetWindowWidth() f32;
extern fn ImGui_GetWindowHeight() f32;
extern fn ImGui_GetWindowViewport() ?*Viewport;
extern fn ImGui_SetNextWindowPos(pos: Vec2, cond: Cond) void;
extern fn ImGui_SetNextWindowPosEx(pos: Vec2, cond: Cond, pivot: Vec2) void;
extern fn ImGui_SetNextWindowSize(size: Vec2, cond: Cond) void;
extern fn ImGui_SetNextWindowSizeConstraints(size_min: Vec2, size_max: Vec2, custom_callback: SizeCallback, custom_callback_data: ?*anyopaque) void;
extern fn ImGui_SetNextWindowContentSize(size: Vec2) void;
extern fn ImGui_SetNextWindowCollapsed(collapsed: bool, cond: Cond) void;
extern fn ImGui_SetNextWindowFocus() void;
extern fn ImGui_SetNextWindowScroll(scroll: Vec2) void;
extern fn ImGui_SetNextWindowBgAlpha(alpha: f32) void;
extern fn ImGui_SetNextWindowViewport(viewport_id: ID) void;
extern fn ImGui_SetWindowPos(pos: Vec2, cond: Cond) void;
extern fn ImGui_SetWindowSize(size: Vec2, cond: Cond) void;
extern fn ImGui_SetWindowCollapsed(collapsed: bool, cond: Cond) void;
extern fn ImGui_SetWindowFocus() void;
extern fn ImGui_SetWindowFontScale(scale: f32) void;
extern fn ImGui_SetWindowPosStr(name: ?[*:0]const u8, pos: Vec2, cond: Cond) void;
extern fn ImGui_SetWindowSizeStr(name: ?[*:0]const u8, size: Vec2, cond: Cond) void;
extern fn ImGui_SetWindowCollapsedStr(name: ?[*:0]const u8, collapsed: bool, cond: Cond) void;
extern fn ImGui_SetWindowFocusStr(name: ?[*:0]const u8) void;
extern fn ImGui_GetContentRegionAvail() Vec2;
extern fn ImGui_GetContentRegionMax() Vec2;
extern fn ImGui_GetWindowContentRegionMin() Vec2;
extern fn ImGui_GetWindowContentRegionMax() Vec2;
extern fn ImGui_GetScrollX() f32;
extern fn ImGui_GetScrollY() f32;
extern fn ImGui_SetScrollX(scroll_x: f32) void;
extern fn ImGui_SetScrollY(scroll_y: f32) void;
extern fn ImGui_GetScrollMaxX() f32;
extern fn ImGui_GetScrollMaxY() f32;
extern fn ImGui_SetScrollHereX(center_x_ratio: f32) void;
extern fn ImGui_SetScrollHereY(center_y_ratio: f32) void;
extern fn ImGui_SetScrollFromPosX(local_x: f32, center_x_ratio: f32) void;
extern fn ImGui_SetScrollFromPosY(local_y: f32, center_y_ratio: f32) void;
extern fn ImGui_PushFont(font: ?*Font) void;
extern fn ImGui_PopFont() void;
extern fn ImGui_PushStyleColor(idx: Col, col: U32) void;
extern fn ImGui_PushStyleColorImVec4(idx: Col, col: Vec4) void;
extern fn ImGui_PopStyleColor() void;
extern fn ImGui_PopStyleColorEx(count: c_int) void;
extern fn ImGui_PushStyleVar(idx: StyleVar, val: f32) void;
extern fn ImGui_PushStyleVarImVec2(idx: StyleVar, val: Vec2) void;
extern fn ImGui_PopStyleVar() void;
extern fn ImGui_PopStyleVarEx(count: c_int) void;
extern fn ImGui_PushTabStop(tab_stop: bool) void;
extern fn ImGui_PopTabStop() void;
extern fn ImGui_PushButtonRepeat(repeat: bool) void;
extern fn ImGui_PopButtonRepeat() void;
extern fn ImGui_PushItemWidth(item_width: f32) void;
extern fn ImGui_PopItemWidth() void;
extern fn ImGui_SetNextItemWidth(item_width: f32) void;
extern fn ImGui_CalcItemWidth() f32;
extern fn ImGui_PushTextWrapPos(wrap_local_pos_x: f32) void;
extern fn ImGui_PopTextWrapPos() void;
extern fn ImGui_GetFont() ?*Font;
extern fn ImGui_GetFontSize() f32;
extern fn ImGui_GetFontTexUvWhitePixel() Vec2;
extern fn ImGui_GetColorU32(idx: Col) U32;
extern fn ImGui_GetColorU32Ex(idx: Col, alpha_mul: f32) U32;
extern fn ImGui_GetColorU32ImVec4(col: Vec4) U32;
extern fn ImGui_GetColorU32ImU32(col: U32) U32;
extern fn ImGui_GetStyleColorVec4(idx: Col) *const Vec4;
extern fn ImGui_Separator() void;
extern fn ImGui_SameLine() void;
extern fn ImGui_SameLineEx(offset_from_start_x: f32, spacing: f32) void;
extern fn ImGui_NewLine() void;
extern fn ImGui_Spacing() void;
extern fn ImGui_Dummy(size: Vec2) void;
extern fn ImGui_Indent() void;
extern fn ImGui_IndentEx(indent_w: f32) void;
extern fn ImGui_Unindent() void;
extern fn ImGui_UnindentEx(indent_w: f32) void;
extern fn ImGui_BeginGroup() void;
extern fn ImGui_EndGroup() void;
extern fn ImGui_GetCursorPos() Vec2;
extern fn ImGui_GetCursorPosX() f32;
extern fn ImGui_GetCursorPosY() f32;
extern fn ImGui_SetCursorPos(local_pos: Vec2) void;
extern fn ImGui_SetCursorPosX(local_x: f32) void;
extern fn ImGui_SetCursorPosY(local_y: f32) void;
extern fn ImGui_GetCursorStartPos() Vec2;
extern fn ImGui_GetCursorScreenPos() Vec2;
extern fn ImGui_SetCursorScreenPos(pos: Vec2) void;
extern fn ImGui_AlignTextToFramePadding() void;
extern fn ImGui_GetTextLineHeight() f32;
extern fn ImGui_GetTextLineHeightWithSpacing() f32;
extern fn ImGui_GetFrameHeight() f32;
extern fn ImGui_GetFrameHeightWithSpacing() f32;
extern fn ImGui_PushID(str_id: ?[*:0]const u8) void;
extern fn ImGui_PushIDStr(str_id_begin: ?[*:0]const u8, str_id_end: ?[*:0]const u8) void;
extern fn ImGui_PushIDPtr(ptr_id: ?*anyopaque) void;
extern fn ImGui_PushIDInt(int_id: c_int) void;
extern fn ImGui_PopID() void;
extern fn ImGui_GetID(str_id: ?[*:0]const u8) ID;
extern fn ImGui_GetIDStr(str_id_begin: ?[*:0]const u8, str_id_end: ?[*:0]const u8) ID;
extern fn ImGui_GetIDPtr(ptr_id: ?*anyopaque) ID;
extern fn ImGui_TextUnformatted(text: ?[*:0]const u8) void;
extern fn ImGui_TextUnformattedEx(text: ?[*:0]const u8, text_end: ?[*:0]const u8) void;
extern fn ImGui_Text(fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_TextV(fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_TextColored(col: Vec4, fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_TextColoredV(col: Vec4, fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_TextDisabled(fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_TextDisabledV(fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_TextWrapped(fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_TextWrappedV(fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_LabelText(label: ?[*:0]const u8, fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_LabelTextV(label: ?[*:0]const u8, fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_BulletText(fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_BulletTextV(fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_SeparatorText(label: ?[*:0]const u8) void;
extern fn ImGui_Button(label: ?[*:0]const u8) bool;
extern fn ImGui_ButtonEx(label: ?[*:0]const u8, size: Vec2) bool;
extern fn ImGui_SmallButton(label: ?[*:0]const u8) bool;
extern fn ImGui_InvisibleButton(str_id: ?[*:0]const u8, size: Vec2, flags: ButtonFlags) bool;
extern fn ImGui_ArrowButton(str_id: ?[*:0]const u8, dir: Dir) bool;
extern fn ImGui_Checkbox(label: ?[*:0]const u8, v: ?*bool) bool;
extern fn ImGui_CheckboxFlagsIntPtr(label: ?[*:0]const u8, flags: ?*c_int, flags_value: c_int) bool;
extern fn ImGui_CheckboxFlagsUintPtr(label: ?[*:0]const u8, flags: ?*c_uint, flags_value: c_uint) bool;
extern fn ImGui_RadioButton(label: ?[*:0]const u8, active: bool) bool;
extern fn ImGui_RadioButtonIntPtr(label: ?[*:0]const u8, v: ?*c_int, v_button: c_int) bool;
extern fn ImGui_ProgressBar(fraction: f32, size_arg: Vec2, overlay: ?[*:0]const u8) void;
extern fn ImGui_Bullet() void;
extern fn ImGui_Image(user_texture_id: TextureID, size: Vec2) void;
extern fn ImGui_ImageEx(user_texture_id: TextureID, size: Vec2, uv0: Vec2, uv1: Vec2, tint_col: Vec4, border_col: Vec4) void;
extern fn ImGui_ImageButton(str_id: ?[*:0]const u8, user_texture_id: TextureID, size: Vec2) bool;
extern fn ImGui_ImageButtonEx(str_id: ?[*:0]const u8, user_texture_id: TextureID, size: Vec2, uv0: Vec2, uv1: Vec2, bg_col: Vec4, tint_col: Vec4) bool;
extern fn ImGui_BeginCombo(label: ?[*:0]const u8, preview_value: ?[*:0]const u8, flags: ComboFlags) bool;
extern fn ImGui_EndCombo() void;
extern fn ImGui_ComboChar(label: ?[*:0]const u8, current_item: ?*c_int, items: [*]const ?[*:0]const u8, items_count: c_int) bool;
extern fn ImGui_ComboCharEx(label: ?[*:0]const u8, current_item: ?*c_int, items: [*]const ?[*:0]const u8, items_count: c_int, popup_max_height_in_items: c_int) bool;
extern fn ImGui_Combo(label: ?[*:0]const u8, current_item: ?*c_int, items_separated_by_zeros: ?[*:0]const u8) bool;
extern fn ImGui_ComboEx(label: ?[*:0]const u8, current_item: ?*c_int, items_separated_by_zeros: ?[*:0]const u8, popup_max_height_in_items: c_int) bool;
extern fn ImGui_ComboCallback(label: ?[*:0]const u8, current_item: ?*c_int, items_getter: ?*const fn (?*anyopaque, c_int, ?*?[*:0]const u8) callconv(.C) bool, data: ?*anyopaque, items_count: c_int) bool;
extern fn ImGui_ComboCallbackEx(label: ?[*:0]const u8, current_item: ?*c_int, items_getter: ?*const fn (?*anyopaque, c_int, ?*?[*:0]const u8) callconv(.C) bool, data: ?*anyopaque, items_count: c_int, popup_max_height_in_items: c_int) bool;
extern fn ImGui_DragFloat(label: ?[*:0]const u8, v: ?*f32) bool;
extern fn ImGui_DragFloatEx(label: ?[*:0]const u8, v: ?*f32, v_speed: f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragFloat2(label: ?[*:0]const u8, v: [2]f32) bool;
extern fn ImGui_DragFloat2Ex(label: ?[*:0]const u8, v: [2]f32, v_speed: f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragFloat3(label: ?[*:0]const u8, v: [3]f32) bool;
extern fn ImGui_DragFloat3Ex(label: ?[*:0]const u8, v: [3]f32, v_speed: f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragFloat4(label: ?[*:0]const u8, v: [4]f32) bool;
extern fn ImGui_DragFloat4Ex(label: ?[*:0]const u8, v: [4]f32, v_speed: f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragFloatRange2(label: ?[*:0]const u8, v_current_min: ?*f32, v_current_max: ?*f32) bool;
extern fn ImGui_DragFloatRange2Ex(label: ?[*:0]const u8, v_current_min: ?*f32, v_current_max: ?*f32, v_speed: f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, format_max: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragInt(label: ?[*:0]const u8, v: ?*c_int) bool;
extern fn ImGui_DragIntEx(label: ?[*:0]const u8, v: ?*c_int, v_speed: f32, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragInt2(label: ?[*:0]const u8, v: [2]c_int) bool;
extern fn ImGui_DragInt2Ex(label: ?[*:0]const u8, v: [2]c_int, v_speed: f32, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragInt3(label: ?[*:0]const u8, v: [3]c_int) bool;
extern fn ImGui_DragInt3Ex(label: ?[*:0]const u8, v: [3]c_int, v_speed: f32, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragInt4(label: ?[*:0]const u8, v: [4]c_int) bool;
extern fn ImGui_DragInt4Ex(label: ?[*:0]const u8, v: [4]c_int, v_speed: f32, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragIntRange2(label: ?[*:0]const u8, v_current_min: ?*c_int, v_current_max: ?*c_int) bool;
extern fn ImGui_DragIntRange2Ex(label: ?[*:0]const u8, v_current_min: ?*c_int, v_current_max: ?*c_int, v_speed: f32, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, format_max: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragScalar(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque) bool;
extern fn ImGui_DragScalarEx(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, v_speed: f32, p_min: ?*anyopaque, p_max: ?*anyopaque, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_DragScalarN(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, components: c_int) bool;
extern fn ImGui_DragScalarNEx(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, components: c_int, v_speed: f32, p_min: ?*anyopaque, p_max: ?*anyopaque, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderFloat(label: ?[*:0]const u8, v: ?*f32, v_min: f32, v_max: f32) bool;
extern fn ImGui_SliderFloatEx(label: ?[*:0]const u8, v: ?*f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderFloat2(label: ?[*:0]const u8, v: [2]f32, v_min: f32, v_max: f32) bool;
extern fn ImGui_SliderFloat2Ex(label: ?[*:0]const u8, v: [2]f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderFloat3(label: ?[*:0]const u8, v: [3]f32, v_min: f32, v_max: f32) bool;
extern fn ImGui_SliderFloat3Ex(label: ?[*:0]const u8, v: [3]f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderFloat4(label: ?[*:0]const u8, v: [4]f32, v_min: f32, v_max: f32) bool;
extern fn ImGui_SliderFloat4Ex(label: ?[*:0]const u8, v: [4]f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderAngle(label: ?[*:0]const u8, v_rad: ?*f32) bool;
extern fn ImGui_SliderAngleEx(label: ?[*:0]const u8, v_rad: ?*f32, v_degrees_min: f32, v_degrees_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderInt(label: ?[*:0]const u8, v: ?*c_int, v_min: c_int, v_max: c_int) bool;
extern fn ImGui_SliderIntEx(label: ?[*:0]const u8, v: ?*c_int, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderInt2(label: ?[*:0]const u8, v: [2]c_int, v_min: c_int, v_max: c_int) bool;
extern fn ImGui_SliderInt2Ex(label: ?[*:0]const u8, v: [2]c_int, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderInt3(label: ?[*:0]const u8, v: [3]c_int, v_min: c_int, v_max: c_int) bool;
extern fn ImGui_SliderInt3Ex(label: ?[*:0]const u8, v: [3]c_int, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderInt4(label: ?[*:0]const u8, v: [4]c_int, v_min: c_int, v_max: c_int) bool;
extern fn ImGui_SliderInt4Ex(label: ?[*:0]const u8, v: [4]c_int, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderScalar(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, p_min: ?*anyopaque, p_max: ?*anyopaque) bool;
extern fn ImGui_SliderScalarEx(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, p_min: ?*anyopaque, p_max: ?*anyopaque, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_SliderScalarN(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, components: c_int, p_min: ?*anyopaque, p_max: ?*anyopaque) bool;
extern fn ImGui_SliderScalarNEx(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, components: c_int, p_min: ?*anyopaque, p_max: ?*anyopaque, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_VSliderFloat(label: ?[*:0]const u8, size: Vec2, v: ?*f32, v_min: f32, v_max: f32) bool;
extern fn ImGui_VSliderFloatEx(label: ?[*:0]const u8, size: Vec2, v: ?*f32, v_min: f32, v_max: f32, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_VSliderInt(label: ?[*:0]const u8, size: Vec2, v: ?*c_int, v_min: c_int, v_max: c_int) bool;
extern fn ImGui_VSliderIntEx(label: ?[*:0]const u8, size: Vec2, v: ?*c_int, v_min: c_int, v_max: c_int, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_VSliderScalar(label: ?[*:0]const u8, size: Vec2, data_type: DataType, p_data: ?*anyopaque, p_min: ?*anyopaque, p_max: ?*anyopaque) bool;
extern fn ImGui_VSliderScalarEx(label: ?[*:0]const u8, size: Vec2, data_type: DataType, p_data: ?*anyopaque, p_min: ?*anyopaque, p_max: ?*anyopaque, format: ?[*:0]const u8, flags: SliderFlags) bool;
extern fn ImGui_InputText(label: ?[*:0]const u8, buf: ?[*:0]const u8, buf_size: usize, flags: InputTextFlags) bool;
extern fn ImGui_InputTextEx(label: ?[*:0]const u8, buf: ?[*:0]const u8, buf_size: usize, flags: InputTextFlags, callback: InputTextCallback, user_data: ?*anyopaque) bool;
extern fn ImGui_InputTextMultiline(label: ?[*:0]const u8, buf: ?[*:0]const u8, buf_size: usize) bool;
extern fn ImGui_InputTextMultilineEx(label: ?[*:0]const u8, buf: ?[*:0]const u8, buf_size: usize, size: Vec2, flags: InputTextFlags, callback: InputTextCallback, user_data: ?*anyopaque) bool;
extern fn ImGui_InputTextWithHint(label: ?[*:0]const u8, hint: ?[*:0]const u8, buf: ?[*:0]const u8, buf_size: usize, flags: InputTextFlags) bool;
extern fn ImGui_InputTextWithHintEx(label: ?[*:0]const u8, hint: ?[*:0]const u8, buf: ?[*:0]const u8, buf_size: usize, flags: InputTextFlags, callback: InputTextCallback, user_data: ?*anyopaque) bool;
extern fn ImGui_InputFloat(label: ?[*:0]const u8, v: ?*f32) bool;
extern fn ImGui_InputFloatEx(label: ?[*:0]const u8, v: ?*f32, step: f32, step_fast: f32, format: ?[*:0]const u8, flags: InputTextFlags) bool;
extern fn ImGui_InputFloat2(label: ?[*:0]const u8, v: [2]f32) bool;
extern fn ImGui_InputFloat2Ex(label: ?[*:0]const u8, v: [2]f32, format: ?[*:0]const u8, flags: InputTextFlags) bool;
extern fn ImGui_InputFloat3(label: ?[*:0]const u8, v: [3]f32) bool;
extern fn ImGui_InputFloat3Ex(label: ?[*:0]const u8, v: [3]f32, format: ?[*:0]const u8, flags: InputTextFlags) bool;
extern fn ImGui_InputFloat4(label: ?[*:0]const u8, v: [4]f32) bool;
extern fn ImGui_InputFloat4Ex(label: ?[*:0]const u8, v: [4]f32, format: ?[*:0]const u8, flags: InputTextFlags) bool;
extern fn ImGui_InputInt(label: ?[*:0]const u8, v: ?*c_int) bool;
extern fn ImGui_InputIntEx(label: ?[*:0]const u8, v: ?*c_int, step: c_int, step_fast: c_int, flags: InputTextFlags) bool;
extern fn ImGui_InputInt2(label: ?[*:0]const u8, v: [2]c_int, flags: InputTextFlags) bool;
extern fn ImGui_InputInt3(label: ?[*:0]const u8, v: [3]c_int, flags: InputTextFlags) bool;
extern fn ImGui_InputInt4(label: ?[*:0]const u8, v: [4]c_int, flags: InputTextFlags) bool;
extern fn ImGui_InputDouble(label: ?[*:0]const u8, v: ?*f64) bool;
extern fn ImGui_InputDoubleEx(label: ?[*:0]const u8, v: ?*f64, step: f64, step_fast: f64, format: ?[*:0]const u8, flags: InputTextFlags) bool;
extern fn ImGui_InputScalar(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque) bool;
extern fn ImGui_InputScalarEx(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, p_step: ?*anyopaque, p_step_fast: ?*anyopaque, format: ?[*:0]const u8, flags: InputTextFlags) bool;
extern fn ImGui_InputScalarN(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, components: c_int) bool;
extern fn ImGui_InputScalarNEx(label: ?[*:0]const u8, data_type: DataType, p_data: ?*anyopaque, components: c_int, p_step: ?*anyopaque, p_step_fast: ?*anyopaque, format: ?[*:0]const u8, flags: InputTextFlags) bool;
extern fn ImGui_ColorEdit3(label: ?[*:0]const u8, col: [3]f32, flags: ColorEditFlags) bool;
extern fn ImGui_ColorEdit4(label: ?[*:0]const u8, col: [4]f32, flags: ColorEditFlags) bool;
extern fn ImGui_ColorPicker3(label: ?[*:0]const u8, col: [3]f32, flags: ColorEditFlags) bool;
extern fn ImGui_ColorPicker4(label: ?[*:0]const u8, col: [4]f32, flags: ColorEditFlags, ref_col: ?*const f32) bool;
extern fn ImGui_ColorButton(desc_id: ?[*:0]const u8, col: Vec4, flags: ColorEditFlags) bool;
extern fn ImGui_ColorButtonEx(desc_id: ?[*:0]const u8, col: Vec4, flags: ColorEditFlags, size: Vec2) bool;
extern fn ImGui_SetColorEditOptions(flags: ColorEditFlags) void;
extern fn ImGui_TreeNode(label: ?[*:0]const u8) bool;
extern fn ImGui_TreeNodeStr(str_id: ?[*:0]const u8, fmt: ?[*:0]const u8, ...) bool;
extern fn ImGui_TreeNodePtr(ptr_id: ?*anyopaque, fmt: ?[*:0]const u8, ...) bool;
extern fn ImGui_TreeNodeV(str_id: ?[*:0]const u8, fmt: ?[*:0]const u8, args: c.va_list) bool;
extern fn ImGui_TreeNodeVPtr(ptr_id: ?*anyopaque, fmt: ?[*:0]const u8, args: c.va_list) bool;
extern fn ImGui_TreeNodeEx(label: ?[*:0]const u8, flags: TreeNodeFlags) bool;
extern fn ImGui_TreeNodeExStr(str_id: ?[*:0]const u8, flags: TreeNodeFlags, fmt: ?[*:0]const u8, ...) bool;
extern fn ImGui_TreeNodeExPtr(ptr_id: ?*anyopaque, flags: TreeNodeFlags, fmt: ?[*:0]const u8, ...) bool;
extern fn ImGui_TreeNodeExV(str_id: ?[*:0]const u8, flags: TreeNodeFlags, fmt: ?[*:0]const u8, args: c.va_list) bool;
extern fn ImGui_TreeNodeExVPtr(ptr_id: ?*anyopaque, flags: TreeNodeFlags, fmt: ?[*:0]const u8, args: c.va_list) bool;
extern fn ImGui_TreePush(str_id: ?[*:0]const u8) void;
extern fn ImGui_TreePushPtr(ptr_id: ?*anyopaque) void;
extern fn ImGui_TreePop() void;
extern fn ImGui_GetTreeNodeToLabelSpacing() f32;
extern fn ImGui_CollapsingHeader(label: ?[*:0]const u8, flags: TreeNodeFlags) bool;
extern fn ImGui_CollapsingHeaderBoolPtr(label: ?[*:0]const u8, p_visible: ?*bool, flags: TreeNodeFlags) bool;
extern fn ImGui_SetNextItemOpen(is_open: bool, cond: Cond) void;
extern fn ImGui_Selectable(label: ?[*:0]const u8) bool;
extern fn ImGui_SelectableEx(label: ?[*:0]const u8, selected: bool, flags: SelectableFlags, size: Vec2) bool;
extern fn ImGui_SelectableBoolPtr(label: ?[*:0]const u8, p_selected: ?*bool, flags: SelectableFlags) bool;
extern fn ImGui_SelectableBoolPtrEx(label: ?[*:0]const u8, p_selected: ?*bool, flags: SelectableFlags, size: Vec2) bool;
extern fn ImGui_BeginListBox(label: ?[*:0]const u8, size: Vec2) bool;
extern fn ImGui_EndListBox() void;
extern fn ImGui_ListBox(label: ?[*:0]const u8, current_item: ?*c_int, items: [*]const ?[*:0]const u8, items_count: c_int, height_in_items: c_int) bool;
extern fn ImGui_ListBoxCallback(label: ?[*:0]const u8, current_item: ?*c_int, items_getter: ?*const fn (?*anyopaque, c_int, ?*?[*:0]const u8) callconv(.C) bool, data: ?*anyopaque, items_count: c_int) bool;
extern fn ImGui_ListBoxCallbackEx(label: ?[*:0]const u8, current_item: ?*c_int, items_getter: ?*const fn (?*anyopaque, c_int, ?*?[*:0]const u8) callconv(.C) bool, data: ?*anyopaque, items_count: c_int, height_in_items: c_int) bool;
extern fn ImGui_PlotLines(label: ?[*:0]const u8, values: ?*const f32, values_count: c_int) void;
extern fn ImGui_PlotLinesEx(label: ?[*:0]const u8, values: ?*const f32, values_count: c_int, values_offset: c_int, overlay_text: ?[*:0]const u8, scale_min: f32, scale_max: f32, graph_size: Vec2, stride: c_int) void;
extern fn ImGui_PlotLinesCallback(label: ?[*:0]const u8, values_getter: ?*const fn (?*anyopaque, c_int) callconv(.C) f32, data: ?*anyopaque, values_count: c_int) void;
extern fn ImGui_PlotLinesCallbackEx(label: ?[*:0]const u8, values_getter: ?*const fn (?*anyopaque, c_int) callconv(.C) f32, data: ?*anyopaque, values_count: c_int, values_offset: c_int, overlay_text: ?[*:0]const u8, scale_min: f32, scale_max: f32, graph_size: Vec2) void;
extern fn ImGui_PlotHistogram(label: ?[*:0]const u8, values: ?*const f32, values_count: c_int) void;
extern fn ImGui_PlotHistogramEx(label: ?[*:0]const u8, values: ?*const f32, values_count: c_int, values_offset: c_int, overlay_text: ?[*:0]const u8, scale_min: f32, scale_max: f32, graph_size: Vec2, stride: c_int) void;
extern fn ImGui_PlotHistogramCallback(label: ?[*:0]const u8, values_getter: ?*const fn (?*anyopaque, c_int) callconv(.C) f32, data: ?*anyopaque, values_count: c_int) void;
extern fn ImGui_PlotHistogramCallbackEx(label: ?[*:0]const u8, values_getter: ?*const fn (?*anyopaque, c_int) callconv(.C) f32, data: ?*anyopaque, values_count: c_int, values_offset: c_int, overlay_text: ?[*:0]const u8, scale_min: f32, scale_max: f32, graph_size: Vec2) void;
extern fn ImGui_BeginMenuBar() bool;
extern fn ImGui_EndMenuBar() void;
extern fn ImGui_BeginMainMenuBar() bool;
extern fn ImGui_EndMainMenuBar() void;
extern fn ImGui_BeginMenu(label: ?[*:0]const u8) bool;
extern fn ImGui_BeginMenuEx(label: ?[*:0]const u8, enabled: bool) bool;
extern fn ImGui_EndMenu() void;
extern fn ImGui_MenuItem(label: ?[*:0]const u8) bool;
extern fn ImGui_MenuItemEx(label: ?[*:0]const u8, shortcut: ?[*:0]const u8, selected: bool, enabled: bool) bool;
extern fn ImGui_MenuItemBoolPtr(label: ?[*:0]const u8, shortcut: ?[*:0]const u8, p_selected: ?*bool, enabled: bool) bool;
extern fn ImGui_BeginTooltip() bool;
extern fn ImGui_EndTooltip() void;
extern fn ImGui_SetTooltip(fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_SetTooltipV(fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_BeginItemTooltip() bool;
extern fn ImGui_SetItemTooltip(fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_SetItemTooltipV(fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_BeginPopup(str_id: ?[*:0]const u8, flags: WindowFlags) bool;
extern fn ImGui_BeginPopupModal(name: ?[*:0]const u8, p_open: ?*bool, flags: WindowFlags) bool;
extern fn ImGui_EndPopup() void;
extern fn ImGui_OpenPopup(str_id: ?[*:0]const u8, popup_flags: PopupFlags) void;
extern fn ImGui_OpenPopupID(id: ID, popup_flags: PopupFlags) void;
extern fn ImGui_OpenPopupOnItemClick(str_id: ?[*:0]const u8, popup_flags: PopupFlags) void;
extern fn ImGui_CloseCurrentPopup() void;
extern fn ImGui_BeginPopupContextItem() bool;
extern fn ImGui_BeginPopupContextItemEx(str_id: ?[*:0]const u8, popup_flags: PopupFlags) bool;
extern fn ImGui_BeginPopupContextWindow() bool;
extern fn ImGui_BeginPopupContextWindowEx(str_id: ?[*:0]const u8, popup_flags: PopupFlags) bool;
extern fn ImGui_BeginPopupContextVoid() bool;
extern fn ImGui_BeginPopupContextVoidEx(str_id: ?[*:0]const u8, popup_flags: PopupFlags) bool;
extern fn ImGui_IsPopupOpen(str_id: ?[*:0]const u8, flags: PopupFlags) bool;
extern fn ImGui_BeginTable(str_id: ?[*:0]const u8, column: c_int, flags: TableFlags) bool;
extern fn ImGui_BeginTableEx(str_id: ?[*:0]const u8, column: c_int, flags: TableFlags, outer_size: Vec2, inner_width: f32) bool;
extern fn ImGui_EndTable() void;
extern fn ImGui_TableNextRow() void;
extern fn ImGui_TableNextRowEx(row_flags: TableRowFlags, min_row_height: f32) void;
extern fn ImGui_TableNextColumn() bool;
extern fn ImGui_TableSetColumnIndex(column_n: c_int) bool;
extern fn ImGui_TableSetupColumn(label: ?[*:0]const u8, flags: TableColumnFlags) void;
extern fn ImGui_TableSetupColumnEx(label: ?[*:0]const u8, flags: TableColumnFlags, init_width_or_weight: f32, user_id: ID) void;
extern fn ImGui_TableSetupScrollFreeze(cols: c_int, rows: c_int) void;
extern fn ImGui_TableHeadersRow() void;
extern fn ImGui_TableHeader(label: ?[*:0]const u8) void;
extern fn ImGui_TableGetSortSpecs() ?*TableSortSpecs;
extern fn ImGui_TableGetColumnCount() c_int;
extern fn ImGui_TableGetColumnIndex() c_int;
extern fn ImGui_TableGetRowIndex() c_int;
extern fn ImGui_TableGetColumnName(column_n: c_int) ?[*:0]const u8;
extern fn ImGui_TableGetColumnFlags(column_n: c_int) TableColumnFlags;
extern fn ImGui_TableSetColumnEnabled(column_n: c_int, v: bool) void;
extern fn ImGui_TableSetBgColor(target: TableBgTarget, color: U32, column_n: c_int) void;
extern fn ImGui_Columns() void;
extern fn ImGui_ColumnsEx(count: c_int, id: ?[*:0]const u8, border: bool) void;
extern fn ImGui_NextColumn() void;
extern fn ImGui_GetColumnIndex() c_int;
extern fn ImGui_GetColumnWidth(column_index: c_int) f32;
extern fn ImGui_SetColumnWidth(column_index: c_int, width: f32) void;
extern fn ImGui_GetColumnOffset(column_index: c_int) f32;
extern fn ImGui_SetColumnOffset(column_index: c_int, offset_x: f32) void;
extern fn ImGui_GetColumnsCount() c_int;
extern fn ImGui_BeginTabBar(str_id: ?[*:0]const u8, flags: TabBarFlags) bool;
extern fn ImGui_EndTabBar() void;
extern fn ImGui_BeginTabItem(label: ?[*:0]const u8, p_open: ?*bool, flags: TabItemFlags) bool;
extern fn ImGui_EndTabItem() void;
extern fn ImGui_TabItemButton(label: ?[*:0]const u8, flags: TabItemFlags) bool;
extern fn ImGui_SetTabItemClosed(tab_or_docked_window_label: ?[*:0]const u8) void;
extern fn ImGui_DockSpace(id: ID) ID;
extern fn ImGui_DockSpaceEx(id: ID, size: Vec2, flags: DockNodeFlags, window_class: ?*const WindowClass) ID;
extern fn ImGui_DockSpaceOverViewport() ID;
extern fn ImGui_DockSpaceOverViewportEx(viewport: ?*const Viewport, flags: DockNodeFlags, window_class: ?*const WindowClass) ID;
extern fn ImGui_SetNextWindowDockID(dock_id: ID, cond: Cond) void;
extern fn ImGui_SetNextWindowClass(window_class: ?*const WindowClass) void;
extern fn ImGui_GetWindowDockID() ID;
extern fn ImGui_IsWindowDocked() bool;
extern fn ImGui_LogToTTY(auto_open_depth: c_int) void;
extern fn ImGui_LogToFile(auto_open_depth: c_int, filename: ?[*:0]const u8) void;
extern fn ImGui_LogToClipboard(auto_open_depth: c_int) void;
extern fn ImGui_LogFinish() void;
extern fn ImGui_LogButtons() void;
extern fn ImGui_LogText(fmt: ?[*:0]const u8, ...) void;
extern fn ImGui_LogTextV(fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGui_BeginDragDropSource(flags: DragDropFlags) bool;
extern fn ImGui_SetDragDropPayload(type: ?[*:0]const u8, data: ?*anyopaque, sz: usize, cond: Cond) bool;
extern fn ImGui_EndDragDropSource() void;
extern fn ImGui_BeginDragDropTarget() bool;
extern fn ImGui_AcceptDragDropPayload(type: ?[*:0]const u8, flags: DragDropFlags) ?*const Payload;
extern fn ImGui_EndDragDropTarget() void;
extern fn ImGui_GetDragDropPayload() ?*const Payload;
extern fn ImGui_BeginDisabled(disabled: bool) void;
extern fn ImGui_EndDisabled() void;
extern fn ImGui_PushClipRect(clip_rect_min: Vec2, clip_rect_max: Vec2, intersect_with_current_clip_rect: bool) void;
extern fn ImGui_PopClipRect() void;
extern fn ImGui_SetItemDefaultFocus() void;
extern fn ImGui_SetKeyboardFocusHere() void;
extern fn ImGui_SetKeyboardFocusHereEx(offset: c_int) void;
extern fn ImGui_SetNextItemAllowOverlap() void;
extern fn ImGui_IsItemHovered(flags: HoveredFlags) bool;
extern fn ImGui_IsItemActive() bool;
extern fn ImGui_IsItemFocused() bool;
extern fn ImGui_IsItemClicked() bool;
extern fn ImGui_IsItemClickedEx(mouse_button: MouseButton) bool;
extern fn ImGui_IsItemVisible() bool;
extern fn ImGui_IsItemEdited() bool;
extern fn ImGui_IsItemActivated() bool;
extern fn ImGui_IsItemDeactivated() bool;
extern fn ImGui_IsItemDeactivatedAfterEdit() bool;
extern fn ImGui_IsItemToggledOpen() bool;
extern fn ImGui_IsAnyItemHovered() bool;
extern fn ImGui_IsAnyItemActive() bool;
extern fn ImGui_IsAnyItemFocused() bool;
extern fn ImGui_GetItemID() ID;
extern fn ImGui_GetItemRectMin() Vec2;
extern fn ImGui_GetItemRectMax() Vec2;
extern fn ImGui_GetItemRectSize() Vec2;
extern fn ImGui_GetMainViewport() ?*Viewport;
extern fn ImGui_GetBackgroundDrawList() ?*DrawList;
extern fn ImGui_GetForegroundDrawList() ?*DrawList;
extern fn ImGui_GetBackgroundDrawListImGuiViewportPtr(viewport: ?*Viewport) ?*DrawList;
extern fn ImGui_GetForegroundDrawListImGuiViewportPtr(viewport: ?*Viewport) ?*DrawList;
extern fn ImGui_IsRectVisibleBySize(size: Vec2) bool;
extern fn ImGui_IsRectVisible(rect_min: Vec2, rect_max: Vec2) bool;
extern fn ImGui_GetTime() f64;
extern fn ImGui_GetFrameCount() c_int;
extern fn ImGui_GetDrawListSharedData() ?*DrawListSharedData;
extern fn ImGui_GetStyleColorName(idx: Col) ?[*:0]const u8;
extern fn ImGui_SetStateStorage(storage: ?*Storage) void;
extern fn ImGui_GetStateStorage() ?*Storage;
extern fn ImGui_BeginChildFrame(id: ID, size: Vec2, flags: WindowFlags) bool;
extern fn ImGui_EndChildFrame() void;
extern fn ImGui_CalcTextSize(text: ?[*:0]const u8) Vec2;
extern fn ImGui_CalcTextSizeEx(text: ?[*:0]const u8, text_end: ?[*:0]const u8, hide_text_after_double_hash: bool, wrap_width: f32) Vec2;
extern fn ImGui_ColorConvertU32ToFloat4(in: U32) Vec4;
extern fn ImGui_ColorConvertFloat4ToU32(in: Vec4) U32;
extern fn ImGui_ColorConvertRGBtoHSV(r: f32, g: f32, b: f32, out_h: *f32, out_s: *f32, out_v: *f32) void;
extern fn ImGui_ColorConvertHSVtoRGB(h: f32, s: f32, v: f32, out_r: *f32, out_g: *f32, out_b: *f32) void;
extern fn ImGui_IsKeyDown(key: Key) bool;
extern fn ImGui_IsKeyPressed(key: Key) bool;
extern fn ImGui_IsKeyPressedEx(key: Key, repeat: bool) bool;
extern fn ImGui_IsKeyReleased(key: Key) bool;
extern fn ImGui_GetKeyPressedAmount(key: Key, repeat_delay: f32, rate: f32) c_int;
extern fn ImGui_GetKeyName(key: Key) ?[*:0]const u8;
extern fn ImGui_SetNextFrameWantCaptureKeyboard(want_capture_keyboard: bool) void;
extern fn ImGui_IsMouseDown(button: MouseButton) bool;
extern fn ImGui_IsMouseClicked(button: MouseButton) bool;
extern fn ImGui_IsMouseClickedEx(button: MouseButton, repeat: bool) bool;
extern fn ImGui_IsMouseReleased(button: MouseButton) bool;
extern fn ImGui_IsMouseDoubleClicked(button: MouseButton) bool;
extern fn ImGui_GetMouseClickedCount(button: MouseButton) c_int;
extern fn ImGui_IsMouseHoveringRect(r_min: Vec2, r_max: Vec2) bool;
extern fn ImGui_IsMouseHoveringRectEx(r_min: Vec2, r_max: Vec2, clip: bool) bool;
extern fn ImGui_IsMousePosValid(mouse_pos: ?*const Vec2) bool;
extern fn ImGui_IsAnyMouseDown() bool;
extern fn ImGui_GetMousePos() Vec2;
extern fn ImGui_GetMousePosOnOpeningCurrentPopup() Vec2;
extern fn ImGui_IsMouseDragging(button: MouseButton, lock_threshold: f32) bool;
extern fn ImGui_GetMouseDragDelta(button: MouseButton, lock_threshold: f32) Vec2;
extern fn ImGui_ResetMouseDragDelta() void;
extern fn ImGui_ResetMouseDragDeltaEx(button: MouseButton) void;
extern fn ImGui_GetMouseCursor() MouseCursor;
extern fn ImGui_SetMouseCursor(cursor_type: MouseCursor) void;
extern fn ImGui_SetNextFrameWantCaptureMouse(want_capture_mouse: bool) void;
extern fn ImGui_GetClipboardText() ?[*:0]const u8;
extern fn ImGui_SetClipboardText(text: ?[*:0]const u8) void;
extern fn ImGui_LoadIniSettingsFromDisk(ini_filename: ?[*:0]const u8) void;
extern fn ImGui_LoadIniSettingsFromMemory(ini_data: ?[*:0]const u8, ini_size: usize) void;
extern fn ImGui_SaveIniSettingsToDisk(ini_filename: ?[*:0]const u8) void;
extern fn ImGui_SaveIniSettingsToMemory(out_ini_size: ?*usize) ?[*:0]const u8;
extern fn ImGui_DebugTextEncoding(text: ?[*:0]const u8) void;
extern fn ImGui_DebugCheckVersionAndDataLayout(version_str: ?[*:0]const u8, sz_io: usize, sz_style: usize, sz_vec2: usize, sz_vec4: usize, sz_drawvert: usize, sz_drawidx: usize) bool;
extern fn ImGui_SetAllocatorFunctions(alloc_func: MemAllocFunc, free_func: MemFreeFunc, user_data: ?*anyopaque) void;
extern fn ImGui_GetAllocatorFunctions(p_alloc_func: ?*MemAllocFunc, p_free_func: ?*MemFreeFunc, p_user_data: ?*?*anyopaque) void;
extern fn ImGui_MemAlloc(size: usize) ?*anyopaque;
extern fn ImGui_MemFree(ptr: ?*anyopaque) void;
extern fn ImGui_GetPlatformIO() *PlatformIO;
extern fn ImGui_UpdatePlatformWindows() void;
extern fn ImGui_RenderPlatformWindowsDefault() void;
extern fn ImGui_RenderPlatformWindowsDefaultEx(platform_render_arg: ?*anyopaque, renderer_render_arg: ?*anyopaque) void;
extern fn ImGui_DestroyPlatformWindows() void;
extern fn ImGui_FindViewportByID(id: ID) ?*Viewport;
extern fn ImGui_FindViewportByPlatformHandle(platform_handle: ?*anyopaque) ?*Viewport;
extern fn ImVector_Construct(vector: ?*anyopaque) void;
extern fn ImVector_Destruct(vector: ?*anyopaque) void;
extern fn ImGuiStyle_ScaleAllSizes(self: *Style, scale_factor: f32) void;
extern fn ImGuiIO_AddKeyEvent(self: *IO, key: Key, down: bool) void;
extern fn ImGuiIO_AddKeyAnalogEvent(self: *IO, key: Key, down: bool, v: f32) void;
extern fn ImGuiIO_AddMousePosEvent(self: *IO, x: f32, y: f32) void;
extern fn ImGuiIO_AddMouseButtonEvent(self: *IO, button: c_int, down: bool) void;
extern fn ImGuiIO_AddMouseWheelEvent(self: *IO, wheel_x: f32, wheel_y: f32) void;
extern fn ImGuiIO_AddMouseSourceEvent(self: *IO, source: MouseSource) void;
extern fn ImGuiIO_AddMouseViewportEvent(self: *IO, id: ID) void;
extern fn ImGuiIO_AddFocusEvent(self: *IO, focused: bool) void;
extern fn ImGuiIO_AddInputCharacter(self: *IO, c: c_uint) void;
extern fn ImGuiIO_AddInputCharacterUTF16(self: *IO, c: Wchar16) void;
extern fn ImGuiIO_AddInputCharactersUTF8(self: *IO, str: ?[*:0]const u8) void;
extern fn ImGuiIO_SetKeyEventNativeData(self: *IO, key: Key, native_keycode: c_int, native_scancode: c_int) void;
extern fn ImGuiIO_SetKeyEventNativeDataEx(self: *IO, key: Key, native_keycode: c_int, native_scancode: c_int, native_legacy_index: c_int) void;
extern fn ImGuiIO_SetAppAcceptingEvents(self: *IO, accepting_events: bool) void;
extern fn ImGuiIO_ClearEventsQueue(self: *IO) void;
extern fn ImGuiIO_ClearInputKeys(self: *IO) void;
extern fn ImGuiInputTextCallbackData_DeleteChars(self: *InputTextCallbackData, pos: c_int, bytes_count: c_int) void;
extern fn ImGuiInputTextCallbackData_InsertChars(self: *InputTextCallbackData, pos: c_int, text: ?[*:0]const u8, text_end: ?[*:0]const u8) void;
extern fn ImGuiInputTextCallbackData_SelectAll(self: *InputTextCallbackData) void;
extern fn ImGuiInputTextCallbackData_ClearSelection(self: *InputTextCallbackData) void;
extern fn ImGuiInputTextCallbackData_HasSelection(self: *const InputTextCallbackData) bool;
extern fn ImGuiPayload_Clear(self: *Payload) void;
extern fn ImGuiPayload_IsDataType(self: *const Payload, type: ?[*:0]const u8) bool;
extern fn ImGuiPayload_IsPreview(self: *const Payload) bool;
extern fn ImGuiPayload_IsDelivery(self: *const Payload) bool;
extern fn ImGuiTextFilter_ImGuiTextRange_empty(self: *const TextFilter_ImGuiTextRange) bool;
extern fn ImGuiTextFilter_ImGuiTextRange_split(self: *const TextFilter_ImGuiTextRange, separator: c_char, out: ?*Vector(TextFilter_ImGuiTextRange)) void;
extern fn ImGuiTextFilter_Draw(self: *TextFilter, label: ?[*:0]const u8, width: f32) bool;
extern fn ImGuiTextFilter_PassFilter(self: *const TextFilter, text: ?[*:0]const u8, text_end: ?[*:0]const u8) bool;
extern fn ImGuiTextFilter_Build(self: *TextFilter) void;
extern fn ImGuiTextFilter_Clear(self: *TextFilter) void;
extern fn ImGuiTextFilter_IsActive(self: *const TextFilter) bool;
extern fn ImGuiTextBuffer_begin(self: *const TextBuffer) ?[*:0]const u8;
extern fn ImGuiTextBuffer_end(self: *const TextBuffer) ?[*:0]const u8;
extern fn ImGuiTextBuffer_size(self: *const TextBuffer) c_int;
extern fn ImGuiTextBuffer_empty(self: *const TextBuffer) bool;
extern fn ImGuiTextBuffer_clear(self: *TextBuffer) void;
extern fn ImGuiTextBuffer_reserve(self: *TextBuffer, capacity: c_int) void;
extern fn ImGuiTextBuffer_c_str(self: *const TextBuffer) ?[*:0]const u8;
extern fn ImGuiTextBuffer_append(self: *TextBuffer, str: ?[*:0]const u8, str_end: ?[*:0]const u8) void;
extern fn ImGuiTextBuffer_appendf(self: *TextBuffer, fmt: ?[*:0]const u8, ...) void;
extern fn ImGuiTextBuffer_appendfv(self: *TextBuffer, fmt: ?[*:0]const u8, args: c.va_list) void;
extern fn ImGuiStorage_Clear(self: *Storage) void;
extern fn ImGuiStorage_GetInt(self: *const Storage, key: ID, default_val: c_int) c_int;
extern fn ImGuiStorage_SetInt(self: *Storage, key: ID, val: c_int) void;
extern fn ImGuiStorage_GetBool(self: *const Storage, key: ID, default_val: bool) bool;
extern fn ImGuiStorage_SetBool(self: *Storage, key: ID, val: bool) void;
extern fn ImGuiStorage_GetFloat(self: *const Storage, key: ID, default_val: f32) f32;
extern fn ImGuiStorage_SetFloat(self: *Storage, key: ID, val: f32) void;
extern fn ImGuiStorage_GetVoidPtr(self: *const Storage, key: ID) ?*anyopaque;
extern fn ImGuiStorage_SetVoidPtr(self: *Storage, key: ID, val: ?*anyopaque) void;
extern fn ImGuiStorage_GetIntRef(self: *Storage, key: ID, default_val: c_int) ?*c_int;
extern fn ImGuiStorage_GetBoolRef(self: *Storage, key: ID, default_val: bool) ?*bool;
extern fn ImGuiStorage_GetFloatRef(self: *Storage, key: ID, default_val: f32) ?*f32;
extern fn ImGuiStorage_GetVoidPtrRef(self: *Storage, key: ID, default_val: ?*anyopaque) ?*?*anyopaque;
extern fn ImGuiStorage_SetAllInt(self: *Storage, val: c_int) void;
extern fn ImGuiStorage_BuildSortByKey(self: *Storage) void;
extern fn ImGuiListClipper_Begin(self: *ListClipper, items_count: c_int, items_height: f32) void;
extern fn ImGuiListClipper_End(self: *ListClipper) void;
extern fn ImGuiListClipper_Step(self: *ListClipper) bool;
extern fn ImGuiListClipper_IncludeItemByIndex(self: *ListClipper, item_index: c_int) void;
extern fn ImGuiListClipper_IncludeItemsByIndex(self: *ListClipper, item_begin: c_int, item_end: c_int) void;
extern fn ImColor_SetHSV(self: *Color, h: f32, s: f32, v: f32, a: f32) void;
extern fn ImColor_HSV(self: *Color, h: f32, s: f32, v: f32, a: f32) Color;
extern fn ImDrawCmd_GetTexID(self: *const DrawCmd) TextureID;
extern fn ImDrawListSplitter_Clear(self: *DrawListSplitter) void;
extern fn ImDrawListSplitter_ClearFreeMemory(self: *DrawListSplitter) void;
extern fn ImDrawListSplitter_Split(self: *DrawListSplitter, draw_list: ?*DrawList, count: c_int) void;
extern fn ImDrawListSplitter_Merge(self: *DrawListSplitter, draw_list: ?*DrawList) void;
extern fn ImDrawListSplitter_SetCurrentChannel(self: *DrawListSplitter, draw_list: ?*DrawList, channel_idx: c_int) void;
extern fn ImDrawList_PushClipRect(self: *DrawList, clip_rect_min: Vec2, clip_rect_max: Vec2, intersect_with_current_clip_rect: bool) void;
extern fn ImDrawList_PushClipRectFullScreen(self: *DrawList) void;
extern fn ImDrawList_PopClipRect(self: *DrawList) void;
extern fn ImDrawList_PushTextureID(self: *DrawList, texture_id: TextureID) void;
extern fn ImDrawList_PopTextureID(self: *DrawList) void;
extern fn ImDrawList_GetClipRectMin(self: *const DrawList) Vec2;
extern fn ImDrawList_GetClipRectMax(self: *const DrawList) Vec2;
extern fn ImDrawList_AddLine(self: *DrawList, p1: Vec2, p2: Vec2, col: U32) void;
extern fn ImDrawList_AddLineEx(self: *DrawList, p1: Vec2, p2: Vec2, col: U32, thickness: f32) void;
extern fn ImDrawList_AddRect(self: *DrawList, p_min: Vec2, p_max: Vec2, col: U32) void;
extern fn ImDrawList_AddRectEx(self: *DrawList, p_min: Vec2, p_max: Vec2, col: U32, rounding: f32, flags: DrawFlags, thickness: f32) void;
extern fn ImDrawList_AddRectFilled(self: *DrawList, p_min: Vec2, p_max: Vec2, col: U32) void;
extern fn ImDrawList_AddRectFilledEx(self: *DrawList, p_min: Vec2, p_max: Vec2, col: U32, rounding: f32, flags: DrawFlags) void;
extern fn ImDrawList_AddRectFilledMultiColor(self: *DrawList, p_min: Vec2, p_max: Vec2, col_upr_left: U32, col_upr_right: U32, col_bot_right: U32, col_bot_left: U32) void;
extern fn ImDrawList_AddQuad(self: *DrawList, p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2, col: U32) void;
extern fn ImDrawList_AddQuadEx(self: *DrawList, p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2, col: U32, thickness: f32) void;
extern fn ImDrawList_AddQuadFilled(self: *DrawList, p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2, col: U32) void;
extern fn ImDrawList_AddTriangle(self: *DrawList, p1: Vec2, p2: Vec2, p3: Vec2, col: U32) void;
extern fn ImDrawList_AddTriangleEx(self: *DrawList, p1: Vec2, p2: Vec2, p3: Vec2, col: U32, thickness: f32) void;
extern fn ImDrawList_AddTriangleFilled(self: *DrawList, p1: Vec2, p2: Vec2, p3: Vec2, col: U32) void;
extern fn ImDrawList_AddCircle(self: *DrawList, center: Vec2, radius: f32, col: U32) void;
extern fn ImDrawList_AddCircleEx(self: *DrawList, center: Vec2, radius: f32, col: U32, num_segments: c_int, thickness: f32) void;
extern fn ImDrawList_AddCircleFilled(self: *DrawList, center: Vec2, radius: f32, col: U32, num_segments: c_int) void;
extern fn ImDrawList_AddNgon(self: *DrawList, center: Vec2, radius: f32, col: U32, num_segments: c_int) void;
extern fn ImDrawList_AddNgonEx(self: *DrawList, center: Vec2, radius: f32, col: U32, num_segments: c_int, thickness: f32) void;
extern fn ImDrawList_AddNgonFilled(self: *DrawList, center: Vec2, radius: f32, col: U32, num_segments: c_int) void;
extern fn ImDrawList_AddText(self: *DrawList, pos: Vec2, col: U32, text_begin: ?[*:0]const u8) void;
extern fn ImDrawList_AddTextEx(self: *DrawList, pos: Vec2, col: U32, text_begin: ?[*:0]const u8, text_end: ?[*:0]const u8) void;
extern fn ImDrawList_AddTextImFontPtr(self: *DrawList, font: ?*const Font, font_size: f32, pos: Vec2, col: U32, text_begin: ?[*:0]const u8) void;
extern fn ImDrawList_AddTextImFontPtrEx(self: *DrawList, font: ?*const Font, font_size: f32, pos: Vec2, col: U32, text_begin: ?[*:0]const u8, text_end: ?[*:0]const u8, wrap_width: f32, cpu_fine_clip_rect: ?*const Vec4) void;
extern fn ImDrawList_AddPolyline(self: *DrawList, points: ?*const Vec2, num_points: c_int, col: U32, flags: DrawFlags, thickness: f32) void;
extern fn ImDrawList_AddConvexPolyFilled(self: *DrawList, points: ?*const Vec2, num_points: c_int, col: U32) void;
extern fn ImDrawList_AddBezierCubic(self: *DrawList, p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2, col: U32, thickness: f32, num_segments: c_int) void;
extern fn ImDrawList_AddBezierQuadratic(self: *DrawList, p1: Vec2, p2: Vec2, p3: Vec2, col: U32, thickness: f32, num_segments: c_int) void;
extern fn ImDrawList_AddImage(self: *DrawList, user_texture_id: TextureID, p_min: Vec2, p_max: Vec2) void;
extern fn ImDrawList_AddImageEx(self: *DrawList, user_texture_id: TextureID, p_min: Vec2, p_max: Vec2, uv_min: Vec2, uv_max: Vec2, col: U32) void;
extern fn ImDrawList_AddImageQuad(self: *DrawList, user_texture_id: TextureID, p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2) void;
extern fn ImDrawList_AddImageQuadEx(self: *DrawList, user_texture_id: TextureID, p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2, uv1: Vec2, uv2: Vec2, uv3: Vec2, uv4: Vec2, col: U32) void;
extern fn ImDrawList_AddImageRounded(self: *DrawList, user_texture_id: TextureID, p_min: Vec2, p_max: Vec2, uv_min: Vec2, uv_max: Vec2, col: U32, rounding: f32, flags: DrawFlags) void;
extern fn ImDrawList_PathClear(self: *DrawList) void;
extern fn ImDrawList_PathLineTo(self: *DrawList, pos: Vec2) void;
extern fn ImDrawList_PathLineToMergeDuplicate(self: *DrawList, pos: Vec2) void;
extern fn ImDrawList_PathFillConvex(self: *DrawList, col: U32) void;
extern fn ImDrawList_PathStroke(self: *DrawList, col: U32, flags: DrawFlags, thickness: f32) void;
extern fn ImDrawList_PathArcTo(self: *DrawList, center: Vec2, radius: f32, a_min: f32, a_max: f32, num_segments: c_int) void;
extern fn ImDrawList_PathArcToFast(self: *DrawList, center: Vec2, radius: f32, a_min_of_12: c_int, a_max_of_12: c_int) void;
extern fn ImDrawList_PathBezierCubicCurveTo(self: *DrawList, p2: Vec2, p3: Vec2, p4: Vec2, num_segments: c_int) void;
extern fn ImDrawList_PathBezierQuadraticCurveTo(self: *DrawList, p2: Vec2, p3: Vec2, num_segments: c_int) void;
extern fn ImDrawList_PathRect(self: *DrawList, rect_min: Vec2, rect_max: Vec2, rounding: f32, flags: DrawFlags) void;
extern fn ImDrawList_AddCallback(self: *DrawList, callback: DrawCallback, callback_data: ?*anyopaque) void;
extern fn ImDrawList_AddDrawCmd(self: *DrawList) void;
extern fn ImDrawList_CloneOutput(self: *const DrawList) ?*DrawList;
extern fn ImDrawList_ChannelsSplit(self: *DrawList, count: c_int) void;
extern fn ImDrawList_ChannelsMerge(self: *DrawList) void;
extern fn ImDrawList_ChannelsSetCurrent(self: *DrawList, n: c_int) void;
extern fn ImDrawList_PrimReserve(self: *DrawList, idx_count: c_int, vtx_count: c_int) void;
extern fn ImDrawList_PrimUnreserve(self: *DrawList, idx_count: c_int, vtx_count: c_int) void;
extern fn ImDrawList_PrimRect(self: *DrawList, a: Vec2, b: Vec2, col: U32) void;
extern fn ImDrawList_PrimRectUV(self: *DrawList, a: Vec2, b: Vec2, uv_a: Vec2, uv_b: Vec2, col: U32) void;
extern fn ImDrawList_PrimQuadUV(self: *DrawList, a: Vec2, b: Vec2, c: Vec2, d: Vec2, uv_a: Vec2, uv_b: Vec2, uv_c: Vec2, uv_d: Vec2, col: U32) void;
extern fn ImDrawList_PrimWriteVtx(self: *DrawList, pos: Vec2, uv: Vec2, col: U32) void;
extern fn ImDrawList_PrimWriteIdx(self: *DrawList, idx: DrawIdx) void;
extern fn ImDrawList_PrimVtx(self: *DrawList, pos: Vec2, uv: Vec2, col: U32) void;
extern fn ImDrawList__ResetForNewFrame(self: *DrawList) void;
extern fn ImDrawList__ClearFreeMemory(self: *DrawList) void;
extern fn ImDrawList__PopUnusedDrawCmd(self: *DrawList) void;
extern fn ImDrawList__TryMergeDrawCmds(self: *DrawList) void;
extern fn ImDrawList__OnChangedClipRect(self: *DrawList) void;
extern fn ImDrawList__OnChangedTextureID(self: *DrawList) void;
extern fn ImDrawList__OnChangedVtxOffset(self: *DrawList) void;
extern fn ImDrawList__CalcCircleAutoSegmentCount(self: *const DrawList, radius: f32) c_int;
extern fn ImDrawList__PathArcToFastEx(self: *DrawList, center: Vec2, radius: f32, a_min_sample: c_int, a_max_sample: c_int, a_step: c_int) void;
extern fn ImDrawList__PathArcToN(self: *DrawList, center: Vec2, radius: f32, a_min: f32, a_max: f32, num_segments: c_int) void;
extern fn ImDrawData_Clear(self: *DrawData) void;
extern fn ImDrawData_AddDrawList(self: *DrawData, draw_list: ?*DrawList) void;
extern fn ImDrawData_DeIndexAllBuffers(self: *DrawData) void;
extern fn ImDrawData_ScaleClipRects(self: *DrawData, fb_scale: Vec2) void;
extern fn ImFontGlyphRangesBuilder_Clear(self: *FontGlyphRangesBuilder) void;
extern fn ImFontGlyphRangesBuilder_GetBit(self: *const FontGlyphRangesBuilder, n: usize) bool;
extern fn ImFontGlyphRangesBuilder_SetBit(self: *FontGlyphRangesBuilder, n: usize) void;
extern fn ImFontGlyphRangesBuilder_AddChar(self: *FontGlyphRangesBuilder, c: Wchar) void;
extern fn ImFontGlyphRangesBuilder_AddText(self: *FontGlyphRangesBuilder, text: ?[*:0]const u8, text_end: ?[*:0]const u8) void;
extern fn ImFontGlyphRangesBuilder_AddRanges(self: *FontGlyphRangesBuilder, ranges: ?*const Wchar) void;
extern fn ImFontGlyphRangesBuilder_BuildRanges(self: *FontGlyphRangesBuilder, out_ranges: ?*Vector(Wchar)) void;
extern fn ImFontAtlasCustomRect_IsPacked(self: *const FontAtlasCustomRect) bool;
extern fn ImFontAtlas_AddFont(self: *FontAtlas, font_cfg: ?*const FontConfig) ?*Font;
extern fn ImFontAtlas_AddFontDefault(self: *FontAtlas, font_cfg: ?*const FontConfig) ?*Font;
extern fn ImFontAtlas_AddFontFromFileTTF(self: *FontAtlas, filename: ?[*:0]const u8, size_pixels: f32, font_cfg: ?*const FontConfig, glyph_ranges: ?*const Wchar) ?*Font;
extern fn ImFontAtlas_AddFontFromMemoryTTF(self: *FontAtlas, font_data: ?*anyopaque, font_size: c_int, size_pixels: f32, font_cfg: ?*const FontConfig, glyph_ranges: ?*const Wchar) ?*Font;
extern fn ImFontAtlas_AddFontFromMemoryCompressedTTF(self: *FontAtlas, compressed_font_data: ?*anyopaque, compressed_font_size: c_int, size_pixels: f32, font_cfg: ?*const FontConfig, glyph_ranges: ?*const Wchar) ?*Font;
extern fn ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(self: *FontAtlas, compressed_font_data_base85: ?[*:0]const u8, size_pixels: f32, font_cfg: ?*const FontConfig, glyph_ranges: ?*const Wchar) ?*Font;
extern fn ImFontAtlas_ClearInputData(self: *FontAtlas) void;
extern fn ImFontAtlas_ClearTexData(self: *FontAtlas) void;
extern fn ImFontAtlas_ClearFonts(self: *FontAtlas) void;
extern fn ImFontAtlas_Clear(self: *FontAtlas) void;
extern fn ImFontAtlas_Build(self: *FontAtlas) bool;
extern fn ImFontAtlas_GetTexDataAsAlpha8(self: *FontAtlas, out_pixels: ?*?*c_char, out_width: ?*c_int, out_height: ?*c_int, out_bytes_per_pixel: ?*c_int) void;
extern fn ImFontAtlas_GetTexDataAsRGBA32(self: *FontAtlas, out_pixels: ?*?*c_char, out_width: ?*c_int, out_height: ?*c_int, out_bytes_per_pixel: ?*c_int) void;
extern fn ImFontAtlas_IsBuilt(self: *const FontAtlas) bool;
extern fn ImFontAtlas_SetTexID(self: *FontAtlas, id: TextureID) void;
extern fn ImFontAtlas_GetGlyphRangesDefault(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_GetGlyphRangesGreek(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_GetGlyphRangesKorean(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_GetGlyphRangesJapanese(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_GetGlyphRangesChineseFull(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_GetGlyphRangesChineseSimplifiedCommon(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_GetGlyphRangesCyrillic(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_GetGlyphRangesThai(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_GetGlyphRangesVietnamese(self: *FontAtlas) ?*const Wchar;
extern fn ImFontAtlas_AddCustomRectRegular(self: *FontAtlas, width: c_int, height: c_int) c_int;
extern fn ImFontAtlas_AddCustomRectFontGlyph(self: *FontAtlas, font: ?*Font, id: Wchar, width: c_int, height: c_int, advance_x: f32, offset: Vec2) c_int;
extern fn ImFontAtlas_GetCustomRectByIndex(self: *FontAtlas, index: c_int) ?*FontAtlasCustomRect;
extern fn ImFontAtlas_CalcCustomRectUV(self: *const FontAtlas, rect: ?*const FontAtlasCustomRect, out_uv_min: ?*Vec2, out_uv_max: ?*Vec2) void;
extern fn ImFontAtlas_GetMouseCursorTexData(self: *FontAtlas, cursor: MouseCursor, out_offset: ?*Vec2, out_size: ?*Vec2, out_uv_border: [2]Vec2, out_uv_fill: [2]Vec2) bool;
extern fn ImFont_FindGlyph(self: *const Font, c: Wchar) ?*const FontGlyph;
extern fn ImFont_FindGlyphNoFallback(self: *const Font, c: Wchar) ?*const FontGlyph;
extern fn ImFont_GetCharAdvance(self: *const Font, c: Wchar) f32;
extern fn ImFont_IsLoaded(self: *const Font) bool;
extern fn ImFont_GetDebugName(self: *const Font) ?[*:0]const u8;
extern fn ImFont_CalcTextSizeA(self: *const Font, size: f32, max_width: f32, wrap_width: f32, text_begin: ?[*:0]const u8) Vec2;
extern fn ImFont_CalcTextSizeAEx(self: *const Font, size: f32, max_width: f32, wrap_width: f32, text_begin: ?[*:0]const u8, text_end: ?[*:0]const u8, remaining: ?*?[*:0]const u8) Vec2;
extern fn ImFont_CalcWordWrapPositionA(self: *const Font, scale: f32, text: ?[*:0]const u8, text_end: ?[*:0]const u8, wrap_width: f32) ?[*:0]const u8;
extern fn ImFont_RenderChar(self: *const Font, draw_list: ?*DrawList, size: f32, pos: Vec2, col: U32, c: Wchar) void;
extern fn ImFont_RenderText(self: *const Font, draw_list: ?*DrawList, size: f32, pos: Vec2, col: U32, clip_rect: Vec4, text_begin: ?[*:0]const u8, text_end: ?[*:0]const u8, wrap_width: f32, cpu_fine_clip: bool) void;
extern fn ImFont_BuildLookupTable(self: *Font) void;
extern fn ImFont_ClearOutputData(self: *Font) void;
extern fn ImFont_GrowIndex(self: *Font, new_size: c_int) void;
extern fn ImFont_AddGlyph(self: *Font, src_cfg: ?*const FontConfig, c: Wchar, x0: f32, y0: f32, x1: f32, y1: f32, u0: f32, v0: f32, u1: f32, v1: f32, advance_x: f32) void;
extern fn ImFont_AddRemapChar(self: *Font, dst: Wchar, src: Wchar, overwrite_dst: bool) void;
extern fn ImFont_SetGlyphVisible(self: *Font, c: Wchar, visible: bool) void;
extern fn ImFont_IsGlyphRangeUnused(self: *Font, c_begin: c_uint, c_last: c_uint) bool;
extern fn ImGuiViewport_GetCenter(self: *const Viewport) Vec2;
extern fn ImGuiViewport_GetWorkCenter(self: *const Viewport) Vec2;
extern fn ImGui_GetKeyIndex(key: Key) Key;

//-----------------------------------------------------------------------------
// Internal
//-----------------------------------------------------------------------------

const alignment = 16;

fn zigAlloc(sz: usize, user_data: ?*anyopaque) callconv(.C) ?*anyopaque {
    var allocator: *std.mem.Allocator = @ptrCast(@alignCast(user_data));

    if (allocator.alignedAlloc(u8, alignment, sz + alignment)) |mem| {
        const user_ptr = mem.ptr + alignment;
        var info_ptr: *usize = @ptrCast(mem.ptr);
        info_ptr.* = sz + alignment;
        return user_ptr;
    } else |_| {
        return null;
    }
}

fn zigFree(ptr: ?*anyopaque, user_data: ?*anyopaque) callconv(.C) void {
    var allocator: *std.mem.Allocator = @ptrCast(@alignCast(user_data));

    if (ptr) |p| {
        const user_ptr: [*]align(alignment) u8 = @ptrCast(@alignCast(p));
        const mem_ptr = user_ptr - alignment;
        const info_ptr: *usize = @ptrCast(mem_ptr);
        const sz = info_ptr.*;
        allocator.free(mem_ptr[0..sz]);
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
