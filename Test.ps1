param(
    [Parameter(Mandatory = $TRUE)][string]$SourcePath
,   [string]$TestsPath = "$PSScriptRoot\tests\"
,   [string]$RunsDirectoryPath = "$PSScriptRoot\runs\"
,   [string]$BuildDirectoryPath = "$PSScriptRoot\build\"
,   [string]$TestsDirectory = "$PSScriptRoot\tests\"
,   [string]$RunsDirectory = "$PSScriptRoot\runs\"
,   [string]$BuildDirectory = "$PSScriptRoot\build\"
,   [switch]$LogMemAlloc
,   [string]$MemAllocLogPath = "memlog.csv"
,   [string]$GccPath = "gcc.exe"
,   [int]$MemAllocAcceptedLimit = 8
,   [string]$TestsFilter = "*"
,   [int]$Timeout = 1000
,   [int]$OutputLimit = 50
)


Function Resolve-GccPath 
{
    param([string]$GccPath)

    @(
        (Resolve-Path $GccPath -ErrorAction SilentlyContinue).Path
    ,   (Get-Command "gcc.exe" -ErrorAction SilentlyContinue).Source
    ) `
    | Where-Object -FilterScript { $_ } `
    | Select-Object -First 1
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
        "Success" { $char = "+"; $color = "Green"  }
        "Error"   { $char = "-"; $color = "Red"    }
        "Info"    { $char = "*"; $color = "Yellow" }
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


Function Compare-TestOutput 
{
    <#
        .SYNOPSIS
        Compares contents of the actual output file with contents of the expected file for the test

        .DESCRIPTION
        Possible results:
        PASSED - contents are equal, test passed.
        CHECK - contents are not equal but output file is not empty, contents and diff of both files are listed and should be checked manually.
        FAILED - the actual output file is empty, but output was expected.
    #>

    param(
        [Parameter(Mandatory = $TRUE, ValueFromPipeline = $TRUE)][PSObject]$InputObject
    ,   [Parameter(Mandatory = $TRUE, ValueFromPipelineByPropertyName = $TRUE)][string]$ActualOutputPath
    ,   [Parameter(Mandatory = $TRUE, ValueFromPipelineByPropertyName = $TRUE)][string]$ExpectedOutputPath
    ,   [int]$Limit
    )

    process 
    {
        if (-not (Test-Path $ExpectedOutputPath))
        {
            Write-Error "Test error: Expected file not found." -ForegroundColor Red
            return $InputObject
        }
        
        if (-not (Test-Path $ActualOutputPath)) 
        {
            Write-Error "Test error: Output file not found." -ForegroundColor Red
            return $InputObject
        }

        $actual = Get-Content $ActualOutputPath | % { $_.TrimEnd() }
        $actual = if ($actual) { $actual } else { [String]::Empty }
        
        $expected = Get-Content $ExpectedOutputPath | % { $_.TrimEnd() }
        $expected = if ($expected) { $expected } else { [String]::Empty }

        $actualLinesCount = $actual.Count
        $outputLimit = [System.Math]::Max($Limit, $expected.Count)
        
        $truncated = ($actualLinesCount -gt $outputLimit)
        $actual = $actual | Select-Object -First $outputLimit

        $comparison = Compare-Object -ReferenceObject $expected -DifferenceObject $actual -CaseSensitive

        $outputs = [PSCustomObject]@{
            "Actual" = $actual
        ;   "Expected" = $expected
        ;   "Comparison" = $comparison
        ;   "Truncated" = [Math]::Max(0, ($actualLinesCount - $outputLimit))
        }

        return $InputObject `
               | Add-Member -MemberType NoteProperty -Name "IsSuccess" -Value (-not $comparison) -PassThru `
               | Add-Member -MemberType NoteProperty -Name "Outputs" -Value $outputs -PassThru `
    }
}


Function Write-TestResult 
{ 
    param(
        [PSObject][Parameter(ValueFromPipeline=$TRUE)]$Result
    ,   [switch]$PassThru
    )

    process 
    {
        if ($Result.IsSuccess)
        {
            Write-Message "PASSED" -Level Success
        }
        else 
        {
            Write-Message "FAILED" -Level Error

            if ($Result.Outputs -and $Result.Outputs.Actual)
            {
                $Result.Outputs.Actual `
                | % {
                        Write-Host "Actual output" 
                        Write-Host "---------------"
                    } `
                    { 
                        Write-Host $_ 
                    } `
                    {
                        if ($Result.Outputs.Truncated)
                        {
                            Write-Host "   ...truncated $($Result.Outputs.Truncated) lines" 
                        }
                        Write-Host ""
                    }
                            
                $Result.Outputs.Expected `
                | % {
                        Write-Host "Expected output" 
                        Write-Host "---------------"
                    } `
                    { 
                        Write-Host $_ 
                    } `
                    {
                        Write-Host ""
                    }
                
                $Result.Outputs.Comparison `
                | Format-Table @{ Label = "Comparison" ; Expression = { $_.InputObject } }, "SideIndicator" -AutoSize `
                | Out-String `
                | Write-Host
            }
            # else there was no output, we do not write out anything
        }
           
        if ($PassThru) 
        {
            return $Result
        }
    }
}


Function Compare-TestAllocations 
{
    param(
        [PSObject][Parameter(ValueFromPipeline=$TRUE)]$InputObject
    ,   [string]$LogPath
    )

    process
    {
        $logFilePath = [System.IO.Path]::Combine($InputObject.RunDirectoryPath, $LogPath)

        if (-not $logFilePath -or (-not (Test-Path $logFilePath))) 
        {
            return $InputObject
        }

        $allocCache = [Ordered]@{}

        $invalidOperations = Get-Content $logFilePath `
        | ConvertFrom-Csv `
        | % { 
                if (($_.Op -eq "+") -and (-not $allocCache.Contains($_.Ptr)))
                {
                    $allocCache.Add($_.Ptr, $_.Size)
                }
                elseif (($_.Op -eq "-") -and ($allocCache.Contains($_.Ptr)))
                {
                    $allocCache.Remove($_.Ptr)
                }
                else
                {
                    return $_
                }
            }

        $log = [PSCustomObject]@{ 
            "Cache" = $allocCache
        ;   "InvalidOperations" = $invalidOperations
        } 

        return $InputObject `
               | Add-Member -MemberType NoteProperty -Name "Memory" -Value $log -PassThru
    }
}


Function Write-TestAllocations
{
    param(
        [PSObject][Parameter(ValueFromPipeline=$TRUE)]$Result
    ,   [int]$AcceptedLeakedLimit
    ,   [switch]$PassThru
    )

    process 
    {
        if ($Result.Memory) 
        {
            $stat = $Result.Memory.Cache.Values | Measure-Object -Sum
        
            if ($stat.Sum -gt $AcceptedLeakedLimit) 
            {
                Write-Message "Memory left: $($stat.Sum) Bytes in $($stat.Count) block(s): $($Result.Memory.Cache.Values)" -Level Info

                $Result.Memory.InvalidOperations `
                | % { 
                        Write-Message "Invalid `"$($_.Op)`" at $($_.Ptr)"
                    }
            }
        }

        if ($PassThru) 
        {
            $Result
        }
    }
}


Function Write-TestSummary 
{
    param(
        [PSObject][Parameter(ValueFromPipeline=$TRUE)]$Result
    )

    begin 
    {
        $passed = 0
        $failed = 0
    }
    process
    {
        if ($Result.IsSuccess) 
        {
            $passed++
        }
        else 
        {
            $failed++
        }
    }
    end
    {
        Write-Message
        Write-Message "===== SUMMARY =====" -Level Info
        Write-Message "Total $($passed + $failed)" -Level Info
        Write-Message "Passed $passed" -Level Success
        Write-Message "Failed $failed" -Level Error
    }
}


Function Invoke-Test
{
    <#
        .SYNOPSIS
        Executes a test case named $Name located at $TestsPath with the given executable at $ExecutablePath:
        1. Set the working directory for the executable to the test directory.
        2. Redirect process input to the test input file "input.txt" located in a directory names $Test.
        3. Redirect process output streams to files in $OutputDirectory.
        4. Run the program but limit its execution time, if $Timeout was specfied.
        5. Compare actual output of the program with expected output in "expected.txt" using the Compare-Output function.

        .DESCRIPTION
        Displays message about execution status:
        OK = process exit code was 0.
        FAILED - process terminated unsuccessfully.
    #>

    param( 
        [Parameter(Mandatory = $TRUE, ValueFromPipeline=$TRUE, ValueFromPipelineByPropertyName=$TRUE)][string]$Name
    ,   [Parameter(Mandatory = $TRUE)][string]$Run
    ,   [Parameter(Mandatory = $TRUE)][string]$ExecutablePath
    ,   [string]$TestsPath = "$PSScriptRoot\tests\"
    ,   [string]$OutputDirectory = "$PSScriptRoot\runs\"
    ,   [int]$Timeout
    )
    
    process 
    {
        $testDirectory = Join-Path $TestsPath -ChildPath $Name

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

        $runDirectory = Join-Path (Join-Path $OutputDirectory -ChildPath $Run) -ChildPath $Name
        
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
                            
        # cache the process handle, otherwise the WaitForExit would not work
        $handle = $process.Handle

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
                Get-Content $errorFilePath | % { [PSCustomObject]@{ "Error output" = $_ } } | Format-Table -AutoSize
            }
        }
        else
        {
            $process.Kill()
            if ($process.ExitCode -ne 0) 
            {
                Write-Message "Execution failed with exit code $($process.ExitCode)" -Level Error
                Get-Content $errorFilePath | % { [PSCustomObject]@{ "Error output" = $_ } } | Format-Table -AutoSize
            }
            else
            {
                Write-Message "Execution timed out" -Level Error
            }
        }

        Copy-Item $ExecutablePath -Destination (Join-Path $runDirectory -ChildPath "bin.exe")

        return [PSCustomObject]@{ 
            RunDirectoryPath = $runDirectory
        ;   ActualOutputPath = $outputFilePath
        ;   ExpectedOutputPath = $expectedFilePath
        }

        # Compare-Output -OutputPath $outputFilePath -ExpectedPath $expectedFilePath -Limit $OutputLimit
        
        # $allocLogFilePath = Join-Path $runDirectory -ChildPath $MemAllocLogPath

        # if (Test-Path $allocLogFilePath) 
        # {
        #     Compare-Allocations -AllocLogFilePath $allocLogFilePath -AcceptedLimit $MemAllocAcceptedLimit
        # }
    }
}



# Main script body

if (-not (Test-Path $SourcePath)) 
{
    Write-Host "Input file not found: $SourcePath" -ForegroundColor Red
    Return
}

$sourceName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)

New-Item $BuildDirectoryPath -ItemType Directory -ErrorAction Ignore | Out-Null
$executablePath = Join-Path $BuildDirectoryPath -ChildPath "$($sourceName).exe"

if (Test-Path $executablePath) 
{
    Remove-Item $executablePath -ErrorAction Stop
} 

$sourceFileName = [System.IO.Path]::GetFileName("$SourcePath")

Write-Message "$sourceFileName"
Write-Message "Compiling..." -Level Info

$gcc = Resolve-GccPath -GccPath $GccPath

# Check if the GCC is available. If not, ask to open Environment Variables settings window to set it in the PATH
if (-not $gcc)
{
    Write-Host "Compiler not found" -ForegroundColor Red
    Write-Host "Unable to find gcc.exe in your PATH. Set up path to the GCC bin directory to your PATH environmnet variable." -Foreground Red
    Write-Host "Set GCC bin directory to the PATH variable and restart PowerShell." -ForegroundColor Red
    Open-EnvironmentVariables -Confirm

    $gcc = Resolve-Path -GccPath $GccPath
}

if (-not $gcc)
{
    Write-Host "Unable to find gcc.exe in your PATH." -ForegroundColor Red
}

# Compile source file with GCC and supply includes in case they are missing in the source file.
# Example: gcc src.c -o src.exe -include "stdio.h" -include "string.h" -include "stdlib.h"
$compilerArgs = @(
    $SourcePath
,   "-o", $executablePath
,   "-include", "stdio.h"
,   "-include", "string.h"
,   "-include", "stdlib.h"
)

if ($LogMemAlloc)
{
    # adds logging of calls to the functions for dynamic memory allocations from stdlib.h to $MemAllocLogPath
    $compilerArgs += @(
        "-include", "$PSScriptRoot\lib\memlog.c"
    ,   "-Wl,--wrap=free,--wrap=malloc,--wrap=realloc,--wrap=calloc"
    ,   "-DMEMLOGFILE=`"\`"$MemAllocLogPath\`"`""
    )
}

Start-Process -FilePath "gcc.exe" -ArgumentList ($compilerArgs | % { $_ }) -Wait -NoNewWindow

if (-not (Test-Path $executablePath))
{
    Write-Message "Compilation failed" -Level Error
    Return
}

Write-Message "Success" -Level Success

Write-Message "Running tests" -Level Info
Write-Message

Get-ChildItem $TestsPath -Filter $TestsFilter -Directory `
| Sort-Object -Property Name `
| % {     
        Write-Message
        Write-Message "Executing test case $($_.Name)" -Level Info
        $_
    } `
| Invoke-Test -Run $sourceName `
              -TestsPath $TestsPath `
              -ExecutablePath $executablePath `
              -Timeout $Timeout `
| Compare-TestOutput -Limit $OutputLimit `
| Compare-TestAllocations -LogPath $MemAllocLogPath `
| Write-TestResult -PassThru `
| Write-TestAllocations -AcceptedLeakedLimit $MemAllocAcceptedLimit -PassThru `
| Write-TestSummary