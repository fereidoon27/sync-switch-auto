# Input.sh - Interactive Input Collection Script

## Description

**Input.sh** is an interactive Bash script designed to collect user input for configuring service migrations and synchronizations between datacenters and virtual machines (VMs). It offers an intuitive, color-coded menu system that guides users through selecting services, source/destination datacenters, VMs, and parallel job settings.

Once selections are made, the script saves the collected input to a structured plain text file (`Collected_Input`) located in the `Info` directory. This input is then used by other scripts, such as `main.sh` and `action.sh`, to automate service management tasks.

---

## Installation Instructions

1. **Clone the repository:**

   ```bash
   git clone https://github.com/fereidoon27/Synchronize_Switch.git
   cd Synchronize_Switch
   ```

2. **Ensure script permissions:**

   ```bash
   chmod +x input.sh
   ```

3. **Prepare configuration files:**
   - Ensure `Info/servers.conf` contains the correct datacenter and VM configurations.

4. **Dependencies:**
   - Requires `bash` (recommended Bash version 4+).

---

## Usage

### Run the script interactively:

```bash
./input.sh
```

### What it does:
- Prompts the user through 6 steps:
  1. Select **Service(s)** to migrate (`binance`, `kucoin`, `gateio`, or all).
  2. Choose the **Source Datacenter**.
  3. Choose the **Destination Datacenter**.
  4. Select **Source VM(s)**.
  5. Select **Destination VM(s)** (validates no overlap if the datacenter is the same).
  6. Define the **Maximum Number of Parallel Jobs**.

- Displays a summary of collected inputs.
- Saves all selections to a plain text file at:

```plaintext
Info/Collected_Input
```

---

## Example Output File (`Info/Collected_Input`):

```
SELECTED SERVICES: binance kucoin
SOURCE_DATACENTER: arvan
Selected SOURCE VMs:
  - cr1arvan
  - cr2arvan
DEST_DATACENTER: cloudzy
Selected DEST VMs:
  - cr1cloudzy
  - cr2cloudzy
MAX_PARALLEL_JOBS: 4
```

---

## Code Structure

```
Synchronize_Switch/
├── input.sh                # This script
├── Info/
│   ├── servers.conf        # VM and datacenter configuration file
│   └── Collected_Input     # Generated file with user selections
```

- `input.sh`: Collects user input and writes to `Collected_Input`.
- `Info/servers.conf`: Provides VM and datacenter details used for input validation.
- `Collected_Input`: Consumed by `main.sh` and `action.sh` for automated operations.

---

## How It Works

1. **Datacenter & VM Selection**:
   - Reads from `servers.conf` to list available datacenters and their VMs.
2. **Validation**:
   - Prevents the user from selecting the same VM for both source and destination if the datacenters are identical.
3. **Color-coded Prompts**:
   - Uses colored output for clarity and ease of use.
4. **Plain Text Export**:
   - Saves selections to `Info/Collected_Input` for use in automation workflows.

---

## Testing Instructions

1. **Run interactively to collect data:**

   ```bash
   ./input.sh
   ```

2. **Verify Collected_Input:**

   ```bash
   cat Info/Collected_Input
   ```

3. **Feed into `main.sh` or `action.sh` for a complete workflow.**

---

## Known Issues

- User must ensure SSH keys are pre-configured between the main machine and VMs (needed later by `action.sh`).
- `servers.conf` must be kept up-to-date; otherwise, selections may be invalid or incomplete.

---

## Author

Fereidoon27  
GitHub: [https://github.com/fereidoon27](https://github.com/fereidoon27)

