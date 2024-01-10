<#
.SYNOPSIS
    Creates a report from Active Directory that includes IP address, TPM Version, and Bitlocker
    Drive Encryption status
.DESCRIPTION
    This Script will access data from the primary DNS Server and Primary Domain Controller to
    collect a list of computers in the designated OU and query those terminals for TPM and
    BDE information.
.PARAMETER SearchBase
    OU where the script will begin it's search
.INPUTS
    Domain controller information, DNS incormation related to DC information.
.OUTPUTS
    CSV in '$PSScriptRoot\Bitlocker_Report_v1.54.csv'
.EXAMPLE
    .\Bitlocker_Report_v1.54.csv
.NOTES
    Author:             Sean Slocum
    Date:               05/02/2023

    TO BE NOTED. This script runs very slow. Our AD environment is what I'd consider small. (<150 endpoints)

    Changelog:
        v1.10   05/02/23    SCS - Initial draft
        v1.20   05/03/23    SCS - Sorry, didn't document well enough.
        v1.30   05/03/23    SCS - Sorry, didn't document well enough.
        v1.40   05/04/23    SCS - Sorry, didn't document well enough.
        v1.50   05/05/23    SCS - Sorry, didn't document well enough.
        v1.51   05/08/23    SCS - Sorry, didn't document well enough.
        v1.52   05/09/23    SCS - Sorry, didn't document well enough.
        v1.53   05/10/23    SCS - Sorry, didn't document well enough.
        v1.54   05/16/23    SCS - Added filter to "$computers" Object where it will only search for
                                  computers that are enabled in AD.
#>

###   VALIDATED 5-5-23   ###

# Set the path to the output CSV file
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "Bitlocker_Report_v1.54.csv"
$results = @()
# Example for code below: '-SearchBase "OU=Terminals,OU=Terminals,DC=<domain>,DC=<domain tld>"' if want to search all of AD
$computers = Get-ADComputer -Filter "Enabled -eq 'True'" -SearchBase <"OU that you want to search in">
$total = $computers.Count
$count = 0

# Loop through each computer and check if it has a valid TPM
foreach ($computer in $computers) {

    # Objects for foreach process
    $count++
    $percentComplete = ($count / $total) * 100
    $roundedPercent = [Math]::round($percentComplete)
    $computerName = $Computer.name
    $computerIPv4 = Resolve-DnsName -Name $computerName -server <"IP Address of DNS server"> -Type A -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress

    # Progress Bar Code
    Write-Progress -Activity " Checking for TPM Modules || $roundedPercent% Complete || $computerName" -PercentComplete $percentComplete

    # Check if the computer is online
    if (Test-Connection -ComputerName $computer.Name -Quiet -Count 1) {
        $isOnline = 'Online'
    }
    else {
        $isOnline = 'Offline'
    }

    # Get the TPM information for the computer
    $tpm = Get-WmiObject -Namespace root\CIMV2\Security\MicrosoftTpm -Class Win32_Tpm -ComputerName $computer.Name -ErrorAction SilentlyContinue
    $tpmSpecVersion = $tpm.SpecVersion
    $bitLockerStatus = if (manage-bde -cn $computer.name -status $env:SystemDrive | Select-String "Protection On") {
        $true
    }
    else {
        $false
    }

    # If the computer has a valid TPM, add it to the results array
    if ($tpm) {
        $results += [PSCustomObject]@{
            'Computer Name'   = $computer.Name
            'IPv4 Address'    = $computerIPv4
            'Online Status'   = $isOnline
            'TPM Version'     = $tpmSpecVersion.Substring(0, 3)
            'Is Active'       = $tpm.IsActivated_InitialValue
            'Is Enabled'      = $tpm.IsEnabled_InitialValue
            'Manufacturer Id' = $tpm.ManufacturerId
            'Bde Enabled'     = $bitLockerStatus
            'Notes'           = ''
        }
    }
    else {
        $results += [PSCustomObject]@{
            'Computer Name'   = $computer.Name
            'IPv4 Address'    = $computerIPv4
            'Online Status'   = $isOnline
            'TPM Version'     = 'N/A'
            'Is Active'       = 'FALSE'
            'Is Enabled'      = 'FALSE'
            'Manufacturer Id' = ''
            'Bde Enabled'     = $bitLockerStatus
            'Notes'           = ''
        }
    }
}

Write-Host "`n|| TPM data found... Exporting now ||"

# Export the results to a CSV file
$results | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "`n|| Export Complete ||"

Read-Host -Prompt "`nPress Enter to continue"
