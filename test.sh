#!/bin/bash

set -eu

fsfile="$(mktemp)"
trap "rm -f $fsfile" EXIT

jemf() { ./jemf "$@"; }

export JEMF_FSFILE="$fsfile"
export __JEMF_TEST__=1
export __JEMF_TEST_PASSWORD__="hunter2"

jemf mkfs -f
[ -z "$(jemf ls)" ]

jemf mkdir d
[ "$(jemf ls)" = "d/" ]

# trying to create a directory that already exists should fail
! jemf mkdir d 2>/dev/null

jemf create -g L10 d/f1

df1="$(jemf cat d/f1)"
[ "${#df1}" = 10 ]

jemf shell <<-EOF
	cd d
	mv f1 f2
EOF

df2="$(jemf cat d/f2)"
[ "$df2" = "$df1" ]

jemf mv d e

ef2="$(jemf cat e/f2)"
[ "$ef2" = "$df2" ]

jemf edit -g L10 e/f2
ef2_old="$ef2"
ef2="$(jemf cat e/f2)"
[ "$ef2" != "$ef2_old" ]

jemf rm e/f2
jemf rm e
[ -z "$(jemf ls)" ]
