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

extern "kernel32" fn TerminateProcess(hProcess: ?*anyopaque, uExitCode: u32) callconv(WINAPI) i32;

extern "kernel32" fn ExitProcess(uExitCode: u32) callconv(WINAPI) noreturn;

extern "kernel32" fn FreeLibrary(hModule: ?*anyopaque) callconv(WINAPI) i32;

extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(WINAPI) ?*anyopaque;

extern "kernel32" fn GetModuleFileNameW(
    hModule: ?*anyopaque,
    lpFilename: [*:0]u16,
    nSize: u32,
) callconv(WINAPI) u32;

extern "kernel32" fn LoadLibraryW(lpLibFileName: [*:0]const u16) callconv(WINAPI) ?*anyopaque;

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
const WAVERR_STILLPLAYING: u32 = 33;

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

extern "user32" fn GetWindowLongPtrW(
    hWnd: ?*anyopaque,
    nIndex: i32,
) callconv(WINAPI) isize;

extern "user32" fn SetWindowLongPtrW(
    hWnd: ?*anyopaque,
    nIndex: i32,
    dwNewLong: isize,
) callconv(WINAPI) isize;

// ---------------------------------------------------------------------------
// Debug logging helper
// ---------------------------------------------------------------------------
fn debug(comptime fmt: []const u8, args: anytype) void {
    if (!builtin.is_test) {
        var buf: [4096]u8 = undefined;
        const prefix = "btf: ";
        const suffix = "\r\n";
        const max_body = buf.len - prefix.len - suffix.len;
        @memcpy(buf[0..prefix.len], prefix);
        const body = std.fmt.bufPrint(buf[prefix.len .. prefix.len + max_body], fmt, args) catch {
            return;
        };
        const total_len = prefix.len + body.len + suffix.len;
        @memcpy(buf[prefix.len + body.len .. total_len], suffix);
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
    const module = LoadLibraryW(&[_:0]u16{ 'b', 't', 'h', 'p', 'r', 'o', 'p', 's', '.', 'c', 'p', 'l' }) orelse return error.BthCplNotFound;
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

const WINDOW_CLASS_NAME: [*:0]const u16 = &[_:0]u16{ 'B', 't', 'F', 'o', 'r', 'c', 'e', 'W', 'i', 'n', 'd', 'o', 'w' };
const WINDOW_TITLE: [*:0]const u16 = &[_:0]u16{ 'B', 't', 'F', 'o', 'r', 'c', 'e' };

// ---------------------------------------------------------------------------
// Silent audio keepalive — prevents BT earbuds idle-disconnect
// ---------------------------------------------------------------------------
const KEEPALIVE_BUF_SIZE: u16 = 8192;

const SilentKeepalive = struct {
    hwo: ?*anyopaque,
    thread: ?std.Thread,
    running: std.atomic.Value(bool),
    silence_buf: [KEEPALIVE_BUF_SIZE]u8,

    fn init() SilentKeepalive {
        return SilentKeepalive{
            .hwo = null,
            .thread = null,
            .running = std.atomic.Value(bool).init(false),
            .silence_buf = [_]u8{0} ** KEEPALIVE_BUF_SIZE,
        };
    }

    fn start(self: *SilentKeepalive) void {
        if (self.running.load(.acquire)) return;
        self.running.store(true, .release);
        self.thread = std.Thread.spawn(.{}, run, .{self}) catch |err| {
            debug("btf: keepalive thread spawn failed: {s}", .{@errorName(err)});
            self.running.store(false, .release);
            return;
        };
    }

    fn stop(self: *SilentKeepalive) void {
        if (!self.running.load(.acquire)) return;
        self.running.store(false, .release);
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    fn run(self: *SilentKeepalive) void {
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
        if (waveOutOpen(&hwo, WAVE_MAPPER, &fmt, 0, 0, CALLBACK_NULL) != 0) {
            self.running.store(false, .release);
            return;
        }
        self.hwo = hwo;

        var hdr = WAVEHDR{
            .lpData = @ptrCast(&self.silence_buf),
            .dwBufferLength = KEEPALIVE_BUF_SIZE,
            .dwBytesRecorded = 0,
            .dwUser = 0,
            .dwFlags = 0,
            .dwLoops = 0,
            .lpNext = null,
            .reserved = 0,
        };

        if (waveOutPrepareHeader(hwo, &hdr, @sizeOf(WAVEHDR)) != 0) {
            _ = waveOutClose(hwo);
            self.running.store(false, .release);
            return;
        }

        _ = waveOutWrite(hwo, &hdr, @sizeOf(WAVEHDR));

        while (self.running.load(.acquire)) {
            Sleep(60);
            if (hdr.dwFlags & WHDR_DONE != 0) {
                _ = waveOutUnprepareHeader(hwo, &hdr, @sizeOf(WAVEHDR));
                hdr.dwFlags = 0;
                if (waveOutPrepareHeader(hwo, &hdr, @sizeOf(WAVEHDR)) != 0) break;
                const rc2 = waveOutWrite(hwo, &hdr, @sizeOf(WAVEHDR));
                if (rc2 != 0) {
                    _ = waveOutUnprepareHeader(hwo, &hdr, @sizeOf(WAVEHDR));
                    break;
                }
            }
        }

        while (hdr.dwFlags & WHDR_DONE == 0) Sleep(10);
        _ = waveOutUnprepareHeader(hwo, &hdr, @sizeOf(WAVEHDR));
        _ = waveOutClose(hwo);
        self.hwo = null;
        self.running.store(false, .release);
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

fn getSelfDir(buf: []u8) ![]u8 {
    var self_path_w: [2048:0]u16 = undefined;
    const len = GetModuleFileNameW(null, &self_path_w, @as(u32, self_path_w.len));
    if (len == 0) return error.ToothTraySpawnFailed;
    const utf8_len = try std.unicode.utf16LeToUtf8(buf, self_path_w[0..len]);
    const src = buf[0..utf8_len];
    const dir_end = std.mem.lastIndexOfScalar(u8, src, '\\') orelse return error.ToothTraySpawnFailed;
    return buf[0 .. dir_end + 1];
}

fn triggerConnectionViaToothTray(device_name: []const u8) !void {
    // Resolve directory of bluetooth_force.exe (ToothTray.exe sits next to it)
    var dir_buf: [4096]u8 = undefined;
    const dir_part = try getSelfDir(&dir_buf);

    const cmdline_u8 = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "\"{s}ToothTray.exe\" connect \"{s}\"",
        .{ dir_part, device_name },
    );
    defer std.heap.page_allocator.free(cmdline_u8);

    if (cmdline_u8.len > 2046) {
        debug("  cmdline too long: {} bytes", .{cmdline_u8.len});
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
        debug("  CreateProcessW failed: 0x{x}", .{GetLastError()});
        return error.ToothTraySpawnFailed;
    }
    defer _ = CloseHandle(pi.hProcess);
    defer _ = CloseHandle(pi.hThread);

    // Wait for ToothTray to finish. No TerminateProcess — killing the process mid-IOCTL
    // can leave the BT driver in an inconsistent state requiring adapter re-plug.
    const wait_res = WaitForSingleObject(pi.hProcess, 15000);
    if (wait_res != WAIT_OBJECT_0) {
        debug("  ToothTrayCli: wait result=0x{x} (not killed, will retry next poll)", .{wait_res});
        return error.ToothTrayFailed;
    }

    var exit_code: u32 = 0;
    _ = GetExitCodeProcess(pi.hProcess, &exit_code);

    if (exit_code == 0) {
        debug("  ToothTrayCli: connect OK", .{});
    } else {
        debug("  ToothTrayCli: connect failed with exit code {}", .{exit_code});
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
                debug("btf: resume event fired", .{});
                if (!state.running.load(.acquire)) break;
                debug("btf: resume delay 3s", .{});
                Sleep(RESUME_DELAY_MS);
                if (!state.running.load(.acquire)) break;
            },
            WAIT_TIMEOUT => {},
            WAIT_FAILED => {
                debug("btf: WaitForSingleObject FAILED", .{});
                break;
            },
            else => {
                debug("btf: unexpected wait result=0x{x}", .{wait_result});
                break;
            },
        }

        if (!state.running.load(.acquire)) break;

        poll_count += 1;
        performPoll(state, poll_count) catch |e| {
            debug("btf: performPoll error: {s}", .{@errorName(e)});
            continue;
        };
    }
    debug("btf: worker exiting", .{});
}

fn performPoll(state: *SharedState, poll_count: u32) !void {
    var radio_params = BLUETOOTH_FIND_RADIO_PARAMS{ .dwSize = @sizeOf(BLUETOOTH_FIND_RADIO_PARAMS) };

    var radio_handle: ?*anyopaque = null;
    const radio_find = state.bth.BluetoothFindFirstRadio(&radio_params, &radio_handle);
    debug("btf: [#{}] BluetoothFindFirstRadio → rf={any}", .{ poll_count, radio_find });
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
        debug("btf: [#{}] BluetoothFindFirstDevice → find={any}", .{ poll_count, device_find });
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
            var name_buf: [1024]u8 = undefined;
            var utf16_len: usize = 0;
            while (utf16_len < 248 and device_info.szName[utf16_len] != 0) : (utf16_len += 1) {}
            const name_len = std.unicode.utf16LeToUtf8(name_buf[0..], device_info.szName[0..utf16_len]) catch |err| {
                debug("btf: [#{}] utf16 conversion error: {s}", .{ poll_count, @errorName(err) });
                return;
            };
            debug("btf: [#{}] found '{s}', connected={}, remembered={}, authenticated={}", .{
                poll_count, name_buf[0..name_len],
                device_info.fConnected,
                device_info.fRemembered,
                device_info.fAuthenticated,
            });

            if (device_info.fConnected != 0) {
                debug("btf: [#{}] already connected — nothing to do", .{poll_count});
                state.silent.start();
                return;
            }

            state.silent.stop();
            debug("btf: [#{}] not connected → launching ToothTrayCli connect", .{poll_count});
            triggerConnectionViaToothTray(name_buf[0..name_len]) catch |e| {
                debug("btf: [#{}] ToothTrayCli error: {s}", .{ poll_count, @errorName(e) });
            };
            return;
        }

        radio_handle = null;
        if (state.bth.BluetoothFindNextRadio(radio_find, &radio_handle) == 0) break;
    }

    debug("btf: [#{}] device not found on any radio", .{poll_count});
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
        WM_POWERBROADCAST => {
            if (wParam == PBT_APMRESUMEAUTOMATIC) {
                const userdata = GetWindowLongPtrW(hWnd, GWLP_USERDATA);
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
    var args_it = try init.args.iterateAllocator(std.heap.page_allocator);
    defer args_it.deinit();

    _ = args_it.next() orelse exitWithError("Usage: bluetooth_force.exe AA:BB:CC:DD:EE:FF");
    const mac_str = args_it.next() orelse exitWithError("Usage: bluetooth_force.exe AA:BB:CC:DD:EE:FF");
    const target_mac = parseMacAddr(mac_str) catch exitWithError("Invalid MAC address format");

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
    };

    const thread = try std.Thread.spawn(.{}, workerThread, .{&shared});
    defer {
        shared.silent.stop();
        shared.running.store(false, .release);
        _ = SetEvent(resume_event);
        thread.join();
    }

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

    const hwnd = CreateWindowExW(
        WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        WINDOW_CLASS_NAME,
        WINDOW_TITLE,
        WS_POPUP,
        0, 0, 0, 0,
        null, null, hinstance, null,
    ) orelse exitWithError("CreateWindowExW failed");

    defer _ = DestroyWindow(hwnd);

    _ = SetWindowLongPtrW(hwnd, GWLP_USERDATA, @bitCast(@intFromPtr(&shared)));

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

test "SharedState alignment" {
    const ss = SharedState{
        .running = std.atomic.Value(bool).init(true),
        .target_mac = 0xAABBCCDDEEFF,
        .resume_event = null,
        .bth = undefined,
        .silent = undefined,
    };
    try expectEqual(@as(u64, 0xAABBCCDDEEFF), ss.target_mac);
    try expectEqual(true, ss.running.load(.acquire));
}
