@echo off

set test /a = "qrz"

for /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="AES" goto EncryptionCompleted
	)

for /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="XTS-AES" goto EncryptionCompleted
	)

for /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="None" goto TPMActivate
	)

goto ElevateAccess

:TPMActivate

powershell Get-BitlockerVolume

echo.
echo  =============================================================
echo  = It looks like your System Drive (%systemdrive%\) is not              =
echo  = encrypted. Let's try to enable BitLocker.                =
echo  =============================================================
for /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue ^| findstr "TRUE"') do (
if "%%A"=="TRUE" goto nextcheck
)

goto TPMFailure

:nextcheck
for /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue ^| findstr "TRUE"') do (
if "%%A"=="TRUE" goto starttpm
)

goto TPMFailure

:starttpm
powershell Initialize-Tpm

:bitlock

manage-bde -protectors -disable %systemdrive%
bcdedit /set {default} recoveryenabled No
bcdedit /set {default} bootstatuspolicy ignoreallfailures

manage-bde -protectors -delete %systemdrive% -type RecoveryPassword
manage-bde -protectors -add %systemdrive% -RecoveryPassword
for /F "tokens=2 delims=: " %%A in ('manage-bde -protectors -get %systemdrive% -type recoverypassword ^| findstr "       ID:"') do (
	echo %%A
	manage-bde -protectors -adbackup %systemdrive% -id %%A
)

manage-bde -protectors -enable %systemdrive%
manage-bde -on %systemdrive% -SkipHardwareTest


:VerifyBitLocker
for /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="AES" goto Inprogress
	)

for /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="XTS-AES" goto Inprogress
	)

for /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="None" goto EncryptionFailed
	)

:TPMFailure
echo.
echo  =============================================================
echo  = System Volume Encryption on drive (%systemdrive%\) failed.           =
echo  = The problem could be the Tpm Chip is off in the BiOS.     =
echo  = Make sure the TPMPresent and TPMReady is True.            =
echo  =                                                           =
echo  = See the Tpm Status below                                  =
echo  =============================================================

powershell get-tpm

echo  Closing session in 30 seconds...
TIMEOUT /T 30 /NOBREAK
Exit

:EncryptionCompleted
echo.
echo  =============================================================
echo  = It looks like your System drive (%systemdrive%) is                   =
echo  = already encrypted or it's in progress. See the drive      =
echo  = Protection Status below.                                  =
echo  =============================================================

powershell Get-BitlockerVolume

echo  Closing session in 20 seconds...
TIMEOUT /T 20 /NOBREAK
Exit

:ElevateAccess
echo  =============================================================
echo  = It looks like your system require that you run this       =
echo  = program as an Administrator.                              =
echo  =                                                           =
echo  = Please right-click the file and run as Administrator.     =
echo  =============================================================

echo  Closing session in 20 seconds...
TIMEOUT /T 20 /NOBREAK
Exit