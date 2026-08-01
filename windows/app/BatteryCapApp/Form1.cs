namespace BatteryCapApp;

public partial class Form1 : Form
{
    private readonly System.Windows.Forms.Timer _timer;
    private readonly Label _batteryLabel;
    private readonly Label _batteryPct;
    private readonly Panel _ring;
    private readonly Label _healthValue;
    private readonly Label _ecValue;
    private readonly Label _acValue;
    private readonly Label _daemonValue;
    private readonly Button _installBtn;
    private readonly Button _uninstallBtn;
    private readonly Button _daemonBtn;
    private readonly Label _statusPill;

    private const string EcTool = @"C:\EC-Tool\EC-Access-Tool.exe";
    private const string DaemonPath = @"C:\EC-Tool\daemon.ps1";

    public Form1()
    {
        Text = "Battery Charge Limiter";
        ClientSize = new Size(420, 560);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(18, 20, 24);
        ForeColor = Color.FromArgb(230, 235, 240);

        var header = new Label
        {
            Text = "🔋 Battery Charge Limiter",
            Font = new Font("Segoe UI", 15, FontStyle.Bold),
            ForeColor = Color.FromArgb(80, 200, 120),
            AutoSize = true,
            Location = new Point(28, 24)
        };

        _statusPill = new Label
        {
            AutoSize = true,
            Font = new Font("Segoe UI", 9, FontStyle.Bold),
            Padding = new Padding(10, 4, 10, 4),
            Location = new Point(28, 58)
        };
        SetPill("AUTO", Color.FromArgb(30, 40, 32), Color.FromArgb(80, 200, 120));

        var sub = new Label
        {
            Text = "80% charge cap · EC register 0x76",
            ForeColor = Color.FromArgb(140, 150, 160),
            Font = new Font("Segoe UI", 9),
            AutoSize = true,
            Location = new Point(28, 90)
        };

        _batteryLabel = new Label
        {
            Text = "BATTERY",
            ForeColor = Color.FromArgb(140, 150, 160),
            Font = new Font("Segoe UI", 10, FontStyle.Bold),
            AutoSize = true,
            Location = new Point(28, 130)
        };
        _batteryPct = new Label
        {
            Text = "--%",
            Font = new Font("Segoe UI", 42, FontStyle.Bold),
            ForeColor = Color.FromArgb(230, 235, 240),
            AutoSize = true,
            Location = new Point(28, 145)
        };

        _ring = new Panel
        {
            Size = new Size(130, 130),
            Location = new Point(250, 120)
        };
        _ring.Paint += RingPaint;

        var healthCard = MakeCard("HEALTH", 30, 300);
        _healthValue = MakeCardValue(healthCard, "--");

        var ecCard = MakeCard("EC REGISTER", 150, 300);
        _ecValue = MakeCardValue(ecCard, "--");

        var acCard = MakeCard("POWER", 270, 300);
        _acValue = MakeCardValue(acCard, "--");

        var daemonCard = MakeCard("DAEMON", 30, 390);
        _daemonValue = MakeCardValue(daemonCard, "--");

        _installBtn = MakeButton("Install", 30, 470, Color.FromArgb(80, 200, 120));
        _uninstallBtn = MakeButton("Uninstall", 155, 470, Color.FromArgb(220, 90, 90));
        _daemonBtn = MakeButton("Daemon", 280, 470, Color.FromArgb(70, 110, 180));

        Controls.AddRange(new Control[]
        {
            header, _statusPill, sub, _batteryLabel, _batteryPct, _ring,
            healthCard, ecCard, acCard, daemonCard,
            _installBtn, _uninstallBtn, _daemonBtn
        });

        _installBtn.Click += (_, _) => RunElevated("-Install");
        _uninstallBtn.Click += (_, _) => RunElevated("-Uninstall");
        _daemonBtn.Click += (_, _) => ToggleDaemon();

        _timer = new System.Windows.Forms.Timer { Interval = 3000 };
        _timer.Tick += (_, _) => RefreshStatus();
        _timer.Start();
        RefreshStatus();
    }

    private void SetPill(string text, Color bg, Color fg)
    {
        _statusPill.Text = text;
        _statusPill.BackColor = bg;
        _statusPill.ForeColor = fg;
    }

    private Panel MakeCard(string title, int x, int y)
    {
        var card = new Panel
        {
            Size = new Size(105, 75),
            Location = new Point(x, y),
            BackColor = Color.FromArgb(26, 30, 36)
        };
        var t = new Label
        {
            Text = title,
            Font = new Font("Segoe UI", 8, FontStyle.Bold),
            ForeColor = Color.FromArgb(140, 150, 160),
            AutoSize = true,
            Location = new Point(12, 8)
        };
        card.Controls.Add(t);
        return card;
    }

    private Label MakeCardValue(Panel card, string initial)
    {
        var v = new Label
        {
            Text = initial,
            Font = new Font("Segoe UI", 14, FontStyle.Bold),
            ForeColor = Color.FromArgb(230, 235, 240),
            AutoSize = true,
            Location = new Point(12, 34)
        };
        card.Controls.Add(v);
        return v;
    }

    private Button MakeButton(string text, int x, int y, Color accent)
    {
        var b = new Button
        {
            Text = text,
            Size = new Size(110, 38),
            Location = new Point(x, y),
            FlatStyle = FlatStyle.Flat,
            BackColor = accent,
            ForeColor = Color.FromArgb(20, 22, 26),
            Font = new Font("Segoe UI", 10, FontStyle.Bold),
            Cursor = Cursors.Hand
        };
        b.FlatAppearance.BorderSize = 0;
        return b;
    }

    private void RingPaint(object? sender, PaintEventArgs e)
    {
        int pct;
        if (!int.TryParse(_batteryPct.Text.Replace("%", ""), out pct)) pct = 0;
        pct = Math.Clamp(pct, 0, 100);

        var rect = new Rectangle(5, 5, 120, 120);
        using var track = new Pen(Color.FromArgb(40, 46, 54), 10);
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        e.Graphics.DrawArc(track, rect, 0, 360);

        var color = pct <= 80 ? Color.FromArgb(80, 200, 120) : Color.FromArgb(220, 90, 90);
        using var fill = new Pen(color, 10);
        e.Graphics.DrawArc(fill, rect, -90, (int)(pct * 3.6));

        var text = $"{pct}%";
        using var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
        using var font = new Font("Segoe UI", 20, FontStyle.Bold);
        using var brush = new SolidBrush(Color.FromArgb(230, 235, 240));
        e.Graphics.DrawString(text, font, brush, rect, sf);
    }

    private void RefreshStatus()
    {
        try
        {
            var battery = GetBatteryInfo();
            _batteryPct.Text = $"{battery.Charge}%";
            _healthValue.Text = battery.Health >= 0 ? $"{battery.Health}%" : "n/a";
            _acValue.Text = battery.OnAc ? "AC" : "Battery";
            _ring.Invalidate();

            string ec = "n/a";
            if (File.Exists(EcTool))
            {
                try
                {
                    var proc = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = EcTool,
                        Arguments = "-winring0 -r 76",
                        RedirectStandardOutput = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    })!;
                    ec = proc.StandardOutput.ReadToEnd().Trim();
                    proc.WaitForExit();
                }
                catch { }
            }
            _ecValue.Text = ec;

            bool daemonRunning = File.Exists(DaemonPath) && DaemonAlive();
            _daemonValue.Text = daemonRunning ? "Running" : "Stopped";
            _daemonValue.ForeColor = daemonRunning ? Color.FromArgb(80, 200, 120) : Color.FromArgb(220, 120, 90);
            _daemonBtn.Text = daemonRunning ? "Stop" : "Start";
        }
        catch { }
    }

    private bool DaemonAlive()
    {
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = "-NoProfile -Command \"[bool](Get-CimInstance Win32_Process -Filter \\\"Name='powershell.exe'\\\" | Where-Object { $_.CommandLine -like '*daemon.ps1*' })\"",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            var proc = System.Diagnostics.Process.Start(psi)!;
            var line = proc.StandardOutput.ReadToEnd().Trim();
            proc.WaitForExit();
            return line.StartsWith("True");
        }
        catch { return false; }
    }

    private (int Charge, int Health, bool OnAc) GetBatteryInfo()
    {
        int charge = -1, health = -1;
        bool onAc = false;
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = "-NoProfile -Command \"$b=Get-CimInstance Win32_Battery; $d=(Get-CimInstance Win32_PortableBattery -ErrorAction SilentlyContinue).DesignCapacity; $f=(Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue).FullChargedCapacity; $h=-1; if($d -and $f){$h=[math]::Round(($f/$d)*100)}; '{0}|{1}|{2}' -f $b.EstimatedChargeRemaining,$h,$([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus)\"",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            var proc = System.Diagnostics.Process.Start(psi)!;
            var line = proc.StandardOutput.ReadToEnd().Trim();
            proc.WaitForExit();
            var parts = line.Split('|');
            if (parts.Length == 3)
            {
                int.TryParse(parts[0], out charge);
                int.TryParse(parts[1], out health);
                onAc = parts[2] == "1" || parts[2] == "2";
            }
        }
        catch { }
        return (charge, health, onAc);
    }

    private void RunElevated(string arg)
    {
        var exe = Environment.ProcessPath!;
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = exe,
                Arguments = arg,
                Verb = "runas",
                UseShellExecute = true
            });
        }
        catch { }
    }

    private void ToggleDaemon()
    {
        if (_daemonValue.Text == "Running")
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = "-NoProfile -Command \"Get-CimInstance Win32_Process | Where-Object {$_.CommandLine -like '*daemon.ps1*'} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }\"",
                UseShellExecute = false,
                CreateNoWindow = true
            });
        }
        else
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = $"-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File {DaemonPath}",
                WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden,
                UseShellExecute = true
            });
        }
        Thread.Sleep(1000);
        RefreshStatus();
    }
}
