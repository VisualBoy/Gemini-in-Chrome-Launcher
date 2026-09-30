<#
.SYNOPSIS
    Launches Google Chrome configured with US country overrides to enable AI features, 
    Automates OpenVPN Connect V3 setup, connects to a US VPN Gate node with split-tunneling (route-nopull),
    dynamically resolves target Gemini domains, adds static OS routes through the VPN interface,
    and launches Chrome with Glic/Gemini flags.
#>

$ErrorActionPreference = "Stop"

# --- Domain Configuration ---
$targetDomains = @(
    "gemini.google.com",
    "generativelanguage.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "alkalimodelfrontend-pa.googleapis.com",
    "clients4.google.com"
)

# --- 1. Administrator Privilege Check ---
Write-Host "Verifying Administrator privileges..." -ForegroundColor Cyan
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Write-Error "Cannot auto-elevate in interactive mode. Please run this console as Administrator or save as a .ps1 file."
        exit 1
    }
    Write-Warning "Administrator privileges required. Relaunching with UAC..."
    Start-Process powershell.exe -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- 2. Search and Install OpenVPN Connect V3 ---
$openVpnPaths = @(
    "$env:ProgramFiles\OpenVPN Connect\OpenVPNConnect.exe",
    "${env:ProgramFiles(x86)}\OpenVPN Connect\OpenVPNConnect.exe"
)
$openVpnExe = $openVpnPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) } | Select-Object -First 1

if (-not $openVpnExe) {
    Write-Host "OpenVPN Connect V3 not found. Installing the latest official version..." -ForegroundColor Yellow
    
    $openVpnUrl = "https://openvpn.net/downloads/openvpn-connect-v3-windows.msi"
    $installerPath = Join-Path $env:TEMP "openvpn-connect-latest.msi"

    try {
        Write-Host "Downloading OpenVPN Connect..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $openVpnUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Error "Critical Error: Failed to download the OpenVPN Connect installer from official URL."
        exit 1
    }

    if (Test-Path $installerPath) {
        Write-Host "Running silent installation for MSI package..." -ForegroundColor Cyan
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installerPath`" /qn /norestart" -Wait -PassThru
        Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
    }

    $openVpnExe = $openVpnPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) } | Select-Object -First 1
    if (-not $openVpnExe) {
        Write-Error "Critical Failure: OpenVPNConnect.exe not located post-installation."
        exit 1
    }
    Write-Host "OpenVPN Connect V3 installed successfully at: $openVpnExe" -ForegroundColor Green
} else {
    Write-Host "OpenVPN Connect V3 is already installed: $openVpnExe" -ForegroundColor Green
}

# --- 3. Fetch US Nodes from VPN Gate API (Integrated OVfinder logic) ---
$ovpnPath = Join-Path $env:TEMP "vpngate_us.ovpn"
Write-Host "Querying VPN Gate API for US nodes..." -ForegroundColor Cyan
try {
    $rawApiData = Invoke-RestMethod -Uri "http://www.vpngate.net/api/iphone/" -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Error "VPN Gate API is unreachable."
    exit 1
}

# Raw data processing: removes unnecessary lines and fixes the header
$validLines = @()
$isHeader = $true

foreach ($line in ($rawApiData -split "\r?\n")) {
    # Skip empty lines or VPN Gate structural metadata (e.g., *vpn_servers)
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("*")) { 
        continue 
    }
    
    # Remove initial '#' character exclusively from the header line
    if ($line.StartsWith("#") -and $isHeader) {
        $line = $line.Substring(1)
        $isHeader = $false
    }
    
    $validLines += $line
}

# Parse CSV now correctly formatted with real headers
$usNodes = $validLines | ConvertFrom-Csv | Where-Object { 
    $_.CountryShort -eq "US" -and -not [string]::IsNullOrWhiteSpace($_.OpenVPN_ConfigData_Base64) 
} | Sort-Object -Property { [long]$_.Speed } -Descending | Select-Object -First 3

# --- 4. Profile Import and Connection ---
$tunnelEstablished = $false
$interfaceIndex = $null

foreach ($node in $usNodes) {
    Write-Host "Testing US Node: $($node.HostName) - $([math]::Round($node.Speed / 1Mb, 2)) Mbps" -ForegroundColor Cyan
    
    $ovpnBytes  = [System.Convert]::FromBase64String($node.OpenVPN_ConfigData_Base64)
    $ovpnConfig = [System.Text.Encoding]::UTF8.GetString($ovpnBytes)

    if ($ovpnConfig -notmatch "route-nopull") {
        $ovpnConfig += "`nroute-nopull`n"
    }
    Set-Content -Path $ovpnPath -Value $ovpnConfig -Encoding UTF8

    Write-Host "Importing profile into OpenVPN Connect V3..." -ForegroundColor DarkCyan
    try {
        Start-Process -FilePath $openVpnExe -ArgumentList "--import-profile=`"$ovpnPath`"" -Wait -ErrorAction Stop
    } catch {
        Write-Warning "Failed to import profile for node $($node.HostName). Trying next..."
        continue
    }

    Write-Host "Initiating VPN connection..." -ForegroundColor DarkCyan
    Start-Process -FilePath $openVpnExe -ArgumentList "--connect=`"$ovpnPath`"" -WindowStyle Hidden

    Write-Host "Waiting for network adapter initialization..." -ForegroundColor Gray
    $retryCount = 0
    while ($retryCount -lt 10) {
        Start-Sleep -Seconds 2
        $tapAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "OpenVPN|TAP|TUN" -and $_.Status -eq "Up" } | Select-Object -First 1
        
        if ($tapAdapter) {
            $interfaceIndex = $tapAdapter.ifIndex
            $tunnelEstablished = $true
            break
        }
        $retryCount++
    }

    if ($tunnelEstablished) {
        Write-Host "OpenVPN connection established on Interface Index: $interfaceIndex" -ForegroundColor Green
        break
    } else {
        Write-Warning "Connection timed out for node $($node.HostName). Attempting next node..."
    }
}

if (-not $tunnelEstablished) {
    Write-Error "Failed to establish OpenVPN connection with any US node."
    exit 1
}

# --- 5. Domain IP Resolution and Static Routing ---
Write-Host "Resolving target domains and configuring static split routes..." -ForegroundColor Cyan
Start-Sleep -Seconds 2 

if ($interfaceIndex) {
    foreach ($domain in $targetDomains) {
        try {
            $ips = [System.Net.Dns]::GetHostAddresses($domain)
            foreach ($ip in $ips) {
                if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
                    route add $ip.IPAddress mask 255.255.255.255 0.0.0.0 IF $interfaceIndex /METRIC 5 2>&1 | Out-Null
                    Write-Host "Routed $domain ($($ip.IPAddress)) via OpenVPN adapter." -ForegroundColor DarkGreen
                }
            }
        } catch {
            Write-Warning "Could not resolve domain: $domain"
        }
    }
} else {
    Write-Warning "OpenVPN network adapter index missing. Traffic routing bypassed."
}

# --- 6. Google Chrome Configuration and Launch ---
$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" -Name "" -ErrorAction SilentlyContinue).'(default)'
)
$chromePath = $chromePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) } | Select-Object -First 1

if (-not $chromePath) {
    Write-Error "Google Chrome executable not found."
    exit 1
}

$featuresList = @(
    "Glic","GlicSidePanel","GlicActor","GlicUnifiedFreScreen","GlicEntrypointVariations",
    "GlicActorAutofill","GlicActorCursor","GlicActorScriptTools","GlicCaptureRegion",
    "GlicDefaultToLastActiveConversation","GlicExperimentalTriggering","GlicPdfSummarize",
    "GlicSelectionPrompt","GlicTabGroups","GlicZeroStateSuggestions","SyncAiThreads",
    "SyncGeminiThreads","ContextualTasksSidePanel","PromptAPI","PromptAPIMultimodalInput",
    "SummarizerAPI","WriterAPI","RewriterAPI","ProofreaderAPI"
) -join ","

$arguments = @(
    "--variations-override-country=us",
    "--lang=en-US",
    "--enable-features=$featuresList",
    "--disable-session-crashed-bubble"
)

Get-Process -Name "chrome" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host "Launching Google Chrome with domain-specific split-routing..." -ForegroundColor Green
Start-Process -FilePath $chromePath -ArgumentList $arguments
Write-Host "Setup Complete!" -ForegroundColor Green

# --- 7. Final prompt to keep the window open ---
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Operations completed. Check the log above if there are any warnings." -ForegroundColor Yellow
Read-Host "Press ENTER to close this window"