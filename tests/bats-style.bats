#!/usr/bin/env bats
#
# How this repository's own tests are written (#56). Bash exempts a command
# negated with a bare `!` from errexit, so inside a test body it only counts as
# the last line: one more line after it and the check can never fail. Negative
# checks in a test therefore use `run !`. Helpers keep `!`, where it is the
# function's return value.

bats_require_minimum_version 1.5.0

BAD="${BATS_TEST_DIRNAME}/fixtures/bats-style-bad.bats.txt"

# Prints file:line for each bare `!` statement inside a @test body.
bare_negations_in_tests() {
  awk '/^@test /{t=1; next} t && /^}/{t=0} t && /^[[:space:]]*![[:space:]]/{print FILENAME ":" FNR}' "$@"
}

@test "no test body asserts with a bare !" {
  run bare_negations_in_tests "${BATS_TEST_DIRNAME}"/*.bats
  [ "$status" -eq 0 ]
  [ -z "$output" ] || { echo "use run ! at: $output"; false; }
}

@test "the rule flags a bare ! in a test body and spares a helper" {
  run bare_negations_in_tests "${BAD}"
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == *":9" ]]
}
