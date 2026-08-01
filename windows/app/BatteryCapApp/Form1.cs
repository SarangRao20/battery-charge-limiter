namespace BatteryCapApp;

public partial class Form1 : Form
{
    private readonly System.Windows.Forms.Timer _timer;
    private readonly Label _batteryPct;
    private readonly Panel _ring;
    private readonly Label _healthValue;
    private readonly Label _ecValue;
    private readonly Label _ecMode;
    private readonly Label _acValue;
    private readonly Label _cycleValue;
    private readonly Label _fullValue;
    private readonly Label _designValue;
    private readonly Label _runtimeValue;
    private readonly Label _daemonValue;
    private readonly Label _statusPill;
    private readonly Button _daemonBtn;

    private const string EcTool = @"C:\EC-Tool\EC-Access-Tool.exe";
    private const string DaemonPath = @"C:\EC-Tool\daemon.ps1";

    public Form1()
    {
        Text = "Battery Charge Limiter";
        ClientSize = new Size(460, 600);
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
            Location = new Point(28, 20)
        };

        _statusPill = new Label
        {
            AutoSize = true,
            Font = new Font("Segoe UI", 9, FontStyle.Bold),
            Padding = new Padding(10, 4, 10, 4),
            Location = new Point(28, 54)
        };
        SetPill("—", Color.FromArgb(30, 40, 32), Color.FromArgb(80, 200, 120));

        var sub = new Label
        {
            Text = "80% charge cap · EC register 0x76",
            ForeColor = Color.FromArgb(140, 150, 160),
            Font = new Font("Segoe UI", 9),
            AutoSize = true,
            Location = new Point(28, 86)
        };

        _batteryPct = new Label
        {
            Text = "--%",
            Font = new Font("Segoe UI", 40, FontStyle.Bold),
            ForeColor = Color.FromArgb(230, 235, 240),
            AutoSize = true,
            Location = new Point(32, 125)
        };

        var batterySub = new Label
        {
            Text = "BATTERY",
            ForeColor = Color.FromArgb(140, 150, 160),
            Font = new Font("Segoe UI", 9, FontStyle.Bold),
            AutoSize = true,
            Location = new Point(32, 180)
        };

        _ring = new Panel
        {
            Size = new Size(120, 120),
            Location = new Point(250, 110)
        };
        _ring.Paint += RingPaint;

        var healthCard = MakeCard("HEALTH", 30, 290);
        _healthValue = MakeCardValue(healthCard, "--");

        var ecCard = MakeCard("EC REG", 170, 290);
        _ecValue = MakeCardValue(ecCard, "--");
        _ecMode = MakeCardSub(ecCard, "");

        var acCard = MakeCard("POWER", 310, 290);
        _acValue = MakeCardValue(acCard, "--");

        var cycleCard = MakeCard("CYCLES", 30, 380);
        _cycleValue = MakeCardValue(cycleCard, "--");

        var fullCard = MakeCard("FULL CAP", 170, 380);
        _fullValue = MakeCardValue(fullCard, "--");

        var designCard = MakeCard("DESIGN", 310, 380);
        _designValue = MakeCardValue(designCard, "--");

        var daemonCard = MakeCard("DAEMON", 30, 470);
        _daemonValue = MakeCardValue(daemonCard, "--");
        _runtimeValue = MakeCardSub(daemonCard, "");

        _daemonBtn = MakeButton("Daemon", 170, 550, Color.FromArgb(70, 110, 180));

        Controls.AddRange(new Control[]
        {
            header, _statusPill, sub, _batteryPct, batterySub, _ring,
            healthCard, ecCard, acCard, cycleCard, fullCard, designCard, daemonCard,
            _daemonBtn
        });

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
            Size = new Size(130, 80),
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
            Font = new Font("Segoe UI", 13, FontStyle.Bold),
            ForeColor = Color.FromArgb(230, 235, 240),
            AutoSize = false,
            AutoEllipsis = true,
            Size = new Size(106, 24),
            TextAlign = ContentAlignment.MiddleLeft,
            Location = new Point(12, 28)
        };
        card.Controls.Add(v);
        return v;
    }

    private Label MakeCardSub(Panel card, string initial)
    {
        var v = new Label
        {
            Text = initial,
            Font = new Font("Segoe UI", 8),
            ForeColor = Color.FromArgb(150, 160, 170),
            AutoSize = false,
            AutoEllipsis = true,
            Size = new Size(106, 18),
            TextAlign = ContentAlignment.MiddleLeft,
            Location = new Point(12, 54)
        };
        card.Controls.Add(v);
        return v;
    }

    private Button MakeButton(string text, int x, int y, Color accent)
    {
        var b = new Button
        {
            Text = text,
            Size = new Size(120, 38),
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

        var rect = new Rectangle(5, 5, 110, 110);
        using var track = new Pen(Color.FromArgb(40, 46, 54), 10);
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        e.Graphics.DrawArc(track, rect, 0, 360);

        var color = pct <= 80 ? Color.FromArgb(80, 200, 120) : Color.FromArgb(220, 90, 90);
        using var fill = new Pen(color, 10);
        e.Graphics.DrawArc(fill, rect, -90, (int)(pct * 3.6));

        var text = $"{pct}%";
        using var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
        using var font = new Font("Segoe UI", 18, FontStyle.Bold);
        using var brush = new SolidBrush(Color.FromArgb(230, 235, 240));
        e.Graphics.DrawString(text, font, brush, rect, sf);
    }

    private void RefreshStatus()
    {
        try
        {
            var b = GetBatteryInfo();
            if (b.Charge >= 0) _batteryPct.Text = $"{b.Charge}%";
            _ring.Invalidate();

            _healthValue.Text = b.Health >= 0 ? $"{b.Health}%" : "n/a";
            _cycleValue.Text = b.Cycles >= 0 ? $"{b.Cycles}" : "n/a";
            _fullValue.Text = b.FullWh >= 0 ? $"{b.FullWh}Wh" : "n/a";
            _designValue.Text = b.DesignWh >= 0 ? $"{b.DesignWh}Wh" : "n/a";

            if (b.OnAc)
            {
                _acValue.Text = "AC";
                _acValue.ForeColor = Color.FromArgb(80, 200, 120);
                _runtimeValue.Text = "plugged in";
            }
            else
            {
                _acValue.Text = "Battery";
                _acValue.ForeColor = Color.FromArgb(230, 180, 60);
                _runtimeValue.Text = b.RuntimeMin >= 0 ? $"{b.RuntimeMin} min left" : "—";
            }

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
            bool inhibited = ec.EndsWith("c5", StringComparison.OrdinalIgnoreCase) || ec.EndsWith("45", StringComparison.OrdinalIgnoreCase);
            _ecMode.Text = inhibited ? "INHIBIT" : "AUTO";
            _ecMode.ForeColor = inhibited ? Color.FromArgb(220, 90, 90) : Color.FromArgb(80, 200, 120);

            bool daemonRunning = File.Exists(DaemonPath) && DaemonAlive();
            _daemonValue.Text = daemonRunning ? "Running" : "Stopped";
            _daemonValue.ForeColor = daemonRunning ? Color.FromArgb(80, 200, 120) : Color.FromArgb(220, 120, 90);
            _daemonBtn.Text = daemonRunning ? "Stop" : "Start";

            SetPill(inhibited ? "INHIBITED" : "AUTO (charging limit 80%)",
                inhibited ? Color.FromArgb(45, 25, 25) : Color.FromArgb(30, 40, 32),
                inhibited ? Color.FromArgb(220, 90, 90) : Color.FromArgb(80, 200, 120));
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

    private (int Charge, int Health, int Cycles, int FullWh, int DesignWh, int RuntimeMin, bool OnAc) GetBatteryInfo()
    {
        int charge = -1, health = -1, cycles = -1, fullWh = -1, designWh = -1, runtimeMin = -1;
        bool onAc = false;
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = "-NoProfile -Command \"Add-Type -AssemblyName Microsoft.VisualBasic; $b=Get-CimInstance Win32_Battery; $d=(Get-CimInstance Win32_PortableBattery -ErrorAction SilentlyContinue).DesignCapacity; $f=(Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue).FullChargedCapacity; $c=(Get-CimInstance -Namespace root/wmi -ClassName BatteryCycleCount -ErrorAction SilentlyContinue).CycleCount; $r=(Get-CimInstance Win32_Battery).EstimatedRunTime; $ac=0; if($b.BatteryStatus -eq 2){$ac=1}; $v=11340; $h=-1; if($d -and $f){$h=[math]::Round(($f/$d)*100)}; '{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $b.EstimatedChargeRemaining,$h,$c,[math]::Round($f/1000,1),[math]::Round($d/1000,1),$r,$ac\"",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            var proc = System.Diagnostics.Process.Start(psi)!;
            var line = proc.StandardOutput.ReadToEnd().Trim();
            proc.WaitForExit();
            var parts = line.Split('|');
            if (parts.Length == 7)
            {
                int.TryParse(parts[0], out charge);
                int.TryParse(parts[1], out health);
                int.TryParse(parts[2], out cycles);
                double.TryParse(parts[3], System.Globalization.CultureInfo.InvariantCulture, out double fullD);
                double.TryParse(parts[4], System.Globalization.CultureInfo.InvariantCulture, out double designD);
                fullWh = (int)Math.Round(fullD);
                designWh = (int)Math.Round(designD);
                int.TryParse(parts[5], out runtimeMin);
                onAc = parts[6] == "1";
            }
        }
        catch { }
        return (charge, health, cycles, fullWh, designWh, runtimeMin, onAc);
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
                Arguments = $"-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"{DaemonPath}\"",
                WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden,
                UseShellExecute = true
            });
        }
        Thread.Sleep(1000);
        RefreshStatus();
    }
}
