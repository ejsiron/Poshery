<#
.SYNOPSIS
Traces CIM associations from the supplied instance, searching for an instance with the name specified in ResultClass.
.DESCRIPTION
Traces CIM associations from the supplied instance, searching for an instance with the name specified in ResultClass.
Instead of following each path to its end before moving to the next, the search moves laterally. It checks all first-level associations, then all second-level associations, etc. until it finds no more unchecked associations or reaches the specified maximum depth.
Due to the behavior of the native CIM cmdlets, searches proceed radially. They do not distinguish between "antecedent" and "descendant" associations. To prevent infinite recursion, the search will skip an instance whose associations have already been checked.
.PARAMETER CimInstance
The CIM instance that serves as the source for the search.
.PARAMETER ResultClassName
The name of the desired CIM instance to retrieve.
.PARAMETER MaxDistance
The maximum number of association levels to process.
Specify 0 to continue until all relationships have been searched.
.PARAMETER MaxResults
The maximum number of associated instances to return.
When set, the search halts immediately when it has found the specified number of matching instances.
When 0 or not set, the search will continue until all associated instances have been checked, up to MaxDistance.
.PARAMETER ExcludeBranches
If the search path that leads to a given CIM instance contains any of the items in ExcludeBranches, the search will not check its associations.
An entry can be a single class name, such as "Win32_OperatingSystem" or it can be a path with multiple components. Separate components with a "/". Example: "Win32_OperatingSystem/Win32_ComputerSystem".
The search uses regular expressions to match. Affix a slash (/) to the end of class names to avoid accidental partial matches. Example: "Win32_OperatingSystem/"..PARAMETER PathOnly
Instead of the discovered instances, returns the path(s) the search used to find them.
Results are displayed in the format of "SourceClassName/FirstAssociation/SecondAssociation/..."
.PARAMETER PathOnly
Instead of the discovered instances, returns the path(s) the search followed to find them.
Results are displayed in the format "SourceClassName/FirstAssociation/SecondAssociation/..."
.PARAMETER KeyOnly
Only retrieve values for key properties. No effect if PathOnly is also specified.
.NOTES
Author: Eric Siron
Version 1.0, November 23, 2018
Released under MIT license
.INPUTS
Microsoft.Management.Infrastructure.CimInstance and String
.OUTPUTS
Microsoft.Management.Infrastructure.CimInstance[] or String[]
.EXAMPLE
PS C:\> $VMHost = (Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem)[0]
PS C:\> Get-CimDistantAssociation.ps1 -CimInstance $VMHost -ResultClassName Msvm_EthernetSwitchPortVlanSettingData

On a Hyper-V host, loads the management operating system instance, then finds all instances of Msvm_EthernetSwitchPortVlanSettingData within an association distance of 10.

.EXAMPLE
PS C:\> $VMHost = (Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem)[0]
PS C:\> Get-CimDistantAssociation.ps1 -CimInstance $VMHost -ResultClassName Msvm_EthernetSwitchPortVlanSettingData -MaxDistance 6

On a Hyper-V host, loads the management operating system instance, then finds all instances of Msvm_EthernetSwitchPortVlanSettingData within an association distance of 6.

.EXAMPLE
PS C:\> $VMHost = (Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem)[0]
PS C:\> Get-CimDistantAssociation.ps1 -CimInstance $VMHost -ResultClassName Msvm_EthernetSwitchPortVlanSettingData -MaxDistance 6 -ExcludeBranches 'Msvm_ResourcePool' -PathOnly

On a Hyper-V host, loads the management operating system instance, then finds the paths of all instances of Msvm_EthernetSwitchPortVlanSettingData within an association distance of 6. Avoids any branch containing an instance named "Msvm_ResourcePool".

.EXAMPLE
PS C:\> $VMHost = (Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem)[0]
PS C:\> Get-CimDistantAssociation.ps1 -CimInstance $VMHost -ResultClassName Msvm_EthernetSwitchPortVlanSettingData -MaxDistance 6 -ExcludeBranches 'Msvm_ResourcePool/Msvm_VirtualEthernetSwitch', 'Msvm_InstalledEthernetSwitchExtension/Msvm_EthernetSwitchFeatureCapabilities' -PathOnly -MaxResults 1

On a Hyper-V host, loads the management operating system instance, then finds the paths of the first instance of Msvm_EthernetSwitchPortVlanSettingData within an association distance of 6. Avoids any branch containing "Msvm_ResourcePool/Msvm_VirtualEthernetSwitch" or "Msvm_InstalledEthernetSwitchExtension/Msvm_EthernetSwitchFeatureCapabilities".

.LINK
Get-CimInstance: https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)][Microsoft.Management.Infrastructure.CimInstance]$CimInstance,
	[Parameter(Mandatory = $true, Position = 2)][String]$ResultClassName,
	[Parameter()][int]$MaxDistance = 10,
	[Parameter()][int]$MaxResults = 0,
	[Parameter()][String[]]$ExcludeBranches = @(),
	[Parameter()][Switch]$PathOnly,
	[Parameter()][Switch]$KeyOnly
)
begin
{
	Set-StrictMode -Version Latest
	$KeyHashes = New-Object System.Collections.ArrayList
	$FoundInstances = New-Object System.Collections.ArrayList

	function MatchInCollection
	{
		param(
			[Parameter()][String]$Haystack,
			[Parameter()][System.Collections.IEnumerable]$Needles
		)
		$Found = $false
		foreach ($Needle in $Needles)
		{
			if ($Haystack -match $Needle)
			{
				$Found = $true
				break
			}
		}
		$Found
	}
	function Get-CimInstanceStringHash
	{
		param(
			[Parameter()][Microsoft.Management.Infrastructure.CimInstance]$CimInstance
		)
		$KeyHash = [String]::Empty
		foreach ($InstanceProperty in $CimInstance.CimInstanceProperties)
		{
			if ($InstanceProperty.Flags -band [Microsoft.Management.Infrastructure.CimFlags]::Key)
			{
				$KeyHash += '{0}{1}' -f $InstanceProperty.Name, $InstanceProperty.Value
			}
		}
		$KeyHash
	}

	function New-CrumbedInstance
	{
		param(
			[Parameter()][Microsoft.Management.Infrastructure.CimInstance]$CimInstance,
			[Parameter()][String]$ParentBreadCrumb = ''
		)
		$BreadCrumb = [String]::Empty
		if ([String]::IsNullOrEmpty($ParentBreadCrumb))
		{
			$BreadCrumb = $CimInstance.CimClass.CimClassName
		}
		else
		{
			$BreadCrumb = [String]::Join('/', @($ParentBreadCrumb, $CimInstance.CimClass.CimClassName))
		}

		$CrumbedInstance = New-Object psobject
		$AddMemberProperties = @{
			BreadCrumb  = $BreadCrumb;
			CimInstance = $CimInstance;
			Hash        = (Get-CimInstanceStringHash -CimInstance $CimInstance)
		}
		Add-Member -InputObject $CrumbedInstance -NotePropertyMembers $AddMemberProperties
		$CrumbedInstance
	}

	function Get-CrumbedChildren
	{
		param(
			[Parameter()][psobject[]]$InstancePacks,
			[Parameter()][String]$Needle,
			[Parameter()][int]$DepthCounter,
			[Parameter()][int]$MaxResults,
			[Parameter()][bool]$KeyOnly
		)
		$Children = New-Object System.Collections.ArrayList
		$DepthInstanceCounter = 0
		foreach ($InstancePack in $InstancePacks)
		{
			Write-Debug -Message ('Parent: {0}' -f $InstancePack.BreadCrumb)
			$DepthInstanceCounter++
			if (-not $KeyHashes.Contains($InstancePack.Hash))
			{
				$OutNull = $KeyHashes.Add($InstancePack.Hash)
				foreach ($AssociatedInstance in Get-CimAssociatedInstance -InputObject $InstancePack.CimInstance -KeyOnly -ErrorAction SilentlyContinue)
				{
					$ThisClassName = $AssociatedInstance.CimClass.CimClassName
					Write-Progress -Activity ('Checking associated instances of "{0}"' -f $InstancePack.CimInstance.CimClass.CimClassName) -CurrentOperation $ThisClassName -Status ('Searching {0} instances at depth {1}' -f $InstancePacks.Count, $DepthCounter) -PercentComplete (($DepthInstanceCounter / $InstancePacks.Count) * 100)
					$ThisCrumbedInstance = New-CrumbedInstance -CimInstance $AssociatedInstance -ParentBreadCrumb $InstancePack.BreadCrumb
					Write-Debug -Message ('Parent: {0}' -f $ThisCrumbedInstance.BreadCrumb)
					Write-Debug -Message $ThisCrumbedInstance.BreadCrumb
					if ($ThisClassName -eq $Needle)
					{
						if ($PathOnly)
						{
							$OutNull = $FoundInstances.Add($ThisCrumbedInstance.BreadCrumb)
						}
						elseif ($KeyOnly)
						{
							$OutNull = $FoundInstances.Add($AssociatedInstance)
						}
						else
						{
							$OutNull = $FoundInstances.Add((Get-CimInstance -InputObject $AssociatedInstance))
						}
						if ($MaxResults -gt 0 -and $FoundInstances.Count -ge $MaxResults)
						{
							return
						}
					}
					elseif (-not (MatchInCollection -Haystack $ThisCrumbedInstance.BreadCrumb -Needles $ExcludeBranches))
					{
						$OutNull = $Children.Add($ThisCrumbedInstance)
					}
				}
			}
		}
		$Children.ToArray()
	}
}

process
{
	$InstancePacks = @(New-CrumbedInstance -ParentBreadCrumb '' -CimInstance $CimInstance)
	$DepthCounter = 0
	do
	{
		$DepthCounter++
		$InstancePacks = Get-CrumbedChildren -InstancePacks $InstancePacks -Needle $ResultClassName -Depth $DepthCounter -MaxResults $MaxResults -KeyOnly $KeyOnly.ToBool()
	} while ($InstancePacks -and $InstancePacks.Count -and ($MaxDistance -eq 0 -or $DepthCounter -le $MaxDistance))
	$FoundInstances
}