# Find-GUID

## SYNOPSIS

Find GUIDs (UUIDs) in a file.

## SYNTAX

```powershell
Find-GUID [-Path] <String> [-StreamBlockSize <Int32>] [-Encoding <String>] [<CommonParameters>]
```

## DESCRIPTION

Find GUIDs (UUIDs) in a file. This script returns a list of GUIDs found in the file along with the number of times each GUID was found.

It can find text-encoded GUIDs inside non-text encoded files although you may need to override the Encoding parameter.

## EXAMPLES

### Example 1: Find all GUIDs in a file

```powershell
Find-GUID -Path 'C:\Temp\MyFile.txt'
```

Find GUIDs in the file C:\Temp\MyFile.txt.

### Example 2: Find all GUIDs in a file using larger blocks of characters

```powershell
Find-GUID -Path 'C:\Temp\MyFile.txt' -StreamBlockSize 128KB
```

Find GUIDs in the file C:\Temp\MyFile.txt, reading 131,072 characters at a time.

### PARAMETERS

### -Path

The path to the file to scan for GUIDs.

```yaml
Type                         String
Required?                    true
Position?                    1
Accept pipeline input?       true
Accept wildcard characters?  true
```

### -StreamBlockSize

The size of the block of characters to read from the file at a time. The default is 65,536. This parameter is used to control memory usage. When increasing this value, be aware that it measures characters, not bytes.

```yaml
Type                         Int32
Required?                    false
Position?                    named
Default value                65536
Accept pipeline input?       false
Accept wildcard characters?  false
```

### -Encoding

The encoding of the file. The default is AutoDetect. The other options are ASCII, Unicode, UTF32, UTF7, and UTF8. Autodetect should work for typical text-encoded files.

```yaml
Type                         String
Required?                    false
Position?                    named
Default value                AutoDetect
Accept pipeline input?       false
Accept wildcard characters?  false
```

### NOTES

Author: Eric Siron
Version 1.0, June 16, 2024
Released under MIT license

## RELATED LINKS

- [Find-GUID](https://ejsiron.github.io/Poshery/Find-GUID)
