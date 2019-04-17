param(
    [Parameter(Mandatory = $TRUE)][string]$SourcePath
,   [string]$TestsDirectory = "$PSScriptRoot\tests\"
,   [string]$RunsDirectory = "$PSScriptRoot\runs\"
,   [string]$BuildDirectory = "$PSScriptRoot\build\"
,   [string]$TestsFilter = "*"
,   [int]$Timeout = 1000
,   [int]$OutputLimit = 50
)


Function Test-Gcc 
{
    return (Get-Command "gcc.exe" -ErrorAction SilentlyContinue) -ne $NULL
}


Function Open-EnvironmentVariables 
{
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    if ($PSCmdlet.ShouldProcess("GCC bin directory", "Open environment variables configuration window?"))
    {
        Start-Process -FilePath rundll32 `
                      -ArgumentList sysdm.cpl,EditEnvironmentVariables `
                      -NoNewWindow `
                      -Wait

        Write-Host
        Write-Host "To apply changes, close and open new PowerShell console window." -ForegroundColor Yellow
    }
}


Enum MessageLevel 
{
    Info
    Success
    Error
}


Function Write-Message
{
    param(
        [Parameter(Position = 0)][String]$Message = ""
    ,   [Parameter(Position = 1)][MessageLevel]$Level
    )

    switch ($Level)
    {
        "Success" { $char = "+"; $color = "Green" }
        "Error" { $char = "-"; $color = "Red" }
        "Info" { $char = "*"; $color = "Yellow" }
    }

    if ($char) 
    {
        Write-Host "[$char] $Message"  -ForegroundColor $color
    }
    else
    {
        Write-Host $Message
    }
}


Function Compare-Output 
{
    <#
        .SYNOPSIS
        Compares contents of the test output file with contents of the expected file

        .DESCRIPTION
        Possible results:
        PASSED - contents are equal, test passed.
        CHECK - contents are not equal but output file is not empty, contents and diff of both files are listed and should be checked manually.
        FAILED - the actual output file is empty, but output was expected.
    #>

    param(
        [Parameter(Mandatory = $TRUE)][string]$OutputPath
    ,   [Parameter(Mandatory = $TRUE)][string]$ExpectedPath 
    ,   [int]$Limit
    )
    
    if (-not (Test-Path $ExpectedPath))
    {
        Write-Error "Expected file not found." -ForegroundColor Red
        Return
    }
    
    if (-not (Test-Path $OutputPath)) 
    {
        Write-Error "Error: Output file not found." -ForegroundColor Red
        Return
    }

    $output = Get-Content $OutputPath | % { $_.TrimEnd() }
    $output = if ($output) { $output } else { [String]::Empty }
    
    $expected = Get-Content $ExpectedPath | % { $_.TrimEnd() }
    $expected = if ($expected) { $expected } else { [String]::Empty }

    $outputCount = $output.Count
    $outputLimit = [System.Math]::Max($Limit, $expected.Count)
    
    $truncated = ($outputCount -gt $outputLimit)
    $output = $output | Select-Object -First $outputLimit

    $compare = Compare-Object -ReferenceObject $expected -DifferenceObject $output -CaseSensitive

    if ($compare) {
        Write-Message "FAILED" -Level Error
        if ($output) {

            $output `
            | % { } { [PSCustomObject]@{ "Actual output"   = $_ } } { if ($truncated) { "   ...truncated $($outputCount - $outputLimit) lines" } } | Format-Table 
            
            $expected `
            | % { [PSCustomObject]@{ "Expected output" = $_ } } | Format-Table
            
            $compare `
            | Format-Table @{ Label = "Comparison" ; Expression = { $_.InputObject } }, SideIndicator
        }
        # else there was no output, we do not write out anything
    }
    else {
        Write-Message "PASSED" -Level Success
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

    
    Write-Message
    Write-Message "Executing test case $Test" -Level Info

    $testDirectory = Join-Path $TestsDirectory -ChildPath $Test

    if (-not (Test-Path $testDirectory))
    {
        Write-Message "Test directory not found, test ignored" -Level Error
        Return
    }

    $inputFilePath    = Join-Path $testDirectory -ChildPath "input.txt"
    $expectedFilePath = Join-Path $testDirectory -ChildPath "expected.txt"

    if ((-not (Test-Path $inputFilePath)) -or (-not (Test-Path $expectedFilePath))) 
    {
        Write-Message "Test files not found, test ignored" -Level Error
        Return
    }

    $runDirectory = Join-Path (Join-Path $OutputDirectory -ChildPath $Run) -ChildPath $Test
    
    # Delete previous run
    if (Test-Path $runDirectory)
    {
        Remove-Item $runDirectory -Recurse
    }
    New-Item $runDirectory -ItemType Directory -ErrorAction Ignore | Out-Null

    Copy-item "$testDirectory\*" -Exclude "expected.txt" -Destination $runDirectory

    $outputFilePath = Join-Path $runDirectory -ChildPath "output.txt"
    $errorFilePath  = Join-Path $runDirectory -ChildPath "error.txt"


    $process = Start-Process -FilePath $ExecutablePath `
                             -WorkingDirectory $runDirectory `
                             -RedirectStandardInput $inputFilePath `
                             -RedirectStandardOutput $outputFilePath `
                             -RedirectStandardError $errorFilePath `
                             -NoNewWindow `
                             -PassThru
                          
    $handle = $process.Handle # cache the process handle, otherwise the WaitForExit would not work

    $exited = $process.WaitForExit($Timeout)
    if ($exited) 
    {
        if ($process.ExitCode -eq 0) 
        {
            Write-Message "Execution successful" -Level Success
        }
        else 
        {
            Write-Message "Execution failed with exit code $($process.ExitCode)" -Level Error
            Get-Content $errorFilePath | % { [PSCustomObject]@{ "Error output" = $_ } } | Format-Table
        }
    }
    else
    {
        $process.Kill()
        if ($process.ExitCode -ne 0) 
        {
            Write-Message "Execution failed with exit code $($process.ExitCode)" -Level Error
            Get-Content $errorFilePath | % { [PSCustomObject]@{ "Error output" = $_ } } | Format-Table
        }
        else
        {
            Write-Message "Execution timed out" -Level Error
        }
    }

    Copy-Item $ExecutablePath -Destination (Join-Path $runDirectory -ChildPath "bin.exe")

    Compare-Output -OutputPath $outputFilePath -ExpectedPath $expectedFilePath -Limit $OutputLimit
}



# Main script body

if (-not (Test-Path $SourcePath)) 
{
    Write-Host "Input file not found: $SourcePath" -ForegroundColor Red
    Return
}

$run = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)

New-Item $BuildDirectory -ItemType Directory -ErrorAction Ignore | Out-Null
$ExecutablePath = Join-Path $BuildDirectory -ChildPath "$($run).exe"

if (Test-Path $ExecutablePath) 
{
    Remove-Item $ExecutablePath -ErrorAction Stop
} 

$filename = [System.IO.Path]::GetFileName("$SourcePath")

Write-Message "$filename"
Write-Message "Compiling..." -Level Info

# Check if the GCC is available. If not, ask to open Environment Varaibles settings window to set it in the PATH
if (-not (Test-Gcc))
{
    Write-Host "Compiler not found" -ForegroundColor Red
    Write-Host "Unable to find gcc.exe in your PATH. Set up path to the GCC bin directory to your PATH environmnet variable." -Foreground Red
    Write-Host "Set GCC bin directory to the PATH variable and restart PowerShell." -ForegroundColor Red
    Open-EnvironmentVariables -Confirm
}

if (Test-Gcc)
{
    # Compile source file with GCC and supply includes in case they are missing in the soruce file.
    # Example: gcc src.c -o src.exe -include "stdio.h" -include "string.h" -include "stdlib.h"
    & gcc.exe $SourcePath -o $ExecutablePath -include "stdio.h" -include "string.h" -include "stdlib.h"
}
else 
{
    Write-Host "Unable to find gcc.exe in your PATH." -ForegroundColor Red
}

if (Test-Path $ExecutablePath)
{
    Write-Message "Success" -Level Success

    Write-Message "Running tests" -Level Info
    Write-Message

    Get-ChildItem $TestsDirectory -Filter $TestsFilter -Directory `
    | Sort-Object -Property Name `
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
    Write-Message "Compilation failed" -Level Error
}
