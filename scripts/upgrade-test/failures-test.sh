#!/bin/bash
# Tests of failures.awk, the classification of the failed requests of the load (scripts/upgrade-test.sh).
# Run from the repository root.

set -euo pipefail

AWK=scripts/upgrade-test/failures.awk
ERRORS=0

# Classifies the FAIL lines on stdin with the given awk variables, and compares the "<phase> <verdict> #<n>" of
# each line with the expected ones
check() {
    local name="$1" expected="$2"
    shift 2
    local actual
    actual=$(awk "$@" -f "$AWK" | awk '{ print $1, $2, $5 }')
    if [ "$actual" = "$expected" ]; then
        echo "OK   $name"
    else
        echo "FAIL $name"
        echo "  expected: $(tr '\n' '|' <<< "$expected")"
        echo "  actual:   $(tr '\n' '|' <<< "$actual")"
        ERRORS=$((ERRORS + 1))
    fi
}

# FAIL <kind> #<n> <start> <end> <time> <code> <detail>
LOG='FAIL query #1 100 101 10:00:00 000 curl: (7) Failed to connect
FAIL ui #2 150 160 10:00:50 502 Bad Gateway
SUMMARY query ok=10 failed=1'

check "rolling: every failure is one of the upgrade" "upgrade failed #1
upgrade failed #2" <<< "$LOG"

check "rolling with a documented outage: the upgrade failures are tolerated" "upgrade tolerated #1
upgrade tolerated #2" -v disruption=1 <<< "$LOG"

check "rolling: after the end of the upgrade, a failure is one of the steady state" "upgrade failed #1
steady failed #2" -v upgraded=120 <<< "$LOG"

check "ha: before the end of the upgrade, then of the drain" "upgrade failed #1
drain failed #2" -v upgraded=120 -v drained=200 -v killed=300 <<< "$LOG"

check "ha: documented outage only for the upgrade" "upgrade tolerated #1
drain failed #2" -v upgraded=120 -v drained=200 -v killed=300 -v disruption=1 <<< "$LOG"

LOSS='FAIL query #1 280 285 10:00:00 500 before the kill
FAIL query #2 290 300 10:00:00 000 in flight at the kill
FAIL mutation #3 295 302 10:00:00 000 in flight at the kill
FAIL ui #4 300 301 10:00:00 502 at the kill
FAIL query #5 309 310 10:00:00 000 within the window
FAIL query #6 310 311 10:00:00 000 after the window
FAIL ui #7 400 401 10:00:00 502 long after'

check "ha: only the requests in flight at the kill or started within the window are tolerated" "steady failed #1
loss tolerated #2
loss tolerated #3
loss tolerated #4
loss tolerated #5
recovered failed #6
recovered failed #7" -v upgraded=120 -v drained=200 -v killed=300 -v window=10 <<< "$LOSS"

[ $ERRORS -eq 0 ] || { echo "$ERRORS failed test(s)"; exit 1; }
