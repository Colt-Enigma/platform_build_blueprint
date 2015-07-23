#!/bin/bash

# Go to srcdir
cd $(dirname ${BASH_SOURCE[0]})/..

rm -rf out.test
mkdir out.test
cd out.test
../bootstrap.bash

# Run ninja, filter the output, and compare against expectations
# $1: Name of test
function testcase()
{
  echo -n "Running $1..."
  if ! ninja -v -d explain >log_$1 2>&1; then
    echo " Failed."
    echo "Test $1 Failed:" >>failed
    tail log_$1 >>failed
    return
  fi
  grep -E "^(Choosing|Newer|Stage)" log_$1 >test_$1
  if ! cmp -s test_$1 ../tests/expected_$1; then
    echo " Failed."
    echo "Test $1 Failed:" >>failed
    diff -u ../tests/expected_$1 test_$1 >>failed
  else
    echo " Passed."
  fi
}




testcase start

# The 2 second sleeps are needed until ninja understands sub-second timestamps
# https://github.com/martine/ninja/issues/371

# This test affects all bootstrap stages
sleep 2
touch ../Blueprints
testcase all

# This test affects nothing, nothing should be done
sleep 2
testcase none

# This test will cause the source build.ninja.in to be copied into the first
# stage.
sleep 2
touch ../build.ninja.in
testcase manifest

# From now on, we're going to be modifying the build.ninja.in, so let's make our
# own copy
sleep 2
../tests/bootstrap.bash -r

sleep 2
testcase start2

# This is similar to the last test, but incorporates a change into the source
# build.ninja.in, so that we'll restart into the new version created by the
# build.
sleep 2
echo "# test" >>src.build.ninja.in
testcase regen

# Add tests to our build by using '-t'
sleep 2
../tests/bootstrap.bash -r -t

sleep 2
testcase start_add_tests

# Make sure that updating a test file causes us to go back to the bootstrap
# stage
sleep 2
touch ../parser/parser_test.go
testcase rebuild_test




if [ -f failed ]; then
  cat failed
  exit 1
fi
