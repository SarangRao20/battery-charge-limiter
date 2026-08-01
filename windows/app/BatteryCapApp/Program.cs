using System.Threading;

namespace BatteryCapApp;

static class Program
{
    private const string MutexName = @"Global\BatteryCapApp_{7B1E4A2C-6B3D-4F2E-9A1C-8D5E7F3B2A1C}";
    private const string ShowEventName = @"Global\BatteryCapApp_Show_{7B1E4A2C-6B3D-4F2E-9A1C-8D5E7F3B2A1C}";

    [STAThread]
    static void Main(string[] args)
    {
        if (Environment.GetCommandLineArgs().Contains("-Install"))
        {
            Installer.RunInstall();
            return;
        }
        if (Environment.GetCommandLineArgs().Contains("-Uninstall"))
        {
            Installer.RunUninstall();
            return;
        }

        using var mutex = new Mutex(true, MutexName, out bool createdNew);
        if (!createdNew)
        {
            try { new EventWaitHandle(false, EventResetMode.AutoReset, ShowEventName).Set(); }
            catch { }
            return;
        }

        ApplicationConfiguration.Initialize();
        var form = new Form1(Environment.GetCommandLineArgs().Contains("-tray"));

        using var showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ShowEventName);
        var waiter = new Thread(() =>
        {
            while (showEvent.WaitOne())
            {
                try { form.BeginInvoke(form.ShowFromTray); } catch { }
            }
        })
        { IsBackground = true };
        waiter.Start();

        Application.Run(form);
    }
}
