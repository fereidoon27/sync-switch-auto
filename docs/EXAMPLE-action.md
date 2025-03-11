# Example - action.sh

This document provides example scenarios demonstrating how `action.sh` operates based on **hypothetical configurations** and **user inputs**. The script automates the process of migrating services between datacenters and virtual machines (VMs), ensuring zero-downtime deployment with robust parallelism and SSH multiplexing.

---

## **Scenario 1: Migrate `binance` Services from `arvan` to `cloudzy` Datacenters (One-to-One Mapping)**

### **Hypothetical `servers.conf` Configuration:**
```
arvan|cr3arvan|185.204.170.246|cr3arvan.stellaramc.ir|ubuntu|22
cloudzy|cr1cloudzy|172.86.68.12|cr1cloudzy.stellaramc.ir|ubuntu|22
```

### **Command Executed:**
```bash
./action.sh -s arvan -d cloudzy -v 3 -D 1 -r binance -p 1 -y
```

### **What Happens:**
1. The script validates both datacenters (`arvan` and `cloudzy`).
2. Maps source VM `cr3arvan` to destination VM `cr1cloudzy`.
3. Initiates SSH connections to both VMs using multiplexing.
4. Copies all deployment scripts for `binance` to both source and destination VMs.
5. Executes the following on **cr1cloudzy** (destination VM):
   - **Deploy** the `binance` service.
   - **Start** the `binance` service.
6. Pauses briefly (5 seconds).
7. Executes the following on **cr3arvan** (source VM):
   - **Stop** the `binance` service.
   - **Purge** the `binance` service.
8. Logs show:
```
[✓] SSH connection established to cr3arvan and cr1cloudzy.
[✓] Scripts copied successfully to both VMs.
[✓] Deployed and started binance on cr1cloudzy.
[✓] Stopped and purged binance on cr3arvan.
[✓] Job #1 completed successfully.
```

### **Result:**
- `binance` service is migrated from `cr3arvan` to `cr1cloudzy`.
- Minimal downtime due to sequential execution.

---

## **Scenario 2: Parallel Migration of Multiple Services (`kucoin`, `gateio`) with Many-to-Many Mapping**

### **Hypothetical `servers.conf` Configuration:**
```
arvan|cr2arvan|185.204.171.190|cr2arvan.stellaramc.ir|ubuntu|22
arvan|cr5arvan|185.204.169.190|cr5arvan.stellaramc.ir|ubuntu|22
cloudzy|cr4cloudzy|216.126.229.36|cr4cloudzy.stellaramc.ir|ubuntu|22
cloudzy|cr5cloudzy|172.86.94.38|cr5cloudzy.stellaramc.ir|ubuntu|22
```

### **Command Executed:**
```bash
./action.sh -s arvan -d cloudzy -v 2,5 -D 4,5 -r kucoin,gateio -p 2 -y
```

### **What Happens:**
1. **Datacenter validation** confirms both `arvan` and `cloudzy` exist.
2. **VM Mappings:**
   - Source VM `cr2arvan` ➡️ Destination VM `cr4cloudzy`
   - Source VM `cr5arvan` ➡️ Destination VM `cr5cloudzy`
3. For each **service** (`kucoin` and `gateio`), the script:
   - **Deploys and starts** on destination VMs.
   - **Stops and purges** on source VMs.
4. The script runs **two jobs in parallel** (`-p 2`):
   - **Job #1**: Migrates both services from `cr2arvan` ➡️ `cr4cloudzy`
   - **Job #2**: Migrates both services from `cr5arvan` ➡️ `cr5cloudzy`
5. SSH multiplexing optimizes the connection handling.
6. Logs show parallel progress:
```
──▶ [Action SSH Connection] | VM cr2arvan             | STATUS: Started | Job 1
──▶ [Action SSH Connection] | VM cr4cloudzy          | STATUS: Started | Job 1
✅  [Action Copy Scripts]    | VM cr4cloudzy          | STATUS: Completed | Job 1
✅  [Action Deploy kucoin]   | VM cr4cloudzy          | STATUS: Completed | Job 1
✅  [Action Start kucoin]    | VM cr4cloudzy          | STATUS: Completed | Job 1
✅  [Action Stop kucoin]     | VM cr2arvan            | STATUS: Completed | Job 1
✅  [Action Purge kucoin]    | VM cr2arvan            | STATUS: Completed | Job 1
```
7. Same for `cr5arvan` and `cr5cloudzy`.

### **Result:**
- `kucoin` and `gateio` are migrated from `arvan` datacenter VMs to `cloudzy` datacenter VMs.
- Operations are handled concurrently, significantly reducing total migration time.

---

## **Key Takeaways**

- Supports both **one-to-one** and **many-to-many** VM mappings.
- Parallel job control (`-p`) improves efficiency with multiple migrations.
- SSH multiplexing ensures fast, persistent connections.
- Modular script execution per service guarantees precise control (deploy/start/stop/purge).
- Detailed logs provide visibility into the entire migration lifecycle.

---

## **Common Logs Example**
```
[2025-03-11 10:15:32] ──▶ [Action SSH Connection] | VM cr2arvan        | STATUS: Started | Job 1
[2025-03-11 10:15:34] ✅  [Action Deploy kucoin]  | VM cr4cloudzy      | STATUS: Completed | Job 1
[2025-03-11 10:15:45] ✅  [Action Stop kucoin]    | VM cr2arvan        | STATUS: Completed | Job 1
[2025-03-11 10:15:47] ✅  [Action Purge kucoin]   | VM cr2arvan        | STATUS: Completed | Job 1
```

---

## **Next Steps for Users**

- Ensure `servers.conf` accurately reflects your infrastructure.
- SSH key authentication must be set up between the main machine and VMs.
- Run `input.sh` and `main.sh` for an interactive experience integrating `action.sh`.

This example demonstrates how `action.sh` manages complex service migrations in scalable and efficient ways across multi-datacenter environments.

