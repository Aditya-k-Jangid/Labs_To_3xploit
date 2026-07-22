<div align="center">

```
 ██╗   ██╗███╗   ██╗██████╗  █████╗ ██╗  ██╗███████╗██████╗
 ██║   ██║████╗  ██║██╔══██╗██╔══██╗██║ ██╔╝██╔════╝██╔══██╗
 ██║   ██║██╔██╗ ██║██████╔╝███████║█████╔╝ █████╗  ██║  ██║
 ██║   ██║██║╚██╗██║██╔══██╗██╔══██║██╔═██╗ ██╔══╝  ██║  ██║
 ╚██████╔╝██║ ╚████║██████╔╝██║  ██║██║  ██╗███████╗██████╔╝
  ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═════╝
        A C T I V E   D I R E C T O R Y   L A B
```

*A vulnerable AD environment for practicing CPTS-style pentesting techniques*

![Difficulty](https://img.shields.io/badge/difficulty-medium--hard-orange?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-windows%20AD-blue?style=for-the-badge)
![Points](https://img.shields.io/badge/points-1000-yellow?style=for-the-badge)

</div>

---

## Overview

This lab includes multiple attack vectors and privilege escalation paths commonly found in real-world assessments — built to mirror the kind of misconfigurations you'd see on CPTS/OSCP/CRTP-style engagements.

```
┌────────────────────────────────────────────────────────┐
│  5 attack paths  →  10 challenges  →  1000 points       │
│  Foothold → Credential Access → Privesc → Domain Admin  │
└────────────────────────────────────────────────────────┘
```

---

## Repository Contents

### `Setup.ps1`
PowerShell script that automatically deploys a vulnerable Active Directory environment on your domain controller. Fully dynamic — adapts to any domain automatically.

**Creates:**
- Vulnerable web application (SQL injection, file upload flaws)
- Multiple user accounts with weak configurations
- Misconfigured permissions (DCSync, constrained delegation)
- GPP passwords in SYSVOL
- Several privilege escalation vectors
- Intentionally weakened security settings

### `challenge_guide.html`
Interactive challenge worksheet with 10 progressively difficult tasks covering the full attack chain from initial foothold to domain compromise.

**Features:**
- Points system (1000 total points)
- Built-in hints for each challenge
- Answer validation
- Progress tracking

---

## Setup Instructions

### Prerequisites
| Requirement | Details |
|---|---|
| OS | Windows Server with AD DS installed |
| Role | Domain Controller configured |
| PowerShell | 5.1+ with `ActiveDirectory` module |
| Privileges | Domain Admin |

### Lab Deployment

```
1. Download Setup.ps1 to your Domain Controller

2. Run as Administrator:
   .\Setup.ps1

3. Reboot the DC (required for LDAP signing changes):
   Restart-Computer -Force

4. Access the web application:
   URL: http://DC-HOSTNAME/portal
   Guest creds: guest / guest123
```

### Using the Challenge Guide

```
1. Open challenge_guide.html in any browser
   (double-click, or: firefox challenge_guide.html)

2. Work through challenges in order — they build on each other

3. Use hints if stuck — each challenge has a hint button

4. Submit answers to track progress and score
```

---

## Attack Paths Overview

```
Path 1 │ Web app -> Backup config -> AS-REP Roasting -> Lateral Movement
Path 2 │ GPP Password -> Instant Domain Admin
Path 3 │ Kerberoasting -> Nested Groups -> Domain Admin
Path 4 │ DCSync Rights Abuse
Path 5 │ Constrained Delegation Exploitation
```

---

## Challenge Breakdown

| Challenge | Focus Area | Points |
|:---------:|------------|:------:|
| 1-2 | Web enumeration & info disclosure | 175 |
| 3-4 | AS-REP roasting & hash cracking | 175 |
| 5 | Kerberoasting | 100 |
| 6 | GPP password exploitation | 125 |
| 7 | DCSync permissions | 125 |
| 8 | Privilege escalation analysis | 100 |
| 9 | Kerberos delegation | 100 |
| 10 | Domain compromise | 100 |
| | **Total** | **1000** |

---

## Tools You'll Need

| Category | Tools |
|---|---|
| AD Attacks | Impacket suite (`GetNPUsers`, `GetUserSPNs`, `secretsdump`, `psexec`) |
| Cracking | Hashcat, John the Ripper |
| Recon | Nmap |
| Optional | BloodHound, PowerView, CrackMapExec |

---

## Learning Objectives

- Active Directory enumeration techniques
- Kerberos attacks (AS-REP, Kerberoasting)
- Credential harvesting from various sources
- Permission abuse and privilege escalation
- Lateral movement strategies
- Complete domain compromise methodologies

---

## Cleanup

To remove all vulnerable configurations:
```powershell
.\Setup.ps1 -Cleanup
```

---

## Important Notes

- For lab environments only — never deploy in production
- Script requires Domain Admin privileges
- All configurations are intentionally insecure
- Perfect for OSCP/CPTS/CRTP practice

---

<div align="center">

```
[ + ]  H A P P Y   H A C K I N G  [ + ]
```

</div>
