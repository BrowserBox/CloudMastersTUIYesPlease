# CloudMasters

<p align="center">
  <img src="logo.png" alt="CloudMasters Logo" width="220">
  <br>
  <b>One TUI to rule them all.</b>
  <br>
  <i>Shop, Compare, and Rent VPS across AWS, Azure, GCP, Hetzner, and Vultr.</i>
</p>

<p align="center">
  <a href="https://github.com/BrowserBox/CloudMastersTUIYesPlease/releases/latest">
    <img src="https://img.shields.io/github/v/release/BrowserBox/CloudMastersTUIYesPlease?style=for-the-badge&color=blue" alt="Latest Release">
  </a>
  <a href="#download"><img src="https://img.shields.io/badge/macOS-PKG_Installer-white?logo=apple&style=for-the-badge" alt="macOS"></a>
  <a href="#download"><img src="https://img.shields.io/badge/Linux-Binary-white?logo=linux&style=for-the-badge" alt="Linux"></a>
  <a href="#download"><img src="https://img.shields.io/badge/Windows-Binary-white?logo=windows&style=for-the-badge" alt="Windows"></a>
</p>

---

## 🚀 What is this?

**CloudMasters** is the ultimate Terminal User Interface (TUI) for developers who are tired of juggling 5 different browser tabs just to find a server.

**We unify the cloud market.** Instead of navigating complex, slow web portals, CloudMasters lets you **search 58,000+ offers** globally, find the cheapest compute (like a $0.001/hr instance in Mumbai), and provision it instantly—all from your keyboard.

**Supported Providers:** AWS, Azure, GCP, Hetzner, and Vultr.

---

## 📸 The Tour

### 1. The Market: Find the Best Deal
Stop guessing if Hetzner is cheaper than AWS for your specific RAM/CPU needs. CloudMasters indexes offers from all provider APIs and caches them locally (SQLite) for instant searching.

![The Market View](market-offers.png)

*   **Global Search:** Filter by Cloud, Region, RAM, CPU Arch, and Price.
*   **Live Sorting:** Instantly see who has the cheapest `2vCPU / 8GB RAM` instance.
*   **Discovery:** During development, we found Azure instances in Mumbai for **$0.001/hour** (shown above).
*   *> Note: Prices shown are the lowest available for that SKU. This often includes Spot/Preemptible pricing mixed with On-Demand.*

### 2. Rent-A-Box: Instant Provisioning
Once you find the box you want, rent it with a single keystroke. No 12-step wizards, no up-selling pages. Just confirm the specs and go.

![Rent A Box Modal](rent-a-box.png)

### 3. The Dashboard: Unified Management
Your active servers appear here, normalized across all providers. A Hetzner box looks just like an EC2 instance.

![Dashboard View](main-dash.png)

*   **Unified Actions:** `(s)` SSH, `(p)` Power/Reboot, `(d)` Delete/Nuke.
*   **Audit Trail:** See that green text at the bottom? That is your **activity log**. Every command CloudMasters runs on your behalf is logged to a daily gzipped file locally. You always know exactly what happened.

---

## 🛠 Under the Hood (The Wrapper Architecture)

CloudMasters is a **native Go binary** that acts as a secure, unified wrapper around your existing vendor CLIs.

1.  **Intent Translation:** You press `Enter` to rent a box.
2.  **Command Construction:** We build the specific `aws ec2...` or `az vm create...` command.
3.  **Execution & Logging:** We run the command using your local credentials and log the output to your local audit trail.

**Safety First:**
We are a "Shopping" tool, not a full "Infrastructure-as-Code" replacement. We are optimized for spinning up resources safely and quickly. Our delete commands are deliberate and focused only on the boxes you select in the UI.

### Prerequisites
You must have the respective provider CLIs installed and authenticated on your machine to use them with CloudMasters:
*   `aws` (AWS CLI)
*   `az` (Azure CLI)
*   `gcloud` (Google Cloud SDK)
*   `hcloud` (Hetzner CLI)
*   `vultr-cli` (Vultr CLI)

---

<a id="download"></a>

## 📥 Installation

### Latest Version: **v2.1.2**

### macOS (Recommended)

Download the `.pkg` installer from the latest release. This will verify the binary and install it to `/usr/local/bin/cloudmasters`.

[**Download macOS Installer (v2.1.2)**](https://github.com/BrowserBox/CloudMastersTUIYesPlease/releases/download/v2.1.2/CloudMasters-2.1.2.pkg)

**Pro Tip:** Add an alias to your `.zshrc` or `.bashrc`:
```bash
alias cm="cloudmasters"
```

### Linux & Windows

Download the standalone binary for your architecture from the **[Releases Page](https://github.com/BrowserBox/CloudMastersTUIYesPlease/releases/latest)**.

**Linux Example:**
```bash
# Download (Verify version number)
wget https://github.com/BrowserBox/CloudMastersTUIYesPlease/releases/download/v2.1.2/cloudmasters_2.1.2_linux_amd64.tar.gz

# Extract
tar -xvf cloudmasters_2.1.2_linux_amd64.tar.gz

# Move to path
chmod +x cloudmasters
sudo mv cloudmasters /usr/local/bin/cloudmasters
```

---

## 💎 Pricing & Model

**CloudMasters is paid software with a Free Trial.**

We are building a sustainable tool where **you are the customer, not the product.**

*   **The Trial:** Full access to shop and manage boxes.
*   **The License:** [Purchase a License](https://license.dosaygo.com/cloudmasters-buy)

---

## ❓ FAQ / Known Issues

*   **Spot vs On-Demand:** Currently, the Market view shows the *lowest possible price* for a machine type. This means you might be looking at Spot/Preemptible pricing. We are working on splitting these views.
*   **Data Freshness:** We fetch fresh offer data in the background. If a price looks wrong, hit `r` to Refresh.
*   **Bugs:** Cloud pricing APIs are messy. If you see something weird, let us know.

## 📬 Feedback

Found a bug? Have a feature request?

*   **Email:** `cloudmasters@browserbox.io`
*   **Issue:** [Open a ticket in this repo](https://github.com/BrowserBox/CloudMastersTUIYesPlease/issues)

*Happy Shopping.*