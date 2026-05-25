{{/*
Render httpGet probe YAML for liveness, readiness, or startup.
include "probes.httpGet" (dict "root" $root "type" "liveness")
*/}}
{{- define "probes.httpGet" -}}
{{- $root := .root -}}
{{- $type := .type -}}
{{- $values := index $root "Values" | default dict -}}
{{- $ingress := get $values "ingress" | default dict -}}
{{- $healthPath := $ingress.healthcheck_path | default "/healthz" -}}
{{- $pathField := dict "liveness" "livecheck_path" "readiness" "readycheck_path" "startup" "startupcheck_path" -}}
{{- $path := index $ingress (index $pathField $type) | default $healthPath -}}
{{- $defaultsByType := dict
  "liveness" (dict
    "initialDelaySeconds" 10
    "periodSeconds" 10
    "timeoutSeconds" 5
    "failureThreshold" 3
  )
  "readiness" (dict
    "initialDelaySeconds" 10
    "periodSeconds" 10
    "timeoutSeconds" 5
    "failureThreshold" 3
  )
  "startup" (dict
    "periodSeconds" 10
    "timeoutSeconds" 5
    "failureThreshold" 30
  )
-}}
{{- $overrides := index (get $values "probes" | default dict) $type | default dict -}}
{{- $cfg := mergeOverwrite (index $defaultsByType $type) $overrides -}}
httpGet:
  path: {{ $path | quote }}
  port: http
{{ toYaml $cfg }}
{{- end }}
