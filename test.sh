#!/bin/bash

set -u

stop_on_fail=false
keep_tmpfile=false

while getopts sk opt; do
	case "$opt" in
	s) stop_on_fail=true;;
	k) keep_tmpfile=true;;
	*) exit 1;;
	esac
done

fsfile="$(mktemp)"

if $keep_tmpfile; then
	echo "Test fsfile is $fsfile"
else
	trap "rm -f $fsfile" EXIT
fi

jemf() { ./jemf "$@"; }

export JEMF_FSFILE="$fsfile"
export __JEMF_TEST__=1
export __JEMF_TEST_PASSWORD__="hunter2"

nfail=0
npass=0
ntests=0

finish()
{
	echo
	echo "Ran $ntests tests; $npass passed, $nfail failed."
	[ "$nfail" = 0 ]
	exit $?
}

runtest()
{
	local status label result n invert=false

	OPTIND=1
	while getopts n opt; do
		case "$opt" in
		n) invert=true;;
		*) return 1;;
		esac
	done
	shift "$((OPTIND-1))"

	label="$1"
	shift 1

	printf '%-40s ' "$label:"

	((++ntests))

	if $invert; then
		! TEST_OUTPUT="$("$@" 2>&1)"
	else
		TEST_OUTPUT="$("$@")"
	fi
	status="$?"

	if [ "$status" = 0 ]; then
		result="pass"
		((++npass))
	else
		result="fail"
		((++nfail))
		if $stop_on_fail; then
			finish
		fi
	fi
	printf '%s\n' "$result"
}

runtest "mkfs" jemf mkfs -f
runtest "ls fresh FS" jemf ls
runtest "empty FS ls output empty" [ -z "$TEST_OUTPUT" ]

runtest "mkdir" jemf mkdir d
runtest "ls with single top-level entry" jemf ls
runtest "single-item ls output" [ "$TEST_OUTPUT" = "d/" ]

runtest -n "mkdir when directory exists" jemf mkdir d

runtest "create file" jemf create -g L10 d/f1
runtest "cat file" jemf cat d/f1

df1="$TEST_OUTPUT"
runtest "autogenerated file length" [ "${#df1}" = 10 ]

runtest "path lookup with '.'" jemf cat d/./f1
runtest "path lookup with '..'" jemf cat d/../d/f1

runtest "create symlink to file" jemf ln d/f1 l1
runtest "read file through symlink" jemf cat -f l1

l1="$TEST_OUTPUT"
runtest "symlink read data" [ "$l1" = "$df1" ]
runtest "rm symlink to file" jemf rm l1

runtest "create symlink to directory" jemf ln d dl
runtest "read file through directory symlink" jemf cat -f dl/f1

dlf1="$TEST_OUTPUT"
runtest "directory link read data" [ "$dlf1" = "$df1" ]
runtest "rm symlink to directory" jemf rm dl

runtest "create broken symlink" jemf ln missing bl
runtest -n "read from broken symlink" jemf cat -f bl
runtest -n "mkdir over broken symlink" jemf mkdir bl
runtest "rm broken symlink" jemf rm bl

runtest "create over broken symlink" jemf shell <<-EOF
	ln target link
	create -g L10 link
EOF
runtest "read from symlink unbroken by create" jemf cat link
linkdata="$TEST_OUTPUT"
runtest "read from target of unbroken link" jemf cat target
tgtdata="$TEST_OUTPUT"
runtest "compare data from link and target" [ "$linkdata" = "$tgtdata" ]
runtest -n "symlink over existing file" jemf ln foobar target
runtest -n "symlink over existing symlink" jemf ln foobar link
runtest "rm link and target" jemf rm link target

runtest "pwd at root" jemf shell <<-EOF
	pwd
EOF
rootpwd="$TEST_OUTPUT"
runtest "pwd output at root" [ "$rootpwd" = "/" ]

runtest "pwd in subdir" jemf shell <<-EOF
	cd d
	pwd
EOF
subdirpwd="$TEST_OUTPUT"
runtest "pwd output in subdir" [ "$subdirpwd" = "/d" ]

runtest -n "mkdir when file exists" jemf mkdir d/f1

runtest "cd & mv via shell" jemf shell <<-EOF
	cd d
	mv f1 f2
EOF

runtest "cat renamed file" jemf cat d/f2
df2="$TEST_OUTPUT"
runtest "file content after rename" [ "$df2" = "$df1" ]

runtest "rename directory" jemf mv d e

runtest "cat file after directory rename" jemf cat e/f2
ef2="$TEST_OUTPUT"
runtest "file content after directory rename" [ "$ef2" = "$df2" ]

runtest "edit existing file" jemf edit -g L10 e/f2
ef2_old="$ef2"
runtest "cat edited file" jemf cat e/f2
ef2="$TEST_OUTPUT"
runtest "content of edited file" [ "$ef2" != "$ef2_old" ]

runtest "rm file" jemf rm e/f2
runtest "rm directory" jemf rm e
runtest "ls on emptied FS" jemf ls
runtest "ls output empty after emptying FS" [ -z "$TEST_OUTPUT" ]

runtest "cross-directory rename" jemf shell <<-EOF
	mkdir d1
	mkdir d2
	create -g L12 d1/f
	mv d1/f d2
EOF

runtest -n "cat old after cross-directory rename" jemf cat d1/f
runtest "cat new after cross-directory rename" jemf cat d2/f

runtest "mv to directory symlink" jemf shell <<-EOF
	ln d1 dirlink
	create -g L10 newfile
	mv newfile dirlink
	cat dirlink/newfile
EOF
fdata="$TEST_OUTPUT"

runtest "symlink into directory" jemf shell <<-EOF
	ln /d1/newfile d2
	cat d2/newfile
EOF
ldata="$TEST_OUTPUT"
runtest "verify symlink data" [ "$ldata" = "$fdata" ]

runtest -n "rm non-empty directory" jemf rm d2
runtest "rm -r on non-empty directory" jemf rm -r d2

finish
