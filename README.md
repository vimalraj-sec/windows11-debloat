# Windows 11 Debloat + Privacy Focused Script

- A lightweight PowerShell script to debloat Windows 11 25H2 by removing unnecessary apps and disabling telemetry. 
- Best used after a fresh Windows 11 25H2 installation for a cleaner, streamlined system.

✔ Removes built-in apps (installed + provisioned)  
✔ Disables telemetry services & scheduled tasks  
✔ Disables Copilot & Widgets via policy  
✔ Removes OneDrive & Teams  
✔ Safe for personal Windows 11 systems  

## Download ZIP
1️⃣ Open: [https://github.com/vimalraj-sec/windows11-debloat](https://github.com/vimalraj-sec/windows11-debloat.git)

2️⃣ Click **Code → Download ZIP**

3️⃣ Extract the folder

## How To Run
1️⃣ Open **PowerShell as Administrator**
2️⃣ Go to the script folder:

```powershell
cd path\to\windows11-debloat
```

3️⃣ Run safely without changing system policy:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows11-debloat.ps1
```

✔ No permanent execution policy changes  
✔ Only applies to this run
## After Completion

Restart your PC:

```powershell
Restart-Computer
```
