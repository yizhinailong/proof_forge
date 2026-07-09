//! Minimal Cloudflare Workers Wasm guest for the Counter spike.
//!
//! This is a hand-written stand-in for what ProofForge's EmitZig backend would
//! eventually generate from `ProofForge/IR/Examples/Counter.lean`.
//!
//! Guest/host protocol:
//! - Request (UTF-8):  "initialize\n" | "increment\n" | "get\n"
//! - Response (UTF-8): "OK\n<value>" | "ERR\n<message>"
//!
//! Host imports (provided by worker.js):
//! - kv_get(key_ptr, key_len) -> u32  (pointer to null-terminated value, or 0)
//! - kv_put(key_ptr, key_len, value_ptr, value_len)
//! - console_log(msg_ptr, msg_len)
//! - get_caller(buf_ptr, buf_len) -> u32 (writes caller string, returns length)
//!
//! Guest exports:
//! - memory
//! - malloc(size) -> u32
//! - free(ptr)
//! - fetch(req_ptr, req_len) -> u32  (response pointer)

const std = @import("std");

// Host imports ---------------------------------------------------------------
extern fn kv_get(key_ptr: u32, key_len: u32) u32;
extern fn kv_put(key_ptr: u32, key_len: u32, value_ptr: u32, value_len: u32) void;
extern fn console_log(msg_ptr: u32, msg_len: u32) void;
extern fn get_caller(buf_ptr: u32, buf_len: u32) u32;

// Simple bump allocator: the spike leaks, but deterministically within one request.
var bump_buffer: [65536]u8 = undefined;
var bump_offset: usize = 0;

fn bumpAllocFn(_: *anyopaque, len: usize, ptr_align: std.mem.Alignment, _: usize) ?[*]u8 {
    const align_val = @as(usize, 1) << @intFromEnum(ptr_align);
    const aligned = (bump_offset + align_val - 1) & ~(align_val - 1);
    if (aligned + len > bump_buffer.len) return null;
    bump_offset = aligned + len;
    return @ptrCast(&bump_buffer[aligned]);
}

fn bumpResizeFn(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
    return false;
}

fn bumpFreeFn(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {}

fn bumpRemapFn(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
    return null;
}

const bump_vtable: std.mem.Allocator.VTable = .{
    .alloc = &bumpAllocFn,
    .resize = &bumpResizeFn,
    .free = &bumpFreeFn,
    .remap = &bumpRemapFn,
};

fn bumpAllocator() std.mem.Allocator {
    return .{
        .ptr = undefined,
        .vtable = &bump_vtable,
    };
}

fn log(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(bumpAllocator(), fmt, args) catch return;
    console_log(@intFromPtr(msg.ptr), @intCast(msg.len));
}

// Memory helpers --------------------------------------------------------------
fn slice(ptr: u32, len: u32) []u8 {
    return @as([*]u8, @ptrFromInt(@as(usize, ptr)))[0..len];
}

fn sliceConst(ptr: u32, len: u32) []const u8 {
    return @as([*]const u8, @ptrFromInt(@as(usize, ptr)))[0..len];
}

fn dupeZ(src: []const u8) ![:0]u8 {
    const copy = try bumpAllocator().alloc(u8, src.len + 1);
    @memcpy(copy[0..src.len], src);
    copy[src.len] = 0;
    return copy[0..src.len :0];
}

fn trimRightWhitespace(src: []const u8) []const u8 {
    var end = src.len;
    while (end > 0) {
        const c = src[end - 1];
        if (c == '\n' or c == '\r' or c == ' ' or c == '\t') {
            end -= 1;
        } else {
            break;
        }
    }
    return src[0..end];
}

// KV helpers ------------------------------------------------------------------
const COUNT_KEY = "count";

fn kvGetU64() ?u64 {
    const value_ptr = kv_get(@intFromPtr(COUNT_KEY.ptr), COUNT_KEY.len);
    if (value_ptr == 0) return null;
    const value_z = @as([*:0]const u8, @ptrFromInt(@as(usize, value_ptr)));
    const value = std.mem.span(value_z);
    defer free(value_ptr);
    return std.fmt.parseInt(u64, value, 10) catch null;
}

fn kvPutU64(value: u64) void {
    const text = std.fmt.allocPrint(bumpAllocator(), "{d}", .{value}) catch return;
    kv_put(@intFromPtr(COUNT_KEY.ptr), COUNT_KEY.len, @intFromPtr(text.ptr), @intCast(text.len));
}

// Response builder ------------------------------------------------------------
fn responseOk(value: u64) u32 {
    const text = std.fmt.allocPrint(bumpAllocator(), "OK\n{d}", .{value}) catch return 0;
    const copy = dupeZ(text) catch return 0;
    return @intFromPtr(copy.ptr);
}

fn responseErr(comptime msg: []const u8) u32 {
    const copy = dupeZ("ERR\n" ++ msg) catch return 0;
    return @intFromPtr(copy.ptr);
}

// Entrypoints -----------------------------------------------------------------
fn initialize() u32 {
    kvPutU64(0);
    log("initialized count=0", .{});
    return responseOk(0);
}

fn increment() u32 {
    const current = kvGetU64() orelse 0;
    const next = current +% 1;
    kvPutU64(next);
    log("incremented {d} -> {d}", .{ current, next });
    return responseOk(next);
}

fn get() u32 {
    const current = kvGetU64() orelse 0;
    return responseOk(current);
}

// Exported API ----------------------------------------------------------------
export fn malloc(size: u32) u32 {
    const ptr = bumpAllocator().alloc(u8, size) catch return 0;
    return @intFromPtr(ptr.ptr);
}

export fn free(ptr: u32) void {
    // Bump allocator does not support individual frees.
    _ = ptr;
}

export fn fetch(req_ptr: u32, req_len: u32) u32 {
    const req = sliceConst(req_ptr, req_len);
    const method = trimRightWhitespace(req);

    log("fetch method={s}", .{method});

    if (std.mem.eql(u8, method, "initialize")) {
        return initialize();
    } else if (std.mem.eql(u8, method, "increment")) {
        return increment();
    } else if (std.mem.eql(u8, method, "get")) {
        return get();
    } else {
        return responseErr("unknown method");
    }
}
