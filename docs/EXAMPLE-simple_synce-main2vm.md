# Example - simple_synce-main2vm.sh

This document provides example scenarios demonstrating how `simple_synce-main2vm.sh` works based on a **hypothetical configuration** from `servers.conf`. The script is responsible for synchronizing files from the **main machine** to selected destination VMs.

---

## **Scenario 1: Synchronizing to a Single VM**

### **Hypothetical `servers.conf` Configuration:**

```
arvan|cr1arvan|185.204.170.177|cr1arvan.stellaramc.ir|ubuntu|22
arvan|cr2arvan|185.204.171.190|cr2arvan.stellaramc.ir|ubuntu|22
```

### **Command Executed:**

```bash
./simple_synce-main2vm.sh --datacenter arvan --vms 1 --jobs 2 --yes
```

### **Expected Behavior:**
1. The script reads `servers.conf` and identifies **cr1arvan** as the target VM.
2. Establishes an SSH connection to `185.204.170.177` (`cr1arvan.stellaramc.ir`).
3. Synchronizes the predefined files and directories from the main machine to `/home/ubuntu/` on **cr1arvan**.
4. Logs the transfer results to `sync_YYYYMMDD.log`.
5. If successful, outputs:

   ```plaintext
   [✓] Synchronization completed for cr1arvan (185.204.170.177)
   ```

---

## **Scenario 2: Synchronizing to Multiple VMs in Parallel**

### **Hypothetical `servers.conf` Configuration:**

```
arvan|cr1arvan|185.204.170.177|cr1arvan.stellaramc.ir|ubuntu|22
arvan|cr2arvan|185.204.171.190|cr2arvan.stellaramc.ir|ubuntu|22
arvan|cr3arvan|185.204.170.246|cr3arvan.stellaramc.ir|ubuntu|22
```

### **Command Executed:**

```bash
./simple_synce-main2vm.sh --datacenter arvan --vms all --jobs 3 --yes
```

### **Expected Behavior:**
1. The script identifies **all VMs in the `arvan` datacenter**: `cr1arvan`, `cr2arvan`, `cr3arvan`.
2. Establishes SSH connections to each VM in parallel.
3. Begins synchronizing files to all selected VMs **simultaneously** (max 3 parallel jobs).
4. Each VM receives:
   - Necessary script files (`*.sh`)
   - Configuration directories (`van-buren-*`)
   - Secret files (`.secret/**`)
5. If the operation is successful, logs will show:

   ```plaintext
   [✓] Synchronization completed for cr1arvan (185.204.170.177)
   [✓] Synchronization completed for cr2arvan (185.204.171.190)
   [✓] Synchronization completed for cr3arvan (185.204.170.246)
   ```
6. If a VM is unreachable (e.g., SSH failure), it logs an error:

   ```plaintext
   [ERROR] Connection failed for cr2arvan (185.204.171.190). Skipping.
   ```

---

## **Key Takeaways**

- The script supports **single or multiple VMs** based on user input.
- Parallel jobs help speed up synchronization when dealing with multiple servers.
- Logs track progress and errors for troubleshooting.
- Automatic SSH connection handling ensures efficiency.

This example illustrates how `simple_synce-main2vm.sh` can be used for scalable, automated file synchronization across datacenters.

