# Simple C Program Tester

Simple testing utility for C programs. 

# Table of contents

1) [Testing procedure overview](#testing-procedure-overview)
2) [General usage](#general-usage)
3) [Windows](#windows)
4) [Linux](#linux)
6) [Something is not working](#something-is-not-working)
5) [FAQ](#faq)

# Testing procedure overview

1. Compile given source code file with GCC compiler and print out compiler output in case of errors or warnings. 
2. If the compilation is successful, print out `OK` message. The executable is located in the `build` directory.
3. For each test scenario located in the `tests` directory:
    1. Create working directory in the `runs` directory with the template `runs\<test_run>\<test_name>\` where `<test_run>` is name of the source code file. 
    1. Copy test files to the working directory, except `expected.txt`. 
    1. Execute the program in the test working directory with input read from a `input.txt` file and its output redirected to `output.txt` file.
    2. Compare program output in `output.txt` with the expected output in `expected.txt` in the test directory.
    3. If outputs match, print out `PASSED` message.
    4. If outputs do not match, print out `CHECK` message (manual check required) and actual output and expected output together with comparison table.
    5. If program had no output but it was expected, print out `FAILED` message.
4. Each test scenario must be completed within the 1000 millisecond timeout (default, can be changed).


# General usage

Clone the repository, or download it as a [ZIP file](https://github.com/martinkonopka/simple-c-program-tester/archive/master.zip).

Put your test scenarios into the `tests` directory, each in separate directory with name of the scenario. Each scenario must include these files:
* `input.txt` which will be redirected to standard input, and
* `expected.txt` which contains expected output of the program.

Template:

```
.\tests\<test_name>\<test_files>
```

For example:

```
tests\
├── basic_test\
│   ├── input.txt
│   └── expected.txt
└── hard_test\
    ├── input.txt
    └── expected.txt
```

# Windows

## Requirements

* Windows PowerShell 5.1 - recommended, lower versions have not been tested
* GCC (compiler)
* Environment variable `PATH` set to the GCC `bin` directory

## How to run tests

Open Windows PowerShell console and run the script with `-SourcePath` parameter set to the source code file to test. The script will build the source file with GCC compiler and run all test scenarios in the `tests` directory.
You can put source code file into the `src` directory. 

```
& .\Test.ps1 -SourcePath .\src\source.c
```

To run a specific test, use the `-TestsFilter` parameter with name of the test to run. 

```
& .\Test.ps1 -SourcePath .\src\source.c -TestsFilter "basic_test"
```
# Linux

## Requirements

* GCC
* (optional) rsync

## How to run tests

``` bash
# To run all tests
./Test.sh ./src/source.c

# Display help
./Test.sh --help

# Run tests with filter
./Test.sh ./src/source.c -f "your filter"
```

# Something is not working

Please if you find an error or bug, create issue, so it can be fixed.
Instructions:
1) Go [here](https://github.com/martinkonopka/simple-c-program-tester/issues)
2) Click `New issue` in top right corner
3) Fill out title and description
4) Do not assign any tags!

# FAQ

## [Windows] The script fails because it is not digitally signed.

Change the execution policy for current user to either `RemoteSigned` or `Unrestricted`.

Check the current execution policy settings with:
```
Get-ExecutionPolicy -List
```

Run the PowerShell as an Administrator and change the execution policy for `CurrentUser` to `Unrestricted` (prompts before running scripts) or `RemoteSigned` (requires remote scripts to be signed).
 
```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Run `Test.ps1` again, it should work.
If you are done with testing, revert the execution policy to the original setting with `Set-ExecutionPolicy`.

More info:
* [About Execution Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1)
* [Set-ExecutionPolicy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-5.1)

## [Windows] Compilation fails because GCC is not set in the PATH.

You have set path to the GCC `bin` directory as an entry to the `PATH` evnironment variable. Doing this allows you to call `gcc.exe` (and other executables from the GCC directory) in any directory without using the absolute path.
1. Download MinGW distribution of the GCC compiler. By default, it is installed in `C:\MinGW\` directory.
2. Open `Advanced System Settings` using the Windows search.   
3. Go to the `Advanced` tab.
4. Press the `Evironment Variables...` button.
5. Select the `PATH` variable in the list of the user variables and press `Edit...` or create a new one.
6. Add new entry with path to the GCC bin directory to the list of entries for PATH, for example `C:\MinGW\bin\`.
7. Save all changes, close all the windows open in these steps.
8. Test the new setting by opening a new command line window and running `gcc.exe`. You should see the output of the GCC compiler. 
9. Reopen PowerShell console to update environment variables. 


## Can it run on Mac?

It can! Mac is POSIX-compliant (Unix-like), so try following [Linux](#linux) instructions. If that is not working, please report it. Instructions [here](#something-is-not-working).
Last resort solution is trying PowerShell (it is not tested though). Although it is native to Microsoft Windows, it is available for MacOS too, see [PowerShell repository](https://github.com/PowerShell/PowerShell) for instructions. You can also run the tests manually :-)

