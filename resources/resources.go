{{ "namespace, kind, name, container-name, container-index, replicas, cpu-request, memory-request, cpu-limit, memory-limit" }}
{{ range .items -}}
  {{- $kind := .kind -}}
  {{- $ns := .metadata.namespace -}}
  {{- $name := .metadata.name -}}
  {{- $replicas := "" -}}
  {{- if eq $kind "DaemonSet" -}}
    {{- $replicas = .status.numberAvailable -}}
    {{- else -}}
    {{- $replicas = .status.replicas -}}
  {{- end -}}
  {{- range $i, $c := .spec.template.spec.containers -}}
    {{$ns}}{{", "}}{{$kind}}{{ ", " }}{{$name }}{{ ", " }}{{.name}}{{", "}}{{$i}}{{", "}}{{$replicas}}{{", "}}
    {{- if .resources.requests.cpu }}{{ .resources.requests.cpu }}{{ else }}{{ "null" }}{{ end }}{{ ", " }}
    {{- if .resources.requests.memory }}{{ .resources.requests.memory }}{{ else }}{{ "null" }}{{ end }}{{ ", " }}
    {{- if .resources.limits.cpu }}{{ .resources.limits.cpu }}{{ else }}{{ "null" }}{{ end }}{{ ", " }}
    {{- if .resources.limits.memory }}{{ .resources.limits.memory }}{{ else }}{{ "null" }}{{ end }}{{ "\n" }}
  {{- end -}}
{{- end -}}

