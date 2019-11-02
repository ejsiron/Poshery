<#
.SYNOPSIS
	Displays the target machine type of any Windows executable (the CPU it was compiled to operate on).

.DESCRIPTION
	Displays the target machine type of any Windows executable file (.exe or .dll).
	The expected usage is to determine if an executable is 32- or 64-bit, in which case it will return "x86" or "x64", respectively.
	However, it will detect all machine types that were known as of the date of this script was authored.
	
.PARAMETER Path
	A string that contains the path to the file to be checked. Can be relative or absolute.

.LINK
	https://ejsiron.github.io/Poshery/Get-ExeTargetMachine
	http://msdn.microsoft.com/en-us/windows/hardware/gg463119.aspx
	
.OUTPUTS
	ExeInfo object with the members:
	-- TargetMachine [String]: file's target machine
	-- Path [String]: path to the file
	-- IsValid [Boolean]: if the file is a executable valid type

.NOTES
   Author: Eric Siron
   Version 2.0, November 1, 2019
   Released under MIT license

.EXAMPLE
	PS C:\> C:\Scripts\Get-ExeTargetMachine.ps1 C:\Windows\bfsvc.exe
	
	Description
	-----------
	Returns the file name and a target machine of x64 (on a 64-bit system)

.EXAMPLE
	PS C:\> C:\Scripts\Get-ExeTargetMachine.ps1 C:\Windows\winhlp32.exe
	
	Description
	-----------
	Returns the file name and a target machine of x86

.EXAMPLE
	PS C:\> Get-ChildItem 'C:\Program Files (x86)\*.exe' -Recurse | C:\Scripts\Get-ExeTargetMachine.ps1
	
	Description
	-----------
	Returns the path and target machine of all EXE files under C:\Program Files (x86) and all subfolders

.EXAMPLE
	PS C:\> Get-ChildItem 'C:\Program Files\*.exe' -Recurse | C:\Scripts\Get-ExeTargetMachine.ps1 | where { $_.TargetMachine -ne 'x64' }
	
	Description
	-----------
	Returns the path and target machine of all EXE files under C:\Program Files and all subfolders that are not 64-bit (x64)

.EXAMPLE
	PS C:\> Get-ChildItem 'C:\windows\*.exe' -Recurse | C:\Scripts\Get-ExeTargetMachine.ps1 | where { $_.TargetMachine -eq '' }
	
	Description
	-----------
	Gets information only for the EXE files of unknown type under C:\Windows and subfolders. This can be used to find 16-bit and other EXEs that don't conform to the portable executable standard
	
.EXAMPLE
	PS C:\> Get-ChildItem 'C:\Program Files\' -Recurse | C:\Scripts\Get-ExeTargetMachine.ps1 | Out-GridView
	
	Description
	-----------
	Finds every file in C:\Program Files and subfolders with a portable executable header, regardless of extension, and displays their names and Target Machine in a grid view
#>

#requires -Version 5.0

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
	[Alias('FullName')][String]$Path
)
BEGIN
{
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

	New-Variable -Name PEHeaderOffsetLocation -Option Constant -Value 0x3c
	New-Variable -Name PEHeaderOffsetLocationNumBytes -Option Constant -Value 2
	New-Variable -Name PESignatureNumBytes -Option Constant -Value 4
	New-Variable -Name MachineTypeNumBytes -Option Constant -Value 2

	class ExeInfo
	{
		[System.String]$TargetMachine
		[System.String]$Path
		[System.Boolean]$IsValid

		ExeInfo([String]$Path, [String]$TargetMachine, [System.String]$ErrorMessage)
		{
			$this.Path = $Path
			if ($ErrorMessage)
			{
				$this.TargetMachine = $ErrorMessage
				$this.IsValid = $false
			}
			else
			{
				$this.TargetMachine = $TargetMachine
				$this.IsValid = $true	
			}
		}
	}
}

PROCESS
{
	$Path = (Get-Item -Path $Path).FullName
	$ErrorMessage = ''
	try
	{
		$PEHeaderOffset = New-Object Byte[] $PEHeaderOffsetLocationNumBytes
		$PESignature = New-Object Byte[] $PESignatureNumBytes
		$MachineType = New-Object Byte[] $MachineTypeNumBytes
			
		Write-Verbose -Message ('Opening {0} for reading.' -f $Path)
		$FileStream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
			
		Write-Verbose -Message 'Moving to the header location expected to contain the location of the PE (portable executable) header.'
		$FileStream.Position = $PEHeaderOffsetLocation
		$BytesRead = $FileStream.Read($PEHeaderOffset, 0, $PEHeaderOffsetLocationNumBytes)
		if ($BytesRead -eq 0)
		{
			$ErrorMessage = 'Not a Windows executable (PE header location not found).'
		}

		if ([String]::IsNullOrEmpty($ErrorMessage))
		{
			Write-Verbose -Message 'Moving to the indicated position of the PE header.'
			$FileStream.Position = [System.BitConverter]::ToUInt16($PEHeaderOffset, 0)
			Write-Verbose -Message 'Reading the PE signature.'
			$BytesRead = $FileStream.Read($PESignature, 0, $PESignatureNumBytes)
			if ($BytesRead -ne $PESignatureNumBytes)
			{
				if ($IgnoreInvalidFiles)
				{
					return
				}
				$ErrorMessage = 'Corrupt or invalid format (PE signature size is incorrect)'
			}
		}

		if ([String]::IsNullOrEmpty($ErrorMessage))
		{
			Write-Verbose -Message 'Verifying the contents of the PE signature (must be characters "P" and "E" followed by two null characters).'
			if (-not($PESignature[0] -eq [Char]'P' -and $PESignature[1] -eq [Char]'E' -and $PESignature[2] -eq 0 -and $PESignature[3] -eq 0))
			{
				$ErrorMessage = '16-bit or not a Windows executable'
			}
		}

		if ([String]::IsNullOrEmpty($ErrorMessage))
		{
			Write-Verbose -Message 'Retrieving machine type.'
			$BytesRead = $FileStream.Read($MachineType, 0, $MachineTypeNumBytes)
			if ($BytesRead -ne $MachineTypeNumBytes)
			{
				$RawMachineType = 0x0
				$ErrorMessage = 'Possibly corrupted (machine type not correct size)'
			}
			else
			{
				$RawMachineType = [System.BitConverter]::ToUInt16($MachineType, 0)
			}
		}

		$TargetMachine = switch ($RawMachineType)
		{
			0x0 { 'Unknown/Any' }
			0x1d3 { 'Matsushita AM33' }
			0x8664	{ 'x64' }
			0x1c0 { 'ARM little endian' }
			0xaa64	{ 'ARM64 little endian' }
			0x1c4 { 'ARM Thumb-2 little endian' }
			0xebc { 'EFI byte code' }
			0x14c { 'x86' }
			0x200 { 'Intel Itanium 64 bit' }
			0x9041	{ 'Mitsubishi M32R little endian' }
			0x266 { 'MIPS16' }
			0x366 { 'MIPS with FPU' }
			0x466 { 'MIPS16 with FPU' }
			0x1f0 { 'PowerPC little endian' }
			0x1f1 { 'PowerPC with floating point support' }
			0x166 { 'MIPS little endian' }
			0x5032	{ 'RISC-V 32-bit address space' }
			0x5064	{ 'RISC-V 64-bit address space' }
			0x5128	{ 'RISC-V 128-bit address space' }
			0x1a2 { 'Hitachi SH3' }
			0x1a3 { 'Hitachi SH3 DSP' }
			0x1a6 { 'Hitachi SH4' }
			0x1a8 { 'Hitachi SH5' }
			0x1c2 { 'Thumb' }
			0x169 { 'MIPS little endian WCE v2' }
			default { 'Unknown type: {0:X0}' -f $RawMachineType }
		}

		[ExeInfo]::New($Path, $TargetMachine, $ErrorMessage)
	}
	catch
	{
		# the real purpose of the outer try/catch is to ensure that any file streams are properly closed. pass errors through
		Write-Error -Message ('Error processing {0}: {1} ' -f $Path, $_) -ErrorAction Continue
	}
	finally
	{
		if ($FileStream)
		{
			$FileStream.Close()
		}
	}
}
