#!/bin/bash

obj="program main.o a/program_a a/main.o b/c/c.o b/d/d.o b/program_b b/main.o c/c.o c/test_cc d/lib.so"
dep="main.d a/main.d b/main.d b/c/c.d b/d/d.d c/c.d d/lib.d"
notes="main.gcno a/main.gcno b/main.gcno b/c/c.gcno b/d/d.gcno c/c.gcno d/lib.gcno"

interrupted ()
{
	PASSED=false
	FAILURE="tests were interrupted while executing \"${BASH_COMMAND}\""
	exit 1
}

teardown ()
{
	if [ -d "${tmpdir}" ]; then
		rm -rf ${tmpdir}
	fi
	if [ "${PASSED}" == 'true' ]; then
		printf '\n\e[1;32mPASSED\e[0m (%s tests)\n\n' ${TESTS}
	else
		printf '\n\e[1;31m%s\e[0m %s\n\n' FAILED "${FAILURE:=while executing \"${BASH_COMMAND}\"}"
	fi
}

test_caption ()
{
	TESTS=$((TESTS + 1))
	printf '\n\e[1;34m%s\e[0m %s\n\n' TEST "${@}"
}

trap "PASSED=false" ERR
trap interrupted INT
trap teardown EXIT

cd test
PASSED=true
TESTS=0

set -o errexit

test_caption "make distclean"
make distclean
for file in ${obj} ${dep} ${notes}; do
	test ! -e ${file}
done

test_caption "make"
make
for file in ${obj} ${dep}; do
	test -e ${file}
done
for file in ${notes}; do
	test ! -e ${file}
done

test_caption "make distclean"
make distclean
for file in ${obj} ${dep} ${notes}; do
	test ! -e ${file}
done

test_caption "make VERBOSE=1"
make VERBOSE=1
for file in ${obj} ${dep}; do
	test -e ${file}
done
for file in ${notes}; do
	test ! -e ${file}
done

test_caption "make VERBOSE=1 clean"
make VERBOSE=1 clean
for file in ${obj} ${dep} ${notes}; do
	test ! -e ${file}
done

tmpdir=$(mktemp -d)
test_caption "make BUILD_DIR=${tmpdir}"
make BUILD_DIR=${tmpdir}
for file in ${obj} ${dep}; do
	test -e ${tmpdir}/${file}
done
for file in ${notes}; do
	test ! -e ${tmpdir}/${file}
done

test_caption "make BUILD_DIR=${tmpdir} clean"
make BUILD_DIR=${tmpdir} clean
for file in ${obj} ${dep} ${notes}; do
	test ! -e ${tmpdir}/${file}
done

test_caption "target 'gcov'"
make gcov
for file in ${obj} ${dep} ${notes}; do
	test -e ${file}
done

test_caption "make clean"
make clean
for file in ${obj} ${dep} ${notes}; do
	test ! -e ${file}
done

#test_caption "make check"
#make check
#for file in c/test_cc c/c.o c/c.d c/.test.sh.guard; do
#	test -e ${file}
#done

test_caption "make debug"
make debug
for file in ${obj} ${dep}; do
	test -e ${file}
done
for file in ${notes}; do
	test ! -e ${file}
done

test_caption "make clean"
make clean
for file in ${obj} ${dep} ${notes}; do
	test ! -e ${file}
done

test_caption "make release"
make release
for file in ${obj} ${dep}; do
	test -e ${file}
done
for file in ${notes}; do
	test ! -e ${file}
done

test_caption "make clean"
make clean
for file in ${obj} ${dep} ${notes}; do
	test ! -e ${file}
done

test_caption "make static"
#make static

test_caption "make clean"
make clean
for file in ${obj} ${dep} ${notes}; do
	test ! -e ${file}
done

exit 0
