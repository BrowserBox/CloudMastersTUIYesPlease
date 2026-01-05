# CloudMasters

<p align="center">
  <img src="logo.png" alt="CloudMasters Logo" width="200">
  <br>
  <b>One TUI to rule them all.</b>
  <br>
  <i>Shop, Compare, and Rent VPS across AWS, Azure, GCP, Hetzner, and Vultr.</i>
</p>

<p align="center">
  <a href="#download"><img src="https://img.shields.io/badge/macOS-PKG_Installer-white?logo=apple&style=for-the-badge" alt="macOS"></a>
  <a href="#download"><img src="https://img.shields.io/badge/Linux-Binary-white?logo=linux&style=for-the-badge" alt="Linux"></a>
  <a href="#download"><img src="https://img.shields.io/badge/Windows-Binary-white?logo=windows&style=for-the-badge" alt="Windows"></a>
</p>

---

## What is this?

**CloudMasters** is a Terminal User Interface (TUI) for developers who are tired of opening 5 different browser tabs just to find a server.

We unify the cloud market. Instead of navigating complex web portals, CloudMasters lets you **search 58,000+ offers** globally, find the cheapest compute (like a $0.001/hr instance in Mumbai), and provision it instantly—all from your keyboard.

**We currently support:** AWS, Azure, GCP, Hetzner, and Vultr.

---

## The Tour

### 1. The Market: Find the Best Deal
Stop guessing if Hetzner is cheaper than AWS for your specific RAM/CPU needs. CloudMasters indexes offers from all provider APIs and caches them locally (SQLite) for instant searching.

![The Market View](PATH_TO_SCREENSHOT_3_MARKET.png)

*   **Global Search:** Filter by Cloud, Region, RAM, CPU Arch, and Price.
*   **Live Sorting:** Instantly see who has the cheapest `2vCPU / 8GB RAM` instance.
*   **Discovery:** During development, we found Azure instances in Mumbai for **$0.001/hour** (shown above).
*   *> Note: Prices shown are the lowest available for that SKU. This often includes Spot/Preemptible pricing mixed with On-Demand.*

### 2. Rent-A-Box: Instant Provisioning
Once you find the box you want, rent it with a single keystroke. No 12-step wizards, no up-selling pages. Just confirm the specs and go.

![Rent A Box Modal](PATH_TO_SCREENSHOT_2_RENT.png)

### 3. The Dashboard: Unified Management
Your active servers appear here, normalized across all providers. A Hetzner box looks just like an EC2 instance.

![Dashboard View](PATH_TO_SCREENSHOT_1_DASHBOARD.png)

*   **Unified Actions:** `(s)` SSH, `(p)` Power/Reboot, `(d)` Delete/Nuke.
*   **Activity Log:** See that green text at the bottom? That is your **audit trail**. Every command CloudMasters runs on your behalf is logged to a daily gzipped file. You always know exactly what happened.

---

## How it Works (The Wrapper Architecture)

CloudMasters is a **native Go binary** that acts as a secure wrapper around your existing vendor CLIs.

1.  **We translate intents:** You press `Enter` to rent a box.
2.  **We build the command:** We construct the specific `aws ec2...` or `az vm create...` command.
3.  **We execute & log:** We run the command using your local credentials and log the output to your local audit trail.

**Safety First:**
We are a "Shopping" tool, not a "Infrastructure-as-Code" replacement. We are optimized for spinning up resources safely. We don't want to accidentally delete your production database, so our delete commands are deliberate and focused only on the boxes you select.

*Requirements: You must have the respective provider CLIs (aws-cli, az, gcloud, hcloud, vultr-cli) installed and authenticated on your machine.*

---

<a id="download"></a>

## Installation

### macOS (Recommended)

Download the `.pkg` installer from the **[Latest Release](https://github.com/YOUR_ORG/get-cloudmasters/releases)**.
This installs to `/usr/local/bin/cloudmasters`.

**Pro Tip:** Add an alias to your `.zshrc` or `.bashrc`:
```bash
alias cm="cloudmasters"
```

### Linux & Windows

Download the standalone binary for your architecture from the **[Releases Page](https://github.com/YOUR_ORG/get-cloudmasters/releases)**.

```bash
# Example for Linux
chmod +x cloudmasters-linux-amd64
sudo mv cloudmasters-linux-amd64 /usr/local/bin/cloudmasters
```

---

## Pricing & Model

**CloudMasters is paid software with a Free Trial.**

We are building a sustainable tool where **you are the customer, not the product.**

*   **The Trial:** Full access to shop and manage boxes.
*   **The License:** [Link to Purchase / Stripe / Etc]

---

## FAQ / Known Issues

*   **Spot vs On-Demand:** Currently, the Market view shows the *lowest possible price* for a machine type. This means you might be looking at Spot/Preemptible pricing. We are working on splitting these views in v1.1.
*   **Data Freshness:** We fetch fresh offer data in the background. If a price looks wrong, hit `r` to Refresh.
*   **Bugs:** This is v1.0. Pricing APIs are messy. If you see something weird, let us know.

## Feedback

Found a bug? Have a feature request?

*   **Email:** `cloudmasters@browserbox.io`
*   **Issue:** Open a ticket in this repo.

*Happy Shopping.*
