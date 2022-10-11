pub extern const tinyfd_version: [8]u8;
pub extern const tinyfd_needs: [*c]const u8;
pub extern var tinyfd_verbose: c_int;
pub extern var tinyfd_silent: c_int;
pub extern var tinyfd_forceConsole: c_int;
pub extern var tinyfd_response: [1024]u8;

pub extern fn tinyfd_beep() void;
pub extern fn tinyfd_notifyPopup(aTitle: [*c]const u8, aMessage: [*c]const u8, aIconType: [*c]const u8) c_int;
pub extern fn tinyfd_messageBox(aTitle: [*c]const u8, aMessage: [*c]const u8, aDialogType: [*c]const u8, aIconType: [*c]const u8, aDefaultButton: c_int) c_int;
pub extern fn tinyfd_inputBox(aTitle: [*c]const u8, aMessage: [*c]const u8, aDefaultInput: [*c]const u8) [*c]u8;
pub extern fn tinyfd_saveFileDialog(aTitle: [*c]const u8, aDefaultPathAndFile: [*c]const u8, aNumOfFilterPatterns: c_int, aFilterPatterns: [*c]const [*c]const u8, aSingleFilterDescription: [*c]const u8) [*c]u8;
pub extern fn tinyfd_openFileDialog(aTitle: [*c]const u8, aDefaultPathAndFile: [*c]const u8, aNumOfFilterPatterns: c_int, aFilterPatterns: [*c]const [*c]const u8, aSingleFilterDescription: [*c]const u8, aAllowMultipleSelects: c_int) [*c]u8;
pub extern fn tinyfd_selectFolderDialog(aTitle: [*c]const u8, aDefaultPath: [*c]const u8) [*c]u8;
pub extern fn tinyfd_colorChooser(aTitle: [*c]const u8, aDefaultHexRGB: [*c]const u8, aDefaultRGB: [*c]const u8, aoResultRGB: [*c]u8) [*c]u8;
pub extern fn tinyfd_arrayDialog(aTitle: [*c]const u8, aNumOfColumns: c_int, aColumns: [*c]const [*c]const u8, aNumOfRows: c_int, aCells: [*c]const [*c]const u8) [*c]u8;

pub fn openFileDialog(title: [:0]const u8, path: [:0]const u8, filter: [:0]const u8) [*c]u8 {
    const filters = &[_][*c]const u8{@ptrCast([*c]const u8, filter)};
    return tinyfd_openFileDialog(title, path, 1, filters, null, 0);
}

pub fn saveFileDialog(title: [:0]const u8, path: [:0]const u8, filter: [:0]const u8) [*c]u8 {
    const filters = &[_][*c]const u8{@ptrCast([*c]const u8, filter)};
    return tinyfd_saveFileDialog(title, path, 1, filters, null);
}
