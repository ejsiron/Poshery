[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)][String]$Path,
	[Parameter()][int]$StreamBlockSize = 64KB,

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
	$MinimumBlockSize = 16KB
	$MaximumBlockSize = 1GB

	if ($StreamBlockSize -lt $MinimumBlockSize)
	{
		$StreamBlockSize = $MinimumBlockSize
	}
	elseif ($StreamBlockSize -gt $MaximumBlockSize)
	{
		$StreamBlockSize = $MaximumBlockSize
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
	# built-in PowerShell regex is insufficient (ex: -match); does not see all matches
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
	$Matcher = [System.Text.RegularExpressions.Regex]::New($GuidPattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)

	class GUIDInfo
	{
		[Guid]$GUID
		[int]$Count
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
	$GUIDsInThisFile = New-Object -TypeName 'System.Collections.Generic.Dictionary`2[[System.Guid], [int]]'
	$BufferString = New-Object -TypeName 'System.Text.StringBuilder'
	$WhitespaceTracker = New-Object -TypeName 'System.Collections.ArrayList'
	$FileIndex = 0

	$ReaderStream = New-Object -TypeName System.IO.StreamReader -ArgumentList $StreamReaderParameters
	while (($RawChar = $ReaderStream.Read() -and $RawChar -ne -1))
	{
		$BufferString.Clear()
		$WhitespaceBlockStart = -1
		$WhitespaceBlockCounter = 0
		for ($i = 0; $i -lt $BytesRead; $i++, $FileIndex++)
		{
			if ($CharBuffer[$i] -match '\s')
			{
				if ($WhitespaceBlockCounter -eq 0)
				{
					# starting a new block of whitespace
					$WhitespaceBlockStart = $FileIndex
				}
				$WhitespaceBlockCounter++
			}
			else
			{
				$BufferString.Append($CharBuffer[$i]) | Out-Null
				if ($WhitespaceBlockCounter -gt 0)
				{
					$WhitespaceTracker.Add(@{Start = $WhitespaceBlockStart; Length = $WhitespaceBlockCounter}) | Out-Null
					$WhitespaceBlockCounter = 0
				}
			}
		}
		$NextOffset = $ReaderStream.BaseStream.Position + 1
		#$NextOffset
		#$BytesRead
		#$WhitespaceTracker
	}
}

end {Invoke-Command -ScriptBlock $CleanupBody}