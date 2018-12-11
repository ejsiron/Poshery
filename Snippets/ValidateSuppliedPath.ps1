<#
Use this stub to select a supplied path or fall back to a default path, preferring a supplied path.
Stops the script if the selected path does not exist.
#>
[CmdletBinding()]
param
(
    [Parameter()][String]$Path = [String]::Empty
)
begin
{
    Set-StrictMode -Version Latest # good practice in general, but ensures that the script will stop on a null $Path
    $DefaultPath = '' # set default path
    if([String]::IsNullOrEmpty($Path)) { $Path = $DefaultPath }
    $Path = (Resolve-Path -Path $Path -ErrorAction Stop).Path
}

process
{
    # use $Path
}
end {}