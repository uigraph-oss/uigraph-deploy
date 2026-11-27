{{/*
Base name for resources, defaults to the release name.
*/}}
{{- define "uigraph.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uigraph.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "uigraph.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "uigraph.labels" -}}
helm.sh/chart: {{ include "uigraph.chart" . }}
{{ include "uigraph.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels shared by a specific service (deployment/service/hpa/pdb all target the same pods).
Usage: include "uigraph.selectorLabels" (dict "root" . "component" "api")
*/}}
{{- define "uigraph.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ include "uigraph.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "uigraph.componentLabels" -}}
{{ include "uigraph.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Base (non-component) selector labels, used by the shared ServiceAccount.
*/}}
{{- define "uigraph.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uigraph.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Fully-qualified name for a given component, e.g. "release-uigraph-api".
Usage: include "uigraph.componentFullname" (dict "root" . "component" "api")
*/}}
{{- define "uigraph.componentFullname" -}}
{{- printf "%s-%s" (include "uigraph.fullname" .root) .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Name of the ServiceAccount to use.
*/}}
{{- define "uigraph.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "uigraph.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Name of the Secret holding app secrets (either the one this chart renders, or an externally-managed one).
*/}}
{{- define "uigraph.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- include "uigraph.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Computed public hostnames / URLs shared across ConfigMaps, Deployments, and the Ingress.
*/}}
{{- define "uigraph.appHost" -}}
{{- .Values.ingress.appHost | default (printf "app.%s" .Values.app.domain) -}}
{{- end -}}

{{- define "uigraph.gatewayHost" -}}
{{- .Values.ingress.gatewayHost | default (printf "sync.%s" .Values.app.domain) -}}
{{- end -}}

{{- define "uigraph.mcpHost" -}}
{{- .Values.ingress.mcpHost | default (printf "mcp.%s" .Values.app.domain) -}}
{{- end -}}

{{- define "uigraph.mcpPublicUrl" -}}
{{- printf "https://%s" (include "uigraph.mcpHost" .) -}}
{{- end -}}

{{- define "uigraph.publicUrl" -}}
{{- .Values.app.publicUrl | default (printf "https://%s" (include "uigraph.appHost" .)) -}}
{{- end -}}

{{- define "uigraph.frontendUrl" -}}
{{- .Values.app.frontendUrl | default (include "uigraph.publicUrl" .) -}}
{{- end -}}

{{- define "uigraph.internalFrontendUrl" -}}
{{- printf "http://%s" (include "uigraph.componentFullname" (dict "root" . "component" "ui")) -}}
{{- end -}}

{{- define "uigraph.internalApiUrl" -}}
{{- printf "http://%s:%v" (include "uigraph.componentFullname" (dict "root" . "component" "api")) .Values.api.port -}}
{{- end -}}

{{- define "uigraph.internalGraphqlUrl" -}}
{{- printf "http://%s:%v" (include "uigraph.componentFullname" (dict "root" . "component" "graphql")) .Values.graphql.port -}}
{{- end -}}

{{- define "uigraph.internalGatewayUrl" -}}
{{- printf "http://%s:%v" (include "uigraph.componentFullname" (dict "root" . "component" "gateway")) .Values.gateway.port -}}
{{- end -}}

{{- define "uigraph.internalMcpUrl" -}}
{{- printf "http://%s:%v" (include "uigraph.componentFullname" (dict "root" . "component" "mcp")) .Values.mcp.port -}}
{{- end -}}

{{/*
Pod template annotations shared by every Deployment: a checksum of the shared configmap.yaml, so
a config-only change actually rolls pods — Kubernetes doesn't do this on its own for env vars
sourced from a ConfigMap/Secret, they're only read at container start — plus any caller-supplied
podAnnotations (e.g. Terraform passing a checksum of the externally-managed Secret's contents,
which this chart has no visibility into when secrets.existingSecret is set).
*/}}
{{- define "uigraph.podAnnotations" -}}
checksum/config: {{ include (print .Template.BasePath "/configmap.yaml") . | sha256sum }}
{{- with .Values.podAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "uigraph.figmaRedirectUri" -}}
{{- .Values.figma.redirectUri | default (printf "%s/api/v1/figma/callback" (include "uigraph.publicUrl" .)) -}}
{{- end -}}

{{/*
uigraph-gateway's config schema requires STORAGE_ENDPOINT (unlike uigraph-api, which tolerates it
being unset) — always emit a real value rather than omitting the key, defaulting to the region's
S3 endpoint. Only used for S3-compatible alternatives (storage.endpoint) does this get overridden.
*/}}
{{- define "uigraph.storageEndpoint" -}}
{{- .Values.storage.endpoint | default (printf "https://s3.%s.amazonaws.com" .Values.storage.region) -}}
{{- end -}}

{{/*
POSTGRES_URL / REDIS_URL, built from plain (non-secret) connection fields plus a Kubernetes
$(VAR) reference to a password/token sourced from the Secret. Kubernetes expands $(VAR_NAME)
against env vars defined earlier in the same container's env list — see api-deployment.yaml.
*/}}
{{- define "uigraph.postgresUrl" -}}
{{- printf "postgres://%s:$(POSTGRES_PASSWORD)@%s:%v/%s?sslmode=%s" .Values.postgres.user .Values.postgres.host .Values.postgres.port .Values.postgres.database .Values.postgres.sslmode -}}
{{- end -}}

{{- define "uigraph.redisUrl" -}}
{{- $scheme := ternary "rediss" "redis" .Values.redis.tls -}}
{{- if .Values.redis.authEnabled -}}
{{- printf "%s://:$(REDIS_AUTH_TOKEN)@%s:%v" $scheme .Values.redis.host .Values.redis.port -}}
{{- else -}}
{{- printf "%s://%s:%v" $scheme .Values.redis.host .Values.redis.port -}}
{{- end -}}
{{- end -}}

{{/*
uigraph-autopilot settings. `helm upgrade --reuse-values` against a release installed before
autopilot existed leaves .Values.autopilot absent, not false, and `--set autopilot.enabled=true`
on such a release sets only that one key. So every autopilot template reads through this dict,
which carries the defaults from values.yaml, instead of reading .Values.autopilot directly.
Usage: $ap := include "uigraph.autopilot" . | fromYaml
*/}}
{{- define "uigraph.autopilot" -}}
{{- $defaults := dict
    "enabled" false
    "image" (dict "repository" "uigraph/uigraph-autopilot" "tag" "0.1.0")
    "replicaCount" 1
    "port" 8086
    "logLevel" "info"
    "database" (dict "name" "autopilot" "params" "" "urlFromSecret" false)
    "resources" (dict "requests" (dict "cpu" "50m" "memory" "64Mi") "limits" (dict "cpu" "250m" "memory" "256Mi")) -}}
{{- toYaml (mergeOverwrite $defaults (deepCopy (.Values.autopilot | default dict))) -}}
{{- end -}}

{{/*
DATABASE_URL for uigraph-autopilot when it is built rather than read from the Secret: the same
Postgres server and credentials as uigraph-api, but its own database. POSTGRES_PASSWORD is
expanded by Kubernetes, as for uigraph.postgresUrl.
Usage: include "uigraph.autopilotDatabaseUrl" (dict "root" . "ap" $ap)
*/}}
{{- define "uigraph.autopilotDatabaseUrl" -}}
{{- $pg := .root.Values.postgres -}}
{{- $db := .ap.database -}}
{{- $url := printf "postgres://%s:$(POSTGRES_PASSWORD)@%s:%v/%s?sslmode=%s" $pg.user $pg.host $pg.port $db.name $pg.sslmode -}}
{{- if $db.params -}}
{{- $url = printf "%s&%s" $url $db.params -}}
{{- end -}}
{{- $url -}}
{{- end -}}
