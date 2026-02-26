<div align="center">

<br>

# 🍎🧃 apple-juice

<br>

**Keep your Mac battery healthy, the secure way**

<br>

<a href="#-quick-start"><img src="https://img.shields.io/badge/Install-1a1a1a?style=for-the-badge" alt="Install"></a>
<a href="#-longevity-mode"><img src="https://img.shields.io/badge/Longevity_Mode-22c55e?style=for-the-badge" alt="Longevity Mode"></a>
<a href="#-security"><img src="https://img.shields.io/badge/Security-1a1a1a?style=for-the-badge" alt="Security"></a>

<br>
<br>

*A security-hardened fork of [BatteryOptimizer_for_Mac](https://github.com/js4jiang5/BatteryOptimizer_for_Mac)*

<img src="https://img.shields.io/badge/Apple_Silicon-black?style=flat-square&logo=apple&logoColor=white" alt="Apple Silicon">
<img src="https://img.shields.io/badge/Intel-0071C5?style=flat-square&logo=intel&logoColor=white" alt="Intel">
<img src="https://img.shields.io/badge/29_Security_Fixes-22c55e?style=flat-square" alt="Security">

<br>
<br>

---

</div>

<br>

## 💚 Longevity Mode

<div align="center">

**The best way to preserve your Mac's battery health.**

</div>

<br>

```bash
brew install MoonBoi9001/tap/apple-juice
sudo apple-juice visudo $USER
apple-juice maintain longevity
```

<br>

Three commands. Set it and forget it. Configure [macOS settings](#%EF%B8%8F-setup) for notifications.

<br>

<div align="center">

| What it does | Why it matters |
|:---|:---|
| Maintains charge at **65%** | Sweet spot for lithium-ion longevity |
| Sails down to **60%** | Avoids micro-charging cycles |
| **Monthly auto-balance** | Keeps cells calibrated |
| **Monitors cell imbalance** | Triggers balance when >0.2V drift detected |

</div>

<br>

> **Lithium-ion batteries degrade fastest at high charge levels.** Keeping your battery between 60-65% dramatically extends its lifespan compared to the default 80-100% cycling.

<br>

---

<br>

## ⚡ Quick Start

**Homebrew:**

```bash
brew install MoonBoi9001/tap/apple-juice
sudo apple-juice visudo $USER
```

**Or curl:**

```bash
curl -s https://raw.githubusercontent.com/MoonBoi9001/apple-juice/main/setup.sh | bash
```

**Then run:**

```bash
apple-juice maintain longevity    # recommended
```

Or pick your own level:

```bash
apple-juice maintain 80           # stay at 80%
apple-juice maintain 80 50        # stay at 80%, sail to 50%
```

<br>

---

<br>

## 🎯 All Commands

<br>

<details>
<summary><b>🔋 Battery Management</b></summary>

<br>

| Command | Description |
|:---|:---|
| `apple-juice maintain longevity` | **Recommended.** Optimized for max lifespan |
| `apple-juice maintain 80` | Keep at 80%, sail to 75% |
| `apple-juice maintain 80 50` | Keep at 80%, sail to 50% |
| `apple-juice maintain suspend` | Temporarily charge to 100% |
| `apple-juice maintain recover` | Resume after suspend |
| `apple-juice maintain stop` | Disable completely |
| `apple-juice charge 90` | Charge to specific level |
| `apple-juice discharge 50` | Discharge to specific level |

</details>

<details>
<summary><b>🔄 Calibration</b></summary>

<br>

| Command | Description |
|:---|:---|
| `apple-juice calibrate` | Full calibration cycle |
| `apple-juice calibrate stop` | Stop calibration |
| `apple-juice balance` | Manual cell balancing |
| `apple-juice schedule` | Configure scheduled calibration |
| `apple-juice schedule disable` | Disable scheduled calibration |

</details>

<details>
<summary><b>📊 Monitoring</b></summary>

<br>

| Command | Description |
|:---|:---|
| `apple-juice status` | Health, temp, cycle count |
| `apple-juice dailylog` | View daily battery log |
| `apple-juice calibratelog` | View calibration history |
| `apple-juice logs` | View CLI logs |
| `apple-juice ssd` | SSD health status |
| `apple-juice ssdlog` | SSD daily log |

</details>

<details>
<summary><b>⚙️ System</b></summary>

<br>

| Command | Description |
|:---|:---|
| `apple-juice update` | Update to latest version |
| `apple-juice version` | Show current version |
| `apple-juice changelog` | View latest changelog |
| `apple-juice reinstall` | Reinstall from scratch |
| `apple-juice uninstall` | Remove completely |
| `apple-juice language tw/us` | Change language |

</details>

<br>

---

<br>

## 🔒 Security

This fork fixes **29 vulnerabilities** found in upstream:

- Command injection via sed/osascript
- Privilege escalation vectors
- Race conditions in file operations
- Signal handler reentrancy bugs
- Missing input validation

Executables are root-owned in `/usr/local/co.battery-optimizer`.

<br>

---

<br>

## ⚙️ Setup

<div align="center">

<br>

**Three quick settings to configure:**

<br>

</div>

<table>
<tr>
<td>

```
🔋  STEP 1
```

</td>
<td>

**System Settings → Battery → Battery Health**

Turn off `Optimize Battery Charging`

</td>
</tr>
<tr>
<td>

```
🔔  STEP 2
```

</td>
<td>

**System Settings → Notifications**

Turn on `Allow notifications when mirroring or sharing`

</td>
</tr>
<tr>
<td>

```
📝  STEP 3
```

</td>
<td>

**System Settings → Notifications → Script Editor**

Select `Alerts`

</td>
</tr>
</table>

<br>

---

<br>

<div align="center">

**[📖 Full Docs](https://github.com/js4jiang5/BatteryOptimizer_for_Mac)** · **[🐛 Report Issue](https://github.com/MoonBoi9001/apple-juice/issues)** · **[⭐ Star on GitHub](https://github.com/MoonBoi9001/apple-juice)**

</div>

<br>

---

<div align="center">

<br>

```
                            ╔═══════════════════════════════════════════════════════════════╗
                            ║                                                               ║
                            ║                        DISCLAIMER                             ║
                            ║                                                               ║
                            ║   This software is provided as-is, without warranty of any    ║
                            ║   kind. Use at your own risk. Battery management involves     ║
                            ║   low-level system operations. The authors are not liable     ║
                            ║   for any damage to your device. Back up before use.          ║
                            ║                                                               ║
                            ╚═══════════════════════════════════════════════════════════════╝
```

<br>

<sub>Made with 🧃 by the community</sub>

<br>
<br>

</div>
