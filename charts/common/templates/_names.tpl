{{/*
Create a chart name. The result is always truncated to 63 characters.

The following order of precedence is used to determine the result:

- use `.Values.global.nameOverride` if set
- use `.Values.nameOverride` if set
- use the chart name

*/}}
{{- define "copmpany/common/names/name" -}}
    {{- $globalNameOverride := "" -}}
    {{- if hasKey .Values "global" -}}
        {{- $globalNameOverride = (default $globalNameOverride .Values.global.nameOverride) -}}
    {{- end -}}
    {{- default .Chart.Name (default .Values.nameOverride $globalNameOverride) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified chart name. This is done by concatenating the Helm release name and the result of the `copmpany/common/names/name` template with a dash.
If the release name contains the chart name the chart name will be used to avoid repetition. The result is always truncated to 63 characters.

This value should typically be used as the `metadata.name` field for all objects in a chart.

The following order of precedence is used to determine the result:

- do not use a full name if `.Values.disableFullName` or `.Values.global.disableFullName` are set to a truthy value
- use `.Values.global.fullnameOverride` if set
- use `.Values.fullnameOverride` if set
- use the release name concatenated with the result of the `copmpany/common/names/name` template

*/}}
{{- define "copmpany/common/names/fullname" -}}
    {{- $name := include "copmpany/common/names/name" . -}}
    {{- $values := merge (dict) .Values -}}
    {{- $globalFullNameOverride := dig "global" "fullnameOverride" "" $values -}}
    {{- $globalDisableFullName := dig "global" "disableFullName" false $values -}}
    {{- $disableFullName := default .Values.disableFullName $globalDisableFullName -}}
    {{- if not $disableFullName -}}
        {{- if or .Values.fullnameOverride $globalFullNameOverride -}}
            {{- $name = default .Values.fullnameOverride $globalFullNameOverride -}}
        {{- else -}}
            {{- if contains $name .Release.Name -}}
                {{- $name = .Release.Name -}}
            {{- else -}}
                {{- $name = printf "%s-%s" .Release.Name $name -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}
    {{- trunc 63 $name | trimSuffix "-" -}}
{{- end -}}
