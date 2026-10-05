{{/*
Expand the name of the chart.
*/}}
{{- define "ontrack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ontrack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ontrack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ontrack.labels" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels" . }}
{{- if and .Chart.AppVersion .Values.includeVersionLabels }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common labels for mgt server
*/}}
{{- define "ontrack.labels.mgt" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels.mgt" . }}
{{- if and .Chart.AppVersion .Values.includeVersionLabels }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common labels for UI
*/}}
{{- define "ontrack.labels.ui" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels.ui" . }}
{{- if and .Chart.AppVersion .Values.includeVersionLabels }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common labels for Keycloak
*/}}
{{- define "ontrack.labels.keycloak" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels.keycloak" . }}
{{- if and .Chart.AppVersion .Values.includeVersionLabels }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common labels for Keycloak Postgres
*/}}
{{- define "ontrack.labels.keycloak.postgres" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels.keycloak.postgres" . }}
{{- if and .Chart.AppVersion .Values.includeVersionLabels }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common labels for LDAP
*/}}
{{- define "ontrack.labels.ldap" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels.ldap" . }}
{{- if and .Chart.AppVersion .Values.includeVersionLabels }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ontrack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ontrack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for the mgt server
*/}}
{{- define "ontrack.selectorLabels.mgt" -}}
app.kubernetes.io/name: {{ include "ontrack.name" . }}-mgt
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for UI
*/}}
{{- define "ontrack.selectorLabels.ui" -}}
app.kubernetes.io/name: {{ include "ontrack.name" . }}-ui
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for Keycloak
*/}}
{{- define "ontrack.selectorLabels.keycloak" -}}
app.kubernetes.io/name: {{ include "ontrack.name" . }}-keycloak
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for Keycloak Postgres
*/}}
{{- define "ontrack.selectorLabels.keycloak.postgres" -}}
app.kubernetes.io/name: {{ include "ontrack.name" . }}-keycloak-postgres
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for LDAP
*/}}
{{- define "ontrack.selectorLabels.ldap" -}}
app.kubernetes.io/name: {{ include "ontrack.name" . }}-ldap
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ontrack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ontrack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Creating a password or reusing it if already existing in the given secret

Parameters:
  - secretName: (string, required) The name of the secret
  - secretKey: (string, required) The name of the key in the secret
  - context: (object, required) The evalutation context

Usage:
  {{- template "ontrack.secretPassword" (dict "secretName" "my-secret" "secretKey" "password" "context" .) -}}

*/}}
{{- define "ontrack.secretPassword" -}}
{{- $existing := (lookup "v1" "Secret" .context.Release.Namespace .secretName) }}
{{- if $existing }}
  {{- index $existing.data .secretKey | b64dec }}
{{- else }}
  {{- randAlphaNum 32 }}
{{- end }}
{{- end }}

{{/*
Environment variables for the Keycloak bootstrap administrator (master realm)
*/}}
{{- define "ontrack.keycloak.bootstrapAdminEnv" -}}
{{- if .Values.auth.keycloak.bootstrap.bootstrapSecret.enabled }}
- name: KC_BOOTSTRAP_ADMIN_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.keycloak.bootstrap.bootstrapSecret.secretName | quote }}
      key: {{ .Values.auth.keycloak.bootstrap.bootstrapSecret.usernameKey | quote }}
      optional: false
- name: KC_BOOTSTRAP_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.auth.keycloak.bootstrap.bootstrapSecret.secretName | quote }}
      key: {{ .Values.auth.keycloak.bootstrap.bootstrapSecret.passwordKey | quote }}
      optional: false
{{- else }}
- name: KC_BOOTSTRAP_ADMIN_USERNAME
  value: {{ .Values.auth.keycloak.bootstrap.username | quote }}
- name: KC_BOOTSTRAP_ADMIN_PASSWORD
  value: {{ .Values.auth.keycloak.bootstrap.password | quote }}
{{- end }}
{{- end }}

{{/*
Validation of the groups & users declared in auth.keycloak.settings
*/}}
{{- define "ontrack.keycloak.validateUsers" -}}
{{- $settings := .Values.auth.keycloak.settings }}
{{- if or $settings.users $settings.groups }}
  {{- if .Values.auth.keycloak.ldap.enabled }}
    {{- fail "For Keycloak, auth.keycloak.settings.users and groups cannot be declared when the LDAP is enabled." }}
  {{- end }}
  {{- if not $settings.enabled }}
    {{- fail "For Keycloak, auth.keycloak.settings.users and groups require auth.keycloak.settings.enabled." }}
  {{- end }}
{{- end }}
{{- $groups := list }}
{{- range $settings.groups }}
  {{- $group := toString . }}
  {{- if or (not .) (contains "/" $group) }}
    {{- fail (printf "Keycloak group %s: a group name must not be blank nor contain /" $group) }}
  {{- end }}
  {{- $groups = append $groups $group }}
{{- end }}
{{- $usernames := list }}
{{- range $index, $user := $settings.users }}
  {{- range $field := list "username" "email" "firstName" "lastName" }}
    {{- if not (index $user $field) }}
      {{- fail (printf "Keycloak user #%d: %s is required" $index $field) }}
    {{- end }}
  {{- end }}
  {{- if has $user.username $usernames }}
    {{- fail (printf "Keycloak user %s is declared more than once" $user.username) }}
  {{- end }}
  {{- $usernames = append $usernames $user.username }}
  {{- $passwordSecret := $user.passwordSecret | default dict }}
  {{- range $field := list "name" "key" }}
    {{- if not (index $passwordSecret $field) }}
      {{- fail (printf "Keycloak user %s: passwordSecret.%s is required" $user.username $field) }}
    {{- end }}
  {{- end }}
  {{- range $user.groups }}
    {{- if not (has (toString .) $groups) }}
      {{- fail (printf "Keycloak user %s: group %s is not declared in auth.keycloak.settings.groups" $user.username (toString .)) }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Name of the environment variable holding the password of the user at the given index in auth.keycloak.settings.users
*/}}
{{- define "ontrack.keycloak.userPasswordEnvName" -}}
{{- printf "KEYCLOAK_USER_%d_PASSWORD" . }}
{{- end }}

{{/*
Environment variables for the passwords of the users declared in auth.keycloak.settings.users
*/}}
{{- define "ontrack.keycloak.usersPasswordEnv" -}}
{{- range $index, $user := .Values.auth.keycloak.settings.users }}
- name: {{ include "ontrack.keycloak.userPasswordEnvName" $index }}
  valueFrom:
    secretKeyRef:
      name: {{ $user.passwordSecret.name | quote }}
      key: {{ $user.passwordSecret.key | quote }}
      optional: false
{{- end }}
{{- end }}

{{/*
JSON array of the Keycloak groups declared in auth.keycloak.settings.groups
*/}}
{{- define "ontrack.keycloak.groups" -}}
{{- $groups := list }}
{{- range .Values.auth.keycloak.settings.groups }}
  {{- $groups = append $groups (dict "name" (toString .) "path" (printf "/%s" .)) }}
{{- end }}
{{- $groups | toJson }}
{{- end }}

{{/*
JSON array of the Keycloak users declared in auth.keycloak.settings.users.
Passwords are never rendered, only ${KEYCLOAK_USER_<index>_PASSWORD} placeholders.

Parameters:
  - root: (object, required) The root context
  - admin: (bool, required) Including the admin user from auth.keycloak.settings.admin (if enabled)
*/}}
{{- define "ontrack.keycloak.users" -}}
{{- $settings := .root.Values.auth.keycloak.settings }}
{{- $users := list }}
{{- if and .admin $settings.admin.enabled }}
  {{- $users = append $users (dict
      "username" "${KEYCLOAK_USER_ADMIN_USERNAME}"
      "enabled" true
      "email" ($settings.admin.email | default .root.Values.auth.admin.email)
      "firstName" $settings.admin.firstName
      "lastName" $settings.admin.lastName
      "emailVerified" true
      "credentials" (list (dict "type" "password" "value" "${KEYCLOAK_USER_ADMIN_PASSWORD}"))
  ) }}
{{- end }}
{{- range $index, $user := $settings.users }}
  {{- $groups := list }}
  {{- range $user.groups }}
    {{- $groups = append $groups (printf "/%s" .) }}
  {{- end }}
  {{- $users = append $users (dict
      "username" $user.username
      "enabled" true
      "email" $user.email
      "firstName" $user.firstName
      "lastName" $user.lastName
      "emailVerified" true
      "groups" $groups
      "credentials" (list (dict "type" "password" "value" (printf "${%s}" (include "ontrack.keycloak.userPasswordEnvName" $index))))
  ) }}
{{- end }}
{{- $users | toJson }}
{{- end }}

{{/*
Guarantees that the management port is never routed outside the cluster.
The management port (8800) serves unauthenticated endpoints.
*/}}
{{- define "ontrack.management.validate" -}}
{{- if and (not .Values.management.service.specific) (eq (int .Values.management.service.port) (int .Values.service.port)) }}
  {{- fail "management.service.port must be different from service.port: the Ingress routes to the service port, which must never lead to the management port." }}
{{- end }}
{{- if .Values.management.service.specific }}
  {{- if ne .Values.management.service.type "ClusterIP" }}
    {{- fail (printf "The management port must never be exposed outside the cluster: management.service.type must be ClusterIP, not %s." .Values.management.service.type) }}
  {{- end }}
{{- else if ne .Values.service.type "ClusterIP" }}
  {{- fail (printf "The management port must never be exposed outside the cluster: it shares the Yontrack service, whose type must then be ClusterIP, not %s. Set management.service.specific to true to use another service type." .Values.service.type) }}
{{- end }}
{{- end }}

{{/*
Elasticsearch is no longer bundled since 6.0: it is only an optional target for the metrics export.
Fails for 5.x values still expecting a bundled cluster.
*/}}
{{- define "ontrack.elasticsearch.validate" -}}
{{- if .Values.elasticsearch.enabled }}
  {{- fail "elasticsearch.enabled is no longer supported: since 6.0, the chart does not bundle Elasticsearch, which Yontrack only needs for the optional metrics export (elasticsearch.metrics.enabled). See the \"Upgrading to 6.x\" section of the chart README." }}
{{- end }}
{{- end }}

{{/*
Name of the resources of the bundled MinIO
*/}}
{{- define "ontrack.minio.fullname" -}}
{{- printf "%s-minio" (include "ontrack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels for the bundled MinIO
*/}}
{{- define "ontrack.selectorLabels.minio" -}}
app.kubernetes.io/name: {{ include "ontrack.name" . }}-minio
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels for the bundled MinIO
*/}}
{{- define "ontrack.labels.minio" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels.minio" . }}
{{- if and .Chart.AppVersion .Values.includeVersionLabels }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Name of the secret holding the credentials of the bundled MinIO
*/}}
{{- define "ontrack.minio.secretName" -}}
{{- default (include "ontrack.minio.fullname" .) .Values.auditTrail.minio.existingSecret }}
{{- end }}

{{/*
Storage of the audit trail evidence, as JSON. Either the bundled MinIO, when enabled, or the
auditTrail.storage values: both cannot be mixed. The endpoint is empty when no storage is configured.
*/}}
{{- define "ontrack.auditTrail.storage" -}}
{{- $storage := .Values.auditTrail.storage }}
{{- $minio := .Values.auditTrail.minio }}
{{- if $minio.enabled }}
  {{- if $storage.endpoint }}
    {{- fail "auditTrail.minio.enabled cannot be combined with auditTrail.storage.endpoint: use either the bundled MinIO or an external storage." }}
  {{- end }}
  {{- if $storage.bucket }}
    {{- fail "auditTrail.storage.bucket cannot be set with the bundled MinIO: use auditTrail.minio.bucket." }}
  {{- end }}
  {{- if $storage.existingSecret }}
    {{- fail "auditTrail.storage.existingSecret cannot be set with the bundled MinIO: use auditTrail.minio.existingSecret." }}
  {{- end }}
  {{- dict
    "endpoint" (printf "http://%s:9000" (include "ontrack.minio.fullname" .))
    "bucket" $minio.bucket
    "region" $storage.region
    "pathStyle" true
    "maxSize" $storage.maxSize
    "secret" (include "ontrack.minio.secretName" .)
    "accessKeyKey" $minio.rootUserKey
    "secretKeyKey" $minio.rootPasswordKey
    | toJson }}
{{- else }}
  {{- dict
    "endpoint" $storage.endpoint
    "bucket" $storage.bucket
    "region" $storage.region
    "pathStyle" $storage.pathStyle
    "maxSize" $storage.maxSize
    "secret" $storage.existingSecret
    "accessKeyKey" $storage.accessKeyKey
    "secretKeyKey" $storage.secretKeyKey
    | toJson }}
{{- end }}
{{- end }}

{{/*
Request body size allowed on the upload paths, in the nginx format: the maximum size of an
evidence file (Yontrack's default when auditTrail.storage.maxSize is empty), plus 1 MB for the
multipart envelope, like the backend.
*/}}
{{- define "ontrack.ingress.uploads.bodySize" -}}
{{- $mb := 1048576 }}
{{- $bytes := add (include "ontrack.auditTrail.maxSizeBytes" . | atoi) $mb }}
{{- printf "%dm" (div (add $bytes (sub $mb 1)) $mb) }}
{{- end }}

{{/*
Maximum size of an evidence file, in bytes. auditTrail.storage.maxSize is a Spring data size
(B, KB, MB, GB or TB, in powers of 1024, bytes when there is no unit), defaulting to Yontrack's 50MB.
*/}}
{{- define "ontrack.auditTrail.maxSizeBytes" -}}
{{- $raw := (include "ontrack.auditTrail.storage" . | fromJson).maxSize | default "50MB" }}
{{- if kindIs "float64" $raw }}
  {{- $raw = int64 $raw }}
{{- end }}
{{- $size := $raw | toString | nospace | upper }}
{{- if not (regexMatch "^[0-9]+(B|KB|MB|GB|TB)?$" $size) }}
  {{- fail (printf "auditTrail.storage.maxSize must be a size like 50MB (B, KB, MB, GB or TB, bytes when there is no unit), not %v." $raw) }}
{{- end }}
{{- $units := dict "" 1 "B" 1 "KB" 1024 "MB" 1048576 "GB" 1073741824 "TB" 1099511627776 }}
{{- mul (regexFind "^[0-9]+" $size | atoi) (get $units (regexReplaceAll "^[0-9]+" $size "")) }}
{{- end }}

{{/*
Class & TLS of the Ingresses, shared by the main one and the upload one
*/}}
{{- define "ontrack.ingress.classAndTls" -}}
{{- if .Values.ingress.ingressClassName }}
ingressClassName: {{ .Values.ingress.ingressClassName | quote }}
{{- end }}
{{- if .Values.ingress.tls.enabled }}
tls:
  - hosts:
      - {{ .Values.ingress.host }}
    secretName: {{ .Values.ingress.tls.secretName | default (printf "%s-tls" .Values.ingress.host) | quote }}
{{- end }}
{{- end }}
