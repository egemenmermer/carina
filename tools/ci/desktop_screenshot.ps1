<#
.SYNOPSIS
  Starts carina.exe normally (no flags), waits, captures the primary screen to
  a PNG with System.Drawing (CopyFromScreen) and closes the app again.

  GitHub's Windows runners boot with a 1024x768 desktop, which is smaller than
  Carina's 1440x900 window, so the display is switched to a larger mode first.
#>
param(
  [Parameter(Mandatory)] [string] $Exe,
  [string] $OutFile = 'desktop.png',
  [int] $WaitSec = 10,
  [int] $Width = 1920,
  [int] $Height = 1080
)
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class CarinaCiDisplay {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion;
    public short dmDriverVersion;
    public short dmSize;
    public short dmDriverExtra;
    public int dmFields;
    public int dmPositionX;
    public int dmPositionY;
    public int dmDisplayOrientation;
    public int dmDisplayFixedOutput;
    public short dmColor;
    public short dmDuplex;
    public short dmYResolution;
    public short dmTTOption;
    public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels;
    public int dmBitsPerPel;
    public int dmPelsWidth;
    public int dmPelsHeight;
    public int dmDisplayFlags;
    public int dmDisplayFrequency;
    public int dmICMMethod;
    public int dmICMIntent;
    public int dmMediaType;
    public int dmDitherType;
    public int dmReserved1;
    public int dmReserved2;
    public int dmPanningWidth;
    public int dmPanningHeight;
  }

  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

  static DEVMODE NewMode() {
    var dm = new DEVMODE();
    dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
    return dm;
  }

  public static List<string> Modes() {
    var seen = new List<string>();
    var dm = NewMode();
    for (int i = 0; EnumDisplaySettings(null, i, ref dm); i++) {
      var s = dm.dmPelsWidth + "x" + dm.dmPelsHeight;
      if (!seen.Contains(s)) seen.Add(s);
    }
    return seen;
  }

  // 0 = DISP_CHANGE_SUCCESSFUL, 1 = restart needed, negative = failure.
  public static int SetResolution(int width, int height) {
    var dm = NewMode();
    if (!EnumDisplaySettings(null, -1 /* ENUM_CURRENT_SETTINGS */, ref dm)) return -100;
    dm.dmPelsWidth = width;
    dm.dmPelsHeight = height;
    dm.dmFields = 0x80000 | 0x100000; // DM_PELSWIDTH | DM_PELSHEIGHT
    return ChangeDisplaySettings(ref dm, 0);
  }
}
'@

[void][CarinaCiDisplay]::SetProcessDPIAware()
$screenW = [CarinaCiDisplay]::GetSystemMetrics(0) # SM_CXSCREEN
$screenH = [CarinaCiDisplay]::GetSystemMetrics(1) # SM_CYSCREEN
Write-Host "Primary screen: ${screenW}x${screenH}; modes: $([CarinaCiDisplay]::Modes() -join ', ')"
if ($screenW -lt $Width -or $screenH -lt $Height) {
  $result = [CarinaCiDisplay]::SetResolution($Width, $Height)
  Write-Host "ChangeDisplaySettings ${Width}x${Height} -> $result"
  if ($result -ne 0) { Write-Host "::warning::Could not switch the display to ${Width}x${Height} (code $result)" }
  Start-Sleep -Seconds 2
  $screenW = [CarinaCiDisplay]::GetSystemMetrics(0)
  $screenH = [CarinaCiDisplay]::GetSystemMetrics(1)
  Write-Host "Primary screen now: ${screenW}x${screenH}"
}

$exePath = (Resolve-Path $Exe).Path
$p = Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath) -PassThru
$null = $p.Handle
Start-Sleep -Seconds $WaitSec
if ($p.HasExited) { throw "carina.exe exited after start (exit code $($p.ExitCode))" }

$p.Refresh()
$hwnd = $p.MainWindowHandle
if ($hwnd -ne [IntPtr]::Zero) {
  [void][CarinaCiDisplay]::ShowWindow($hwnd, 9) # SW_RESTORE
  [void][CarinaCiDisplay]::SetForegroundWindow($hwnd)
  Start-Sleep -Seconds 1
} else {
  Write-Host '::warning::carina.exe has no main window handle'
}
$title = $p.MainWindowTitle
Write-Host "Carina window title: '$title'"
if ($title -notlike 'Carina*') { Write-Host "::warning::Unexpected window title '$title'" }

$bmp = [System.Drawing.Bitmap]::new($screenW, $screenH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
try {
  $g.CopyFromScreen(0, 0, 0, 0, [System.Drawing.Size]::new($screenW, $screenH))
  $outPath = Join-Path (Get-Location).Path $OutFile
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Host "Saved $outPath ($((Get-Item $outPath).Length) bytes)"
} finally {
  $g.Dispose()
  $bmp.Dispose()
  if (-not $p.HasExited) {
    [void]$p.CloseMainWindow()
    if (-not $p.WaitForExit(15000)) {
      Write-Host '::warning::carina.exe did not close on WM_CLOSE; killing it'
      try { $p.Kill($true) } catch { Write-Host "Kill failed: $_" }
    }
  }
}
Write-Host "carina.exe closed (exit code $($p.ExitCode))"
