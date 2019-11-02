# Get-ExeTargetMachine

## SYNOPSIS

Displays the target machine type of any Windows executable (the CPU it was compiled to operate on).

## SYNTAX

```PowerShell
   Enable-WACDelegation.ps1 [-ComputerName] <String[]>
   [[-WACComputerName] <String>] [-Force] [<CommonParameters>]
```

## DESCRIPTION

Displays the target machine type of any Windows executable file (.exe or .dll).

The expected usage is to determine if an executable is 32- or 64-bit, in which case it will indicate "x86" or "x64", respectively. However, it will detect all machine types that were known as of the date of this script was authored.

## EXAMPLES

### Example 1: Returns the file name and a target machine of x64 (on a 64-bit system)

```PowerShell
PS C:\> Get-ExeTargetMachine.ps1 C:\Windows\bfsvc.exe
```

### Example 2: Returns the file name and a target machine of x86

```PowerShell
PS C:\> Get-ExeTargetMachine.ps1 C:\Windows\winhlp32.exe
```

### Example 3: Returns the path and target machine of all EXE files under C:\Program Files (x86) and all subfolders

```PowerShell
PS C:\> Get-ChildItem 'C:\Program Files (x86)\*.exe' -Recurse | Get-ExeTargetMachine.ps1
```

### Example 4: Returns the path and target machine of all EXE files under C:\Program Files and all subfolders that are not 64-bit (x64)

```PowerShell
PS C:\> Get-ChildItem 'C:\Program Files\*.exe' -Recurse | Get-ExeTargetMachine.ps1 | where { $_.TargetMachine -ne 'x64' }
```

### Example 5: Gets information only for the EXE files of unknown type under C:\Windows and subfolders. This can be used to find 16-bit and other EXEs that don't conform to the portable executable standard

```PowerShell
PS C:\> Get-ChildItem 'C:\windows\*.exe' -Recurse | Get-ExeTargetMachine.ps1 | where { $_.TargetMachine -eq '' }
```

### Example 6: Finds every file in C:\Program Files and subfolders with a portable executable header, regardless of extension, and displays their names and Target Machine in a grid view

```PowerShell
PS C:\> Get-ChildItem 'C:\Program Files\' -Recurse | Get-ExeTargetMachine.ps1 | Out-GridView
```

## REQUIRED PARAMETERS

A string that contains the path to the file to be checked. Can be relative or absolute.

### Path

```yaml
Type: String[]
Required: true
Position: 1
Default value: None
Accept pipeline input: True (ByValue, ByPropertyName)
Accept wildcard characters: True
```

## INPUTS

String

## OUTPUTS

ExeInfo object with members:

* TargetMachine [String]: file's target machine
* Path [String]: path to the file
* IsValid [Boolean]: if the file is a executable valid type

## LINK

[PE Format](http://msdn.microsoft.com/en-us/windows/hardware/gg463119.aspx)

## NOTES

Author: Eric Siron

Version 2.0, November 1, 2019

Released under MIT license
