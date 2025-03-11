# Synchronize\_Switch

## Description

**Synchronize\_Switch** is a powerful automation tool designed to streamline the management and migration of services across different datacenters and virtual machines (VMs). It enables users to synchronize files, configure environments variable, and control services such as **binance**, **kucoin**, and **gateio** through a combination of interactive and automated workflows.

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

## &#x20;Instructions

1. **Clone the repository:**

   ```bash
   git clone https://github.com/fereidoon27/Synchronize_Switch.git
   cd $HOME/Synchronize_Switch
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



---

## Usage

### Run the Main Menu Interface:

```bash
./main.sh
```

#### Menu Options:

| Option | Description                                                                        |
| ------ | ---------------------------------------------------------------------------------- |
| 1      | Synchronize: Sync files from Main VM to destination VMs.                           |
| 2      | Update Environment & Edit EDN: Configure proxy and env variables based on network. |
| 3      | Switch Services: Deploy, start, stop, and purge services across datacenters.       |
| 4      | Run Complete Workflow Sequentially: Collect inputs and run all tasks in order.     |
| 0      | Exit                                                                               |

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

## Hypothetical Workflow Examples

Below are two hypothetical examples showcasing how to use the **Synchronize\_Switch** workflow. These scenarios assume the `servers.conf` file is configured properly and all scripts are executable.

---

### Scenario 1: Migrate Binance Service from cr1arvan  to cr1cloudzy

#### Step 1: Environment Setup

The `servers.conf` file is stored in the `Info/` directory within the project structure. Each line in this file follows the format:

```
<datacenter>|<vm_name>|<ip_address>|<host_name>|<username>|<ssh_port>
```

For example:

```
azma|cr1azma|172.20.10.31|172.20.10.31|ubuntu|22
```

```
# servers.conf excerpt:
arvan|cr1arvan|185.204.170.177|cr1arvan.stellaramc.ir|ubuntu|22
cloudzy|cr1cloudzy|172.86.68.12|cr1cloudzy.stellaramc.ir|ubuntu|22
```

#### Step 2: Start the Workflow

```bash
./main.sh
```

#### Step 3: Select Workflow Option

```
4: Run Complete Workflow Sequentially
```

#### Step 4: Provide the input values required for this migration.

- **Service Selection:** binance
- **Source Datacenter:** arvan
- **Destination Datacenter:** cloudzy
- **Source VM:** cr1arvan
- **Destination VM:** cr1cloudzy
- **Max Parallel Jobs:** 1

  This variable controls how many tasks run simultaneously. For example, setting it to `2` allows two file synchronizations or service switches to happen at the same time. Increasing parallel jobs can speed up operations when working with multiple VMs but may consume more system resources.

#### Step 5: Review and Confirm Input

```text
SELECTED SERVICES: binance
SOURCE_DATACENTER: arvan
Selected SOURCE VMs:
  - cr1arvan
DEST_DATACENTER: cloudzy
Selected DEST VMs:
  - cr1cloudzy
MAX_PARALLEL_JOBS: 1
```

#### Step 6: Workflow Execution

This is the start of the execution phase on the selected VMs. During this stage, the user will only observe the workflow steps as they are processed, with no further input required.

1. Synchronizes binance files from Main to cr1cloudzy.

2. Updates environment variables on cr1cloudzy.

3. Deploys and starts binance service on cr1cloudzy.

4. Stops and purges binance service on cr1arvan.



#### Expected Outcome

```
[✓] Files synced to cr1cloudzy
[✓] Environment updated on cr1cloudzy
[✓] Binance deployed and started on cr1cloudzy
[✓] Binance stopped and purged from cr1arvan
```

#### Logs and Timestamps

- A detailed log of the entire operation is saved in:

  ```
  $HOME/service_actions_<date>.log
  $HOME/sync_<date>.log
  ```

  (e.g., service\_actions\_20250311.log)

- Each log entry includes precise timestamps for every task, providing a clear audit trail and easy troubleshooting.

- Additional logs may be available in `/tmp` for temporary files or SSH connections.

---

### Scenario 2: Parallel Migration of Multiple Services (Binance and Kucoin) from Azma to Cloudzy

#### Step 1: Environment Setup

```
# servers.conf excerpt:
azma|cr1azma|172.20.10.31|172.20.10.31|ubuntu|22
azma|cr2azma|172.20.10.32|172.20.10.32|ubuntu|22

cloudzy|cr4cloudzy|216.126.229.36|cr4cloudzy.stellaramc.ir|ubuntu|22
cloudzy|cr5cloudzy|172.86.94.38|cr5cloudzy.stellaramc.ir|ubuntu|22
```

#### Step 2: Start the Workflow

```bash
./main.sh
```

#### Step 3: Select Workflow Option

```
4: Run Complete Workflow Sequentially
```

#### Step 4: Input Collection (via input.sh prompts)

- **Services Selection:** binance, kucoin
- **Source Datacenter:** azma
- **Destination Datacenter:** cloudzy
- **Source VMs:** cr1azma, cr2azma
- **Destination VMs:** cr4cloudzy, cr5cloudzy
- **Max Parallel Jobs:** 2

#### Step 5: Review and Confirm Input

```text
SELECTED SERVICES: binance kucoin
SOURCE_DATACENTER: azma
Selected SOURCE VMs:
  - cr1azma
  - cr2azma
DEST_DATACENTER: cloudzy
Selected DEST VMs:
  - cr4cloudzy
  - cr5cloudzy
MAX_PARALLEL_JOBS: 2
```

#### Step 6: Workflow Execution

1. Synchronizes  files from main to both destination VMs in parallel.
2. Updates environment variables on cr4cloudzy and cr5cloudzy.
3. Deploys and starts both services on cr4cloudzy and cr5cloudzy.
4. Stops and purges both services from cr1azma and cr2azma.

#### Expected Outcome

```
[✓] Files synced to cr4cloudzy and cr5cloudzy
[✓] Environment updated on cr4cloudzy and cr5cloudzy
[✓] Binance & Kucoin deployed and started on cloudzy datacenter VMs
[✓] Binance & Kucoin stopped and purged from azma datacenter VMs
```

#### Logs and Timestamps

- A detailed log of the entire operation is saved in:

  ```
  $HOME/service_actions_<date>.log
  $HOME/sync_<date>.log
  ```

  (e.g., service\_actions\_20250311.log)

- Each log entry includes precise timestamps for every task, providing a clear audit trail and easy troubleshooting.

- Additional logs may be found in `/tmp` related to temporary SSH sessions and rsync transfers.

---

These examples illustrate how **Synchronize\_Switch** automates complex multi-datacenter service migrations using interactive or fully automated workflows.

---

## Known Issues

- SSH key-based authentication is required between the main machine and all target VMs.
- `servers.conf` must be kept accurate to prevent errors.
- SSH multiplex control files in `/tmp` may require manual cleanup after failures.

---

## Author

Fereidoon27\
GitHub: [https://github.com/fereidoon27](https://github.com/fereidoon27)

