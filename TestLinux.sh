#!/bin/bash

# 2019 Matúš Chovan

header="Simple C Program Tester for LINUX"
usage="Usage: TestLinux.sh <source_program.c> [OPTIONS...]"

help_format="%3s %-30s %s\n"

ferr="\e[1m\e[31m[-]\e[39m\e[0m"
fok="\e[1m\e[32m[+]\e[39m\e[0m"
finfo="\e[1m\e[34m[*]\e[39m\e[0m"

output_dir="build"
tests_dir="tests"
run_dir="runs"

source_path=""
output_path="$output_dir/a.out"
test_filter=""

# Print usage
helpmenu() {
	echo
    echo $header
    echo $usage
    echo
    printf "$help_format" "" "--help" "Display this menu"
    printf "$help_format" "-f" "--tests-filter NAME" "Run specific test with name NAME"
}

# Compile src with gcc
compile() {
	if [ ! -d "$output_dir" ]; then mkdir $output_dir; fi
	echo -e "$finfo Compiling..."
	gcc $source_path -o $output_path -lm
}

# $1 => test directory path
test() {
	outf="output.txt"
	errf="error.txt"
	test=$1
	exec=$output_path

	echo -e "$finfo Executing test case '${test##*/}'"
	
	if [ -d $run_dir ]; then rm -r "$run_dir"/*; fi
	sleep 0.1
	cp -r "$test"/* $run_dir
	#echo $exec
	(cd $run_dir && exec "../$exec" < ".$test/input.txt" > "$outf" 2>"$errf")

	exit_code=$?
	if [ ! $exit_code == 0 ]; then
		echo -e "$ferr Failed with exit code $exit_code"
		return
	fi
}

# Run all test in test directory
# Find all subdirectories in test/ pick the ones, that
# match the filter and sort them
runtests() {
	echo -e "\n$finfo Running tests"
	if [ ! -d $run_dir ]; then mkdir $run_dir; fi
	for tdir in `find ./$tests_dir -mindepth 1 -type d | grep "$test_filter" | sort`
	do
		test $tdir
	done
	echo
}

# Cleanup compiled files and copied files
cleanup() {
	echo -e "$finfo Cleaning up"
	rm $output_path
	rm -r "$run_dir"/*
}


# === MAIN ===

# Check if user is trying to display help menu
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
	helpmenu
	exit
fi

# Read and parse C program path
source_path=$1
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
        --tests-filter | -f)
			shift
			test_filter="$1"
            ;;
	esac
	shift
done

# Compile and check success
compile
sleep 0.5
if [ ! -f "$output_path" ]; then
	echo -e "$ferr Compilation error"
	exit
else
	echo -e "$fok Compilation success"
fi

runtests

cleanup