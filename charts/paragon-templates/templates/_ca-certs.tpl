{{/*
Build resolved custom CA source list (YAML): enabled, bundlePath, sources[].
Includes global.caCerts.sources when caCerts.enabled, plus global.redisCaCert when enabled (deduped).
Input: (dict "root" $)
*/}}
{{- define "caCerts.configYaml" -}}
{{- $root := .root -}}
{{- $sources := list -}}
{{- $g := $root.Values.global | default dict -}}
{{- $caCerts := $g.caCerts | default dict -}}
{{- if and (hasKey $caCerts "enabled") $caCerts.enabled (hasKey $caCerts "sources") (kindIs "slice" $caCerts.sources) -}}
{{- range $caCerts.sources -}}
{{- if .secretName -}}
{{- $sources = append $sources (dict "type" "secret" "name" .secretName "key" (.key | default "ca.pem")) -}}
{{- else if .configMapName -}}
{{- $sources = append $sources (dict "type" "configMap" "name" .configMapName "key" (.key | default "ca.pem")) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $redis := $g.redisCaCert | default dict -}}
{{- $redisOn := and (hasKey $redis "enabled") $redis.enabled -}}
{{- if $redisOn -}}
{{- $rn := $redis.secretName | default "redis-ca-cert" -}}
{{- $dup := false -}}
{{- range $sources -}}
{{- if and (eq .type "secret") (eq .name $rn) (eq .key "server-ca.pem") -}}
{{- $dup = true -}}
{{- end -}}
{{- end -}}
{{- if not $dup -}}
{{- $sources = append $sources (dict "type" "secret" "name" $rn "key" "server-ca.pem") -}}
{{- end -}}
{{- end -}}
{{- $bundlePath := $caCerts.bundlePath | default "/etc/ssl/custom-ca/ca-bundle.pem" -}}
enabled: {{ gt (len $sources) 0 }}
bundlePath: {{ $bundlePath | quote }}
sources:
{{- range $i, $src := $sources }}
  - index: {{ $i }}
    type: {{ $src.type }}
    name: {{ $src.name }}
    key: {{ $src.key }}
    volumeName: custom-ca-source-{{ $i }}
    fileName: {{ $i }}-{{ $src.key }}
{{- end }}
{{- end -}}

{{/*
Container env when custom CA bundle is enabled.
Input: (dict "root" $)
*/}}
{{- define "caCerts.containerEnv" -}}
{{- $root := .root -}}
{{- $ca := include "caCerts.configYaml" (dict "root" $root) | fromYaml -}}
{{- if $ca.enabled -}}
- name: NODE_EXTRA_CA_CERTS
  value: {{ $ca.bundlePath | quote }}
- name: PGSSLROOTCERT
  value: {{ $ca.bundlePath | quote }}
{{- end -}}
{{- end -}}

{{/*
Main workload volumeMounts for the bundle directory.
Input: (dict "root" $)
*/}}
{{- define "caCerts.containerVolumeMounts" -}}
{{- $root := .root -}}
{{- $ca := include "caCerts.configYaml" (dict "root" $root) | fromYaml -}}
{{- if $ca.enabled -}}
- name: custom-ca-bundle
  mountPath: /etc/ssl/custom-ca
  readOnly: true
{{- end -}}
{{- end -}}

{{/*
Init container concatenates mounted PEMs into bundlePath on emptyDir.
Input: (dict "root" $)
*/}}
{{- define "caCerts.initContainers" -}}
{{- $root := .root -}}
{{- $ca := include "caCerts.configYaml" (dict "root" $root) | fromYaml -}}
{{- if $ca.enabled -}}
- name: custom-ca-bundle
  image: {{ include "paragon.testImage" (dict "root" $root) | quote }}
  imagePullPolicy: {{ include "paragon.imagePullPolicy" (dict "root" $root) }}
  command: ["/bin/sh", "-c"]
  args:
    - mkdir -p /etc/ssl/custom-ca/sources && cat /etc/ssl/custom-ca/sources/* > {{ $ca.bundlePath }}
  volumeMounts:
    - name: custom-ca-bundle
      mountPath: /etc/ssl/custom-ca
    {{- range $ca.sources }}
    - name: {{ .volumeName }}
      mountPath: /etc/ssl/custom-ca/sources/{{ .fileName }}
      subPath: {{ .key }}
      readOnly: true
    {{- end }}
{{- end -}}
{{- end -}}

{{/*
Pod volumes for custom CA sources and bundle emptyDir.
Input: (dict "root" $)
*/}}
{{- define "caCerts.volumes" -}}
{{- $root := .root -}}
{{- $ca := include "caCerts.configYaml" (dict "root" $root) | fromYaml -}}
{{- if $ca.enabled -}}
- name: custom-ca-bundle
  emptyDir: {}
{{- range $ca.sources }}
- name: {{ .volumeName }}
  {{- if eq .type "secret" }}
  secret:
    secretName: {{ .name }}
    items:
      - key: {{ .key }}
        path: {{ .key }}
  {{- else }}
  configMap:
    name: {{ .name }}
    items:
      - key: {{ .key }}
        path: {{ .key }}
  {{- end }}
{{- end }}
{{- end -}}
{{- end -}}
