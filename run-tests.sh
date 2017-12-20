#! /bin/bash -ex
TEST_COUNT=32
TODO_COUNT=1

elm-make src/VerifyExamples.elm --output bin/elm.js --warn
pushd example
../bin/cli.js
elm-test 2>&1 | tee ../result.json
popd
cat result.json | grep "Passed:   ${TEST_COUNT}"
cat result.json | grep "Failed:   0"
cat result.json | grep "Todo:     ${TODO_COUNT}"
