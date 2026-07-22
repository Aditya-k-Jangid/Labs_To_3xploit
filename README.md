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

![Labs](https://img.shields.io/badge/labs-1-blueviolet?style=for-the-badge)
![Focus](https://img.shields.io/badge/focus-AD%20%7C%20Web%20%7C%20Pentest-red?style=for-the-badge)
![Status](https://img.shields.io/badge/status-active-brightgreen?style=for-the-badge)

</div>

---

## Lab Index

| # | Lab | Type | Difficulty | Focus | Status |
|:-:|-----|------|:----------:|-------|:------:|
| 01 | **[Unbaked](./unbaked/)** | Active Directory | Medium-Hard | Kerberoasting · AS-REP · GPP · DCSync · Delegation | Playable |

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

### Challenge Breakdown

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

Full write-up: [`unbaked/README.md`](./unbaked/README.md)

---

<div align="center">

```
[ + ]  new labs get added as they're built  [ + ]
```

</div>
