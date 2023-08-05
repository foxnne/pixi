pub const nfdchar_t = u8;
pub const nfdpathset_t = extern struct {
    buf: [*c]nfdchar_t,
    indices: [*c]usize,
    count: usize,
};
pub const NFD_ERROR: c_int = 0;
pub const NFD_OKAY: c_int = 1;
pub const NFD_CANCEL: c_int = 2;
pub const nfdresult_t = c_int;
pub extern fn NFD_OpenDialog(filterList: [*c]const nfdchar_t, defaultPath: [*c]const nfdchar_t, outPath: [*c][*c]nfdchar_t) nfdresult_t;
pub extern fn NFD_OpenDialogMultiple(filterList: [*c]const nfdchar_t, defaultPath: [*c]const nfdchar_t, outPaths: [*c]nfdpathset_t) nfdresult_t;
pub extern fn NFD_SaveDialog(filterList: [*c]const nfdchar_t, defaultPath: [*c]const nfdchar_t, outPath: [*c][*c]nfdchar_t) nfdresult_t;
pub extern fn NFD_PickFolder(defaultPath: [*c]const nfdchar_t, outPath: [*c][*c]nfdchar_t) nfdresult_t;
pub extern fn NFD_GetError() [*c]const u8;
pub extern fn NFD_PathSet_GetCount(pathSet: [*c]const nfdpathset_t) usize;
pub extern fn NFD_PathSet_GetPath(pathSet: [*c]const nfdpathset_t, index: usize) [*c]nfdchar_t;
pub extern fn NFD_PathSet_Free(pathSet: [*c]nfdpathset_t) void;
