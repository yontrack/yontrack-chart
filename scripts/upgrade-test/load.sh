#!/bin/sh
# Load of the rolling and ha upgrade tests (scripts/upgrade-test.sh), run in the cluster, against the services:
# GraphQL queries and mutations on the backend, GET / on the UI. The GraphQL requests read and create predefined
# validation stamps: creating a project needs a valid license. Every failed request is logged
# (FAIL <kind> #<n> <start> <end> <time> <code> <detail>, start and end in epoch seconds) and counted, until /tmp/stop
# exists. The start of the last successful request of each kind is kept in /tmp/<kind>.ok. Ends with SUMMARY lines,
# then DONE.

set -u

SEED=upgrade-test
# Suffix of the created stamps, unique per run of the pod (its PID is always 1)
RUN=$(date +%s)

# Runs a request, with $1 the kind of request and the rest the curl arguments,
# and sets START (epoch seconds), CODE (HTTP code, 000 on a connection error) and BODY
request() {
    kind="$1"
    shift
    START=$(date +%s)
    # curl leaves the body of the previous request when it gets none
    rm -f "/tmp/$kind.body"
    CODE=$(curl -sS -o "/tmp/$kind.body" -w '%{http_code}' --max-time 10 "$@" 2> "/tmp/$kind.err")
    BODY="$(cat "/tmp/$kind.err")$(cat "/tmp/$kind.body" 2> /dev/null)"
}

graphql() {
    kind="$1"
    request "$kind" -X POST -H 'Content-Type: application/json' -H "X-Ontrack-Token: $TOKEN" \
        --data "{\"query\":\"$2\"}" "$BACKEND/graphql"
}

# Token of the provisioned admin, from the actuator
TOKEN=""
for _ in $(seq 1 60); do
    TOKEN=$(curl -sf --max-time 10 "$MGT/manage/account/$ADMIN" | tr -d '"')
    [ -n "$TOKEN" ] && break
    sleep 5
done
[ -n "$TOKEN" ] || { echo "ERROR no token"; exit 1; }
# Shared with the queries of scripts/upgrade-test.sh
echo "$TOKEN" > /tmp/token

# Seeding
graphql seed "mutation { createPredefinedValidationStamp(input: {name: \\\"$SEED\\\", description: \\\"\\\"}) { predefinedValidationStamp { id } errors { message } } }"
echo "Seed: $CODE $BODY"
echo "$BODY" | grep -qE '"predefinedValidationStamp":\{"id"|already exists' || { echo "ERROR seed"; exit 1; }

# Checks the last request, given the kind, the request number and an expected fragment of the body
check() {
    case "$CODE" in
        2??)
            if [ -n "$3" ] && ! echo "$BODY" | grep -qF "$3"; then
                echo "FAIL $1 #$2 $START $(date +%s) $(date +%T) $CODE $BODY"
                return 1
            fi
            ;;
        *)
            echo "FAIL $1 #$2 $START $(date +%s) $(date +%T) $CODE $BODY" | head -c 500
            echo
            return 1
            ;;
    esac
    echo "$START" > "/tmp/$1.ok"
}

loop() {
    kind="$1"
    ok=0
    failed=0
    n=0
    while [ ! -f /tmp/stop ]; do
        n=$((n + 1))
        case "$kind" in
            query)
                graphql query "{ predefinedValidationStampByName(name: \\\"$SEED\\\") { id name } }"
                expected="\"name\":\"$SEED\""
                ;;
            mutation)
                graphql mutation "mutation { createPredefinedValidationStamp(input: {name: \\\"$SEED-$RUN-$n\\\", description: \\\"\\\"}) { predefinedValidationStamp { id } errors { message } } }"
                expected='"predefinedValidationStamp":{"id"'
                ;;
            ui)
                request ui "$UI/"
                expected=""
                ;;
        esac
        if check "$kind" "$n" "$expected"; then
            ok=$((ok + 1))
        else
            failed=$((failed + 1))
        fi
        sleep 0.2
    done
    echo "SUMMARY $kind ok=$ok failed=$failed"
}

loop query &
loop mutation &
loop ui &
echo "READY"
wait
echo "DONE"
# Kept alive for the logs to be read
sleep 3600
