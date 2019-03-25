# Simple Tester

Script for testing C programs with test scenarios.

# Requirements

* Windows PowerShell 5.1 - recommended, lower versions may work (not tested).
* GCC compiler
* (optional) Environment variable PATH set to GCC `bin` directory; otherwise, use the `-GccPath` parameter

# How to use

Put your test scenarios into the `tests` directory, each in separate directory with name of the test.
For example:

```
.\tests\basic_test\<test_files>
```

Open Windows PowerShell and run the script with `-SourcePath` parameter set to the source code file to test. The script will run all test in the `tests` directorty.
You can put source code file into the `src` directory. 

```
& Test.ps1 -SourcePath .\src\source.c
```

To run a specific test, use the `-TestsFilter` parameter with name of the test to run. 

```
& Test.ps1 -SourcePath .\src\source.c -TestsFilter "basic_test"
```

# FAQ

## The script fails due to execution policy

Change execution policy for current user to either `Unrestricted` or `RemoteSigned`.

Check the current execution policy with:
```
Get-ExecutionPolicy 
```

Run the PowerShell as an Administrator and change the execution policy to `Unrestricted` (prompts before running scripts) or `RemoteSigned` (requires remote scripts to be signed).
 
```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

Run the `Test.ps1` again, it should work.
If you are done with testing, revert the execution policy to the original setting with `Set-ExecutionPolicy`.

More info:
* [About Execution Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1)
* [Set-ExecutionPolicy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-5.1)

