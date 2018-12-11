# Poshery Snippets

Incomplete PowerShell snips useful in other scripts

## Snippet Information

Details about each snippet.

### TemporarilyOverridePSDefaults.ps1

Allows you to override the global PSDefaultParameterValues only for the duration of your script. The portion in the begin{} block safely stores the existing values. The end{} block restores the global.
Inside your script, you change the global in any way that you desire. You can override any individual setting. You can clear all of them with $PSDefaultParameterValues.Clear().
In order to ensure that the script functions as expected, do not throw an exception from the end{} block prior to resetting PSDefaultParameter. In general, it's bad practice to throw from end{} in general, but in this case it will prevent this script from performing its only duty.

### ValidateSuppliedPath.ps1

Allow the user to supply a desired $Path. If unspecified, fallback to a default that you supply. The script validates that the path exists, and stops if it does not. The final $Path variable is fully qualified, even if it was supplied as a relative path.