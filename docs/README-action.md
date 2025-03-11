# Action.sh - Service Migration & Control Script

## Description

**Action.sh** is a powerful Bash script designed to automate the migration and management of services across different datacenters and virtual machines (VMs). It supports deploying, starting, stopping, and purging services like **binance**, **kucoin**, and **gateio** on target VMs. The script uses SSH to execute commands remotely and supports parallel job execution for faster, scalable operations.

This script is particularly useful for **switching services** between VMs in different datacenters, ensuring minimal downtime and seamless service continuity.

---

## Installation Instructions

1. **Clone the repository:**

   ```bash
   git clone https://github.com/fereidoon27/Synchronize_Switch.git
   cd Synchronize_Switch
   ```

2. **Ensure script permissions:**

   ```bash
   chmod +x action.sh
   ```

3. **Prepare configuration files:**
   - Verify `Info/servers.conf` exists and includes valid server entries.
   - Confirm deployment scripts are present in the `deployment_scripts/` directory:
     - `deploy_all_<service>.sh`
     - `start_all_<service>.sh`
     - `stop_all_<service>.sh`
     - `purge_all_<service>.sh`

4. **Dependencies:**
   - Requires `bash`, `ssh`, and `scp`.

---

## Usage

### Basic Usage (Interactive Mode):

```bash
./action.sh
```

Prompts the user to select:
- Source datacenter and VMs.
- Destination datacenter and VMs.
- Services to migrate.
- Parallel job execution settings.

### Automated Mode (Non-interactive):

```bash
./action.sh -s <source_dc> -d <dest_dc> -v <source_vm_numbers> -D <dest_vm_numbers> -p <parallel_jobs> -r <services> -y
```

#### Example:

```bash
./action.sh -s arvan -d cloudzy -v 1,2 -D 4,5 -p 3 -r binance,kucoin -y
```

### Options:

| Option            | Description                                                                                         |
|-------------------|-----------------------------------------------------------------------------------------------------|
| `-s`             | Source datacenter name.                                                                             |
| `-d`             | Destination datacenter name.                                                                        |
| `-v`             | Source VM numbers (comma-separated or `all`).                                                       |
| `-D`             | Destination VM numbers (comma-separated).                                                           |
| `-p`             | Maximum number of parallel jobs.                                                                    |
| `-r`             | Services to migrate (comma-separated: `binance`, `kucoin`, `gateio`).                               |
| `-y`             | Non-interactive mode (skip confirmation prompts).                                                    |
| `-V`             | Verbose mode (additional logging output).                                                           |
| `-h`             | Show the help message.                                                                              |

---

## Code Structure

```
Synchronize_Switch/
├── action.sh                      # Main service migration script
├── deployment_scripts/            # Contains deploy/start/stop/purge scripts for services
│   ├── deploy_all_binance.sh
│   ├── start_all_binance.sh
│   ├── stop_all_binance.sh
│   ├── purge_all_binance.sh
│   └── ...
├── Info/
│   └── servers.conf               # Server configuration file
└── logs/                          # (Optional) Logs created during actions
```

- `action.sh`: Orchestrates the full migration process for services.
- `deployment_scripts/`: Contains service-specific scripts for deployment, start, stop, and purge.
- `Info/servers.conf`: Defines VM details for all datacenters.
- Log files: By default, logs are saved in `$HOME/service_actions_YYYYMMDD.log`.

---

## How It Works

1. **Prepares SSH Connections**:
   - Establishes persistent SSH sessions using ControlMaster for efficiency.
2. **Copies Deployment Scripts**:
   - Transfers necessary deployment scripts to remote servers.
3. **Executes Actions by Service**:
   - On destination VMs: deploy and start services.
   - On source VMs: stop and purge services after successful destination deployment.
4. **Parallel Processing**:
   - Runs multiple migration jobs in parallel using background processes.
5. **Logs All Operations**:
   - Tracks each step (started, completed, failed) with timestamps.

---

## Testing Instructions

1. **Dry-run (manual testing):**
   - Test SSH connections and ensure control sockets are working:
     ```bash
     ssh -o ControlMaster=auto -o ControlPersist=1h user@host
     ```
   - Run a single job manually with limited parallel jobs (`-p 1`) for verification.

2. **Check log files:**
   - Located at `$HOME/service_actions_YYYYMMDD.log`
   - Review the logs to verify successful job completion and troubleshoot failures.

---

## Known Issues

- Requires passwordless SSH setup between the main machine and all VMs.
- Service-specific scripts (`deploy`, `start`, `stop`, `purge`) must exist and be executable.
- VMs in the same datacenter must not overlap in source and destination mappings.

---

## Roadmap

- Improve retry logic on SSH connection failures.
- Add JSON/YAML configuration support to simplify server and service management.
- Explore converting the script into a Go application for better performance and maintainability.

---

## License

This project is licensed under the MIT License.

---

## Author

Fereidoon27  
GitHub: [https://github.com/fereidoon27](https://github.com/fereidoon27)

