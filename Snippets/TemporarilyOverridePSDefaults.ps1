<#
Use this stub to override the global $PSDefaultParameterValues for the duration of your script.
#>
begin
{
	$ExistingDefaultParams = $PSDefaultParameterValues.Clone()
	# do other init stuff
}
process
{
	# do process stuff
}
end
{
	# do other cleanup stuff; DO NOT THROW UNCAUGHT EXCEPTIONS
	$PSDefaultParameterValues.Clear()
	foreach ($ParamKey in $ExistingDefaultParams.Keys)
	{
		$PSDefaultParameterValues.Add($ParamKey, $ExistingDefaultParams[$ParamKey])
	}
}
