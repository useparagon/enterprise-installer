{{/*
Expand the name of the chart.
*/}}
{{- define "ocs-code-runner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ocs-code-runner.fullname" -}}
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

{{- define "ocs-code-runner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ocs-code-runner.labels" -}}
helm.sh/chart: {{ include "ocs-code-runner.chart" . }}
{{ include "ocs-code-runner.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ocs
{{- end }}

{{- define "ocs-code-runner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ocs-code-runner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "ocs-code-runner.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ocs-code-runner.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Map platform CLOUD_STORAGE_TYPE (S3/GCP/AZURE) to the OCS knative provider
(s3/gcp/azure/minio). Prefer an explicit OCS_CODE_RUNNER_STORAGE_TYPE when set.
*/}}
{{- define "ocs-code-runner.storageType" -}}
{{- $explicit := "" -}}
{{- if and .Values.global .Values.global.env -}}
{{- $explicit = index .Values.global.env "OCS_CODE_RUNNER_STORAGE_TYPE" | default "" -}}
{{- end -}}
{{- if $explicit -}}
{{- $explicit -}}
{{- else -}}
{{- $cloud := "" -}}
{{- if and .Values.global .Values.global.env -}}
{{- $cloud = index .Values.global.env "CLOUD_STORAGE_TYPE" | default "S3" -}}
{{- end -}}
{{- lower $cloud -}}
{{- end -}}
{{- end }}

{{- define "ocs-code-runner.storageBucket" -}}
{{- if and .Values.global .Values.global.env (index .Values.global.env "OCS_CODE_RUNNER_STORAGE_BUCKET") -}}
{{- index .Values.global.env "OCS_CODE_RUNNER_STORAGE_BUCKET" -}}
{{- else if and .Values.global .Values.global.env -}}
{{- index .Values.global.env "CLOUD_STORAGE_SYSTEM_BUCKET" | default "" -}}
{{- end -}}
{{- end }}

{{- define "ocs-code-runner.storageRegion" -}}
{{- if and .Values.global .Values.global.env (index .Values.global.env "OCS_CODE_RUNNER_STORAGE_REGION") -}}
{{- index .Values.global.env "OCS_CODE_RUNNER_STORAGE_REGION" -}}
{{- else if and .Values.global .Values.global.env -}}
{{- index .Values.global.env "CLOUD_STORAGE_REGION" | default (index .Values.global.env "AWS_REGION" | default "") -}}
{{- end -}}
{{- end }}

{{- define "ocs-code-runner.storageEndpoint" -}}
{{- if and .Values.global .Values.global.env (index .Values.global.env "OCS_CODE_RUNNER_STORAGE_ENDPOINT") -}}
{{- index .Values.global.env "OCS_CODE_RUNNER_STORAGE_ENDPOINT" -}}
{{- else if and .Values.global .Values.global.env -}}
{{- index .Values.global.env "CLOUD_STORAGE_PRIVATE_URL" | default "" -}}
{{- end -}}
{{- end }}

{{/*
Container env for the knative HTTP runner: storage target + optional access keys
from the shared paragon-secrets (absent on AWS pod-identity installs).
*/}}
{{- define "ocs-code-runner.containerEnv" -}}
- name: NODE_OPTIONS
  value: --max-old-space-size=768
- name: OCS_CODE_RUNNER_STORAGE_TYPE
  value: {{ include "ocs-code-runner.storageType" . | quote }}
- name: OCS_CODE_RUNNER_STORAGE_BUCKET
  value: {{ include "ocs-code-runner.storageBucket" . | quote }}
{{- with include "ocs-code-runner.storageRegion" . }}
- name: OCS_CODE_RUNNER_STORAGE_REGION
  value: {{ . | quote }}
{{- end }}
{{- with include "ocs-code-runner.storageEndpoint" . }}
- name: OCS_CODE_RUNNER_STORAGE_ENDPOINT
  value: {{ . | quote }}
{{- end }}
- name: OCS_CODE_RUNNER_STORAGE_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: CLOUD_STORAGE_MICROSERVICE_USER
      optional: true
- name: OCS_CODE_RUNNER_STORAGE_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: CLOUD_STORAGE_MICROSERVICE_PASS
      optional: true
{{- end }}
