# Main.sh - Orchestrator Script for Complete Workflow

## Description

**Main.sh** is the central orchestrator script that ties together all the individual components of the **Synchronize_Switch** project. It provides a unified menu-driven interface to run the core functionalities of the system, including file synchronization, environment updates, and service switching.

With `main.sh`, users can execute a **complete workflow sequentially**, ensuring a smooth transition from synchronization to environment configuration and finally service migration between datacenters and virtual machines (VMs).

---

## Installation Instructions

1. **Clone the repository:**

   ```bash
   git clone https://github.com/fereidoon27/Synchronize_Switch.git
   cd Synchronize_Switch
   ```

2. **Ensure script permissions:**

   ```bash
   chmod +x main.sh
   ```

3. **Dependencies:**
   - Requires `bash`.
   - Other dependent scripts must be executable:
     - `simple_synce-main2vm.sh`
     - `edit_edn_base_on_ip.sh`
     - `action.sh`
     - `input.sh`

4. **Prepare configuration files:**
   - Ensure `Info/servers.conf` is updated.
   - Make sure any environment files and service deployment scripts are in place.

---

## Usage

### Run the main orchestrator script:

```bash
./main.sh
```

### Menu Options:

```
1: Synchronize
   - Sync a folder from the Main VM to destination VMs.

2: Update Environment & Edit EDN
   - Copy the appropriate environment file and modify proxy settings in configuration files.

3: Switch Services
   - Execute deploy, start, stop, and purge actions for selected services across VMs.

4: Run Complete Workflow Sequentially
   - Collect user input and run synchronization, environment updates, and service migrations in sequence.

0: Exit - Terminate the main script.
```

---

## Code Structure

```
Synchronize_Switch/
├── main.sh                    # This script
├── input.sh                   # Interactive input collection
├── simple_synce-main2vm.sh    # Sync files to VMs
├── edit_edn_base_on_ip.sh     # Update environment and config files
├── action.sh                  # Service migration and control
├── Info/
│   ├── servers.conf           # VM and datacenter config file
│   └── Collected_Input        # Saved user input
└── deployment_scripts/        # Deployment action scripts (deploy, start, stop, purge)
```

---

## How It Works

1. **Menu-Driven Interface**:
   - Guides the user through actions using numbered menu options.

2. **Complete Workflow (Option 4)**:
   - Runs `input.sh` to collect user input (or uses existing `Collected_Input` if confirmed).
   - Parses selections from `Collected_Input`.
   - Executes the following in sequence:
     - `simple_synce-main2vm.sh` for file synchronization.
     - `edit_edn_base_on_ip.sh` for environment and EDN updates.
     - `action.sh` for service switch (deploy/start/stop/purge).

3. **Interactive & Automated**:
   - Supports both manual confirmation and non-interactive runs.

---

## Example Complete Workflow

1. Select option **4: Run Complete Workflow Sequentially**.
2. Collect and confirm your inputs via `input.sh`.
3. The script will automatically:
   - Synchronize files.
   - Update environment variables.
   - Switch services between source and destination datacenters.

---

## Testing Instructions

1. **Dry-run through menu options 1-3 individually before running option 4.**
2. **Verify logs and outcomes after each step:**
   - `sync_YYYYMMDD.log`
   - `service_actions_YYYYMMDD.log`

---

## Known Issues

- SSH keys must be properly configured for seamless connections.
- Any misconfiguration in `servers.conf` can cause incomplete operations.
- Manual cleanup may be needed for SSH multiplex control paths in `/tmp`.

---

## Roadmap

- Add support for CLI arguments to trigger specific flows without menu interaction.
- Enhance error reporting and recovery across sequential workflows.
- Potential integration with a web UI for non-technical users.

---

## License

This project is licensed under the MIT License.

---

## Author

Fereidoon27  
GitHub: [https://github.com/fereidoon27](https://github.com/fereidoon27)

