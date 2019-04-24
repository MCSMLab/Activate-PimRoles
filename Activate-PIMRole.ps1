<#
.SYNOPSIS
This script activates a PIM role

.DESCRIPTION
UserName is a required parameter

.PARAMETER UserName

.NOTES
1.0 - 
2.0 - Added default answers
3.0 - Now translates role activation time to the local time zone of the computer running the script
3.1 - Cleaned up time translation. Cleaned up formating and output.
3.2 - Changed display of multiple active roles.

Activate-PIMRole.ps1
v3.2
4/24/2019
By Nathan O'Bryan, MVP|MCSM
nathan@mcsmlab.com

Special thanks to Damian Scoles (https://www.practicalpowershell.com/) for an assist with the time translation in V3

.EXAMPLE
Activate-PIMRole -UserName nathan@mcsmlab.com

.LINK
https://www.mcsmlab.com/about
https://github.com/MCSMLab/Activate-PimRoles/blob/master/Activate-PIMRole.ps1
#>

#Command line parameter
PARAM ($UserName = $(Throw "-UserName is a required parameter" ))

#Default answers
$DisableRoleDefault = 'Y'
$EnableRoleDefault = 'Y'
$ReasonDefault = 'Work'
$DurationDefault = '8'

Clear-Host

#Check for PIM PowerShell module
If (-Not ( Get-Module -ListAvailable 'Microsoft.Azure.ActiveDirectory.PIM.PSModule' ).path)
{
    Write-Host "The Azure AD Privileged Identity Management Module is not installed, we will try to install it now" -ForegroundColor Yellow
    write-Host "This will only work if you are running this script as Local Administrator" -ForegroundColor Yellow
    Write-Host ""
    
    #Check if the script runs in an local Administrator context
    If ($(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $True)
        {Install-Module -Name Microsoft.Azure.ActiveDirectory.PIM.PSModule} 
    
    #Exit if PowerShell if not run as admin
    Else
    {
        Write-Host "You are not running the script as Local Admin. The script will exit now" -ForegroundColor Yellow
        Exit
    }
}

#Connect to PIM service and get current roles
Connect-PimService -UserName $UserName | Out-Null
$CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object { ($_.ExpirationTime) } | Select-Object RoleName, ExpirationTime, RoleID | ForEach-Object {$BaseTime = [DateTime]$_.ExpirationTime;$_.ExpirationTime = $BaseTime;Return $PSItem}

#Check currently assigned roles
If ($CurrentRoles) {
    #Show active roles
    ForEach ($Role in $CurrentRoles) {
        Write-Host "You now have the privileged role:       " -ForegroundColor Green -NoNewline
        Write-Host $($Role.RoleName) -ForegroundColor Green
        
        Write-Host "The privileged role is valid until:     " -ForegroundColor Green -NoNewline
        Write-Host  $($Role.ExpirationTime) -ForegroundColor Green
        Write-Host
        }

    #Disable current roles on request
    If (($DisableRole = Read-Host "Do you want to disable a privileged role? [$($DisableRoleDefault)]") -eq '') {$DisableRole = $DisableRoleDefault} Else {}
    If ($DisableRole -eq "Y") {
        $CurrentRoles | ForEach-Object {Disable-PrivilegedRoleAssignment -RoleId $_.RoleId | Out-Null}

    $CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object { ($_.ExpirationTime) } | Select-Object RoleName, ExpirationTime, RoleID
        If (-Not ($CurrentRoles) ) {Write-Host "You do not have any active roles" -ForegroundColor Yellow -NoNewline}
    }
}

Else {   
    Write-Host "You do not have any active roles" -ForegroundColor Yellow
    
    #Activate a role
    If (($EnableRole = Read-Host "Do you want to enable one or more privileged role? [$($DisableRoleDefault)]") -eq '') {$EnableRole = $EnableRoleDefault} Else {}
    If ($EnableRole -eq "Y") {
        $SelectedRoles = Get-PrivilegedRoleAssignment | Out-GridView -Title "Select the role(s) that you want to enable" -PassThru
        $SelectedRoles | ForEach-Object {
            If (($Reason = Read-Host "Provide a reason why you need the elevated role: $($_.RoleName) [$($ReasonDefault)]") -eq '') {$Reason = $ReasonDefault} Else {}
            If (($Duration = Read-Host "Provide a duration for this activation [$($DurationDefault)]") -eq '') {$Duration = $DurationDefault} Else {}
            Enable-PrivilegedRoleAssignment -RoleId $_.RoleId -Reason $Reason -Duration $Duration | Out-Null
            Write-Host
       }

    #Show active roles
    $CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object {($_.ExpirationTime)} | Select-Object RoleName, ExpirationTime, RoleID | ForEach-Object {$BaseTime = [DateTime]$_.ExpirationTime;$_.ExpirationTime = $BaseTime;Return $PSItem}        
    ForEach ($Role in $CurrentRoles) {
        Write-Host "You now have the privileged role:       " -ForegroundColor Green -NoNewline
        Write-Host $($Role.RoleName) -ForegroundColor Green
        
        Write-Host "The privileged role is valid until:     " -ForegroundColor Green -NoNewline
        Write-Host  $($Role.ExpirationTime) -ForegroundColor Green
        Write-Host
        }
    }
}

Disconnect-PimService
