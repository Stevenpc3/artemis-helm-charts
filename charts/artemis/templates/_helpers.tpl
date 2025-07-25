{{/* Create artemis name for different modes */}}
{{- define "company/artemis/getName" -}}
    {{- $temp := include "company/common/names/fullname" . -}}
    {{- if .Values.ha.enabled -}}
        {{- printf "%s-1" $temp -}}
    {{- else -}}
        {{- printf "%s" $temp -}}
    {{- end -}}
{{- end -}}

{{/* Create the memory configuration */}}
{{- define "company/artemis/memory" -}}
    {{- $values := merge (dict) .Values -}}
    {{- $dev := dig "global" "dev" "" $values -}}
    {{- $memory := dig "jvm" "memory" "1G" $values -}}
    {{- if $dev -}}
        {{- "-XX:MaxRAMPercentage=70.0" -}}
    {{- else -}}
        {{- printf "-Xmx%s -Xms%s" $memory $memory -}}
    {{- end -}}
{{- end -}}

{{- define "helpers.zookeeperService" -}}
{{- $port := 2181 -}}
{{- $containerPorts := index .Values "zookeeper-bitnami" "zookeeper" "containerPorts" -}}
{{- if $containerPorts -}}
    {{- $port = index .Values "zookeeper-bitnami" "zookeeper" "containerPorts" "client" | int -}}
{{- end -}}
{{ printf "%s:%d" (include "helpers.zookeeperName" . ) $port }}
{{- end -}}

{{- define "helpers.zookeeperName" -}}
{{- if (index .Values "zookeeper-bitnami" "zookeeper" "fullnameOverride") -}}
    {{- print (index .Values "zookeeper-bitnami" "zookeeper" "fullnameOverride") -}}
{{- else if (index .Values "zookeeper-bitnami" "zookeeper" "nameOverride") -}}
{{- $name := index .Values "zookeeper-bitnami" "zookeeper" "nameOverride" -}}
    {{- if contains $name .Release.Name -}}
        {{- printf "%s" $name  -}}
    {{- else -}}
        {{- printf "%s-%s" .Release.Name $name -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s-zookeeper" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/* Create artemis outh conf name */}}
{{- define "company/artemis/oauthConfName" -}}
    {{- $name := include "company/common/names/name" . }}
    {{- printf "%s-%s-oauth2-conf" .Release.Name $name -}}
{{- end -}}