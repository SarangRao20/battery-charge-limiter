namespace BatteryCapApp;

static class Program
{
    [STAThread]
    static void Main()
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
        ApplicationConfiguration.Initialize();
        Application.Run(new Form1());
    }
}
