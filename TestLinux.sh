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
exec="$output_dir/a.out"
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
	gcc $source_path -o $exec -lm
}

# $1 => test directory path
test() {
	outf="output.txt"
	errf="error.txt"
	test=$1

	#echo -e "$finfo Executing test case '${test##*/}'"
	
	if [ -d $run_dir ]; then find $run_dir -type f -delete; fi
	cp -r "$test"/* $run_dir
	
	(cd $run_dir && exec timeout 1s "../$exec" < ".$test/input.txt" > "$outf" 2>"$errf")

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
	diff "$run_dir/output.txt" "$run_dir/expected.txt" >> /dev/null
	result=$?
	if [ $result -eq 0 ]; then
		echo -e "$fok PASSED"
	else
		echo -e "$ferr FAILED"
		echo "##### actual #####"
		cat "$run_dir/output.txt"
		echo "---- expected ----"
		cat "$run_dir/expected.txt"
		echo "##################"
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
		if [ ! -f "$tdir/input.txt" ] || [ ! -f "$tdir/expected.txt" ]; then
			echo -e "$ferr Test files missing in '${tdir##*/}'"
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
	find $run_dir -type f -delete
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
if [ ! -f "$exec" ]; then
	echo -e "$ferr Compilation error"
	exit
else
	echo -e "$fok Compilation success"
fi

runtests

cleanup