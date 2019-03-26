param(
    [Parameter(Mandatory = $TRUE)][string]$SourcePath
,   [string]$TestsDirectory = "$PSScriptRoot\tests\"
,   [string]$RunsDirectory = "$PSScriptRoot\runs\"
,   [string]$BuildDirectory = "$PSScriptRoot\build\"
,   [string]$GccPath = "gcc"
,   [string]$TestsFilter = "*"
,   [int]$Timeout = 5000
)

Function Compare-Output 
{
    <#
        .SYNOPSIS
        Compares contents of the test output file with contents of the expected file

        .DESCRIPTION
        Possible results:
        PASSED - contents are equal, test passed.
        CHECK - contents are not equal but output file is non-empty, contents and diff of both files are listed and should be checked manually.
        FAILED - the test output file is empty, but output was expected.
    #>

    param(
        [Parameter(Mandatory = $TRUE)][string]$OutputPath
    ,   [Parameter(Mandatory = $TRUE)][string]$ExpectedPath 
    )
    
    if (-not (Test-Path $ExpectedPath))
    {
        Write-Error "Expected file not found." -ForegroundColor Red
        Return
    }
    
    if (-not (Test-Path $OutputPath)) 
    {
        Write-Host "Error: Output file not found." -ForegroundColor Red
        Return
    }

    $output = Get-Content $OutputPath | % { $_.TrimEnd() }
    $output = if ($output) { $output } else { [String]::Empty }
    
    $expected = Get-Content $ExpectedPath | % { $_.TrimEnd() }
    $expected = if ($expected) { $expected } else { [String]::Empty }

    $compare = Compare-Object -ReferenceObject $expected -DifferenceObject $output -CaseSensitive
        
    if ($compare) {
        if ($output) {
            Write-Host "CHECK" -ForegroundColor Gray
            Write-Host "##### output #####"
            $output | Write-Host
            Write-Host "---- expected ----"
            $expected | Write-Host
            Write-Host "---- compared ----"
            $compare | Format-Table
            Write-Host "##################"
        }
        else {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "##### output #####"
            $output | Write-Host
            Write-Host "---- expected ----"
            $expected | Write-Host
            Write-Host "##################"
        }
    }
    else {
        Write-Host "PASSED" -ForegroundColor Green
    }
}

Function Test-Run
{
    <#
        .SYNOPSIS
        Executes a test run with executable, sets the working directory for the executable to the test directory and redirects output streams to files in |OutputDirectory|.
        The output is then compared to the expected output with the Compare-Output function.

        .DESCRIPTION
        Displays message about execution status:
        OK = process exit code was 0.
        FAILED - process terminated unsuccessfully.
    #>

    param( 
        [Parameter(Mandatory = $TRUE)][string]$Run
    ,   [Parameter(Mandatory = $TRUE)][string]$ExecutablePath
    ,   [Parameter(Mandatory = $TRUE)][string]$Test
    ,   [string]$TestsDirectory = "$PSScriptRoot\tests\"
    ,   [string]$OutputDirectory = "$PSScriptRoot\runs\"
    ,   [int]$Timeout
    )

    
    Write-Host 
    Write-Host $Test -ForegroundColor Yellow

    $testWorkingDirectory = Join-Path $TestsDirectory -ChildPath $Test

    if (-not (Test-Path $testWorkingDirectory))
    {
        Write-Host "Test directory not found, test ignored"
        Return
    }

    $runOutputDir = Join-Path $OutputDirectory -ChildPath $Run

    if (-not (Test-Path $runOutputDir))
    {
        New-Item $runOutputDir -ItemType Directory -ErrorAction Ignore | Out-Null
    }

    $inputFilePath    = Join-Path $testWorkingDirectory -ChildPath "input.txt"
    $expectedFilePath = Join-Path $testWorkingDirectory -ChildPath "expected.txt"

    if ((-not (Test-Path $inputFilePath)) -or (-not (Test-Path $expectedFilePath))) 
    {
        Write-Host "Test files not found, test ignored"
        Return
    }

    $outputDir = Join-Path $runOutputDir -ChildPath $Test

    $outputFilePath = Join-Path $outputDir -ChildPath "output.txt"
    $errorFilePath  = Join-Path $outputDir -ChildPath "error.txt"

    Remove-Item $outputDir -Recurse -ErrorAction SilentlyContinue | Out-Null
    New-Item $outputDir -ItemType Directory | Out-Null

    Write-Host "Execution: " -NoNewline

    $process = Start-Process -FilePath $ExecutablePath `
                             -WorkingDirectory $testWorkingDirectory `
                             -RedirectStandardInput $inputFilePath `
                             -RedirectStandardOutput $outputFilePath `
                             -RedirectStandardError $errorFilePath `
                             -NoNewWindow `
                             -PassThru
                          
    $handle = $process.Handle # cache the process handle, otherwise the WaitForExit would not work

    $exited = $process.WaitForExit($Timeout)
    if ($exited) 
    {
        if ($process.ExitCode -eq 0) {
            Write-Host "OK" -ForegroundColor Green
        }
        else {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor Red 
        }
    }
    else
    {
        Write-Host "TIMEOUT" -ForegroundColor Red
    }

    Write-Host "Test result: " -NoNewline
    Compare-Output -OutputPath $outputFilePath -ExpectedPath $expectedFilePath
}



# Main script body

if (-not (Test-Path $SourcePath)) {
    Write-Host "Input file not found: $SourcePath" -ForegroundColor Red
    Return
}

$run = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)

New-Item $BuildDirectory -ItemType Directory -ErrorAction Ignore | Out-Null
$ExecutablePath = Join-Path $BuildDirectory -ChildPath "$($run).exe"

if (Test-Path $ExecutablePath) 
{
    Remove-Item $ExecutablePath 
} 


Write-Host "Compiling $($SourcePath): " -NoNewline

# Compile source file with GCC and supply includes in case they are missing in the soruce file.
# Example: gcc src.c -o src.exe -include "stdio.h" -include "string.h" -include "stdlib.h"
& $GccPath $SourcePath -o $ExecutablePath -include "stdio.h" -include "string.h" -include "stdlib.h"

if (Test-Path $ExecutablePath) 
{
    Write-Host "OK" -ForegroundColor Green
    Write-Host "Path: $ExecutablePath"
    Write-Host "Running tests:"

    Get-ChildItem $TestsDirectory -Filter $TestsFilter -Directory `
    | % { 
            Test-Run -Run $run `
                     -Test $_.Name `
                     -TestsDirectory $TestsDirectory `
                     -ExecutablePath $ExecutablePath `
                     -Timeout $Timeout
        }
}
else 
{
    Write-Host "Compilation failed" -ForegroundColor Red
}
