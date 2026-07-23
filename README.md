<div align="center">

```
██╗   ██╗██╗   ██╗██╗     ███╗   ██╗
██║   ██║██║   ██║██║     ████╗  ██║
██║   ██║██║   ██║██║     ██╔██╗ ██║
╚██╗ ██╔╝██║   ██║██║     ██║╚██╗██║
 ╚████╔╝ ╚██████╔╝███████╗██║ ╚████║
  ╚═══╝   ╚═════╝ ╚══════╝╚═╝  ╚═══╝
      L A B S   R E P O S I T O R Y
```

### A collection of self-built vulnerable environments for offensive security practice
*Active Directory · Web · Misc — built to break, made to learn*

![Labs](https://img.shields.io/badge/labs-2-blueviolet?style=for-the-badge)
![Focus](https://img.shields.io/badge/focus-AD%20%7C%20Web%20%7C%20Pentest-red?style=for-the-badge)
![Status](https://img.shields.io/badge/status-active-brightgreen?style=for-the-badge)

</div>

---

## Lab Index

| # | Lab | Type | Difficulty | Focus | Status |
|:-:|-----|------|:----------:|-------|:------:|
| 01 | **[Unbaked](https://github.com/Aditya-k-Jangid/Labs_To_3xploit/tree/main/Unbacked)** | Active Directory | Medium-Hard | Kerberoasting · AS-REP · GPP · DCSync · Delegation | Playable |
| 02 | **[Control](https://github.com/Aditya-k-Jangid/Labs_To_3xploit/tree/main/Control)** | Active Directory | Hard | Anonymous SMB · Credential Cracking · ACL Abuse · AD CS ESC1 · Domain Admin | Playable |

> More rows get added here as new labs drop.

---

```
┌──────────────────────────────────────────────┐
│  01 // UNBAKED                                │
│  Active Directory Penetration Testing Lab     │
└──────────────────────────────────────────────┘
```

A fully dynamic, vulnerable AD environment with multiple realistic attack paths, CPTS-style.

<table>
<tr><td><b>Focus</b></td><td>Kerberos attacks, credential harvesting, ACL/permission abuse, privesc, lateral movement</td></tr>
<tr><td><b>Deploy</b></td><td><code>Setup.ps1</code> on a fresh DC — auto-adapts to any domain</td></tr>
<tr><td><b>Practice</b></td><td><code>challenge_guide.html</code> — 10 challenges, 1000 pts, built-in hints + progress tracking</td></tr>
<tr><td><b>Cleanup</b></td><td><code>.\Setup.ps1 -Cleanup</code></td></tr>
</table>

### Attack Paths

```
Path 1 │ Web app -> Backup config -> AS-REP Roasting -> Lateral Movement
Path 2 │ GPP Password -> Instant Domain Admin
Path 3 │ Kerberoasting -> Nested Groups -> Domain Admin
Path 4 │ DCSync Rights Abuse
Path 5 │ Constrained Delegation Exploitation
```

Full write-up: [`unbaked/README.md`](https://github.com/Aditya-k-Jangid/Labs_To_3xploit/tree/main/Unbacked/README.md)

---

```
┌──────────────────────────────────────────────┐
│  02 // CONTROL                                │
│  AD ESC1 Attack Lab                           │
└──────────────────────────────────────────────┘
```

A single-DC chain lab focused on AD Certificate Services abuse, built on top of a deliberately weakened domain.

<table>
<tr><td><b>Focus</b></td><td>Anonymous SMB enumeration, credential cracking, ACL abuse, AD CS ESC1 exploitation, path to Domain Admin</td></tr>
<tr><td><b>Deploy</b></td><td><code>LabSetup.ps1</code> on a fresh DC (AD DS + AD CS Enterprise Root CA required first)</td></tr>
<tr><td><b>Verify</b></td><td><code>Checker.ps1</code> — confirms the environment built correctly before attacking</td></tr>
<tr><td><b>Practice</b></td><td><code>Guide.html</code> — flag submission + hints</td></tr>
</table>

### Attack Path

```
Anonymous SMB -> Cracked creds -> ACL abuse -> AD CS ESC1 -> Domain Admin
```

Full write-up: [`Control/README.md`](https://github.com/Aditya-k-Jangid/Labs_To_3xploit/tree/main/Control/README.md)

---

<div align="center">

```
[ + ]  new labs get added as they're built  [ + ]
```

</div>
