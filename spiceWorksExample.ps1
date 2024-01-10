<#
.SYNOPSIS
    List all workstations in the domain.  Fields include LastLogonDate and the latest BitLocker password set date (if present)
.DESCRIPTION
    List all workstations in the domain.  Fields include LastLogonDate and the latest BitLocker password set date (if present)
.PARAMETER SearchBase
    OU where the script will begin it's search
.INPUTS
    None
.OUTPUTS
    CSV in script path
.EXAMPLE
    .\New-BitLockerReport.ps1
.NOTES
    Author:             Martin Pugh
    Found:              https://community.spiceworks.com/topic/1083065-bitlocker-status-on-all-computers
    Help:               https://fabozzi.net/powershell-find-computers-in-ad-with-stored-bitlocker-keys/ 
    Date:               4/9/2015
      
    Changelog:
        4/9             MLP - Initial Release
        4/15            MLP - Added code to load ActiveDirectory tools, or error out if they aren't present
#>

[CmdletBinding()]
Param (
    [string]$SearchBase = "OU=YourOUforWorkstations,DC=Your,DC=Domain"
)

Try { Import-Module ActiveDirectory -ErrorAction Stop }
Catch { Write-Warning "Unable to load Active Directory module because $($Error[0])"; Exit }


Write-Verbose "Getting Workstations..." -Verbose
$Computers = Get-ADComputer -Filter * -SearchBase $SearchBase -Properties LastLogonDate
$Count = 1
$Results = ForEach ($Computer in $Computers)
{
    Write-Progress -Id 0 -Activity "Searching Computers for BitLocker" -Status "$Count of $($Computers.Count)" -PercentComplete (($Count / $Computers.Count) * 100)
    New-Object PSObject -Property @{
        ComputerName = $Computer.Name
        LastLogonDate = $Computer.LastLogonDate 
        BitLockerPasswordSet = Get-ADObject -Filter "objectClass -eq 'msFVE-RecoveryInformation'" -SearchBase $Computer.distinguishedName -Properties msFVE-RecoveryPassword,whenCreated | Sort-Object whenCreated -Descending | Select-Object -First 1 | Select-Object -ExpandProperty whenCreated
    }
    $Count ++
}
Write-Progress -Id 0 -Activity " " -Status " " -Completed

$ReportPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path) -ChildPath "WorkstationsWithBitLocker.csv"
Write-Verbose "Building the report..." -Verbose
$Results | Select-Object ComputerName,LastLogonDate,BitLockerPasswordSet | Sort-Object ComputerName | Export-Csv $ReportPath -NoTypeInformation
Write-Verbose "Report saved at: $ReportPath" -Verbose