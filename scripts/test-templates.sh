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
    assert_equals "/rest paths outside the audit trail" \
        "$(manifests 'select(.kind == "Ingress") | .spec.rules[].http.paths[] | select(.path | test("^/rest") and (test("^/rest/extension/audit-trail(/|$)") | not)) | .path')" ""
fi

test_case "The backend APIs follow the service port"
if render_ok --set service.port=9090; then
    assert_equals "/rest/extension/audit-trail" "$(ingress_backend /rest/extension/audit-trail)" "Prefix ontrack-yontrack-chart:9090"
    assert_equals "/rest/extension/audit-trail/validation-runs" "$(ingress_backend /rest/extension/audit-trail/validation-runs)" "Prefix ontrack-yontrack-chart:9090"
fi

echo "Upload Ingress"

UPLOADS=ontrack-yontrack-chart-uploads
BACKEND_UPLOADS=/rest/extension/audit-trail/validation-runs
UI_UPLOADS=/api/protected/uploads/audit-trail/validation-runs

# yq selector of an Ingress by name
ingress_named() {
    echo "select(.kind == \"Ingress\" and .metadata.name == \"$1\")"
}

# Annotation of an Ingress
ingress_annotation() {
    manifests "$(ingress_named "$1") | .metadata.annotations[\"$2\"]"
}

# Paths of an Ingress, as path pathType service:port
ingress_paths() {
    manifests "$(ingress_named "$1") | .spec.rules[].http.paths[] | .path + \" \" + .pathType + \" \" + .backend.service.name + \":\" + (.backend.service.port.number | tostring)"
}

test_case "The upload paths have their own Ingress, with a body size following the default maximum size"
if render_ok; then
    assert_equals "upload paths" "$(ingress_paths "$UPLOADS")" \
        "$BACKEND_UPLOADS Prefix ontrack-yontrack-chart:8080
$UI_UPLOADS Prefix ontrack-yontrack-chart-ui:3000"
    assert_equals "body size" "$(ingress_annotation "$UPLOADS" nginx.ingress.kubernetes.io/proxy-body-size)" "51m"
    assert_equals "request buffering" "$(ingress_annotation "$UPLOADS" nginx.ingress.kubernetes.io/proxy-request-buffering)" "off"
fi

test_case "The upload body size follows the maximum size of an evidence file, plus 1 MB"
for case in 100MB:101m 1GB:1025m 512KB:2m 1048576B:2m 31457280:31m 10mb:11m; do
    if render_ok --set-string "auditTrail.storage.maxSize=${case%%:*}"; then
        assert_equals "body size for ${case%%:*}" "$(ingress_annotation "$UPLOADS" nginx.ingress.kubernetes.io/proxy-body-size)" "${case##*:}"
    fi
done

test_case "The upload body size follows a maximum size given as a number of bytes"
printf 'auditTrail:\n  storage:\n    maxSize: 104857600\n' > "$TMP/max-size.yaml"
if render_ok -f "$TMP/max-size.yaml"; then
    assert_equals "body size" "$(ingress_annotation "$UPLOADS" nginx.ingress.kubernetes.io/proxy-body-size)" "101m"
fi

test_case "The upload body size follows the maximum size of the bundled MinIO"
if render_ok --set auditTrail.minio.enabled=true --set auditTrail.storage.maxSize=10MB; then
    assert_equals "body size" "$(ingress_annotation "$UPLOADS" nginx.ingress.kubernetes.io/proxy-body-size)" "11m"
fi

test_case "The maximum size of an evidence file must be a size"
render_fails_with "auditTrail.storage.maxSize must be a size like 50MB" --set auditTrail.storage.maxSize=50Mo
render_fails_with "auditTrail.storage.maxSize must be a size like 50MB" --set auditTrail.storage.maxSize=-1MB

test_case "The upload annotations override the default ones, for other ingress controllers"
if render_ok --set-string 'ingress.uploads.annotations.nginx\.ingress\.kubernetes\.io/proxy-body-size=200m' \
    --set-string 'ingress.uploads.annotations.traefik\.ingress\.kubernetes\.io/router\.middlewares=yontrack-uploads@kubernetescrd'; then
    assert_equals "body size" "$(ingress_annotation "$UPLOADS" nginx.ingress.kubernetes.io/proxy-body-size)" "200m"
    assert_equals "extra annotation" "$(ingress_annotation "$UPLOADS" traefik.ingress.kubernetes.io/router.middlewares)" "yontrack-uploads@kubernetescrd"
    assert_equals "main body size" "$(ingress_annotation ontrack-yontrack-chart nginx.ingress.kubernetes.io/proxy-body-size)" "null"
fi

test_case "The upload Ingress shares the class, host, TLS and annotations of the main Ingress, except the certificate issuance"
if render_ok --set ingress.ingressClassName=nginx --set ingress.host=yontrack.example.com --set ingress.tls.secretName=yontrack-tls \
    --set-string 'ingress.annotations.nginx\.ingress\.kubernetes\.io/whitelist-source-range=10.0.0.0/8' \
    --set-string 'ingress.annotations.nginx\.ingress\.kubernetes\.io/proxy-body-size=8m' \
    --set-string 'ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt' \
    --set-string 'ingress.annotations.kubernetes\.io/tls-acme=true'; then
    INGRESS_SPEC='.spec.ingressClassName + " " + .spec.rules[0].host + " " + (.spec.tls | to_json(0))'
    assert_equals "class, host & TLS" \
        "$(manifests "$(ingress_named "$UPLOADS") | $INGRESS_SPEC")" \
        "$(manifests "$(ingress_named ontrack-yontrack-chart) | $INGRESS_SPEC")"
    assert_equals "upload annotations" "$(manifests "$(ingress_named "$UPLOADS") | .metadata.annotations | to_entries | map(.key + \"=\" + .value) | sort | join(\" \")")" \
        "nginx.ingress.kubernetes.io/proxy-body-size=51m nginx.ingress.kubernetes.io/proxy-request-buffering=off nginx.ingress.kubernetes.io/whitelist-source-range=10.0.0.0/8"
    assert_equals "main body size" "$(ingress_annotation ontrack-yontrack-chart nginx.ingress.kubernetes.io/proxy-body-size)" "8m"
fi

test_case "The upload Ingress can be disabled, the upload paths being then served by the main Ingress"
if render_ok --set ingress.uploads.enabled=false; then
    assert_equals "Ingresses" "$(manifests '[select(.kind == "Ingress") | .metadata.name] | join(" ")')" "ontrack-yontrack-chart"
fi

test_case "The main Ingress keeps the default body size"
if render_ok; then
    assert_equals "main annotations" "$(manifests "$(ingress_named ontrack-yontrack-chart) | .metadata.annotations | to_json(0)")" "null"
    assert_equals "main paths" "$(ingress_paths ontrack-yontrack-chart | cut -d' ' -f1 | tr '\n' ' ')" \
        "/keycloak /graphql /hook /rest/extension/audit-trail / "
fi

echo "Bitnami sub-charts"

# Each Bitnami sub-chart embeds its own version of the "common" library, and Helm keeps only one definition per
# template name: the image check of RabbitMQ must not depend on another sub-chart lending it a lenient version (#136).
test_case "RabbitMQ renders on its own, with an external Postgres (#136)"
if render_ok --set postgresql.local=false --set postgresql.postgresFromEnv=true; then
    assert_equals "Postgres resources" "$(manifests 'select(.metadata.name | test("postgresql")) | .kind + "/" + .metadata.name')" ""
    assert_equals "RabbitMQ image" "$(manifests 'select(.kind == "StatefulSet" and (.metadata.name | test("rabbitmq"))) | .spec.template.spec.containers[] | select(.name == "rabbitmq") | .image')" \
        "docker.io/bitnamilegacy/rabbitmq:4.1.3-debian-12-r1"
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

echo "Audit trail instance key"

EXTERNAL_KEY_STORE=(
    --set ontrack.config.key_store=secret
    --set ontrack.config.secret_key_store.external.enabled=true
    --set ontrack.config.secret_key_store.external.store.path=yontrack/dev/demo
    --set ontrack.config.secret_key_store.external.store.key=yontrackEncryptionKey
)

# Entries of the key store ExternalSecret, as secretKey=path:property:decodingStrategy
key_store_entries() {
    manifests 'select(.kind == "ExternalSecret" and .metadata.name == "ontrack-ontrack-encryption-key") | .spec.data[] | .secretKey + "=" + .remoteRef.key + ":" + .remoteRef.property + ":" + .remoteRef.decodingStrategy' | tr '\n' ' '
}

test_case "The instance key is not mapped by default"
if render_ok "${EXTERNAL_KEY_STORE[@]}"; then
    assert_equals "Key store entries" "$(key_store_entries)" \
        "net.nemerosa.ontrack.security.EncryptionServiceImpl.encryption=yontrack/dev/demo:yontrackEncryptionKey:Base64 "
fi

test_case "The instance key is mapped from the path of the encryption key by default"
if render_ok "${EXTERNAL_KEY_STORE[@]}" \
    --set ontrack.config.secret_key_store.external.auditTrail.key=yontrackAuditTrailKey; then
    assert_equals "Key store entries" "$(key_store_entries)" \
        "net.nemerosa.ontrack.security.EncryptionServiceImpl.encryption=yontrack/dev/demo:yontrackEncryptionKey:Base64 audit-trail.ed25519=yontrack/dev/demo:yontrackAuditTrailKey:None "
fi

test_case "The instance key is mapped from its own path, with its own decoding"
if render_ok "${EXTERNAL_KEY_STORE[@]}" \
    --set ontrack.config.secret_key_store.external.auditTrail.key=key \
    --set ontrack.config.secret_key_store.external.auditTrail.path=yontrack/dev/audit-trail \
    --set ontrack.config.secret_key_store.external.auditTrail.decodingStrategy=Base64; then
    assert_equals "Key store entries" "$(key_store_entries)" \
        "net.nemerosa.ontrack.security.EncryptionServiceImpl.encryption=yontrack/dev/demo:yontrackEncryptionKey:Base64 audit-trail.ed25519=yontrack/dev/audit-trail:key:Base64 "
fi

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

echo "UI sign-out"

# Environment variables of the UI container whose name matches a regex, as NAME=value
ui_env() {
    manifests "select(.kind == \"Deployment\" and (.metadata.name | test(\"-ui$\"))) | .spec.template.spec.containers[] | select(.name == \"yontrack-chart-ui\") | .env[] | select(.name | test(\"$1\")) | .name + \"=\" + .value"
}

# Renders the NOTES with a client-side install dry-run into $TMP/notes.txt
render_notes() {
    if ! helm install ontrack "$CHART" --dry-run=client "$@" > "$TMP/install.txt" 2> "$TMP/err.txt"; then
        fail "rendering of the notes failed: $(grep -i error "$TMP/err.txt")"
    fi
    sed -n '/^NOTES:/,$p' "$TMP/install.txt" > "$TMP/notes.txt"
    if ! [ -s "$TMP/notes.txt" ]; then
        fail "no notes rendered"
    fi
}

OIDC=(--set auth.kind=oidc --set auth.oidc.issuer=https://idp.example.com --set ontrack.url=https://yontrack.example.com)

test_case "Federated sign-out is enabled by default for OIDC"
if render_ok "${OIDC[@]}"; then
    assert_equals "Sign-out env" "$(ui_env 'SIGNOUT')" "NEXTAUTH_FEDERATED_SIGNOUT=true"
fi

test_case "Federated sign-out can be disabled for OIDC"
if render_ok "${OIDC[@]}" --set auth.oidc.federatedSignOut=false; then
    assert_equals "Sign-out env" "$(ui_env 'SIGNOUT')" "NEXTAUTH_FEDERATED_SIGNOUT=false"
fi

test_case "No federated sign-out setting for Keycloak"
if render_ok --set auth.oidc.federatedSignOut=false; then
    assert_equals "Sign-out env" "$(ui_env 'SIGNOUT')" ""
fi

test_case "The notes name the post-logout redirect URI for OIDC"
render_notes "${OIDC[@]}"
if ! grep -qF "https://yontrack.example.com/api/auth/signout-complete" "$TMP/notes.txt"; then
    fail "post-logout redirect URI not in the notes"
fi

test_case "No post-logout redirect URI in the notes when federated sign-out is disabled"
render_notes "${OIDC[@]}" --set auth.oidc.federatedSignOut=false
if grep -qF "signout-complete" "$TMP/notes.txt"; then
    fail "post-logout redirect URI in the notes"
fi

test_case "No post-logout redirect URI in the notes for Keycloak"
render_notes
if grep -qF "signout-complete" "$TMP/notes.txt"; then
    fail "post-logout redirect URI in the notes"
fi

echo "Keycloak theme"

test_case "The theme archive does not depend on the checkout time, umask or owner (#99)"
for run in 1 2; do
    mkdir -p "$TMP/themes$run"
    cp -R "$CHART/files/themes/yontrack" "$TMP/themes$run/"
done
# Second checkout: later timestamps, other permissions
find "$TMP/themes2" -exec touch -t 203001010000 {} +
chmod -R g+w "$TMP/themes2"
for run in 1 2; do
    if ! THEMES="$TMP/themes$run" ./scripts/build-theme.sh "$TMP/theme$run.tar.gz"; then
        fail "theme archive build failed"
    fi
done
if ! cmp -s "$TMP/theme1.tar.gz" "$TMP/theme2.tar.gz"; then
    fail "the theme archive changes between two checkouts of the same files"
fi

if [ $FAILED -eq 1 ]; then
    echo "Some template tests failed."
    exit 1
else
    echo "All template tests passed."
fi
