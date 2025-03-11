# Example - edit_edn_base_on_ip.sh

This document provides example scenarios demonstrating how `edit_edn_base_on_ip.sh` works based on **hypothetical inputs** from `servers.conf`. This script updates environment variables and proxy settings in system configuration files depending on the VM's network type (internal or external).

---

## **Scenario 1: Update Proxy Settings for Internal Network Servers**

### **Hypothetical `servers.conf` Configuration:**

```
azma|cr1azma|172.20.10.31|172.20.10.31|ubuntu|22
azma|cr2azma|172.20.10.32|172.20.10.32|ubuntu|22
```

### **Command Executed:**

```bash
./edit_edn_base_on_ip.sh --datacenter azma --servers 1,2
```

### **Expected Behavior:**
1. The script selects VMs `cr1azma` and `cr2azma` from the `azma` datacenter.
2. It connects to both VMs and runs the **network detection** script.
3. Each VM reports an IP address matching `172.20.*`, indicating an **internal network**.
4. The script:
   - Copies the internal environment file (`envs`) to each VM.
   - Updates `system*.edn` files to enable proxy settings:
     - `:use-proxy? true`
     - `Set-Proxy? true`
   - Ensures the environment file is sourced in both `.bashrc` and `.profile`.
5. Logs the following actions:

   ```plaintext
   ✓ Completed: cr1azma
   ✓ Completed: cr2azma
   ```

---

## **Scenario 2: Update Proxy Settings for External Network Servers**

### **Hypothetical `servers.conf` Configuration:**

```
cloudzy|cr1cloudzy|216.126.229.35|cr1cloudzy.stellaramc.ir|ubuntu|22
cloudzy|cr2cloudzy|172.86.94.38|cr2cloudzy.stellaramc.ir|ubuntu|22
```

### **Command Executed:**

```bash
./edit_edn_base_on_ip.sh --datacenter cloudzy --servers 1,2
```

### **Expected Behavior:**
1. The script selects VMs `cr1cloudzy` and `cr2cloudzy` from the `cloudzy` datacenter.
2. It connects to both VMs and runs the **network detection** script.
3. Each VM reports an external IP address (not `172.20.*`).
4. The script:
   - Copies the external environment file (`newpin/envs`) to each VM.
   - Updates `system*.edn` files to disable proxy settings:
     - `:use-proxy? false`
     - `Set-Proxy? false`
   - Ensures the environment file is sourced in both `.bashrc` and `.profile`.
5. Logs the following actions:

   ```plaintext
   ✓ Completed: cr1cloudzy
   ✓ Completed: cr2cloudzy
   ```

---

## **Key Takeaways**

- Automatically detects network type based on the VM's IP.
- Switches between internal and external proxy configurations.
- Works in parallel for multiple VMs with a maximum concurrency limit.
- Generates logs for each VM in `/tmp` or a temporary directory for review.

This example demonstrates how `edit_edn_base_on_ip.sh` can dynamically manage environment settings based on the network context of your infrastructure.

