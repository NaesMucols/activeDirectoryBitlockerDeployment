<#
.SYNOPSIS
    THE GOAL OF THIS SCRIPT IS TO RETRIEVE THE BDE KEYS AND BACKUP THE KEYS TO ACTIVE DIRECTORY
.DESCRIPTION
    THIS SCRIPT WILL BACKUP THE BITLOCKER DRIVE ECRYPTION KEYS AND THEIR ID'S TO ACTIVE DIRECTORY. IT WILL NOT RESET THE KEYS AND
    IT WILL RUN AUTOMATICALLY.
.PARAMETER SEARCHBASE
    DOESN'T HAVE TO BE SEARCH BASE. LIST DESCRIPTIONS FOR SPECIFIC COMMANDS
.INPUTS
    Localhost name, BDE protectors, Win32_OperatingSystem.Version,
.OUTPUTS
    COMPUTER BDE NUMERICAL KEY TO ACTIVE DIRECTORY
.EXAMPLE
    RECOVERY PASSWORD:
	293075-648945-564993-239230-359019-078053-691167-003182

        COMPUTER: <COMPUTERNAME>.<FQDN>
        DATE: YYYY-MM-DD HR:MM:SS -0600
        PASSWORD ID: 0018DE52-6F4E-4A73-AB2C-F1A0A7C67461

.NOTES
    AUTHOR: SEAN SLOCUM
    DATE:   05/17/2023

    WARNING:
        THIS SCRIPT ASSUMES AN ENVIRONMENT WHERE THE FOLLOWING GROUP POLICY SETTINGS ARE ENABLED:
         -SAVE BITLOCKER RECOVERY INFORMATION TO AD DS FOR OPERATING SYSTEM DRIVES
         -DO NOT ENABLE BITLOCKER UNTIL RECOVERY INFORMATION IS STORED TO AD DS FOR OPERATING SYSTEM DRIVES

    USING THIS SCRIPT WITHOUT THOSE SETTINGS ENABLED COULD POTENTIALLY LOCK USERS OUT OF THEIR DATA SINCE
    THE RECOVERY INFORMATION IS NOT AUTOMATICALLY STORED ELSEWHERE OR DISPLAYED TO THE USER.

    THIS SCRIPT WILL NOT STORE THE RECOVERY KEY ANYWHERE. READ ABOVE TO UNDERSTAND WHY.

    TO CAUSE THIS SCRIPT TO RUN AT LOGON, STORE IT IN A LOCATION READABLE BY THE AUTHENTICATED USERS OR DOMAIN COMPUTERS GROUP.
    THEN IN GROUP POLICY, CREATE A STARTUP SCRIPT (COMPUTER CONFIGURATION > POLICIES WINDOWS SETTINGS > SCRIPTS). SET THE SCRIPT
    NAME TO "POWERSHELL.EXE" AND THE SCRIPT PARAMETERS TO "-EXECUTIONPOLICY BYPASS -NONINTERACTIVE -COMMAND
    \\NETWORKPATH\SCRIPTNAME.PS1". I HAVE A NETWORK LOCATION IN \\<ITServer>\<hiddenShare$>\BATCHFILES\

    NOTE:
    BITLOCKER HAS SOME STRANGE ERROR REPORTING BEHAVIOR. FOR EXAMPLE, DURING TESTING, THE INITIAL SCRIPT (V1.20) ATTEMPT
    FAILED WITHOUT AN ERROR WRITTEN TO THE LOG FILE. BITLOCKER WILL REFUSE TO ENABLE IF IT DETECTED A CD/DVD INSERTED. AFTER THIS
    WAS RECTIFIED AND THE SYSTEM WAS RESTARTED, THE FIRST USER WHO LOGGED ON SAW A POPUP DIALOG ERRORMESSAGE SAYING THAT BITLOCKER
    COULD NOT RETRIEVE THE DECRYPTION KEY AND RECOMMENDING TO CHECK THE TPM -- BUT BITLOCKER THEN PROCEEDED TO ENABLE AFTER THAT
    MESSAGE WAS DISMISSED. IT APPEARS THAT AN ERROR ENCOUNTERED ON A GIVEN SCRIPT ATTEMPT DOES NOT TRIGGER A POPUP DIALOG ERROR
    UNTIL THE NEXT BOOT, AND EVEN THEN THE DIALOG ERROR MESSAGE MAY BE MISLEADING. I'VE ADDED THE $LASTEXITCODE SYSTEM VARIABLE TO
    TRY AND REMEDIATE THIS ISSUE AS WELL.

    IMPLEMENTATION:
    THIS SCRIPT IS MEANT TO BE DEPLOYED AS A SCHEDULED TASK VIA GROUP POLICY OBJECTS. PASS THESE ARGUMENTS INTO THE POWERSHELL.EXE
    PROGRAM INVOKATION. -NOPROFILE -NOLOGO -NONINTERACTIVE -EXECUTIONPOLICY BYPASS -FILE \\SERVER\FILE\LOCATION\ETC.PS1

    AS TESTED:


    SOURCES:
        HTTPS://SOCIAL.TECHNET.MICROSOFT.COM/FORUMS/LYNC/EN-US/656B5803-2F76-4957-AFD1-63C7759E86FB/BACKUPBITLOCKERKEYPROTECTOR-DOESNT-RETURN-ANY-ERROR-EVEN-IF-IT-FAILS?FORUM=MDOPMBAM
        https://www.youtube.com/watch?v=v7tIRK84D8U


    CHANGELOG:
        V1.00   05/14/23    SCS - DRAFT - INITIAL DRAFT
        V1.10   05/17/23    SCS - DRAFT - RECREATED DOCUMENT, BEGIN DEBUGGING
        V1.20   05/17/23    SCS - WIP   - DEVELOPING COMPLETE AND TESTED. (JK IT DIDN'T ACTUALLY
                                          WORK AS I THOUGHT IT DID. Psudo Success?) SEE NOTES
                                          ABOVE.
        V1.21   05/17/23    SCS - WIP   - PREVIOUS VERSION WAS FAILING WITHOUT AN ERROR CODE. NEW
                                          VERSION IS A NEW ITERATION. ADDED NOTES AND WARNINGS.
                                          REDESIGNED CODE TO CHECK AND MAKE SURE THAT THE OS IS AT
                                          LEAST WINDOWS 8 OR SERVER 2012 AND NEWER.
        V1.22   05/22/23    SCS - WIP   - I CLEANED UP THE CODE A BIT. MADE GENERIC VERSION.

#>

# CONFIRM THE TARGET IS RUNNING WINDOWS 8 / SERVER 2012 OR NEWER THEN BEGIN THE NEXT STEP IF THE STATEMENT IS TRUE
if ([version](Get-CimInstance -ClassName Win32_OperatingSystem).Version -ge [version]6.2) {
    $BitLockerC = Get-BitLockerVolume -MountPoint $env:SystemDrive
    # IF THE VOLUME IS DECRYPTED THEN IT WILL TRY TO ENCRYPT THE DRIVE.
    if ($BitLockerC.VolumeStatus -eq "FullyDecrypted") {
        try {
            #REMOVE ANY PROTECTORS THAT MAY HAVE BEEN CREATED FROM PREVIOUS ATTEMPTS THAT DID NOT COMPLETE
            $Protectors = $BitLockerC.KeyProtector.KeyProtectorID
            if ($Protectors) {
                $Protectors | ForEach-Object {Remove-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $_}
            }
            Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector -ErrorAction Stop
            Enable-BitLocker -MountPoint $env:SystemDrive -TpmProtector -EncryptionMethod XtsAes256 -UsedSpaceOnly -ErrorAction Stop
        } catch {
            Write-Output "BitLocker encryption could not be enabled, see error below. `nLast Exit Code: $lastExitCode" $_ | Out-File S:\Projects\Monitoring and Security\BitLocker\BitLockerError.txt
        }
    # IF THE VOLUME IS ALREADY ENCRYPTED THEN IT WILL TRY TO BACKUP THE BDE KEYS TO AD
    } else {
        try {
            # The code below will initiate the backup part of the script
            $BitVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive
            $RecoveryKey = $BitVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
            # backups the key to Local Active Directory. Will fail if AD environment is only azure Cloud-Based AD.
            Backup-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $RecoveryKey.KeyProtectorID
            # The code below backups the key to Azure Active Directory. Will fail if AD isn't hybrid mode or Local.
            ## BackupToAAD-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $RecoveryKey.KeyProtectorID
        } catch {
            Write-Output "BitLocker encryption key could not be backed up, see error below. `nLast Exit Code: $lastExitCode" $_ | Out-File 'S:\Projects\Monitoring and Security\BitLocker\BitLockerError.txt'
        }
    }
}
else {
    Write-Error -MESSAGE "Windows is not running a compatible version. Please install Microsoft Server 2012 or Microsoft Windows 8 and try again."
}
