# Simple C Program Tester

Simple testing utility for C programs written in PowerShell.

Overview of the testing procedure with the `Test.ps1` script:

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


# Requirements

* Windows PowerShell 5.1 - recommended, lower versions may work (not tested)
* GNU GCC compiler
* (optional) Environment variable PATH set to GCC `bin` directory; otherwise, use the `-GccPath` parameter with path to the `gcc.exe`

# How to use it

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

Open Windows PowerShell console and run the script with `-SourcePath` parameter set to the source code file to test. The script will run all test scenarios in the `tests` directory.
You can put source code file into the `src` directory. 

```
& .\Test.ps1 -SourcePath .\src\source.c
```

To run a specific test, use the `-TestsFilter` parameter with name of the test to run. 

```
& .\Test.ps1 -SourcePath .\src\source.c -TestsFilter "basic_test"
```


# FAQ

## The script fails because it is not digitally signed.

Change the execution policy for current user to either `RemoteSigned` or `Unrestricted`.

Check the current execution policy settings with:
```
Get-ExecutionPolicy -List
```

Run the PowerShell as an Administrator and change the execution policy for `CurrentUser` to `Unrestricted` (prompts before running scripts) or `RemoteSigned` (requires remote scripts to be signed).
 
```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Run the `Test.ps1` again, it should work.
If you are done with testing, revert the execution policy to the original setting with `Set-ExecutionPolicy`.

More info:
* [About Execution Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1)
* [Set-ExecutionPolicy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-5.1)

