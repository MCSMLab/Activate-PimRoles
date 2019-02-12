<#
.SYNOPSIS
This script activates a PIM role

.DESCRIPTION
UserName is a required parameter.

.PARAMETER UserName

.NOTES
1.0 - 

Activate-PIMRole.ps1
v1.0
2/7/2019
By Nathan O'Bryan, MVP|MCSM
nathan@mcsmlab.com

.EXAMPLE
Activate-PIMRole -UserName nathan@mcsmlab.com

.LINK
https://www.mcsmlab.com/about
#>

PARAM
(
    $UserName = $(throw "-UserName is a required parameter" )
)

Clear-Host

#Check for PIM PowerShell module
If (-Not ( Get-Module -ListAvailable 'Microsoft.Azure.ActiveDirectory.PIM.PSModule' ).path)
{
    Write-Host "The Azure AD Privileged Identity Management Module is not installed, we will try to install it now." -ForegroundColor Yellow
    write-Host "This will only work if you are running this script as Local Administrator" -ForegroundColor Yellow
    Write-Host ""

    #Check if the script runs in an local Administrator context
    If ($(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $True)
    {
        Install-Module -Name Microsoft.Azure.ActiveDirectory.PIM.PSModule
    } 
    
    Else
    {
        Write-Host "You are not running the script as Local Admin, we can not install the correct Module. The script will exit now" -ForegroundColor Yellow
        Exit
    }
}

#Connect to PIM service and get current roles
Connect-PimService -UserName $UserName
$CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object { ($_.ExpirationTime) } | Select-Object RoleName,ExpirationTime,RoleID

#Check currently assigned roles
If ($CurrentRoles) {
    
    $RoleEnabled = $True
    Write-Host "You currently have the role(s):         " -ForegroundColor Green -NoNewline
    Write-Host $($CurrentRoles.RoleName) -ForegroundColor Magenta
    
    Write-Host "The privileged role is valid until:    " -ForegroundColor Green -NoNewline
    Write-Host  $($CurrentRoles.ExpirationTime) -ForegroundColor Magenta
    
    #Disable current roles on request
    $DisableRole = Read-Host "Do you want to disable the current privileged role(s)? (Y/N)"
    If ($DisableRole -eq "Y") {
        $CurrentRoles | ForEach-Object {
            Disable-PrivilegedRoleAssignment -RoleId $_.RoleId | Out-Null
        }
        
        $CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object { ($_.expirationtime) } | Select-Object RoleName,ExpirationTime,RoleID
        If (-Not ($CurrentRoles) ) {
            Write-Host "You do not have any active roles" -ForegroundColor Yellow -NoNewline
        }
    }
}

Else {
    
    Write-Host "You do not have any active roles"
    
    #Activate a role
    $EnableRole = Read-Host "Do you want to enable a privileged role? (Y/N)"
    
    If ($EnableRole -eq "Y") {
        $SelectedRoles = Get-PrivilegedRoleAssignment | Out-GridView -Title "Select the role(s) that you want to enable" -PassThru
        $SelectedRoles | ForEach-Object {
            $Reason = Read-Host -Prompt "Provide a reason why you need the elevated role: $($_.RoleName)"
            Enable-PrivilegedRoleAssignment -RoleId $_.RoleId -Reason $Reason | Out-Null
        }
        
        $CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object { ($_.expirationtime) } | Select-Object RoleName,ExpirationTime,RoleID
        If ($CurrentRoles) {
            Write-Host "You now have the privileged role(s):    " -ForegroundColor Green -NoNewline
            Write-Host $($CurrentRoles.RoleName) -ForegroundColor Magenta
            Write-Host "The privileged role is valid until :    " -ForegroundColor Green -NoNewline
            Write-Host  $($CurrentRoles.ExpirationTime) -ForegroundColor Magenta
        }
    }
}