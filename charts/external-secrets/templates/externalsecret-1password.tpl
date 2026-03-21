{{- $defaultStore := .Values.onepassword.defaultStore -}}
{{- range $name, $values := .Values.onepassword.secrets }}
  {{- if $values.enabled }}
    {{ $store := $values.store | default $defaultStore }}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ $name }}
  {{- with (merge ($values.labels | default dict) (include "externalSecrets.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (merge ($values.annotations | default dict) (include "externalSecrets.annotations" $ | fromYaml)) }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: {{ $store }}
  target:
    creationPolicy: Owner
    name: {{ $name }}
    {{- with $values.templateKeys }}
    template:
      engineVersion: v2
      data:
      {{- range $key, $value := . }}
        {{ $key }}: {{ $value | quote }}
      {{- end }}
    {{- end }}
  data:
    {{- range $key, $value := $values.keys }}
    - secretKey: {{ $key }}
      remoteRef:
      {{- if $value.section }}
        key: "{{ $value.item }}/{{ $value.section }}/{{ $value.field }}"
      {{- else }}
        key: "{{ $value.item }}/{{ $value.field }}"
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
