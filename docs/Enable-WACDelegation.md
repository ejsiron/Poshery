# Enable-WACDelegation

## SYNOPSIS

Grants delegation in Active Directory to a system running Windows Admin Center so that it can pass credentials to the destination system(s).

## SYNTAX

```PowerShell
    Enable-WACDelegation.ps1 [-ComputerName] <String[]>
    [[-WACComputerName] <String>]
    [-Force] [<CommonParameters>]
```

## DESCRIPTION

Grants delegation in Active Directory to a system running Windows Admin Center so that it can pass credentials to the destination system(s).
In some cases, this will reduce the need to continually re-enter credentials when using Windows Admin Center.

## EXAMPLES

### Example 1: One target, WAC server specified

```PowerShell
PS C:\> Enable-WACDelegation -ComputerName svtarget -WACComputerName svwac
```

Enables the system named "svwac" to delegate to "hc-target"

### Example 2: One target, WAC server specified, positional parameters

```PowerShell
C:\> Enable-WACDelegation svtarget svwac
```

Enables the system named "svwac" to delegate to "hc-target"

### Example 3: Multiple targets, WAC server specified

```PowerShell
C:\> Enable-WACDelegation svtarget1, svtarget2 svwac
```

Enables the system named "svwac" to delegate to both "svtarget1" and "svtarget2"

### Example 4: Multiple targets, local WAC assumed

```PowerShell
C:\> Enable-WACDelegation svtarget1, svtarget2
```

If the local system is running a gateway WAC, enables it to delegate to both "svtarget1" and "svtarget2"

## REQUIRED PARAMETERS

### ComputerName

Name of one or more target computers. Use only the short (NetBIOS) name.

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: True (ByValue, ByPropertyName)
Accept wildcard characters: false
```

## OPTIONAL PARAMETERS

### WACComputerName

Name of the system that hosts Windows Admin Center running in gateway mode. Use only the short (NetBIOS) name.

If not specified, assumes the local system. To reduce accidents from leaving off the second parameter, will check the local system for the existence of a WAC gateway. If not found and running non-interactively, the script will exit. If not found and running interactively, prompts for the name of the WAC system. Use -Force to override the local check.

```yaml
Type: String
Required: false
Position: 3
Default value: $env:COMPUTERNAME
Accept pipeline input: false
Accept wildcard characters: false
```

### Force

Override the local check for a WAC gateway.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
Accept wildcard characters: false
```

## INPUTS

String

## OUTPUTS

None

## NOTES

Author: Eric Siron

Version 1.1, February 13, 2019

Released under MIT license
