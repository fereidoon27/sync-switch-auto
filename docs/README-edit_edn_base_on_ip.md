# Edit EDN Base on IP

## Description

**Edit EDN Base on IP** is a Bash script that automatically configures environment variables and proxy settings on multiple virtual machines (VMs), based on their network location (internal or external). It detects whether a VM resides in an internal network and adjusts settings in `system.edn` files and environment profiles accordingly.

The script is designed to work in both **interactive** and **automated** modes. It processes multiple VMs in parallel to speed up operations and utilizes SSH for remote access and control.

---

## Installation Instructions

1. **Clone the repository:**

   ```bash
   git clone https://github.com/fereidoon27/Synchronize_Switch.git
   cd Synchronize_Switch
   ```

2. **Ensure script permissions:**

   ```bash
   chmod +x edit_edn_base_on_ip.sh
   ```

3. **Prepare configuration files:**
   - Confirm the existence of `Info/servers.conf` with correct server information.

4. **Dependencies:**
   - Requires `bash`, `ssh`, and `rsync`.

5. **Prepare environment files:**
   - Internal and external environment files are expected in:
     - `$HOME/ansible/env/envs` (internal)
     - `$HOME/ansible/env/newpin/envs` (external)

---

## Usage

### Basic Usage (Interactive Mode):

```bash
./edit_edn_base_on_ip.sh
```

- You will be prompted to:
  - Select a datacenter.
  - Choose VMs to process.

### Automated Mode (Non-interactive):

```bash
./edit_edn_base_on_ip.sh --datacenter <datacenter_name> --servers <vm_numbers>
```

#### Example:

```bash
./edit_edn_base_on_ip.sh --datacenter cloudzy --servers 1,3,5
```

### Options:
| Option                  | Description                                                      |
|-------------------------|------------------------------------------------------------------|
| `-d`, `--datacenter`    | Specify the datacenter name.                                    |
| `-s`, `--servers`       | Specify servers to process (comma-separated numbers or `all`).  |
| `-h`, `--help`          | Show the help message.                                          |

---

## Code Structure

```
Synchronize_Switch/
├── edit_edn_base_on_ip.sh    # This script
├── Info/
│   └── servers.conf          # Server configuration (required)
└── ansible/
    └── env/                  # Internal and external environment files (expected path)
```

- `edit_edn_base_on_ip.sh`: Main script to update configuration files.
- `Info/servers.conf`: Lists server groups, VMs, IPs, usernames, and ports.
- Internal/external env files are copied depending on network type.

---

## How It Works

1. **Detects Network Type:**
   - Runs a script on each VM to determine if the VM is in an internal network (based on IP address pattern).
2. **Copies Environment Files:**
   - Chooses the correct `envs` file based on network type and copies it to `/etc/profile.d/` as `hermes-env.sh`.
3. **Updates `system.edn` Files:**
   - Searches for `system*.edn` files and modifies proxy settings accordingly (`:use-proxy?`, `Set-Proxy?`).
4. **Parallel Processing:**
   - Runs on multiple servers in parallel, controlled by `MAX_PARALLEL` (default is 6).
5. **Logging:**
   - Creates logs for each VM's process and outputs summaries.

---

## Testing Instructions

1. **Run against a single VM first:**
   ```bash
   ./edit_edn_base_on_ip.sh --datacenter azma --servers 1
   ```

2. **Check logs and VM status:**
   - Review VM-specific logs in `/tmp/` or wherever specified.
   - Validate that `system.edn` files and environment variables are correctly updated.

---

## Known Issues

- SSH keys must be pre-configured for passwordless login.
- Requires correct internal/external `envs` files in the expected directories.

---

## Author

Fereidoon27  
GitHub: [https://github.com/fereidoon27](https://github.com/fereidoon27)

