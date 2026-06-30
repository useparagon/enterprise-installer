{{/*
Resolve repository path with optional useparagon/ prefix rewrite.
Input: (dict "root" $ "repository" "useparagon/account")
Skips rewrite when repository already includes a registry host (first path segment contains ".").
*/}}
{{- define "paragon.resolveRepository" -}}
{{- $root := .root -}}
{{- $repository := required "repository" .repository -}}
{{- $parts := splitList "/" $repository -}}
{{- $first := index $parts 0 | default $repository -}}
{{- if contains "." $first -}}
{{- $repository -}}
{{- else if and $root.Values.global (hasKey $root.Values.global "imageRepositoryPrefix") -}}
{{- if hasPrefix "useparagon/" $repository -}}
{{- $repository = trimPrefix "useparagon/" $repository -}}
{{- end -}}
{{- with $root.Values.global.imageRepositoryPrefix -}}
{{- $repository = printf "%s/%s" . $repository -}}
{{- end -}}
{{- $repository -}}
{{- else -}}
{{- $repository -}}
{{- end -}}
{{- end -}}

{{/*
Build a full container image reference (repository:tag or repository:tag@sha).
Input: (dict "root" $ "repository" "useparagon/account" "tag" "1.0.0" "registry" "" "useMigrationRegistry" false "sha" "")
Optional registry supports split registry/repository fields (e.g. quay.io + brancz/kube-rbac-proxy).
useMigrationRegistry selects global.migrationImageRegistry before global.imageRegistry.
Optional sha appends @digest when set.
*/}}
{{- define "paragon.image" -}}
{{- $root := .root -}}
{{- $repository := include "paragon.resolveRepository" . -}}
{{- $tag := required "tag" .tag -}}
{{- $registry := .registry | default "" -}}
{{- $sha := .sha | default "" -}}
{{- $useMigrationRegistry := .useMigrationRegistry | default false -}}
{{- $globalRegistry := "" -}}
{{- if and $root.Values.global $useMigrationRegistry -}}
{{- $globalRegistry = $root.Values.global.migrationImageRegistry | default $root.Values.global.imageRegistry | default "" -}}
{{- else if $root.Values.global -}}
{{- $globalRegistry = $root.Values.global.imageRegistry | default "" -}}
{{- end -}}
{{- $parts := splitList "/" $repository -}}
{{- $first := index $parts 0 | default $repository -}}
{{- $ref := "" -}}
{{- if contains "." $first -}}
{{- $ref = printf "%s:%s" $repository $tag -}}
{{- else if $globalRegistry -}}
{{- $ref = printf "%s/%s:%s" $globalRegistry $repository $tag -}}
{{- else if $registry -}}
{{- $ref = printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
{{- $ref = printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- if $sha -}}
{{- printf "%s@%s" $ref $sha -}}
{{- else -}}
{{- $ref -}}
{{- end -}}
{{- end -}}

{{/*
Image reference for a chart's main workload container.
Input: (dict "root" $) — tag from global.paragon_version / global.env.VERSION.
For statefulsets pass tagFallback from image.tag via the tag param.
*/}}
{{- define "paragon.containerImage" -}}
{{- $root := .root -}}
{{- $tag := .tag | default ($root.Values.global.paragon_version | default $root.Values.global.env.VERSION) -}}
{{- include "paragon.image" (dict "root" $root "repository" $root.Values.image.repository "tag" $tag "registry" ($root.Values.image.registry | default "") "useMigrationRegistry" (.useMigrationRegistry | default false) "sha" ($root.Values.image.sha | default "")) -}}
{{- end -}}

{{/*
Merge global and chart-level imagePullSecrets.
Input: (dict "root" $) or (dict "root" $ "imagePullSecrets" .Values.imagePullSecrets)
*/}}
{{- define "paragon.imagePullSecrets" -}}
{{- $root := .root -}}
{{- $local := .imagePullSecrets | default $root.Values.imagePullSecrets | default list -}}
{{- $global := list -}}
{{- if and $root.Values.global $root.Values.global.imagePullSecrets -}}
{{- $global = $root.Values.global.imagePullSecrets -}}
{{- end -}}
{{- range (concat $global $local) }}
{{- if eq (typeOf .) "map[string]interface {}" }}
- {{ toYaml . | trim }}
{{- else }}
- name: {{ . }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
imagePullPolicy: chart value, then global.pullPolicy, then IfNotPresent.
Input: (dict "root" $)
*/}}
{{- define "paragon.imagePullPolicy" -}}
{{- $root := .root -}}
{{- $root.Values.image.pullPolicy | default $root.Values.global.pullPolicy | default "IfNotPresent" -}}
{{- end -}}

{{/*
Helm test hook image (busybox by default).
Input: (dict "root" $) or (dict "root" $ "tag" "1.36")
*/}}
{{- define "paragon.testImage" -}}
{{- $root := .root -}}
{{- $repo := "busybox" -}}
{{- $defaultTag := "latest" -}}
{{- if and $root.Values.global $root.Values.global.testImage -}}
{{- $repo = $root.Values.global.testImage.repository | default $repo -}}
{{- $defaultTag = $root.Values.global.testImage.tag | default $defaultTag -}}
{{- end -}}
{{- $tag := .tag | default $defaultTag -}}
{{- include "paragon.image" (dict "root" $root "repository" $repo "tag" $tag) -}}
{{- end -}}

{{/*
Restart cron kubectl image.
Input: (dict "root" $)
*/}}
{{- define "paragon.kubectlImage" -}}
{{- $root := .root -}}
{{- $repo := "alpine/kubectl" -}}
{{- $tag := "1.36.2" -}}
{{- if and $root.Values.global $root.Values.global.kubectlImage -}}
{{- $repo = $root.Values.global.kubectlImage.repository | default $repo -}}
{{- $tag = $root.Values.global.kubectlImage.tag | default $tag -}}
{{- end -}}
{{- include "paragon.image" (dict "root" $root "repository" $repo "tag" $tag) -}}
{{- end -}}
