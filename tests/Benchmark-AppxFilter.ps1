# Benchmark for AppX Bloatware Package Filtering Loop
$bloatApps = @(
    "Microsoft.Todos", "Microsoft.Print3D", "Microsoft.3DBuilder", "Microsoft.Microsoft3DViewer",
    "Microsoft.OneConnect", "Microsoft.MSPaint", "Microsoft.WindowsAlarms", "Microsoft.People",
    "Microsoft.SkypeApp", "Microsoft.WindowsMaps", "Microsoft.WindowsSoundRecorder", "Microsoft.WindowsCommunicationsApps",
    "Microsoft.MixedReality.Portal", "ByteDance.TikTok", "SpotifyAB.SpotifyMusic", "Disney.37853FC22B2CE",
    "AmazonVideo.PrimeVideo", "Facebook.InstagramBeta", "King.com.CandyCrushSaga", "King.com.CandyCrushSodaSaga",
    "4DF9E0F8.Netflix", "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MicrosoftSudoku", "Microsoft.Copilot",
    "Microsoft.Windows.Ai.Copilot.Provider", "7EE7776C.LinkedInforWindows", "Microsoft.LinkedIn", "LinkedIn",
    "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.BingFinance", "Microsoft.BingSports",
    "Microsoft.BingSearch", "Microsoft.MicrosoftOfficeHub", "MicrosoftTeams", "Microsoft.MSTeams",
    "Microsoft.Teams", "Microsoft.GetHelp", "Microsoft.Getstarted", "Microsoft.WindowsFeedbackHub",
    "Microsoft.YourPhone", "Microsoft.Office.ActionsServer", "Microsoft.OfficePushNotificationUtility", "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo", "Microsoft.MixedRealityLink", "Microsoft.Adera", "Microsoft.Adera-Lite",
    "Microsoft.MicrosoftPCManager", "Microsoft.GamingApp"
)

$provisioned = [System.Collections.Generic.List[PSCustomObject]]::new()
for ($i = 0; $i -lt 100; $i++) {
    $name = if ($i % 2 -eq 0) { $bloatApps[$i % $bloatApps.Count] + "_8wekyb3d8bbwe" } else { "Vendor.App$i" + "_8wekyb3d8bbwe" }
    $disp = "Friendly Name $i"
    $provisioned.Add([PSCustomObject]@{ PackageName = $name; DisplayName = $disp })
}

$allInstalled = [System.Collections.Generic.List[PSCustomObject]]::new()
for ($i = 0; $i -lt 150; $i++) {
    $name = if ($i % 3 -eq 0) { $bloatApps[$i % $bloatApps.Count] } else { "Vendor.InstalledApp$i" }
    $family = $name + "_8wekyb3d8bbwe"
    $allInstalled.Add([PSCustomObject]@{ NonRemovable = $false; Name = $name; PackageFamilyName = $family })
}

# Warmup
1..5 | ForEach-Object {
    foreach ($app in $bloatApps) {
        $appEscaped = [regex]::Escape($app)
        $pkgPattern = "^$appEscaped(_|$)"
        $dispPattern = "^$appEscaped($|\s)"
        $staged = $provisioned.Where({
            ($_.PackageName -match $pkgPattern) -or
            ($_.DisplayName -and $_.DisplayName -match $dispPattern)
        })
    }
}

# Baseline execution
$sw = [System.Diagnostics.Stopwatch]::StartNew()
1..100 | ForEach-Object {
    foreach ($app in $bloatApps) {
        $staged = $provisioned.Where({
            ($_.PackageName -match "^$([regex]::Escape($app))(_|$)") -or
            ($_.DisplayName -and $_.DisplayName -match "^$([regex]::Escape($app))($|\s)")
        })
        $installed = $allInstalled.Where({
            -not $_.NonRemovable -and
            ($_.Name -match "^$([regex]::Escape($app))" -or ($_.PackageFamilyName -and $_.PackageFamilyName -match "^$([regex]::Escape($app))"))
        })
    }
}
$sw.Stop()
$baselineMs = $sw.ElapsedMilliseconds

# Optimized execution
$sw = [System.Diagnostics.Stopwatch]::StartNew()
1..100 | ForEach-Object {
    foreach ($app in $bloatApps) {
        $appEscaped = [regex]::Escape($app)
        $pkgPattern = "^$appEscaped(_|$)"
        $dispPattern = "^$appEscaped($|\s)"
        $staged = $provisioned.Where({
            ($_.PackageName -match $pkgPattern) -or
            ($_.DisplayName -and $_.DisplayName -match $dispPattern)
        })

        $appPattern = "^$([regex]::Escape($app))"
        $installed = $allInstalled.Where({
            -not $_.NonRemovable -and
            ($_.Name -match $appPattern -or ($_.PackageFamilyName -and $_.PackageFamilyName -match $appPattern))
        })
    }
}
$sw.Stop()
$optimizedMs = $sw.ElapsedMilliseconds

$speedup = [math]::Round((($baselineMs - $optimizedMs) / $baselineMs) * 100, 2)
Write-Host "Baseline: ${baselineMs} ms"
Write-Host "Optimized: ${optimizedMs} ms"
Write-Host "Speedup: ${speedup}% faster"
