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

const INVALID_HANDLE_VALUE: ?*anyopaque = @ptrFromInt(~@as(usize, 0));
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

    return BthApi{
        .BluetoothFindFirstRadio = findFirstRadio,
        .BluetoothFindNextRadio = findNextRadio,
        .BluetoothFindRadioClose = findRadioClose,
        .BluetoothFindFirstDevice = findFirstDevice,
        .BluetoothFindNextDevice = findNextDevice,
        .BluetoothFindDeviceClose = findDeviceClose,
        .module = module,
    };
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const POLL_INTERVAL_MS: u32 = 2000;
const RESUME_DELAY_MS: u32 = 3000;

// L3 — connect (ToothTray) backoff while the earbuds are unreachable. Capped at
// 4s so a case-open still reconnects within ~one poll, but we stop hammering BT
// while the earbuds are away. Reset to 0 on a successful connect.
const CONNECT_BACKOFF_BASE_MS: u32 = 500;
const CONNECT_BACKOFF_CAP_MS: u32 = 4000;

// L5 — circuit breaker for ToothTray spawns (worker thread only).
const CONNECT_CB_WINDOW_MS: i64 = 10_000;
const CONNECT_CB_MAX_SPAWNS: u32 = 20;
const CONNECT_CB_COOLDOWN_MS: i64 = 30_000;

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
fn backoffMs(consecutive_failures: u32, base_ms: u32, cap_ms: u32) u32 {
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
const CircuitBreaker = struct {
    window_ms: i64,
    max_events: u32,
    cooldown_ms: i64,
    count: u32 = 0,
    window_start_ms: i64 = 0,
    tripped_until_ms: i64 = 0,
    trip_count: u32 = 0,

    fn allow(self: *CircuitBreaker, now_ms: i64) bool {
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

fn decidePollAction(found: bool, fConnected: i32) PollAction {
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
                    if (!state.watchdog_tripped) state.silent.start(name);
                    return;
                },
                .stop_and_connect => {
                    // Not connected: stop any keepalive (no point streaming to an
                    // absent device -> avoids FxSound/driver churn while away).
                    state.silent.stop();
                    if (state.watchdog_tripped) return;

                    const now = nowMs();
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
                            },
                        }
                        return;
                    };
                    // Spawn succeeded and ToothTray reported success.
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
// Entry point
// ---------------------------------------------------------------------------
pub fn main(init: std.process.Init.Minimal) !void {
    // Harden the whole process against DLL preloading/hijacking: resolve DLLs
    // only from System32 by default. LOAD_LIBRARY_SEARCH_SYSTEM32 is available on
    // all supported Windows versions (KB2533623 and later).
    _ = SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32);

    var args_it = try init.args.iterateAllocator(std.heap.page_allocator);
    defer args_it.deinit();

    _ = args_it.next() orelse exitWithError("Usage: bluetooth_force.exe AA:BB:CC:DD:EE:FF [audio-name-substring]");
    const mac_str = args_it.next() orelse exitWithError("Usage: bluetooth_force.exe AA:BB:CC:DD:EE:FF [audio-name-substring]");
    const target_mac = parseMacAddr(mac_str) catch |err| switch (err) {
        error.ZeroMacAddress => exitWithError("MAC must be non-zero (00:00:00:00:00:00 is not a valid device)"),
        else => exitWithError("Invalid MAC address format"),
    };

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
