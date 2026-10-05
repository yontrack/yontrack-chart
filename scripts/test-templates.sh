#!/bin/bash
# Assertions on the rendered chart templates.
# Requires helm, jq and yq (mikefarah v4). Run from the repository root.

set -uo pipefail

CHART=charts/yontrack
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

FAILED=0
CURRENT=""

test_case() {
    CURRENT="$1"
    echo "- $CURRENT"
}

fail() {
    echo "  FAILED: $1"
    FAILED=1
}

# Renders the chart with the given values file(s)/flags into $TMP/out.yaml. Stderr goes to $TMP/err.txt.
render() {
    helm template ontrack "$CHART" "$@" > "$TMP/out.yaml" 2> "$TMP/err.txt"
}

# Renders the chart and fails the current test if the rendering does not succeed
render_ok() {
    if ! render "$@"; then
        fail "rendering failed: $(grep -i error "$TMP/err.txt")"
        return 1
    fi
}

# Renders the chart and fails the current test if the rendering does not fail with the given message
render_fails_with() {
    local message="$1"
    shift
    if render "$@"; then
        fail "rendering was expected to fail with: $message"
    elif ! grep -qF -- "$message" "$TMP/err.txt"; then
        fail "expected error '$message', got: $(grep -i error "$TMP/err.txt")"
    fi
}

# Runs a yq expression on the rendered manifests
manifests() {
    yq ea "$1" "$TMP/out.yaml"
}

# Extracts the Keycloak realm JSON from the rendered manifests
realm() {
    manifests 'select(.kind == "ConfigMap" and (.metadata.name | test("-keycloak-settings$"))) | .data["ontrack.json"]'
}

# Checks that a jq expression evaluated on some JSON gives the expected value (compact JSON)
assert_json() {
    local json="$1" expression="$2" expected="$3" actual
    if ! actual=$(jq -c "$expression" <<< "$json" 2>&1); then
        fail "invalid JSON or expression '$expression': $actual"
    elif [ "$actual" != "$expected" ]; then
        fail "$expression: expected $expected, got $actual"
    fi
}

assert_equals() {
    local label="$1" actual="$2" expected="$3"
    if [ "$actual" != "$expected" ]; then
        fail "$label: expected '$expected', got '$actual'"
    fi
}

USERS="$TMP/users.yaml"
cat > "$USERS" <<'EOF'
auth:
  keycloak:
    settings:
      groups:
        - dast-admins
        - dast-readers
      users:
        - username: dast-admin
          email: dast-admin@example.com
          firstName: DAST
          lastName: Admin
          groups:
            - dast-admins
          passwordSecret:
            name: dast-users
            key: admin-password
        - username: dast-reader
          email: dast-reader@example.com
          firstName: DAST
          lastName: O"Reader
          groups:
            - dast-readers
            - dast-admins
          passwordSecret:
            name: dast-users
            key: reader-password
EOF

# Writes a variant of the users values, modified by a yq expression, and prints its path
# (--set on a list index would replace the whole list)
users_with() {
    yq "$1" "$USERS" > "$TMP/users-variant.yaml"
    echo "$TMP/users-variant.yaml"
}

LDAP="$TMP/ldap.yaml"
cat > "$LDAP" <<'EOF'
auth:
  keycloak:
    settings:
      admin:
        enabled: false
    ldap:
      enabled: true
EOF

echo "Keycloak users & groups"

test_case "Default realm has the admin user and no groups"
if render_ok; then
    R=$(realm)
    assert_json "$R" '.groups' '[]'
    assert_json "$R" '[.users[].username]' '["${KEYCLOAK_USER_ADMIN_USERNAME}"]'
    assert_json "$R" '.users[0].credentials' '[{"type":"password","value":"${KEYCLOAK_USER_ADMIN_PASSWORD}"}]'
    assert_equals "users job" "$(manifests 'select(.kind == "Job") | .metadata.name')" ""
fi

test_case "Declared groups and users are rendered in the realm, next to the admin"
if render_ok -f "$USERS"; then
    R=$(realm)
    assert_json "$R" '.groups' '[{"name":"dast-admins","path":"/dast-admins"},{"name":"dast-readers","path":"/dast-readers"}]'
    assert_json "$R" '[.users[].username]' '["${KEYCLOAK_USER_ADMIN_USERNAME}","dast-admin","dast-reader"]'
    assert_json "$R" '.users[1] | {email, firstName, lastName, enabled, emailVerified, groups}' \
        '{"email":"dast-admin@example.com","firstName":"DAST","lastName":"Admin","enabled":true,"emailVerified":true,"groups":["/dast-admins"]}'
    assert_json "$R" '.users[2].lastName' '"O\"Reader"'
    assert_json "$R" '.users[2].groups' '["/dast-readers","/dast-admins"]'
    assert_json "$R" '.users[1].credentials' '[{"type":"password","value":"${KEYCLOAK_USER_0_PASSWORD}"}]'
    assert_json "$R" '.users[2].credentials' '[{"type":"password","value":"${KEYCLOAK_USER_1_PASSWORD}"}]'
fi

test_case "User passwords are set on Keycloak from the secrets"
if render_ok -f "$USERS"; then
    assert_equals "password env" \
        "$(manifests 'select(.kind == "Deployment" and (.metadata.name | test("-keycloak$"))) | .spec.template.spec.containers[0].env[] | select(.name | test("^KEYCLOAK_USER_[0-9]+_PASSWORD$")) | [.name, .valueFrom.secretKeyRef.name, .valueFrom.secretKeyRef.key] | join(" ")')" \
        "KEYCLOAK_USER_0_PASSWORD dast-users admin-password
KEYCLOAK_USER_1_PASSWORD dast-users reader-password"
fi

test_case "Users only, without the admin"
if render_ok -f "$USERS" --set auth.keycloak.settings.admin.enabled=false; then
    assert_json "$(realm)" '[.users[].username]' '["dast-admin","dast-reader"]'
fi

test_case "Groups only"
if render_ok --set 'auth.keycloak.settings.groups={dast-admins}'; then
    assert_json "$(realm)" '.groups' '[{"name":"dast-admins","path":"/dast-admins"}]'
fi

test_case "Missing groups and users are added to an existing realm by a post-install/post-upgrade job"
if render_ok -f "$USERS"; then
    JOB='select(.kind == "Job" and (.metadata.name | test("-keycloak-users$")))'
    assert_equals "hook" "$(manifests "$JOB | .metadata.annotations[\"helm.sh/hook\"]")" "post-install,post-upgrade"
    assert_equals "password env" \
        "$(manifests "$JOB | .spec.template.spec.containers[0].env[] | select(.name | test(\"^KEYCLOAK_USER_[0-9]+_PASSWORD\$\")) | [.name, .valueFrom.secretKeyRef.name, .valueFrom.secretKeyRef.key] | join(\" \")")" \
        "KEYCLOAK_USER_0_PASSWORD dast-users admin-password
KEYCLOAK_USER_1_PASSWORD dast-users reader-password"
    IMPORT=$(manifests "$JOB | .spec.template.spec.containers[0].env[] | select(.name == \"KEYCLOAK_IMPORT\") | .value")
    assert_json "$IMPORT" '.ifResourceExists' '"SKIP"'
    assert_json "$IMPORT" '[.groups[].name]' '["dast-admins","dast-readers"]'
    assert_json "$IMPORT" '[.users[].username]' '["dast-admin","dast-reader"]'
    assert_json "$IMPORT" '.users[1].credentials[0].value' '"${KEYCLOAK_USER_1_PASSWORD}"'
    assert_equals "pod labels" "$(manifests "$JOB | .spec.template.metadata.labels // {} | keys | .[]")" ""
fi

test_case "Users and groups are not compatible with the LDAP"
render_fails_with "cannot be declared when the LDAP is enabled" -f "$USERS" -f "$LDAP"
render_fails_with "cannot be declared when the LDAP is enabled" -f "$LDAP" --set 'auth.keycloak.settings.groups={dast-admins}'

test_case "Users and groups need the provisioning of Keycloak"
render_fails_with "require auth.keycloak.settings.enabled" -f "$USERS" --set auth.keycloak.settings.enabled=false

test_case "A user must belong to declared groups"
render_fails_with "Keycloak user dast-admin: group unknown is not declared" -f "$(users_with '.auth.keycloak.settings.users[0].groups = ["unknown"]')"

test_case "A user needs a password secret"
render_fails_with "Keycloak user dast-admin: passwordSecret.key is required" -f "$(users_with 'del(.auth.keycloak.settings.users[0].passwordSecret.key)')"
render_fails_with "Keycloak user dast-admin: passwordSecret.name is required" -f "$(users_with '.auth.keycloak.settings.users[0].passwordSecret.name = ""')"
render_fails_with "Keycloak user dast-admin: passwordSecret.name is required" -f "$(users_with 'del(.auth.keycloak.settings.users[0].passwordSecret)')"

test_case "A user needs a complete profile"
for field in username email firstName lastName; do
    render_fails_with "Keycloak user #0: $field is required" -f "$(users_with ".auth.keycloak.settings.users[0].$field = \"\"")"
done

test_case "Usernames must be unique"
render_fails_with "Keycloak user dast-admin is declared more than once" -f "$(users_with '.auth.keycloak.settings.users[1].username = "dast-admin"')"

test_case "Group names must be valid"
render_fails_with "Keycloak group a/b: a group name must not be blank nor contain /" --set 'auth.keycloak.settings.groups={a/b}'

echo "Management port"

# Checks that nothing routes to the management port: no Ingress/HTTPRoute backend targets it,
# and the services carrying it are only reachable from inside the cluster.
assert_management_not_routed() {
    local port="$1"
    assert_equals "Ingress backends to the management port" \
        "$(manifests "select(.kind == \"Ingress\") | .. | select(tag == \"!!map\" and has(\"service\")) | .service | select(.port.number == $port or .port.name == \"mgt\" or (.name | test(\"-management\$\")))")" ""
    assert_equals "HTTPRoute" "$(manifests 'select(.kind == "HTTPRoute") | .metadata.name')" ""
    assert_equals "Services exposing the management port outside the cluster" \
        "$(manifests 'select(.kind == "Service" and .spec.type != "ClusterIP" and (.spec.ports[] | .targetPort == 8800)) | .metadata.name')" ""
}

test_case "The management port is never routed (shared service)"
if render_ok; then
    assert_management_not_routed 8800
fi

test_case "The management port is never routed (specific service)"
if render_ok --set management.service.specific=true --set management.service.port=9000; then
    assert_management_not_routed 9000
fi

test_case "The main service can be exposed when the management port has its own service"
if render_ok --set management.service.specific=true --set service.type=LoadBalancer; then
    assert_management_not_routed 8800
fi

test_case "The management port cannot share a non-ClusterIP service"
render_fails_with "management port must never be exposed outside the cluster" --set service.type=LoadBalancer
render_fails_with "management port must never be exposed outside the cluster" --set service.type=NodePort

test_case "The management service must be ClusterIP"
render_fails_with "management port must never be exposed outside the cluster" --set management.service.specific=true --set management.service.type=LoadBalancer

test_case "The management port cannot be the service port"
render_fails_with "management.service.port must be different from service.port" --set management.service.port=8080

echo "Ingress"

# Backend of an Ingress path, as pathType service:port
ingress_backend() {
    manifests "select(.kind == \"Ingress\") | .spec.rules[].http.paths[] | select(.path == \"$1\") | .pathType + \" \" + .backend.service.name + \":\" + (.backend.service.port.number | tostring)"
}

test_case "The backend APIs are routed to the Yontrack service"
if render_ok; then
    for path in /graphql /hook /rest/extension/audit-trail; do
        assert_equals "$path" "$(ingress_backend "$path")" "Prefix ontrack-yontrack-chart:8080"
    done
    assert_equals "/" "$(ingress_backend /)" "Prefix ontrack-yontrack-chart-ui:3000"
fi

test_case "Only the audit trail is routed under /rest"
if render_ok; then
    assert_equals "/rest paths" \
        "$(manifests 'select(.kind == "Ingress") | .spec.rules[].http.paths[] | select(.path | test("^/rest")) | .path')" \
        "/rest/extension/audit-trail"
fi

test_case "The backend APIs follow the service port"
if render_ok --set service.port=9090; then
    assert_equals "/rest/extension/audit-trail" "$(ingress_backend /rest/extension/audit-trail)" "Prefix ontrack-yontrack-chart:9090"
fi

echo "Elasticsearch"

# Environment variables of the Yontrack container whose name matches a regex, as NAME=value (or NAME=secret:key)
ontrack_env() {
    manifests "select(.kind == \"StatefulSet\") | .spec.template.spec.containers[] | select(.name == \"yontrack-chart\") | .env[] | select(.name | test(\"$1\")) | .name + \"=\" + (.value // (.valueFrom.secretKeyRef.name + \":\" + .valueFrom.secretKeyRef.key))"
}

test_case "No Elasticsearch by default"
if render_ok; then
    assert_equals "Elasticsearch resources" "$(manifests 'select(.metadata.name | test("elasticsearch")) | .kind + "/" + .metadata.name')" ""
    assert_equals "Elasticsearch init containers" "$(manifests 'select(.kind == "StatefulSet") | .spec.template.spec.initContainers[]?.name | select(test("elasticsearch"))')" ""
    assert_equals "Elasticsearch env" "$(ontrack_env 'ELASTIC')" ""
fi

test_case "Metrics export to Elasticsearch"
if render_ok --set elasticsearch.metrics.enabled=true --set elasticsearch.uris=https://es:9200 --set elasticsearch.username=yontrack --set elasticsearch.existingSecret=es-secret; then
    assert_equals "Elasticsearch env" "$(ontrack_env 'ELASTIC' | sort | tr '\n' ' ')" \
        "ONTRACK_EXTENSION_ELASTIC_METRICS_ENABLED=true ONTRACK_EXTENSION_ELASTIC_METRICS_INDEX_NAME=ontrack_metrics SPRING_ELASTICSEARCH_PASSWORD=es-secret:password SPRING_ELASTICSEARCH_URIS=https://es:9200 SPRING_ELASTICSEARCH_USERNAME=yontrack "
    assert_equals "Elasticsearch resources" "$(manifests 'select(.metadata.name | test("elasticsearch")) | .kind + "/" + .metadata.name')" ""
fi

test_case "Metrics export to Elasticsearch without credentials"
if render_ok --set elasticsearch.metrics.enabled=true --set elasticsearch.uris=https://es:9200; then
    assert_equals "Elasticsearch env" "$(ontrack_env 'ELASTIC' | sort | tr '\n' ' ')" \
        "ONTRACK_EXTENSION_ELASTIC_METRICS_ENABLED=true ONTRACK_EXTENSION_ELASTIC_METRICS_INDEX_NAME=ontrack_metrics SPRING_ELASTICSEARCH_URIS=https://es:9200 "
fi

test_case "Metrics export to Elasticsearch needs the URIs"
render_fails_with "elasticsearch.uris is required when elasticsearch.metrics.enabled is true" --set elasticsearch.metrics.enabled=true

test_case "Elasticsearch is no longer bundled"
render_fails_with "elasticsearch.enabled is no longer supported" --set elasticsearch.enabled=true

echo "Audit trail storage"

STORAGE_ENV='AUDITTRAIL_STORAGE'
MINIO=ontrack-yontrack-chart-minio

# Names of the resources of the bundled MinIO, as Kind/name
minio_resources() {
    yq e 'select(.metadata.name | test("-minio")) | .kind + "/" + .metadata.name' "$TMP/out.yaml" | grep -v '^---$' | sort | tr '\n' ' '
}

test_case "No audit trail storage by default"
if render_ok; then
    assert_equals "Storage env" "$(ontrack_env "$STORAGE_ENV")" ""
    assert_equals "MinIO resources" "$(minio_resources)" ""
fi

test_case "External audit trail storage"
if render_ok \
    --set auditTrail.storage.endpoint=https://fra1.digitaloceanspaces.com \
    --set auditTrail.storage.bucket=evidence \
    --set auditTrail.storage.region=fra1 \
    --set auditTrail.storage.maxSize=100MB \
    --set auditTrail.storage.existingSecret=spaces; then
    assert_equals "Storage env" "$(ontrack_env "$STORAGE_ENV" | sort | tr '\n' ' ')" \
        "ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_ACCESSKEY=spaces:accessKey ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_BUCKET=evidence ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_ENDPOINT=https://fra1.digitaloceanspaces.com ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_MAXSIZE=100MB ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_PATHSTYLE=false ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_REGION=fra1 ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_SECRETKEY=spaces:secretKey "
    assert_equals "MinIO resources" "$(minio_resources)" ""
fi

test_case "External audit trail storage with custom secret keys and path style"
if render_ok \
    --set auditTrail.storage.endpoint=http://s3.local:9000 \
    --set auditTrail.storage.bucket=evidence \
    --set auditTrail.storage.pathStyle=true \
    --set auditTrail.storage.existingSecret=s3 \
    --set auditTrail.storage.accessKeyKey=AWS_ACCESS_KEY_ID \
    --set auditTrail.storage.secretKeyKey=AWS_SECRET_ACCESS_KEY; then
    assert_equals "Storage env" "$(ontrack_env "$STORAGE_ENV" | sort | tr '\n' ' ')" \
        "ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_ACCESSKEY=s3:AWS_ACCESS_KEY_ID ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_BUCKET=evidence ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_ENDPOINT=http://s3.local:9000 ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_PATHSTYLE=true ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_REGION=us-east-1 ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_SECRETKEY=s3:AWS_SECRET_ACCESS_KEY "
fi

test_case "External audit trail storage needs a bucket and a secret"
render_fails_with "auditTrail.storage.bucket is required" \
    --set auditTrail.storage.endpoint=http://s3.local:9000 --set auditTrail.storage.existingSecret=s3
render_fails_with "auditTrail.storage.existingSecret is required" \
    --set auditTrail.storage.endpoint=http://s3.local:9000 --set auditTrail.storage.bucket=evidence

# Value of an env variable of the bundled MinIO container, or its secret reference
minio_env() {
    manifests "select(.kind == \"StatefulSet\" and .metadata.name == \"$MINIO\") | .spec.template.spec.containers[0].env[] | select(.name == \"$1\") | .value // (.valueFrom.secretKeyRef.name + \":\" + .valueFrom.secretKeyRef.key)"
}

test_case "Bundled MinIO for the audit trail storage"
if render_ok --set auditTrail.minio.enabled=true; then
    assert_equals "MinIO resources" "$(minio_resources)" \
        "ConfigMap/$MINIO PersistentVolumeClaim/$MINIO Secret/$MINIO Service/$MINIO StatefulSet/$MINIO "
    assert_equals "Storage env" "$(ontrack_env "$STORAGE_ENV" | sort | tr '\n' ' ')" \
        "ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_ACCESSKEY=$MINIO:rootUser ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_BUCKET=yontrack-audit-trail ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_ENDPOINT=http://$MINIO:9000 ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_PATHSTYLE=true ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_REGION=us-east-1 ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_SECRETKEY=$MINIO:rootPassword "
    assert_equals "MinIO credentials" \
        "$(manifests "select(.kind == \"Secret\" and .metadata.name == \"$MINIO\") | .data | keys | sort | join(\",\")")" "rootPassword,rootUser"
    assert_equals "MinIO root user" "$(minio_env MINIO_ROOT_USER)" "$MINIO:rootUser"
    assert_equals "MinIO root password" "$(minio_env MINIO_ROOT_PASSWORD)" "$MINIO:rootPassword"
    assert_equals "MinIO bucket" "$(minio_env YONTRACK_MINIO_BUCKET)" "yontrack-audit-trail"
    assert_equals "MinIO volume" \
        "$(manifests "select(.kind == \"StatefulSet\" and .metadata.name == \"$MINIO\") | .spec.template.spec.volumes[] | select(.persistentVolumeClaim) | .persistentVolumeClaim.claimName")" "$MINIO"
fi

test_case "Bundled MinIO with an existing secret"
if render_ok --set auditTrail.minio.enabled=true --set auditTrail.minio.existingSecret=minio-root \
    --set auditTrail.minio.rootUserKey=user --set auditTrail.minio.rootPasswordKey=password; then
    assert_equals "MinIO resources" "$(minio_resources)" \
        "ConfigMap/$MINIO PersistentVolumeClaim/$MINIO Service/$MINIO StatefulSet/$MINIO "
    assert_equals "Storage credentials" "$(ontrack_env "${STORAGE_ENV}_(ACCESS|SECRET)KEY" | sort | tr '\n' ' ')" \
        "ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_ACCESSKEY=minio-root:user ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_SECRETKEY=minio-root:password "
    assert_equals "MinIO root user" "$(minio_env MINIO_ROOT_USER)" "minio-root:user"
    assert_equals "MinIO root password" "$(minio_env MINIO_ROOT_PASSWORD)" "minio-root:password"
fi

test_case "Bundled MinIO with its own bucket and a maximum size"
if render_ok --set auditTrail.minio.enabled=true --set auditTrail.minio.bucket=other --set auditTrail.storage.maxSize=10MB; then
    assert_equals "Storage env" "$(ontrack_env "${STORAGE_ENV}_(BUCKET|MAXSIZE)" | sort | tr '\n' ' ')" \
        "ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_BUCKET=other ONTRACK_EXTENSION_AUDITTRAIL_STORAGE_MAXSIZE=10MB "
    assert_equals "MinIO bucket" "$(minio_env YONTRACK_MINIO_BUCKET)" "other"
fi

test_case "Bundled MinIO cannot be mixed with an external storage"
render_fails_with "auditTrail.minio.enabled cannot be combined with auditTrail.storage.endpoint" \
    --set auditTrail.minio.enabled=true --set auditTrail.storage.endpoint=https://s3.example \
    --set auditTrail.storage.bucket=evidence --set auditTrail.storage.existingSecret=s3
render_fails_with "auditTrail.storage.bucket cannot be set with the bundled MinIO" \
    --set auditTrail.minio.enabled=true --set auditTrail.storage.bucket=evidence
render_fails_with "auditTrail.storage.existingSecret cannot be set with the bundled MinIO" \
    --set auditTrail.minio.enabled=true --set auditTrail.storage.existingSecret=s3

echo "Probes"

# Settings of a probe of the Yontrack container, as initialDelaySeconds/periodSeconds/timeoutSeconds/failureThreshold
ontrack_probe() {
    manifests "select(.kind == \"StatefulSet\") | .spec.template.spec.containers[] | select(.name == \"yontrack-chart\") | .$1 | [.initialDelaySeconds, .periodSeconds, .timeoutSeconds, .failureThreshold] | join(\"/\")"
}

test_case "Default probes leave enough time for the first start"
if render_ok; then
    assert_equals "startup probe" "$(ontrack_probe startupProbe)" "30/10/5/36"
    assert_equals "liveness probe" "$(ontrack_probe livenessProbe)" "60/60/5/3"
    assert_equals "readiness probe" "$(ontrack_probe readinessProbe)" "60/60/5/3"
fi

test_case "Probes are configurable"
if render_ok \
    --set ontrack.probes.startup.initialDelaySeconds=1 --set ontrack.probes.startup.periodSeconds=2 \
    --set ontrack.probes.startup.timeoutSeconds=3 --set ontrack.probes.startup.failureThreshold=4 \
    --set ontrack.probes.liveness.initialDelaySeconds=5 --set ontrack.probes.liveness.periodSeconds=6 \
    --set ontrack.probes.liveness.timeoutSeconds=7 --set ontrack.probes.liveness.failureThreshold=8 \
    --set ontrack.probes.readiness.initialDelaySeconds=9 --set ontrack.probes.readiness.periodSeconds=10 \
    --set ontrack.probes.readiness.timeoutSeconds=11 --set ontrack.probes.readiness.failureThreshold=12; then
    assert_equals "startup probe" "$(ontrack_probe startupProbe)" "1/2/3/4"
    assert_equals "liveness probe" "$(ontrack_probe livenessProbe)" "5/6/7/8"
    assert_equals "readiness probe" "$(ontrack_probe readinessProbe)" "9/10/11/12"
fi

if [ $FAILED -eq 1 ]; then
    echo "Some template tests failed."
    exit 1
else
    echo "All template tests passed."
fi
