# Chrome Gemini Split-Tunneling Launcher

Launches Google Chrome configured with US country overrides to enable AI feature with automate OpenVPN  setup, connection to a US VPN Gate node with split-tunneling (route-nopull),     dynamically resolves target Gemini domains, adds static OS routes through the VPN interface,     and launches Chrome with Glic/Gemini flags.

<img width="1024" height="576" alt="image" src="https://gist.github.com/user-attachments/assets/9022ffa4-149f-4b15-8990-8c1f666a18ad" />


## Features

- **Automated OpenVPN Connect V3 Setup**: Automatically detects local installations of OpenVPN Connect V3 and performs a silent MSI installation if missing.
- **Dynamic US Node Selection**: Queries the VPN Gate API, parses node data, sorts by bandwidth speed, and selects optimal US-based VPN nodes.
- **Strict Split-Tunneling**: Appends `route-nopull` to configuration profiles to ensure non-AI internet traffic is not routed through the VPN tunnel.
- **Dynamic DNS & Host Routing**: Resolves target Gemini and Google AI API domain IPs at runtime and injects static IPv4 OS routes directly into the active OpenVPN adapter interface.
- **Chrome Experimental Flags Launcher**: Launches Google Chrome configured with US country overrides, language forcing (`en-US`), and enabled feature flags for Glic, Prompt API, Summarizer API, Writer API, and related AI tools.
- **Self-Elevating Execution**: Detects privilege levels and automatically prompts for UAC Administrator elevation when executed as a script.

## Tech Stack

- **Scripting & Automation**: PowerShell 5.1+
- **VPN Engine**: OpenVPN Connect V3 (CLI & MSI Installer)
- **API Integration**: VPN Gate REST API (`http://www.vpngate.net/api/iphone/`)
- **Target Platform**: Windows 10 / 11
- **Target Browser**: Google Chrome

## Getting Started

### Prerequisites

- Windows 10 or Windows 11
- PowerShell 5.1 or higher
- Google Chrome installed on default system paths

### Setup & Execution

1. **Set Execution Policy (Current Process)**
Open PowerShell as Administrator and allow script execution for the current session:
```powershell
Set-ExecutionPolicy Unrestricted -Scope Process -Force

```


2. **Run the Launcher Script**
Execute the PowerShell script directly:
```powershell
.\launch_chrome_ai.ps1

```


> **Note**: If not started in an elevated console, the script will request UAC elevation automatically.



## Architecture / How It Works

```
+------------------+     +------------------------+     +------------------------+
|  Privilege Check | --> | OpenVPN Connect Check  | --> |   Query VPN Gate API   |
| (Elevate via UAC)|     | (Silent MSI Install)   |     | (Filter US Top Nodes)  |
+------------------+     +------------------------+     +------------------------+
                                                                     |
                                                                     v
+------------------+     +------------------------+     +------------------------+
|  Launch Chrome   | <-- | Dynamic DNS Resolution | <-- | Import .ovpn Profile & |
| (AI Feature Flags)|    | & Static OS Route Add  |     | Establish TUN Tunnel   |
+------------------+     +------------------------+     +------------------------+

```

1. **Privilege Elevation**: Confirms administrative privileges necessary for Windows routing table updates (`route add`).
2. **Client Management**: Verifies `OpenVPNConnect.exe` existence. Downloads and executes silent installation via `msiexec` if absent.
3. **Node Selection & Sanitization**: Retrieves CSV server lists from VPN Gate, cleans metadata headers, filters for active US nodes with Base64 OpenVPN configurations, and sorts by speed.
4. **Tunnel Initialization**: Injects `route-nopull` into the config, imports the profile via OpenVPN CLI (`--import-profile`), initiates connection (`--connect`), and monitors Windows Network Adapters until the TUN/TAP interface status reports `Up`.
5. **Selective Domain Routing**: Resolves IPv4 addresses for target domains (`gemini.google.com`, `generativelanguage.googleapis.com`, `cloudaicompanion.googleapis.com`, `alkalimodelfrontend-pa.googleapis.com`, `clients4.google.com`) and binds static host routes to the VPN interface index.
6. **Browser Deployment**: Terminates active Chrome processes and launches Chrome using flags that enable built-in AI capabilities and mimic US region access.

## Target Domains

The script routes only the following domain endpoints through the US VPN interface:

* `gemini.google.com`
* `generativelanguage.googleapis.com`
* `cloudaicompanion.googleapis.com`
* `alkalimodelfrontend-pa.googleapis.com`
* `clients4.google.com`