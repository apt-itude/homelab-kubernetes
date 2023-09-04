{{- $defaultVault := .Values.defaultVault -}}
{{- range $name, $values := .Values.items }}
  {{- if $values.enabled }}
    {{ $vault := $values.vault | default $defaultVault }}
    {{ $item := $values.item | required ".item is required" }}
---
apiVersion: onepassword.com/v1
kind: OnePasswordItem
metadata:
  name: {{ $name }}
  {{- with (merge ($values.labels | default dict) (include "onepassword.labels" $ | fromYaml)) }}
  labels: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (merge ($values.annotations | default dict) (include "onepassword.annotations" $ | fromYaml)) }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  itemPath: vaults/{{ $vault }}/items/{{ $item }}
  {{- end }}
{{- end }}
