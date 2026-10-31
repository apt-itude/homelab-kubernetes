# AGENTS.md

Homelab Kubernetes GitOps source. Each app is a self-contained Helm chart in `apps/<name>/`. Argo CD deploys one `Application` per directory (named exactly like the directory, e.g. `home-assistant`). The Argo CD `Application`/`ApplicationSet` manifests are **not** in this repo — only the charts are.

## Layout
- `apps/<app>/` — one Helm chart per deployed app. The real artifacts.
- `charts/` — shared helper charts consumed as dependencies by application charts; they are not deployed on their own. They are ordinary `type: application` charts (not Helm `type: library` charts), so don't reach for that type when adding one. `charts/external-secrets/` is the only current example.
- `apps/kargo-projects/` — a deployed app like any other, but its workload is config: it renders the Kargo Projects/Warehouses/Stages that drive other apps' deployments (see below), not a container.

There is no build/test/lint/CI config on `main` (no Makefile, no `.github/`, no tests). Validate chart changes with Helm only.

## Helm
Dependencies are not vendored (`.gitignore` excludes `**/charts/*.tgz`), so build before rendering/linting:
```
helm dependency build apps/<app>
helm template apps/<app>      # or: helm lint apps/<app>
```
Remote deps pulled from upstream registries:
- `library-charts.k8s-at-home.com` `common` — wraps `esphome`, `home-assistant`, `mosquitto`, `zwave-js-ui`
- legacy `k8s-at-home.com/charts` — `unifi`; this is a **separate** repo from the `library-charts` one above
- `prometheus-community` `kube-prometheus-stack`
- `charts.jetstack.io` — `cert-manager`
- `charts.external-secrets.io` — `external-secrets`
- `ori-edge.github.io/k8s_gateway` — `k8s-gateway`
- `charts.longhorn.io` — `longhorn`
- `metallb.github.io/metallb` — `metallb`
- `oci://ghcr.io/akuity/kargo-charts` — `kargo`

`Chart.lock` is committed — regenerate it when you change `Chart.yaml` dependencies.

The k8s-at-home-backed apps are wrappers: `templates/common.yaml` is just `{{ include "common.all" . }}` and all config lives in `values.yaml`. Don't add raw manifests to those.

## Secrets
Never commit secrets. Apps declare 1Password-backed secrets in their own `values.yaml` under `external-secrets.onepassword.secrets.<secretName>` (item/field refs). Apps pull the chart in via a `Chart.yaml` dependency on `file://../../charts/external-secrets`; it renders them against `ClusterSecretStore` `1password-homelab` (vault `Homelab`). Add a key by editing that values block, not by adding a template.

## Kargo automation (the non-obvious part)
`apps/kargo-projects/values.yaml` is the source of truth for automated version bumps. Each entry creates a Kargo project named `kargo-<app>` that watches an upstream image or chart, opens a **squash-merged PR** against this repo, then syncs Argo CD. The `promotion` type decides what gets edited:
- `helmAppVersion` → `apps/<app>/Chart.yaml` `appVersion`
- `helmChartVersion` → the upstream entry under `dependencies` in `apps/<app>/Chart.yaml`, plus `Chart.lock` (Kargo's `helm-update-chart` step). The subscription's `repoURL` and chart name must exactly match that dependency's `repository` and `name`. This holds for OCI too (`repoURL: oci://<registry>`, without the chart name); the Warehouse template appends the chart name itself, since Kargo's OCI subscriptions point at the chart and omit `name`.
- `helmImageTags` → image tags in `apps/<app>/values.yaml`

Implications:
- For Kargo-managed apps, `appVersion`, the subscribed dependency's version (and `Chart.lock`), and the tagged image values are **bot-owned**. Don't hand-edit them or fight bot PRs — change the subscription in `apps/kargo-projects/values.yaml` instead.
- A new app gets auto-updates only after adding a matching entry there. `promotion` must contain exactly one of the three keys.
- Bot commits say `./repo/apps/<app>/...` because Kargo clones into `./repo` before editing; the real path is `apps/<app>/...`.

## Conventions
- `main` is the default branch. Only automated Kargo promotion PRs are squash-merged (by the pipeline below); human PRs are merged normally.
- Public hostnames are `<name>.lucyscrib.com`; TLS uses the `lucys-crib-acme` ClusterIssuer (Let's Encrypt DNS-01 via Cloudflare, defined in `apps/cert-manager/templates/`). External traffic enters through `apps/cloudflare-tunnel/values.yaml` (its ingress map), not per-app LoadBalancers.
- `apps/test/` is the unmodified `helm create` scaffold (nginx) — don't copy it as a pattern.
- Top-level `charts/` (shared) is not the same as a chart's own `charts/` subdir (vendored deps).
