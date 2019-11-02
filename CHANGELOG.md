# Change Log for Poshery

This file contains a log of changes made to the individual scripts.

## Get-ExeTargetMachine

History for Get-ExeTargetMachine

### 2.0

* **Breaking change**: All parameters except *Path* removed
* **Breaking change**: Outputs a custom object for each file, see help
* **Breaking change**: Access errors use the error stream as usual. All format errors and warnings written into the output object. Use a Where filter to pare down the results (see help)
* Online help added
* Comment-based help corrections

### 1.0.2

* Moved to GitHub for versioning
* Modified for MIT license
* Updated target machine list
* Changed positional parameters to named

### 1.0.1 (not on GitHub)

* Modified non-EXE handling to return as soon as further processing is unnecessary

### 1.0 (not on GitHub)

* Version 1.0 December 10, 2014: Initial release
