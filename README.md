# Synchronize_Switch

## Description

**Synchronize_Switch** is a powerful automation framework designed to streamline the management and migration of services across different datacenters and virtual machines (VMs). It enables users to synchronize files, configure environments, and control services such as **binance**, **kucoin**, and **gateio** through a combination of interactive and automated workflows.

The repository provides a modular set of Bash scripts that allow for:
- File synchronization from a main VM to destination VMs.
- Automated environment setup based on network detection.
- Seamless service switching and deployment across datacenters.

This system is particularly useful for managing **multi-datacenter service deployments** with minimal downtime and ensuring consistency across distributed infrastructure.

---

## Features

- Interactive and non-interactive execution modes.
- Parallel job processing for efficiency.
- SSH multiplexing for faster connection handling.
- Modular and extensible design.
- Detailed logging for audit and debugging.

---

## Installation Instructions

1. **Clone the repository:**

   ```bash
   git clone https://github.com/fereidoon27/Synchronize_Switch.git
   cd Synchronize_Switch
   ```

2. **Set script permissions:**

   ```bash
   chmod +x *.sh
   chmod +x deployment_scripts/*.sh
   ```

3. **Prepare configuration files:**
   - Edit `Info/servers.conf` to match your datacenter and VM details.
   - Ensure environment files are available in:
     - `$HOME/ansible/env/envs` (for internal networks)
     - `$HOME/ansible/env/newpin/envs` (for external networks)

4. **Dependencies:**
   - `bash`
   - `rsync`
   - `ssh` and `scp`

---

## Usage

### Run the Main Menu Interface:

```bash
./main.sh
```

#### Menu Options:

| Option | Description |
|--------|-------------|
| 1 | Synchronize: Sync files from Main VM to destination VMs. |
| 2 | Update Environment & Edit EDN: Configure proxy and env variables based on network. |
| 3 | Switch Services: Deploy, start, stop, and purge services across datacenters. |
| 4 | Run Complete Workflow Sequentially: Collect inputs and run all tasks in order. |
| 0 | Exit |

### Example Complete Workflow:

```bash
# Start the complete workflow
./main.sh
# Choose option 4 from the menu
```

---

## Code Structure

```
Synchronize_Switch/
├── main.sh                       # Orchestrator script
├── simple_synce-main2vm.sh       # File synchronization script
├── edit_edn_base_on_ip.sh        # Environment & EDN config updater
├── action.sh                     # Service migration and control
├── input.sh                      # Interactive input collection
├── deployment_scripts/           # Deployment scripts for services
│   ├── deploy_all_binance.sh
│   ├── start_all_binance.sh
│   ├── stop_all_binance.sh
│   ├── purge_all_binance.sh
│   └── ... (other services)
├── Info/
│   ├── servers.conf              # VM and datacenter configuration file
│   └── Collected_Input           # Saved user input for workflows
└── logs/                         # Logs created during operations (optional)
```

---

## Individual Script Descriptions

### 1. `main.sh`
- Central menu to run synchronization, environment updates, and service switching.
- Handles complete workflows based on user input.

### 2. `simple_synce-main2vm.sh`
- Synchronizes files from the main machine to selected destination VMs.
- Supports parallel file transfers with SSH multiplexing and rsync.

### 3. `edit_edn_base_on_ip.sh`
- Detects network type (internal/external) on VMs.
- Updates environment files and proxy settings in system configuration files.

### 4. `action.sh`
- Executes deploy, start, stop, and purge actions on services across datacenters.
- Supports parallel job execution and provides detailed logging.

### 5. `input.sh`
- Provides an interactive interface for selecting services, datacenters, VMs, and job settings.
- Saves input to `Info/Collected_Input` for use by other scripts.

---

## Testing Instructions

1. **Run `input.sh` to collect inputs manually:**

   ```bash
   ./input.sh
   cat Info/Collected_Input
   ```

2. **Run scripts individually to test:**

   ```bash
   ./simple_synce-main2vm.sh
   ./edit_edn_base_on_ip.sh
   ./action.sh
   ```

3. **Run the complete workflow through `main.sh`.**

---

## Known Issues

- SSH key-based authentication is required between the main machine and all target VMs.
- `servers.conf` must be kept accurate to prevent errors.
- SSH multiplex control files in `/tmp` may require manual cleanup after failures.

---

## Roadmap

- Convert Bash scripts to Go for improved performance and maintainability.
- Add support for JSON/YAML configuration files.
- Implement monitoring and alerting features.
- Build a web-based UI for non-technical users.

---

## License

This project is licensed under the MIT License.

---

## Author

Fereidoon27  
GitHub: [https://github.com/fereidoon27](https://github.com/fereidoon27)

