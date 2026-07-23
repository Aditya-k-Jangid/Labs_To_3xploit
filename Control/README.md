```
   _____ ____  _   _ _____ ____   ___  _
  / ____/ __ \| \ | |_   _|  __ \ / _ \| |
 | |   | |  | |  \| | | | | |__) | | | | |
 | |   | |  | | . ` | | | |  _  /| | | | |
 | |___| |__| | |\  |_| |_| | \ \| |_| | |____
  \_____\____/|_| \_|_____|_|  \_\\___/|______|

        A D   E S C 1   A T T A C K   L A B
              created by Sawsage
```

---

### [!] READ THIS FIRST

```
+--------------------------------------------------------------------+
|  ISOLATED LAB ONLY.                                                |
|                                                                     |
|  This repo intentionally weakens a Windows domain: null sessions,  |
|  guest access, broken ACLs, a vulnerable cert template, disabled   |
|  Defender/firewall. Run it ONLY on a VM you own, on a host-only    |
|  or internal network with no route to your real network.          |
+--------------------------------------------------------------------+
```

---

## Table of Contents

```
 0. Get the virtualization software & OS image
 1. Build the lab environment
 2. Run the setup script
 3. Run the checker
 4. Open the guide
 5. Start pentesting
```

---

## 0. Get the virtualization software & OS image  ( ._.)

Pick **one** hypervisor:

| Hypervisor | Platform | Link |
|---|---|---|
| VMware Workstation Pro (free for personal use) | Windows / Linux | https://www.vmware.com/products/workstation-pro.html |
| Oracle VirtualBox (free, open source) | Windows / Linux / macOS | https://www.virtualbox.org/wiki/Downloads |

Then grab the OS image:

| Item | Link |
|---|---|
| Windows Server 2022 Evaluation ISO (180-day trial) | https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022 |
| Windows Server 2025 Evaluation ISO (180-day trial) | https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025 |

**Install steps:**

1. Install your chosen hypervisor using its default options.
2. Create a new VM:
   - **RAM:** 4 GB minimum (8 GB recommended)
   - **Disk:** 60 GB, dynamically allocated
   - **Network adapter:** Host-only or Internal Network (**not** Bridged/NAT to your home network)
3. Mount the Windows Server ISO and complete the installation (choose **Desktop Experience**, not Server Core — you'll want the GUI for `certtmpl.msc` later).
4. Install VM tools (VMware Tools / Guest Additions) for clipboard/shared folder support.

---

## 1. Build the lab environment  \(^_^)/

Do this once the VM is booted into a fresh Windows Server install. This part's on you — pick whatever names/addressing you like — just make sure each box below is checked before moving on:

```
[ ] Static IP set on the VM's network adapter (don't leave it on DHCP)
[ ] Computer renamed to something you'll recognize as the DC (e.g. DC01)
[ ] AD DS role installed, server promoted to a new forest
    (pick your own domain name, e.g. yourlab.local)
[ ] DNS role installed alongside AD DS
    (automatic if you let Install-ADDSForest install DNS for you)
[ ] AD Certificate Services role installed, Enterprise Root CA configured
    (required for the ESC1 step later)
[ ] Logged in as Domain Administrator for every step from here on
```

Once your domain, DNS, and CA are all up, you're ready to run the automated setup.

---

## 2. Run the setup script  (>_<)

From an **elevated PowerShell** prompt on the DC:

```powershell
iex (iwr 'https://raw.githubusercontent.com/Aditya-k-Jangid/Labs_To_3xploit/refs/heads/main/Control/LabSetup.ps1')
```

This provisions the users, SMB share, ACLs, AD Recycle Bin, ESC1 certificate template, and drops the flags. Check the console output for a summary once it finishes.

---

## 3. Run the checker  (-_-)

Verifies the environment was built correctly before you start attacking it:

```powershell
iex (iwr 'https://raw.githubusercontent.com/Aditya-k-Jangid/Labs_To_3xploit/refs/heads/main/Control/Checker.ps1')
```

Re-run this any time something seems off — it'll tell you which piece of the setup didn't take.

---

## 4. Open the guide  (o_o)

Open **`Guide.html`** in a browser (double-click it, or `Start-Process Guide.html`). From there you can:

- Submit flags as you find them
- Request hints if you get stuck on a step

---

## 5. Start pentesting  ¯\\\_(ツ)_/¯

You're on your own from here. 

<img width="220" height="124" alt="image" src="https://github.com/user-attachments/assets/693f02a5-f848-494b-aa88-ddb61373a0ba" />


Good luck, and don't forget to snapshot the VM before you start so you can roll back and replay the chain.

```
     _____ ____   ____  _____   _    _   _  _____ _  __
    / ____/ __ \ / __ \|  __ \ | |  | | | |/ ____| |/ /
   | |  __| |  | | |  | | |  | || |  | | | | |    | ' /
   | | |_ | |  | | |  | | |  | || |  | | | | |    |  <
   | |__| | |__| | |__| | |__| || |__| |_| | |____| . \
    \_____\____/ \____/|_____/  \____/\___/ \_____|_|\_\
```
