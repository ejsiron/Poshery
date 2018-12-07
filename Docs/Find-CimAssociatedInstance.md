# Find-CimAssociatedInstance

## SYNOPSIS

Traces CIM associations from the supplied instance, searching for an instance with the name specified in ResultClass.

## SYNTAX

```PowerShell
Find-CimAssociatedInstance.ps1 [-CimInstance] <CimInstance>
 [-ResultClassName] <String> [-MaxDistance <Int32>] [-MaxResults <Int32>]
 [-ExcludeBranches <String[]>] [-PathOnly]
 [-KeyOnly] [<CommonParameters>]
```

## DESCRIPTION

Traces CIM associations from the supplied instance, searching for an instance with the name specified in ResultClass.

Instead of following each path to its end before moving to the next, the search moves laterally. It checks all first-level associations, then all second-level associations, etc. until it finds no more unchecked associations or reaches the specified maximum depth.

Due to the behavior of the native CIM cmdlets, searches proceed radially. They do not distinguish between "antecedent" and "descendant" associations. To prevent infinite recursion, the search will skip an instance whose associations have already been checked.

## EXAMPLES

### Example 1: Retrieve all related instances of a specific type using defaults

```PowerShell
PS C:\> $VMHost = (Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem)[0]
PS C:\> Find-CimAssociatedInstance.ps1 -CimInstance $VMHost -ResultClassName Msvm_EthernetSwitchPortVlanSettingData
```

On a Hyper-V host, loads the management operating system instance, then finds all instances of Msvm_EthernetSwitchPortVlanSettingData within an association distance of 10 (the default).

### Example 2: Limit the search distance to 6 levels

```PowerShell
PS C:\> $VMHost = (Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem)[0]
PS C:\> Find-CimAssociatedInstance.ps1 -CimInstance $VMHost -ResultClassName Msvm_EthernetSwitchPortVlanSettingData -MaxDistance 6
```

On a Hyper-V host, loads the management operating system instance, then finds all instances of Msvm_EthernetSwitchPortVlanSettingData within an association distance of 6.

### Example 3: Exclude a specific class from the search.

```PowerShell
PS C:\> $VMHost = (Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem)[0]
PS C:\> Find-CimAssociatedInstance.ps1 -CimInstance $VMHost -ResultClassName Msvm_EthernetSwitchPortVlanSettingData -MaxDistance 6 -ExcludeBranches 'Msvm_ResourcePool' -PathOnly
```

On a Hyper-V host, loads the management operating system instance, then finds the paths of all instances of Msvm_EthernetSwitchPortVlanSettingData within an association distance of 6. Avoids any branch containing an instance named "Msvm_ResourcePool".

### Example 4: Exclude multiple branches from the search.

```PowerShell
PS C:\> $VMHost = (Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem)[0]
PS C:\> Find-CimAssociatedInstance.ps1 -CimInstance $VMHost -ResultClassName Msvm_EthernetSwitchPortVlanSettingData -MaxDistance 6 -ExcludeBranches 'Msvm_ResourcePool/Msvm_VirtualEthernetSwitch', 'Msvm_InstalledEthernetSwitchExtension/Msvm_EthernetSwitchFeatureCapabilities' -PathOnly -MaximumResults 1
```

On a Hyper-V host, loads the management operating system instance, then finds the paths of the first instance of Msvm_EthernetSwitchPortVlanSettingData within an association distance of 6. Avoids any branch containing "Msvm_ResourcePool/Msvm_VirtualEthernetSwitch" or "Msvm_InstalledEthernetSwitchExtension/Msvm_EthernetSwitchFeatureCapabilities".

## REQUIRED PARAMETERS

### -CimInstance

The CIM instance that serves as the source for the search.

```yaml
Type: Microsoft.Management.Infrastructure.CimInstance
Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -ResultClassName

The name of the desired CIM instance to retrieve.

```yaml
Type: String
Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## OPTIONAL PARAMETERS

### -MaxDistance

The maximum number of association levels to process.
Specify 0 to continue until all relationships have been searched.

```yaml
Type: Integer32
Required: False
Position: Named
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxResults

The maximum number of associated instances to return.
When set, the search halts immediately when it has found the specified number of matching instances.
When 0 or not set, the search will continue until all associated instances have been checked, up to MaxDistance.

```yaml
Type: SwitchParameter
Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeBranches

If the search path that leads to a given CIM instance contains any of the items in ExcludeBranches, the search will not check its associations.

An entry can be a single class name, such as "Win32_OperatingSystem" or it can be a path with multiple components. Separate components with a "/". Example: "Win32_OperatingSystem/Win32_ComputerSystem".

The search uses regular expressions to match. Affix a slash (/) to the end of class names to avoid accidental partial matches. Example: "Win32_OperatingSystem/".

```yaml
Type: String[]
Required: False
Position: Named
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -PathOnly

Instead of the discovered instances, returns the path(s) the search followed to find them.

Results are displayed in the format "SourceClassName/FirstAssociation/SecondAssociation/..."

```yaml
Type: SwitchParameter
Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -PARAMETER KeyOnly

Only retrieve values for key properties. No effect if PathOnly is also specified.

```yaml
Type: SwitchParameter
Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

- **Microsoft.Management.Infrastructure.CimInstance**
- **String**

## OUTPUTS

**Microsoft.Management.Infrastructure.CimInstance[]** by default.
**String** is -PathOnly is set.

## NOTES

Author: Eric Siron

Version 1.0, November 23, 2018

Released under MIT license

## RELATED LINKS
[Get-CimInstance](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance)