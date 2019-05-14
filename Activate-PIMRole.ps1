<#
.SYNOPSIS
This script activates a PIM role

.DESCRIPTION
UserName is a required parameter

.PARAMETER UserName
Required paramter. UserName for the acount with roles to activate.

.PARAMETER GlobalAdmin
Optional parameter. Using this parameter will skip the role picker and just activate the Global Admin role as quickly as possible.

.NOTES
1.0 - 
2.0 - Added default answers
3.0 - Now translates role activation time to the local time zone of the computer running the script
3.1 - Cleaned up time translation. Cleaned up formating and output.
3.2 - Changed display of multiple active roles.
4.0 - Added -GlobalAdmin switch which activates Global Admin role
4.1 - Added functions for a couple chucks of code that are used multiple times

Activate-PIMRole.ps1
v4.1
5/14/2019
By Nathan O'Bryan, MVP|MCSM
nathan@mcsmlab.com
Special thanks to Damian Scoles (https://www.practicalpowershell.com/) for an assist with the time translation in V3

.EXAMPLE
Activate-PIMRole -UserName nathan@mcsmlab.com

.Example
Activate-PIMRole -UserName nathan@mcsmlab.com -GlobalAdmin

.LINK
https://www.mcsmlab.com/about
https://github.com/MCSMLab/Activate-PimRoles/blob/master/Activate-PIMRole.ps1
#>

#Command line parameter
[cmdletbinding()]
Param (
    [Parameter(Mandatory=$True)][String]$UserName,
    [Parameter(Mandatory=$False)][Switch]$GlobalAdmin
    )

Function Show-ActiveRoles {
$CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object {($_.ExpirationTime)} | Select-Object RoleName, ExpirationTime, RoleID | ForEach-Object {$BaseTime = [DateTime]$_.ExpirationTime;$_.ExpirationTime = $BaseTime;Return $PSItem}        
If (-Not ($CurrentRoles)) {Write-Host "The requested role needs approval before it will be active" -ForegroundColor Yellow}

ForEach ($Role in $CurrentRoles) {
    Write-Host "You now have the privileged role:       " -ForegroundColor Green -NoNewline
    Write-Host $($Role.RoleName) -ForegroundColor Green
        
    Write-Host "The privileged role is valid until:     " -ForegroundColor Green -NoNewline
    Write-Host  $($Role.ExpirationTime) -ForegroundColor Green
    Write-Host}
}

Function Ask-Activate {
If (($Reason = Read-Host "Provide a reason why you need the elevated role: $($_.RoleName) [$($ReasonDefault)]") -eq '') {$Reason = $ReasonDefault} Else {}
If (($Duration = Read-Host "Provide a duration for this activation [$($DurationDefault)]") -eq '') {$Duration = $DurationDefault} Else {}
If (($Ticket = Read-Host "Provide a ticket number for this activation [$($TicketDefault)]") -eq '') {$Ticket = $TicketDefault} Else {}

Enable-PrivilegedRoleAssignment -RoleId $_.RoleId -Reason $Reason -Duration $Duration -TicketNumber $Ticket | Out-Null
}

#Default answers
$DisableRoleDefault = 'Y'
$EnableRoleDefault = 'Y'
$ReasonDefault = 'Work'
$DurationDefault = '8'
$TicketDefault = '123'

Clear-Host

#Check for PIM PowerShell module
If (-Not ( Get-Module -ListAvailable 'Microsoft.Azure.ActiveDirectory.PIM.PSModule' ).path){
    Write-Host "The Azure AD Privileged Identity Management Module is not installed, we will try to install it now" -ForegroundColor Yellow
    write-Host "This will only work if you are running this script as Local Administrator" -ForegroundColor Yellow
    Write-Host
    
    #Check if the script runs in an local Administrator context
    If ($(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) -eq $True)
        {Install-Module -Name Microsoft.Azure.ActiveDirectory.PIM.PSModule} 
    
    #Exit if PowerShell if not run as admin
    Else
    {Write-Host "You are not running the script as Local Admin. The script will exit now" -ForegroundColor Yellow
    Exit}}

Connect-PimService -UserName $UserName | Format-List UserName, TenantName

If ($GlobalAdmin) {
    $SelectedRoles = Get-PrivilegedRoleAssignment | Where-Object { ($_.RoleName -Eq "Global Administrator") } | Select-Object RoleName, ExpirationTime, RoleID

    $SelectedRoles | ForEach-Object {
    Ask-Activate
    Show-ActiveRoles
    Exit
    }
}

Write-host "All roles assigned to this account" -ForegroundColor Green
Get-PrivilegedRoleAssignment | Format-Table RoleName, IsElevated, IsPermanent -AutoSize

$CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object {($_.ExpirationTime)} | Select-Object RoleName, ExpirationTime, RoleID | ForEach-Object {$BaseTime = [DateTime]$_.ExpirationTime;$_.ExpirationTime = $BaseTime;Return $PSItem}

#Check currently assigned roles
If ($CurrentRoles) {
    Show-ActiveRoles

    #Disable current roles on request
    If (($DisableRole = Read-Host "Do you want to disable active role(s)? [$($DisableRoleDefault)]") -eq '') {$DisableRole = $DisableRoleDefault} Else {}
    If ($DisableRole -eq "Y") {$CurrentRoles | ForEach-Object {Disable-PrivilegedRoleAssignment -RoleId $_.RoleId | Out-Null}

    $CurrentRoles = Get-PrivilegedRoleAssignment | Where-Object { ($_.ExpirationTime) } | Select-Object RoleName, ExpirationTime, RoleID
        If (-Not ($CurrentRoles)) {Write-Host "You do not have any active roles" -ForegroundColor Yellow }}}

Else {   
    Write-Host "You do not have any active roles" -ForegroundColor Yellow
    
    #Activate a role
    If (($EnableRole = Read-Host "Do you want to enable one or more privileged role(s)? [$($EnableRoleDefault)]") -eq '') {$EnableRole = $EnableRoleDefault} Else {}
    If ($EnableRole -eq "Y") {
        $SelectedRoles = Get-PrivilegedRoleAssignment | Out-GridView -Title "Select the role(s) that you want to enable" -PassThru
        $SelectedRoles | ForEach-Object {
            Ask-Activate
            Write-Host}

    Show-ActiveRoles
    }}

Disconnect-PimService
