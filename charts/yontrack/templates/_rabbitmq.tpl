{{/*
Name of the resources of the bundled RabbitMQ: those of the Bitnami sub-chart it replaces (#183)
*/}}
{{- define "ontrack.rabbitmq.fullname" -}}
{{- printf "%s-rabbitmq" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels of the bundled RabbitMQ: those of the Bitnami sub-chart, since the selector of a StatefulSet is immutable
*/}}
{{- define "ontrack.selectorLabels.rabbitmq" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: rabbitmq
{{- end }}

{{/*
Common labels of the bundled RabbitMQ
*/}}
{{- define "ontrack.labels.rabbitmq" -}}
{{- if .Values.includeVersionLabels }}
helm.sh/chart: {{ include "ontrack.chart" . }}
{{- end }}
{{ include "ontrack.selectorLabels.rabbitmq" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Configuration of the bundled RabbitMQ (rabbitmq.conf), with its credentials: in the secret
*/}}
{{- define "ontrack.rabbitmq.config" -}}
default_user = {{ .Values.rabbitmq.auth.username }}
default_pass = {{ .Values.rabbitmq.auth.password }}
loopback_users = none
listeners.tcp.default = 5672
log.console = true
log.file = false
{{- end }}
