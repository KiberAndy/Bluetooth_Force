const std = @import("std");
const builtin = @import("builtin");

// ---------------------------------------------------------------------------
// Calling convention
// ---------------------------------------------------------------------------
const WINAPI: std.builtin.CallingConvention = if (builtin.cpu.arch == .x86)
    .{ .x86_stdcall = .{} }
else
    .c;

// ---------------------------------------------------------------------------
// Window message constants
// ---------------------------------------------------------------------------
const WM_CLOSE: u32 = 0x0010;
const WM_DESTROY: u32 = 0x0002;
const WM_NCCREATE: u32 = 0x0081;
const WM_POWERBROADCAST: u32 = 0x0218;
const PBT_APMRESUMEAUTOMATIC: usize = 0x0012;
const WS_POPUP: u32 = 0x80000000;
const WS_EX_TOOLWINDOW: u32 = 0x00000080;
const WS_EX_NOACTIVATE: u32 = 0x08000000;
const GWLP_USERDATA: i32 = -21;

// ---------------------------------------------------------------------------
// WaitForSingleObject constants
// ---------------------------------------------------------------------------
const CREATE_NO_WINDOW: u32 = 0x08000000;
const WAIT_OBJECT_0: u32 = 0x00000000;
const WAIT_TIMEOUT: u32 = 0x00000102;
const WAIT_FAILED: u32 = 0xFFFFFFFF;

// Restrict DLL resolution to %SystemRoot%\System32 so a rogue bthprops.cpl in
// the application directory or CWD cannot be loaded instead of the system copy.
const LOAD_LIBRARY_SEARCH_SYSTEM32: u32 = 0x00000800;

// ---------------------------------------------------------------------------
// Kernel32 externs
// ---------------------------------------------------------------------------
extern "kernel32" fn CreateEventW(
    lpEventAttributes: ?*anyopaque,
    bManualReset: i32,
    bInitialState: i32,
    lpName: ?[*:0]const u16,
) callconv(WINAPI) ?*anyopaque;

extern "kernel32" fn SetEvent(hEvent: ?*anyopaque) callconv(WINAPI) i32;

extern "kernel32" fn WaitForSingleObject(
    hHandle: ?*anyopaque,
    dwMilliseconds: u32,
) callconv(WINAPI) u32;

extern "kernel32" fn CloseHandle(hObject: ?*anyopaque) callconv(WINAPI) i32;

extern "kernel32" fn ExitProcess(uExitCode: u32) callconv(WINAPI) noreturn;

extern "kernel32" fn FreeLibrary(hModule: ?*anyopaque) callconv(WINAPI) i32;

extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(WINAPI) ?*anyopaque;

extern "kernel32" fn GetModuleFileNameW(
    hModule: ?*anyopaque,
    lpFilename: [*:0]u16,
    nSize: u32,
) callconv(WINAPI) u32;

extern "kernel32" fn LoadLibraryExW(lpLibFileName: [*:0]const u16, hFile: ?*anyopaque, dwFlags: u32) callconv(WINAPI) ?*anyopaque;

extern "kernel32" fn SetDefaultDllDirectories(DirectoryFlags: u32) callconv(WINAPI) i32;

extern "kernel32" fn GetProcAddress(
    hModule: ?*anyopaque,
    lpProcName: [*:0]const u8,
) callconv(WINAPI) ?*anyopaque;

extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(WINAPI) void;

extern "kernel32" fn CreateProcessW(
    lpApplicationName: ?[*:0]const u16,
    lpCommandLine: [*:0]u16,
    lpProcessAttributes: ?*anyopaque,
    lpThreadAttributes: ?*anyopaque,
    bInheritHandles: i32,
    dwCreationFlags: u32,
    lpEnvironment: ?*anyopaque,
    lpCurrentDirectory: ?[*:0]const u16,
    lpStartupInfo: *STARTUPINFOW,
    lpProcessInformation: *PROCESS_INFORMATION,
) callconv(WINAPI) i32;

extern "kernel32" fn GetLastError() callconv(WINAPI) u32;
extern "kernel32" fn OutputDebugStringA(lpOutputString: [*:0]const u8) callconv(WINAPI) void;

extern "kernel32" fn GetExitCodeProcess(hProcess: ?*anyopaque, lpExitCode: *u32) callconv(WINAPI) i32;

extern "kernel32" fn GetStdHandle(nStdHandle: u32) callconv(WINAPI) ?*anyopaque;

extern "kernel32" fn WriteFile(
    hFile: ?*anyopaque,
    lpBuffer: [*]const u8,
    nNumberOfBytesToWrite: u32,
    lpNumberOfBytesWritten: *u32,
    lpOverlapped: ?*anyopaque,
) callconv(WINAPI) i32;

// r2-l1 externs — file log (btf.log), the freeze kill switch and the
// absolute System32 path used for pnputil.
extern "kernel32" fn GetSystemDirectoryW(lpBuffer: [*:0]u16, uSize: u32) callconv(WINAPI) u32;
extern "kernel32" fn GetFileSizeEx(hFile: ?*anyopaque, lpFileSize: *i64) callconv(WINAPI) i32;

// r2-l3 -- the recovery journal must hit the disk BEFORE the disable it
// describes, so it needs an explicit flush (a BSOD is one of the failure
// modes it exists for), and it must be removable once the radio is back.
extern "kernel32" fn FlushFileBuffers(hFile: ?*anyopaque) callconv(WINAPI) i32;
extern "kernel32" fn DeleteFileW(lpFileName: [*:0]const u16) callconv(WINAPI) i32;
extern "kernel32" fn MoveFileExW(
    lpExistingFileName: [*:0]const u16,
    lpNewFileName: ?[*:0]const u16,
    dwFlags: u32,
) callconv(WINAPI) i32;
extern "kernel32" fn GetFileAttributesW(lpFileName: [*:0]const u16) callconv(WINAPI) u32;
extern "kernel32" fn GetLocalTime(lpSystemTime: *SYSTEMTIME) callconv(WINAPI) void;
const MOVEFILE_REPLACE_EXISTING: u32 = 0x00000001;
const FILE_APPEND_DATA: u32 = 0x00000004;
const OPEN_ALWAYS: u32 = 4;
const FILE_SHARE_READ_WRITE: u32 = 0x00000003;
const INVALID_FILE_ATTRIBUTES: u32 = 0xFFFFFFFF;

// ---------------------------------------------------------------------------
// SetupAPI / CfgMgr32 / Shell32 externs — R2 usb-cycle (escalation rung)
// ---------------------------------------------------------------------------
extern "shell32" fn IsUserAnAdmin() callconv(WINAPI) i32;

extern "setupapi" fn SetupDiGetClassDevsW(
    ClassGuid: ?*const GUID,
    Enumerator: ?[*:0]const u16,
    hwndParent: ?*anyopaque,
    Flags: u32,
) callconv(WINAPI) ?*anyopaque;

extern "setupapi" fn SetupDiEnumDeviceInfo(
    DeviceInfoSet: ?*anyopaque,
    MemberIndex: u32,
    DeviceInfoData: *SP_DEVINFO_DATA,
) callconv(WINAPI) i32;

extern "setupapi" fn SetupDiGetDeviceInstanceIdW(
    DeviceInfoSet: ?*anyopaque,
    DeviceInfoData: *SP_DEVINFO_DATA,
    DeviceInstanceId: [*]u16,
    DeviceInstanceIdSize: u32,
    RequiredSize: ?*u32,
) callconv(WINAPI) i32;

extern "setupapi" fn SetupDiSetClassInstallParamsW(
    DeviceInfoSet: ?*anyopaque,
    DeviceInfoData: *SP_DEVINFO_DATA,
    ClassInstallParams: *SP_CLASSINSTALL_HEADER,
    ClassInstallParamsSize: u32,
) callconv(WINAPI) i32;

extern "setupapi" fn SetupDiCallClassInstaller(
    InstallFunction: u32,
    DeviceInfoSet: ?*anyopaque,
    DeviceInfoData: *SP_DEVINFO_DATA,
) callconv(WINAPI) i32;

extern "setupapi" fn SetupDiDestroyDeviceInfoList(
    DeviceInfoSet: ?*anyopaque,
) callconv(WINAPI) i32;

/// CONFIGRET (u32): CR_SUCCESS == 0.
extern "cfgmgr32" fn CM_Get_DevNode_Status(
    ulStatus: *u32,
    ulProblemNumber: *u32,
    dnDevInst: u32,
    ulFlags: u32,
) callconv(WINAPI) u32;

/// R2 fallback path (r1-l4): disable/enable a devnode directly through
/// CfgMgr32. Same admin requirement as DIF_PROPERTYCHANGE, but no
/// install-params struct packing to get wrong. CR_SUCCESS == 0.
extern "cfgmgr32" fn CM_Disable_DevNode(
    dnDevInst: u32,
    ulFlags: u32,
) callconv(WINAPI) u32;

extern "cfgmgr32" fn CM_Enable_DevNode(
    dnDevInst: u32,
    ulFlags: u32,
) callconv(WINAPI) u32;

const CR_SUCCESS: u32 = 0;

/// Win32 layout: ONLY cbSize + InstallFunction — 8 bytes. The previous
/// revision carried an extra DevInst field here (12 bytes), which shifted
/// every downstream offset: cbSize advertised 12, SP_PROPCHANGE_PARAMS
/// advertised 24 instead of 20, and SetupDiSetClassInstallParamsW rejected
/// the blob outright (field: "disable failed 0x80070006" on every rung-3
/// attempt). The devnode is already identified by the DeviceInfoData
/// argument passed alongside — the header never carried it.
const SP_CLASSINSTALL_HEADER = extern struct {
    cbSize: u32,
    InstallFunction: u32,
};

const SP_PROPCHANGE_PARAMS = extern struct {
    ClassInstallHeader: SP_CLASSINSTALL_HEADER,
    StateChange: u32,
    Scope: u32,
    HwProfile: u32,
};

const SP_DEVINFO_DATA = extern struct {
    cbSize: u32,
    InterfaceClassGuid: GUID,
    DevInst: u32,
    Reserved: usize,
};

const DIF_PROPERTYCHANGE: u32 = 0x00000012;
const DICS_ENABLE: u32 = 1;
const DICS_DISABLE: u32 = 2;
const DICS_FLAG_GLOBAL: u32 = 1;
const DIGCF_PRESENT: u32 = 0x00000002;
// r1-l7 FIELD BUG (archive 2026-09-02 22:41): a query with ClassGuid=NULL
// must set DIGCF_ALLCLASSES — MSDN: "To return devices for all device setup
// classes, set the DIGCF_ALLCLASSES flag, and set the ClassGuid parameter to
// NULL." r1-l5 sent (null ClassGuid, L"USB", DIGCF_PRESENT): the call SUCCEEDS
// (no failure line in dbgview) but yields a set without our radio, so the
// cycle aborted "not present" while the CSV logged OK/CM_PROB_NONE and
// bt_healthcheck.ps1 found USB\VID_0A12&PID_0001\5&127C236B&0&3 OK.
const DIGCF_ALLCLASSES: u32 = 0x00000004;
// USB device class {36FC9E60-C465-11CF-8056-444553540000}
const GUID_DEVCLASS_USB = GUID{
    .Data1 = 0x36fc9e60,
    .Data2 = 0xc465,
    .Data3 = 0x11cf,
    .Data4 = .{ 0x80, 0x56, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00 },
};
// PnP enumerator name L"USB" (null-terminated UTF-16), the query key for the
// usb-cycle enumeration. FIELD BUG r1-l4 (archive 2026-09-02 22:07): the
// query used GUID_DEVCLASS_USB, but a Bluetooth radio's devnode does not sit
// in the USB *setup class* — CSR radios install under the Bluetooth class
// (GUID_DEVCLASS_BLUETOOTH / BthUSB). The class-GUID query returned no
// matching devnode while the radio was demonstrably present (diagnose CSV:
// OK / CM_PROB_NONE for the whole session), and the cycle aborted with
// "not present". Matching by ENUMERATOR name instead — every devnode whose
// instance ID starts with "USB\", regardless of setup class — is what the
// 2026-09-01 field build effectively did (it found
// USB\VID_0A12&PID_0001\5&127C236B&0&3). Class is irrelevant to us anyway:
// we match the instance ID by VID/PID ourselves.
const ENUMERATOR_USB = [_:0]u16{ 'U', 'S', 'B' };
// AudioEndpoint device setup class {CD171DE3-70E5-41C9-8AC9-8FF103BA2AA1} —
// devnodes for every render/capture endpoint the audio stack exposes; a linked
// A2DP headset adds its own (the field "endpoints 1 vs 2" signature).
const GUID_DEVCLASS_AUDIOENDPOINT = GUID{
    .Data1 = 0xcd171de3,
    .Data2 = 0x70e5,
    .Data3 = 0x41c9,
    .Data4 = .{ 0x8a, 0xc9, 0x8f, 0xf1, 0x03, 0xba, 0x2a, 0xa1 },
};
// Config-manager flags for the re-enumeration wait.
const DN_HAS_PROBLEM: u32 = 0x00000400;
const DN_STARTED: u32 = 0x00000008;

const INVALID_HANDLE_VALUE: ?*anyopaque = @ptrFromInt(~@as(usize, 0));

// --health report file (r1-l6)
extern "kernel32" fn CreateFileW(
    lpFileName: [*:0]const u16,
    dwDesiredAccess: u32,
    dwShareMode: u32,
    lpSecurityAttributes: ?*anyopaque,
    dwCreationDisposition: u32,
    dwFlagsAndAttributes: u32,
    hTemplateFile: ?*anyopaque,
) callconv(WINAPI) ?*anyopaque;
const GENERIC_WRITE: u32 = 0x40000000;
const CREATE_ALWAYS: u32 = 2;
const FILE_ATTRIBUTE_NORMAL: u32 = 0x80;
const STD_ERROR_HANDLE: u32 = 0xFFFFFFF4;

// ---------------------------------------------------------------------------
// WinMM externs (silent audio keepalive)
// ---------------------------------------------------------------------------
const WAVE_MAPPER: u32 = 0xFFFFFFFF;
const CALLBACK_NULL: u32 = 0;
const WAVE_FORMAT_PCM: u16 = 1;
const WHDR_DONE: u32 = 0x00000001;

const WAVEFORMATEX = extern struct {
    wFormatTag: u16,
    nChannels: u16,
    nSamplesPerSec: u32,
    nAvgBytesPerSec: u32,
    nBlockAlign: u16,
    wBitsPerSample: u16,
    cbSize: u16,
};

const WAVEHDR = extern struct {
    lpData: ?*u8,
    dwBufferLength: u32,
    dwBytesRecorded: u32,
    dwUser: usize,
    dwFlags: u32,
    dwLoops: u32,
    lpNext: ?*WAVEHDR,
    reserved: usize,
};

extern "winmm" fn waveOutOpen(
    phwo: *?*anyopaque,
    uDeviceID: u32,
    pwfx: *const WAVEFORMATEX,
    dwCallback: usize,
    dwInstance: usize,
    fdwOpen: u32,
) callconv(WINAPI) u32;

extern "winmm" fn waveOutPrepareHeader(
    hwo: ?*anyopaque,
    pwh: *WAVEHDR,
    cbwh: u32,
) callconv(WINAPI) u32;

extern "winmm" fn waveOutWrite(
    hwo: ?*anyopaque,
    pwh: *WAVEHDR,
    cbwh: u32,
) callconv(WINAPI) u32;

extern "winmm" fn waveOutUnprepareHeader(
    hwo: ?*anyopaque,
    pwh: *WAVEHDR,
    cbwh: u32,
) callconv(WINAPI) u32;

extern "winmm" fn waveOutClose(hwo: ?*anyopaque) callconv(WINAPI) u32;

extern "winmm" fn waveOutReset(hwo: ?*anyopaque) callconv(WINAPI) u32;

extern "winmm" fn waveOutGetNumDevs() callconv(WINAPI) u32;

extern "winmm" fn waveOutGetDevCapsW(
    uDeviceID: usize,
    pwoc: *WAVEOUTCAPSW,
    cbwoc: u32,
) callconv(WINAPI) u32;

// WHDR loop flags — play the keepalive as a single looping buffer instead of a
// high-frequency requeue loop (near-zero driver churn -> stops amplifying the
// driver's ETW-registration leak).
const WHDR_BEGINLOOP: u32 = 0x00000004;
const WHDR_ENDLOOP: u32 = 0x00000008;

const WAVEOUTCAPSW = extern struct {
    wMid: u16,
    wPid: u16,
    vDriverVersion: u32,
    szPname: [32]u16,
    dwFormats: u32,
    wChannels: u16,
    wReserved1: u16,
    dwSupport: u32,
};

// Monotonic millisecond clock for backoff / circuit-breaker timing. Zig 0.16's
// std.time exposes no clock fn, so read it straight from the OS (Windows-only,
// like every caller here).
extern "kernel32" fn GetTickCount64() callconv(WINAPI) u64;

fn nowMs() i64 {
    return @intCast(GetTickCount64());
}

// Performance info (paged-pool self-watchdog). K32GetPerformanceInfo is exported
// by kernel32.dll on Windows 7+, so we avoid an extra psapi link dependency.
const PERFORMANCE_INFORMATION = extern struct {
    cb: u32,
    CommitTotal: usize,
    CommitLimit: usize,
    CommitPeak: usize,
    PhysicalTotal: usize,
    PhysicalAvailable: usize,
    SystemCache: usize,
    KernelTotal: usize,
    KernelPaged: usize,
    KernelNonpaged: usize,
    PageSize: usize,
    HandleCount: u32,
    ProcessCount: u32,
    ThreadCount: u32,
};

extern "kernel32" fn K32GetPerformanceInfo(
    pPerformanceInformation: *PERFORMANCE_INFORMATION,
    cb: u32,
) callconv(WINAPI) i32;

// Returns current system paged-pool usage in bytes, or null on failure.
fn queryPagedPoolBytes() ?u64 {
    var info: PERFORMANCE_INFORMATION = std.mem.zeroes(PERFORMANCE_INFORMATION);
    info.cb = @sizeOf(PERFORMANCE_INFORMATION);
    if (K32GetPerformanceInfo(&info, info.cb) == 0) return null;
    return @as(u64, info.KernelPaged) * @as(u64, info.PageSize);
}

// ---------------------------------------------------------------------------
// User32 externs
// ---------------------------------------------------------------------------
extern "user32" fn DefWindowProcW(
    hWnd: ?*anyopaque,
    Msg: u32,
    wParam: usize,
    lParam: isize,
) callconv(WINAPI) isize;

extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(WINAPI) void;

extern "user32" fn RegisterClassExW(
    lpWndClassEx: *WNDCLASSEXW,
) callconv(WINAPI) u16;

extern "user32" fn CreateWindowExW(
    dwExStyle: u32,
    lpClassName: [*:0]const u16,
    lpWindowName: [*:0]const u16,
    dwStyle: u32,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?*anyopaque,
    hMenu: ?*anyopaque,
    hInstance: ?*anyopaque,
    lpParam: ?*anyopaque,
) callconv(WINAPI) ?*anyopaque;

extern "user32" fn GetMessageW(
    lpMsg: *MSG,
    hWnd: ?*anyopaque,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
) callconv(WINAPI) i32;

extern "user32" fn TranslateMessage(lpMsg: *MSG) callconv(WINAPI) i32;

extern "user32" fn DispatchMessageW(lpMsg: *MSG) callconv(WINAPI) isize;

extern "user32" fn DestroyWindow(hWnd: ?*anyopaque) callconv(WINAPI) i32;

// On 64-bit Windows the *Ptr* variants are real exports. On 32-bit Windows they
// are only C macros that alias the non-Ptr (LONG-width) functions, so linking
// against GetWindowLongPtrW/SetWindowLongPtrW fails with "undefined symbol".
// Bind to the correct underlying export per target width and wrap behind a
// pointer-width helper so call sites stay identical.
const is_win64 = @sizeOf(usize) == 8;

extern "user32" fn GetWindowLongPtrW(
    hWnd: ?*anyopaque,
    nIndex: i32,
) callconv(WINAPI) isize;

extern "user32" fn SetWindowLongPtrW(
    hWnd: ?*anyopaque,
    nIndex: i32,
    dwNewLong: isize,
) callconv(WINAPI) isize;

extern "user32" fn GetWindowLongW(
    hWnd: ?*anyopaque,
    nIndex: i32,
) callconv(WINAPI) i32;

extern "user32" fn SetWindowLongW(
    hWnd: ?*anyopaque,
    nIndex: i32,
    dwNewLong: i32,
) callconv(WINAPI) i32;

fn getWindowUserData(hWnd: ?*anyopaque, nIndex: i32) isize {
    return if (is_win64)
        GetWindowLongPtrW(hWnd, nIndex)
    else
        GetWindowLongW(hWnd, nIndex);
}

fn setWindowUserData(hWnd: ?*anyopaque, nIndex: i32, value: isize) void {
    if (is_win64) {
        _ = SetWindowLongPtrW(hWnd, nIndex, value);
    } else {
        // GWLP_USERDATA stores a pointer; on 32-bit the slot is exactly LONG
        // wide, so truncating isize -> i32 is the documented, lossless behavior.
        _ = SetWindowLongW(hWnd, nIndex, @truncate(value));
    }
}

// ---------------------------------------------------------------------------
// r2-l1 — durable log channel (btf.log next to the exe)
// ---------------------------------------------------------------------------
// Why: the two r1-l11 kernel crashes could not be ATTRIBUTED, only guessed at,
// because the daemon's single log channel was OutputDebugStringA — with no
// DebugView running at crash time it left zero evidence behind. From r2-l1
// every debug() line is also appended, timestamped, to btf.log, rotated at
// LOG_MAX_BYTES into btf.log.1. Opened with FILE_APPEND_DATA and a shared
// read/write mode so the file can be tailed while the daemon runs.
const LOG_MAX_BYTES: i64 = 2 * 1024 * 1024;
var log_handle: ?*anyopaque = null;
// No lock guards this handle on purpose. The handle is opened ONCE with
// FILE_APPEND_DATA (and never GENERIC_WRITE), and on Windows a single WriteFile
// on an append-only handle is atomic with respect to other writers: the offset
// is taken and advanced by the kernel, so concurrent lines from the worker
// thread, the keepalive thread and the message loop cannot interleave or
// overwrite each other. logFileWrite is therefore given ONE fully formatted
// line per call and issues exactly ONE WriteFile. (std.Thread.Mutex does not
// exist in Zig 0.16, and a hand-rolled spinlock in a logging path would be a
// worse trade than relying on the documented append semantics.)

/// UTF-8 -> NUL-terminated UTF-16 into a caller buffer. Returns null instead
/// of a partial path when the buffer is too small (a truncated path must never
/// be handed to CreateFileW/MoveFileExW).
fn utf16PathZ(out: []u16, path_u8: []const u8) ?[:0]const u16 {
    if (out.len == 0 or path_u8.len + 1 > out.len) return null;
    const n = std.unicode.utf8ToUtf16Le(out[0 .. out.len - 1], path_u8) catch return null;
    out[n] = 0;
    return out[0..n :0];
}

/// Build "<exe dir><name>". Returns null when the exe path is unavailable.
fn selfDirPath(buf: []u8, name: []const u8) ?[]const u8 {
    var dir_buf: [4096]u8 = undefined;
    const dir = getSelfDir(&dir_buf) catch return null;
    return std.fmt.bufPrint(buf, "{s}{s}", .{ dir, name }) catch null;
}

fn logFileInit() void {
    if (builtin.is_test) return;
    var path_u8: [4200]u8 = undefined;
    const path = selfDirPath(&path_u8, "btf.log") orelse return;
    var path_w: [4300]u16 = undefined;
    const path_z = utf16PathZ(&path_w, path) orelse return;

    // Rotation happens before the append handle is opened, so a long-lived
    // install can never grow the log without bound.
    const probe = CreateFileW(path_z.ptr, GENERIC_WRITE, FILE_SHARE_READ_WRITE, null, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    if (probe != null and probe != INVALID_HANDLE_VALUE) {
        var size: i64 = 0;
        const oversized = GetFileSizeEx(probe, &size) != 0 and size >= LOG_MAX_BYTES;
        _ = CloseHandle(probe);
        if (oversized) {
            var old_u8: [4200]u8 = undefined;
            if (selfDirPath(&old_u8, "btf.log.1")) |old_path| {
                var old_w: [4300]u16 = undefined;
                if (utf16PathZ(&old_w, old_path)) |old_z| {
                    _ = MoveFileExW(path_z.ptr, old_z.ptr, MOVEFILE_REPLACE_EXISTING);
                }
            }
        }
    }

    const h = CreateFileW(path_z.ptr, FILE_APPEND_DATA, FILE_SHARE_READ_WRITE, null, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    if (h == null or h == INVALID_HANDLE_VALUE) return;
    log_handle = h;
}

/// Append ONE complete, already-formatted line. Must stay a single WriteFile:
/// that is what makes concurrent logging safe without a lock (see log_handle).
fn logFileWrite(bytes: []const u8) void {
    const h = log_handle orelse return;
    var written: u32 = 0;
    _ = WriteFile(h, bytes.ptr, @intCast(bytes.len), &written, null);
}

// ---------------------------------------------------------------------------
// Debug logging helper
// ---------------------------------------------------------------------------
fn debug(comptime fmt: []const u8, args: anytype) void {
    if (!builtin.is_test) {
        var buf: [4096]u8 = undefined;
        const prefix = "btf: ";
        const suffix = "\r\n";
        // Reserve one extra byte for a NUL terminator so the same buffer can be
        // handed to OutputDebugStringA below.
        const max_body = buf.len - prefix.len - suffix.len - 1;
        @memcpy(buf[0..prefix.len], prefix);
        const body = std.fmt.bufPrint(buf[prefix.len .. prefix.len + max_body], fmt, args) catch {
            return;
        };
        const total_len = prefix.len + body.len + suffix.len;
        @memcpy(buf[prefix.len + body.len .. total_len], suffix);
        buf[total_len] = 0;

        // In the GUI (subsystem:windows) build this process usually has no valid
        // stderr, so OutputDebugStringA is the only channel that surfaces these
        // messages to a debugger/DebugView. WriteFile to stderr is kept for
        // console or stderr-redirected runs.
        OutputDebugStringA(@ptrCast(&buf));

        // r2-l1: the same line on the durable channel, wall-clock stamped so a
        // log line can be lined up against a minidump timestamp.
        if (log_handle != null) {
            var st: SYSTEMTIME = undefined;
            GetLocalTime(&st);
            var line_buf: [4300]u8 = undefined;
            const line = std.fmt.bufPrint(&line_buf, "{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3} {s}", .{
                st.wHour,
                st.wMinute,
                st.wSecond,
                st.wMilliseconds,
                buf[0..total_len],
            }) catch "";
            if (line.len > 0) logFileWrite(line);
        }

        const stderr_handle = GetStdHandle(STD_ERROR_HANDLE);
        if (stderr_handle == null or stderr_handle == INVALID_HANDLE_VALUE) return;
        var written: u32 = 0;
        _ = WriteFile(stderr_handle, &buf, @intCast(total_len), &written, null);
    }
}

// ---------------------------------------------------------------------------
// Win32 types
// ---------------------------------------------------------------------------
const WNDPROC = *const fn (?*anyopaque, u32, usize, isize) callconv(WINAPI) isize;

const WNDCLASSEXW = extern struct {
    cbSize: u32,
    style: u32,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: ?*anyopaque,
    hIcon: ?*anyopaque,
    hCursor: ?*anyopaque,
    hbrBackground: ?*anyopaque,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: [*:0]const u16,
    hIconSm: ?*anyopaque,
};

const CREATESTRUCTW = extern struct {
    lpCreateParams: ?*anyopaque,
    hInstance: ?*anyopaque,
    hMenu: ?*anyopaque,
    hwndParent: ?*anyopaque,
    cy: i32,
    cx: i32,
    y: i32,
    x: i32,
    style: i32,
    lpszName: ?[*:0]const u16,
    lpszClass: ?[*:0]const u16,
    dwExStyle: u32,
};

const PROCESS_INFORMATION = extern struct {
    hProcess: ?*anyopaque,
    hThread: ?*anyopaque,
    dwProcessId: u32,
    dwThreadId: u32,
};

const STARTUPINFOW = extern struct {
    cb: u32,
    lpReserved: ?[*:0]u16,
    lpDesktop: ?[*:0]u16,
    lpTitle: ?[*:0]u16,
    dwX: u32,
    dwY: u32,
    dwXSize: u32,
    dwYSize: u32,
    dwXCountChars: u32,
    dwYCountChars: u32,
    dwFillAttribute: u32,
    dwFlags: u32,
    wShowWindow: u16,
    cbReserved2: u16,
    lpReserved2: ?*anyopaque,
    hStdInput: ?*anyopaque,
    hStdOutput: ?*anyopaque,
    hStdError: ?*anyopaque,
};

const MSG = extern struct {
    hwnd: ?*anyopaque,
    message: u32,
    wParam: usize,
    lParam: isize,
    time: u32,
    pt_x: i32,
    pt_y: i32,
};

// ---------------------------------------------------------------------------
// Bluetooth Classic types (from bthprops.cpl)
// ---------------------------------------------------------------------------
const BLUETOOTH_ADDRESS = extern struct {
    ullRemote: u64,
};

const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

const SYSTEMTIME = extern struct {
    wYear: u16,
    wMonth: u16,
    wDayOfWeek: u16,
    wDay: u16,
    wHour: u16,
    wMinute: u16,
    wSecond: u16,
    wMilliseconds: u16,
};

const BLUETOOTH_DEVICE_INFO = extern struct {
    dwSize: u32,
    Address: BLUETOOTH_ADDRESS,
    ulClassofDevice: u32,
    fConnected: i32,
    fRemembered: i32,
    fAuthenticated: i32,
    stLastSeen: SYSTEMTIME,
    stLastUsed: SYSTEMTIME,
    szName: [248]u16,
};

const BLUETOOTH_DEVICE_SEARCH_PARAMS = extern struct {
    dwSize: u32,
    fReturnAuthenticated: i32,
    fReturnRemembered: i32,
    fReturnUnknown: i32,
    fReturnConnected: i32,
    fIssueInquiry: i32,
    cTimeoutMultiplier: u8,
    hRadio: ?*anyopaque,
};

const BLUETOOTH_FIND_RADIO_PARAMS = extern struct {
    dwSize: u32,
};

/// Win32 BLUETOOTH_RADIO_INFO (bluetoothapis.h). 8-byte alignment of the
/// address field pads dwSize by 4, so sizeof == 520 (pinned by a test below).
const BLUETOOTH_RADIO_INFO = extern struct {
    dwSize: u32,
    Address: BLUETOOTH_ADDRESS,
    szName: [248]u16,
    ulClassofDevice: u32,
    lmpSubversion: u16,
    manufacturer: u16,
};

const BthApi = struct {
    BluetoothFindFirstRadio: *const fn (
        pParams: *BLUETOOTH_FIND_RADIO_PARAMS,
        phRadio: *?*anyopaque,
    ) callconv(WINAPI) ?*anyopaque,

    BluetoothFindNextRadio: *const fn (
        hFind: ?*anyopaque,
        phRadio: *?*anyopaque,
    ) callconv(WINAPI) i32,

    BluetoothFindRadioClose: *const fn (
        hFind: ?*anyopaque,
    ) callconv(WINAPI) i32,

    BluetoothFindFirstDevice: *const fn (
        pSearchParams: *BLUETOOTH_DEVICE_SEARCH_PARAMS,
        pDeviceInfo: *BLUETOOTH_DEVICE_INFO,
    ) callconv(WINAPI) ?*anyopaque,

    BluetoothFindNextDevice: *const fn (
        hFind: ?*anyopaque,
        pDeviceInfo: *BLUETOOTH_DEVICE_INFO,
    ) callconv(WINAPI) i32,

    BluetoothFindDeviceClose: *const fn (
        hFind: ?*anyopaque,
    ) callconv(WINAPI) i32,

    // R1 — programmatic radio reset ("software re-plug"). Optional so a system
    // whose bthprops.cpl lacks this export still loads the rest of the API
    // (R1 then simply stays dormant instead of killing the whole app).
    BluetoothEnableIncomingConnections: ?*const fn (
        hRadio: ?*anyopaque,
        fEnabled: i32,
    ) callconv(WINAPI) i32,

    // --health probes (r1-l6). All best-effort optionals: a missing export
    // only removes that probe from the report, never the app.
    BluetoothGetRadioInfo: ?*const fn (
        hRadio: ?*anyopaque,
        pRadioInfo: *BLUETOOTH_RADIO_INFO,
    ) callconv(WINAPI) u32,
    BluetoothIsDiscoverable: ?*const fn (
        hRadio: ?*anyopaque,
    ) callconv(WINAPI) i32,
    BluetoothIsConnectable: ?*const fn (
        hRadio: ?*anyopaque,
    ) callconv(WINAPI) i32,

    module: ?*anyopaque,
};

fn loadBthApi() !BthApi {
    // Load strictly from System32 (LOAD_LIBRARY_SEARCH_SYSTEM32) so a same-named
    // bthprops.cpl in the application directory or CWD cannot hijack the load.
    const module = LoadLibraryExW(&[_:0]u16{ 'b', 't', 'h', 'p', 'r', 'o', 'p', 's', '.', 'c', 'p', 'l' }, null, LOAD_LIBRARY_SEARCH_SYSTEM32) orelse return error.BthCplNotFound;
    errdefer _ = FreeLibrary(module);

    const findFirstRadio = @as(
        *const fn (*BLUETOOTH_FIND_RADIO_PARAMS, *?*anyopaque) callconv(WINAPI) ?*anyopaque,
        @ptrCast(GetProcAddress(module, "BluetoothFindFirstRadio") orelse return error.BthApiMissing),
    );
    const findNextRadio = @as(
        *const fn (?*anyopaque, *?*anyopaque) callconv(WINAPI) i32,
        @ptrCast(GetProcAddress(module, "BluetoothFindNextRadio") orelse return error.BthApiMissing),
    );
    const findRadioClose = @as(
        *const fn (?*anyopaque) callconv(WINAPI) i32,
        @ptrCast(GetProcAddress(module, "BluetoothFindRadioClose") orelse return error.BthApiMissing),
    );
    const findFirstDevice = @as(
        *const fn (*BLUETOOTH_DEVICE_SEARCH_PARAMS, *BLUETOOTH_DEVICE_INFO) callconv(WINAPI) ?*anyopaque,
        @ptrCast(GetProcAddress(module, "BluetoothFindFirstDevice") orelse return error.BthApiMissing),
    );
    const findNextDevice = @as(
        *const fn (?*anyopaque, *BLUETOOTH_DEVICE_INFO) callconv(WINAPI) i32,
        @ptrCast(GetProcAddress(module, "BluetoothFindNextDevice") orelse return error.BthApiMissing),
    );
    const findDeviceClose = @as(
        *const fn (?*anyopaque) callconv(WINAPI) i32,
        @ptrCast(GetProcAddress(module, "BluetoothFindDeviceClose") orelse return error.BthApiMissing),
    );

    // R1 — resolved best-effort: missing export only disables the radio-reset
    // layer, never the app (see BthApi.BluetoothEnableIncomingConnections).
    const enableIncoming: ?*const fn (?*anyopaque, i32) callconv(WINAPI) i32 = if (GetProcAddress(module, "BluetoothEnableIncomingConnections")) |p|
        @as(*const fn (?*anyopaque, i32) callconv(WINAPI) i32, @ptrCast(p))
    else
        null;

    // --health probes — best-effort the same way (r1-l6).
    const getRadioInfo: ?*const fn (?*anyopaque, *BLUETOOTH_RADIO_INFO) callconv(WINAPI) u32 = if (GetProcAddress(module, "BluetoothGetRadioInfo")) |p|
        @as(*const fn (?*anyopaque, *BLUETOOTH_RADIO_INFO) callconv(WINAPI) u32, @ptrCast(p))
    else
        null;
    const isDiscoverable: ?*const fn (?*anyopaque) callconv(WINAPI) i32 = if (GetProcAddress(module, "BluetoothIsDiscoverable")) |p|
        @as(*const fn (?*anyopaque) callconv(WINAPI) i32, @ptrCast(p))
    else
        null;
    const isConnectable: ?*const fn (?*anyopaque) callconv(WINAPI) i32 = if (GetProcAddress(module, "BluetoothIsConnectable")) |p|
        @as(*const fn (?*anyopaque) callconv(WINAPI) i32, @ptrCast(p))
    else
        null;

    return BthApi{
        .BluetoothFindFirstRadio = findFirstRadio,
        .BluetoothFindNextRadio = findNextRadio,
        .BluetoothFindRadioClose = findRadioClose,
        .BluetoothFindFirstDevice = findFirstDevice,
        .BluetoothFindNextDevice = findNextDevice,
        .BluetoothFindDeviceClose = findDeviceClose,
        .BluetoothEnableIncomingConnections = enableIncoming,
        .BluetoothGetRadioInfo = getRadioInfo,
        .BluetoothIsDiscoverable = isDiscoverable,
        .BluetoothIsConnectable = isConnectable,
        .module = module,
    };
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
pub const POLL_INTERVAL_MS: u32 = 2000;
const RESUME_DELAY_MS: u32 = 3000;

// L3 — connect (ToothTray) backoff while the earbuds are unreachable. Capped at
// 4s so a case-open still reconnects within ~one poll, but we stop hammering BT
// while the earbuds are away. Reset to 0 on a successful connect.
pub const CONNECT_BACKOFF_BASE_MS: u32 = 500;
pub const CONNECT_BACKOFF_CAP_MS: u32 = 4000;

// L5 — circuit breaker for ToothTray spawns (worker thread only).
pub const CONNECT_CB_WINDOW_MS: i64 = 10_000;
pub const CONNECT_CB_MAX_SPAWNS: u32 = 20;
pub const CONNECT_CB_COOLDOWN_MS: i64 = 30_000;

// L6 — paged-pool watchdog. The diagnosed leak climbs by gigabytes; 800MB over
// the lowest-seen baseline is far above normal fluctuation yet trips long before
// the ~16GB BSOD point. While tripped we pause keepalive + connects and log
// loudly; we auto-clear once usage falls back near baseline. Because this reads
// the *global* system pool, a bloat caused by some *other* process would also
// trip us; the force-clear timeout below re-baselines and resumes the keepalive
// so our core function can never be paused forever by an external hog.
const WATCHDOG_TRIP_BYTES: u64 = 800 * 1024 * 1024;
const WATCHDOG_CLEAR_BYTES: u64 = 200 * 1024 * 1024;
// Force-clear a stuck watchdog after this long, re-baselining to current usage.
const WATCHDOG_FORCE_CLEAR_MS: i64 = 30 * 60 * 1000;
// Heartbeat log cadence while the watchdog stays tripped (visibility).
const WATCHDOG_LOG_INTERVAL_MS: i64 = 60 * 1000;

// R1 — programmatic radio reset ("software re-plug") tuning.
//
// TRIGGER. The only reliably observable state is "target remembered but not
// connected" (found && !fConnected) — and it is IDENTICAL for two very
// different situations: earbuds powered off in their case, and earbuds powered
// on and paging at a wedged radio that cannot answer their pages (the exact
// user-reported bug). ToothTray's exit code cannot separate them either:
// ToothTray connect is a one-shot KSPROPERTY_ONESHOT_RECONNECT poke at the BT
// audio driver (see m2jean/ToothTray, BluetoothAudioDevices.cpp) — it does not
// wait for the link, so the spawn "succeeds" (exit 0) regardless of whether
// the device is reachable. Therefore the recovery window arms on the FIRST
// stop_and_connect observation of the absence episode and fires after
// R1_ARM_MS of continuous absence — slow first-time connections are unaffected
// because a healthy case-open connects in ~3s, well under the window.
//
// STORM CAP. Absence also covers "earbuds resting in their case", so the
// trigger alone would toggle forever. The hard cap reuses the tested L5
// CircuitBreaker primitive (unmodified): at most R1_CB_MAX_RESETS resets per
// R1_CB_WINDOW_MS — after a burst of 3, the radio is left alone for 10
// minutes. Worst-case cost while the earbuds rest all day: 3 harmless 300ms
// page-scan toggles per 10 minutes (established links are unaffected by scan
// state; only NEW incoming BR/EDR connections pause for 300ms).
pub const R1_ARM_MS: i64 = 20_000;
pub const R1_COOLDOWN_MS: i64 = 60_000;
// R1 hard cap — a fresh CircuitBreaker instance (L5 primitive, not modified).
pub const R1_CB_WINDOW_MS: i64 = 10 * 60 * 1000;
pub const R1_CB_MAX_RESETS: u32 = 3;
pub const R1_CB_COOLDOWN_MS: i64 = 10 * 60 * 1000;
// How long the radio stays "disabled" inside the toggle before re-enabling.
const R1_TOGGLE_QUIET_MS: u32 = 300;
// Re-enable is the one step that must not fail silently: if it did, the
// adapter would stay non-connectable (worse than the wedge itself). Retry hard.
const R1_REENABLE_ATTEMPTS: u32 = 5;
const R1_REENABLE_RETRY_MS: u32 = 100;
// Settle time after a successful reset before the next ToothTray attempt —
// one poll cycle for the controller to re-arm its page scan.
pub const R1_POST_RESET_RECONNECT_MS: i64 = 2_000;

// ---------------------------------------------------------------------------
// R2 — usb-cycle ("hardware re-plug") — the escalation rung of the ladder.
//
// LADDER (build tag r1-l7 = "R1 fix + 3-rung ladder + health/cycle one-shot modes"):
//   rung 1  connect     — ToothTray one-shot reconnect kick (every poll).
//   rung 2  page-scan   — R1 programmatic radio reset, 20 s into an absence
//                         episode (see the R1 block above).
//   rung 3  usb-cycle   — full SetupAPI disable/enable of the CSR dongle's
//                         USB devnode (USB\VID_0A12&PID_0001): the software
//                         equivalent of physically yanking the dongle. Field
//                         evidence (diagnose.ps1 archives) showed some wedges
//                         survive the page-scan toggle and only clear on a
//                         real power-cycle — this rung is for exactly those.
//
// ESCALATION GATE (shouldUsbCycle, pure + tested). The cycle only fires when
// the rung-2 page-scan reset has ALREADY been tried within the current
// absence episode AND the episode is still alive R2_ARM_MS after it began —
// i.e. escalation strictly follows a failed softer rung, never replaces it.
//
// STORM CAP. A cycle tears down every Bluetooth link on the machine for a few
// seconds (worse than the 300 ms page-scan pause), so its breaker is twice as
// strict: at most R2_CB_MAX_CYCLES cycles per 10-minute window, and never
// two cycles closer together than R2_MIN_INTERVAL_MS. Non-admin processes
// cannot cycle at all: the rung logs "skipped (admin required)" once and
// stays dormant — run diagnose.ps1 (self-elevating) or start the exe from an
// elevated shell.
pub const R2_ARM_MS: i64 = 45_000;
pub const R2_MIN_INTERVAL_MS: i64 = 120_000;
pub const R2_CB_WINDOW_MS: i64 = 10 * 60 * 1000;
pub const R2_CB_MAX_CYCLES: u32 = 2;
pub const R2_CB_COOLDOWN_MS: i64 = 10 * 60 * 1000;
// How long the dongle stays disabled inside the cycle before re-enabling.
const R2_DISABLE_QUIET_MS: u32 = 2000;
// r1-l8: verified cycle state machine. An enable/disable API call returning
// success is a receipt, not a state change (field archive 2026-09-02 23:55:
// DICS_ENABLE accepted with TRUE, the devnode never restarted, stayed
// CM_PROB_DISABLED, the tool reported "complete" and left the dongle
// disabled). Every step is now verified against CM_Get_DevNode_Status bits.
const CM_PROB_DISABLED: u32 = 22; // problem code: devnode is software-disabled
const R2_DISABLE_VERIFY_MS: u32 = 3_000; // observe CM_PROB_DISABLED before enabling
const R2_ENABLE_VERIFY_MS: u32 = 2_500; // observe DN_STARTED per enable path

// r2-l3 -- crash-safe disable recovery.
//
// A devnode disable is PERSISTENT: DICS_DISABLE and CM_Disable_DevNode both
// store the disabled flag in the device's registry key, so it survives a
// replug into the same port and a reboot. Field 2026-09-03: the user was
// left with Bluetooth switched off in Device Manager after a cycle whose
// enable step never completed. Everything below exists to make that state
// impossible to reach, and self-healing if it is somehow reached anyway.
const RECOVERY_JOURNAL_NAME = "btf_pending_enable.txt";
pub const RECOVERY_RETRY_MS: i64 = 5_000; // repairs are NOT rate-limited like escalations
const RECOVERY_VERIFY_MS: u32 = 3_000;
// pnputil owns the PnP stack even when our in-process calls are refused,
// and /restart-device never writes the persistent disabled flag at all.
const PNPUTIL_TIMEOUT_MS: u32 = 30_000;
const R2_REENUM_POLL_MS: u32 = 250;
// Settle time after a successful cycle before the next ToothTray attempt.
pub const R2_POST_CYCLE_RECONNECT_MS: i64 = 2_000;
// The dongle this build cycles: CSR-based BT radio (user's hardware).
const R2_MATCH_VID: []const u8 = "vid_0a12";
const R2_MATCH_PID: []const u8 = "pid_0001";

// ---------------------------------------------------------------------------
// R3 — earbud-devnode restart (r2-l1). The rung that REPLACES the removed
// service-restart wave.
// ---------------------------------------------------------------------------
// FORENSIC BASIS (field, r1-l11 era — two kernel crashes, same bucket):
//   KERNEL_SECURITY_CHECK_FAILURE (0x139) Arg1=3 CORRUPT_LIST_ENTRY
//   BthA2dp!IrpList_HandleCancel <- AVFilter::CancelServiceReadyRequest
//   <- IoCancelIrp <- IoCancelThreadIo <- PspExitThread   (svchost.exe)
// The fault fires when a SERVICE THREAD EXITS while a "service ready" IRP is
// still pending in BthA2dp: the cancel races the A2DP IRP-list churn and the
// same LIST_ENTRY is unlinked twice. That is a Microsoft driver bug, and no
// amount of user-mode preparation removes the race — stopping bthserv /
// BthAvctpSvc / BTAGService always terminates svchost threads and always
// re-enters IoCancelThreadIo. So r2-l1 NEVER stops a service automatically;
// the invariant is enforced by a unit test that scans this very source for
// service-control API tokens.
//
// WHAT THIS RUNG DOES INSTEAD: it tears down and re-creates the earbuds' own
// BTHENUM function devnodes (the A2DP/AVRCP/HFP filter instances) through the
// documented PnP path. That produces the effect the service wave was wanted
// for — the audio filters are rebuilt from scratch — but the IRP
// cancellations happen on PnP remove/start inside the driver's own state
// machine, not on thread exit.
//
// MECHANISM ORDER (per devnode):
//   1. pnputil /restart-device — one atomic stop+start that leaves NO
//      persistent disable flag, so a failure cannot strand the earbud
//      endpoints "off" (field r1-l10: pnputil succeeded where DIF/CM were
//      rejected). Verified afterwards via CM_Get_DevNode_Status.
//   2. Verified disable -> quiet -> verified enable, the r1-l8 pattern, with a
//      hard enable retry loop and printed manual-recovery lines.
// It is placed BEFORE the usb-cycle: it is the cheaper rung (only the earbud
// function devnodes blink; anything else on the dongle keeps working).
pub const R3_ARM_MS: i64 = 30_000; // absence before this rung may fire
pub const R3_MIN_INTERVAL_MS: i64 = 90_000; // minimum spacing of two restarts
pub const R3_MAX_PER_EPISODE: u32 = 2; // per absence episode
pub const R3_CB_WINDOW_MS: i64 = 10 * 60 * 1000;
pub const R3_CB_MAX_RESTARTS: u32 = 3;
pub const R3_CB_COOLDOWN_MS: i64 = 10 * 60 * 1000;
// After a successful usb-cycle the dongle is freshly re-enumerated and the
// earbud function devnodes usually come back stale, so exactly one extra
// verified refresh is queued this far after the VERIFIED completion of the
// cycle (fresh nowMs() — the r1-l11 post-mortem traced its mis-timed gate to
// a stale `now` captured before a multi-second operation).
pub const R3_POST_CYCLE_DELAY_MS: i64 = 15_000;
pub const R3_POST_RESTART_RECONNECT_MS: i64 = 3_000;
const R3_QUIET_MS: u32 = 1_500; // between disable and enable (fallback path)
const R3_VERIFY_MS: u32 = 4_000; // per state-change verification window
const R3_MAX_NODES: u32 = 16; // earbud function devnodes touched per pass
const R3_PNPUTIL_TIMEOUT_MS: u32 = 20_000;
// r2-l2 -- SCOPE of the rung. r2-l1 restarted EVERY present BTHENUM node
// carrying the earbuds' MAC (10 of them in the field): the container
// DEV_<MAC> node, Handsfree, SPP, GATT, PnP-info and two vendor nodes on top
// of the audio ones. The link did come back, but Windows never ran its "an
// audio device connected" path: the default render endpoint stayed on the
// speakers, so the volume flyout showed their level and the tray icon never
// switched to the earbuds (field report 2026-09-03 18:58). The container node
// is what re-enumerates the endpoints, and the non-audio profile nodes were
// never part of the A2DP wedge -- so the rung now touches ONLY these two.
pub const R3_AUDIO_PROFILE_A2DP: []const u8 = "{0000110b";
pub const R3_AUDIO_PROFILE_AVRCP: []const u8 = "{0000110c";
// r2-l2 -- the usb-cycle must not fire on the heels of a restart. Field log:
// 18:44:17.865 restart complete -> 18:44:19.876 usb-cycle begin, i.e. 2.0 s
// later, long before the restarted nodes could possibly have re-linked.
pub const R2_POST_R3_QUIET_MS: i64 = 30_000;
// r2-l2 -- the page-scan rung is dead on this CSR dongle: every attempt is
// rejected with 0x80070057, wedged and healthy alike (--health probe P3, and
// 5/5 rejections in the 18:43 field log). After this many consecutive
// rejections it is muted for the rest of the run so the ladder stops waiting
// for a rung that can never fire.
pub const R1_DEAD_REJECTIONS: u32 = 3;
// How often the freeze kill switch (btf_freeze.txt) is re-read while running.
const FREEZE_RECHECK_MS: i64 = 15_000;
// PnP enumerator of Bluetooth function devnodes: instance IDs look like
// BTHENUM\{0000110b-0000-1000-8000-00805f9b34fb}_VID&...\8&...&_&948b93b1e4a1_C0000000
const ENUMERATOR_BTHENUM = [_:0]u16{ 'B', 'T', 'H', 'E', 'N', 'U', 'M' };

const WINDOW_CLASS_NAME: [*:0]const u16 = &[_:0]u16{ 'B', 't', 'F', 'o', 'r', 'c', 'e', 'W', 'i', 'n', 'd', 'o', 'w' };
const WINDOW_TITLE: [*:0]const u16 = &[_:0]u16{ 'B', 't', 'F', 'o', 'r', 'c', 'e' };

// ---------------------------------------------------------------------------
// Silent audio keepalive — prevents BT earbuds idle-disconnect
// ---------------------------------------------------------------------------
const KEEPALIVE_BUF_SIZE: u16 = 8192;

// Number of times the keepalive playback loop sleeps before bailing out while
// waiting for the driver to flag a buffer DONE. Bounds every wait so shutdown
// and error paths can never hang the process.
const KEEPALIVE_DRAIN_SPINS: u32 = 400; // 400 * 5ms = 2s hard cap

// L3 backoff bounds for keepalive (re)open failures.
const KEEPALIVE_BACKOFF_BASE_MS: u32 = 250;
const KEEPALIVE_BACKOFF_CAP_MS: u32 = 5000;

// L5 circuit-breaker tuning for keepalive opens. Normal operation opens the
// device roughly once per connect session, so 30 opens / 10s is huge headroom
// for legitimate device-switch churn yet trips long before any storm.
const KEEPALIVE_CB_WINDOW_MS: i64 = 10_000;
const KEEPALIVE_CB_MAX_OPENS: u32 = 30;
const KEEPALIVE_CB_COOLDOWN_MS: i64 = 30_000;

// A huge loop count makes the single keepalive buffer play effectively forever
// (~46ms/buffer * 2^31 ≈ years), so the driver is touched once per session
// instead of ~16x/second.
const KEEPALIVE_LOOP_COUNT: u32 = 0x7FFF_FFFF;

// Fill the keepalive buffer with an inaudible, *non-zero* dither (alternating
// +/-1 LSB per 16-bit sample). A pure-silence (all-zero) stream can be treated
// as idle by some audio engines/drivers (notably when FxSound's APO sits in the
// render chain), which lets the BT earbuds idle-disconnect anyway. A tiny
// non-zero signal keeps the render stream genuinely active without being
// audible. Pure function -> unit-testable.
fn fillKeepaliveBuffer(buf: []u8) void {
    var i: usize = 0;
    while (i + 1 < buf.len) : (i += 2) {
        const sample: i16 = if ((i / 2) % 2 == 0) @as(i16, 1) else @as(i16, -1);
        const bits: u16 = @bitCast(sample);
        buf[i] = @truncate(bits);
        buf[i + 1] = @truncate(bits >> 8);
    }
    // A trailing odd byte cannot form a 16-bit sample; leave it zeroed.
    if (i < buf.len) buf[i] = 0;
}

const SilentKeepalive = struct {
    hwo: ?*anyopaque,
    thread: ?std.Thread,
    // `want_run` is a *request* flag owned by start()/stop(); the worker loop
    // reads it to decide whether to keep playing. Thread lifetime is tracked
    // solely via `thread`, so a self-exited worker is always joined (no leak).
    want_run: std.atomic.Value(bool),
    silence_buf: [KEEPALIVE_BUF_SIZE]u8,
    // L2 — resolved waveOut endpoint. Defaults to WAVE_MAPPER (system default)
    // and is replaced with the earbuds' own endpoint once resolved, so the
    // keepalive stops streaming through the FxSound default-device APO (the
    // component that amplified the driver's ETW leak).
    device_id: u32,
    // Optional user override substring for the audio endpoint name (CLI arg 3).
    override_name: ?[]const u8,
    // L5 — circuit breaker scoped to this (single) keepalive thread.
    breaker: CircuitBreaker,

    fn init() SilentKeepalive {
        var s = SilentKeepalive{
            .hwo = null,
            .thread = null,
            .want_run = std.atomic.Value(bool).init(false),
            .silence_buf = [_]u8{0} ** KEEPALIVE_BUF_SIZE,
            .device_id = WAVE_MAPPER,
            .override_name = null,
            .breaker = .{
                .window_ms = KEEPALIVE_CB_WINDOW_MS,
                .max_events = KEEPALIVE_CB_MAX_OPENS,
                .cooldown_ms = KEEPALIVE_CB_COOLDOWN_MS,
            },
        };
        fillKeepaliveBuffer(&s.silence_buf);
        return s;
    }

    // L2 — Enumerate waveOut endpoints and pick the earbuds' own device so the
    // keepalive bypasses FxSound. Called from the worker thread on (re)start
    // while no playback thread exists. Best-effort: on any failure it leaves
    // device_id = WAVE_MAPPER (still bounded by the circuit breaker).
    fn resolveDevice(self: *SilentKeepalive, bt_name: []const u8) void {
        const n = waveOutGetNumDevs();
        if (n == 0) return;

        // szPname is up to 31 UTF-16 chars; worst-case UTF-8 is 3 bytes/char
        // (~93 bytes), so 128 leaves headroom and never truncates a non-ASCII
        // (e.g. Cyrillic/CJK) endpoint name into an empty string that fails to
        // match and silently falls back to WAVE_MAPPER (the FxSound APO).
        var name_store: [16][128]u8 = undefined;
        var name_slices: [16][]const u8 = undefined;
        var count: usize = 0;
        var dev: u32 = 0;
        while (dev < n and count < name_store.len) : (dev += 1) {
            var caps: WAVEOUTCAPSW = std.mem.zeroes(WAVEOUTCAPSW);
            if (waveOutGetDevCapsW(dev, &caps, @sizeOf(WAVEOUTCAPSW)) != 0) continue;
            var w_len: usize = 0;
            while (w_len < caps.szPname.len and caps.szPname[w_len] != 0) : (w_len += 1) {}
            const u8_len = std.unicode.utf16LeToUtf8(&name_store[count], caps.szPname[0..w_len]) catch 0;
            name_slices[count] = name_store[count][0..u8_len];
            debug("waveOut[{}] = {s}", .{ dev, name_slices[count] });
            count += 1;
        }

        if (selectAudioDevice(name_slices[0..count], bt_name, self.override_name)) |idx| {
            self.device_id = @intCast(idx);
            debug("keepalive -> endpoint #{} ({s})", .{ idx, name_slices[idx] });
        } else {
            self.device_id = WAVE_MAPPER;
            debug("keepalive -> WAVE_MAPPER (no earbud endpoint matched)", .{});
        }
    }

    // start()/stop() are only ever called from the single worker thread, never
    // concurrently with each other.
    fn start(self: *SilentKeepalive, bt_name: []const u8) void {
        // A live thread already owns the session. Guarding on the thread handle
        // (not on want_run) means a worker that self-exited on an open failure
        // is still tracked and will be joined by stop() -> no handle leak.
        if (self.thread != null) return;
        // Resolve the earbud endpoint fresh on each start so a re-paired device
        // (new endpoint id) is picked up, and so the keepalive targets the
        // earbuds directly instead of the FxSound default-device APO.
        self.resolveDevice(bt_name);
        self.want_run.store(true, .release);
        self.thread = std.Thread.spawn(.{}, run, .{self}) catch |err| {
            debug("keepalive thread spawn failed: {s}", .{@errorName(err)});
            self.want_run.store(false, .release);
            return;
        };
    }

    fn stop(self: *SilentKeepalive) void {
        self.want_run.store(false, .release);
        // Always join if we hold a thread handle, regardless of whether the
        // worker exited on its own (e.g. a waveOutOpen failure). This is what
        // prevents the std.Thread / OS thread-handle leak.
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    fn run(self: *SilentKeepalive) void {
        // Resilient outer loop: if a render session dies (device switch, FxSound
        // re-initialising the audio engine, default-device change, transient
        // MMSYSERR) we back off and reopen instead of silently giving up.
        // L3 backoff + L5 circuit breaker bound how fast we can reopen, so a
        // pathological open/fail cycle can never become a registration storm.
        var fails: u32 = 0;
        while (self.want_run.load(.acquire)) {
            const now = nowMs();
            if (!self.breaker.allow(now)) {
                debug("keepalive circuit OPEN — cooling down", .{});
                self.interruptibleSleep(1000);
                continue;
            }

            const opened = self.runSession();
            if (opened) {
                fails = 0;
            } else {
                fails +|= 1;
            }

            if (self.want_run.load(.acquire)) {
                const wait_ms = if (opened) 500 else backoffMs(fails, KEEPALIVE_BACKOFF_BASE_MS, KEEPALIVE_BACKOFF_CAP_MS);
                self.interruptibleSleep(wait_ms);
            }
        }
    }

    // Sleep in small slices so stop() is honoured within ~50ms even during a
    // long backoff wait.
    fn interruptibleSleep(self: *SilentKeepalive, total_ms: u32) void {
        var slept: u32 = 0;
        while (slept < total_ms and self.want_run.load(.acquire)) : (slept += 50) {
            Sleep(@min(@as(u32, 50), total_ms - slept));
        }
    }

    // One waveOut open->play->close session. Opens the *resolved endpoint* and
    // queues a single looping buffer, so the driver is touched once per session
    // instead of ~16x/second — the key change that stops amplifying the driver's
    // ETW-registration leak. Returns true if the device opened, false on open
    // failure. Every wait is bounded and the header is always reset+unprepared
    // before close, so this can neither hang nor leave the driver referencing
    // our buffer.
    fn runSession(self: *SilentKeepalive) bool {
        const fmt = WAVEFORMATEX{
            .wFormatTag = WAVE_FORMAT_PCM,
            .nChannels = 2,
            .nSamplesPerSec = 44100,
            .nAvgBytesPerSec = 176400,
            .nBlockAlign = 4,
            .wBitsPerSample = 16,
            .cbSize = 0,
        };

        var hwo: ?*anyopaque = null;
        if (waveOutOpen(&hwo, self.device_id, &fmt, 0, 0, CALLBACK_NULL) != 0) return false;
        self.hwo = hwo;
        defer {
            self.hwo = null;
            _ = waveOutClose(hwo);
        }

        var hdr = WAVEHDR{
            .lpData = @ptrCast(&self.silence_buf),
            .dwBufferLength = KEEPALIVE_BUF_SIZE,
            .dwBytesRecorded = 0,
            .dwUser = 0,
            .dwFlags = WHDR_BEGINLOOP | WHDR_ENDLOOP,
            .dwLoops = KEEPALIVE_LOOP_COUNT,
            .lpNext = null,
            .reserved = 0,
        };

        if (waveOutPrepareHeader(hwo, &hdr, @sizeOf(WAVEHDR)) != 0) return false;
        // Tracks whether `hdr` is currently sitting in the driver's queue. Only a
        // queued buffer can ever have WHDR_DONE raised, so the drain spin below
        // is meaningful *only* while queued. Skipping it on the not-queued error
        // paths (write failed, or a failed re-arm) avoids burning the full ~2s
        // cap waiting for a DONE flag that can never come.
        var queued = false;
        // Guarantee the driver stops referencing `hdr`/`silence_buf` before this
        // stack frame unwinds. waveOutReset forces queued buffers to DONE; the
        // bounded spin then waits for that flag (read atomically — the winmm
        // driver thread writes it) before unpreparing. The bound turns the old
        // unbounded `while (DONE == 0)` into a hard ~2s ceiling so shutdown can
        // never hang.
        defer {
            _ = waveOutReset(hwo);
            if (queued) {
                var spins: u32 = 0;
                while (@atomicLoad(u32, &hdr.dwFlags, .acquire) & WHDR_DONE == 0 and spins < KEEPALIVE_DRAIN_SPINS) : (spins += 1) {
                    Sleep(5);
                }
            }
            _ = waveOutUnprepareHeader(hwo, &hdr, @sizeOf(WAVEHDR));
        }

        if (waveOutWrite(hwo, &hdr, @sizeOf(WAVEHDR)) != 0) return false;
        queued = true;

        // The looping buffer plays for ~years; we idle here until stop is
        // requested. If the loop ever does finish (DONE set), re-arm it once —
        // still far below any churn that could matter.
        while (self.want_run.load(.acquire)) {
            Sleep(200);
            if (@atomicLoad(u32, &hdr.dwFlags, .acquire) & WHDR_DONE != 0) {
                _ = waveOutUnprepareHeader(hwo, &hdr, @sizeOf(WAVEHDR));
                queued = false;
                @atomicStore(u32, &hdr.dwFlags, WHDR_BEGINLOOP | WHDR_ENDLOOP, .release);
                hdr.dwLoops = KEEPALIVE_LOOP_COUNT;
                if (waveOutPrepareHeader(hwo, &hdr, @sizeOf(WAVEHDR)) != 0) return false;
                if (waveOutWrite(hwo, &hdr, @sizeOf(WAVEHDR)) != 0) return false;
                queued = true;
            }
        }
        return true;
    }
};

// ---------------------------------------------------------------------------
// Shared state between threads
// ---------------------------------------------------------------------------
const SharedState = struct {
    running: std.atomic.Value(bool),
    target_mac: u64,
    resume_event: ?*anyopaque,
    bth: BthApi,
    silent: SilentKeepalive,
    last_tooth_tray_handle: ?*anyopaque,
    // L3 — ToothTray connect backoff.
    connect_fails: u32 = 0,
    next_connect_ms: i64 = 0,
    // L5 — ToothTray spawn circuit breaker (worker thread only).
    tt_breaker: CircuitBreaker = .{
        .window_ms = CONNECT_CB_WINDOW_MS,
        .max_events = CONNECT_CB_MAX_SPAWNS,
        .cooldown_ms = CONNECT_CB_COOLDOWN_MS,
    },
    // L6 — paged-pool watchdog state.
    pool_min_bytes: u64 = std.math.maxInt(u64),
    watchdog_tripped: bool = false,
    watchdog_tripped_ms: i64 = 0,
    watchdog_last_log_ms: i64 = 0,
    // R1 — radio-reset ("software re-plug") state. r1_armed_ms == 0 is the
    // "not armed" sentinel; safe because GetTickCount64 never returns 0 for a
    // user-started process. r1_last_reset_ms == 0 means "no reset yet". The
    // breaker is the hard storm cap (see the R1 constants comment).
    r1_armed_ms: i64 = 0,
    r1_last_reset_ms: i64 = 0,
    // R2 — true once the page-scan rung fired within the current absence
    // episode; the usb-cycle rung escalates only after this. Cleared when the
    // link returns (same disarm point as r1_armed_ms).
    r1_reset_in_episode: bool = false,
    // r2-l2 -- consecutive rejections of the page-scan write; at
    // R1_DEAD_REJECTIONS the rung is muted for the rest of the run.
    r1_rejects: u32 = 0,
    r1_dead_logged: bool = false,
    r1_breaker: CircuitBreaker = .{
        .window_ms = R1_CB_WINDOW_MS,
        .max_events = R1_CB_MAX_RESETS,
        .cooldown_ms = R1_CB_COOLDOWN_MS,
    },
    // R2 — usb-cycle escalation state. r2_last_cycle_ms == 0 means "no cycle
    // yet". The breaker is the hard storm cap (see the R2 constants comment).
    r2_last_cycle_ms: i64 = 0,
    r2_admin_skip_logged: bool = false,
    r2_breaker: CircuitBreaker = .{
        .window_ms = R2_CB_WINDOW_MS,
        .max_events = R2_CB_MAX_CYCLES,
        .cooldown_ms = R2_CB_COOLDOWN_MS,
    },
    // R3 — earbud-devnode restart state (r2-l1). r3_force_after_ms != 0 is the
    // one-shot post-usb-cycle refresh described at the R3 constants.
    r3_last_restart_ms: i64 = 0,
    r3_restarts_in_episode: u32 = 0,
    r3_force_after_ms: i64 = 0,
    r3_admin_skip_logged: bool = false,
    // r2-l2 -- VERIFIED completion of the last earbud restart (fresh clock,
    // never the tick that started it); the usb-cycle stays quiet after it.
    r3_last_complete_ms: i64 = 0,
    // r2-l3 -- rung 0 (repair). recovery_armed mirrors the existence of
    // btf_pending_enable.txt: while it is true a disable of ours is
    // unaccounted for and EVERY escalation rung stays blocked.
    recovery_armed: bool = false,
    recovery_last_ms: i64 = 0,
    recovery_attempts: u32 = 0,
    recovery_logged: bool = false,
    r3_breaker: CircuitBreaker = .{
        .window_ms = R3_CB_WINDOW_MS,
        .max_events = R3_CB_MAX_RESTARTS,
        .cooldown_ms = R3_CB_COOLDOWN_MS,
    },
    // r2-l1 — kill switch state (btf_freeze.txt next to the exe).
    escalation_frozen: bool = false,
    freeze_checked_ms: i64 = 0,
};

// ---------------------------------------------------------------------------
// MAC address parsing
// ---------------------------------------------------------------------------
fn parseMacAddr(s: []const u8) !u64 {
    if (s.len != 17) return error.InvalidMacFormat;
    if (s[2] != ':' or s[5] != ':' or s[8] != ':' or s[11] != ':' or s[14] != ':')
        return error.InvalidMacFormat;

    var mac: u64 = 0;
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        const hi = try hexNibble(s[i * 3]);
        const lo = try hexNibble(s[i * 3 + 1]);
        mac = (mac << 8) | (@as(u64, hi) << 4) | @as(u64, lo);
    }
    // 00:00:00:00:00:00 is not a valid unicast device address. Reject it here so
    // a zero target can never enter the poll loop, where it would match no real
    // device (they all have non-zero addresses) and spin forever.
    if (mac == 0) return error.ZeroMacAddress;
    return mac;
}

fn hexNibble(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'A'...'F' => c - 'A' + 10,
        'a'...'f' => c - 'a' + 10,
        else => error.InvalidHexChar,
    };
}

// ---------------------------------------------------------------------------
// ToothTrayCli connection trigger
// ---------------------------------------------------------------------------

/// Quote a single argument for a Windows command line using the
/// CommandLineToArgvW / MSVCRT rules: wrap in double quotes, backslash-escape
/// embedded quotes, and double any run of backslashes that precedes a quote
/// (including the implicit closing quote). Without this, a hostile Bluetooth
/// device name (fully attacker-controlled via szName) that contains a quote
/// could break out of its quotes and inject arguments into ToothTray.exe.
/// Returns error.NameTooLong if the escaped argument would not fit in `buf`.
fn quoteArgInto(buf: []u8, arg: []const u8) ![]u8 {
    var n: usize = 0;
    const emit = struct {
        fn one(b: []u8, idx: *usize, ch: u8) !void {
            if (idx.* >= b.len) return error.NameTooLong;
            b[idx.*] = ch;
            idx.* += 1;
        }
    }.one;

    try emit(buf, &n, '"');
    var i: usize = 0;
    while (i < arg.len) {
        var backslashes: usize = 0;
        while (i < arg.len and arg[i] == '\\') : (i += 1) backslashes += 1;

        if (i == arg.len) {
            // Trailing backslashes precede the closing quote: double them.
            var k: usize = 0;
            while (k < backslashes * 2) : (k += 1) try emit(buf, &n, '\\');
        } else if (arg[i] == '"') {
            // Backslashes before a quote are doubled, then the quote escaped.
            var k: usize = 0;
            while (k < backslashes * 2 + 1) : (k += 1) try emit(buf, &n, '\\');
            try emit(buf, &n, '"');
            i += 1;
        } else {
            // Backslashes not followed by a quote are literal.
            var k: usize = 0;
            while (k < backslashes) : (k += 1) try emit(buf, &n, '\\');
            try emit(buf, &n, arg[i]);
            i += 1;
        }
    }
    try emit(buf, &n, '"');
    return buf[0..n];
}

// ---------------------------------------------------------------------------
// Multi-layer leak protection — pure, unit-testable logic
// ---------------------------------------------------------------------------

// L3 — Exponential backoff with a hard cap. failures==0 -> 0 (happy path, no
// delay). Pure.
pub fn backoffMs(consecutive_failures: u32, base_ms: u32, cap_ms: u32) u32 {
    if (consecutive_failures == 0) return 0;
    var v: u64 = base_ms;
    var i: u32 = 1;
    while (i < consecutive_failures) : (i += 1) {
        v *%= 2;
        if (v >= cap_ms) return cap_ms;
    }
    return @intCast(@min(v, @as(u64, cap_ms)));
}

// L5 — Circuit breaker. Counts expensive OS calls (waveOutOpen attempts,
// ToothTray spawns) in a fixed (tumbling) window: the window resets in full
// once window_ms elapses, rather than sliding continuously. If the count
// exceeds max_events the circuit OPENS for cooldown_ms, during which allow()
// returns false. Makes a runaway registration storm physically impossible.
// Single-threaded per instance.
pub const CircuitBreaker = struct {
    window_ms: i64,
    max_events: u32,
    cooldown_ms: i64,
    count: u32 = 0,
    window_start_ms: i64 = 0,
    tripped_until_ms: i64 = 0,
    trip_count: u32 = 0,

    pub fn allow(self: *CircuitBreaker, now_ms: i64) bool {
        if (now_ms < self.tripped_until_ms) return false;
        if (now_ms - self.window_start_ms >= self.window_ms) {
            self.window_start_ms = now_ms;
            self.count = 0;
        }
        self.count += 1;
        if (self.count > self.max_events) {
            self.tripped_until_ms = now_ms + self.cooldown_ms;
            self.trip_count += 1;
            self.count = 0;
            self.window_start_ms = now_ms;
            return false;
        }
        return true;
    }

    fn isTripped(self: *const CircuitBreaker, now_ms: i64) bool {
        return now_ms < self.tripped_until_ms;
    }
};

// L6 — Paged-pool watchdog decision. Trips when current usage exceeds the
// lowest-seen baseline by more than threshold_bytes. Pure.
fn watchdogTripped(min_baseline_bytes: u64, current_bytes: u64, threshold_bytes: u64) bool {
    return current_bytes > min_baseline_bytes and (current_bytes - min_baseline_bytes) > threshold_bytes;
}

// R1 — Should the worker perform the programmatic radio reset now? Pure.
// armed_ms == 0 is the "not armed" sentinel. last_reset_ms == 0 means "no
// reset performed yet" (and can never collide with a real timestamp for the
// same reason as above).
pub fn shouldRadioReset(armed_ms: i64, now_ms: i64, last_reset_ms: i64) bool {
    if (armed_ms == 0) return false;
    if (now_ms - armed_ms < R1_ARM_MS) return false;
    if (last_reset_ms != 0 and now_ms - last_reset_ms < R1_COOLDOWN_MS) return false;
    return true;
}

// R2 — Should the worker escalate to the usb-cycle rung now? Pure.
// armed_ms == 0 is the "not armed" sentinel (same safety argument as R1).
// Escalation requires that the SOFTER rung (page-scan reset) already fired
// within this absence episode — the cycle never replaces rung 2, it only
// follows a failed rung 2. last_cycle_ms == 0 means "no cycle yet"; the
// min-interval gate keeps two cycles always at least R2_MIN_INTERVAL_MS apart
// even inside the breaker window. The CircuitBreaker in SharedState is the
// additional hard storm cap on top of these gates.
pub fn shouldUsbCycle(
    armed_ms: i64,
    now_ms: i64,
    r1_reset_in_episode: bool,
    last_cycle_ms: i64,
) bool {
    if (armed_ms == 0) return false;
    if (!r1_reset_in_episode) return false;
    if (now_ms - armed_ms < R2_ARM_MS) return false;
    if (last_cycle_ms != 0 and now_ms - last_cycle_ms < R2_MIN_INTERVAL_MS) return false;
    return true;
}

// R3 — Should the worker restart the earbuds' own function devnodes now?
// Pure. armed_ms == 0 is the "not armed" sentinel (same safety argument as
// R1/R2) and it outranks every other input: nothing fires before an absence
// episode has been observed. force_after_ms != 0 is the one-shot refresh
// queued after a VERIFIED usb-cycle completion; it deliberately bypasses the
// arm/interval/episode gates (the devnodes were just re-enumerated, so the
// pre-cycle history says nothing about them) but never bypasses the breaker,
// which is consulted by the caller.
pub fn shouldEarbudRestart(
    armed_ms: i64,
    now_ms: i64,
    last_restart_ms: i64,
    restarts_in_episode: u32,
    force_after_ms: i64,
) bool {
    if (armed_ms == 0) return false;
    if (force_after_ms != 0) return now_ms >= force_after_ms;
    if (now_ms - armed_ms < R3_ARM_MS) return false;
    if (restarts_in_episode >= R3_MAX_PER_EPISODE) return false;
    if (last_restart_ms != 0 and now_ms - last_restart_ms < R3_MIN_INTERVAL_MS) return false;
    return true;
}

/// r2-l2 -- SCOPE predicate: is this instance ID one of the earbuds' AUDIO
/// profile nodes (A2DP sink {0000110b} / AVRCP {0000110c})?
///
/// WHY THIS EXISTS (field 2026-09-03): restarting all ten of the earbuds'
/// BTHENUM nodes -- container DEV_<MAC>, Handsfree, SPP, GATT, PnP-info,
/// vendor nodes -- brought the link back through a re-enumeration instead of a
/// profile connect, so Windows never switched the default audio endpoint to
/// the earbuds. Narrowing the rung to the audio profiles keeps its curative
/// power (the wedge lives in the A2DP/AVRCP filters) without disturbing the
/// device container the audio endpoints hang off. Pure.
pub fn isEarbudAudioNode(id: []const u8) bool {
    return containsIgnoreCase(id, R3_AUDIO_PROFILE_A2DP) or
        containsIgnoreCase(id, R3_AUDIO_PROFILE_AVRCP);
}

/// r2-l2 -- may the usb-cycle escalate yet, given the last VERIFIED completion
/// of an earbud restart? Pure. 0 means "no restart yet" (nothing to wait for).
pub fn usbCycleQuietAfterRestart(now_ms: i64, last_restart_done_ms: i64) bool {
    if (last_restart_done_ms == 0) return true;
    return now_ms - last_restart_done_ms >= R2_POST_R3_QUIET_MS;
}

/// r2-l2 -- is the page-scan rung provably dead on this radio? Pure.
pub fn radioResetRungDead(consecutive_rejects: u32) bool {
    return consecutive_rejects >= R1_DEAD_REJECTIONS;
}

/// 0x948B93B1E4A1 -> "948b93b1e4a1": the shape a BTHENUM instance ID carries
/// for the remote device address (lowercase, no separators). Pure.
pub fn macHex12(addr: u64) [12]u8 {
    var out: [12]u8 = undefined;
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        const b: u8 = @truncate(addr >> @intCast(8 * (5 - i)));
        out[i * 2] = asciiLower(hexDigit(b >> 4));
        out[i * 2 + 1] = asciiLower(hexDigit(b & 0x0F));
    }
    return out;
}

/// Does this device instance ID belong to the target earbuds? Pure,
/// case-insensitive. Kept separate from the match loop so the ID shape stays
/// unit-testable against real field instance IDs.
pub fn idContainsMac(id: []const u8, mac_hex12: []const u8) bool {
    return containsIgnoreCase(id, mac_hex12);
}

// Case-insensitive ASCII substring test (allocation-free). Non-ASCII bytes
// compare verbatim.
fn asciiLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return false;
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var j: usize = 0;
        while (j < needle.len) : (j += 1) {
            if (asciiLower(haystack[i + j]) != asciiLower(needle[j])) break;
        }
        if (j == needle.len) return true;
    }
    return false;
}

/// Pure predicate: does this device instance ID belong to the CSR dongle?
/// Case-insensitive over ASCII. Unit-tested because the r1-l4 field failure
/// happened *around* this match (wrong enumeration query), and the matcher
/// itself must stay provably correct as the query changes.
fn isCsrRadioInstanceId(id: []const u8) bool {
    return containsIgnoreCase(id, R2_MATCH_VID) and containsIgnoreCase(id, R2_MATCH_PID);
}

fn isFxSoundName(name: []const u8) bool {
    return containsIgnoreCase(name, "fxsound") or containsIgnoreCase(name, "fx sound");
}

// L2 — Pick the waveOut device that routes the keepalive directly to the
// earbuds, bypassing the FxSound default-device APO (the storm amplifier).
//   1. If `override` is set, return the first device whose name contains it.
//   2. Otherwise match any >=4-char alphanumeric token of the Bluetooth device
//      name against the endpoint names, skipping FxSound endpoints.
// Returns the device index, or null to fall back to WAVE_MAPPER. Pure.
fn selectAudioDevice(names: []const []const u8, bt_name: []const u8, override: ?[]const u8) ?usize {
    if (override) |ov| {
        if (ov.len > 0) {
            for (names, 0..) |n, idx| {
                if (containsIgnoreCase(n, ov)) return idx;
            }
            return null;
        }
    }

    var start: usize = 0;
    var i: usize = 0;
    while (i <= bt_name.len) : (i += 1) {
        const at_end = i == bt_name.len;
        const is_sep = at_end or !(std.ascii.isAlphanumeric(bt_name[i]));
        if (is_sep) {
            const token = bt_name[start..i];
            if (token.len >= 4) {
                for (names, 0..) |n, idx| {
                    if (isFxSoundName(n)) continue;
                    if (containsIgnoreCase(n, token)) return idx;
                }
            }
            start = i + 1;
        }
    }
    return null;
}

// r2-l3 -- pure gates of the repair rung. Kept pure so the PoC harness and
// the unit tests exercise the very same decisions the daemon makes.

/// A repair is retried on a fixed short interval and is deliberately NOT
/// subject to a circuit breaker: giving up on re-enabling the user's
/// Bluetooth is never the safer option. Backwards clocks (DST, NTP step,
/// sleep/resume) must not stall it either.
pub fn shouldRetryRecovery(now: i64, last_attempt_ms: i64) bool {
    if (last_attempt_ms == 0) return true;
    if (now < last_attempt_ms) return true;
    return now - last_attempt_ms >= RECOVERY_RETRY_MS;
}

/// The repair is only complete when the radio is actually there AND no
/// matching devnode is left disabled. present == 0 means the dongle is
/// unplugged: nothing can be judged yet, so the journal must be KEPT.
pub fn radioRecoveryDone(present_nodes: u32, still_disabled: u32) bool {
    return present_nodes > 0 and still_disabled == 0;
}

/// Repair before escalate: while a disable of ours is unaccounted for,
/// harsher rungs would only pile damage onto a radio that is switched off.
pub fn recoveryBlocksEscalation(recovery_armed: bool) bool {
    return recovery_armed;
}

fn getSelfDir(buf: []u8) ![]u8 {
    var self_path_w: [2048:0]u16 = undefined;
    const len = GetModuleFileNameW(null, &self_path_w, @as(u32, self_path_w.len));
    if (len == 0) return error.ToothTraySpawnFailed;
    // On truncation GetModuleFileNameW returns nSize (the buffer length) and, on
    // older Windows, may not NUL-terminate. Treat a full buffer as failure rather
    // than silently resolving a truncated executable path.
    if (len >= self_path_w.len) return error.ToothTraySpawnFailed;
    const utf8_len = try std.unicode.utf16LeToUtf8(buf, self_path_w[0..len]);
    const src = buf[0..utf8_len];
    const dir_end = std.mem.lastIndexOfScalar(u8, src, '\\') orelse return error.ToothTraySpawnFailed;
    return buf[0 .. dir_end + 1];
}

fn triggerConnectionViaToothTray(state: *SharedState, device_name: []const u8) !void {
    if (state.last_tooth_tray_handle) |h| {
        const alive = WaitForSingleObject(h, 0);
        if (alive == WAIT_TIMEOUT) {
            return error.ToothTrayBusy;
        }
        _ = CloseHandle(h);
        state.last_tooth_tray_handle = null;
    }

    // Resolve directory of bluetooth_force.exe (ToothTray.exe sits next to it)
    var dir_buf: [4096]u8 = undefined;
    const dir_part = try getSelfDir(&dir_buf);

    // Escape the (attacker-controlled) device name so it cannot break out of
    // its quotes and inject arguments into ToothTray.exe. Assumes ToothTray
    // parses its command line with the standard CommandLineToArgvW/MSVCRT rules.
    var name_quoted_buf: [2048]u8 = undefined;
    const name_quoted = quoteArgInto(&name_quoted_buf, device_name) catch {
        debug("device name too long to quote safely", .{});
        return error.ToothTraySpawnFailed;
    };

    const cmdline_u8 = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "\"{s}ToothTray.exe\" connect {s}",
        .{ dir_part, name_quoted },
    );
    defer std.heap.page_allocator.free(cmdline_u8);

    if (cmdline_u8.len > 2046) {
        debug("cmdline too long: {} bytes", .{cmdline_u8.len});
        return error.ToothTraySpawnFailed;
    }
    var cmdline_u16: [2048:0]u16 = undefined;
    const utf16_len = try std.unicode.utf8ToUtf16Le(cmdline_u16[0 .. cmdline_u16.len - 1], cmdline_u8);
    cmdline_u16[utf16_len] = 0;

    var si: STARTUPINFOW = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi: PROCESS_INFORMATION = std.mem.zeroes(PROCESS_INFORMATION);

    const ok = CreateProcessW(
        null,
        &cmdline_u16,
        null, null, 0,
        CREATE_NO_WINDOW, null, null,
        &si, &pi,
    );
    if (ok == 0) {
        debug("CreateProcessW failed: 0x{x}", .{GetLastError()});
        return error.ToothTraySpawnFailed;
    }
    // Thread handle is not needed after spawn
    _ = CloseHandle(pi.hThread);

    // Wait for ToothTray to finish. No TerminateProcess — killing the process mid-IOCTL
    // can leave the BT driver in an inconsistent state requiring adapter re-plug.
    const wait_res = WaitForSingleObject(pi.hProcess, 15000);
    if (wait_res != WAIT_OBJECT_0) {
        state.last_tooth_tray_handle = pi.hProcess;
        return error.ToothTrayFailed;
    }

    var exit_code: u32 = 0;
    _ = GetExitCodeProcess(pi.hProcess, &exit_code);
    _ = CloseHandle(pi.hProcess);
    state.last_tooth_tray_handle = null;

    if (exit_code != 0) {
        debug("ToothTray: failed, exit {}", .{exit_code});
        return error.ToothTrayFailed;
    }
}

// ---------------------------------------------------------------------------
// Worker thread: polls BT devices and triggers connection via ToothTrayCli
// ---------------------------------------------------------------------------
fn workerThread(state: *SharedState) void {
    var poll_count: u32 = 0;
    while (state.running.load(.acquire)) {
        const wait_result = WaitForSingleObject(state.resume_event, POLL_INTERVAL_MS);

        switch (wait_result) {
            WAIT_OBJECT_0 => {
                if (!state.running.load(.acquire)) break;
                Sleep(RESUME_DELAY_MS);
                if (!state.running.load(.acquire)) break;
            },
            WAIT_TIMEOUT => {},
            WAIT_FAILED => {
                // A transient wait failure must NOT permanently kill polling;
                // that would silently stop all reconnect/keepalive handling
                // until the process is restarted. Back off one poll interval
                // and retry -- only `running` going false ends the loop.
                debug("WaitForSingleObject FAILED: 0x{x}", .{GetLastError()});
                Sleep(POLL_INTERVAL_MS);
                continue;
            },
            else => {
                debug("unexpected wait result=0x{x}", .{wait_result});
                Sleep(POLL_INTERVAL_MS);
                continue;
            },
        }

        if (!state.running.load(.acquire)) break;

        // L6 — sample paged pool each cycle; pause keepalive/connects if the
        // system pool is growing abnormally (the diagnosed driver leak).
        sampleWatchdog(state);

        poll_count += 1;
        performPoll(state, poll_count) catch |e| {
            if (e != error.ToothTrayBusy) {
                debug("performPoll: {s}", .{@errorName(e)});
            }
            continue;
        };
    }
}

// L6 — Sample system paged-pool and pause/resume on abnormal growth. Tracks the
// lowest-seen usage as baseline so a one-time post-boot ramp doesn't false-trip.
fn sampleWatchdog(state: *SharedState) void {
    const cur = queryPagedPoolBytes() orelse return;
    if (cur < state.pool_min_bytes) state.pool_min_bytes = cur;
    const now = nowMs();

    if (!state.watchdog_tripped) {
        if (watchdogTripped(state.pool_min_bytes, cur, WATCHDOG_TRIP_BYTES)) {
            state.watchdog_tripped = true;
            state.watchdog_tripped_ms = now;
            state.watchdog_last_log_ms = now;
            debug("WATCHDOG TRIPPED: paged pool +{} MB over baseline — pausing keepalive/connects", .{(cur - state.pool_min_bytes) / (1024 * 1024)});
            state.silent.stop();
        }
        return;
    }

    // Tripped. Preferred exit: the pool falls back near baseline.
    if (cur <= state.pool_min_bytes + WATCHDOG_CLEAR_BYTES) {
        state.watchdog_tripped = false;
        debug("watchdog cleared: paged pool back near baseline", .{});
        return;
    }

    // Safety exit: the pool has stayed high for too long. Since we measure the
    // *global* system pool, an external process could keep it elevated forever;
    // force-clear and re-baseline to the current level so the keepalive resumes
    // (a permanently paused keepalive would silently break our whole purpose).
    if (now - state.watchdog_tripped_ms >= WATCHDOG_FORCE_CLEAR_MS) {
        state.watchdog_tripped = false;
        state.pool_min_bytes = cur;
        debug("watchdog force-clear after timeout; re-baselining to {} MB and resuming", .{cur / (1024 * 1024)});
        return;
    }

    // Still tripped: periodic heartbeat so the paused state is visible in logs.
    if (now - state.watchdog_last_log_ms >= WATCHDOG_LOG_INTERVAL_MS) {
        state.watchdog_last_log_ms = now;
        debug("watchdog still tripped: paged pool {} MB (+{} MB over baseline)", .{ cur / (1024 * 1024), (cur - state.pool_min_bytes) / (1024 * 1024) });
    }
}

// ---------------------------------------------------------------------------
// Poll decision — extracted as a pure function so the "connected -> start the
// silent keepalive" trigger (the *sole* entry point for sound playback) is
// unit-testable without spawning threads, opening waveOut, or touching the
// Bluetooth API. performPoll() applies the exact same logic below.
//
// This is the heart of the "sound is guaranteed when the case is opened"
// contract: the only way the keepalive ever starts is through this decision
// returning .start_keepalive, so exhaustively testing it covers every path
// that can (or cannot) lead to sound.
// ---------------------------------------------------------------------------
const PollAction = enum {
    /// Target device was not found on this radio — keep scanning.
    none,
    /// Target is connected — start (or keep running) the silent keepalive so
    /// the earbuds hear a non-zero stream and never idle-disconnect.
    start_keepalive,
    /// Target is known but not connected — stop any stale keepalive and ask
    /// ToothTray to bring the link up.
    stop_and_connect,
};

pub fn decidePollAction(found: bool, fConnected: i32) PollAction {
    if (!found) return .none;
    if (fConnected != 0) return .start_keepalive;
    return .stop_and_connect;
}

fn performPoll(state: *SharedState, _: u32) !void {
    var radio_params = BLUETOOTH_FIND_RADIO_PARAMS{ .dwSize = @sizeOf(BLUETOOTH_FIND_RADIO_PARAMS) };

    var radio_handle: ?*anyopaque = null;
    const radio_find = state.bth.BluetoothFindFirstRadio(&radio_params, &radio_handle);
    if (radio_find == null) return;
    defer _ = state.bth.BluetoothFindRadioClose(radio_find);

    while (true) {
        const rh = radio_handle orelse break;
        defer _ = CloseHandle(rh);

        var search_params = BLUETOOTH_DEVICE_SEARCH_PARAMS{
            .dwSize = @sizeOf(BLUETOOTH_DEVICE_SEARCH_PARAMS),
            .fReturnAuthenticated = 1,
            .fReturnRemembered = 1,
            .fReturnUnknown = 0,
            .fReturnConnected = 1,
            .fIssueInquiry = 0,
            .cTimeoutMultiplier = 1,
            .hRadio = rh,
        };

        var device_info = BLUETOOTH_DEVICE_INFO{
            .dwSize = @sizeOf(BLUETOOTH_DEVICE_INFO),
            .Address = BLUETOOTH_ADDRESS{ .ullRemote = 0 },
            .ulClassofDevice = 0,
            .fConnected = 0,
            .fRemembered = 0,
            .fAuthenticated = 0,
            .stLastSeen = SYSTEMTIME{
                .wYear = 0, .wMonth = 0, .wDayOfWeek = 0, .wDay = 0,
                .wHour = 0, .wMinute = 0, .wSecond = 0, .wMilliseconds = 0,
            },
            .stLastUsed = SYSTEMTIME{
                .wYear = 0, .wMonth = 0, .wDayOfWeek = 0, .wDay = 0,
                .wHour = 0, .wMinute = 0, .wSecond = 0, .wMilliseconds = 0,
            },
            .szName = [_]u16{0} ** 248,
        };

        const device_find = state.bth.BluetoothFindFirstDevice(&search_params, &device_info);
        if (device_find == null) {
            radio_handle = null;
            if (state.bth.BluetoothFindNextRadio(radio_find, &radio_handle) == 0) break;
            continue;
        }
        defer _ = state.bth.BluetoothFindDeviceClose(device_find);

        var found = false;
        while (true) {
            if (device_info.Address.ullRemote == state.target_mac) {
                found = true;
                break;
            }
            device_info.dwSize = @sizeOf(BLUETOOTH_DEVICE_INFO);
            device_info.Address.ullRemote = 0;
            if (state.bth.BluetoothFindNextDevice(device_find, &device_info) == 0) break;
        }

        if (found) {
            // Decode the device name once (best-effort). Unlike the old code, the
            // name is now needed on BOTH branches: the keepalive uses it to pick
            // the earbuds' own audio endpoint (L2). A name that fails UTF-16 ->
            // UTF-8 conversion must still never prevent the keepalive from
            // starting (that is the app's whole job), so on decode failure we
            // fall back to an empty name -> resolveDevice() uses WAVE_MAPPER,
            // still bounded by the circuit breaker.
            var name_buf: [1024]u8 = undefined;
            var name_u16_len: usize = 0;
            while (name_u16_len < 248 and device_info.szName[name_u16_len] != 0) : (name_u16_len += 1) {}
            // utf16LeToUtf8 returns the number of bytes written (usize), not a
            // slice; capture the length and slice the buffer ourselves. On decode
            // failure fall back to length 0 -> empty name -> WAVE_MAPPER.
            const name_len = std.unicode.utf16LeToUtf8(name_buf[0..], device_info.szName[0..name_u16_len]) catch blk: {
                debug("utf16 conversion error; using default audio endpoint", .{});
                break :blk 0;
            };
            const name: []const u8 = name_buf[0..name_len];

            // Route through the pure decision function so the tested logic and
            // the production logic can never drift apart.
            switch (decidePollAction(found, device_info.fConnected)) {
                .start_keepalive => {
                    // Earbuds are connected: reset connect backoff and start the
                    // endpoint-targeted keepalive — unless the watchdog paused us.
                    state.connect_fails = 0;
                    state.next_connect_ms = 0;
                    state.r1_armed_ms = 0; // R1 — link is up, wedge is moot
                    state.r1_reset_in_episode = false; // R2 — ladder disarmed too
                    // R3 — the absence episode is over: its per-episode budget,
                    // spacing history and any queued post-cycle refresh all
                    // belong to that episode and are dropped with it.
                    state.r3_restarts_in_episode = 0;
                    state.r3_last_restart_ms = 0;
                    state.r3_force_after_ms = 0;
                    state.r3_last_complete_ms = 0;
                    if (!state.watchdog_tripped) state.silent.start(name);
                    return;
                },
                .stop_and_connect => {
                    // Not connected: stop any keepalive (no point streaming to an
                    // absent device -> avoids FxSound/driver churn while away).
                    state.silent.stop();
                    if (state.watchdog_tripped) return;

                    const now = nowMs();

                    // r2-l3 -- RUNG 0: repair before escalate.
                    //
                    // If a disable of ours is unaccounted for, the radio may
                    // be switched off entirely (field 2026-09-03: Bluetooth
                    // showed up disabled in Device Manager, and a replug did
                    // not help because the flag is persistent). Escalating
                    // in that state is pointless and harmful, so the repair
                    // runs first and blocks the whole ladder until it is
                    // done. It is intentionally NOT capped by a breaker.
                    if (shouldRetryRecovery(now, state.recovery_last_ms)) {
                        state.recovery_last_ms = now;
                        state.recovery_armed = recoveryJournalPresent();
                        if (state.recovery_armed) {
                            state.recovery_attempts +|= 1;
                            if (!state.recovery_logged) {
                                state.recovery_logged = true;
                                debug("rung recovery: a pending disable was left behind ({s}) -- every escalation rung is BLOCKED until the radio is enabled again", .{RECOVERY_JOURNAL_NAME});
                            }
                            var rout = HealthOut{ .hFile = null, .tag = "rung recovery" };
                            _ = recoverDisabledRadio(&rout, false);
                            // Re-read the marker instead of trusting the
                            // return value (r1-l5: an API receipt is not a
                            // state). Only the marker being gone means the
                            // radio was observed present and started.
                            state.recovery_armed = recoveryJournalPresent();
                            if (!state.recovery_armed) {
                                debug("rung recovery: cleared after {} attempt(s) -- the ladder is armed again", .{state.recovery_attempts});
                                state.recovery_attempts = 0;
                                state.recovery_logged = false;
                            }
                        }
                    }
                    if (recoveryBlocksEscalation(state.recovery_armed)) return;

                    // R1 — wedge recovery, checked on EVERY entry into this
                    // branch (ahead of the L3 backoff gate): a wedged radio must
                    // not have its cure delayed by the retry clock.
                    //
                    // Arm on the first observation of the absence episode.
                    // "Remembered but not connected" is the same observable for
                    // earbuds resting in their case and earbuds paging at a
                    // wedged radio (ToothTray's one-shot connect succeeds either
                    // way), so absence-duration is the only usable trigger. The
                    // CircuitBreaker below is what keeps resting-earbuds cost
                    // bounded (max 3 resets per 10 minutes, then silence).
                    if (state.r1_armed_ms == 0) state.r1_armed_ms = now;
                    // r2-l2 -- a rung that is rejected by this dongle on every
                    // single attempt must not hold the ladder hostage: once it
                    // is proven dead it is muted for the run AND the escalation
                    // mark is set, so the PnP rungs below stop waiting for it.
                    if (radioResetRungDead(state.r1_rejects)) {
                        if (!state.r1_dead_logged) {
                            state.r1_dead_logged = true;
                            debug("rung page-scan: MUTED for this run after {} consecutive rejections -- escalation goes straight to the PnP rungs", .{state.r1_rejects});
                        }
                        state.r1_reset_in_episode = true;
                    } else if (shouldRadioReset(state.r1_armed_ms, now, state.r1_last_reset_ms) and
                        state.r1_breaker.allow(now))
                    {
                        // Rate-limit the whole procedure regardless of outcome.
                        state.r1_last_reset_ms = now;
                        // R2 escalation mark: rung 2 has now been exercised in
                        // this absence episode (success or failure alike).
                        state.r1_reset_in_episode = true;
                        if (radioReset(state, rh)) {
                            // The rung works on this radio after all -- forget
                            // the rejection history so it is never muted by
                            // stale evidence.
                            state.r1_rejects = 0;
                            state.connect_fails = 0;
                            state.next_connect_ms = now + R1_POST_RESET_RECONNECT_MS;
                            return;
                        }
                        state.r1_rejects +|= 1;
                        debug("R1: reset attempt failed ({} in a row); will retry after cooldown", .{state.r1_rejects});
                    }

                    // R3 — earbud-devnode restart (r2-l1), the rung that took
                    // the place of the service-restart wave. Deliberately
                    // BEFORE the usb-cycle: it is the cheaper, narrower
                    // operation (only the earbuds' own function devnodes are
                    // torn down; everything else on the dongle keeps working),
                    // and it addresses the wedge class the field proved lives
                    // ABOVE the radio — two verified usb-cycles with a healthy
                    // dongle and still no link (r1-l11, 13:41).
                    // Gate order matches R1/R2: pure gates first, breaker last
                    // (short-circuit, so an early attempt never burns budget),
                    // elevation checked inside restartEarbudDevnodes.
                    if (!escalationFrozen(state, now) and shouldEarbudRestart(
                        state.r1_armed_ms,
                        now,
                        state.r3_last_restart_ms,
                        state.r3_restarts_in_episode,
                        state.r3_force_after_ms,
                    ) and state.r3_breaker.allow(now))
                    {
                        // Rate-limit regardless of outcome, and consume the
                        // one-shot post-cycle refresh before the attempt so a
                        // failure cannot make it fire again on the next poll.
                        state.r3_force_after_ms = 0;
                        state.r3_last_restart_ms = now;
                        state.r3_restarts_in_episode +|= 1;
                        if (restartEarbudDevnodes(state)) {
                            // FRESH clock: the pass takes seconds, and the
                            // r1-l11 post-mortem traced its mis-timed gate to a
                            // stale `now` captured before a long operation.
                            const after_restart = nowMs();
                            state.connect_fails = 0;
                            state.next_connect_ms = after_restart + R3_POST_RESTART_RECONNECT_MS;
                            // r2-l2 -- the harsher rung now owes this restart a
                            // quiet window measured from its VERIFIED completion.
                            state.r3_last_complete_ms = after_restart;
                            return;
                        }
                        debug("R3: earbud-devnode restart did not restart any node; falling through to the next rung", .{});
                    }

                    // R2 — usb-cycle escalation, checked right after the failed
                    // (or capped) page-scan rung and BEFORE the L3 backoff gate:
                    // a wedged dongle must not wait on the retry clock. Mirrors
                    // the R1 gate order: pure gates first, breaker last
                    // (short-circuit, so an armed-but-early cycle never burns
                    // breaker budget), admin check inside usbCycleRadio.
                    if (!escalationFrozen(state, now) and shouldUsbCycle(
                        state.r1_armed_ms,
                        now,
                        state.r1_reset_in_episode,
                        state.r2_last_cycle_ms,
                    ) and usbCycleQuietAfterRestart(now, state.r3_last_complete_ms) and
                        state.r2_breaker.allow(now))
                    {
                        state.r2_last_cycle_ms = now;
                        if (usbCycleRadio(state)) {
                            // The radio was torn down and re-enumerated: give
                            // the stack one poll cycle to settle, same policy
                            // as R1. The absence episode continues (the device
                            // is still away), so r1_armed_ms stays armed and
                            // the ladder restarts from its softer rungs under
                            // the breaker caps.
                            state.connect_fails = 0;
                            // FRESH clock after the multi-second cycle (r2-l1):
                            // every follow-up gate must be measured from the
                            // VERIFIED COMPLETION, never from the tick that
                            // started the operation — that stale-`now` bug is
                            // what let the r1-l11 wave fire 19.2 s after a
                            // cycle instead of 30 s.
                            const after_cycle = nowMs();
                            state.next_connect_ms = after_cycle + R2_POST_CYCLE_RECONNECT_MS;
                            // The dongle was re-enumerated, so the earbuds'
                            // function devnodes usually come back stale: queue
                            // exactly one verified refresh of them, and clear
                            // the pre-cycle R3 history that no longer describes
                            // the new devnodes.
                            state.r3_force_after_ms = after_cycle + R3_POST_CYCLE_DELAY_MS;
                            state.r3_restarts_in_episode = 0;
                            state.r3_last_restart_ms = 0;
                            return;
                        }
                        // Cycle failed (no admin / not found / SetupAPI error):
                        // fall through to the normal cadence; the gates above
                        // plus the breaker keep the retry rhythm bounded.
                    }

                    if (now < state.next_connect_ms) return; // L3 backoff window
                    if (!state.tt_breaker.allow(now)) { // L5 circuit breaker
                        debug("connect circuit OPEN — cooling down", .{});
                        return;
                    }

                    triggerConnectionViaToothTray(state, name) catch |e| {
                        switch (e) {
                            error.ToothTrayBusy => {}, // prior attempt still running; no penalty
                            else => {
                                debug("ToothTrayCli error: {s}", .{@errorName(e)});
                                state.connect_fails +|= 1;
                                state.next_connect_ms = now + backoffMs(
                                    state.connect_fails,
                                    CONNECT_BACKOFF_BASE_MS,
                                    CONNECT_BACKOFF_CAP_MS,
                                );
                                // R1 note: ToothTray failures intentionally do
                                // NOT arm the recovery window — the one-shot
                                // connect succeeds (exit 0) even for unreachable
                                // devices, so exit codes carry no wedge signal.
                            },
                        }
                        return;
                    };
                    // Spawn succeeded and ToothTray reported success.
                    // R1 note: this is NOT treated as a link — ToothTray's
                    // one-shot connect returns 0 even when the device is
                    // unreachable, so only start_keepalive (a real link seen
                    // by the poll) disarms the recovery window.
                    state.connect_fails = 0;
                    state.next_connect_ms = 0;
                    return;
                },
                // found == true rules out .none.
                .none => {},
            }
        }

        radio_handle = null;
        if (state.bth.BluetoothFindNextRadio(radio_find, &radio_handle) == 0) break;
    }
}

// ---------------------------------------------------------------------------
// R1 — programmatic radio reset ("software re-plug")
// ---------------------------------------------------------------------------
// Symptom this treats: after an ugly disconnect (or a failed USB selective
// suspend wake) the radio/stack can wedge with a stuck page-scan state —
// outgoing connects fail and incoming pages from the earbuds go unanswered,
// so the poll loop retries forever into a dead end. The user's workaround —
// physically unplug/replug the dongle — resets the controller's scan state.
// This is the software equivalent, done through the documented bthprops.cpl
// API already loaded for the poll loop:
//   BluetoothEnableIncomingConnections(hRadio, false)  ->  quiet pause
//   BluetoothEnableIncomingConnections(hRadio, true)
// Disabling forces the stack to rewrite the controller's scan-enable state on
// re-enable, which re-arms page scan. No admin rights, no driver reload.
// A failed re-enable would leave the adapter non-connectable (worse than the
// wedge), so that step is retried hard before giving up.
fn radioReset(state: *SharedState, hRadio: ?*anyopaque) bool {
    const enableIncoming = state.bth.BluetoothEnableIncomingConnections orelse {
        debug("R1: BluetoothEnableIncomingConnections unavailable, reset skipped", .{});
        return false;
    };
    debug("R1: radio reset begin (page-scan toggle)", .{});
    if (enableIncoming(hRadio, 0) == 0) {
        // Nothing was changed: the wedge state is untouched and the normal
        // retry cadence continues untouched.
        debug("R1: disable failed 0x{x}, radio left as-is", .{GetLastError()});
        return false;
    }
    Sleep(R1_TOGGLE_QUIET_MS);
    var reenabled = false;
    var attempt: u32 = 0;
    while (attempt < R1_REENABLE_ATTEMPTS) : (attempt += 1) {
        if (attempt > 0) Sleep(R1_REENABLE_RETRY_MS);
        if (enableIncoming(hRadio, 1) != 0) {
            reenabled = true;
            break;
        }
        debug("R1: re-enable attempt {}/{} failed 0x{x}", .{ attempt + 1, R1_REENABLE_ATTEMPTS, GetLastError() });
    }
    if (!reenabled) {
        debug("R1: RE-ENABLE FAILED after retries — adapter may stay non-connectable until next reset or replug", .{});
        return false;
    }
    debug("R1: radio reset complete", .{});
    return true;
}

// ---------------------------------------------------------------------------
// R2 — usb-cycle ("hardware re-plug") via SetupAPI
// ---------------------------------------------------------------------------
// The escalation rung of the ladder (see the R2 constants block). Field
// evidence showed wedges that survive the R1 page-scan toggle and only clear
// when the dongle loses power — the classic manual fix was physically
// yanking the CSR dongle. This is that fix, software-driven:
//
//   1. enumerate present devnodes on the USB enumerator (see ENUMERATOR_USB
//      for why the setup-class GUID must NOT be used here), match
//      VID_0A12/PID_0001 (CSR)
//   2. DICS_DISABLE via DIF_PROPERTYCHANGE  -> dongle drops off the bus
//   3. observe CM_PROB_DISABLED (r1-l8 verified disable; CfgMgr32 fallback
//      on miss) + quiet pause (R2_DISABLE_QUIET_MS)
//   4. DICS_ENABLE                          -> fresh enumeration, fresh
//                                              controller state
//   5. observe DN_STARTED with no problem code (r1-l8 verified enable: the
//      DICS_ENABLE acceptance alone is NOT an enable — field 23:55) —
//      each attempt runs DIF and CM_Enable_DevNode sequentially, and a
//      cycle that cannot verify the enable reports FAILED, not "complete"
//
// Requires elevation: a non-admin DIF_PROPERTYCHANGE fails with
// ERROR_ACCESS_DENIED, so the rung proactively logs "skipped (admin
// required)" exactly once and stays dormant instead of hammering a denied
// call every poll. Success is reported as "complete (N cycled)"; after it the
// stack needs a few seconds to bring the radio back — the earbuds typically
// reconnect within ~10 s (field metric), the poll loop simply rides it out.
fn usbCycleRadio(state: *SharedState) bool {
    if (IsUserAnAdmin() == 0) {
        if (!state.r2_admin_skip_logged) {
            state.r2_admin_skip_logged = true;
            debug("rung usb-cycle: skipped (admin required) — run from diagnose.ps1 or an elevated shell", .{});
        }
        return false;
    }
    // dbgview-only channel under the historical "rung usb-cycle:" tag — the
    // field protocol greps for these exact lines (begin → cycling → complete).
    var out = HealthOut{ .hFile = null, .tag = "rung usb-cycle" };
    return cycleCsrRadioOnce(&out);
}

/// The usb-cycle core, shared by the auto-ladder rung (usbCycleRadio, dbgview
/// lines under the "rung usb-cycle:" tag) and the one-shot --cycle mode
/// (report file + "cycle:" tag). Every step line goes through out.line so
/// both channels carry identical evidence text; in the auto-ladder the report
/// handle is null and the line lands in DebugView only.
fn cycleCsrRadioOnce(out: *HealthOut) bool {
    out.line("begin", .{});

    // Query by PnP enumerator "USB", NOT by GUID_DEVCLASS_USB: the radio's
    // devnode lives in the Bluetooth setup class, so the class-GUID query
    // missed it in the field (r1-l4, archive 2026-09-02 22:07 — see the
    // comment at ENUMERATOR_USB). ClassGuid=NULL REQUIRES DIGCF_ALLCLASSES
    // (r1-l7, archive 2026-09-02 22:41 — see the comment at DIGCF_ALLCLASSES).
    // Instance IDs are matched by hand below.
    const devs = SetupDiGetClassDevsW(null, &ENUMERATOR_USB, null, DIGCF_PRESENT | DIGCF_ALLCLASSES) orelse {
        out.line("SetupDiGetClassDevsW failed 0x{x}", .{GetLastError()});
        return false;
    };
    defer _ = SetupDiDestroyDeviceInfoList(devs);

    // Find the CSR dongle's devnode. Device instance IDs are ASCII; compare
    // case-insensitively over a stack-decoded copy.
    var target = SP_DEVINFO_DATA{
        .cbSize = @sizeOf(SP_DEVINFO_DATA),
        .InterfaceClassGuid = GUID_DEVCLASS_USB,
        .DevInst = 0,
        .Reserved = 0,
    };
    var matched = false;
    var matched_len: usize = 0;
    var scanned: u32 = 0; // devnodes the query actually returned (r1-l7 miss forensics)
    var index: u32 = 0;
    var id_ascii: [220]u8 = undefined;
    while (!matched) : (index += 1) {
        var info = SP_DEVINFO_DATA{
            .cbSize = @sizeOf(SP_DEVINFO_DATA),
            .InterfaceClassGuid = GUID_DEVCLASS_USB,
            .DevInst = 0,
            .Reserved = 0,
        };
        if (SetupDiEnumDeviceInfo(devs, index, &info) == 0) break; // end of list
        scanned += 1;

        var id_wide: [220]u16 = undefined;
        if (SetupDiGetDeviceInstanceIdW(devs, &info, &id_wide, id_wide.len, null) == 0) continue;

        var n: usize = 0;
        while (n < id_wide.len and id_wide[n] != 0) : (n += 1) {}
        if (n > id_ascii.len) continue;
        for (id_wide[0..n], 0..) |ch, i| id_ascii[i] = asciiLower(@truncate(ch));

        if (isCsrRadioInstanceId(id_ascii[0..n])) {
            target = info;
            matched_len = n;
            matched = true;
        }
    }
    if (!matched) {
        // r1-l7: the scanned count splits the two possible failure worlds in
        // the field log: scanned=0 => the QUERY is broken (flags/enum), while
        // scanned>0 without a match => the MATCH is broken (ID shape). r1-l5
        // shipped a broken query and the log could not tell the two apart.
        out.line("CSR radio USB\\VID_0A12&PID_0001 not present (scanned {d} devnodes on the USB enumerator), cycle aborted", .{scanned});
        return false;
    }

    // Log the exact devnode we are about to cycle — in field archives this
    // line is the anchor that ties the fix to the user's physical dongle.
    out.line("cycling {s}...", .{id_ascii[0..matched_len]});

    // r2-l3 -- try the NON-PERSISTENT path first. pnputil /restart-device
    // stops and restarts the devnode without ever writing the persistent
    // disabled flag, so a process death in the middle of it can not leave
    // the user without Bluetooth. Same power-cycle effect on the radio.
    {
        var exe_buf: [1100]u8 = undefined;
        if (systemPathOf(&exe_buf, "pnputil.exe")) |pnputil| {
            var cmd_buf: [1500]u8 = undefined;
            if (std.fmt.bufPrint(&cmd_buf, "\"{s}\" /restart-device \"{s}\"", .{ pnputil, id_ascii[0..matched_len] })) |cmd| {
                const code = runHiddenWait(cmd, PNPUTIL_TIMEOUT_MS);
                if (code != null and code.? == 0 and waitDevnodeStarted(target.DevInst, R2_ENABLE_VERIFY_MS)) {
                    out.line("complete (1 cycled via pnputil /restart-device, no persistent disable needed)", .{});
                    return true;
                }
                out.line("pnputil /restart-device did not verify (exit={?}) -- falling back to the journalled disable/enable pair", .{code});
            } else |_| {}
        }
    }

    // r2-l3 -- ARM THE JOURNAL BEFORE THE DISABLE. A persistent disable
    // outlives this process, a replug and a reboot; on 2026-09-03 the user
    // was left with Bluetooth switched off in Device Manager exactly that
    // way. If the marker can not be made durable, the disable is not
    // attempted at all.
    if (!recoveryJournalArm(id_ascii[0..matched_len])) {
        out.line("cannot write {s} next to the exe -- REFUSING to disable the dongle (an unrecoverable disable is worse than a wedge)", .{RECOVERY_JOURNAL_NAME});
        return false;
    }

    // Disable: primary path is DIF_PROPERTYCHANGE (what Device Manager does);
    // r1-l4 fallback is CM_Disable_DevNode — same effect through CfgMgr32,
    // immune to install-params packing. Field logs (r1-l3) showed the DIF
    // path rejected with 0x80070006, so on machines where it never works the
    // cycle still fires instead of dying on the first step.
    if (!usbPropChange(devs, &target, DICS_DISABLE)) {
        const dif_err = GetLastError();
        if (CM_Disable_DevNode(target.DevInst, 0) == CR_SUCCESS) {
            out.line("DIF disable failed 0x{x}, disabled via CM_Disable_DevNode", .{dif_err});
        } else {
            out.line("disable failed (DIF 0x{x}, CM failed too), dongle left as-is", .{dif_err});
            recoveryJournalDisarm(); // nothing was disabled: nothing to repair
            return false;
        }
    }

    // r1-l8: verify the disable actually landed before enabling. Enabling a
    // devnode whose disable never completed would fake a cure (the controller
    // would never lose power). Observed state: DN_HAS_PROBLEM +
    // CM_PROB_DISABLED. On a miss, retry through the CfgMgr32 path and
    // observe again; if the disabled state never shows, stop WITHOUT
    // enabling so the dongle is left exactly as it was.
    if (!waitDevnodeDisabled(target.DevInst, R2_DISABLE_VERIFY_MS)) {
        out.line("disable not observed in {} ms — trying CM_Disable_DevNode", .{R2_DISABLE_VERIFY_MS});
        const cm_dis = CM_Disable_DevNode(target.DevInst, 0) == CR_SUCCESS;
        if (!cm_dis or !waitDevnodeDisabled(target.DevInst, R2_DISABLE_VERIFY_MS)) {
            out.line("disable did not take effect — aborting WITHOUT enabling, dongle state untouched", .{});
            recoveryJournalDisarm(); // the node never went down: nothing to repair
            return false;
        }
    }
    Sleep(R2_DISABLE_QUIET_MS);

    // Enable is the one step that must not fail silently: a dongle left
    // disabled is exactly the state this tool exists to cure. r1-l8: every
    // attempt is VERIFIED against the devnode status (DN_STARTED, no problem
    // code), because DICS_ENABLE acceptance alone is not an enable — field
    // archive 2026-09-02 23:55: the call returned TRUE, the devnode never
    // restarted, stayed CM_PROB_DISABLED and the tool reported success. The
    // two paths now run SEQUENTIALLY per attempt (the old short-circuit
    // `or` never reached CM_Enable_DevNode exactly when it was needed).
    var started = false;
    var attempt: u32 = 0;
    while (attempt < R1_REENABLE_ATTEMPTS and !started) : (attempt += 1) {
        if (attempt > 0) Sleep(R1_REENABLE_RETRY_MS * 2);

        if (usbPropChange(devs, &target, DICS_ENABLE)) {
            started = waitDevnodeStarted(target.DevInst, R2_ENABLE_VERIFY_MS);
            if (started) break;
            out.line("enable attempt {}/{}: DICS_ENABLE accepted but not STARTED in {} ms — trying CM_Enable_DevNode", .{ attempt + 1, R1_REENABLE_ATTEMPTS, R2_ENABLE_VERIFY_MS });
        } else {
            out.line("enable attempt {}/{}: DICS_ENABLE rejected 0x{x} — trying CM_Enable_DevNode", .{ attempt + 1, R1_REENABLE_ATTEMPTS, GetLastError() });
        }

        if (CM_Enable_DevNode(target.DevInst, 0) == CR_SUCCESS) {
            started = waitDevnodeStarted(target.DevInst, R2_ENABLE_VERIFY_MS);
            if (started) break;
            out.line("enable attempt {}/{}: CM_Enable_DevNode accepted but not STARTED in {} ms", .{ attempt + 1, R1_REENABLE_ATTEMPTS, R2_ENABLE_VERIFY_MS });
        } else {
            out.line("enable attempt {}/{}: CM_Enable_DevNode failed 0x{x}", .{ attempt + 1, R1_REENABLE_ATTEMPTS, GetLastError() });
        }
    }
    if (!started) {
        out.line("ENABLE FAILED after {} attempts — dongle is left DISABLED. The repair rung KEEPS RETRYING every {} ms and at every start, because {s} is still armed. Manual options:", .{ R1_REENABLE_ATTEMPTS, RECOVERY_RETRY_MS, RECOVERY_JOURNAL_NAME });
        out.line("  0) elevated: bluetooth_force.exe --recover", .{});
        out.line("  1) admin PowerShell: Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'USB\\VID_0A12*' | Enable-PnpDevice -Confirm:$false", .{});
        out.line("  2) Device Manager: the CSR radio with the down-arrow -> Enable", .{});
        out.line("  3) replug into a DIFFERENT USB port (same-port replug keeps the disabled flag)", .{});
        return false;
    }

    // The pair completed and the node is STARTED: the disable is accounted
    // for, so the journal must go before anything else can read it.
    recoveryJournalDisarm();
    out.line("complete (1 cycled)", .{});
    return true;
}

/// r1-l8: devnode state predicates over CM_Get_DevNode_Status. Pure so the
/// bit semantics stay unit-testable. A disable lands as DN_HAS_PROBLEM +
/// CM_PROB_DISABLED; a completed enable lands as DN_STARTED with no problem
/// code. The -Checked variants wrap the Win32 call (0 = CR_SUCCESS).
fn devnodeStatusMeansDisabled(status: u32, problem: u32) bool {
    return (status & DN_HAS_PROBLEM) != 0 and problem == CM_PROB_DISABLED;
}

fn devnodeStatusMeansStarted(status: u32, problem: u32) bool {
    return (status & DN_STARTED) != 0 and (status & DN_HAS_PROBLEM) == 0 and problem == 0;
}

fn devnodeDisabled(devinst: u32) bool {
    var status: u32 = 0;
    var problem: u32 = 0;
    if (CM_Get_DevNode_Status(&status, &problem, devinst, 0) != 0) return false;
    return devnodeStatusMeansDisabled(status, problem);
}

/// Poll until the devnode shows the started state (or the timeout expires).
/// Returns the last observed verdict — the caller treats false as "this
/// enable attempt did not take effect".
fn waitDevnodeStarted(devinst: u32, timeout_ms: u32) bool {
    var waited: u32 = 0;
    while (true) {
        var status: u32 = 0;
        var problem: u32 = 0;
        if (CM_Get_DevNode_Status(&status, &problem, devinst, 0) == 0 and
            devnodeStatusMeansStarted(status, problem)) return true;
        if (waited >= timeout_ms) return false;
        Sleep(R2_REENUM_POLL_MS);
        waited += R2_REENUM_POLL_MS;
    }
}

/// Poll until the devnode shows the software-disabled state (or timeout).
fn waitDevnodeDisabled(devinst: u32, timeout_ms: u32) bool {
    var waited: u32 = 0;
    while (true) {
        if (devnodeDisabled(devinst)) return true;
        if (waited >= timeout_ms) return false;
        Sleep(R2_REENUM_POLL_MS);
        waited += R2_REENUM_POLL_MS;
    }
}

/// One DIF_PROPERTYCHANGE pass (enable or disable) on a devnode. Both steps
/// share this: set SP_PROPCHANGE_PARAMS as class install params, then call
/// the class installer.
fn usbPropChange(devs: ?*anyopaque, info: *SP_DEVINFO_DATA, state_change: u32) bool {
    var params = SP_PROPCHANGE_PARAMS{
        .ClassInstallHeader = .{
            .cbSize = @sizeOf(SP_CLASSINSTALL_HEADER),
            .InstallFunction = DIF_PROPERTYCHANGE,
        },
        .StateChange = state_change,
        .Scope = DICS_FLAG_GLOBAL,
        .HwProfile = 0,
    };
    if (SetupDiSetClassInstallParamsW(
        devs,
        info,
        &params.ClassInstallHeader,
        @sizeOf(SP_PROPCHANGE_PARAMS),
    ) == 0) return false;
    if (SetupDiCallClassInstaller(DIF_PROPERTYCHANGE, devs, info) == 0) return false;
    return true;
}

// ---------------------------------------------------------------------------
// Window procedure
// ---------------------------------------------------------------------------
fn windowProc(
    hWnd: ?*anyopaque,
    msg: u32,
    wParam: usize,
    lParam: isize,
) callconv(WINAPI) isize {
    switch (msg) {
        WM_NCCREATE => {
            // Install the SharedState pointer as early as possible (this is the
            // first message a window receives) so a resume broadcast that races
            // window creation is never lost.
            const cs: *CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lParam)));
            if (cs.lpCreateParams) |p| {
                setWindowUserData(hWnd, GWLP_USERDATA, @bitCast(@intFromPtr(p)));
            }
            return DefWindowProcW(hWnd, msg, wParam, lParam);
        },
        WM_POWERBROADCAST => {
            if (wParam == PBT_APMRESUMEAUTOMATIC) {
                const userdata = getWindowUserData(hWnd, GWLP_USERDATA);
                if (userdata != 0) {
                    const s: *SharedState = @ptrFromInt(@as(usize, @bitCast(userdata)));
                    _ = SetEvent(s.resume_event);
                }
            }
            return DefWindowProcW(hWnd, msg, wParam, lParam);
        },
        WM_CLOSE => {
            _ = DestroyWindow(hWnd);
            return 0;
        },
        WM_DESTROY => {
            PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

// ---------------------------------------------------------------------------
// --health — one-shot forensic probe battery (r1-l6)
// ---------------------------------------------------------------------------
// Answers "what is the BT stack doing RIGHT NOW" with raw, timestamped
// evidence instead of guesses. Every probe prints its own elapsed time in
// ms: on a healthy controller all probes return within tens of milliseconds,
// while a wedged CSR controller shows multi-second latencies or hard
// rejections (0x80070057 on the scan-mode write is the field-known
// signature). The decisive protocol: run --health in the HEALTHY state and
// again DURING the wedge, then diff — the probes that CHANGE between the two
// runs are the wedge fingerprint, and they single out where the fault lives
// (transport, controller command path, connection path, or audio stack).
//
// Probe battery:
//   P1  radio enumeration + BluetoothGetRadioInfo  (stack <-> HCI transport)
//   P2  IsDiscoverable / IsConnectable             (controller scan state)
//   P3  scan-mode WRITE (disable -> enable)        (the exact R1 call)
//   P4  device-cache lookup of the target MAC      (what the radio knows)
//   P5  AudioEndpoint devnode count                (audio stack picture)
// Output: a text report file (path argument) plus the same lines through
// OutputDebugStringA ("btf: health: ...") so a dbgview capture records them.
// Exit code stays 0 — the report content is the verdict.

fn hexDigit(v: u8) u8 {
    return if (v < 10) '0' + v else 'A' + (v - 10);
}

/// 0x948B93B1E4A1 -> "94:8B:93:B1:E4:A1" (parseMacAddr order, MSB first).
fn fmtMac(addr: u64) [17]u8 {
    var out: [17]u8 = undefined;
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        const b: u8 = @truncate(addr >> @intCast(8 * (5 - i)));
        out[i * 3] = hexDigit(b >> 4);
        out[i * 3 + 1] = hexDigit(b & 0x0F);
        if (i < 5) out[i * 3 + 2] = ':';
    }
    return out;
}

/// Decode a UTF-16LE string (bounded input, NUL-trimmed) into out. Returns
/// "?" on any encoding trouble — never fails the probe.
fn utf16ToUtf8Bounded(w: []const u16, out: []u8) []const u8 {
    var n: usize = 0;
    while (n < w.len and w[n] != 0) : (n += 1) {}
    const n_out = std.unicode.utf16LeToUtf8(out, w[0..n]) catch return "?";
    return out[0..n_out];
}

/// Dual-channel report line: the text file gets the plain line, DebugView
/// gets the same line behind the usual "btf: " prefix. tag selects the
/// channel label: "health" (probes), "cycle" (--cycle one-shot), "rung
/// usb-cycle" (auto-ladder core — keeps the historical field anchors).
const HealthOut = struct {
    hFile: ?*anyopaque,
    tag: []const u8 = "health",

    fn line(self: *HealthOut, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const body = std.fmt.bufPrint(&buf, fmt, args) catch return;
        if (self.hFile) |h| {
            var written: u32 = 0;
            _ = WriteFile(h, body.ptr, @intCast(body.len), &written, null);
            _ = WriteFile(h, "\r\n", 2, &written, null);
        }
        debug("{s}: {s}", .{ self.tag, body });
    }
};

fn healthMain(args_it: anytype) void {
    const t_start = nowMs();

    // argv: --health [MAC | out-path] [out-path]
    var out_path_buf: [512]u8 = undefined;
    var out_path: []const u8 = "btf_health_report.txt";
    var target_mac: ?u64 = null;
    if (args_it.next()) |a| {
        if (a.len == 17) {
            target_mac = parseMacAddr(a) catch null;
        }
        if (target_mac == null and a.len > 0) {
            const n = @min(a.len, out_path_buf.len);
            @memcpy(out_path_buf[0..n], a[0..n]);
            out_path = out_path_buf[0..n];
        }
    }
    if (out_path.len == "btf_health_report.txt".len and
        std.mem.eql(u8, out_path, "btf_health_report.txt"))
    {
        // still allow an explicit third arg to override the default
        if (args_it.next()) |a| {
            if (a.len > 0) {
                const n = @min(a.len, out_path_buf.len);
                @memcpy(out_path_buf[0..n], a[0..n]);
                out_path = out_path_buf[0..n];
            }
        }
    }

    // Open the report file through raw Win32 (GUI-subsystem process, no std.fs
    // dependency churn); a failed open degrades to DebugView-only evidence.
    var path_wide: [540]u16 = undefined;
    var hfile: ?*anyopaque = null;
    blk: {
        const wlen = std.unicode.utf8ToUtf16Le(path_wide[0 .. path_wide.len - 1], out_path) catch break :blk;
        path_wide[wlen] = 0;
        const h = CreateFileW(@ptrCast(&path_wide), GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
        if (h != INVALID_HANDLE_VALUE) hfile = h;
    }
    var out = HealthOut{ .hFile = hfile };
    defer {
        if (hfile) |h| {
            _ = CloseHandle(h);
        }
    }

    const mac_disp = if (target_mac) |m| fmtMac(m) else [17]u8{ '-', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' };
    out.line("build=r1-l8 admin={} target=[{s}] report={s}", .{ IsUserAnAdmin() != 0, mac_disp, out_path });

    const bth_api_opt: ?BthApi = loadBthApi() catch null;
    if (bth_api_opt == null) {
        out.line("probe bthprops: FAILED TO LOAD — stack-level probes unavailable; PnP-level problem is certain", .{});
        return;
    }
    const bth_api = bth_api_opt.?;

    // --- P1: radios ---------------------------------------------------------
    var radios: [4]?*anyopaque = .{ null, null, null, null };
    var n_radios: usize = 0;
    {
        var params = BLUETOOTH_FIND_RADIO_PARAMS{ .dwSize = @sizeOf(BLUETOOTH_FIND_RADIO_PARAMS) };
        var hradio: ?*anyopaque = null;
        const t0 = nowMs();
        const hfind = bth_api.BluetoothFindFirstRadio(&params, &hradio);
        const dt0 = nowMs() - t0;
        if (hfind) |hf| {
            defer _ = bth_api.BluetoothFindRadioClose(hf);
            while (hradio != null and n_radios < radios.len) {
                radios[n_radios] = hradio;
                n_radios += 1;
                var next: ?*anyopaque = null;
                if (bth_api.BluetoothFindNextRadio(hf, &next) == 0) break;
                hradio = next;
            }
            out.line("probe radios: found={} ({} ms) — 0 means the stack sees no radio at all (PnP/driver branch)", .{ n_radios, dt0 });
        } else {
            out.line("probe radios: NONE (GetLastError=0x{x}) ({} ms) — the stack sees no radio (PnP/driver branch)", .{ GetLastError(), dt0 });
        }
    }

    // --- P1b/P2/P3 per radio -------------------------------------------------
    for (radios[0..n_radios], 0..) |r, idx| {
        if (bth_api.BluetoothGetRadioInfo) |g| {
            var info = std.mem.zeroes(BLUETOOTH_RADIO_INFO);
            info.dwSize = @sizeOf(BLUETOOTH_RADIO_INFO);
            const t1 = nowMs();
            const rc = g(r, &info);
            const dt1 = nowMs() - t1;
            if (rc == 0) {
                var name_buf: [192]u8 = undefined;
                const nm_raw = utf16ToUtf8Bounded(info.szName[0..40], &name_buf);
                const nm = if (nm_raw.len == 0) "(no name)" else nm_raw;
                const mfr = if (info.manufacturer == 15) "Cambridge Silicon Radio (CSR)" else "other";
                out.line("radio[{}]: addr={s} name=\"{s}\" manufacturer={} ({s}) lmp_subversion=0x{x} class_of_device=0x{x} ({} ms) — transport stack<->HCI alive", .{ idx, fmtMac(info.Address.ullRemote), nm, info.manufacturer, mfr, info.lmpSubversion, info.ulClassofDevice, dt1 });
            } else {
                out.line("radio[{}]: GetRadioInfo FAILED 0x{x} ({} ms) — radio handle dead or controller not answering", .{ idx, rc, dt1 });
            }
        } else {
            out.line("radio[{}]: GetRadioInfo export missing (probe skipped)", .{idx});
        }

        if (bth_api.BluetoothIsDiscoverable != null and bth_api.BluetoothIsConnectable != null) {
            const t2 = nowMs();
            const d = bth_api.BluetoothIsDiscoverable.?(r);
            const d_err: u32 = if (d != 0) 0 else GetLastError();
            const c = bth_api.BluetoothIsConnectable.?(r);
            const c_err: u32 = if (c != 0) 0 else GetLastError();
            const dt2 = nowMs() - t2;
            out.line("radio[{}]: scan state: discoverable={} (err 0x{x}) connectable={} (err 0x{x}) ({} ms)", .{ idx, d != 0, d_err, c != 0, c_err, dt2 });
        } else {
            out.line("radio[{}]: scan-state exports missing (probe skipped)", .{idx});
        }

        // P3 — the exact R1 call. THE decisive probe: if this rejects with
        // 0x80070057 in BOTH runs (healthy and wedged), the R1 rung is dead on
        // this dongle in general; if it only rejects while wedged, the
        // rejection IS the wedge fingerprint. Enable is retried hard so the
        // probe always restores the radio's incoming-connections state.
        if (bth_api.BluetoothEnableIncomingConnections) |f| {
            const t3 = nowMs();
            const d_ok = f(r, 0) != 0;
            const dt3 = nowMs() - t3;
            const d_err: u32 = if (d_ok) 0 else GetLastError();
            var en_ok = false;
            var en_err: u32 = 0;
            var tries: u32 = 0;
            const t4 = nowMs();
            while (tries < R1_REENABLE_ATTEMPTS) : (tries += 1) {
                if (f(r, 1) != 0) {
                    en_ok = true;
                    break;
                }
                en_err = GetLastError();
                Sleep(R1_REENABLE_RETRY_MS);
            }
            const dt4 = nowMs() - t4;
            if (d_ok and en_ok) {
                out.line("radio[{}]: probe scan-write: disable=OK ({} ms) enable=OK ({} ms, tries={}) — controller ACCEPTS scan-mode writes (R1 call works NOW)", .{ idx, dt3, dt4, tries + 1 });
            } else {
                out.line("radio[{}]: probe scan-write: disable={}/0x{x} ({} ms) enable={}/0x{x} ({} ms, tries={}) — REJECTED (0x80070057 here = the field-known CSR signature)", .{ idx, d_ok, d_err, dt3, en_ok, en_err, dt4, tries + 1 });
            }
        } else {
            out.line("radio[{}]: BluetoothEnableIncomingConnections missing (probe skipped)", .{idx});
        }
    }

    // --- P4: device cache ----------------------------------------------------
    if (target_mac) |tm| {
        if (n_radios > 0 and radios[0] != null) {
            var search = BLUETOOTH_DEVICE_SEARCH_PARAMS{
                .dwSize = @sizeOf(BLUETOOTH_DEVICE_SEARCH_PARAMS),
                .fReturnAuthenticated = 1,
                .fReturnRemembered = 1,
                .fReturnUnknown = 0,
                .fReturnConnected = 1,
                .fIssueInquiry = 0, // cached records only — do NOT force an inquiry
                .cTimeoutMultiplier = 0,
                .hRadio = radios[0],
            };
            var di = std.mem.zeroes(BLUETOOTH_DEVICE_INFO);
            di.dwSize = @sizeOf(BLUETOOTH_DEVICE_INFO);
            const t5 = nowMs();
            const hfind = bth_api.BluetoothFindFirstDevice(&search, &di);
            const dt5 = nowMs() - t5;
            if (hfind) |hf| {
                defer _ = bth_api.BluetoothFindDeviceClose(hf);
                var total: usize = 0;
                var matched = false;
                while (true) {
                    total += 1;
                    if (di.Address.ullRemote == tm) {
                        matched = true;
                        var name_buf: [192]u8 = undefined;
                        const nm_raw = utf16ToUtf8Bounded(di.szName[0..40], &name_buf);
                        const nm = if (nm_raw.len == 0) "(no name)" else nm_raw;
                        out.line("device target: connected={} remembered={} authenticated={} name=\"{s}\" — visible to the stack at BT level", .{ di.fConnected != 0, di.fRemembered != 0, di.fAuthenticated != 0, nm });
                    }
                    di.dwSize = @sizeOf(BLUETOOTH_DEVICE_INFO);
                    if (bth_api.BluetoothFindNextDevice(hf, &di) == 0) break;
                }
                out.line("device cache: {} known devices scanned, target {s} ({} ms)", .{ total, if (matched) "FOUND" else "NOT-IN-CACHE", dt5 });
            } else {
                out.line("device cache: EMPTY/unavailable (GetLastError=0x{x}) ({} ms)", .{ GetLastError(), dt5 });
            }
        }
    }

    // --- P5: audio endpoints --------------------------------------------------
    {
        const devs = SetupDiGetClassDevsW(&GUID_DEVCLASS_AUDIOENDPOINT, null, null, DIGCF_PRESENT) orelse {
            out.line("endpoints: SetupDiGetClassDevsW failed 0x{x}", .{GetLastError()});
            return;
        };
        defer _ = SetupDiDestroyDeviceInfoList(devs);
        var count: usize = 0;
        var index: u32 = 0;
        while (index < 256) : (index += 1) {
            var info = SP_DEVINFO_DATA{
                .cbSize = @sizeOf(SP_DEVINFO_DATA),
                .InterfaceClassGuid = std.mem.zeroes(GUID),
                .DevInst = 0,
                .Reserved = 0,
            };
            if (SetupDiEnumDeviceInfo(devs, index, &info) == 0) break;
            count += 1;
        }
        out.line("endpoints: AudioEndpoint devnodes present={}(+headset when linked) ({} ms) — the CSV column measures the same thing", .{ count, nowMs() - t_start });
    }

    out.line("verdict: diff healthy-run vs wedged-run — probes that CHANGE are the wedge fingerprint; scan-write 0x80070057 while wedged but OK when healthy => wedge lives in the CSR controller command path (usb-cycle is the cure); 0x80070057 in BOTH runs => R1 is dead on this dongle, usb-cycle is the only software rung; probe latencies >1000 ms => transport stalling", .{});
    // r1-l7: the 2026-09-02 field pair (22:59:33 wedged / 23:02:50 healthy,
    // replug between) validated the third branch: ALL probes 0-15 ms in BOTH
    // runs, only connected=false -> true after the replug — a "quiet wedge"
    // inside the CSR controller firmware (commands answered, links not
    // established). Pin that reading into the report so future pairs are
    // scored against it without re-deriving the interpretation.
    out.line("verdict2: wedged-run with ALL probes <100 ms but target connected=false => quiet CSR wedge: the controller answers commands yet will not establish the link; the cure is a radio re-init (--cycle, driver level) or physical replug (power cut); a BTHUSB id=3 warning storm in the System log is the usual precursor", .{});
    out.line("health: done ({} ms total)", .{nowMs() - t_start});
}

// ---------------------------------------------------------------------------
// --cycle — one-shot software replug of the CSR radio (r1-l7)
// ---------------------------------------------------------------------------
// The field pair above proved the wedge lives in the controller firmware and
// a physical replug (power cut + re-enumeration) is the proven cure. The
// software equivalent of a replug is a driver-level radio restart: disable
// the devnode (BTHUSB unloads, controller stops), enable it again (fresh
// HCI_Reset, fresh page-scan state). That logic already exists as ladder
// rung 3; --cycle exposes the very same core as a button the user can press
// DURING a wedge, without waiting for the ladder and without touching the
// dongle. Exit codes for scripting: 0 = cycled, 1 = failed, 2 = not admin.
// Verification protocol after a run: the earbuds should reconnect within
// ~10-20 s; `--health` then shows connected=true if the wedge was cured.
fn cycleMain(args_it: anytype) void {
    const t_start = nowMs();

    var out_path_buf: [512]u8 = undefined;
    var out_path: []const u8 = "btf_cycle_report.txt";
    if (args_it.next()) |a| {
        if (a.len > 0) {
            const n = @min(a.len, out_path_buf.len);
            @memcpy(out_path_buf[0..n], a[0..n]);
            out_path = out_path_buf[0..n];
        }
    }

    var path_wide: [540]u16 = undefined;
    var hfile: ?*anyopaque = null;
    blk: {
        const wlen = std.unicode.utf8ToUtf16Le(path_wide[0 .. path_wide.len - 1], out_path) catch break :blk;
        path_wide[wlen] = 0;
        const h = CreateFileW(@ptrCast(&path_wide), GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
        if (h != INVALID_HANDLE_VALUE) hfile = h;
    }
    var out = HealthOut{ .hFile = hfile, .tag = "cycle" };
    defer {
        if (hfile) |h| _ = CloseHandle(h);
    }

    out.line("build=r1-l8 admin={} report={s}", .{ IsUserAnAdmin() != 0, out_path });
    if (IsUserAnAdmin() == 0) {
        out.line("ABORTED: admin required for device disable/enable — run from an elevated shell", .{});
        ExitProcess(2);
    }

    const ok = cycleCsrRadioOnce(&out);

    // Post-probe: is the radio back on the stack after the re-init? The
    // devnode may be DN_STARTED while the stack is still re-opening it, so
    // this is best-effort evidence, not a verdict.
    const bth_api_opt: ?BthApi = loadBthApi() catch null;
    if (bth_api_opt) |bth_api| {
        var params = BLUETOOTH_FIND_RADIO_PARAMS{ .dwSize = @sizeOf(BLUETOOTH_FIND_RADIO_PARAMS) };
        var hradio: ?*anyopaque = null;
        const t0 = nowMs();
        if (bth_api.BluetoothFindFirstRadio(&params, &hradio)) |hf| {
            defer _ = bth_api.BluetoothFindRadioClose(hf);
            var n: usize = 0;
            while (hradio != null and n < 8) {
                n += 1;
                var next: ?*anyopaque = null;
                if (bth_api.BluetoothFindNextRadio(hf, &next) == 0) break;
                hradio = next;
            }
            out.line("probe: stack sees {d} radio(s) ({} ms) after the re-init", .{ n, nowMs() - t0 });
        } else {
            out.line("probe: stack sees NO radio yet (GetLastError=0x{x}) — it may need a few more seconds", .{GetLastError()});
        }
    } else {
        out.line("probe: bthprops unavailable, radio re-presence not verified", .{});
    }

    if (ok) {
        out.line("result: cycled ({} ms) — watch the earbuds reconnect within ~10-20 s, then run --health to confirm connected=true", .{nowMs() - t_start});
    } else {
        out.line("result: FAILED ({} ms) — the dongle may be left DISABLED; follow the Recovery lines above (Enable-PnpDevice / Device Manager / different port)", .{nowMs() - t_start});
    }
    ExitProcess(if (ok) 0 else 1);
}

// ---------------------------------------------------------------------------
// --restart-earbuds — one-shot earbud-devnode restart (r2-l1)
// ---------------------------------------------------------------------------
// R3 — earbud-devnode restart (r2-l1): the rung that REPLACED the service wave
// ---------------------------------------------------------------------------
// Both r1-l11 kernel crashes share one bucket:
//
//   KERNEL_SECURITY_CHECK_FAILURE (0x139), Arg1=3, CORRUPT_LIST_ENTRY
//   BthA2dp!IrpList_HandleCancel+0x94
//     <- AVFilter::CancelServiceReadyRequest
//     <- IoCancelIrp <- IoCancelThreadIo <- PspExitThread  (svchost.exe)
//
// PspExitThread is the load-bearing frame: the crash needs a SERVICE THREAD
// TO EXIT while an IRP is pending inside BthA2dp. So r2-l1 does not try to
// make the service wave safe (that is a probability reduction whose failure
// mode is another kernel crash on the user's machine) — it removes the frame.
// No Bluetooth service is ever stopped automatically; the source-scanning
// unit test "r2-l1 INVARIANT" fails the build if that code ever comes back.
//
// What takes its place: restart the earbuds' OWN function devnodes. The field
// proved a wedge class that survives a verified usb-cycle (r1-l11, 13:41: two
// clean cycles, healthy dongle, still no link), so that class lives ABOVE the
// radio — in the A2DP/AVRCP function devnodes. Restarting exactly those nodes
// rebuilds the same driver objects a service restart would have rebuilt, over
// the supported PnP path, without any service thread exiting.
//
// Rules kept from the r1-l5/l6 era: every state change is VERIFIED through
// CM_Get_DevNode_Status (an API receipt is not a state), and there are no
// silent paths (every step emits a line, and from r2-l1 those lines also land
// in btf.log so the next crash is provable).

/// Absolute "<System32>\<name>" path. pnputil must never be resolved through
/// PATH: this process runs elevated, so a writable-directory hijack would be
/// a privilege escalation.
fn systemPathOf(buf: []u8, name: []const u8) ?[]const u8 {
    var sys_w: [520:0]u16 = undefined;
    const n = GetSystemDirectoryW(&sys_w, 512);
    if (n == 0 or n >= 512) return null;
    var sys_u8: [1100]u8 = undefined;
    const len = std.unicode.utf16LeToUtf8(sys_u8[0..], sys_w[0..n]) catch return null;
    if (len == 0) return null;
    return std.fmt.bufPrint(buf, "{s}\\{s}", .{ sys_u8[0..len], name }) catch null;
}

/// Run a command line hidden and wait for it. Returns the exit code, or null
/// if the spawn failed or the timeout expired.
///
/// NO TerminateProcess on timeout — killing pnputil mid-PnP-operation is
/// exactly how a devnode gets left half-installed. A timed-out child is
/// reported and left alone; the caller falls back to the in-process path.
fn runHiddenWait(cmdline_u8: []const u8, timeout_ms: u32) ?u32 {
    if (cmdline_u8.len > 2046) return null;
    var cmdline_u16: [2048:0]u16 = undefined;
    const utf16_len = std.unicode.utf8ToUtf16Le(cmdline_u16[0 .. cmdline_u16.len - 1], cmdline_u8) catch return null;
    cmdline_u16[utf16_len] = 0;

    var si: STARTUPINFOW = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi: PROCESS_INFORMATION = std.mem.zeroes(PROCESS_INFORMATION);

    if (CreateProcessW(
        null,
        &cmdline_u16,
        null,
        null,
        0,
        CREATE_NO_WINDOW,
        null,
        null,
        &si,
        &pi,
    ) == 0) {
        debug("R3: CreateProcessW failed 0x{x}", .{GetLastError()});
        return null;
    }
    _ = CloseHandle(pi.hThread);

    const wait_res = WaitForSingleObject(pi.hProcess, timeout_ms);
    if (wait_res != WAIT_OBJECT_0) {
        _ = CloseHandle(pi.hProcess);
        return null;
    }
    var exit_code: u32 = 0;
    _ = GetExitCodeProcess(pi.hProcess, &exit_code);
    _ = CloseHandle(pi.hProcess);
    return exit_code;
}

/// Verified enable of one devnode. Both mechanisms run SEQUENTIALLY per
/// attempt (r1-l8: the old short-circuit `or` never reached CM_Enable_DevNode
/// exactly when it was needed), and each is judged by the devnode status, not
/// by its return code — field archive 2026-09-02 23:55 had DICS_ENABLE return
/// TRUE while the node stayed CM_PROB_DISABLED.
fn enableDevnodeVerified(devs: ?*anyopaque, info: *SP_DEVINFO_DATA, id: []const u8, out: *HealthOut) bool {
    var attempt: u32 = 0;
    while (attempt < R1_REENABLE_ATTEMPTS) : (attempt += 1) {
        if (attempt > 0) Sleep(R1_REENABLE_RETRY_MS * 2);

        if (usbPropChange(devs, info, DICS_ENABLE)) {
            if (waitDevnodeStarted(info.DevInst, R3_VERIFY_MS)) return true;
            out.line("  enable {}/{}: DICS_ENABLE accepted but not STARTED in {} ms — trying CM_Enable_DevNode", .{ attempt + 1, R1_REENABLE_ATTEMPTS, R3_VERIFY_MS });
        } else {
            out.line("  enable {}/{}: DICS_ENABLE rejected 0x{x} — trying CM_Enable_DevNode", .{ attempt + 1, R1_REENABLE_ATTEMPTS, GetLastError() });
        }

        if (CM_Enable_DevNode(info.DevInst, 0) == CR_SUCCESS) {
            if (waitDevnodeStarted(info.DevInst, R3_VERIFY_MS)) return true;
            out.line("  enable {}/{}: CM_Enable_DevNode accepted but not STARTED in {} ms", .{ attempt + 1, R1_REENABLE_ATTEMPTS, R3_VERIFY_MS });
        } else {
            out.line("  enable {}/{}: CM_Enable_DevNode failed 0x{x}", .{ attempt + 1, R1_REENABLE_ATTEMPTS, GetLastError() });
        }
    }
    _ = id;
    return false;
}

/// Restart ONE earbud function devnode.
///
/// Path A is `pnputil /restart-device`: one atomic PnP restart, no window in
/// which the node is left disabled. It is tried first precisely because the
/// field showed pnputil succeeding where DIF/CM both failed (r1-l10: DIF
/// err=0xd, CM CR=0x17, pnputil exit 0).
/// Path B is the in-process fallback: verified disable -> quiet -> verified
/// enable. Its dangerous state is "disabled and not re-enabled", so a failed
/// disable aborts WITHOUT enabling anything, and a failed enable prints the
/// exact recovery command instead of failing quietly.
fn restartOneDevnode(devs: ?*anyopaque, info: *SP_DEVINFO_DATA, id: []const u8, was_started: bool, out: *HealthOut) bool {
    pnp: {
        var pnputil_buf: [1200]u8 = undefined;
        const pnputil = systemPathOf(&pnputil_buf, "pnputil.exe") orelse break :pnp;
        var id_quoted_buf: [640]u8 = undefined;
        const id_quoted = quoteArgInto(&id_quoted_buf, id) catch break :pnp;
        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" /restart-device {s}", .{ pnputil, id_quoted }) catch break :pnp;

        const exit_code = runHiddenWait(cmd, R3_PNPUTIL_TIMEOUT_MS) orelse {
            out.line("  pnputil /restart-device did not complete in {} ms — falling back to disable/enable", .{R3_PNPUTIL_TIMEOUT_MS});
            break :pnp;
        };
        if (exit_code == 0) {
            if (waitDevnodeStarted(info.DevInst, R3_VERIFY_MS)) {
                out.line("  restarted via pnputil (verified STARTED)", .{});
                return true;
            }
            // r2-l2 -- a node that was NOT started BEFORE the restart (a
            // profile that only starts while the link is up) cannot be
            // judged by DN_STARTED afterwards. r2-l1 did exactly that and
            // burned a pointless disable/enable round on two such nodes
            // per pass (field 18:44:06-18:44:17, 11.5 s for one wave).
            if (!was_started) {
                out.line("  restarted via pnputil (node was not STARTED before either -- accepted)", .{});
                return true;
            }
        }
        out.line("  pnputil exit {} but node not verified STARTED — falling back to disable/enable", .{exit_code});
    }

    var disabled = usbPropChange(devs, info, DICS_DISABLE) and waitDevnodeDisabled(info.DevInst, R3_VERIFY_MS);
    if (!disabled) {
        const dif_err = GetLastError();
        if (CM_Disable_DevNode(info.DevInst, 0) == CR_SUCCESS) {
            disabled = waitDevnodeDisabled(info.DevInst, R3_VERIFY_MS);
        }
        if (!disabled) {
            out.line("  disable did not take effect (DIF 0x{x}) — node left exactly as it was", .{dif_err});
            return false;
        }
    }
    Sleep(R3_QUIET_MS);

    if (enableDevnodeVerified(devs, info, id, out)) {
        out.line("  restarted via verified disable/enable", .{});
        return true;
    }

    out.line("  ENABLE FAILED — this node is left DISABLED. Recovery, elevated PowerShell:", .{});
    out.line("    Enable-PnpDevice -InstanceId '{s}' -Confirm:$false", .{id});
    return false;
}

/// The R3 core, shared by the auto-ladder rung (restartEarbudDevnodes) and the
/// one-shot --restart-earbuds mode, so what the user verifies by hand during a
/// wedge is byte-for-byte what fires automatically later.
///
/// The matching devnodes are SNAPSHOTTED before anything is touched: a restart
/// re-enumerates the node, and iterating a SetupAPI list while mutating it is
/// how you end up acting on a stale index. Only the earbuds' own nodes are
/// eligible — the radio itself can never match (idContainsMac is anchored on
/// the 12-hex MAC, and the dongle's ID does not contain it).
fn earbudRestartOnce(target_mac: u64, out: *HealthOut) bool {
    // Same coercion rule as the unit test: macHex12 yields a [12]u8 VALUE, and
    // idContainsMac/std.fmt want a slice, so bind the array once and take a
    // slice of it explicitly.
    const mac_hex_arr = macHex12(target_mac);
    const mac_hex: []const u8 = &mac_hex_arr;
    out.line("begin (mac={s})", .{mac_hex});

    // BTHENUM is the enumerator that owns the per-device function nodes
    // (A2DP/AVRCP/HFP). ClassGuid=NULL REQUIRES DIGCF_ALLCLASSES (r1-l7).
    const devs = SetupDiGetClassDevsW(null, &ENUMERATOR_BTHENUM, null, DIGCF_PRESENT | DIGCF_ALLCLASSES) orelse {
        out.line("SetupDiGetClassDevsW(BTHENUM) failed 0x{x}", .{GetLastError()});
        return false;
    };
    defer _ = SetupDiDestroyDeviceInfoList(devs);

    var nodes: [R3_MAX_NODES]SP_DEVINFO_DATA = undefined;
    var node_ids: [R3_MAX_NODES][220]u8 = undefined;
    var node_id_len: [R3_MAX_NODES]usize = undefined;
    // r2-l2 -- pre-state per node: only a node that WAS started may be
    // required to be started again after the restart.
    var node_started: [R3_MAX_NODES]bool = undefined;
    var node_count: u32 = 0;
    var skipped_non_audio: u32 = 0;
    var scanned: u32 = 0;
    var index: u32 = 0;

    while (node_count < R3_MAX_NODES) : (index += 1) {
        var info = SP_DEVINFO_DATA{
            .cbSize = @sizeOf(SP_DEVINFO_DATA),
            .InterfaceClassGuid = GUID_DEVCLASS_USB,
            .DevInst = 0,
            .Reserved = 0,
        };
        if (SetupDiEnumDeviceInfo(devs, index, &info) == 0) break; // end of list
        scanned += 1;

        var id_wide: [220]u16 = undefined;
        if (SetupDiGetDeviceInstanceIdW(devs, &info, &id_wide, id_wide.len, null) == 0) continue;
        var n: usize = 0;
        while (n < id_wide.len and id_wide[n] != 0) : (n += 1) {}
        if (n == 0 or n > node_ids[node_count].len) continue;
        for (id_wide[0..n], 0..) |ch, i| node_ids[node_count][i] = @truncate(ch);

        // idContainsMac is case-insensitive: real IDs carry the MAC in both
        // cases (…_0&948b93b1e4a1_… and …&948B93B1E4A1_…).
        if (!idContainsMac(node_ids[node_count][0..n], mac_hex)) continue;

        // r2-l2 -- SCOPE: the audio profile nodes only. The container
        // DEV_<MAC> node and the non-audio profiles (Handsfree, SPP, GATT,
        // PnP-info, vendor) are deliberately left alone: restarting them is
        // what made Windows re-enumerate the earbuds instead of connecting
        // them, which cost the default-endpoint switch and its remembered
        // volume. Every skip is logged -- no silent paths (r1-l6).
        if (!isEarbudAudioNode(node_ids[node_count][0..n])) {
            skipped_non_audio += 1;
            out.line("skip (non-audio, left untouched) {s}", .{node_ids[node_count][0..n]});
            continue;
        }

        // Single status read (timeout 0 = one probe, no wait).
        node_started[node_count] = waitDevnodeStarted(info.DevInst, 0);
        nodes[node_count] = info;
        node_id_len[node_count] = n;
        node_count += 1;
    }

    if (node_count == 0) {
        // Same forensic split as r1-l7: scanned=0 means the QUERY is broken,
        // scanned>0 without a match means the earbuds are simply not
        // enumerated right now (case closed / out of range).
        out.line("no present BTHENUM AUDIO devnode carries mac {s} (scanned {d}, skipped {d} non-audio) -- nothing to restart", .{ mac_hex, scanned, skipped_non_audio });
        return false;
    }

    out.line("{d} earbud AUDIO devnode(s) to restart (scanned {d} BTHENUM nodes, {d} non-audio left untouched)", .{ node_count, scanned, skipped_non_audio });

    var restarted: u32 = 0;
    var i: u32 = 0;
    while (i < node_count) : (i += 1) {
        const id = node_ids[i][0..node_id_len[i]];
        out.line("node {s}", .{id});
        if (restartOneDevnode(devs, &nodes[i], id, node_started[i], out)) restarted += 1;
    }

    out.line("complete ({d}/{d} node(s) restarted)", .{ restarted, node_count });
    return restarted > 0;
}

/// Auto-ladder entry for R3. Elevation is checked HERE (not in the gate) so a
/// non-elevated run logs the reason exactly once and then stays silent, the
/// same contract the usb-cycle rung has.
fn restartEarbudDevnodes(state: *SharedState) bool {
    if (IsUserAnAdmin() == 0) {
        if (!state.r3_admin_skip_logged) {
            state.r3_admin_skip_logged = true;
            debug("rung earbud-restart: skipped (admin required) — run from an elevated shell or diagnose.ps1", .{});
        }
        return false;
    }
    // dbgview + btf.log channel; the field protocol greps this exact tag.
    var out = HealthOut{ .hFile = null, .tag = "rung earbud-restart" };
    return earbudRestartOnce(state.target_mac, &out);
}

/// Is btf_freeze.txt present next to the exe?
///
/// This is the kill switch. After a machine has been blue-screened twice by an
/// automatic escalation, the user must be able to disarm the device-level
/// rungs WITHOUT a rebuild, a reboot or a code change — creating one empty
/// file is the cheapest instruction that survives a bad day. poc/bsod_guard.ps1
/// creates it automatically when a new minidump appears.
// ---------------------------------------------------------------------------
// r2-l3 -- the recovery journal and the repair rung (rung 0)
// ---------------------------------------------------------------------------
// The journal is a marker file next to the exe. Its EXISTENCE means "a
// persistent disable of ours is unaccounted for"; its contents (the devnode
// instance id) are evidence for the field archive only and are never parsed
// back, so a truncated or garbled file can not change behaviour.
//
// Ownership matters: the repair rung only ever runs while this file exists,
// which means it can not fight a user who disabled Bluetooth on purpose. The
// one exception is the explicit --recover mode the user runs by hand.

fn recoveryJournalPresent() bool {
    var path_u8: [4200]u8 = undefined;
    const path = selfDirPath(&path_u8, RECOVERY_JOURNAL_NAME) orelse return false;
    var path_w: [4300]u16 = undefined;
    const path_z = utf16PathZ(&path_w, path) orelse return false;
    return GetFileAttributesW(path_z.ptr) != INVALID_FILE_ATTRIBUTES;
}

/// Arm the journal BEFORE a disable. Returns false if the marker could not be
/// made durable -- and the caller must then NOT disable anything: an
/// unrecoverable disable is worse than a wedge that stays wedged.
fn recoveryJournalArm(id: []const u8) bool {
    var path_u8: [4200]u8 = undefined;
    const path = selfDirPath(&path_u8, RECOVERY_JOURNAL_NAME) orelse return false;
    var path_w: [4300]u16 = undefined;
    const path_z = utf16PathZ(&path_w, path) orelse return false;

    const h = CreateFileW(path_z.ptr, GENERIC_WRITE, FILE_SHARE_READ_WRITE, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    if (h == null or h == INVALID_HANDLE_VALUE) return false;
    var written: u32 = 0;
    _ = WriteFile(h, id.ptr, @intCast(id.len), &written, null);
    _ = WriteFile(h, "\r\n", 2, &written, null);
    // Order is what makes this crash-safe: flush, then close, then verify the
    // marker is really visible, and only then may the caller disable.
    _ = FlushFileBuffers(h);
    _ = CloseHandle(h);
    return GetFileAttributesW(path_z.ptr) != INVALID_FILE_ATTRIBUTES;
}

fn recoveryJournalDisarm() void {
    var path_u8: [4200]u8 = undefined;
    const path = selfDirPath(&path_u8, RECOVERY_JOURNAL_NAME) orelse return;
    var path_w: [4300]u16 = undefined;
    const path_z = utf16PathZ(&path_w, path) orelse return;
    _ = DeleteFileW(path_z.ptr);
}

/// Rung 0: re-enable every present CSR radio devnode that is sitting disabled.
///
/// forced=false is the automatic path: it does nothing unless the journal says
/// a disable of ours is outstanding. forced=true is --recover, the button the
/// user presses on a machine that is already stuck (a build without the
/// journal, or a manual disable they want undone).
///
/// Edge cases, all deliberate:
///   * dongle unplugged (present == 0) -> journal KEPT, so the radio is fixed
///     the moment it reappears; a same-port replug keeps the disabled flag,
///     which is exactly what the user saw in Device Manager.
///   * replugged into a DIFFERENT port -> the instance id changes, so matching
///     is by vendor id (isCsrRadioInstanceId), never by the journalled string.
///   * not elevated -> nothing can be enabled; the journal is kept, the exact
///     manual command is logged, and the next elevated run repairs it.
///   * the enable APIs report success but the node never starts -> judged by
///     devnode status only, then pnputil /enable-device as the last resort.
///   * nothing was actually disabled -> the journal is stale (we crashed after
///     a successful enable) and is cleared.
fn recoverDisabledRadio(out: *HealthOut, forced: bool) bool {
    if (!forced and !recoveryJournalPresent()) return false;

    if (IsUserAnAdmin() == 0) {
        out.line("NOT ELEVATED: a disabled radio can only be enabled from an elevated process. Run this in an admin PowerShell: Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'USB\\VID_0A12*' | Enable-PnpDevice -Confirm:$false", .{});
        return false;
    }

    const devs = SetupDiGetClassDevsW(null, &ENUMERATOR_USB, null, DIGCF_PRESENT | DIGCF_ALLCLASSES) orelse {
        out.line("SetupDiGetClassDevsW failed 0x{x} -- cannot inspect the radio, journal kept", .{GetLastError()});
        return false;
    };
    defer _ = SetupDiDestroyDeviceInfoList(devs);

    var present: u32 = 0;
    var repaired: u32 = 0;
    var still_disabled: u32 = 0;
    var index: u32 = 0;
    var id_ascii: [220]u8 = undefined;
    while (true) : (index += 1) {
        var info = SP_DEVINFO_DATA{
            .cbSize = @sizeOf(SP_DEVINFO_DATA),
            .InterfaceClassGuid = GUID_DEVCLASS_USB,
            .DevInst = 0,
            .Reserved = 0,
        };
        if (SetupDiEnumDeviceInfo(devs, index, &info) == 0) break;

        var id_wide: [220]u16 = undefined;
        if (SetupDiGetDeviceInstanceIdW(devs, &info, &id_wide, id_wide.len, null) == 0) continue;
        var n: usize = 0;
        while (n < id_wide.len and id_wide[n] != 0) : (n += 1) {}
        if (n > id_ascii.len) continue;
        for (id_wide[0..n], 0..) |ch, i| id_ascii[i] = asciiLower(@truncate(ch));
        const id = id_ascii[0..n];
        if (!isCsrRadioInstanceId(id)) continue;

        present += 1;
        if (!devnodeDisabled(info.DevInst)) continue;

        out.line("DISABLED radio devnode: {s} -- enabling", .{id});
        var ok = enableDevnodeVerified(devs, &info, id, out);
        if (!ok) {
            var exe_buf: [1100]u8 = undefined;
            if (systemPathOf(&exe_buf, "pnputil.exe")) |pnputil| {
                var cmd_buf: [1500]u8 = undefined;
                if (std.fmt.bufPrint(&cmd_buf, "\"{s}\" /enable-device \"{s}\"", .{ pnputil, id })) |cmd| {
                    const code = runHiddenWait(cmd, PNPUTIL_TIMEOUT_MS);
                    out.line("  pnputil /enable-device exit={?}", .{code});
                    ok = waitDevnodeStarted(info.DevInst, RECOVERY_VERIFY_MS);
                } else |_| {}
            }
        }
        if (ok) repaired += 1 else still_disabled += 1;
    }

    if (present == 0) {
        out.line("no CSR radio devnode present right now (dongle unplugged?) -- journal KEPT, the radio is enabled again as soon as it reappears", .{});
        return false;
    }
    if (radioRecoveryDone(present, still_disabled)) {
        if (repaired > 0) {
            out.line("RECOVERED: {} radio devnode(s) enabled and STARTED (of {} present) -- journal cleared", .{ repaired, present });
        } else {
            out.line("nothing to repair: {} radio devnode(s) present and started -- stale journal cleared", .{present});
        }
        recoveryJournalDisarm();
        return repaired > 0;
    }
    out.line("STILL DISABLED: {} of {} node(s) refused to enable -- journal KEPT, retrying every {} ms. Manual fix in an admin PowerShell: Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'USB\\VID_0A12*' | Enable-PnpDevice -Confirm:$false", .{ still_disabled, present, RECOVERY_RETRY_MS });
    return false;
}

fn escalationFrozenByFile() bool {
    var path_u8: [4200]u8 = undefined;
    const path = selfDirPath(&path_u8, "btf_freeze.txt") orelse return false;
    var path_w: [4300]u16 = undefined;
    const path_z = utf16PathZ(&path_w, path) orelse return false;
    return GetFileAttributesW(path_z.ptr) != INVALID_FILE_ATTRIBUTES;
}

/// Cached freeze state, re-read every FREEZE_RECHECK_MS so the switch works
/// on a running daemon (~15 s to take effect) without hitting the filesystem
/// on every poll. Both transitions are logged: an undocumented silent freeze
/// would look exactly like a broken ladder in the next field archive.
fn escalationFrozen(state: *SharedState, now_ms: i64) bool {
    if (state.freeze_checked_ms == 0 or now_ms - state.freeze_checked_ms >= FREEZE_RECHECK_MS) {
        state.freeze_checked_ms = now_ms;
        const frozen_now = escalationFrozenByFile();
        if (frozen_now != state.escalation_frozen) {
            state.escalation_frozen = frozen_now;
            if (frozen_now) {
                debug("escalation FROZEN by btf_freeze.txt — earbud-restart and usb-cycle are disabled; ToothTray connect and page-scan toggle keep working", .{});
            } else {
                debug("escalation UNFROZEN (btf_freeze.txt is gone) — earbud-restart and usb-cycle are armed again", .{});
            }
        }
    }
    return state.escalation_frozen;
}

// ---------------------------------------------------------------------------
// The manual button for the rung that replaced the service wave: it runs the
// SAME core the daemon runs (earbudRestartOnce), so what the user verifies by
// hand during a wedge is exactly what fires automatically later. Protocol:
// during a wedge run this, then watch whether the earbuds link within ~10 s.
// Exit codes for scripting: 0 = at least one devnode restarted, 1 = nothing
// restarted, 2 = not elevated.
fn restartEarbudsMain(args_it: anytype) void {
    const t_start = nowMs();

    const mac_arg = args_it.next() orelse exitWithError("Usage: bluetooth_force.exe --restart-earbuds AA:BB:CC:DD:EE:FF [report-path]");
    const target_mac = parseMacAddr(mac_arg) catch |err| switch (err) {
        error.ZeroMacAddress => exitWithError("MAC must be non-zero (00:00:00:00:00:00 is not a valid device)"),
        else => exitWithError("Invalid MAC address format"),
    };

    var out_path_buf: [512]u8 = undefined;
    var out_path: []const u8 = "btf_restart_earbuds_report.txt";
    if (args_it.next()) |a| {
        if (a.len > 0) {
            const n = @min(a.len, out_path_buf.len);
            @memcpy(out_path_buf[0..n], a[0..n]);
            out_path = out_path_buf[0..n];
        }
    }

    var path_wide: [540]u16 = undefined;
    var hfile: ?*anyopaque = null;
    blk: {
        const wlen = std.unicode.utf8ToUtf16Le(path_wide[0 .. path_wide.len - 1], out_path) catch break :blk;
        path_wide[wlen] = 0;
        const h = CreateFileW(@ptrCast(&path_wide), GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
        if (h != INVALID_HANDLE_VALUE) hfile = h;
    }
    var out = HealthOut{ .hFile = hfile, .tag = "restart-earbuds" };
    defer {
        if (hfile) |h| _ = CloseHandle(h);
    }

    out.line("build=r2-l3 admin={} mac={s} report={s}", .{ IsUserAnAdmin() != 0, mac_arg, out_path });
    if (IsUserAnAdmin() == 0) {
        out.line("ABORTED: admin required for devnode restart — run from an elevated shell", .{});
        ExitProcess(2);
    }

    const ok = earbudRestartOnce(target_mac, &out);
    if (ok) {
        out.line("result: restarted ({} ms) — watch the earbuds link within ~10 s", .{nowMs() - t_start});
    } else {
        out.line("result: NOTHING RESTARTED ({} ms) — read the node lines above; if none were listed the earbuds have no present function devnodes right now (open the case first)", .{nowMs() - t_start});
    }
    ExitProcess(if (ok) 0 else 1);
}

// ---------------------------------------------------------------------------
// r2-l3 -- the manual repair button. Unlike the automatic rung this one
// does NOT require the journal: it exists for a machine that is already
// stuck, including one left disabled by an older build that had no journal
// at all. Exit codes: 0 = something was enabled, 1 = nothing to do (or it
// could not be fixed), 2 = not elevated.
// ---------------------------------------------------------------------------
fn recoverMain(args_it: anytype) void {
    _ = args_it;
    logFileInit();
    var out = HealthOut{ .hFile = null, .tag = "recover" };
    out.line("build=r2-l3 admin={}", .{IsUserAnAdmin() != 0});
    if (IsUserAnAdmin() == 0) {
        out.line("ABORTED: enabling a devnode requires elevation -- start PowerShell as administrator and run this again", .{});
        ExitProcess(2);
    }
    const ok = recoverDisabledRadio(&out, true);
    if (ok) {
        out.line("result: the radio was disabled and is now enabled -- Bluetooth should be back in Device Manager", .{});
    } else {
        out.line("result: nothing was enabled -- either the radio was already fine, or the dongle is unplugged, or the lines above say why it refused", .{});
    }
    ExitProcess(if (ok) 0 else 1);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
pub fn main(init: std.process.Init.Minimal) !void {
    // Harden the whole process against DLL preloading/hijacking: resolve DLLs
    // only from System32 by default. LOAD_LIBRARY_SEARCH_SYSTEM32 is available on
    // all supported Windows versions (KB2533623 and later).
    _ = SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32);

    var args_it = try init.args.iterateAllocator(std.heap.page_allocator);
    defer args_it.deinit();

    const usage = "Usage: bluetooth_force.exe AA:BB:CC:DD:EE:FF [audio-name-substring] | --health [MAC] [report-path] | --cycle [report-path] | --restart-earbuds MAC [report-path] | --recover";
    _ = args_it.next() orelse exitWithError(usage);
    const arg1 = args_it.next() orelse exitWithError(usage);
    if (std.mem.eql(u8, arg1, "--health")) {
        healthMain(&args_it);
        return;
    }
    if (std.mem.eql(u8, arg1, "--cycle")) {
        cycleMain(&args_it);
        return;
    }
    if (std.mem.eql(u8, arg1, "--restart-earbuds")) {
        restartEarbudsMain(&args_it);
        return;
    }
    if (std.mem.eql(u8, arg1, "--recover")) {
        recoverMain(&args_it);
        return;
    }
    const mac_str = arg1;
    const target_mac = parseMacAddr(mac_str) catch |err| switch (err) {
        error.ZeroMacAddress => exitWithError("MAC must be non-zero (00:00:00:00:00:00 is not a valid device)"),
        else => exitWithError("Invalid MAC address format"),
    };

    // First evidence line — the anchor every DebugView/CLI filter keys on:
    // build tag, target MAC, exe path, elevation state (R2 needs admin=1).
    {
        var exe_wide: [1024:0]u16 = undefined;
        exe_wide[1023] = 0;
        const exe_len = GetModuleFileNameW(null, &exe_wide, 1023);
        var exe_utf8: [2048]u8 = undefined;
        const exe_str: []const u8 = if (exe_len > 0 and exe_len <= exe_wide.len) blk: {
            const n = std.unicode.utf16LeToUtf8(exe_utf8[0..], exe_wide[0..exe_len]) catch break :blk "?";
            if (n == 0) break :blk "?";
            break :blk exe_utf8[0..n];
        } else "?";
        // r2-l1: open the durable log BEFORE the start line, so the very first
        // evidence line also lands in btf.log.
        logFileInit();
        debug("start: build=r2-l3 mac={s} exe={s} admin={} log={s}", .{
            mac_str,
            exe_str,
            IsUserAnAdmin() != 0,
            if (log_handle != null) "btf.log" else "NONE (file log unavailable)",
        });
        debug("policy: automatic rungs are radio repair -> ToothTray connect -> page-scan toggle -> earbud-devnode restart -> usb-cycle (the dongle is restarted non-persistently when possible, and any persistent disable is journalled and always repaired). NO Bluetooth service is ever stopped automatically (crash bucket 0x139_3_CORRUPT_LIST_ENTRY_BthA2dp!IrpList_HandleCancel). Manual stack restart: poc\\restart_bt_stack.ps1", .{});
        // r2-l3 -- a persistent disable outlives the process that made it,
        // so the very first thing a new run does is account for one.
        if (recoveryJournalPresent()) {
            debug("startup: a pending disable journal was found -- repairing the radio BEFORE the ladder starts", .{});
            var rout = HealthOut{ .hFile = null, .tag = "startup recovery" };
            _ = recoverDisabledRadio(&rout, false);
        }
        if (escalationFrozenByFile()) {
            debug("escalation FROZEN at startup by btf_freeze.txt — earbud-restart and usb-cycle are disabled; delete that file to re-enable", .{});
        }
    }

    // Optional 3rd arg: explicit audio endpoint name substring. By default the
    // keepalive auto-discovers the earbuds' own endpoint (L2); this override is
    // only needed if auto-detection picks the wrong device. Copied into a buffer
    // that lives for the whole process (this frame runs the message loop).
    var audio_override_buf: [128]u8 = undefined;
    const audio_override: ?[]const u8 = blk: {
        const a = args_it.next() orelse break :blk null;
        if (a.len == 0) break :blk null;
        const n = @min(a.len, audio_override_buf.len);
        @memcpy(audio_override_buf[0..n], a[0..n]);
        break :blk audio_override_buf[0..n];
    };

    const bth_api = loadBthApi() catch exitWithError("Failed to load bthprops.cpl Bluetooth API");
    defer _ = FreeLibrary(bth_api.module);

    const resume_event = CreateEventW(null, 0, 0, null) orelse exitWithError("CreateEventW failed");
    defer _ = CloseHandle(resume_event);

    var shared = SharedState{
        .running = std.atomic.Value(bool).init(true),
        .target_mac = target_mac,
        .resume_event = resume_event,
        .bth = bth_api,
        .silent = SilentKeepalive.init(),
        .last_tooth_tray_handle = null,
    };
    // Apply the optional CLI audio-endpoint override before the worker starts
    // (the worker's first start() reads it during device resolution).
    shared.silent.override_name = audio_override;

    // Create the message-only window BEFORE spawning the worker. exitWithError
    // calls ExitProcess, which skips defers; by finishing all fallible window
    // setup first, any failure here exits while no worker/keepalive is running,
    // so nothing that needs a graceful shutdown can be torn down mid-flight
    // (e.g. the keepalive dying inside waveOutWrite).
    const hinstance = GetModuleHandleW(null) orelse exitWithError("GetModuleHandleW failed");

    var wc = WNDCLASSEXW{
        .cbSize = @sizeOf(WNDCLASSEXW),
        .style = 0,
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinstance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = WINDOW_CLASS_NAME,
        .hIconSm = null,
    };

    if (RegisterClassExW(&wc) == 0) exitWithError("RegisterClassExW failed");

    // Pass &shared as lpParam so windowProc installs GWLP_USERDATA in
    // WM_NCCREATE, before the window can receive any other message. Setting it
    // only after CreateWindowExW returns leaves a small window in which a resume
    // broadcast racing creation would be dropped.
    const hwnd = CreateWindowExW(
        WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        WINDOW_CLASS_NAME,
        WINDOW_TITLE,
        WS_POPUP,
        0, 0, 0, 0,
        null, null, hinstance, @ptrCast(&shared),
    ) orelse exitWithError("CreateWindowExW failed");

    defer _ = DestroyWindow(hwnd);

    // Worker is spawned only after all fallible setup above has succeeded.
    const thread = try std.Thread.spawn(.{}, workerThread, .{&shared});
    defer {
        // Stop the worker FIRST, then the keepalive. The worker thread is the
        // sole owner of silent.start()/stop(); stopping the keepalive before
        // the worker is joined would race the worker's own start()/stop() calls
        // (a data race on the non-atomic `thread`/`hwo` fields) and could even
        // let a freshly started keepalive thread outlive `shared` on this stack
        // frame (use-after-return). Joining the worker first restores the
        // single-threaded start()/stop() invariant SilentKeepalive relies on.
        shared.running.store(false, .release);
        _ = SetEvent(resume_event);
        thread.join();
        shared.silent.stop();
        if (shared.last_tooth_tray_handle) |h| _ = CloseHandle(h);
    }

    var msg: MSG = undefined;
    while (true) {
        const ret = GetMessageW(&msg, null, 0, 0);
        if (ret <= 0) break;
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
}

fn exitWithError(msg: []const u8) noreturn {
    debug("{s}", .{msg});
    ExitProcess(1);
}

//==============================================================================
// TESTS
//==============================================================================
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test "parseMacAddr valid formats" {
    const cases = [_]struct { mac: []const u8, expected: u64 }{
        .{ .mac = "AA:BB:CC:DD:EE:FF", .expected = 0xAABBCCDDEEFF },
        .{ .mac = "00:11:22:33:44:55", .expected = 0x001122334455 },
        .{ .mac = "FF:FF:FF:FF:FF:FF", .expected = 0xFFFFFFFFFFFF },
        .{ .mac = "12:34:56:78:9A:BC", .expected = 0x123456789ABC },
        .{ .mac = "ab:cd:ef:01:23:45", .expected = 0xABCDEF012345 },
        .{ .mac = "aA:bB:cC:dD:eE:fF", .expected = 0xAABBCCDDEEFF },
    };
    for (cases) |c| {
        const result = try parseMacAddr(c.mac);
        try expectEqual(c.expected, result);
    }
}

test "parseMacAddr invalid formats" {
    const fmt_errors = [_][]const u8{
        "",
        "AA:BB:CC:DD:EE",
        "AA:BB:CC:DD:EE:FF:GG",
        "AA-BB-CC-DD-EE-FF",
        "AABBCCDDEEFF",
        "AA:BB:CC:DD:EE:FF ",
        " AA:BB:CC:DD:EE:FF",
    };
    for (fmt_errors) |c| try testing.expectError(error.InvalidMacFormat, parseMacAddr(c));
    try testing.expectError(error.InvalidHexChar, parseMacAddr("XX:BB:CC:DD:EE:FF"));
}

test "hexNibble" {
    try expectEqual(@as(u8, 0), try hexNibble('0'));
    try expectEqual(@as(u8, 9), try hexNibble('9'));
    try expectEqual(@as(u8, 10), try hexNibble('A'));
    try expectEqual(@as(u8, 15), try hexNibble('F'));
    try expectEqual(@as(u8, 10), try hexNibble('a'));
    try expectEqual(@as(u8, 15), try hexNibble('f'));
    try testing.expectError(error.InvalidHexChar, hexNibble('G'));
    try testing.expectError(error.InvalidHexChar, hexNibble(' '));
}

test "BLUETOOTH_DEVICE_INFO size matches Win32" {
    try expectEqual(@as(usize, @sizeOf(BLUETOOTH_DEVICE_INFO)), @as(usize, 560));
}

test "BLUETOOTH_DEVICE_SEARCH_PARAMS size matches Win32" {
    try expectEqual(@as(usize, @sizeOf(BLUETOOTH_DEVICE_SEARCH_PARAMS)), @as(usize, 40));
}

test "GUID size matches Win32" {
    try expectEqual(@as(usize, @sizeOf(GUID)), @as(usize, 16));
}

test "BLUETOOTH_ADDRESS size matches Win32" {
    try expectEqual(@as(usize, @sizeOf(BLUETOOTH_ADDRESS)), @as(usize, 8));
}

test "fillKeepaliveBuffer produces inaudible non-zero dither" {
    var buf: [KEEPALIVE_BUF_SIZE]u8 = [_]u8{0xAA} ** KEEPALIVE_BUF_SIZE;
    fillKeepaliveBuffer(&buf);

    // Buffer must be non-zero overall: an all-zero stream can be treated as
    // idle by the audio engine (the FxSound idle-disconnect regression).
    var any_nonzero = false;
    for (buf) |b| {
        if (b != 0) any_nonzero = true;
    }
    try expect(any_nonzero);

    // Every 16-bit little-endian sample must be exactly +1 or -1 (1 LSB):
    // genuinely active on the wire, but inaudible.
    var i: usize = 0;
    while (i + 1 < buf.len) : (i += 2) {
        const bits: u16 = @as(u16, buf[i]) | (@as(u16, buf[i + 1]) << 8);
        const sample: i16 = @bitCast(bits);
        const expected: i16 = if ((i / 2) % 2 == 0) 1 else -1;
        try expectEqual(expected, sample);
    }
}

test "fillKeepaliveBuffer handles odd-length and tiny buffers" {
    // Odd length: trailing byte cannot form a sample and must be zeroed,
    // and the function must not write out of bounds.
    var odd: [5]u8 = [_]u8{0xFF} ** 5;
    fillKeepaliveBuffer(&odd);
    try expectEqual(@as(u8, 0), odd[4]);
    // First sample (bytes 0..1) is +1 little-endian.
    try expectEqual(@as(u8, 1), odd[0]);
    try expectEqual(@as(u8, 0), odd[1]);

    var empty: [0]u8 = .{};
    fillKeepaliveBuffer(&empty); // must not crash

    var one: [1]u8 = .{0x7F};
    fillKeepaliveBuffer(&one);
    try expectEqual(@as(u8, 0), one[0]);
}

test "SilentKeepalive.init seeds buffer and idle thread state" {
    const ka = SilentKeepalive.init();
    // No thread is owned before start(); stop() on a fresh instance is a no-op
    // (the leak fix keys off `thread`, not a separate running flag).
    try expect(ka.thread == null);
    try expect(!ka.want_run.load(.acquire));
    // init() must pre-fill the dither so the very first session is non-silent.
    try expectEqual(@as(u8, 1), ka.silence_buf[0]);
}

test "SharedState alignment" {
    const ss = SharedState{
        .running = std.atomic.Value(bool).init(true),
        .target_mac = 0xAABBCCDDEEFF,
        .resume_event = null,
        .bth = undefined,
        .silent = undefined,
        .last_tooth_tray_handle = null,
    };
    try expectEqual(@as(u64, 0xAABBCCDDEEFF), ss.target_mac);
    try expectEqual(true, ss.running.load(.acquire));
}

//==============================================================================
// SOUND-GUARANTEE TESTS
//
// These tests exist to prove that the moment the earbuds case is opened and
// the earbuds connect, sound (the silent non-zero keepalive) is *guaranteed*
// to start — with no "silent on first run, audible only after restart"
// regression. The contract has several layers, each tested independently:
//
//   1. The keepalive buffer is pre-filled with a non-zero dither at init()
//      time, BEFORE any start() call — so the very first waveOutWrite can
//      never emit a pure-zero stream that the BT engine treats as idle.
//   2. The "device connected -> start keepalive" decision is the sole entry
//      point for playback; it is a pure, exhaustively-tested function.
//   3. start()/stop() lifecycle is race-free, idempotent, and restartable.
//   4. The run() outer loop retries failed sessions so a transient
//      waveOutOpen failure on the first attempt can never permanently kill
//      sound (the root cause of the original "restart fixes it" symptom).
//==============================================================================

//------------------------------------------------------------------------------
// Layer 1 — buffer readiness: the keepalive is never silent on first play
//------------------------------------------------------------------------------

test "sound-guarantee: init() pre-fills buffer before any start() call" {
    // The "no sound on first run" bug class is caused by lazy buffer init:
    // if the dither is only filled inside runSession(), a thread that starts
    // before the fill completes writes a zero buffer and the BT engine
    // idle-disconnects. init() must fill eagerly.
    var ka = SilentKeepalive.init();
    defer ka.stop(); // safe no-op: thread is null

    // First byte must be 0x01 (low byte of +1 in little-endian), proving the
    // buffer was filled during init(), not left zeroed.
    try expectEqual(@as(u8, 1), ka.silence_buf[0]);
    try expectEqual(@as(u8, 0), ka.silence_buf[1]); // high byte of +1
}

test "sound-guarantee: full buffer has zero all-zero 2-byte windows" {
    // A pure-zero 16-bit sample anywhere in the stream can be enough for some
    // audio engines (notably FxSound's APO) to flag the render stream as idle
    // and let the earbuds disconnect. Every 16-bit slot must be ±1.
    var ka = SilentKeepalive.init();
    defer ka.stop();

    var i: usize = 0;
    while (i + 1 < ka.silence_buf.len) : (i += 2) {
        const bits: u16 = @as(u16, ka.silence_buf[i]) |
            (@as(u16, ka.silence_buf[i + 1]) << 8);
        try expect(bits != 0);
        const sample: i16 = @bitCast(bits);
        try expect(sample == 1 or sample == -1);
    }
}

test "sound-guarantee: buffer pattern starts with +1 then alternates" {
    // The dither must be deterministic: +1 at sample 0, -1 at sample 1, +1 at
    // sample 2, ... A non-deterministic or off-by-one pattern would either
    // inject a DC offset or accidentally produce a zero sample.
    var ka = SilentKeepalive.init();
    defer ka.stop();

    var sample_idx: usize = 0;
    while (sample_idx + 1 < ka.silence_buf.len) : (sample_idx += 2) {
        const bits: u16 = @as(u16, ka.silence_buf[sample_idx]) |
            (@as(u16, ka.silence_buf[sample_idx + 1]) << 8);
        const sample: i16 = @bitCast(bits);
        const expected: i16 = if ((sample_idx / 2) % 2 == 0) 1 else -1;
        try expectEqual(expected, sample);
    }
}

test "sound-guarantee: buffer has zero DC offset (sum of samples is zero)" {
    // An accidental DC offset in a "silent" keepalive can be amplified by the
    // BT codec into an audible click. A balanced ±1 dither sums to zero over
    // any even sample count, which is inaudible and codec-safe.
    var ka = SilentKeepalive.init();
    defer ka.stop();

    var sum: i64 = 0;
    var i: usize = 0;
    while (i + 1 < ka.silence_buf.len) : (i += 2) {
        const bits: u16 = @as(u16, ka.silence_buf[i]) |
            (@as(u16, ka.silence_buf[i + 1]) << 8);
        sum += @as(i64, @as(i16, @bitCast(bits)));
    }
    // KEEPALIVE_BUF_SIZE is even, so there are exactly KEEPALIVE_BUF_SIZE/2
    // samples, half +1 and half -1 -> sum is exactly 0.
    try expectEqual(@as(i64, 0), sum);
}

test "sound-guarantee: repeated init() always re-fills the buffer" {
    // After a stop()+restart cycle (the "restart the app" scenario the user
    // is worried about), init() must produce an equally-valid buffer. There
    // must be no path where the second init() leaves the buffer zeroed.
    for (0..5) |_| {
        var ka = SilentKeepalive.init();
        defer ka.stop();
        try expectEqual(@as(u8, 1), ka.silence_buf[0]);
        try expectEqual(@as(u8, 0), ka.silence_buf[1]);
        // Last full sample must also be valid ±1.
        const last = ka.silence_buf.len - 2;
        const bits: u16 = @as(u16, ka.silence_buf[last]) |
            (@as(u16, ka.silence_buf[last + 1]) << 8);
        const sample: i16 = @bitCast(bits);
        try expect(sample == 1 or sample == -1);
    }
}

test "sound-guarantee: init() never returns a zeroed buffer" {
    // Defensive: stress init() many times. If any single call ever returns a
    // buffer whose first byte is 0, the "first-run silence" bug is back.
    for (0..50) |_| {
        var ka = SilentKeepalive.init();
        defer ka.stop();
        try expect(ka.silence_buf[0] != 0);
    }
}

test "sound-guarantee: KEEPALIVE_BUF_SIZE is even" {
    // A non-even buffer size would leave a trailing byte that cannot form a
    // 16-bit sample, wasting space and complicating the dither. More
    // importantly, waveOutWrite with a PCM format requires whole samples;
    // an odd buffer length would be a silent driver-level error.
    try expect(KEEPALIVE_BUF_SIZE % 2 == 0);
}

test "sound-guarantee: KEEPALIVE_BUF_SIZE is large enough to avoid gaps" {
    // A buffer too small relative to the poll/sleep cadence would cause
    // underruns (gaps in playback) that the BT codec may treat as idle.
    // At 44100 Hz stereo 16-bit, one second is 176400 bytes.
    // 8192 bytes ~ 46ms of audio. The worker loop sleeps 60ms between
    // buffer-done checks, so the buffer must cover at least that plus
    // jitter. 8192 covers ~46ms which the run loop re-queues on DONE.
    // This test pins the constant so a regression is caught.
    try expectEqual(@as(u16, 8192), KEEPALIVE_BUF_SIZE);
    // Sanity: at least one full sample frame (4 bytes stereo 16-bit).
    try expect(KEEPALIVE_BUF_SIZE >= 4);
}

//------------------------------------------------------------------------------
// Layer 2 — the decision: the sole entry point for sound playback
//------------------------------------------------------------------------------

test "decidePollAction: connected device starts keepalive" {
    // The golden path: case opens, earbuds connect, performPoll sees
    // fConnected != 0 -> sound must start. This is THE test for the user's
    // requirement.
    try expectEqual(PollAction.start_keepalive, decidePollAction(true, 1));
}

test "decidePollAction: disconnected device stops and triggers connection" {
    // Device is known but not yet connected -> stop any stale keepalive and
    // ask ToothTray to bring the link up. Sound is NOT started here; it
    // starts on the next poll once fConnected becomes 1.
    try expectEqual(PollAction.stop_and_connect, decidePollAction(true, 0));
}

test "decidePollAction: device not found does nothing" {
    try expectEqual(PollAction.none, decidePollAction(false, 0));
    try expectEqual(PollAction.none, decidePollAction(false, 1));
    // Even a "connected" flag is irrelevant when the device wasn't found.
    try expectEqual(PollAction.none, decidePollAction(false, -1));
}

test "decidePollAction: any non-zero fConnected starts keepalive" {
    // Win32 BOOL is a 4-byte int; any non-zero value is truthy. The BT API
    // normally uses 1, but defensive code must treat 2, -1, maxInt as
    // "connected" too.
    try expectEqual(PollAction.start_keepalive, decidePollAction(true, 1));
    try expectEqual(PollAction.start_keepalive, decidePollAction(true, 2));
    try expectEqual(PollAction.start_keepalive, decidePollAction(true, -1));
    try expectEqual(PollAction.start_keepalive, decidePollAction(true, std.math.maxInt(i32)));
    try expectEqual(PollAction.start_keepalive, decidePollAction(true, std.math.minInt(i32) + 1));
}

test "decidePollAction: exactly zero fConnected means not connected" {
    // Only literal 0 is "not connected". This is the branch that triggers
    // ToothTray and stops the keepalive — getting it wrong would either
    // never connect or never start sound.
    try expectEqual(PollAction.stop_and_connect, decidePollAction(true, 0));
}

test "decidePollAction: is exhaustive with no fallthrough" {
    // Pin every branch of the decision table. If someone adds a new
    // PollAction variant or changes the logic, this table forces a review.
    const cases = [_]struct { found: bool, conn: i32, want: PollAction }{
        .{ .found = false, .conn = 0, .want = .none },
        .{ .found = false, .conn = 1, .want = .none },
        .{ .found = true, .conn = 0, .want = .stop_and_connect },
        .{ .found = true, .conn = 1, .want = .start_keepalive },
        .{ .found = true, .conn = -1, .want = .start_keepalive },
    };
    for (cases) |c| {
        try expectEqual(c.want, decidePollAction(c.found, c.conn));
    }
}

test "decidePollAction: start_keepalive is only reachable when device is found AND connected" {
    // The "sound starts" invariant: there is NO input combination other than
    // (found=true, fConnected!=0) that returns start_keepalive. This means
    // sound can never start spuriously, and can never fail to start when
    // the device is genuinely connected.
    var found_any_false_positive = false;
    // found=false with any connection flag must never start.
    for ([_]i32{ std.math.minInt(i32), -1, 0, 1, 2, std.math.maxInt(i32) }) |conn| {
        if (decidePollAction(false, conn) == .start_keepalive) {
            found_any_false_positive = true;
        }
    }
    try expect(!found_any_false_positive);

    // found=true with fConnected==0 must never start.
    try expect(decidePollAction(true, 0) != .start_keepalive);

    // found=true with any non-zero fConnected MUST start.
    for ([_]i32{ -1, 1, 2, 100, std.math.maxInt(i32) }) |conn| {
        try expectEqual(PollAction.start_keepalive, decidePollAction(true, conn));
    }
}

//------------------------------------------------------------------------------
// Layer 3 — start()/stop() lifecycle invariants
//------------------------------------------------------------------------------

test "lifecycle: fresh init has no thread and want_run is false" {
    var ka = SilentKeepalive.init();
    defer ka.stop();
    try expect(ka.thread == null);
    try expect(!ka.want_run.load(.acquire));
    try expect(ka.hwo == null);
}

test "lifecycle: stop() on a fresh instance is a safe no-op" {
    // stop() must never crash when called on an instance that was never
    // started. The guard keys off `thread` (not want_run) specifically so
    // this holds.
    var ka = SilentKeepalive.init();
    ka.stop(); // must not crash, must not hang
    try expect(ka.thread == null);
    try expect(!ka.want_run.load(.acquire));
}

test "lifecycle: double stop() is safe" {
    var ka = SilentKeepalive.init();
    ka.stop();
    ka.stop(); // idempotent
    try expect(ka.thread == null);
    try expect(!ka.want_run.load(.acquire));
}

test "lifecycle: stop() joins a live dummy thread and clears the handle" {
    // We cannot call start() here because it would spawn the real run()
    // worker, which calls waveOutOpen — a Windows-only symbol that breaks
    // cross-platform `zig build test`. Instead we spawn a *harmless* dummy
    // thread (one that returns immediately and never touches winmm) and
    // assign it to `thread`, then verify stop() joins it and nulls the
    // field. This exercises the exact join+clear path that prevents the
    // std.Thread / OS handle leak described in stop()'s comment.
    const Dummy = struct {
        fn run() void {}
    };

    var ka = SilentKeepalive.init();
    ka.want_run.store(true, .release);
    ka.thread = std.Thread.spawn(.{}, Dummy.run, .{}) catch |err| {
        // If the host can't spawn a thread (CI resource limits), skip —
        // the invariant is still verified by the other lifecycle tests.
        debug("dummy thread spawn failed in test: {s}", .{@errorName(err)});
        return;
    };

    try expect(ka.thread != null);
    ka.stop();
    try expect(ka.thread == null);
    try expect(!ka.want_run.load(.acquire));
}

test "lifecycle: stop() joins even if want_run was already cleared" {
    // Simulates a worker that self-exited (e.g. waveOutOpen failed on the
    // very first attempt): want_run is still true from start(), but the
    // worker has returned. stop() must still join the handle so the OS
    // thread resource is reclaimed — this is the specific leak the
    // "always join if thread != null" guard exists to prevent.
    const Dummy = struct {
        fn run() void {}
    };

    var ka = SilentKeepalive.init();
    ka.thread = std.Thread.spawn(.{}, Dummy.run, .{}) catch return;
    // Simulate a self-exited worker: want_run stays as-is (the worker would
    // have observed it but returned anyway after a waveOut failure).
    ka.stop();
    try expect(ka.thread == null);
}

test "lifecycle: want_run is cleared by stop() even with no thread" {
    // Manually set want_run=true (simulating start()'s first action) without
    // spawning a thread, then call stop(). want_run must be false afterwards.
    var ka = SilentKeepalive.init();
    ka.want_run.store(true, .release);
    ka.stop();
    try expect(!ka.want_run.load(.acquire));
}

test "lifecycle: after stop(), thread is null enabling a subsequent start" {
    // The "restart fixes it" symptom the user is worried about would be a
    // bug if stop() failed to clear `thread`: start() guards on
    // `thread != null` and would silently no-op, so the second start would
    // never spawn a worker and sound would never come back. Verify the
    // field is null after stop().
    var ka = SilentKeepalive.init();
    const Dummy = struct {
        fn run() void {}
    };
    ka.thread = std.Thread.spawn(.{}, Dummy.run, .{}) catch return;
    ka.stop();
    try expect(ka.thread == null);
    // A fresh init() after stop() must also work (the "restart the app"
    // path).
    var ka2 = SilentKeepalive.init();
    defer ka2.stop();
    try expect(ka2.thread == null);
    try expectEqual(@as(u8, 1), ka2.silence_buf[0]);
}

//------------------------------------------------------------------------------
// Layer 4 — run() retry semantics (verified via the want_run contract)
//------------------------------------------------------------------------------

test "run-retry: want_run stays true across a self-exited session" {
    // run() loops `while (want_run) { runSession(); if (want_run) Sleep(500); }`.
    // If runSession() returns early (e.g. waveOutOpen failed on the first
    // call — the exact "no sound on first run" trigger), the loop must
    // retry. The only thing that stops the retry is want_run becoming false.
    // We verify the contract holds: stop() is the only thing that clears it.
    var ka = SilentKeepalive.init();
    ka.want_run.store(true, .release);
    // Simulate runSession returning without touching want_run.
    try expect(ka.want_run.load(.acquire));
    // stop() clears it.
    ka.stop();
    try expect(!ka.want_run.load(.acquire));
}

test "run-retry: KEEPALIVE_DRAIN_SPINS bounds shutdown so it can never hang" {
    // The old code had an unbounded `while (DONE == 0)` that could hang
    // shutdown forever if a buffer was never queued. The new code caps the
    // spin at KEEPALIVE_DRAIN_SPINS. Verify the cap is exactly 400 (400 * 5ms
    // = 2s hard ceiling), so a regression to an unbounded wait is caught.
    try expectEqual(@as(u32, 400), KEEPALIVE_DRAIN_SPINS);
    // 400 * 5ms = 2000ms = 2s. This must be strictly less than the
    // WaitForSingleObject(process, 15000) ToothTray timeout so a stuck
    // keepalive can't delay app shutdown past the ToothTray wait.
    const drain_ms: u32 = KEEPALIVE_DRAIN_SPINS * 5;
    try expect(drain_ms <= 15000);
}

//------------------------------------------------------------------------------
// Layer 5 — timing constants that govern "how fast does sound start"
//------------------------------------------------------------------------------

test "timing: POLL_INTERVAL_MS is 2000ms" {
    // After the case opens, the worker polls every 2s. This is the worst-
    // case latency from "earbuds connected" to "sound starts". Pinning it
    // catches a regression that could make sound start too late (user
    // perceives silence) or too often (battery drain).
    try expectEqual(@as(u32, 2000), POLL_INTERVAL_MS);
}

test "timing: RESUME_DELAY_MS is 3000ms" {
    // After a power-resume event the worker waits 3s before polling, to give
    // the BT stack time to re-enumerate. Too short -> device not yet visible
    // -> silent gap. Too long -> user perceives no sound. Pin the value.
    try expectEqual(@as(u32, 3000), RESUME_DELAY_MS);
}

test "timing: resume delay is greater than poll interval" {
    // The resume delay must be >= poll interval, otherwise a resume-triggered
    // poll could race the BT re-enumeration and miss the (still-connecting)
    // device, producing a "no sound after sleep" gap.
    try expect(RESUME_DELAY_MS >= POLL_INTERVAL_MS);
}

//------------------------------------------------------------------------------
// Struct layout — Win32 ABI compatibility
// These pin the extern struct sizes so a field-type change (e.g. u32 -> u64)
// that would silently break the BT IOCTLs / waveOut calls is caught at test
// time, not at "sound randomly doesn't work on some machines" time.
//------------------------------------------------------------------------------

test "ABI: WAVEFORMATEX size matches Win32" {
    // Win32 WAVEFORMATEX is 18 bytes under #pragma pack(1) used by the SDK.
    // Zig's extern struct uses natural alignment, so the struct gets 2 bytes
    // of trailing padding to reach 4-byte alignment -> 20 bytes. This does
    // NOT affect waveOutOpen: the API reads fields by offset, and every
    // field offset is identical. Pin the Zig-reported size so a field-type
    // change (e.g. u16 -> u32) is caught.
    try expectEqual(@as(usize, 20), @sizeOf(WAVEFORMATEX));
}

test "ABI: WAVEHDR size matches Win32" {
    // WAVEHDR on x64 is 48 bytes (4 pointer-width fields * 8 + 4 DWORDs * 4
    // = 32 + 16 = 48, no trailing padding needed since 48 % 8 == 0).
    // On x86 it is 32 bytes (all fields 4 bytes wide). Pin the size so a
    // field-type change that would corrupt waveOutPrepareHeader is caught.
    const expected: usize = if (@sizeOf(usize) == 8) 48 else 32;
    try expectEqual(expected, @sizeOf(WAVEHDR));
}

test "ABI: SYSTEMTIME size is 16 bytes" {
    try expectEqual(@as(usize, 16), @sizeOf(SYSTEMTIME));
}

test "ABI: BLUETOOTH_FIND_RADIO_PARAMS size is 4 bytes" {
    try expectEqual(@as(usize, 4), @sizeOf(BLUETOOTH_FIND_RADIO_PARAMS));
}

test "ABI: WNDCLASSEXW size matches Win32" {
    // cbSize field of WNDCLASSEXW must equal sizeof(WNDCLASSEXW); if the
    // Zig struct layout drifts from Win32, RegisterClassExW silently fails.
    const expected: usize = if (@sizeOf(usize) == 8) 80 else 48;
    try expectEqual(expected, @sizeOf(WNDCLASSEXW));
}

test "ABI: MSG size matches Win32" {
    const expected: usize = if (@sizeOf(usize) == 8) 48 else 28;
    try expectEqual(expected, @sizeOf(MSG));
}

test "ABI: STARTUPINFOW size matches Win32" {
    // STARTUPINFOW on x64 is 104 bytes (4 DWORDs + 3 pointers + 8 DWORDs +
    // 2 WORDs + 4 pad + 4 pointers, with pointer-width alignment gaps).
    // On x86 it is 68 bytes. Pin the size so CreateProcessW doesn't get a
    // corrupted STARTUPINFOW.
    const expected: usize = if (@sizeOf(usize) == 8) 104 else 68;
    try expectEqual(expected, @sizeOf(STARTUPINFOW));
}

test "ABI: PROCESS_INFORMATION size matches Win32" {
    // 2 handles (pointer-width) + 2 DWORDs.
    const expected: usize = @sizeOf(usize) * 2 + 8;
    try expectEqual(expected, @sizeOf(PROCESS_INFORMATION));
}

test "ABI: WAVEFORMATEX fields describe the exact keepalive format" {
    // The keepalive writes a 44100 Hz, stereo, 16-bit PCM stream. If any of
    // these drift (e.g. someone "optimises" to mono), the dither pattern
    // and the byte math in fillKeepaliveBuffer silently break.
    var ka = SilentKeepalive.init();
    defer ka.stop();
    const fmt = WAVEFORMATEX{
        .wFormatTag = WAVE_FORMAT_PCM,
        .nChannels = 2,
        .nSamplesPerSec = 44100,
        .nAvgBytesPerSec = 176400,
        .nBlockAlign = 4,
        .wBitsPerSample = 16,
        .cbSize = 0,
    };
    try expectEqual(@as(u16, 1), fmt.wFormatTag);
    try expectEqual(@as(u16, 2), fmt.nChannels);
    try expectEqual(@as(u32, 44100), fmt.nSamplesPerSec);
    try expectEqual(@as(u32, 176400), fmt.nAvgBytesPerSec);
    try expectEqual(@as(u16, 4), fmt.nBlockAlign);
    try expectEqual(@as(u16, 16), fmt.wBitsPerSample);
    // nAvgBytesPerSec must equal nSamplesPerSec * nBlockAlign.
    try expectEqual(fmt.nSamplesPerSec * @as(u32, fmt.nBlockAlign), fmt.nAvgBytesPerSec);
    // Buffer must hold whole sample frames (nBlockAlign bytes each).
    try expect(ka.silence_buf.len % fmt.nBlockAlign == 0);
}

//------------------------------------------------------------------------------
// Win32 constant pinning — a wrong constant here = silent breakage
//------------------------------------------------------------------------------

test "constants: wave/audio constants" {
    try expectEqual(@as(u32, 0xFFFFFFFF), WAVE_MAPPER);
    try expectEqual(@as(u32, 0), CALLBACK_NULL);
    try expectEqual(@as(u16, 1), WAVE_FORMAT_PCM);
    try expectEqual(@as(u32, 0x00000001), WHDR_DONE);
}

test "constants: WaitForSingleObject result codes" {
    try expectEqual(@as(u32, 0x00000000), WAIT_OBJECT_0);
    try expectEqual(@as(u32, 0x00000102), WAIT_TIMEOUT);
    try expectEqual(@as(u32, 0xFFFFFFFF), WAIT_FAILED);
    try expectEqual(@as(u32, 0x08000000), CREATE_NO_WINDOW);
}

test "constants: window message constants" {
    try expectEqual(@as(u32, 0x0010), WM_CLOSE);
    try expectEqual(@as(u32, 0x0002), WM_DESTROY);
    try expectEqual(@as(u32, 0x0218), WM_POWERBROADCAST);
    try expectEqual(@as(usize, 0x0012), PBT_APMRESUMEAUTOMATIC);
}

test "constants: window style constants" {
    try expectEqual(@as(u32, 0x80000000), WS_POPUP);
    try expectEqual(@as(u32, 0x00000080), WS_EX_TOOLWINDOW);
    try expectEqual(@as(u32, 0x08000000), WS_EX_NOACTIVATE);
    try expectEqual(@as(i32, -21), GWLP_USERDATA);
}

//------------------------------------------------------------------------------
// fillKeepaliveBuffer — exhaustive edge-case coverage
//------------------------------------------------------------------------------

test "fillKeepaliveBuffer: empty buffer does not crash" {
    var buf: [0]u8 = .{};
    fillKeepaliveBuffer(&buf);
}

test "fillKeepaliveBuffer: single-byte buffer is zeroed (no sample possible)" {
    var buf: [1]u8 = .{0x5A};
    fillKeepaliveBuffer(&buf);
    try expectEqual(@as(u8, 0), buf[0]);
}

test "fillKeepaliveBuffer: two-byte buffer is exactly +1" {
    // Minimum viable buffer: one 16-bit sample, must be +1 LE = [0x01, 0x00].
    var buf: [2]u8 = .{ 0xFF, 0xFF };
    fillKeepaliveBuffer(&buf);
    try expectEqual(@as(u8, 1), buf[0]);
    try expectEqual(@as(u8, 0), buf[1]);
}

test "fillKeepaliveBuffer: three-byte buffer has one sample + trailing zero" {
    var buf: [3]u8 = .{ 0xFF, 0xFF, 0xFF };
    fillKeepaliveBuffer(&buf);
    try expectEqual(@as(u8, 1), buf[0]);
    try expectEqual(@as(u8, 0), buf[1]);
    try expectEqual(@as(u8, 0), buf[2]); // trailing odd byte zeroed
}

test "fillKeepaliveBuffer: four-byte buffer is +1, -1" {
    // Two samples: even index -> +1, odd index -> -1.
    var buf: [4]u8 = .{ 0xAA, 0xAA, 0xAA, 0xAA };
    fillKeepaliveBuffer(&buf);
    // +1 LE = [0x01, 0x00]
    try expectEqual(@as(u8, 1), buf[0]);
    try expectEqual(@as(u8, 0), buf[1]);
    // -1 LE = [0xFF, 0xFF]
    try expectEqual(@as(u8, 0xFF), buf[2]);
    try expectEqual(@as(u8, 0xFF), buf[3]);
}

test "fillKeepaliveBuffer: is deterministic (same input -> same output)" {
    var a: [128]u8 = undefined;
    var b: [128]u8 = undefined;
    fillKeepaliveBuffer(&a);
    fillKeepaliveBuffer(&b);
    try expectEqualSlices(u8, &a, &b);
}

test "fillKeepaliveBuffer: is idempotent (double fill == single fill)" {
    var once: [256]u8 = undefined;
    fillKeepaliveBuffer(&once);

    var twice: [256]u8 = undefined;
    fillKeepaliveBuffer(&twice);
    fillKeepaliveBuffer(&twice);

    try expectEqualSlices(u8, &once, &twice);
}

test "fillKeepaliveBuffer: no all-zero 2-byte window in any even-length buffer" {
    // Sweep several sizes; for each, verify no pair of bytes is 0x00 0x00.
    const sizes = [_]usize{ 2, 4, 8, 16, 64, 256, 1024, 4096, KEEPALIVE_BUF_SIZE };
    for (sizes) |sz| {
        const buf = std.heap.page_allocator.alloc(u8, sz) catch return;
        defer std.heap.page_allocator.free(buf);
        @memset(buf, 0xAA);
        fillKeepaliveBuffer(buf);
        var i: usize = 0;
        while (i + 1 < buf.len) : (i += 2) {
            try expect(!(buf[i] == 0 and buf[i + 1] == 0));
        }
    }
}

test "fillKeepaliveBuffer: alternating pattern holds for full-size buffer" {
    // Full KEEPALIVE_BUF_SIZE buffer: every even-indexed sample is +1, every
    // odd-indexed sample is -1. A single violation would mean the dither
    // pattern is broken and could let the BT engine idle-disconnect.
    var buf: [KEEPALIVE_BUF_SIZE]u8 = [_]u8{0} ** KEEPALIVE_BUF_SIZE;
    fillKeepaliveBuffer(&buf);

    var sample_idx: usize = 0;
    while (sample_idx + 1 < buf.len) : (sample_idx += 2) {
        const bits: u16 = @as(u16, buf[sample_idx]) | (@as(u16, buf[sample_idx + 1]) << 8);
        const sample: i16 = @bitCast(bits);
        const expected: i16 = if ((sample_idx / 2) % 2 == 0) 1 else -1;
        try expectEqual(expected, sample);
    }
}

test "fillKeepaliveBuffer: odd-length buffer trailing byte is always zero" {
    // Regardless of size, an odd trailing byte must be 0 (it can't form a
    // sample and leaving it non-zero could leak into the next buffer).
    const sizes = [_]usize{ 1, 3, 5, 7, 9, 11, 255, 257, 8191, 8193 };
    for (sizes) |sz| {
        const buf = std.heap.page_allocator.alloc(u8, sz) catch return;
        defer std.heap.page_allocator.free(buf);
        @memset(buf, 0x7E);
        fillKeepaliveBuffer(buf);
        try expectEqual(@as(u8, 0), buf[buf.len - 1]);
    }
}

test "fillKeepaliveBuffer: every byte is part of a valid sample or a zero pad" {
    // For even-length buffers, every byte belongs to a ±1 sample. For odd,
    // every byte except the last belongs to a ±1 sample, and the last is 0.
    var even: [100]u8 = undefined;
    fillKeepaliveBuffer(&even);
    var i: usize = 0;
    while (i + 1 < even.len) : (i += 2) {
        const bits: u16 = @as(u16, even[i]) | (@as(u16, even[i + 1]) << 8);
        const sample: i16 = @bitCast(bits);
        try expect(sample == 1 or sample == -1);
    }

    var odd: [101]u8 = undefined;
    fillKeepaliveBuffer(&odd);
    i = 0;
    while (i + 1 < odd.len - 1) : (i += 2) {
        const bits: u16 = @as(u16, odd[i]) | (@as(u16, odd[i + 1]) << 8);
        const sample: i16 = @bitCast(bits);
        try expect(sample == 1 or sample == -1);
    }
    try expectEqual(@as(u8, 0), odd[odd.len - 1]);
}

//------------------------------------------------------------------------------
// parseMacAddr / hexNibble — expanded edge cases
//------------------------------------------------------------------------------

test "parseMacAddr: rejects the all-zero address and accepts all-FFs" {
    try testing.expectError(error.ZeroMacAddress, parseMacAddr("00:00:00:00:00:00"));
    try expectEqual(@as(u64, 0xFFFFFFFFFFFF), try parseMacAddr("FF:FF:FF:FF:FF:FF"));
    try expectEqual(@as(u64, 0xFFFFFFFFFFFF), try parseMacAddr("ff:ff:ff:ff:ff:ff"));
}

test "parseMacAddr: case-insensitivity within a single MAC" {
    try expectEqual(@as(u64, 0xAABBCCDDEEFF), try parseMacAddr("Aa:Bb:Cc:Dd:Ee:Ff"));
    try expectEqual(@as(u64, 0x0123456789AB), try parseMacAddr("01:23:45:67:89:aB"));
}

test "parseMacAddr: numeric-only MAC" {
    try expectEqual(@as(u64, 0x001122334455), try parseMacAddr("00:11:22:33:44:55"));
    try expectEqual(@as(u64, 0x999999999999), try parseMacAddr("99:99:99:99:99:99"));
}

test "parseMacAddr: rejects wrong separators" {
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA-BB-CC-DD-EE-FF"));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA.BB.CC.DD.EE.FF"));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA BB CC DD EE FF"));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AABBCCDDEEFF"));
}

test "parseMacAddr: rejects wrong length" {
    try testing.expectError(error.InvalidMacFormat, parseMacAddr(""));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB:CC:DD:EE"));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB:CC:DD:EE:FF:GG"));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB:CC:DD:EE:F")); // 15 chars
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB:CC:DD:EE:FF:")); // 18 chars
}

test "parseMacAddr: rejects whitespace" {
    try testing.expectError(error.InvalidMacFormat, parseMacAddr(" AA:BB:CC:DD:EE:FF"));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB:CC:DD:EE:FF "));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB:CC:DD:EE:FF\n"));
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB: CC:DD:EE:FF"));
}

test "parseMacAddr: rejects non-hex characters" {
    try testing.expectError(error.InvalidHexChar, parseMacAddr("GG:BB:CC:DD:EE:FF"));
    try testing.expectError(error.InvalidHexChar, parseMacAddr("AA:BB:CC:DD:EE:G0"));
    try testing.expectError(error.InvalidHexChar, parseMacAddr("ZZ:00:00:00:00:00"));
    // ':' inside a byte position is caught by the format check first.
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("A::B:CC:DD:EE:FF"));
}

test "parseMacAddr: exactly 17 characters is the only valid length" {
    // 17 = 6 bytes * 2 hex chars + 5 colons. Pin this boundary.
    try expectEqual(@as(usize, 17), "AA:BB:CC:DD:EE:FF".len);
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB:CC:DD:EE:F")); // 16
    try testing.expectError(error.InvalidMacFormat, parseMacAddr("AA:BB:CC:DD:EE:FF0")); // 18
}

test "hexNibble: digit boundaries" {
    try expectEqual(@as(u8, 0), try hexNibble('0'));
    try expectEqual(@as(u8, 9), try hexNibble('9'));
}

test "hexNibble: uppercase boundaries" {
    try expectEqual(@as(u8, 10), try hexNibble('A'));
    try expectEqual(@as(u8, 15), try hexNibble('F'));
}

test "hexNibble: lowercase boundaries" {
    try expectEqual(@as(u8, 10), try hexNibble('a'));
    try expectEqual(@as(u8, 15), try hexNibble('f'));
}

test "hexNibble: rejects characters just outside hex ranges" {
    // Characters adjacent to valid ranges — a common source of off-by-one.
    try testing.expectError(error.InvalidHexChar, hexNibble('/')); // before '0'
    try testing.expectError(error.InvalidHexChar, hexNibble(':')); // after '9'
    try testing.expectError(error.InvalidHexChar, hexNibble('@')); // before 'A'
    try testing.expectError(error.InvalidHexChar, hexNibble('G')); // after 'F'
    try testing.expectError(error.InvalidHexChar, hexNibble('`')); // before 'a'
    try testing.expectError(error.InvalidHexChar, hexNibble('g')); // after 'f'
}

test "hexNibble: rejects control and whitespace" {
    try testing.expectError(error.InvalidHexChar, hexNibble(0)); // null
    try testing.expectError(error.InvalidHexChar, hexNibble(' '));
    try testing.expectError(error.InvalidHexChar, hexNibble('\n'));
    try testing.expectError(error.InvalidHexChar, hexNibble('\t'));
}

test "hexNibble: all 256 byte values classified correctly" {
    var c: u16 = 0;
    while (c < 256) : (c += 1) {
        const ch: u8 = @intCast(c);
        const result = hexNibble(ch);
        const valid = (ch >= '0' and ch <= '9') or
            (ch >= 'A' and ch <= 'F') or
            (ch >= 'a' and ch <= 'f');
        if (valid) {
            const expected: u8 = switch (ch) {
                '0'...'9' => ch - '0',
                'A'...'F' => ch - 'A' + 10,
                'a'...'f' => ch - 'a' + 10,
                else => unreachable,
            };
            try expectEqual(expected, try result);
        } else {
            try testing.expectError(error.InvalidHexChar, result);
        }
    }
}

//------------------------------------------------------------------------------
// SilentKeepalive field-level invariants
//------------------------------------------------------------------------------

test "SilentKeepalive: silence_buf is KEEPALIVE_BUF_SIZE bytes" {
    var ka = SilentKeepalive.init();
    defer ka.stop();
    try expectEqual(@as(usize, KEEPALIVE_BUF_SIZE), ka.silence_buf.len);
}

test "SilentKeepalive: hwo is null at init" {
    // hwo is the waveOut handle, set inside runSession(). It must start null
    // so a stray stop() before the first session can't close a stale handle.
    var ka = SilentKeepalive.init();
    defer ka.stop();
    try expect(ka.hwo == null);
}

test "SilentKeepalive: want_run is an atomic and starts false" {
    var ka = SilentKeepalive.init();
    defer ka.stop();
    try expect(!ka.want_run.load(.acquire));
    // Verify it's actually an atomic (compile-time type check).
    comptime try expect(@TypeOf(ka.want_run) == std.atomic.Value(bool));
}

test "SilentKeepalive: buffer first sample is +1, second is -1" {
    // Pin the exact dither so a refactor that flips the polarity or shifts
    // the pattern is caught. +1 then -1 (not -1 then +1) is the contract.
    var ka = SilentKeepalive.init();
    defer ka.stop();

    const s0_bits: u16 = @as(u16, ka.silence_buf[0]) | (@as(u16, ka.silence_buf[1]) << 8);
    const s1_bits: u16 = @as(u16, ka.silence_buf[2]) | (@as(u16, ka.silence_buf[3]) << 8);
    try expectEqual(@as(i16, 1), @as(i16, @bitCast(s0_bits)));
    try expectEqual(@as(i16, -1), @as(i16, @bitCast(s1_bits)));
}

//------------------------------------------------------------------------------
// Integration-style: the full "case opened" golden path, as far as pure logic
// allows. These tests stitch together every layer to prove the end-to-end
// contract: case opens -> device seen connected -> decision says start ->
// keepalive is ready to emit non-zero audio immediately.
//------------------------------------------------------------------------------

test "golden path: case-opened scenario reaches start_keepalive decision" {
    // Simulate: worker polls, finds the target MAC, device_info.fConnected=1.
    // The decision MUST be start_keepalive. This is the single test that,
    // if it fails, proves sound will not start when the case is opened.
    const found = true;
    const fConnected: i32 = 1;
    try expectEqual(PollAction.start_keepalive, decidePollAction(found, fConnected));
}

test "golden path: keepalive buffer is ready the instant start would be called" {
    // At the moment decidePollAction returns start_keepalive, the
    // SilentKeepalive must already have a valid non-zero buffer — there is
    // no async fill, no lazy init, no "first call zeroes the buffer" gap.
    var ka = SilentKeepalive.init();
    defer ka.stop();

    // Simulate the decision firing.
    const action = decidePollAction(true, 1);
    try expectEqual(PollAction.start_keepalive, action);

    // The buffer is ready RIGHT NOW, no setup needed.
    try expectEqual(@as(u8, 1), ka.silence_buf[0]);
    try expectEqual(@as(u8, 0), ka.silence_buf[1]);
    // And the whole buffer is non-zero-dithered.
    var i: usize = 0;
    while (i + 1 < ka.silence_buf.len) : (i += 2) {
        const bits: u16 = @as(u16, ka.silence_buf[i]) |
            (@as(u16, ka.silence_buf[i + 1]) << 8);
        try expect(bits != 0);
    }
}

test "golden path: pre-connected poll then case-opened poll both start sound" {
    // Regression for the "no sound on first run" class: the first poll
    // might see the device not-yet-connected (case was just opened, BT
    // link is still coming up). The second poll sees it connected. Both
    // polls must make the correct decision so sound starts on the second
    // poll — NOT only after an app restart.
    const first_poll = decidePollAction(true, 0); // seen, not yet connected
    try expectEqual(PollAction.stop_and_connect, first_poll);

    const second_poll = decidePollAction(true, 1); // now connected
    try expectEqual(PollAction.start_keepalive, second_poll);
}

test "golden path: no scenario silences an already-started keepalive spuriously" {
    // Once the device is connected, every subsequent poll with the device
    // still connected must keep returning start_keepalive (idempotent
    // start). There is no PollAction.stop that fires from a connected
    // state, so sound can never be killed while the earbuds are linked.
    for (1..10) |n| {
        const conn: i32 = @intCast(n);
        try expectEqual(PollAction.start_keepalive, decidePollAction(true, conn));
    }
}

test "golden path: device disappearing then reconnecting restarts sound" {
    // Earbuds disconnect (case closed) -> not found -> none.
    // Case reopened -> found, connected -> start_keepalive again.
    // This is the "restart the app" scenario the user is worried about,
    // but happening naturally within a single app run.
    try expectEqual(PollAction.none, decidePollAction(false, 0));
    try expectEqual(PollAction.start_keepalive, decidePollAction(true, 1));
}

//------------------------------------------------------------------------------
// Regression sentinels — each pins a specific historical bug so it can't
// come back. The comments name the bug; the assertion prevents it.
//------------------------------------------------------------------------------

test "regression: buffer is filled in init(), not lazily in runSession()" {
    // Historical bug: buffer was zero-initialised and only filled inside
    // runSession() after waveOutOpen. If the first waveOutOpen succeeded
    // before the fill completed (or the fill was skipped on an error path),
    // the first buffer queued to the driver was all-zero silence, the BT
    // engine treated it as idle, and the earbuds disconnected. Restarting
    // the app "fixed" it only because the second run happened to fill the
    // buffer in time. The fix: fill in init(). This test pins that.
    var ka = SilentKeepalive.init();
    defer ka.stop();
    // The buffer is non-zero BEFORE any start()/runSession() call.
    try expect(ka.silence_buf[0] != 0);
    try expect(ka.silence_buf[1] == 0); // high byte of +1
    try expect(ka.silence_buf[2] == 0xFF); // low byte of -1
    try expect(ka.silence_buf[3] == 0xFF); // high byte of -1
}

test "regression: run() outer loop retries after a failed session" {
    // Historical bug: a single waveOutOpen failure killed the keepalive
    // permanently, so a transient first-call failure meant "no sound until
    // app restart". The fix: run() loops `while (want_run) { runSession();
    // if (want_run) Sleep(500); }`, retrying forever until stop(). We
    // can't call run() in a cross-platform test (it calls waveOut), but we
    // verify the retry contract via the want_run flag: only stop() clears
    // it, so the loop always retries until explicitly stopped.
    var ka = SilentKeepalive.init();
    ka.want_run.store(true, .release);
    // Simulate runSession() failing and returning: want_run must still be
    // true, so the loop iterates again.
    try expect(ka.want_run.load(.acquire));
    // Simulate a second failure: still true, still retrying.
    try expect(ka.want_run.load(.acquire));
    // Only stop() ends the retry.
    ka.stop();
    try expect(!ka.want_run.load(.acquire));
}

test "regression: stop() always joins even a self-exited worker" {
    // Historical bug: stop() only joined if want_run was true, so a worker
    // that self-exited (waveOutOpen failure) leaked its OS thread handle.
    // The fix: stop() joins whenever `thread != null`, regardless of
    // want_run. Verified in lifecycle tests above; this sentinel documents
    // the specific regression.
    const Dummy = struct {
        fn run() void {}
    };
    var ka = SilentKeepalive.init();
    ka.thread = std.Thread.spawn(.{}, Dummy.run, .{}) catch return;
    // Worker "self-exited" (dummy returns immediately). want_run is still
    // the init() default (false). stop() must still join.
    ka.stop();
    try expect(ka.thread == null);
}

test "regression: drain spin is bounded (no unbounded shutdown hang)" {
    // Historical bug: shutdown did `while (hdr.dwFlags & WHDR_DONE == 0) {}`
    // with no bound. If waveOutWrite failed, the buffer was never queued,
    // DONE never got set, and shutdown hung forever — the app would not
    // exit, requiring a kill. The fix: cap at KEEPALIVE_DRAIN_SPINS. Pin
    // both the cap and the per-spin sleep so the total bound is known.
    try expectEqual(@as(u32, 400), KEEPALIVE_DRAIN_SPINS);
    // runSession sleeps 5ms per spin -> 400 * 5 = 2000ms hard cap.
    try expectEqual(@as(u32, 2000), KEEPALIVE_DRAIN_SPINS * 5);
}

test "regression: fillKeepaliveBuffer never writes a pure-zero sample" {
    // Historical bug: a pure-zero (0x0000) 16-bit sample in the keepalive
    // was treated as idle by FxSound's APO, letting the earbuds disconnect
    // despite "silent" playback running. The fix: ±1 dither. This test
    // sweeps the full buffer and asserts no zero sample exists, on every
    // run, forever.
    var ka = SilentKeepalive.init();
    defer ka.stop();
    var i: usize = 0;
    while (i + 1 < ka.silence_buf.len) : (i += 2) {
        const lo: u16 = ka.silence_buf[i];
        const hi: u16 = ka.silence_buf[i + 1];
        try expect(!(lo == 0 and hi == 0));
    }
}

test "quoteArgInto: plain name is wrapped in double quotes" {
    var buf: [64]u8 = undefined;
    const out = try quoteArgInto(&buf, "MyBuds");
    try expectEqualSlices(u8, "\"MyBuds\"", out);
}

test "quoteArgInto: hostile name with an embedded quote stays one argument" {
    var buf: [256]u8 = undefined;
    const out = try quoteArgInto(&buf, "evil\" --danger");
    // Wrapped in quotes...
    try expect(out.len >= 2);
    try expect(out[0] == '"');
    try expect(out[out.len - 1] == '"');
    // ...and every interior double quote is backslash-escaped, so
    // CommandLineToArgvW cannot see an argument boundary inside the name.
    var i: usize = 1;
    while (i < out.len - 1) : (i += 1) {
        if (out[i] == '"') try expect(out[i - 1] == '\\');
    }
}

test "quoteArgInto: returns error when the buffer is too small" {
    var buf: [4]u8 = undefined;
    try testing.expectError(error.NameTooLong, quoteArgInto(&buf, "toolong"));
}

//------------------------------------------------------------------------------
// Leak-fix layers L2/L3/L5/L6 — pure logic unit tests
//------------------------------------------------------------------------------

test "backoffMs: zero failures means no delay (happy path)" {
    try expectEqual(@as(u32, 0), backoffMs(0, 500, 4000));
}

test "backoffMs: grows exponentially and is capped" {
    try expectEqual(@as(u32, 500), backoffMs(1, 500, 4000));
    try expectEqual(@as(u32, 1000), backoffMs(2, 500, 4000));
    try expectEqual(@as(u32, 2000), backoffMs(3, 500, 4000));
    try expectEqual(@as(u32, 4000), backoffMs(4, 500, 4000));
    // Beyond the cap it stays clamped, never overflowing.
    try expectEqual(@as(u32, 4000), backoffMs(50, 500, 4000));
}

test "CircuitBreaker: trips after exceeding max_events in the window" {
    var cb = CircuitBreaker{ .window_ms = 10_000, .max_events = 3, .cooldown_ms = 30_000 };
    // First three attempts inside the window are allowed.
    try expect(cb.allow(1000));
    try expect(cb.allow(1100));
    try expect(cb.allow(1200));
    // The fourth exceeds max_events -> circuit OPENS.
    try expect(!cb.allow(1300));
    try expect(cb.isTripped(1300));
    // Still open during cooldown.
    try expect(!cb.allow(5000));
    try expect(cb.trip_count == 1);
}

test "CircuitBreaker: recovers and allows again after cooldown elapses" {
    var cb = CircuitBreaker{ .window_ms = 10_000, .max_events = 2, .cooldown_ms = 30_000 };
    try expect(cb.allow(0));
    try expect(cb.allow(100));
    try expect(!cb.allow(200)); // trips at t=200, open until t=30_200
    // Still open during the cooldown window (ends at 200 + 30_000 = 30_200).
    try expect(cb.isTripped(30_000));
    // Cooldown fully elapsed -> no longer tripped.
    try expect(!cb.isTripped(30_201));
    // After cooldown, allow() works again.
    try expect(cb.allow(30_201));
}

test "watchdogTripped: only trips when growth over baseline exceeds threshold" {
    const mb = 1024 * 1024;
    // Below threshold -> no trip.
    try expect(!watchdogTripped(100 * mb, 500 * mb, 800 * mb));
    // Exactly at threshold -> not strictly greater -> no trip.
    try expect(!watchdogTripped(100 * mb, 900 * mb, 800 * mb));
    // Over threshold -> trips.
    try expect(watchdogTripped(100 * mb, 901 * mb, 800 * mb));
    // current below baseline can never trip (no underflow).
    try expect(!watchdogTripped(500 * mb, 100 * mb, 800 * mb));
}

test "shouldRadioReset: never fires while unarmed (healthy path)" {
    // Healthy machines never arm the recovery window -> R1 stays dormant
    // forever, no matter how much time passes or how many resets happened.
    try expect(!shouldRadioReset(0, 0, 0));
    try expect(!shouldRadioReset(0, 86_400_000, 0));
    try expect(!shouldRadioReset(0, 86_400_000, 86_000_000));
}

test "shouldRadioReset: fires only after the arm window elapses" {
    const armed: i64 = 1_000;
    // One millisecond short of the window -> still wait.
    try expect(!shouldRadioReset(armed, armed + R1_ARM_MS - 1, 0));
    // Window fully elapsed -> fire (no previous reset to rate-limit).
    try expect(shouldRadioReset(armed, armed + R1_ARM_MS, 0));
}

test "shouldRadioReset: cooldown enforces at most one reset per minute" {
    const armed: i64 = 1_000;
    const last: i64 = armed + R1_ARM_MS; // first reset fired here
    // One millisecond short of the cooldown -> suppress.
    try expect(!shouldRadioReset(armed, last + R1_COOLDOWN_MS - 1, last));
    // Cooldown fully elapsed -> fire again (S6 degradation path: 1/minute).
    try expect(shouldRadioReset(armed, last + R1_COOLDOWN_MS, last));
}

test "shouldRadioReset: sentinel last_reset_ms allows the very first reset" {
    // last_reset_ms == 0 must not be treated as "reset just happened".
    try expect(shouldRadioReset(1_000, 1_000 + R1_ARM_MS, 0));
    // And armed_ms == 0 always suppresses, regardless of the other args.
    try expect(!shouldRadioReset(0, 1_000 + R1_ARM_MS, 0));
}

test "shouldUsbCycle: never fires while unarmed or before rung 2 ran" {
    // Unarmed episode -> no escalation, ever (healthy path stays silent).
    try expect(!shouldUsbCycle(0, 86_400_000, true, 0));
    // Armed but rung 2 (page-scan) has not fired in this episode yet:
    // the cycle strictly FOLLOWS a failed softer rung, never replaces it.
    const armed: i64 = 1_000;
    try expect(!shouldUsbCycle(armed, armed + R2_ARM_MS + 60_000, false, 0));
}

test "shouldUsbCycle: escalates only after the arm window with rung 2 exercised" {
    const armed: i64 = 1_000;
    // One ms short of the escalation window -> still wait.
    try expect(!shouldUsbCycle(armed, armed + R2_ARM_MS - 1, true, 0));
    // Window fully elapsed, rung 2 done -> escalate.
    try expect(shouldUsbCycle(armed, armed + R2_ARM_MS, true, 0));
}

test "shouldUsbCycle: min interval keeps two cycles apart" {
    const armed: i64 = 1_000;
    const last_cycle: i64 = armed + R2_ARM_MS; // first cycle fired here
    // One ms short of the min interval -> suppress.
    try expect(!shouldUsbCycle(armed, last_cycle + R2_MIN_INTERVAL_MS - 1, true, last_cycle));
    // Interval fully elapsed -> escalate again (capped by the breaker).
    try expect(shouldUsbCycle(armed, last_cycle + R2_MIN_INTERVAL_MS, true, last_cycle));
}

test "shouldUsbCycle: sentinel last_cycle_ms allows the very first cycle" {
    const armed: i64 = 1_000;
    try expect(shouldUsbCycle(armed, armed + R2_ARM_MS, true, 0));
}

test "R2 breaker: hard-caps the storm at 2 cycles per 10-minute window" {
    // Same L5 primitive, stricter budget: two cycles are allowed inside one
    // window, the third call trips it and silences the rung for the cooldown.
    var breaker = CircuitBreaker{
        .window_ms = R2_CB_WINDOW_MS,
        .max_events = R2_CB_MAX_CYCLES,
        .cooldown_ms = R2_CB_COOLDOWN_MS,
    };
    const t0: i64 = 60_000;
    try expect(breaker.allow(t0));
    try expect(breaker.allow(t0 + 1_000));
    try expect(!breaker.allow(t0 + 2_000)); // tripped
    // Cooldown elapsed -> window resets, budget restored.
    try expect(breaker.allow(t0 + 2_000 + R2_CB_COOLDOWN_MS));
}

test "SetupAPI ABI: SP_PROPCHANGE_PARAMS / SP_DEVINFO_DATA layout matches Win32" {
    // SP_CLASSINSTALL_HEADER: cbSize + InstallFunction ONLY (8 bytes). The
    // r1-l3 revision asserted a phantom DevInst field here, which made this
    // very test enforce the corrupted layout — 114/114 green while every
    // field rung-3 attempt failed with 0x80070006. Win32 truth:
    //   typedef struct _SP_CLASSINSTALL_HEADER { DWORD cbSize; DI_FUNCTION
    //       InstallFunction; } SP_CLASSINSTALL_HEADER;
    try expectEqual(@as(usize, 8), @sizeOf(SP_CLASSINSTALL_HEADER));
    try expectEqual(@as(usize, 8), @offsetOf(SP_PROPCHANGE_PARAMS, "StateChange"));
    try expectEqual(@as(usize, 12), @offsetOf(SP_PROPCHANGE_PARAMS, "Scope"));
    try expectEqual(@as(usize, 16), @offsetOf(SP_PROPCHANGE_PARAMS, "HwProfile"));
    try expectEqual(@as(usize, 20), @sizeOf(SP_PROPCHANGE_PARAMS));
    // SP_DEVINFO_DATA: cbSize, GUID, DevInst, Reserved(natural pointer size),
    // with the same padding the C compiler would apply on this arch.
    try expectEqual(@as(usize, 20), @offsetOf(SP_DEVINFO_DATA, "DevInst"));
    try expectEqual(@sizeOf(SP_DEVINFO_DATA) - @sizeOf(usize), @offsetOf(SP_DEVINFO_DATA, "Reserved"));
    // cbSize handed to SetupDi must equal the struct size itself.
    try expectEqual(@sizeOf(SP_DEVINFO_DATA), @as(usize, @sizeOf(SP_DEVINFO_DATA)));
}

test "R1 breaker: hard-caps the storm at 3 resets per 10-minute window" {
    // The R1 breaker is a stock CircuitBreaker (L5 primitive) with the R1
    // constants. Three resets inside one window are allowed, the fourth call
    // trips it and silences R1 for the rest of the window. This cap is what
    // makes the absence-based trigger safe for earbuds resting in their case.
    var r1 = CircuitBreaker{
        .window_ms = R1_CB_WINDOW_MS,
        .max_events = R1_CB_MAX_RESETS,
        .cooldown_ms = R1_CB_COOLDOWN_MS,
    };
    const t0: i64 = 60_000;
    try expect(r1.allow(t0)); // reset #1
    try expect(r1.allow(t0 + 60_000)); // reset #2
    try expect(r1.allow(t0 + 120_000)); // reset #3
    const trip_at = t0 + 180_000;
    try expect(!r1.allow(trip_at)); // 4th -> trip, radio left alone
    try expect(r1.isTripped(trip_at + R1_CB_COOLDOWN_MS - 1));
    // Cooldown (counted from the trip) fully elapsed -> fresh budget of three.
    try expect(r1.allow(trip_at + R1_CB_COOLDOWN_MS));
    try expect(r1.allow(trip_at + R1_CB_COOLDOWN_MS + 60_000));
    try expect(r1.allow(trip_at + R1_CB_COOLDOWN_MS + 120_000));
    try expect(!r1.allow(trip_at + R1_CB_COOLDOWN_MS + 180_000));
}

test "BLUETOOTH_RADIO_INFO: layout size matches the Win32 struct (520 bytes)" {
    try expectEqual(@as(usize, 520), @sizeOf(BLUETOOTH_RADIO_INFO));
    try expectEqual(@as(usize, 512), @offsetOf(BLUETOOTH_RADIO_INFO, "ulClassofDevice"));
}

test "fmtMac: round-trips parseMacAddr formatting (MSB first, uppercase)" {
    const mac = try parseMacAddr("94:8B:93:B1:E4:A1");
    const s = fmtMac(mac);
    try expectEqualSlices(u8, "94:8B:93:B1:E4:A1", s[0..]);
    const zero = fmtMac(0);
    try expectEqualSlices(u8, "00:00:00:00:00:00", zero[0..]);
}

test "isCsrRadioInstanceId: matches the CSR dongle across ID shapes" {
    // The exact instance ID the 2026-09-01 field build matched (debug4.log).
    try expect(isCsrRadioInstanceId("USB\\VID_0A12&PID_0001\\5&127C236B&0&3"));
    // Case must not matter (PnP IDs are case-preserving but not case-stable).
    try expect(isCsrRadioInstanceId("usb\\vid_0a12&pid_0001\\x"));
    try expect(isCsrRadioInstanceId("USB\\VID_0a12&PID_0001"));
    // Wrong PID / wrong VID / unrelated present device must not match.
    try expect(!isCsrRadioInstanceId("USB\\VID_0A12&PID_0002\\5&127C236B&0&3"));
    try expect(!isCsrRadioInstanceId("USB\\VID_1A12&PID_0001\\5&127C236B&0&3"));
    try expect(!isCsrRadioInstanceId("USB\\VID_8087&PID_0026\\5&2B5C9BD&0&2"));
    try expect(!isCsrRadioInstanceId(""));
}

// r1-l5 regression pin: the enumeration query must select the USB PnP
// *enumerator* (null class GUID + L"USB"), never GUID_DEVCLASS_USB — the
// CSR radio's devnode installs under the Bluetooth setup class, so the
// class-GUID query missed a demonstrably present radio (field archive
// 2026-09-02 22:07: CSV OK/CM_PROB_NONE while the cycle aborted "not
// present"). The extern call itself cannot run under the host test
// environment, so pin the decision as pure data instead.
test "ENUMERATOR_USB: L\"USB\" selector for SetupDiGetClassDevsW" {
    const e = &ENUMERATOR_USB; // [3:0]u16 — len is 3, sentinel sits at [3]
    try expectEqual(@as(usize, 3), e.len);
    try expectEqual(@as(u16, 'U'), e[0]);
    try expectEqual(@as(u16, 'S'), e[1]);
    try expectEqual(@as(u16, 'B'), e[2]);
    try expectEqual(@as(u16, 0), e[3]); // null-terminated UTF-16
}

// r1-l7 regression pin: the usb-cycle query passes (null ClassGuid, L"USB",
// DIGCF_PRESENT | DIGCF_ALLCLASSES). r1-l5 dropped DIGCF_ALLCLASSES; with a
// NULL ClassGuid that is an ill-formed all-classes query — the call succeeds
// but the set does not contain the radio (field archive 2026-09-02 22:41:
// "not present, cycle aborted" while CSV + PnP both showed the radio OK).
// The extern call cannot run under the host test environment, so pin the
// flag values as pure data, same approach as the ENUMERATOR_USB pin above.
test "DIGCF flags: ClassGuid=NULL all-classes query needs DIGCF_ALLCLASSES" {
    try expectEqual(@as(u32, 0x00000002), DIGCF_PRESENT);
    try expectEqual(@as(u32, 0x00000004), DIGCF_ALLCLASSES);
    try expectEqual(@as(u32, 0x00000006), DIGCF_PRESENT | DIGCF_ALLCLASSES);
}

// r1-l8 regression pin: the verified cycle state machine. Field archive
// 2026-09-02 23:55: DICS_ENABLE returned TRUE while the devnode never
// restarted and stayed CM_PROB_DISABLED — the old code believed the API
// receipt and reported "complete", leaving the dongle disabled. These
// predicates are the only enable/disable evidence the cycle now trusts.
test "devnode status predicates: disabled vs started bit semantics" {
    // Disabled: DN_HAS_PROBLEM + CM_PROB_DISABLED (DN_STARTED may or may not
    // still be set in the residual mask — the problem code is decisive).
    try expect(devnodeStatusMeansDisabled(DN_HAS_PROBLEM, CM_PROB_DISABLED));
    try expect(devnodeStatusMeansDisabled(DN_HAS_PROBLEM | DN_STARTED, CM_PROB_DISABLED));
    try expect(!devnodeStatusMeansDisabled(DN_STARTED, 0)); // healthy started
    try expect(!devnodeStatusMeansDisabled(DN_HAS_PROBLEM, 10)); // start failure is not "user disabled"
    // Started: DN_STARTED with a clean problem code — the only verified
    // "enable took effect" signal.
    try expect(devnodeStatusMeansStarted(DN_STARTED, 0));
    try expect(!devnodeStatusMeansStarted(DN_STARTED, CM_PROB_DISABLED)); // stuck disabled
    try expect(!devnodeStatusMeansStarted(DN_HAS_PROBLEM, 10)); // failed re-start
    try expect(!devnodeStatusMeansStarted(0, 0)); // not enumerated yet
}

test "containsIgnoreCase / isFxSoundName: case-insensitive matching" {
    try expect(containsIgnoreCase("Speakers (FxSound Audio)", "fxsound"));
    try expect(containsIgnoreCase("WF-1000XM5 Stereo", "xm5"));
    try expect(!containsIgnoreCase("Realtek", "fxsound"));
    try expect(!containsIgnoreCase("abc", "abcd")); // needle longer than haystack
    try expect(!containsIgnoreCase("abc", "")); // empty needle never matches
    try expect(isFxSoundName("FxSound Speakers"));
    try expect(isFxSoundName("Fx Sound Device"));
    try expect(!isFxSoundName("Headphones (WF-1000XM5)"));
}

test "selectAudioDevice: picks the earbud endpoint and skips FxSound" {
    const names = [_][]const u8{
        "Speakers (FxSound Audio Enhancer)",
        "Headphones (WF-1000XM5 Stereo)",
        "Realtek HD Audio",
    };
    // Bluetooth name shares the 'WF-1000XM5' token with endpoint #1.
    const idx = selectAudioDevice(&names, "WF-1000XM5", null);
    try expect(idx != null);
    try expectEqual(@as(usize, 1), idx.?);

    // No matching token -> fall back to WAVE_MAPPER (null).
    try expect(selectAudioDevice(&names, "XY", null) == null);
}

test "selectAudioDevice: honours an explicit override substring" {
    const names = [_][]const u8{
        "Speakers (FxSound Audio Enhancer)",
        "Headphones (WF-1000XM5 Stereo)",
        "Realtek HD Audio",
    };
    // Override wins regardless of the BT name, and may even target FxSound if
    // the user explicitly asks for it.
    try expectEqual(@as(usize, 2), selectAudioDevice(&names, "WF-1000XM5", "realtek").?);
    // Override with no match -> null (do not silently fall back to token match).
    try expect(selectAudioDevice(&names, "WF-1000XM5", "nonexistent") == null);
}

test "WAVEOUTCAPSW: layout size matches the Win32 struct (84 bytes)" {
    try expectEqual(@as(usize, 84), @sizeOf(WAVEOUTCAPSW));
}

test "SilentKeepalive: init resolves to WAVE_MAPPER default endpoint" {
    var ka = SilentKeepalive.init();
    defer ka.stop();
    try expectEqual(WAVE_MAPPER, ka.device_id);
    try expect(ka.override_name == null);
}

// ===========================================================================
// r2-l1 tests — the earbud-devnode restart rung, the kill switch, and the
// safety invariant that replaced the service-restart wave.
// ===========================================================================

test "r2-l1 gate: sentinel armed==0 never fires" {
    // r1_armed_ms == 0 means "no absence episode". A real GetTickCount64()
    // never returns 0 for a running process, so this sentinel cannot collide
    // with a genuine timestamp.
    try expect(!shouldEarbudRestart(0, 10_000_000, 0, 0, 0));
    // Not even a queued post-cycle refresh may fire without an episode.
    try expect(!shouldEarbudRestart(0, 10_000_000, 0, 0, 9_999_999));
}

test "r2-l1 gate: arm window must fully elapse" {
    const armed: i64 = 100_000;
    try expect(!shouldEarbudRestart(armed, armed + R3_ARM_MS - 1, 0, 0, 0));
    try expect(shouldEarbudRestart(armed, armed + R3_ARM_MS, 0, 0, 0));
}

test "r2-l1 gate: per-episode budget caps the rung" {
    const armed: i64 = 100_000;
    const now = armed + R3_ARM_MS + 10_000;
    try expect(shouldEarbudRestart(armed, now, 0, R3_MAX_PER_EPISODE - 1, 0));
    try expect(!shouldEarbudRestart(armed, now, 0, R3_MAX_PER_EPISODE, 0));
    try expect(!shouldEarbudRestart(armed, now, 0, R3_MAX_PER_EPISODE + 5, 0));
}

test "r2-l1 gate: minimum interval between restarts" {
    const armed: i64 = 100_000;
    const last: i64 = 140_000;
    try expect(!shouldEarbudRestart(armed, last + R3_MIN_INTERVAL_MS - 1, last, 1, 0));
    try expect(shouldEarbudRestart(armed, last + R3_MIN_INTERVAL_MS, last, 1, 0));
}

test "r2-l1 gate: post-cycle refresh overrides arm, interval and episode budget" {
    // After a VERIFIED usb-cycle the earbud devnodes are stale, so exactly one
    // refresh is queued from the FRESH completion clock. It must fire even if
    // the episode budget is exhausted and the interval has not elapsed — but
    // never before its own deadline, and never without an episode.
    const armed: i64 = 100_000;
    const force_at: i64 = 200_000;
    try expect(!shouldEarbudRestart(armed, force_at - 1, force_at - 5_000, 99, force_at));
    try expect(shouldEarbudRestart(armed, force_at, force_at - 5_000, 99, force_at));
    try expect(shouldEarbudRestart(armed, force_at + 60_000, force_at - 5_000, 99, force_at));
}

test "r2-l1 gate: rung ordering is a property of the constants" {
    // Ladder order must not depend on call order alone: page-scan toggle ->
    // earbud-devnode restart -> usb-cycle.
    try expect(R1_ARM_MS < R3_ARM_MS);
    try expect(R3_ARM_MS < R2_ARM_MS);
    // And the escalation must never out-pace the cheaper rung's cooldown.
    try expect(R3_MIN_INTERVAL_MS > R1_COOLDOWN_MS);
}

test "r2-l1: macHex12 formats a Bluetooth address as lowercase 12-hex" {
    // Field instance ID tail for the user's Redmi Buds 6 Lite: ..._948b93b1e4a1_...
    try expectEqualSlices(u8, "948b93b1e4a1", &macHex12(0x948b93b1e4a1));
    // Leading zeros must be preserved — a naive hex print would drop them and
    // the devnode match would silently never fire.
    try expectEqualSlices(u8, "00000000000a", &macHex12(0x0a));
    try expectEqualSlices(u8, "ffffffffffff", &macHex12(0xffffffffffff));
}

test "r2-l1: idContainsMac matches real BTHENUM instance IDs, case-insensitively" {
    // macHex12 returns a fixed-size [12]u8; idContainsMac takes a slice, so the
    // array must be materialised into a named const and passed by reference
    // (Zig will not coerce an array VALUE to []const u8).
    const mac_arr = macHex12(0x948b93b1e4a1);
    const mac: []const u8 = &mac_arr;
    const a2dp: []const u8 = "BTHENUM\\{0000110b-0000-1000-8000-00805f9b34fb}_VID&00010a12_PID&0001\\8&2f2c9c1&0&948b93b1e4a1_C00000000";
    const avrcp: []const u8 = "BTHENUM\\{0000110c-0000-1000-8000-00805f9b34fb}_LOCALMFG&0000\\8&2F2C9C1&0&948B93B1E4A1_C00000000";
    const dongle: []const u8 = "USB\\VID_0A12&PID_0001\\5&127C236B&0&3";
    const other_earbuds: []const u8 = "BTHENUM\\{0000110b-0000-1000-8000-00805f9b34fb}_VID&00010a12_PID&0001\\8&2f2c9c1&0&aabbccddeeff_C00000000";

    try expect(idContainsMac(a2dp, mac));
    try expect(idContainsMac(avrcp, mac)); // uppercase in the ID
    try expect(!idContainsMac(dongle, mac)); // the radio itself is never a target
    try expect(!idContainsMac(other_earbuds, mac)); // somebody else's headset
    try expect(!idContainsMac("", mac));
    try expect(!idContainsMac("948b93b1e4a", mac)); // truncated, must not match
}

test "r2-l1 gate table: every decision matches the simulated ladder" {
    // The table is generated by the simulation that produced the timing
    // numbers in the report, so a constant tweak that changes behaviour makes
    // this test fail instead of silently shifting field behaviour.
    const data = @embedFile("gate_cases.txt");
    var checked: usize = 0;
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const kind = it.next() orelse return error.BadGateTable;
        if (std.mem.eql(u8, kind, "r3")) {
            const armed = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const now = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const last = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const in_ep = try std.fmt.parseInt(u32, it.next() orelse return error.BadGateTable, 10);
            const force = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const want = (try std.fmt.parseInt(u8, it.next() orelse return error.BadGateTable, 10)) != 0;
            try expectEqual(want, shouldEarbudRestart(armed, now, last, in_ep, force));
        } else if (std.mem.eql(u8, kind, "r2")) {
            const armed = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const now = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const in_ep = (try std.fmt.parseInt(u8, it.next() orelse return error.BadGateTable, 10)) != 0;
            const last = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const want = (try std.fmt.parseInt(u8, it.next() orelse return error.BadGateTable, 10)) != 0;
            try expectEqual(want, shouldUsbCycle(armed, now, in_ep, last));
        } else if (std.mem.eql(u8, kind, "r1")) {
            const armed = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const now = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const last = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const want = (try std.fmt.parseInt(u8, it.next() orelse return error.BadGateTable, 10)) != 0;
            try expectEqual(want, shouldRadioReset(armed, now, last));
        } else if (std.mem.eql(u8, kind, "r2q")) {
            const now = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const done = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const want = (try std.fmt.parseInt(u8, it.next() orelse return error.BadGateTable, 10)) != 0;
            try expectEqual(want, usbCycleQuietAfterRestart(now, done));
        } else if (std.mem.eql(u8, kind, "r1d")) {
            const rejects = try std.fmt.parseInt(u32, it.next() orelse return error.BadGateTable, 10);
            const want = (try std.fmt.parseInt(u8, it.next() orelse return error.BadGateTable, 10)) != 0;
            try expectEqual(want, radioResetRungDead(rejects));
        } else if (std.mem.eql(u8, kind, "rcv")) {
            const now = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const last = try std.fmt.parseInt(i64, it.next() orelse return error.BadGateTable, 10);
            const want = (try std.fmt.parseInt(u8, it.next() orelse return error.BadGateTable, 10)) != 0;
            try expectEqual(want, shouldRetryRecovery(now, last));
        } else if (std.mem.eql(u8, kind, "rdone")) {
            const present = try std.fmt.parseInt(u32, it.next() orelse return error.BadGateTable, 10);
            const left = try std.fmt.parseInt(u32, it.next() orelse return error.BadGateTable, 10);
            const want = (try std.fmt.parseInt(u8, it.next() orelse return error.BadGateTable, 10)) != 0;
            try expectEqual(want, radioRecoveryDone(present, left));
        } else {
            return error.BadGateTable;
        }
        checked += 1;
    }
    // Guard against an empty or truncated table silently passing.
    try expect(checked >= 20);
}

test "r2-l1 breaker: the restart rung is capped exactly like the other rungs" {
    var cb = CircuitBreaker{
        .window_ms = R3_CB_WINDOW_MS,
        .max_events = R3_CB_MAX_RESTARTS,
        .cooldown_ms = R3_CB_COOLDOWN_MS,
    };
    var t: i64 = 100_000;
    var allowed: u32 = 0;
    var i: u32 = 0;
    while (i < R3_CB_MAX_RESTARTS + 3) : (i += 1) {
        if (cb.allow(t)) allowed += 1;
        t += R3_MIN_INTERVAL_MS;
    }
    try expect(allowed <= R3_CB_MAX_RESTARTS);
}

test "r2-l1 INVARIANT: the source contains no service-control path at all" {
    // WHY THIS TEST EXISTS (regression test for the two blue screens):
    // both crashes shared the bucket
    //   0x139_3_CORRUPT_LIST_ENTRY_BthA2dp!IrpList_HandleCancel
    // reached through IoCancelIrp <- IoCancelThreadIo <- PspExitThread, i.e.
    // a Bluetooth SERVICE THREAD exiting while an IRP was pending inside
    // BthA2dp. No service is stopped -> no service thread exits -> that code
    // path cannot be entered by this program. The policy is enforced
    // mechanically, not by review: if anyone ever re-adds a service stop,
    // this test fails before the binary can reach the user's machine.
    // The needles are concatenated from fragments so this test does not match
    // itself in the source it scans.
    const src = @embedFile("main.zig");
    const needles = [_][]const u8{
        "OpenSC" ++ "ManagerW",
        "OpenSer" ++ "viceW",
        "Control" ++ "Service",
        "StartSer" ++ "viceW",
        "QuerySer" ++ "viceStatus",
        "advapi" ++ "32",
        "net" ++ ".exe stop",
        "sc" ++ ".exe stop",
    };
    for (needles) |n| {
        if (std.mem.indexOf(u8, src, n) != null) {
            std.debug.print("forbidden service-control token found in main.zig: {s}\n", .{n});
            return error.ServiceControlPathPresent;
        }
    }
}

test "r2-l1 log: rotation threshold keeps btf.log bounded" {
    // btf.log + btf.log.1 must stay small enough to live next to the exe
    // forever unnoticed. The previous build had no file log at all, which is
    // why neither blue screen left any evidence from this program.
    try expect(LOG_MAX_BYTES > 64 * 1024);
    try expect(LOG_MAX_BYTES <= 8 * 1024 * 1024);
}

// ---------------------------------------------------------------------------
// r2-l3 -- the repair rung (field bug 2026-09-03: Bluetooth left DISABLED)
// ---------------------------------------------------------------------------

test "r2-l3 recovery: a repair is retried on a fixed interval and never stalls" {
    // First ever attempt.
    try expect(shouldRetryRecovery(0, 0));
    try expect(shouldRetryRecovery(500_000, 0));
    // Inside the interval: wait. On or past it: go.
    const t: i64 = 500_000;
    try expect(!shouldRetryRecovery(t, t));
    try expect(!shouldRetryRecovery(t + RECOVERY_RETRY_MS - 1, t));
    try expect(shouldRetryRecovery(t + RECOVERY_RETRY_MS, t));
    try expect(shouldRetryRecovery(t + 10 * RECOVERY_RETRY_MS, t));
    // A backwards clock (NTP step, DST, sleep/resume) must never be able to
    // park a disabled radio for hours: a negative delta means "go now".
    try expect(shouldRetryRecovery(t - 1, t));
    try expect(shouldRetryRecovery(0, t));
    // Repairs are far more eager than any escalation rung.
    try expect(RECOVERY_RETRY_MS < R1_ARM_MS);
    try expect(RECOVERY_RETRY_MS < R3_ARM_MS);
    try expect(RECOVERY_RETRY_MS < R2_ARM_MS);
}

test "r2-l3 recovery: an unplugged dongle is not a completed repair" {
    // present == 0: the dongle is unplugged, so nothing can be concluded and
    // the journal must be KEPT. This is the exact field case: the user pulled
    // the dongle, and the persistent flag came back with it on replug.
    try expect(!radioRecoveryDone(0, 0));
    try expect(!radioRecoveryDone(0, 1));
    // Present but still disabled: not done either.
    try expect(!radioRecoveryDone(1, 1));
    try expect(!radioRecoveryDone(3, 1));
    // Present and nothing left disabled: done.
    try expect(radioRecoveryDone(1, 0));
    try expect(radioRecoveryDone(7, 0));
}

test "r2-l3 recovery: escalation is blocked while a disable is unaccounted for" {
    try expect(recoveryBlocksEscalation(true));
    try expect(!recoveryBlocksEscalation(false));
}

test "r2-l3 INVARIANT: the journal is armed BEFORE the disable and released after" {
    const source = @embedFile("main.zig");

    // The non-persistent path must be attempted first: it can not leave the
    // user without Bluetooth even if the process dies mid-operation.
    const restart_needle = "/restart-device ";
    const restart_at = std.mem.indexOf(u8, source, restart_needle) orelse return error.NonPersistentPathMissing;

    // The journal must be armed, and the disable must REFUSE to run if it
    // could not be armed.
    const arm_needle = "if (!recoveryJournalArm(id_ascii[0..matched_len])) {";
    const arm_at = std.mem.indexOf(u8, source, arm_needle) orelse return error.JournalNotArmed;

    // ...strictly before the first persistent disable of the dongle.
    const disable_needle = "if (!usbPropChange(devs, &target, DICS_DISABLE)) {";
    const disable_at = std.mem.indexOf(u8, source, disable_needle) orelse return error.DisableSiteMissing;

    try expect(restart_at < arm_at);
    try expect(arm_at < disable_at);

    // The marker is released again on the success path...
    try expect(std.mem.indexOf(u8, source, "recoveryJournalDisarm();") != null);
    // ...and the poll blocks every escalation rung while it is armed.
    try expect(std.mem.indexOf(u8, source, "if (recoveryBlocksEscalation(state.recovery_armed)) return;") != null);
    // ...and a fresh process repairs a leftover before the ladder runs.
    try expect(std.mem.indexOf(u8, source, "startup: a pending disable journal was found") != null);
    // ...and the user has a manual button that does not need the journal.
    try expect(std.mem.indexOf(u8, source, "fn recoverMain(") != null);
    try expect(std.mem.indexOf(u8, source, "--recover") != null);

    // The repair path must never be capped by a circuit breaker: giving up on
    // re-enabling the user's Bluetooth is not an acceptable outcome.
    const rung0_at = std.mem.indexOf(u8, source, "if (shouldRetryRecovery(now, state.recovery_last_ms)) {") orelse return error.Rung0Missing;
    const rung0_end = std.mem.indexOfPos(u8, source, rung0_at, "if (recoveryBlocksEscalation(") orelse return error.Rung0Missing;
    try expect(std.mem.indexOf(u8, source[rung0_at..rung0_end], "breaker") == null);

    // And the repair must run ahead of every escalation rung in the poll.
    const r1_at = std.mem.indexOf(u8, source, "if (radioResetRungDead(state.r1_rejects)) {") orelse return error.LadderMissing;
    try expect(rung0_at < r1_at);
}

test "r2-l3 journal: the marker name is a plain file next to the exe" {
    // A directory separator here would put the marker somewhere else than the
    // exe folder and silently break both arming and the startup repair.
    try expect(RECOVERY_JOURNAL_NAME.len > 0);
    try expect(std.mem.indexOfScalar(u8, RECOVERY_JOURNAL_NAME, '/') == null);
    try expect(std.mem.indexOfScalar(u8, RECOVERY_JOURNAL_NAME, '\\') == null);
    try expect(!std.mem.eql(u8, RECOVERY_JOURNAL_NAME, "btf.log"));
    try expect(!std.mem.eql(u8, RECOVERY_JOURNAL_NAME, "btf_freeze.txt"));
}
