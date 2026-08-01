using System.Diagnostics;
using System.Runtime.InteropServices;

namespace BatteryCapApp;

public static class Installer
{
    private const string Dest = @"C:\EC-Tool";
    private const string TaskName = "Battery80Cap";
    private const string SvcName = "WinRing0_1_2_0";
    private const string EcTool = @"C:\EC-Tool\EC-Access-Tool.exe";
    private const string DaemonPath = @"C:\EC-Tool\daemon.ps1";
    private const string WinRing0Sys = @"C:\EC-Tool\WinRing0x64.sys";

    public static void RunInstall()
    {
        EnsureElevated();
        Console.WriteLine("=== Battery Charge Limiter Setup ===");

        if (!File.Exists(EcTool) || !File.Exists(WinRing0Sys) || !File.Exists(DaemonPath))
        {
            Console.Error.WriteLine("Required files not found in C:\\EC-Tool. Run the installer (BatteryCapSetup.exe) first.");
            Pause();
            return;
        }

        if (!Directory.Exists(Dest)) Directory.CreateDirectory(Dest);
        AddDefenderExclusion();

        Console.WriteLine("[1/4] Installing driver...");
        if (!StartService(SvcName))
        {
            Run("sc.exe", $"create {SvcName} type= kernel start= auto binPath= \"{WinRing0Sys}\"");
            Run("sc.exe", $"start {SvcName}");
            Thread.Sleep(1000);
            if (!StartService(SvcName))
            {
                Console.Error.WriteLine("WinRing0 service could not be started.");
                Pause();
                return;
            }
        }
        Console.WriteLine("Driver OK");

        Console.WriteLine("[2/4] Registering scheduled task...");
        var task = "powershell.exe";
        var args = $"-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"{DaemonPath}\"";
        Run("schtasks.exe",
            $"/Create /TN \"{TaskName}\" /TR \"\\\"{task}\\\" {args}\" /SC ONLOGON /RL HIGHEST /F");
        Console.WriteLine("Task OK");

        Console.WriteLine("[3/4] Testing EC access...");
        var test = RunCapture(EcTool, "-winring0 -r 76");
        Console.WriteLine(test.Trim().Length == 0 ? "EC read empty" : $"EC reg 0x76 = {test.Trim()}");

        Console.WriteLine("[4/4] Launching daemon...");
        Run("powershell.exe", $"-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"{DaemonPath}\"");
        Console.WriteLine("Daemon running in system tray.");
        Pause();
    }

    public static void RunUninstall()
    {
        EnsureElevated();
        Console.WriteLine("=== Battery Charge Limiter Uninstall ===");

        Console.WriteLine("Stopping daemon...");
        Run("powershell.exe", "-NoProfile -Command \"Get-CimInstance Win32_Process | Where-Object {$_.CommandLine -like '*daemon.ps1*'} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }\"");

        Console.WriteLine("Removing scheduled task...");
        Run("schtasks.exe", $"/Delete /TN \"{TaskName}\" /F");

        Console.WriteLine("Removing driver service...");
        Run("sc.exe", $"stop {SvcName}");
        Thread.Sleep(500);
        Run("sc.exe", $"delete {SvcName}");

        Console.WriteLine("Uninstall complete. (Files in C:\\EC-Tool can be removed manually.)");
        Pause();
    }

    private static void EnsureElevated()
    {
        var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
        var principal = new System.Security.Principal.WindowsPrincipal(identity);
        bool isAdmin = principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
        if (!isAdmin)
        {
            Console.WriteLine("Administrator privileges required. Launching elevated...");
            Process.Start(new ProcessStartInfo
            {
                FileName = Environment.ProcessPath!,
                Arguments = string.Join(' ', Environment.GetCommandLineArgs().Skip(1)),
                Verb = "runas",
                UseShellExecute = true
            });
            Environment.Exit(0);
        }
    }

    private static void AddDefenderExclusion()
    {
        Run("powershell.exe", $"-NoProfile -Command \"Add-MpPreference -ExclusionPath '{Dest}' -ErrorAction SilentlyContinue\"");
    }

    private static bool StartService(string name)
    {
        var svc = RunCapture("sc.exe", $"query {name}");
        return svc.Contains("RUNNING", StringComparison.OrdinalIgnoreCase);
    }

    private static void Run(string exe, string args)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = exe,
                Arguments = args,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            });
        }
        catch { }
    }

    private static string RunCapture(string exe, string args)
    {
        try
        {
            var p = Process.Start(new ProcessStartInfo
            {
                FileName = exe,
                Arguments = args,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            });
            if (p == null) return "";
            var outStr = p.StandardOutput.ReadToEnd();
            p.WaitForExit();
            return outStr;
        }
        catch { return ""; }
    }

    private static void Pause()
    {
        Console.WriteLine("Press any key to exit...");
        try { Console.ReadKey(true); } catch { }
    }
}
