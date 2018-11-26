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
	# do other cleanup stuff
	$PSDefaultParameterValues.Clear()
	foreach ($ParamKey in $ExistingDefaultParams.Keys)
	{
		$PSDefaultParameterValues.Add($ParamKey, $ExistingDefaultParams[$ParamKey])
	}
}
