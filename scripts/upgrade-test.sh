#!/bin/bash
# Upgrade test on a kind cluster (#151): installs the previous published chart, then upgrades it to the
# chart of this checkout, with a backend image which has one pending expand and one pending contract
# migration (scripts/upgrade-test/Dockerfile).
#
#   ./scripts/upgrade-test.sh rolling   # ontrack.zeroDowntimeUpgrades: true, under load: no request may fail,
#                                       # and the hook Job runs the contract migration
#   ./scripts/upgrade-test.sh default   # default mode: the pod comes back, both migrations ran at startup
#   ./scripts/upgrade-test.sh ha        # as rolling, with two backends and two UIs on two workers (#169), then,
#                                       # still under load: a node drain (no request may fail) and the unplanned
#                                       # loss of a backend pod (only the requests in flight on it, or within 10 s,
#                                       # may fail; Quartz leaves no job running on it)
#
# Requires docker, kind, kubectl, helm, yq and gh (for the previous release). Run from the repository root.
#
# Environment:
#   KIND_CLUSTER            kind cluster to use (default: yt-upgrade, yt-ha in ha mode), created if missing
#   PREVIOUS_CHART_VERSION  chart to upgrade from (default: the latest GitHub release of the same major, other than this version)
#   BASE_IMAGE              backend image to add the test migrations to (default: yontrack/yontrack:<appVersion>)
#   IMAGE_PLATFORM          platform of the test image (default: linux/amd64)
#   OUT                     directory of the logs and reports (default: build/upgrade-test)

set -euo pipefail

MODE="${1:-}"
case "$MODE" in
    rolling) ZDU=true LOAD=true ;;
    default) ZDU=false LOAD=false ;;
    ha) ZDU=true LOAD=true ;;
    *) echo "Usage: $0 rolling|default|ha" >&2; exit 2 ;;
esac

CHART=charts/yontrack
DIR=scripts/upgrade-test
if [ "$MODE" = ha ]; then
    CLUSTER="${KIND_CLUSTER:-yt-ha}"
else
    CLUSTER="${KIND_CLUSTER:-yt-upgrade}"
fi
NS=upgrade-test
RELEASE=yt
BACKEND="$RELEASE-yontrack-chart"
JOB="$BACKEND-contract-migrations"
BACKEND_PODS="app.kubernetes.io/name=yontrack-chart,app.kubernetes.io/instance=$RELEASE"
UI_PODS="app.kubernetes.io/name=yontrack-chart-ui,app.kubernetes.io/instance=$RELEASE"
# Label of the worker running the single-instance services in ha mode, never drained (kind-ha.yaml)
SERVICES_LABEL=upgrade-test/services
# Seconds after the loss of a backend within which the requests must succeed again (ha mode)
WINDOW=10
OUT="${OUT:-build/upgrade-test}"
KUBECTL_CLUSTER=(kubectl --context "kind-$CLUSTER")
KUBECTL=("${KUBECTL_CLUSTER[@]}" -n "$NS")
HELM=(helm --kube-context "kind-$CLUSTER" -n "$NS")
VALUES=(-f "$DIR/values.yaml" --set "ontrack.zeroDowntimeUpgrades=$ZDU")
[ "$MODE" != ha ] || VALUES+=(-f "$DIR/values-ha.yaml")

CURRENT=$(yq -r .version "$CHART/Chart.yaml")
APP_VERSION=$(yq -r .appVersion "$CHART/Chart.yaml")
# Same major only: the other release lines (v5) are published elsewhere, and a major upgrade may have downtime
MAJOR="${CURRENT%%.*}"
PREVIOUS="${PREVIOUS_CHART_VERSION:-$(gh release list --exclude-drafts --limit 100 --json tagName --jq "[.[].tagName | select(. != \"$CURRENT\" and startswith(\"$MAJOR.\"))][0]")}"
[ -n "$PREVIOUS" ] || { echo "No previous $MAJOR.x release" >&2; exit 1; }
BASE_IMAGE="${BASE_IMAGE:-yontrack/yontrack:$APP_VERSION}"
# Documented outage of the upgrade to this version, if any (failed requests are then expected)
DISRUPTION=$(awk -v v="$CURRENT" '$1 == v { $1 = ""; sub(/^ +/, ""); print }' "$DIR/disruptive.txt")
# Another repository, same tag: the UI image follows the tag of the backend image
TEST_REPOSITORY=upgrade-test.local/yontrack
TEST_IMAGE="$TEST_REPOSITORY:$APP_VERSION"
# Phases, in epoch seconds of the load pod (see failures.awk): ends of the upgrade and of the drain, and just before
# the loss of a backend
UPGRADED=""
DRAINED=""
KILLED=""

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

# Current time of the load pod, in epoch seconds: the clock of the requests it logs
load_now() {
    "${KUBECTL[@]}" exec upgrade-test-load -- date +%s
}

# Runs a GraphQL query on the backend from the load pod, with its token
graphql() {
    # shellcheck disable=SC2016 # Expanded in the pod
    "${KUBECTL[@]}" exec upgrade-test-load -- sh -c 'curl -sS --max-time 10 -X POST -H "Content-Type: application/json" \
        -H "X-Ontrack-Token: $(cat /tmp/token)" --data "$1" "$BACKEND/graphql"' sh "{\"query\":\"$1\"}"
}

JOBS_QUERY="{ jobs(size: 1000) { pageItems { description runningOn } } }"

# Running jobs, as "<pod> <description>" lines
running_jobs() {
    yq -p json -r '.data.jobs.pageItems[] | select(.runningOn != null) | .runningOn + " " + .description' <<< "$(graphql "$JOBS_QUERY")"
}

# Number of Quartz instances named after a pod (0 once Quartz has recovered a lost one)
quartz_instances() {
    sql "select count(*) from qrtz_scheduler_state where instance_name = '$1'"
}

# Pods matching a selector, as "<pod> <node>" lines
placement() {
    "${KUBECTL[@]}" get pods -l "$1" --field-selector status.phase=Running \
        -o jsonpath='{range .items[*]}{.metadata.name} {.spec.nodeName}{"\n"}{end}'
}

# Logs of all the pods matching a selector
pod_logs() {
    "${KUBECTL[@]}" logs -l "$1" --all-containers --prefix --tail=-1 --max-log-requests 10
}

diagnostics() {
    log "Diagnostics in $OUT"
    "${KUBECTL_CLUSTER[@]}" get nodes -o wide > "$OUT/nodes.txt" 2>&1 || true
    "${KUBECTL[@]}" get all,pdb,events -o wide > "$OUT/resources.txt" 2>&1 || true
    "${KUBECTL[@]}" get events --sort-by=.lastTimestamp \
        -o custom-columns=TIME:.lastTimestamp,REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message > "$OUT/events.txt" 2>&1 || true
    pod_logs "$BACKEND_PODS" > "$OUT/backend.log" 2>&1 || true
    pod_logs "$UI_PODS" > "$OUT/ui.log" 2>&1 || true
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
[ -z "$DISRUPTION" ] || log "Documented outage of the upgrade to $CURRENT: $DISRUPTION"

if ! grep -qx "$CLUSTER" <<< "$(kind get clusters)"; then
    if [ "$MODE" = ha ]; then
        kind create cluster --name "$CLUSTER" --config "$DIR/kind-ha.yaml" --wait 120s
    else
        kind create cluster --name "$CLUSTER" --wait 120s
    fi
fi

if [ "$MODE" = ha ]; then
    [ -n "$("${KUBECTL_CLUSTER[@]}" get nodes -l "$SERVICES_LABEL" -o name)" ] \
        || { echo "The kind cluster $CLUSTER has no node labelled $SERVICES_LABEL: see $DIR/kind-ha.yaml" >&2; exit 1; }
    # The DNS and the volume provisioner of kind run as single instances: kept off the drained worker
    for deployment in kube-system/coredns local-path-storage/local-path-provisioner; do
        "${KUBECTL_CLUSTER[@]}" -n "${deployment%/*}" patch deployment "${deployment#*/}" --type merge \
            -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"$SERVICES_LABEL\":\"true\"}}}}}"
        "${KUBECTL_CLUSTER[@]}" -n "${deployment%/*}" rollout status deployment "${deployment#*/}" --timeout 120s
    done
fi

log "Test image $TEST_IMAGE"
docker build -q --platform "${IMAGE_PLATFORM:-linux/amd64}" --build-arg "BASE_IMAGE=$BASE_IMAGE" -t "$TEST_IMAGE" "$DIR"
kind load docker-image "$TEST_IMAGE" --name "$CLUSTER"

"${KUBECTL_CLUSTER[@]}" delete namespace "$NS" --ignore-not-found --wait
"${KUBECTL_CLUSTER[@]}" create namespace "$NS"

log "Installing the chart $PREVIOUS"
"${HELM[@]}" install "$RELEASE" oci://registry-1.docker.io/yontrack/yontrack-chart --version "$PREVIOUS" \
    "${VALUES[@]}" --wait --timeout 20m
if [ "$MODE" = ha ]; then
    # A chart without ontrack.replicas runs one backend: the upgrade then goes from one to two
    log "Backends of the chart $PREVIOUS: $("${KUBECTL[@]}" get "deployment/$BACKEND" -o jsonpath='{.status.readyReplicas}')"
fi

if [ "$LOAD" = true ]; then
    log "Starting the load"
    "${KUBECTL[@]}" create configmap upgrade-test-load --from-file="$DIR/load.sh"
    if [ "$MODE" = ha ]; then
        yq ".spec.nodeSelector.\"$SERVICES_LABEL\" = \"true\"" "$DIR/load-pod.yaml" | "${KUBECTL[@]}" apply -f -
    else
        "${KUBECTL[@]}" apply -f "$DIR/load-pod.yaml"
    fi
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
"${HELM[@]}" upgrade "$RELEASE" "$CHART" "${VALUES[@]}" --set image.repository=$TEST_REPOSITORY \
    --wait --timeout 20m || UPGRADE=$?
[ $UPGRADE -eq 0 ] || fail "helm upgrade exited with $UPGRADE"

"${KUBECTL[@]}" rollout status "deployment/$BACKEND" --timeout 60s || fail "the backend is not rolled out"
[ "$("${KUBECTL[@]}" get "deployment/$BACKEND" -o jsonpath='{.spec.template.spec.containers[0].image}')" = "$TEST_IMAGE" ] \
    || fail "the backend does not run $TEST_IMAGE"
[ "$LOAD" = false ] || UPGRADED=$(load_now)

if [ "$MODE" = ha ]; then
    log "Node drain"
    NODE=$("${KUBECTL_CLUSTER[@]}" get nodes -l "!$SERVICES_LABEL,!node-role.kubernetes.io/control-plane" -o jsonpath='{.items[0].metadata.name}')
    placement "$BACKEND_PODS"
    placement "$UI_PODS"
    # The rollout spreads the new backends among themselves, whatever the old ones did (#179). Only the pods of the
    # current ReplicaSet: the old ones may still be terminating.
    HASH=$("${KUBECTL[@]}" get pods -l "$BACKEND_PODS" --sort-by=.metadata.creationTimestamp \
        -o jsonpath='{range .items[*]}{.metadata.labels.pod-template-hash}{"\n"}{end}' | tail -1)
    if [ -n "$(placement "$BACKEND_PODS,pod-template-hash=$HASH" | awk '{ print $2 }' | sort | uniq -d)" ]; then
        fail "the backends of the rollout share a node"
    fi
    if ! awk -v node="$NODE" '$2 == node { found = 1 } END { exit !found }' <<< "$(placement "$BACKEND_PODS")"; then
        fail "no backend runs on $NODE: the backends are not spread across the workers"
    else
        DRAIN=0
        "${KUBECTL_CLUSTER[@]}" drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout 10m || DRAIN=$?
        [ $DRAIN -eq 0 ] || fail "the drain of $NODE exited with $DRAIN"
        # The evicted backend waits for a node, the other one serving: with one worker left, below minDomains (2), its
        # node cannot take a second backend (#181)
        sleep 15
        SCHEDULED=$("${KUBECTL[@]}" get pods -l "$BACKEND_PODS" \
            -o jsonpath='{range .items[*]}{.metadata.name} {.spec.nodeName}{"\n"}{end}')
        echo "$SCHEDULED"
        [ "$(awk 'NF == 2' <<< "$SCHEDULED" | wc -l | tr -d ' ')" = 1 ] \
            || fail "the evicted backend did not wait for a node: the backends share the remaining worker"
        "${KUBECTL_CLUSTER[@]}" uncordon "$NODE"
        "${KUBECTL[@]}" rollout status "deployment/$BACKEND" --timeout 5m || fail "the backend is not available again after the drain"
        "${KUBECTL[@]}" rollout status "deployment/$BACKEND-ui" --timeout 5m || fail "the UI is not available again after the drain"
    fi
    DRAINED=$(load_now)

    log "Unplanned loss of a backend"
    # Lets the loops run on the drained topology first
    sleep 20
    BACKENDS=$(placement "$BACKEND_PODS" | awk '{ print $1 }')
    [ -n "$BACKENDS" ] || { fail "no backend runs"; exit 1; }
    # A backend running a job, so that Quartz has a run to recover: the jobs are short, one may not show up
    LOST=""
    for _ in $(seq 1 60); do
        LOST=$(running_jobs | awk '{ print $1 }' | grep -Fx -f <(echo "$BACKENDS") | head -1 || true)
        [ -z "$LOST" ] || break
        sleep 1
    done
    if [ -n "$LOST" ]; then
        log "Jobs running on $LOST at its loss:"
        running_jobs | grep "^$LOST " || true
    else
        LOST=$(head -1 <<< "$BACKENDS")
        log "No job running at the loss of $LOST: only the recovery of its Quartz instance is checked"
    fi
    [ "$(quartz_instances "$LOST")" = 1 ] || fail "$LOST is not a Quartz instance"
    KILLED=$(load_now)
    "${KUBECTL[@]}" delete pod "$LOST" --grace-period=0 --force

    log "Recovery"
    # A request of each kind started after the window succeeds: failures.awk checks that none started after it fails
    RECOVERED=false
    for _ in $(seq 1 60); do
        if [ "$("${KUBECTL[@]}" exec upgrade-test-load -- sh -c \
            "for kind in query mutation ui; do [ \"\$(cat /tmp/\$kind.ok)\" -ge $((KILLED + WINDOW)) ] || exit 1; done && echo yes" 2> /dev/null || true)" = yes ]; then
            RECOVERED=true
            break
        fi
        sleep 2
    done
    [ $RECOVERED = true ] || fail "no successful request of each kind started $WINDOW s after the loss of $LOST"

    log "Recovery of $LOST by Quartz"
    for _ in $(seq 1 60); do
        [ "$(quartz_instances "$LOST")" = 0 ] && break
        sleep 2
    done
    if [ "$(quartz_instances "$LOST")" != 0 ]; then
        fail "Quartz did not recover the instance $LOST"
    else
        JOBS=$(graphql "$JOBS_QUERY")
        if [ "$(yq -p json '.data.jobs.pageItems | length' <<< "$JOBS")" = 0 ]; then
            fail "no job listed: $JOBS"
        elif grep "^$LOST " <<< "$(running_jobs)"; then
            fail "jobs still shown running on $LOST"
        fi
    fi
    "${KUBECTL[@]}" rollout status "deployment/$BACKEND" --timeout 5m || fail "the lost backend is not replaced"
fi

if [ "$LOAD" = true ]; then
    log "Stopping the load"
    "${KUBECTL[@]}" exec upgrade-test-load -- touch /tmp/stop
    for _ in $(seq 1 30); do
        grep -qx DONE <<< "$(load_logs)" && break
        sleep 2
    done
    load_logs > "$OUT/load.log"
    grep '^SUMMARY' "$OUT/load.log" || true
    for kind in query mutation ui; do
        grep -Eq "^SUMMARY $kind ok=[1-9]" "$OUT/load.log" || fail "no successful $kind request"
    done
    awk -v upgraded="$UPGRADED" -v drained="$DRAINED" -v killed="$KILLED" -v window="$WINDOW" -v disruption="$DISRUPTION" \
        -f "$DIR/failures.awk" "$OUT/load.log" > "$OUT/failures.txt"
    if [ -s "$OUT/failures.txt" ]; then
        log "Failed requests by phase:"
        awk '{ print $1, $2 }' "$OUT/failures.txt" | sort | uniq -c
        [ -z "$DISRUPTION" ] || ! grep -q '^upgrade tolerated' "$OUT/failures.txt" || log "Expected during the upgrade: $DISRUPTION"
        head -50 "$OUT/failures.txt"
        FAILURES=$(awk '$2 == "failed"' "$OUT/failures.txt" | wc -l | tr -d ' ')
        [ "$FAILURES" = 0 ] || fail "$FAILURES failed request(s)"
    fi

    log "Contract migrations Job"
    wait "$JOB_LOGS" || true
    [ -n "$("${KUBECTL[@]}" get events --field-selector "involvedObject.kind=Job,involvedObject.name=$JOB,reason=Completed" -o name)" ] \
        || fail "the $JOB Job did not complete"
    grep -F "Contract migration applied: V9002" "$OUT/contract-job.log" || fail "the Job did not apply the contract migration"
    if grep -F "Contract migration applied" <<< "$(pod_logs "$BACKEND_PODS")"; then
        fail "the backend ran contract migrations at startup"
    fi
else
    log "Migrations at startup"
    "${KUBECTL[@]}" get job "$JOB" > /dev/null 2>&1 && fail "the $JOB Job exists in default mode"
    grep -F "Contract migration applied: V9002" <<< "$(pod_logs "$BACKEND_PODS")" \
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
