#!/bin/bash

# ====================
# 2019 Matúš Chovan
# ====================

# Variables from outside
source_path=""
test_filter=""
differences=0
cleanup=0
timeout=1

# Inside variables
header="Simple C Program Tester for LINUX"
usage="Usage: ./TestLinux.sh <source_program.c> [OPTIONS...]"

help_format="%3s %-30s %s\n"

ferr="\e[1m\e[31m[-]\e[39m\e[0m"
fok="\e[1m\e[32m[+]\e[39m\e[0m"
finfo="\e[1m\e[34m[*]\e[39m\e[0m"

output_dir="build"
tests_dir="tests"
run_dir="runs"

exec="`pwd`/$output_dir/a.out"
source_name=""

use_rsync=1

let passed=0
let failed=0
let omitted=0

# Print usage
helpmenu() {
	echo
    echo $header
    echo $usage
    echo
    printf "$help_format" "-h" "--help" "Display this menu"
    printf "$help_format" "-f" "--filter NAME" "Run specific test with name NAME"
	printf "$help_format" "-d" "--differences" "Display whole expected and actual output instead of only differences"
	printf "$help_format" "-c" "--cleanup" "Delete generated outputs after finishing"
	printf "$help_format" "-t" "--timeout" "Set programs execution time limit. Program will be killed after time limit is exceeded."
	echo
	echo "Flags need to be typed separately. Ex: './Test.sh ... -dc' will not work. You have to type './Test.sh ... -d -c'"
}

# Compile src with gcc
compile() {
	command -v gcc >> /dev/null
	if [ $? -gt 0 ]; then
		echo "$ferr GCC in not installed or not in PATH"
		exit
	fi
	if [ ! -d "$output_dir" ]; then mkdir $output_dir; fi
	echo -e "$finfo Compiling..."
	gcc $source_path -o $exec -lm
}

# $1 => test directory path
test() {
	test=${1##*/}

	echo -e "$finfo Executing test case $test"
	
	# Reset test's run folder
	if [ -d "$run_dir/$source_name/$test" ]; then find "$run_dir/$source_name/$test" -type f -delete; fi
	if [ $use_rsync -eq 1 ];then
		rsync -r --exclude="expected.txt" "`pwd`/$tests_dir/$test/" "`pwd`/$run_dir/$source_name/$test/"
	else
		if [ ! -d "`pwd`/$run_dir/$source_name/$test/" ]; then mkdir "`pwd`/$run_dir/$source_name/$test/"; fi
		find "`pwd`/$tests_dir/$test/" -mindepth 1 -path "`pwd`/$tests_dir/$test/expected.txt" -prune -o -exec cp '{}' "`pwd`/$run_dir/$source_name/$test/" \;
	fi
	
	# Run C program with redirected outputs in new spawned shell
	(cd "$run_dir/$source_name/$test" && exec timeout "$timeout"s $exec < "input.txt" > "output.txt" 2>"error.txt")

	# Check if program failed (check status codes)
	exit_code=$?
	if [ $exit_code -eq 124 ]; then
		echo -e "$ferr Allowed program runtime exceeded"
		return
	elif [ ! $exit_code == 0 ]; then
		echo -e "$ferr Failed with exit code $exit_code"
		return
	fi

	# Check program output with expected results
	diff -ZB "$run_dir/$source_name/$test/output.txt" "$tests_dir/$test/expected.txt" >> /dev/null
	result=$?
	if [ $result -eq 0 ]; then
		echo -e "$fok PASSED"
		((passed++))
	else
		echo -e "$ferr FAILED"
		((failed++))
		if [ $differences -eq 0 ]; then
			diff "$run_dir/$source_name/$test/output.txt" "$tests_dir/$test/expected.txt"
		else
			echo "##### actual #####"
			cat "$run_dir/$source_name/$test/output.txt"
			echo "---- expected ----"
			cat "$run_dir/$source_name/$test/expected.txt"
			echo "##################"
		fi
	fi
}

# Find all subdirectories in test/, pick the ones that
# match the filter and sort them
# Then run tests within these folders
runtests() {
	echo -e "$finfo Running tests\n"
	if [ ! -d "$run_dir/$source_name" ]; then mkdir "$run_dir/$source_name"; fi
	for tdir in `find ./$tests_dir -mindepth 1 -type d | grep "$test_filter" | sort`
	do
		echo "=============================="
		if [ ! -f "$tdir/input.txt" ] || [ ! -f "$tdir/expected.txt" ]; then
			echo -e "$ferr Skipping '${tdir##*/}', test files missing"
			((omitted++))
			continue
		fi
		test $tdir
	done
	echo
}

# Cleanup compiled files and copied files
cleanup() {
	echo -e "$finfo Cleaning up"
	rm "$exec"
	if [ ! $cleanup -eq 0 ]; then find $run_dir -mindepth 1 -delete; fi
}

summary() {
	echo
	echo "===== SUMMARY ====="
	echo "Total $((passed + failed + omitted))"
	echo "Passed $passed"
	echo "Failed $failed"
	if [ $omitted -gt 0 ]; then echo "Omitted $omitted"; fi
}


# === MAIN ===

# Check if user is trying to display help
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
	helpmenu
	exit
fi

# Read and parse C program path
source_path="`pwd`/$1"
source_name=${source_path##*/}
if [ "${source_path#*.}" != "c" ]; then
	echo -e "$ferr Input file was not provided or is not a c source code => $source_path"
	echo "$usage"
	exit
elif [ ! -f $source_path ]; then
	echo -e "$ferr Input file '$source_path' does not exist"
	exit
fi
shift

# Read and parse other flags
while [ ! $# -eq 0 ]
do
	case "$1" in
		--help | -h)
			helpmenu
			exit
			;;
        --filter | -f)
			shift
			test_filter="$1"
            ;;
		--differences | -d)
			differences=1
			;;
		--cleanup | -c)
			cleanup=1
			;;
		--timeout | -t)
			shift
			timeout="$1"
			echo -e "$finfo Setting time limit to $timeout seconds"
			;;
	esac
	shift
done

# Check for rsync command
command -v rsync >> /dev/null
if [ $? -gt 0 ]; then use_rsync=0; fi

# Compile and check success
compile
sleep 0.5
if [ ! -f "$exec" ]; then
	echo -e "$ferr Compilation error"
	exit
else
	echo -e "$fok Compilation success"
fi

# Run and clean
runtests
cleanup
summary