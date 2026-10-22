# Refreshes data/substack.json with the latest essays from Drew's Substack and,
# if anything changed, commits and pushes it so GitHub redeploys the site.
#
# Runs daily from the Windows scheduled task "Cool Publishers - Update Substack".
# It runs on this PC because Substack refuses requests from GitHub's servers.
# Log: %LOCALAPPDATA%\CoolPublishers\update-substack.log

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$out = Join-Path $repo 'data\substack.json'
$git = 'C:\Program Files\Git\cmd\git.exe'
$logDir = Join-Path $env:LOCALAPPDATA 'CoolPublishers'
New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir 'update-substack.log'
function Log($msg) { Add-Content -Path $log -Value ("{0:yyyy-MM-dd HH:mm}  {1}" -f (Get-Date), $msg) }

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object Net.WebClient
    $wc.Encoding = [Text.Encoding]::UTF8
    $wc.Headers.Add('User-Agent', 'coolpublishers.com feed updater')
    [xml]$feed = $wc.DownloadString('https://drewbuell.substack.com/feed')

    $posts = @($feed.rss.channel.item | Select-Object -First 3 | ForEach-Object {
        $img = ($_.enclosure | Where-Object { $_.type -like 'image/*' } | Select-Object -First 1).url
        [ordered]@{
            title    = "$($_.title.InnerText)".Trim()
            subtitle = "$($_.description.InnerText)".Trim()
            link     = "$($_.link)".Trim()
            date     = ([DateTimeOffset]::Parse($_.pubDate)).ToString('o')
            image    = $img
        }
    })
    if ($posts.Count -eq 0) { Log 'Feed had no posts; nothing changed.'; exit 0 }

    $json = ConvertTo-Json @{ posts = $posts } -Depth 4
    [IO.File]::WriteAllText($out, $json, (New-Object Text.UTF8Encoding $false))

    $changed = & $git -C $repo status --porcelain -- data/substack.json
    if (-not $changed) { Log 'No new essays.'; exit 0 }

    & $git -C $repo add -- data/substack.json
    & $git -C $repo commit -q -m "Update latest Substack essays" -- data/substack.json
    & $git -C $repo push -q 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git push failed (exit $LASTEXITCODE)" }
    Log "Pushed new essays: $($posts[0].title)"
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
