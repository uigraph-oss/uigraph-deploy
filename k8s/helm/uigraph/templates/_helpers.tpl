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

{{- define "uigraph.figmaRedirectUri" -}}
{{- .Values.figma.redirectUri | default (printf "%s/api/v1/figma/callback" (include "uigraph.publicUrl" .)) -}}
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
