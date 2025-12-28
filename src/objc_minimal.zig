//! Minimal objc wrapper for Zig 0.16 compatibility
//! Only imports the parts we actually use, avoiding @Type issues

const objc_full = @import("objc");

// Re-export everything except Block and the fancy msgSend wrapper
pub const c = objc_full.c;

/// On some targets, Objective-C uses `i8` instead of `bool`.
/// This helper casts a `bool` value to the target value type.
pub fn boolParam(param: bool) c.BOOL {
    return switch (c.BOOL) {
        bool => param,
        i8 => @intFromBool(param),
        else => @compileError("unexpected boolean type"),
    };
}

/// On some targets, Objective-C uses `i8` instead of `bool`.
/// This helper casts a target value type to `bool`.
pub fn boolResult(result: c.BOOL) bool {
    return switch (c.BOOL) {
        bool => result,
        i8 => result == 1,
        else => @compileError("unexpected boolean type"),
    };
}
pub const AutoreleasePool = objc_full.AutoreleasePool;
pub const Class = objc_full.Class;
pub const getClass = objc_full.getClass;
pub const getMetaClass = objc_full.getMetaClass;
pub const allocateClassPair = objc_full.allocateClassPair;
pub const registerClassPair = objc_full.registerClassPair;
pub const disposeClassPair = objc_full.disposeClassPair;
pub const Encoding = objc_full.Encoding;
pub const Iterator = objc_full.Iterator;
pub const Object = objc_full.Object;
pub const Property = objc_full.Property;
pub const Protocol = objc_full.Protocol;
pub const getProtocol = objc_full.getProtocol;
pub const sel = objc_full.sel;
pub const Sel = objc_full.Sel;
pub const free = objc_full.free;

// Note: We intentionally don't re-export Block or the type-building msgSend
// because they use @Type which was removed in Zig 0.16.
// We use Object.msgSend directly instead, which works fine.
