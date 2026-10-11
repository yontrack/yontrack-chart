#!/bin/bash
# Upgrade test on a kind cluster (#151): installs the previous published chart, then upgrades it to the
# chart of this checkout, with a backend image which has one pending expand and one pending contract
# migration (scripts/upgrade-test/Dockerfile).
#
#   ./scripts/upgrade-test.sh rolling   # ontrack.zeroDowntimeUpgrades: true, under load: no request may fail,
#                                       # and the hook Job runs the contract migration
#   ./scripts/upgrade-test.sh default   # default mode: the pod comes back, both migrations ran at startup
#
# Requires docker, kind, kubectl, helm, yq and gh (for the previous release). Run from the repository root.
#
# Environment:
#   KIND_CLUSTER            kind cluster to use (default: yt-upgrade), created if missing
#   PREVIOUS_CHART_VERSION  chart to upgrade from (default: the latest GitHub release of the same major, other than this version)
#   BASE_IMAGE              backend image to add the test migrations to (default: yontrack/yontrack:<appVersion>)
#   IMAGE_PLATFORM          platform of the test image (default: linux/amd64)
#   OUT                     directory of the logs and reports (default: build/upgrade-test)

set -euo pipefail

MODE="${1:-}"
case "$MODE" in
    rolling) ZDU=true ;;
    default) ZDU=false ;;
    *) echo "Usage: $0 rolling|default" >&2; exit 2 ;;
esac

CHART=charts/yontrack
DIR=scripts/upgrade-test
CLUSTER="${KIND_CLUSTER:-yt-upgrade}"
NS=upgrade-test
RELEASE=yt
BACKEND="$RELEASE-yontrack-chart"
JOB="$BACKEND-contract-migrations"
OUT="${OUT:-build/upgrade-test}"
KUBECTL=(kubectl --context "kind-$CLUSTER" -n "$NS")
HELM=(helm --kube-context "kind-$CLUSTER" -n "$NS")

CURRENT=$(yq -r .version "$CHART/Chart.yaml")
APP_VERSION=$(yq -r .appVersion "$CHART/Chart.yaml")
# Same major only: the other release lines (v5) are published elsewhere, and a major upgrade may have downtime
MAJOR="${CURRENT%%.*}"
PREVIOUS="${PREVIOUS_CHART_VERSION:-$(gh release list --exclude-drafts --limit 100 --json tagName --jq "[.[].tagName | select(. != \"$CURRENT\" and startswith(\"$MAJOR.\"))][0]")}"
[ -n "$PREVIOUS" ] || { echo "No previous $MAJOR.x release" >&2; exit 1; }
BASE_IMAGE="${BASE_IMAGE:-yontrack/yontrack:$APP_VERSION}"
# Another repository, same tag: the UI image follows the tag of the backend image
TEST_REPOSITORY=upgrade-test.local/yontrack
TEST_IMAGE="$TEST_REPOSITORY:$APP_VERSION"

mkdir -p "$OUT"
FAILED=0

log() {
    echo "[upgrade-test] $*"
}

fail() {
    echo "[upgrade-test] FAILED: $*"
    FAILED=1
}

# Runs SQL on the Yontrack database
sql() {
    "${KUBECTL[@]}" exec "$RELEASE-postgresql-0" -- env PGPASSWORD=ontrack psql -U ontrack -d ontrack -tAc "$1"
}

# Logs of the load pod (read whole: a `grep -q` in a pipe would fail it with SIGPIPE under pipefail)
load_logs() {
    "${KUBECTL[@]}" logs upgrade-test-load 2> /dev/null || true
}

diagnostics() {
    log "Diagnostics in $OUT"
    "${KUBECTL[@]}" get all,events -o wide > "$OUT/resources.txt" 2>&1 || true
    "${KUBECTL[@]}" logs "deployment/$BACKEND" --all-containers --tail=-1 > "$OUT/backend.log" 2>&1 || true
    "${KUBECTL[@]}" logs "deployment/$BACKEND-ui" --tail=-1 > "$OUT/ui.log" 2>&1 || true
    load_logs > "$OUT/load.log"
}

on_exit() {
    local code=$?
    if [ $code -ne 0 ] || [ $FAILED -ne 0 ]; then
        diagnostics
    fi
}
trap on_exit EXIT

log "Mode $MODE: chart $PREVIOUS -> $CURRENT, backend image $BASE_IMAGE + test migrations"

if ! grep -qx "$CLUSTER" <<< "$(kind get clusters)"; then
    kind create cluster --name "$CLUSTER" --wait 120s
fi

log "Test image $TEST_IMAGE"
docker build -q --platform "${IMAGE_PLATFORM:-linux/amd64}" --build-arg "BASE_IMAGE=$BASE_IMAGE" -t "$TEST_IMAGE" "$DIR"
kind load docker-image "$TEST_IMAGE" --name "$CLUSTER"

kubectl --context "kind-$CLUSTER" delete namespace "$NS" --ignore-not-found --wait
kubectl --context "kind-$CLUSTER" create namespace "$NS"

log "Installing the chart $PREVIOUS"
"${HELM[@]}" install "$RELEASE" oci://registry-1.docker.io/yontrack/yontrack-chart --version "$PREVIOUS" \
    -f "$DIR/values.yaml" --set ontrack.zeroDowntimeUpgrades=$ZDU --wait --timeout 20m

if [ "$MODE" = rolling ]; then
    log "Starting the load"
    "${KUBECTL[@]}" create configmap upgrade-test-load --from-file="$DIR/load.sh"
    "${KUBECTL[@]}" apply -f "$DIR/load-pod.yaml"
    for _ in $(seq 1 120); do
        logs=$(load_logs)
        grep -qx READY <<< "$logs" && break
        grep -q '^ERROR' <<< "$logs" && break
        sleep 5
    done
    grep -qx READY <<< "$(load_logs)" || { fail "the load did not start"; exit 1; }
    # Lets the loops warm up on the previous version
    sleep 20

    # The hook Job is deleted once succeeded: its logs are followed as soon as it starts
    (
        for _ in $(seq 1 1200); do
            if "${KUBECTL[@]}" logs -f "job/$JOB" > "$OUT/contract-job.log" 2> /dev/null; then
                break
            fi
            sleep 1
        done
    ) &
    JOB_LOGS=$!
fi

log "Upgrading to the chart of this checkout ($CURRENT)"
UPGRADE=0
"${HELM[@]}" upgrade "$RELEASE" "$CHART" \
    -f "$DIR/values.yaml" --set ontrack.zeroDowntimeUpgrades=$ZDU --set image.repository=$TEST_REPOSITORY \
    --wait --timeout 20m || UPGRADE=$?
[ $UPGRADE -eq 0 ] || fail "helm upgrade exited with $UPGRADE"

"${KUBECTL[@]}" rollout status "deployment/$BACKEND" --timeout 60s || fail "the backend is not rolled out"
[ "$("${KUBECTL[@]}" get "deployment/$BACKEND" -o jsonpath='{.spec.template.spec.containers[0].image}')" = "$TEST_IMAGE" ] \
    || fail "the backend does not run $TEST_IMAGE"

if [ "$MODE" = rolling ]; then
    log "Stopping the load"
    "${KUBECTL[@]}" exec upgrade-test-load -- touch /tmp/stop
    for _ in $(seq 1 30); do
        grep -qx DONE <<< "$(load_logs)" && break
        sleep 2
    done
    load_logs > "$OUT/load.log"
    grep '^SUMMARY' "$OUT/load.log" || true
    for kind in query mutation ui; do
        summary=$(grep "^SUMMARY $kind " "$OUT/load.log" || true)
        if [ -z "$summary" ]; then
            fail "no summary for the $kind requests"
        elif ! [[ "$summary" =~ ok=[1-9][0-9]*\ failed=0$ ]]; then
            fail "$summary"
        fi
    done
    if grep -q '^FAIL' "$OUT/load.log"; then
        log "Failed requests:"
        grep '^FAIL' "$OUT/load.log" | head -50
    fi

    log "Contract migrations Job"
    wait "$JOB_LOGS" || true
    [ -n "$("${KUBECTL[@]}" get events --field-selector "involvedObject.kind=Job,involvedObject.name=$JOB,reason=Completed" -o name)" ] \
        || fail "the $JOB Job did not complete"
    grep -F "Contract migration applied: V9002" "$OUT/contract-job.log" || fail "the Job did not apply the contract migration"
    if grep -F "Contract migration applied" <<< "$("${KUBECTL[@]}" logs "deployment/$BACKEND" --tail=-1)"; then
        fail "the backend ran contract migrations at startup"
    fi
else
    log "Migrations at startup"
    "${KUBECTL[@]}" get job "$JOB" > /dev/null 2>&1 && fail "the $JOB Job exists in default mode"
    grep -F "Contract migration applied: V9002" <<< "$("${KUBECTL[@]}" logs "deployment/$BACKEND" --tail=-1)" \
        || fail "the backend did not apply the contract migration at startup"
fi

log "Schema"
[ "$(sql "select count(*) from schema_version where version = '9001' and success")" = 1 ] \
    || fail "the expand migration V9001 is not in schema_version"
[ "$(sql "select string_agg(version, ',' order by installed_rank) from schema_version_contract where success and type = 'SQL'")" = 9002 ] \
    || fail "schema_version_contract does not list the contract migration V9002 alone"
[ "$(sql "select to_regclass('upgrade_test_legacy') is null")" = t ] \
    || fail "the table dropped by the contract migration is still there"

if [ $FAILED -ne 0 ]; then
    log "Upgrade test ($MODE) failed."
    exit 1
fi
log "Upgrade test ($MODE) passed."
