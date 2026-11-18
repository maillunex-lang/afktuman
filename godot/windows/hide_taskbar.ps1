param([Parameter(Mandatory=$true)][int]$TargetPid)
# Mark the game's own windows as tool windows, removing taskbar buttons.
# The Godot StatusIndicator tray icon is the only persistent entry point.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class TumanWindows {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr param);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr64(IntPtr hwnd, int index);
  [DllImport("user32.dll", EntryPoint="GetWindowLongW")] public static extern IntPtr GetWindowLong32(IntPtr hwnd, int index);
  [DllImport("user32.dll", EntryPoint="SetWindowLongPtrW")] public static extern IntPtr SetWindowLongPtr64(IntPtr hwnd, int index, IntPtr value);
  [DllImport("user32.dll", EntryPoint="SetWindowLongW")] public static extern IntPtr SetWindowLong32(IntPtr hwnd, int index, IntPtr value);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
  public static void HideFromTaskbar(uint targetPid) {
    EnumWindows((hwnd, arg) => {
      uint pid;
      GetWindowThreadProcessId(hwnd, out pid);
      if (pid != targetPid) return true;
      const int GWL_EXSTYLE = -20;
      const long WS_EX_TOOLWINDOW = 0x80, WS_EX_APPWINDOW = 0x40000;
      long style = (IntPtr.Size == 8 ? GetWindowLongPtr64(hwnd, GWL_EXSTYLE) : GetWindowLong32(hwnd, GWL_EXSTYLE)).ToInt64();
      long updated = (style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW;
      if (updated != style) {
        if (IntPtr.Size == 8) SetWindowLongPtr64(hwnd, GWL_EXSTYLE, new IntPtr(updated));
        else SetWindowLong32(hwnd, GWL_EXSTYLE, new IntPtr(updated));
        SetWindowPos(hwnd, IntPtr.Zero, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0004 | 0x0020);
      }
      return true;
    }, IntPtr.Zero);
  }
}
'@
while ($true) {
  try { $null = Get-Process -Id $TargetPid -ErrorAction Stop } catch { break }
  [TumanWindows]::HideFromTaskbar([uint32]$TargetPid)
  Start-Sleep -Seconds 2
}
