#!/bin/bash

# ====================
# 2019 Matúš Chovan
# ====================

# Variables from outside
source_path=""
test_filter=""
differences=0
cleanup=0

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

let passed=0
let failed=0
let omitted=0

# Print usage
helpmenu() {
	echo
    echo $header
    echo $usage
    echo
    printf "$help_format" "" "--help" "Display this menu"
    printf "$help_format" "-f" "--tests-filter NAME" "Run specific test with name NAME"
	printf "$help_format" "-d" "--differences" "Display whole expected and actual output instead of only differences"
	printf "$help_format" "-c" "--cleanup" "Delete generated outputs after finishing"
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
	
	if [ -d "$run_dir/$test" ]; then find "$run_dir/$test" -type f -delete; fi
	rsync -r --exclude="expected.txt" "`pwd`/$tests_dir/$test/" "`pwd`/$run_dir/$test/"
	
	(cd "$run_dir/$test" && exec timeout 1s $exec < "input.txt" > "output.txt" 2>"error.txt")

	# Check if porgram failed
	exit_code=$?
	if [ $exit_code -eq 124 ]; then
		echo -e "$ferr Allowed program runtime exceeded"
		return
	elif [ ! $exit_code == 0 ]; then
		echo -e "$ferr Failed with exit code $exit_code"
		return
	fi

	# Check program output with expected
	diff -ZB "$run_dir/$test/output.txt" "$tests_dir/$test/expected.txt" >> /dev/null
	result=$?
	if [ $result -eq 0 ]; then
		echo -e "$fok PASSED"
		((passed++))
	else
		echo -e "$ferr FAILED"
		((failed++))
		if [ $differences -eq 0 ]; then
			diff "$run_dir/$test/output.txt" "$tests_dir/$test/expected.txt"
		else
			echo "##### actual #####"
			cat "$run_dir/$test/output.txt"
			echo "---- expected ----"
			cat "$tests_dir/$test/expected.txt"
			echo "##################"
		fi
	fi
}

# Run all test in test directory
# Find all subdirectories in test/ pick the ones, that
# match the filter and sort them
runtests() {
	echo -e "$finfo Running tests\n"
	if [ ! -d $run_dir ]; then mkdir $run_dir; fi
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
	echo "Omitted $omitted"
}


# === MAIN ===

# Read and parse C program path
source_path="`pwd`/$1"
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
        --tests-filter | -f)
			shift
			test_filter="$1"
            ;;
		--differences | -d)
			differences=1
			;;
		--cleanup | -c)
			cleanup=1
			;;
	esac
	shift
done

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