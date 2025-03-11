# Example - input.sh

This document demonstrates example scenarios using `input.sh`, which is responsible for gathering user input interactively and saving it to `Collected_Input` for downstream processing by other scripts.

---

## **Scenario 1: Simple Input Collection for a Binance Service Migration**

### **Hypothetical `servers.conf` Configuration:**
```
arvan|cr1arvan|185.204.170.177|cr1arvan.stellaramc.ir|ubuntu|22
cloudzy|cr1cloudzy|172.86.68.12|cr1cloudzy.stellaramc.ir|ubuntu|22
```

### **User Input Sequence:**
1. **Select services:**
   - Input: `1`
   - Service selected: `binance`

2. **Select SOURCE datacenter:**
   - Input: `1`
   - Selected SOURCE datacenter: `arvan`

3. **Select DESTINATION datacenter:**
   - Input: `2`
   - Selected DESTINATION datacenter: `cloudzy`

4. **Select SOURCE VMs:**
   - VM list shows:
     - `1. cr1arvan`
   - Input: `1`
   - Selected SOURCE VM: `cr1arvan`

5. **Select DESTINATION VMs:**
   - VM list shows:
     - `1. cr1cloudzy`
   - Input: `1`
   - Selected DESTINATION VM: `cr1cloudzy`

6. **Enter MAX_PARALLEL_JOBS:**
   - Input: `1`

### **Expected `Collected_Input` Output:**
```
SELECTED SERVICES: binance
SOURCE_DATACENTER: arvan
Selected SOURCE VMs:
  - cr1arvan
DEST_DATACENTER: cloudzy
Selected DEST VMs:
  - cr1cloudzy
MAX_PARALLEL_JOBS: 1
```

---

## **Scenario 2: Complex Multi-Service, Multi-VM Selection with Conflict Validation**

### **Hypothetical `servers.conf` Configuration:**
```
azma|cr1azma|172.20.10.31|172.20.10.31|ubuntu|22
azma|cr2azma|172.20.10.32|172.20.10.32|ubuntu|22
azma|cr3azma|172.20.10.33|172.20.10.33|ubuntu|22
```

### **User Input Sequence:**
1. **Select services:**
   - Input: `13`
   - Services selected: `binance` and `kucoin`

2. **Select SOURCE datacenter:**
   - Input: `1`
   - Selected SOURCE datacenter: `azma`

3. **Select DESTINATION datacenter:**
   - Input: `1`
   - Selected DESTINATION datacenter: `azma` (same as source)

4. **Select SOURCE VMs:**
   - VM list shows:
     - `1. cr1azma`
     - `2. cr2azma`
     - `3. cr3azma`
   - Input: `1,2`
   - Selected SOURCE VMs: `cr1azma`, `cr2azma`

5. **Select DESTINATION VMs:**
   - VM list shows the same as source:
     - `1. cr1azma`
     - `2. cr2azma`
     - `3. cr3azma`
   - Input: `3,1`
   - Selected DESTINATION VMs: `cr3azma`, `cr1azma`

> ⚠️ The script **validates** that no SOURCE VM matches a DESTINATION VM.
- Conflict: `cr1azma` appears in both lists ➡️ **Rejected!**

### **User Corrects the Input:**
- Input: `3,2`
- Now DESTINATION VMs: `cr3azma`, `cr2azma`

⚠️ The script **detects** that `cr2azma` overlaps again ➡️ **Rejected!**

- Final input: `3`
- DESTINATION VM list: `cr3azma`

Now no overlap ➡️ **Accepted!**

6. **Enter MAX_PARALLEL_JOBS:**
   - Input: `2`

### **Expected `Collected_Input` Output:**
```
SELECTED SERVICES: binance kucoin
SOURCE_DATACENTER: azma
Selected SOURCE VMs:
  - cr1azma
DEST_DATACENTER: azma
Selected DEST VMs:
  - cr3azma
MAX_PARALLEL_JOBS: 2
```

---

## **Key Takeaways**

- `input.sh` enforces **validation** when the source and destination datacenter are the same to prevent overlapping VMs.
- Supports multi-service, multi-VM selections.
- Stores structured output in `Info/Collected_Input` for use by `main.sh` and `action.sh`.
- Interactive prompts ensure the user configures valid, logical migration setups.

---

## **Tips for Users**
- Use `all` to select all VMs in a datacenter.
- If an error occurs, carefully review the SOURCE and DESTINATION selections.
- Review `Collected_Input` after running `input.sh`:

```bash
cat Info/Collected_Input
```

