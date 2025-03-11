# Example Scenarios - Synchronize_Switch Master Workflow

This document demonstrates comprehensive example scenarios of running the **full Synchronize_Switch workflow** as defined in the master `README.md`. These examples highlight practical applications, covering synchronization, environment updates, and service migrations across datacenters and virtual machines (VMs).

---

## **Scenario 1: Full Workflow for Binance Service Migration from Arvan to Cloudzy**

### **Hypothetical `servers.conf` Configuration:**
```
arvan|cr3arvan|185.204.170.246|cr3arvan.stellaramc.ir|ubuntu|22
cloudzy|cr4cloudzy|216.126.229.36|cr4cloudzy.stellaramc.ir|ubuntu|22
```

### **Step 1: Run the Master Script**
```bash
./main.sh
```

### **Step 2: Select Option 4 - Complete Workflow Sequentially**
```
4: Run Complete Workflow Sequentially
```

### **Step 3: Follow Prompts in `input.sh`**
1. **Select Service(s):**
   - Input: `1`
   - Selected: `binance`

2. **Select SOURCE Datacenter:**
   - Input: `1` ➡️ `arvan`

3. **Select DESTINATION Datacenter:**
   - Input: `2` ➡️ `cloudzy`

4. **Select SOURCE VMs:**
   - Input: `1` ➡️ `cr3arvan`

5. **Select DESTINATION VMs:**
   - Input: `1` ➡️ `cr4cloudzy`

6. **Max Parallel Jobs:**
   - Input: `1`

### **Step 4: Confirm Collected Input**
```
SELECTED SERVICES: binance
SOURCE_DATACENTER: arvan
Selected SOURCE VMs:
  - cr3arvan
DEST_DATACENTER: cloudzy
Selected DEST VMs:
  - cr4cloudzy
MAX_PARALLEL_JOBS: 1
```
- Confirm: `y`

### **Step 5: Automatic Workflow Execution**
1. **File Synchronization (simple_synce-main2vm.sh):**
   - Syncs files from the main machine to `cr4cloudzy`.
2. **Environment Update (edit_edn_base_on_ip.sh):**
   - Detects external IP ➡️ disables proxy.
   - Copies environment files and modifies `system.edn`.
3. **Service Switch (action.sh):**
   - Deploys and starts `binance` on `cr4cloudzy`.
   - Stops and purges `binance` on `cr3arvan`.

### **Expected Outcome:**
```
[✓] Synchronization to cr4cloudzy completed
[✓] Proxy settings updated for cr4cloudzy (external network)
[✓] Deployed and started binance on cr4cloudzy
[✓] Stopped and purged binance on cr3arvan
```

---

## **Scenario 2: Parallel Migration of Multiple Services from Azma to Cloudzy**

### **Hypothetical `servers.conf` Configuration:**
```
azma|cr1azma|172.20.10.31|172.20.10.31|ubuntu|22
azma|cr2azma|172.20.10.32|172.20.10.32|ubuntu|22
cloudzy|cr4cloudzy|216.126.229.36|cr4cloudzy.stellaramc.ir|ubuntu|22
cloudzy|cr5cloudzy|172.86.94.38|cr5cloudzy.stellaramc.ir|ubuntu|22
```

### **Step 1: Run the Master Script**
```bash
./main.sh
```

### **Step 2: Select Option 4 - Complete Workflow Sequentially**
```
4: Run Complete Workflow Sequentially
```

### **Step 3: Follow Prompts in `input.sh`**
1. **Select Service(s):**
   - Input: `12`
   - Selected: `binance` and `kucoin`

2. **Select SOURCE Datacenter:**
   - Input: `1` ➡️ `azma`

3. **Select DESTINATION Datacenter:**
   - Input: `2` ➡️ `cloudzy`

4. **Select SOURCE VMs:**
   - Input: `12` ➡️ `cr1azma` and `cr2azma`

5. **Select DESTINATION VMs:**
   - Input: `12` ➡️ `cr4cloudzy` and `cr5cloudzy`

6. **Max Parallel Jobs:**
   - Input: `2`

### **Step 4: Confirm Collected Input**
```
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
- Confirm: `y`

### **Step 5: Automatic Workflow Execution**
1. **File Synchronization (simple_synce-main2vm.sh):**
   - Syncs files to `cr4cloudzy` and `cr5cloudzy` in parallel.
2. **Environment Update (edit_edn_base_on_ip.sh):**
   - Detects external IP ➡️ disables proxy on both destination VMs.
3. **Service Switch (action.sh):**
   - Parallel Jobs:
     - Job #1: Migrates `binance` and `kucoin` from `cr1azma` ➡️ `cr4cloudzy`.
     - Job #2: Migrates `binance` and `kucoin` from `cr2azma` ➡️ `cr5cloudzy`.

### **Expected Outcome:**
```
[✓] Synchronization completed for cr4cloudzy and cr5cloudzy
[✓] Proxy disabled on both destination VMs
[✓] binance + kucoin deployed and started on cloudzy datacenter VMs
[✓] binance + kucoin stopped and purged from azma datacenter VMs
```

---

## **Key Takeaways**
- `main.sh` automates the entire migration lifecycle: **Input → Sync → Environment Update → Service Migration**.
- Supports **single service**, **multi-service**, **one-to-one**, and **many-to-many** VM mappings.
- Parallel processing significantly speeds up complex migrations.
- Easy-to-use prompts guide the user to create valid, logical workflows.

---

## **Common Pitfalls and Solutions**
| **Issue**                                          | **Solution**                                                       |
|----------------------------------------------------|--------------------------------------------------------------------|
| Source and destination VMs overlap in same DC      | Ensure distinct VM selections when both DCs are identical.        |
| SSH connection failures                            | Verify SSH key setup and ensure `servers.conf` IPs are correct.    |
| Proxy misconfiguration after `edit_edn_base_on_ip` | Check network detection script and validate environment files.     |

---

## **Tips for Best Practice**
- Run the `main.sh` regularly to ensure consistency across datacenters.
- Keep `servers.conf` updated to reflect your infrastructure.
- Review `Collected_Input` to confirm selections before executing workflows.

---

This example document illustrates complete use cases for the `Synchronize_Switch` repository, showcasing its capabilities for automated, reliable, and efficient service migrations across multiple datacenters.

