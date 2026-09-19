//! kernel32.dll entry points and the process/event structures they use.

use super::*;

pub const CREATE_NO_WINDOW: u32 = 0x0800_0000;
pub const WAIT_OBJECT_0: u32 = 0x0000_0000;
pub const WAIT_TIMEOUT: u32 = 0x0000_0102;
pub const WAIT_FAILED: u32 = 0xFFFF_FFFF;
pub const ERROR_ALREADY_EXISTS: u32 = 183;
pub const STD_ERROR_HANDLE: u32 = 0xFFFF_FFF4;

pub const GENERIC_WRITE: u32 = 0x4000_0000;
pub const FILE_APPEND_DATA: u32 = 0x0000_0004;
pub const OPEN_ALWAYS: u32 = 4;
pub const CREATE_ALWAYS: u32 = 2;
pub const OPEN_EXISTING: u32 = 3;
pub const FILE_ATTRIBUTE_NORMAL: u32 = 0x0000_0080;
pub const FILE_SHARE_READ: u32 = 0x0000_0001;
pub const FILE_SHARE_WRITE: u32 = 0x0000_0002;
pub const FILE_SHARE_READ_WRITE: u32 = 0x0000_0003;
pub const MOVEFILE_REPLACE_EXISTING: u32 = 0x0000_0001;
pub const INVALID_FILE_ATTRIBUTES: u32 = 0xFFFF_FFFF;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct STARTUPINFOW {
    pub cb: u32,
    pub lpReserved: *mut u16,
    pub lpDesktop: *mut u16,
    pub lpTitle: *mut u16,
    pub dwX: u32,
    pub dwY: u32,
    pub dwXSize: u32,
    pub dwYSize: u32,
    pub dwXCountChars: u32,
    pub dwYCountChars: u32,
    pub dwFillAttribute: u32,
    pub dwFlags: u32,
    pub wShowWindow: u16,
    pub cbReserved2: u16,
    pub lpReserved2: *mut u8,
    pub hStdInput: HANDLE,
    pub hStdOutput: HANDLE,
    pub hStdError: HANDLE,
}

impl Default for STARTUPINFOW {
    fn default() -> Self {
        // SAFETY: all-zero is the documented "cb unset" state; the caller sets
        // `cb` to `size_of::<STARTUPINFOW>()` before use, exactly as the SDK
        // requires.
        unsafe { std::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct PROCESS_INFORMATION {
    pub hProcess: HANDLE,
    pub hThread: HANDLE,
    pub dwProcessId: u32,
    pub dwThreadId: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct PERFORMANCE_INFORMATION {
    pub cb: u32,
    pub CommitTotal: usize,
    pub CommitLimit: usize,
    pub CommitPeak: usize,
    pub PhysicalTotal: usize,
    pub PhysicalAvailable: usize,
    pub SystemCache: usize,
    pub KernelTotal: usize,
    pub KernelPaged: usize,
    pub KernelNonpaged: usize,
    pub PageSize: usize,
    pub HandleCount: u32,
    pub ProcessCount: u32,
    pub ThreadCount: u32,
}

#[link(name = "kernel32")]
unsafe extern "system" {
    pub fn CreateEventW(
        lpEventAttributes: *mut c_void,
        bManualReset: i32,
        bInitialState: i32,
        lpName: *const u16,
    ) -> HANDLE;
    pub fn SetEvent(hEvent: HANDLE) -> BOOL;
    pub fn WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: u32) -> u32;
    pub fn CloseHandle(hObject: HANDLE) -> BOOL;
    pub fn CreateFileW(
        lpFileName: *const u16,
        dwDesiredAccess: u32,
        dwShareMode: u32,
        lpSecurityAttributes: *mut c_void,
        dwCreationDisposition: u32,
        dwFlagsAndAttributes: u32,
        hTemplateFile: HANDLE,
    ) -> HANDLE;
    pub fn CreateMutexW(
        lpMutexAttributes: *mut c_void,
        bInitialOwner: i32,
        lpName: *const u16,
    ) -> HANDLE;
    pub fn ExitProcess(uExitCode: u32) -> !;
    pub fn FreeLibrary(hModule: HMODULE) -> BOOL;
    pub fn GetModuleHandleW(lpModuleName: *const u16) -> HMODULE;
    pub fn GetModuleFileNameW(hModule: HMODULE, lpFilename: *mut u16, nSize: u32) -> u32;
    pub fn LoadLibraryExW(lpLibFileName: *const u16, hFile: HANDLE, dwFlags: u32) -> HMODULE;
    pub fn SetDefaultDllDirectories(directoryFlags: u32) -> BOOL;
    pub fn GetProcAddress(hModule: HMODULE, lpProcName: *const u8) -> FARPROC;
    pub fn Sleep(dwMilliseconds: u32);
    pub fn CreateProcessW(
        lpApplicationName: *const u16,
        lpCommandLine: *mut u16,
        lpProcessAttributes: *mut c_void,
        lpThreadAttributes: *mut c_void,
        bInheritHandles: i32,
        dwCreationFlags: u32,
        lpEnvironment: *mut c_void,
        lpCurrentDirectory: *const u16,
        lpStartupInfo: *mut STARTUPINFOW,
        lpProcessInformation: *mut PROCESS_INFORMATION,
    ) -> BOOL;
    pub fn GetLastError() -> u32;
    pub fn OutputDebugStringA(lpOutputString: *const u8);
    pub fn GetExitCodeProcess(hProcess: HANDLE, lpExitCode: *mut u32) -> BOOL;
    pub fn GetStdHandle(nStdHandle: u32) -> HANDLE;
    pub fn WriteFile(
        hFile: HANDLE,
        lpBuffer: *const u8,
        nNumberOfBytesToWrite: u32,
        lpNumberOfBytesWritten: *mut u32,
        lpOverlapped: *mut c_void,
    ) -> BOOL;
    pub fn GetSystemDirectoryW(lpBuffer: *mut u16, uSize: u32) -> u32;
    pub fn GetFileSizeEx(hFile: HANDLE, lpFileSize: *mut i64) -> BOOL;
    pub fn FlushFileBuffers(hFile: HANDLE) -> BOOL;
    pub fn DeleteFileW(lpFileName: *const u16) -> BOOL;
    pub fn MoveFileExW(
        lpExistingFileName: *const u16,
        lpNewFileName: *const u16,
        dwFlags: u32,
    ) -> BOOL;
    pub fn GetFileAttributesW(lpFileName: *const u16) -> u32;
    pub fn GetLocalTime(lpSystemTime: *mut SYSTEMTIME);
    pub fn GetTickCount64() -> u64;
    pub fn K32GetPerformanceInfo(
        pPerformanceInformation: *mut PERFORMANCE_INFORMATION,
        cb: u32,
    ) -> BOOL;
    pub fn DeviceIoControl(
        hDevice: HANDLE,
        dwIoControlCode: u32,
        lpInBuffer: *const c_void,
        nInBufferSize: u32,
        lpOutBuffer: *mut c_void,
        nOutBufferSize: u32,
        lpBytesReturned: *mut u32,
        lpOverlapped: *mut c_void,
    ) -> BOOL;
}
