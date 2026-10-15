{{/*
Name of the resources of the bundled Postgres: those of the Bitnami sub-chart it replaces (#183)
*/}}
{{- define "ontrack.postgresql.fullname" -}}
{{- printf "%s-postgresql" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels of the bundled Postgres: those of the Bitnami sub-chart, since the selector of a StatefulSet is immutable
*/}}
{{- define "ontrack.selectorLabels.postgresql" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: postgresql
app.kubernetes.io/component: primary
{{- end }}

{{/*
Common labels of the bundled Postgres
*/}}
{{- define "ontrack.labels.postgresql" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels.postgresql" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Data of the ConfigMap of a Postgres: the chart owns postgresql.conf, pg_hba.conf & pg_ident.conf, outside PGDATA.
The Bitnami images kept them outside their data directory, which therefore has none of them (#183).

Parameters:
  - maxConnections: (int, optional) max_connections
  - config: (string, optional) extra lines of postgresql.conf
*/}}
{{- define "ontrack.postgres.configData" -}}
postgresql.conf: |
  listen_addresses = '*'
  {{- with .maxConnections }}
  max_connections = {{ int . }}
  {{- end }}
  {{- with .config }}
  {{- . | trim | nindent 2 }}
  {{- end }}
pg_hba.conf: |
  # TYPE  DATABASE  USER  ADDRESS       METHOD
  local   all       all                 trust
  host    all       all   127.0.0.1/32  trust
  host    all       all   ::1/128       trust
  host    all       all   all           scram-sha-256
pg_ident.conf: ""
{{- end }}

{{/*
StatefulSet of a Postgres, shared by the bundled one and the one of Keycloak (#183). Official image, as the user &
group 1001 (those of the Bitnami images), with a read-only root filesystem. The configuration is in the ConfigMap
(see "ontrack.postgres.configData"): a change restarts Postgres.

The volume is mounted at /var/lib/postgresql/storage, with PGDATA in its data/ folder, as in the Bitnami layout: the
volume of the Bitnami sub-chart is used as is. Not at /var/lib/postgresql: the official image declares a VOLUME at
/var/lib/postgresql/data, which the container runtime would mount over the data of the volume.

Parameters:
  - root: (object, required) the root context
  - name: (string, required) name of the StatefulSet
  - serviceName: (string, required) its governing Service
  - labels: (string, required) rendered labels of the StatefulSet
  - selectorLabels: (string, required) rendered selector labels, also the labels of the pod
  - configMap: (string, required) name of the ConfigMap of the configuration
  - configData: (string, required) rendered data of this ConfigMap, for its checksum
  - image: (dict, required) repository, tag & pullPolicy
  - database: (string, required) name of the database created at the first start
  - credentials: (dict, required) either secret, usernameKey & passwordKey, or username & password
  - claimTemplate: (dict, optional) data volume claimed by the StatefulSet: size, storageClass, annotations, labels
  - claimName: (string, optional) existing PVC used as data volume when there is no claimTemplate
  - subPath: (string, optional) folder of the data volume to mount
  - resources, nodeSelector, tolerations, affinity, podAnnotations: (optional) of the pod
*/}}
{{- define "ontrack.postgres.statefulset" -}}
{{- $root := .root }}
{{- $credentials := .credentials }}
{{- $pgIsReady := `exec pg_isready -q -h 127.0.0.1 -p 5432 -U "$POSTGRES_USER" -d "dbname=$POSTGRES_DB"` }}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .name }}
  labels:
    {{- .labels | nindent 4 }}
spec:
  replicas: 1
  serviceName: {{ .serviceName }}
  podManagementPolicy: OrderedReady
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      {{- .selectorLabels | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ .configData | sha256sum }}
        {{- with .podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- .selectorLabels | nindent 8 }}
    spec:
      serviceAccountName: {{ include "ontrack.serviceAccountName" $root }}
      automountServiceAccountToken: false
      {{- if not (include "ontrack.openshift.adaptSecurityContext" $root) }}
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        runAsNonRoot: true
        fsGroup: 1001
        fsGroupChangePolicy: OnRootMismatch
        seccompProfile:
          type: RuntimeDefault
      {{- end }}
      containers:
        - name: postgresql
          image: {{ .image.repository }}:{{ .image.tag }}
          imagePullPolicy: {{ .image.pullPolicy }}
          {{- if not (include "ontrack.openshift.adaptSecurityContext" $root) }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          {{- end }}
          args:
            - postgres
            - -c
            - config_file=/etc/postgresql/postgresql.conf
            - -c
            - hba_file=/etc/postgresql/pg_hba.conf
            - -c
            - ident_file=/etc/postgresql/pg_ident.conf
          env:
            - name: PGDATA
              value: /var/lib/postgresql/storage/data
            - name: POSTGRES_DB
              value: {{ .database | quote }}
            {{- if $credentials.secret }}
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: {{ $credentials.secret | quote }}
                  key: {{ $credentials.usernameKey | quote }}
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $credentials.secret | quote }}
                  key: {{ $credentials.passwordKey | quote }}
            {{- else }}
            - name: POSTGRES_USER
              value: {{ $credentials.username | quote }}
            - name: POSTGRES_PASSWORD
              value: {{ $credentials.password | quote }}
            {{- end }}
          ports:
            - name: tcp-postgresql
              containerPort: 5432
              protocol: TCP
          # The first start runs initdb, and a start after a crash replays the WAL
          startupProbe:
            exec:
              command: [ "/bin/sh", "-c", {{ $pgIsReady | quote }} ]
            periodSeconds: 5
            timeoutSeconds: 5
            failureThreshold: 120
          livenessProbe:
            exec:
              command: [ "/bin/sh", "-c", {{ $pgIsReady | quote }} ]
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 6
          readinessProbe:
            exec:
              command: [ "/bin/sh", "-c", {{ $pgIsReady | quote }} ]
            periodSeconds: 5
            timeoutSeconds: 5
            failureThreshold: 3
          {{- with .resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/storage
              {{- with .subPath }}
              subPath: {{ . }}
              {{- end }}
            - name: config
              mountPath: /etc/postgresql
              readOnly: true
            - name: run
              mountPath: /var/run/postgresql
            - name: tmp
              mountPath: /tmp
            - name: dshm
              mountPath: /dev/shm
      {{- with .nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        {{- if not .claimTemplate }}
        - name: data
          persistentVolumeClaim:
            claimName: {{ required "ontrack.postgres.statefulset: claimName or claimTemplate is required" .claimName }}
        {{- end }}
        - name: config
          configMap:
            name: {{ .configMap }}
        - name: run
          emptyDir: {}
        - name: tmp
          emptyDir: {}
        - name: dshm
          emptyDir:
            medium: Memory
  {{- with .claimTemplate }}
  volumeClaimTemplates:
    {{- include "ontrack.volumeClaimTemplate" . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
Claim template "data" of a StatefulSet. volumeClaimTemplates are immutable: for the bundled Postgres & RabbitMQ, the
claim templates must stay those of the Bitnami sub-charts, given the same values (#183).

Parameters: size, storageClass ("-" for none), annotations, labels (rendered)
*/}}
{{- define "ontrack.volumeClaimTemplate" -}}
- apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: data
    {{- with .labels }}
    labels:
      {{- . | nindent 6 }}
    {{- end }}
    {{- with .annotations }}
    annotations:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: {{ .size | quote }}
    {{- with .storageClass }}
    storageClassName: {{ ternary "" . (eq . "-") | quote }}
    {{- end }}
{{- end }}

{{/*
Data of the ConfigMap of the bundled Postgres
*/}}
{{- define "ontrack.postgresql.configData" -}}
{{- include "ontrack.postgres.configData" (dict "maxConnections" .Values.postgresql.maxConnections "config" .Values.postgresql.config) }}
{{- end }}

{{/*
Data of the ConfigMap of the Keycloak Postgres
*/}}
{{- define "ontrack.keycloak.postgres.configData" -}}
{{- include "ontrack.postgres.configData" dict }}
{{- end }}
