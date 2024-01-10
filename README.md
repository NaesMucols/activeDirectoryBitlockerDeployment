# Bitlocker Drive Encription deployment for Active Directory environments.

This repository will have some supporting documents to deploy Bitlocker Drive Encryption to an AD Environment. 

---------------------------------------------------------------------------------------------------
 
## BDE Policies and Scripts

Author:   Sean C. Slocum, II <br/>
Created:  01-08-2024 <br/>
Modified: 01-09-2024 <br/>
Synopsis: I created this document to make My job easier <br/>
Description: This document should outline the different files in this directory and their 
             purposes. This document will also mention the sources that I used during this 
             project. 
### Table of contents
1. Sources and people who helped me.
2. List of files and their purpose.
3. GPO's (There are two GPO's, unless you want to consolidate. I didn't)
4. Designed use. 


## Water Hazards

- I do NOT take responsibility for anything that happens, good or bad, to your network because of 
  these scripts. READ them with your own eyes, every line of code. I haven't been writing 
  powershell for 10 years or even 10 months. Update and change these scripts how you see fit. 

- You CAN lock out every computer on your network if you're not careful. I tested that "feature" 
  with a few VMs in a test OU. 

- Ignorance and disregard for testing can end in catastrophic failure. 
   - I created a test OU and put windows 10 and 11 VMs in that OU. It worked for me and helped me 
     see how Bitlocker Drive Encription works.

- Make sure you read the scripts and input your local network information before running or scheduling them.

- The likelyhood of me being able to help you diagnose any problems are slim. 
   - See: "It works on my machine".


---------------------------------------------------------------------------------------------------


## 1. Sources and people who helped me

Sean Jr. on Youtube (No Relation, I promise.)
 - Sean's video directed me largely through this process. 
 - I didn't follow the instructions to a T, but I followed it pretty closely.
 - https://www.youtube.com/watch?v=v7tIRK84D8U&t=1s

Martin Pugh on Spiceworks
 - I used a LOT of this script in creating my own. You'll see the similarities when you read
   through all the scripts.
 - https://community.spiceworks.com/topic/1083065-bitlocker-status-on-all-computers

Fabozzi.net 
 - I don't know how to give credit here. 
 - Misc Reading to get a better understanding. 
 - https://fabozzi.net/powershell-find-computers-in-ad-with-stored-bitlocker-keys/


---------------------------------------------------------------------------------------------------


## 2. List of files and their purpose

EnablingBitLocker.bat
 - Provided by Sean Jr. 
 - This will enable BDE. 
 - Designed to be scheduled and stored in a hidden share.
 - I haven't modified this file.

GENERIC_BDE_AD_Backup_v1.22.ps1
 - Made by me.
 - This script will be what actually backs up the GPO to AD
 - Designed to be scheduled and stored in a hidden share.

GENERIC_Bitlocker_Report_v1.54.ps1
 - Made by me. 
 - This will just return a CSV with Computer name IPv4 Address, Online status, TPM Version, if BDE 
   is enabled, and other miscellaneous info.
 - Runs slow as shit rolling uphill. But it works and doesn't disrupt the network to the best of 
   my knowledge. 

spiceWorksExample.ps1
 - Made by Martin Pugh
 - The purpose of this is to show important PS Scripts that I learned from..
 - I haven't modified this file.


---------------------------------------------------------------------------------------------------


## 3. GPO's (There are two GPO's, unless you want to consolidate. I didn't)

### GPO 1 - BDE Key Backup 
 *User Configuration Disabled*

Description: This GPO will create a scheduled task that will check monthly for new BDE Keys. 
             (Think: you have Bitlocker ToGo enabled)

Setting Location: Computer Configuration > Preferences > Control Panel Settings > Scheduled Tasks
                   > *right click* New Scheduled Task for At least windows 7
Options:
 - Task
    - Name: BDE_AD_Backup_v1.22
    - Description: <use whatever you'd like>
    - Security Options
       - Account: "NT AUTHORITY\System"
       - check "run whether the user is logged on or not
       - check "Run with highest Privileges
    - Configure for Windows Vista or Server 2008
 - Triggers
    - At Log On
       - of any user
       - Delay: 1 minute
    - On a schedule
       - Monthly: can be any day. I chose first monday of every month.
    - On idle
 - Actions
    - Start a Program
       - Program: powershell.exe
       - Add Arguments: -EXECUTIONPOLICY BYPASS -NONINTERACTIVE -FILE \\<server>\<hiddenShare$>\GENERIC_BDE_AD_Backup_v1.22.ps1
 - Settings (Full disclosure, I mostly left these as their default values)
    - Stop if the computer ceases to be idle:  No   
    - Restart if the idle state resumes:  No   
    - Start the task only if the computer is on AC power:  No   
    - Stop if the computer switches to battery power:  No   
    - Allow task to be run on demand:  Yes   
    - Stop task if it runs longer than:  Immediately   
    - If the running task does not end when requested, force it to stop:  No   
    - If the task is already running, then the following rule applies:  IgnoreNew 


### GPO 2 - Part 1 - BDE Policy and Script
   *User Configuration Disabled*

Description: There's a couple parts to this GPO. There are 3 configuration templates and a
             scheduled task that will enable Bitlocker Drive Encryption. I'll divide them up for 
             simplicity 

Setting Location - Configuration Template: Computer Configuration > Policies > Administrative Templates
Options: 
 - Windows Components/BitLocker Drive Encryption
    - Choose drive encryption method and cipher strength (Windows 10 [Version 1511] and later)
       - Enabled
          - Select the encryption method for operating system drives: XTS-AES 256-bit 
          - Select the encryption method for fixed data drives: XTS-AES 256-bit 
          - Select the encryption method for removable data drives: XTS-AES 256-bit 
    - Choose drive encryption method and cipher strength (Windows 8, Windows Server 2012, Windows 8.1, Windows Server 2012 R2, Windows 10 [Version 1507])
       - Enabled
          - Select the encryption method: AES 256-bit 
    - Store BitLocker recovery information in Active Directory Domain Services (Windows Server 
      2008 and Windows Vista)
       - Enabled
          - Require BitLocker backup to AD DS: Enabled 
          - Select BitLocker recovery information to store: Recovery passwords and key packages 
 - Windows Components/BitLocker Drive Encryption/Fixed Data Drives
    - Choose how BitLocker-protected fixed drives can be recovered
       - Enabled
          - Allow data recovery agent: Enabled 
          - Configure user storage of BitLocker recovery information:
             - Allow 48-digit recovery password
             - Allow 256-bit recovery key
          - Omit recovery options from the BitLocker setup wizard: Disabled 
          - Save BitLocker recovery information to AD DS for fixed data drives: Enabled 
          - Configure storage of BitLocker recovery information to AD DS: Backup recovery passwords and key packages 
          - Do not enable BitLocker until recovery information is stored to AD DS for fixed data drives Enabled 
    - Enforce drive encryption type on fixed data drives Enabled 
       - Select the encryption type: Used Space Only encryption
 - Windows Components/BitLocker Drive Encryption/Operating System Drives
    - Allow network unlock at startup: Enabled 
    - Choose how BitLocker-protected operating system drives can be recovered
       - Enabled
          - Allow data recovery agent: Enabled 
          - Configure user storage of BitLocker recovery information:
             - Allow 48-digit recovery password
             - Allow 256-bit recovery key
          - Omit recovery options from the BitLocker setup wizard: Disabled 
          - Save BitLocker recovery information to AD DS for fixed data drives: Enabled 
          - Configure storage of BitLocker recovery information to AD DS: Store recovery passwords and key packages 
          - Do not enable BitLocker until recovery information is stored to AD DS for fixed data drives Enabled 
    - Enforce drive encryption type on fixed data drives Enabled 
       - Select the encryption type: Used Space Only encryption


 ### GPO 2 - Part 2 - BDE Policy and Script

Setting Location - Scheduled task: Computer Configuration > Preferences > Control Panel Settings
                                  > Scheduled Tasks > 
Options:
 - Task
    - Name: BDE | Enable Script
    - Description: <use whatever you'd like>
    - Security Options
       - Account: "NT AUTHORITY\System"
       - check "run whether the user is logged on or not
       - check "Run with highest Privileges
    - Configure for Windows Vista or Server 2008
 - Triggers
    - At Log On
       - of any user
       - Delay: 1 minute
    - On idle
 - Actions
    - Start a Program
       - Program: powershell.exe
       - Add Arguments: -EXECUTIONPOLICY BYPASS -NONINTERACTIVE -FILE \\<server>\<hiddenShare$>\EnablingBitLocker.bat
 - Settings (Full disclosure, I mostly left these as their default values)
    - Stop if the computer ceases to be idle:  No   
    - Restart if the idle state resumes:  No   
    - Start the task only if the computer is on AC power:  No
    - Stop if the computer switches to battery power:  Yes   
    - Allow task to be run on demand:  Yes   
    - Stop task if it runs longer than:  3 days   
    - If the running task does not end when requested, force it to stop:  No   
    - If the task is already running, then the following rule applies:  IgnoreNew

## 4. Designed use 

These documents are meant to be used as guidance. Do NOT copy and paste anything unless you've 
verified that it's compatible with your network and systems. I've only tested these policies 
against Windows 10 and 11 machines. This document is NOT a substitute to research and 
developement. Use with caution. You CAN lock out every computer on your network if it's not 
configured properly. I tested it, it's possible. I promise. Use the scripts ONLY after you've 
verified that they won't harm your network. 
