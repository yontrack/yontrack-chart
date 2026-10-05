#!/bin/sh
#
# Entry point of the bundled MinIO-compatible storage (Silo): starts the
# server, creates the bucket named by YONTRACK_MINIO_BUCKET once the server
# answers, and then stays in the foreground with it.
#
# The readiness probe looks for the marker below, so the service is only
# ready once its bucket exists, without any Helm hook.
#
# Adapted from yontrack/yontrack's compose/minio/start.sh.

set -eu

: "${YONTRACK_MINIO_BUCKET:?the bucket to create}"

READY=/tmp/yontrack-bucket-ready
rm -f "$READY"

silo server /data --address :9000 --console-address :9001 &
server=$!

# Forwarded, so that the pod stops gracefully
trap 'kill -TERM "$server" 2>/dev/null' TERM INT

attempts=0
until mcli alias set local http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1; do
    # Server gone (stopped by the trap, or crashed): no point in waiting for it
    if ! kill -0 "$server" 2>/dev/null; then
        wait "$server"
        exit $?
    fi
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 60 ]; then
        echo "MinIO did not answer within 60s" >&2
        kill -TERM "$server" 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

mcli mb --ignore-existing "local/$YONTRACK_MINIO_BUCKET"
touch "$READY"

# The container lives and dies with the server. `wait` returns early when the
# trap fires, so the server is waited for again until it has really stopped.
set +e
wait "$server"
status=$?
if kill -0 "$server" 2>/dev/null; then
    wait "$server"
    status=$?
fi
exit "$status"
