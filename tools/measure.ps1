param([string]$Exe, [switch]$Play, [int]$IdleSec = 8, [int]$PlaySec = 25, [string]$Backend = "")
$env:Path = "C:\Windows\System32;C:\Windows"
if ($Backend) { $env:QT_MEDIA_BACKEND = $Backend }
function Mem($id) {
    $p = Get-Process -Id $id
    $s = (Get-Counter "\Process V2(*)\Working Set - Private" -ErrorAction SilentlyContinue).CounterSamples |
        Where-Object { $_.InstanceName -like "*cloud-music*" -and $_.InstanceName -like "*:$id" } | Select-Object -First 1
    $pw = if ($s) { [math]::Round($s.CookedValue / 1MB) } else { -1 }
    $c0 = $p.TotalProcessorTime.TotalSeconds; Start-Sleep 5; $p.Refresh()
    $cpu = [math]::Round(($p.TotalProcessorTime.TotalSeconds - $c0) / 5 * 100, 1)
    "ws=$([math]::Round($p.WorkingSet64/1MB))MB privWS=${pw}MB commit=$([math]::Round($p.PrivateMemorySize64/1MB))MB threads=$($p.Threads.Count) cpu=${cpu}%"
}
$a = if ($Play) { "--play" } else { "--idle" }
$p = Start-Process $Exe -PassThru -WorkingDirectory C:\Windows\Temp -ArgumentList $a
Start-Sleep $IdleSec
"idle    : " + (Mem $p.Id)
if ($Play) {
    Start-Sleep $PlaySec
    "playing : " + (Mem $p.Id)
}
Stop-Process $p -Force
