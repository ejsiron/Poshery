<#
.SYNOPSIS
	Grants delegation in Active Directory to a system running Windows Admin Center so that it can pass credentials to the destination system(s).
.DESCRIPTION
	Grants delegation in Active Directory to a system running Windows Admin Center so that it can pass credentials to the destination system(s).
	In some cases, this will reduce the need to continually re-enter credentials when using Windows Admin Center.
.PARAMETER ComputerName
	Name of one or more target computers. Use only the short (NetBIOS) name.
.PARAMETER WACComputerName
    Name of the system that hosts Windows Admin Center running in gateway mode. Use only the short (NetBIOS) name.
    If not specified, assumes the local system. To reduce accidents from leaving off the second parameter, will check the local system for the existence of a WAC gateway. If not found and running non-interactively, the script will exit. If not found and running interactively, prompts for the name of the WAC system. Use -Force to override the local check.
.PARAMETER Force
    Override the local check for a WAC gateway.
.EXAMPLE
	PS C:\> Enable-WACDelegation -ComputerName svtarget -WACComputerName svwac
	Enables the system named "svwac" to delegate to "hc-target"
.EXAMPLE
	PS C:\> Enable-WACDelegation svtarget svwac
	Enables the system named "svwac" to delegate to "hc-target"
.EXAMPLE
	PS C:\> Enable-WACDelegation svtarget1, svtarget2 svwac
    Enables the system named "svwac" to delegate to both "svtarget1" and "svtarget2"
.EXAMPLE
    PS C:\> Enable-WACDelegation svtarget1, svtarget2
    If the local system is running a gateway WAC, enables it to delegate to both "svtarget1" and "svtarget2"
.NOTES
    Author: Eric Siron
    Version 1.1, February 13, 2019
    Released under MIT license
.LINK
https://ejsiron.github.io/Poshery/Enable-WACDelegation
#>

#requires -Version 4
#requires -Modules @{ ModuleName='ActiveDirectory'; ModuleVersion='1.0.1.0' }

[CmdletBinding()]
param(
	[Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)][String[]]$ComputerName,
    [Parameter(Position=2)][String]$WACComputerName=$env:COMPUTERNAME,
    [Parameter()][Switch]$Force
)
begin
{
    $ErrorActionPreference=[System.Management.Automation.ActionPreference]::Stop
    $WACMissingMessage = 'No WAC gateway installation detected. Specify a value for the WACComputerName parameter.'
    if([String]::IsNullOrEmpty($WACComputerName))
    {
        $WACComputerName = $env:COMPUTERNAME
    }
    if($WACComputerName -eq $env:COMPUTERNAME -and -not $Force)
    {
        if(-not (Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\ServerManagementGateway\'))
        {
            if([bool]([Environment]::GetCommandLineArgs() -like '-noni*'))
            {
                Write-Error -Message $WACMissingMessage
            }
            else
            {
                while($WACComputerName -eq $env:COMPUTERNAME -or [String]::IsNullOrEmpty($WACComputerName))
                {
                    $WACComputerName = Read-Host -Prompt $WACMissingMessage
                }
            }
        }
    }
}

process
{
	$WACGateway = Get-ADComputer -Identity $WACComputerName -ErrorAction Stop
	foreach($TargetSystem in $ComputerName)
	{
		Set-ADComputer -Identity $TargetSystem -PrincipalsAllowedToDelegateToAccount $WACGateway
	}
}
