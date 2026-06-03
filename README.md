# Autogit: Repository Orchestrator

Autogit is a robust, smart, and lightweight automation script designed to streamline Git workflow management across multiple repositories. Operating within a single parent directory, Autogit acts as a centralized command center to instantly diagnose tracking statuses, stage changes, commit, pull, push, and configure remote tracking across your entire local workspace.

Whether you run it as a standalone script or source it as a dynamic shell function, Autogit handles repository lifecycles securely while preserving your custom structural layouts and personal settings.

---

## 🚀 Quick Start

### 1. Installation & Environment Set Up

Clone the repository directly into your dedicated scripts workspace directory:

```bash
# Create and jump into your scripts directory
mkdir -p ~/scripts && cd ~/scripts

# Clone the orchestrator repository
git clone https://github.com/Kilobyte4621/autogit.git

# Make the core engine script executable
chmod +x ~/scripts/autogit/autogit.sh
```

### 2. Dual-Mode Deployment

Autogit features a **Dual-Mode Architecture**. You can interact with it using whichever deployment pattern fits your terminal style best:

#### Pattern A: Standalone Execution Path

Execute the script directly inside your terminal using its relative execution path:

```bash
./autogit/autogit.sh

```

#### Pattern B: Importable Shell Function

Source the script directly inside your active configuration file (`~/.bashrc` or `~/.zshrc`) to map it as a persistent shell utility:

```bash
echo "source ~/scripts/autogit/autogit.sh" >> ~/.bashrc
source ~/.bashrc

```

> 💡 Pro-Tip (Dynamic Sourcing): If you prefer not to hardcode individual source lines manually, you can use the `add2bash` utility available in the **ShellUtilities** repository. This tool allows you to dynamically sweep, clean, and import an entire directory of independent .sh function scripts directly into your active profile environment in one clean sweep.

Once sourced, invoke the engine natively from anywhere in your filesystem simply by typing:

```bash
autogit

```

---

## 🛠️ Detailed Operational Lifecycle (Under the Hood)

Autogit executes sequentially across six isolated workflow phases:

```
[1] Host Environment Validation
               │
               ▼
[2] Safe Target Selection (Reads/Updates .autogit_list)
               │
               ▼
[3] Multi-Threaded State Analysis (git fetch + evaluation)
               │
               ▼
[4] Comprehensive Health Matrix Generation
               │
               ▼
[5] Interactive Decision Engine (User Choices 1-6)
               │
               ▼
[6] Post-Action Operational Summary

```

### Phase 1: Context Isolation

The engine scans the initialization variables to evaluate exactly how it was executed. It locks onto the base path container (`~/scripts`) and instantiates local variables to completely protect your active parent shell from environment variable leakage or unintended pollution.

### Phase 2: Non-Destructive List Generation & Sync

The engine targets `.autogit_list` inside your application directory.

* **If missing:** It requests approval to deploy a fresh tracking configuration template.
* **If present:** It fires a **Smart Synchronization Append Engine**. It parses the existing tracking list—skipping and preserving your custom comments or ordered parameters—cross-references it against physical directory entries in your workspace, and cleanly appends only newly discovered repositories to the bottom of the tracking list.

### Phase 3: Multi-Threaded Evaluation Engine

The script sequentially drops into each selected repository path and runs isolated Git inspection commands using localized stderr redirections to avoid terminal noise. It analyzes:

* Uncommitted staging layers using `--porcelain` tracking.
* Branch divergences by resolving object hashes across localized references (`@`), remote tracking hooks (`@{u}`), and their shared historical intersection points (`merge-base`).

### Phase 4: Actionable Matrix Compilation

The compiled statuses are parsed into separate internal tracking arrays, outputting a visual layout grouped by specific required actions (e.g., Need Commit, Need Push, Need Pull).

### Phase 5: Execution Orchestration Loop

The user chooses a recovery path via an interactive terminal menu. The engine streams active Git output directly back to your terminal window during execution so you monitor real-time tracking events.

### Phase 6: Graceful Environment Restoration

The script checks internal error matrices, alerts you to network or key dropping failures, safely pops your terminal back into your pre-execution working directory context (`$ORIGINAL_PWD`), and terminates cleanly with proper POSIX return structures.

---

## 📋 Command Line Options & Core Flags

When initializing Autogit, you can pass parameters to bypass prompts or reconfigure targeting scope on the fly:

| Short Flag | Long Flag | Functional Target Identity |
| --- | --- | --- |
| `-a` | `--all` | **Global Evaluation Mode**: Overrides `.autogit_list` to automatically scan every single directory containing a valid `.git` framework in your parent folder. |
| `-y` | `--yes` | **Automation Override**: Completely bypasses all interactive confirmation prompts and sets the runtime choice to automatic confirmation. |
|  | `--skip-self` | **Self Inspection Bypass**: Prevents the `autogit` script folder itself from being queried or changed during scans. |
| `-h` | `--help` | **Help System**: Outputs the operational command documentation and exits instantly. |

---

## 🛡️ Built-In Security Protocols & Core Safeguards

Autogit enforces production-level safety measures to protect your code and terminal state:

### 1. Isolated Execution Failure Boundary

The termination layer uses a dynamic `terminate_with` routine. If running standalone, it calls `exit` to pass operational signals back to systemic shell managers. If sourced, it switches automatically to `return`, completely preventing the script from closing or crashing your active terminal window session if an unexpected fault occurs.

### 2. Leak-Proof Working Tree Memory (`ORIGINAL_PWD`)

Before descending into lower-level project folders, Autogit registers your starting path location. Regardless of nested step errors, network drops, or execution cancellations, it safely returns your terminal session to the exact directory you were in before triggering the script.

### 3. Private Configuration Protection (Automatic Gitignore Guards)

To prevent tracking metadata, custom workflows, or local workspace names from leaking into remote public repositories, Autogit inspects its own environment tracking. It intercepts initialization workflows and automatically configures a `.gitignore` guard rule for `.autogit_list`.

### 4. Zero Ghost Branch Crashes (Smart Branch Detection)

When linking new local repositories to GitHub remote origins via SSH, running a push on an empty repository without any commits triggers a critical Git refspec failure (`src refspec master does not match any`). Autogit prevents this by deploying a fault-tolerant evaluation layer:

```bash
git branch --show-current
# If empty, evaluates symbolic references -> falls back to init.defaultBranch config -> defaults to main

```

If a repository is completely empty, the engine halts the sync pipeline and instructs you to build an initial commit before pushing code into the cloud.

---

## 📝 Customizing Workspace Targets

Your `.autogit_list` file handles target tracking configurations. It uses standard comment strings (`#`) for layout organization. You can comment out a line to skip checking a repository without deleting it from your list:

```text
# Active Daily Core Projects
ShellUtilities
ArchivePar2

# On-Hold/Archived Tracking Targets (Autogit skips these automatically)
# TestSandboxProject
# LegacyDataParser

# New Repositories are appended automatically right below here:

```