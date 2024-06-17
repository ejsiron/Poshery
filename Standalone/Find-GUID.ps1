<#
.SYNOPSIS
	Find GUIDs (UUIDs) in a file.
.DESCRIPTION
	Find GUIDs (UUIDs) in a file. This script returns a list of GUIDs found in the file along with the number of times each GUID was found.
	It can find text-encoded GUIDs inside non-text encoded files although you may need to override the Encoding parameter.
.PARAMETER Path
	The path to the file to scan for GUIDs.
.PARAMETER StreamBlockSize
	The size of the block of characters to read from the file at a time. The default is 65,536. This parameter is used to control memory usage. When increasing this value, be aware that it measures characters, not bytes.
.PARAMETER Encoding
	The encoding of the file. The default is AutoDetect. The other options are ASCII, Unicode, UTF32, UTF7, and UTF8. Autodetect should work for typical text-encoded files.
.EXAMPLE
	Find-GUID -Path 'C:\Temp\MyFile.txt'
	Find GUID in the file C:\Temp\MyFile.txt.
.EXAMPLE
	Find-GUID -Path 'C:\Temp\MyFile.txt' -StreamBlockSize 128KB
	Find GUID in the file C:\Temp\MyFile.txt, reading 131,072 characters at a time.
.NOTES
	Author: Eric Siron
	Version 1.0, June 16, 2024
	Released under MIT license
.LINK
	https://ejsiron.github.io/Poshery/Find-GUID
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)][String]$Path,
	[Parameter()][ValidateRange(4KB, 1GB)][int]$StreamBlockSize = 64KB,

	[ValidateSet(
		'AutoDetect',
		'ASCII',
		'Unicode',
		'UTF32',
		'UTF7',
		'UTF8'
	)]
	[Parameter()][String]$Encoding = 'AutoDetect'
)

begin
{
	$ErrorActionPreference = 'Stop'
	Set-StrictMode -Version Latest

	# $PreviousBlockCarryOverMaxChars is the maximum number of non-whitespace characters that can be carried over from the previously-scanned block.
	# It helps to ensure that GUIDs that span block boundaries are not missed. The size was chosen arbitrarily, but should be more than sufficient
	# to capture any block-spanning GUID in a typical text-encoded file.
	$PreviousBlockCarryOverMaxChars = 64
	if ($PreviousBlockCarryOverMaxChars -ge $StreamBlockSize)
	{
		# this is a non-sensical value and might cause undefined behavior
		$PreviousBlockCarryOverMaxChars = $StreamBlockSize - 1
	}

	$ReaderStream = $null
	$StreamReaderParameters = @(, $Path)
	switch ($Encoding)
	{
		'ASCII'
		{
			$StreamReaderParameters += [System.Text.Encoding]::ASCII
		}
		'Unicode'
		{
			$StreamReaderParameters += [System.Text.Encoding]::Unicode
		}
		'UTF32'
		{
			$StreamReaderParameters += [System.Text.Encoding]::UTF32
		}
		'UTF7'
		{
			$StreamReaderParameters += [System.Text.Encoding]::UTF7
		}
		'UTF8'
		{
			$StreamReaderParameters += [System.Text.Encoding]::UTF8
		}
		default
		{
			$StreamReaderParameters += $true
		}
	}

	$GuidPattern = '([0-9A-Fa-f]{8})(?:(?:(?:[,-])?(?:0?x)?([0-9A-Fa-f]{4})){2})(?:(?:(?:[,-])?(?:0?x)?([0-9A-Fa-f]{2})){2})(?:(?:(?:[,-])?(?:0?x)?([0-9A-Fa-f]{2})){6})'
	# format 1: A864F394-C94E-4727-8EEB-89223E3096AF
	# format 2: 0xa864f394,0xc94e,0x4727,0x8e,0xeb,0x89,0x22,0x3e,0x30,0x96,0xaf
	# format 3: 0xa864f394,0xc94e,0x4727,{0x8e,0xeb,0x89,0x22,0x3e,0x30,0x96,0xaf}
	# this pattern assumes all whitespace (including line breaks) have been removed from the sample text
	#
	# each match represents a found GUID in the text
	# each match has 5 numbered groups. groups 2-4 have captures of their own
	# group 0: the entire match, as captured (A864F394-C94E-4727-8EEB-89223E3096AF or 0xa864f394,0xc94e,0x4727,0x8e,0xeb,0x89,0x22,0x3e,0x30,0x96,0xaf or {0xa864f394,0xc94e,0x4727,{0x8e,0xeb,0x89,0x22,0x3e,0x30,0x96,0xaf}})
	# group 1:
	# 	UUID field: time_low, characters 1-8 of the GUID
	# 		can retrieve from the "Value" property of the match object
	# 		[->A864F394<-]-C94E-4727-8EEB-89223E3096AF
	# 		[->0xa864f394<-],0xc94e,0x4727,0x8e,0xeb,0x89,0x22,0x3e,0x30,0x96,0xaf
	# group 2:
	# 		UUID fields: time_mid and time_hi_and_version, characters 9 through 12 (time_mid) and 13 through 16 (time_hi_and_version)
	# 		can retrieve from the "Captures" property of the match object ("Value" only contains time_hi_and_version)
	# 		A864F394-[->C94E-4727<-]-8EEB-89223E3096AF										:Captures[0].Value = C94E, Captures[1].Value = 4727
	# 		0xa864f394,[->0xc94e,0x4727<-],0x8e,0xeb,0x89,0x22,0x3e,0x30,0x96,0xaf	:Captures[0].Value = C94E, Captures[1].Value = 4727
	# group 3:
	# 		UUID fields: clock_seq_hi_and_reserved and clock_seq_low, characters 17 and 18 (clock_seq_hi_and_reserved) and characters 19 and 20 (clock_seq_low)
	# 		can retrieve from the "Captures" property of the match object ("Value" only contains clock_seq_hi_and_reserved)
	# 		A864F394-C94E-4727-[->8EEB<-]-89223E3096AF										:Captures[0].Value = 8E, Captures[1].Value = EB
	# 		0xa864f394,0xc94e,0x4727,[->0x8e,0xeb[<-],0x89,0x22,0x3e,0x30,0x96,0xaf	:Captures[0].Value = 8E, Captures[1].Value = EB
	# group 4:
	# 		UUID field: node, characters 21 through 36
	# 		can retrieve from the "Captures" property of the match object ("Value" only captures the final octet pair)
	#		A864F394-C94E-4727-8EEB-[->89223E3096AF<-]										:Captures[0].Value through Captures[5].Value contains octet pairs in order
	#		0xa864f394,0xc94e,0x4727,0x8e,0xeb,[->0x89,0x22,0x3e,0x30,0x96,0xaf<-]	:Captures[0].Value through Captures[5].Value contains octet pairs in order
	$GuidMatcher = [System.Text.RegularExpressions.Regex]::New($GuidPattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)
	$WSMatcher = [System.Text.RegularExpressions.Regex]::New('\s', [System.Text.RegularExpressions.RegexOptions]::Compiled)

	class GUIDInfo
	{
		[Guid]$GUID
		[int]$Count = 0
	}

	$CleanupBody = {
		if ($null -ne $ReaderStream)
		{
			$ReaderStream.Close()
		}
	}
}

process
{
	if (-not(Test-Path -Path $Path -PathType Leaf))
	{
		Write-Error -Message ('File "{0}" does not exist.' -f $Path)
	}

	trap
	{
		Invoke-Command -ScriptBlock $CleanupBody
		throw $_
	}
	$GUIDsInThisFile = New-Object -TypeName 'System.Collections.Generic.Dictionary`2[[System.Guid], [GuidInfo]]'
	$CharBuffer = New-Object -TypeName 'char[]' -ArgumentList $StreamBlockSize
	$ProcessSB = New-Object -TypeName 'System.Text.StringBuilder'
	$ReaderStream = New-Object -TypeName System.IO.StreamReader -ArgumentList $StreamReaderParameters
	while ($CharsRead = $ReaderStream.Read($CharBuffer, 0, $StreamBlockSize))
	{
		$ProcessSB.Append($CharBuffer, 0, $CharsRead) | Out-Null
		$ProcessString = $WSMatcher.Replace($ProcessSB.ToString(), '')
		$GUIDMatches = $GuidMatcher.Matches($ProcessString)
		:GUIDWalker foreach ($FoundGUID in $GUIDMatches)
		{
			$ThisGUID = $null
			try
			{
				$ThisGUID = [System.Guid]::Parse($FoundGUID.Value)	# works for the first format, which should be the overwhelming majority
			}
			catch
			{
				$GUIDBuilder = New-Object -TypeName 'System.Text.StringBuilder'
				$GUIDBuilder.Append($FoundGUID.Groups[1].Value) | Out-Null
				$GUIDBuilder.Append('-') | Out-Null
				$GUIDBuilder.Append($FoundGUID.Groups[2].Captures[0].Value) | Out-Null
				$GUIDBuilder.Append('-') | Out-Null
				$GUIDBuilder.Append($FoundGUID.Groups[2].Captures[1].Value) | Out-Null
				$GUIDBuilder.Append('-') | Out-Null
				0..1 | ForEach-Object -Process {$GUIDBuilder.Append($FoundGUID.Groups[3].Captures[$_].Value) } | Out-Null
				$GUIDBuilder.Append('-') | Out-Null
				0..5 | ForEach-Object -Process {$GUIDBuilder.Append($FoundGUID.Groups[4].Captures[$_].Value) } | Out-Null
				try
				{
					$ThisGUID = [System.Guid]::Parse($GUIDBuilder.ToString())
				}
				catch
				{
					Write-Warning -Message ('File data "{0}" appeared valid, but the GUID parser rejected it: {0}' -f $FoundGUID.Value, $_)
					continue GUIDWalker
				}
			}
			if (-not $GUIDsInThisFile.ContainsKey($ThisGUID))
			{
				$GUIDsInThisFile[$ThisGUID] = [GUIDInfo]::new()
				$GUIDsInThisFile[$ThisGUID].GUID = $ThisGUID
			}
			$GUIDsInThisFile[$ThisGUID].Count++
		}
		$ProcessSB.Clear() | Out-Null
		$LastUsedCharOffset = 0
		if ($GUIDMatches.Count)
		{
			$LastUsedCharOffset = $GUIDMatches[($GUIDMatches.Count - 1)].Groups[4].Captures[5].Index + $GUIDMatches[($GUIDMatches.Count - 1)].Groups[4].Captures[5].Length
		}
		if ($ProcessString.Length - $LastUsedCharOffset -gt $PreviousBlockCarryOverMaxChars)
		{
			$LastUsedCharOffset = $ProcessString.Length - $PreviousBlockCarryOverMaxChars
		}
		$ProcessSB.Append($ProcessString.ToCharArray($LastUsedCharOffset, $ProcessString.Length - $LastUsedCharOffset)) | Out-Null
	}
	$GUIDsInThisFile.Values

}

end {Invoke-Command -ScriptBlock $CleanupBody}