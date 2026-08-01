using System.Threading;

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
    private readonly NotifyIcon _tray;
    private readonly ToolStripMenuItem _bypassItem;

    private const string EcTool = @"C:\EC-Tool\EC-Access-Tool.exe";
    private const int StopAt = 80;

    private readonly bool _startInTray;
    private bool _exiting;
    private bool _bypassed;
    private bool _inhibited;
    private bool _wroteAuto;
    private Icon _greenIcon = null!;
    private Icon _redIcon = null!;
    private Icon _grayIcon = null!;

    public Form1(bool startInTray)
    {
        _startInTray = startInTray;
        Text = "Battery Charge Limiter";
        ClientSize = new Size(460, 600);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(18, 20, 24);
        ForeColor = Color.FromArgb(230, 235, 240);

        LoadIcons();

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

        Controls.AddRange(new Control[]
        {
            header, _statusPill, sub, _batteryPct, batterySub, _ring,
            healthCard, ecCard, acCard, cycleCard, fullCard, designCard, daemonCard
        });

        _tray = new NotifyIcon
        {
            Icon = _greenIcon,
            Text = $"Battery Cap {StopAt}%",
            Visible = true
        };
        var menu = new ContextMenuStrip();
        var openItem = new ToolStripMenuItem("Open Dashboard");
        _bypassItem = new ToolStripMenuItem("Bypass - Full Charge");
        var exitItem = new ToolStripMenuItem("Exit");
        menu.Items.AddRange(new ToolStripItem[] { openItem, _bypassItem, new ToolStripSeparator(), exitItem });
        _tray.ContextMenuStrip = menu;

        openItem.Click += (_, _) => ShowFromTray();
        _bypassItem.Click += (_, _) => ToggleBypass();
        exitItem.Click += (_, _) => ExitApp();
        _tray.DoubleClick += (_, _) => ShowFromTray();

        FormClosing += (_, e) =>
        {
            if (!_exiting && _tray.Visible)
            {
                e.Cancel = true;
                Hide();
                _tray.ShowBalloonTip(1500, "Battery Charge Limiter", "Still running in system tray", ToolTipIcon.Info);
            }
        };

        Shown += (_, _) => { if (_startInTray) Hide(); };

        _timer = new System.Windows.Forms.Timer { Interval = 3000 };
        _timer.Tick += async (_, _) => await RefreshStatusAsync();
        _timer.Start();
        _ = RefreshStatusAsync();
    }

    public void ShowFromTray()
    {
        Show();
        WindowState = FormWindowState.Normal;
        Activate();
    }

    private void LoadIcons()
    {
        try
        {
            _greenIcon = new Icon(@"C:\EC-Tool\green.ico");
            _redIcon = new Icon(@"C:\EC-Tool\red.ico");
            _grayIcon = new Icon(@"C:\EC-Tool\gray.ico");
        }
        catch
        {
            _greenIcon = SystemIcons.Shield;
            _redIcon = SystemIcons.Hand;
            _grayIcon = SystemIcons.Shield;
        }
    }

    private void ToggleBypass()
    {
        _bypassed = !_bypassed;
        _bypassItem.Text = _bypassed ? "Cancel Bypass" : "Bypass - Full Charge";
        if (_bypassed) WriteEc("40");
        _tray.ShowBalloonTip(2500, "Battery Cap",
            _bypassed ? "Bypass enabled - will charge to 100%" : "Protection enabled (stop at 80%)",
            _bypassed ? ToolTipIcon.Info : ToolTipIcon.Info);
        _ = RefreshStatusAsync();
    }

    private void ExitApp()
    {
        _exiting = true;
        _tray.Visible = false;
        _tray.Dispose();
        Application.Exit();
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

    private async Task RefreshStatusAsync()
    {
        try
        {
            var (charge, health, cycles, fullWh, designWh, runtimeMin, onAc, ec) =
                await Task.Run(() =>
                {
                    var b = GetBatteryInfo();
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
                    return (b.Charge, b.Health, b.Cycles, b.FullWh, b.DesignWh, b.RuntimeMin, b.OnAc, ec);
                });

            if (charge >= 0) _batteryPct.Text = $"{charge}%";
            _ring.Invalidate();

            _healthValue.Text = health >= 0 ? $"{health}%" : "n/a";
            _cycleValue.Text = cycles >= 0 ? $"{cycles}" : "n/a";
            _fullValue.Text = fullWh >= 0 ? $"{fullWh}Wh" : "n/a";
            _designValue.Text = designWh >= 0 ? $"{designWh}Wh" : "n/a";

            if (onAc)
            {
                _acValue.Text = "AC";
                _acValue.ForeColor = Color.FromArgb(80, 200, 120);
                _runtimeValue.Text = "plugged in";
            }
            else
            {
                _acValue.Text = "Battery";
                _acValue.ForeColor = Color.FromArgb(230, 180, 60);
                _runtimeValue.Text = runtimeMin >= 0 ? $"{runtimeMin} min left" : "—";
            }

            _ecValue.Text = ec;
            bool inhibited = ec.EndsWith("c5", StringComparison.OrdinalIgnoreCase) || ec.EndsWith("45", StringComparison.OrdinalIgnoreCase);
            _ecMode.Text = inhibited ? "INHIBIT" : "AUTO";
            _ecMode.ForeColor = inhibited ? Color.FromArgb(220, 90, 90) : Color.FromArgb(80, 200, 120);

            _daemonValue.Text = "Active";
            _daemonValue.ForeColor = Color.FromArgb(80, 200, 120);

            if (_bypassed)
            {
                if (!_wroteAuto) { WriteEc("40"); _wroteAuto = true; }
                _tray.Icon = _greenIcon;
            }
            else if (!onAc)
            {
                _tray.Icon = _grayIcon;
                _inhibited = false;
                _wroteAuto = false;
            }
            else if (charge >= StopAt)
            {
                if (!_inhibited)
                {
                    WriteEc("45");
                    _inhibited = true;
                    _wroteAuto = false;
                    _tray.ShowBalloonTip(2500, "Battery Cap", $"Charging stopped at {charge}%", ToolTipIcon.Warning);
                }
                _tray.Icon = _redIcon;
            }
            else
            {
                if (inhibited || !_wroteAuto)
                {
                    WriteEc("40");
                    _wroteAuto = true;
                }
                _inhibited = false;
                _tray.Icon = _greenIcon;
            }

            SetPill(_bypassed ? "BYPASS (charging to 100%)" : inhibited ? "INHIBITED" : "AUTO (charging limit 80%)",
                _bypassed ? Color.FromArgb(45, 45, 25) : inhibited ? Color.FromArgb(45, 25, 25) : Color.FromArgb(30, 40, 32),
                _bypassed ? Color.FromArgb(230, 180, 60) : inhibited ? Color.FromArgb(220, 90, 90) : Color.FromArgb(80, 200, 120));
        }
        catch { }
    }

    private void WriteEc(string val)
    {
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = EcTool,
                Arguments = $"-winring0 -w 76 {val}",
                UseShellExecute = false,
                CreateNoWindow = true
            });
        }
        catch { }
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
}
