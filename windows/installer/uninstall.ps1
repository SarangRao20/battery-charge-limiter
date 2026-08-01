#Requires -RunAsAdministrator

$taskName = "Battery80Cap"
$svcName = "WinRing0_1_2_0"

# Stop app/daemon
Get-Process BatteryCapApp -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*daemon.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# Remove scheduled task
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }

# Remove driver service (stop first so delete succeeds)
$svc = Get-Service $svcName -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -ne "Stopped") { sc.exe stop $svcName | Out-Null; Start-Sleep 1 }
    sc.exe delete $svcName | Out-Null
}
