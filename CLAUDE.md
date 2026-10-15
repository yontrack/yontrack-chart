# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Helm 3 chart repository that deploys **Yontrack** (a CI/CD tracking platform) to Kubernetes. The chart is published to Docker Hub as an OCI artifact at `oci://registry-1.docker.io/yontrack/yontrack-chart` (the legacy `nemerosa/yontrack-chart` location only receives 5.x versions, published from the `v5` branch).

The chart has no sub-chart: it deploys its own PostgreSQL 17 and RabbitMQ 4, on the official images (since 6.0.0-beta.6, replacing the Bitnami sub-charts; their StatefulSets keep the names, selectors and volume claims of the sub-charts, which are immutable). Since 6.0, Elasticsearch is no longer bundled: Yontrack searches in Postgres (`pg_trgm`), and an external Elasticsearch is only an optional target for the metrics export (`elasticsearch.*` values).

## Common Commands

```bash
# Lint the chart
helm lint charts/yontrack

# Render templates locally (for inspection)
helm template ontrack charts/yontrack -f values.yaml > template.yaml

# Run the template assertions (requires jq and yq)
./scripts/test-templates.sh

# Upgrade the previous published chart to this one on a kind cluster (rolling: zero-downtime, under load; default)
./scripts/upgrade-test.sh rolling

# Same with two replicas on a three-node kind cluster, then a node drain and the loss of a backend pod
./scripts/upgrade-test.sh ha

# Tests of the classification of the failed requests of these upgrade tests
./scripts/upgrade-test/failures-test.sh

# Validate Docker images referenced in the chart are reachable
./scripts/check-images.sh

# Regenerate values documentation (requires helm-docs)
helm-docs charts/yontrack

# Package the chart
helm package charts/yontrack

# Build Keycloak theme tarball (required before packaging; reproducible, see #99)
./scripts/build-theme.sh
```

## Architecture

### Chart Structure

The main chart lives in `charts/yontrack/`. Key files:

- `Chart.yaml` — chart metadata; `appVersion` is auto-updated by Yontrack's auto-versioning system via PRs
- `values.yaml` — all configurable defaults; all values are documented inline for `helm-docs`
- `templates/_helpers.tpl` — shared template helpers (naming, labels, secret generation)
- `files/themes/` — custom Keycloak login theme (packaged as `yontrack.tar.gz`)
- `files/partials/keycloak/` — Keycloak realm/client JSON templates

The root-level `values.yaml` is a local override file (gitignored) used for local testing; the canonical defaults are in `charts/yontrack/values.yaml`.

### Deployed Components

| Component | Template prefix | Notes |
|-----------|----------------|-------|
| Yontrack backend | `ontrack-*` | Deployment; PVC for data, or an ephemeral volume with `ontrack.zeroDowntimeUpgrades` |
| Next.js UI | `ui-*` | Frontend, uses NextAuth |
| PostgreSQL | `postgresql-*` | Yontrack's main database; optional (`postgresql.local`); StatefulSet from the `ontrack.postgres.statefulset` helper (`_postgres.tpl`) |
| RabbitMQ | `rabbitmq-*` | Messaging; optional (`rabbitmq.local`, else `rabbitmq.external`) |
| Keycloak | `keycloak-*` | Optional; has its own PostgreSQL StatefulSet, from the same helper |
| MinIO-compatible storage | `minio-*` | Optional (`auditTrail.minio.enabled`); Silo image, audit trail evidence, bucket created by `files/minio/start.sh` |

### Authentication Modes

Authentication is controlled via `auth.*` values:

- **Keycloak (default)**: Deploys a bundled Keycloak instance with its own PostgreSQL. Supports LDAP federation and comes with a custom `yontrack` theme.
- **External OIDC**: Configure via `auth.oidc.*` for Okta, Auth0, Microsoft Entra, etc. See `docs/` for provider-specific setup.
- **LDAP**: Direct LDAP or via Keycloak federation (`auth.keycloak.ldap.*`).

### Secrets Management

Templates exist in pairs for many secrets: a plain Kubernetes secret (`*-secret.yaml`) and an ExternalSecret variant (`*-external-secret.yaml`). The ExternalSecret variant integrates with the [External Secrets Operator](https://external-secrets.io/) for pulling credentials from Vault, AWS Secrets Manager, etc. Use `auth.keycloak.*.useExternalSecret` / similar flags to switch between them.

### CI/CD

Two release lines:

- `main` — 6.x line. Chart versions with a prerelease suffix (`6.0.0-beta.N`) are published as GitHub prereleases.
- `v5` — 5.x patch line, with its own `release.yml` and `.yontrack/ci.yaml`.

Fixes needed on both lines land on `main` and are cherry-picked to `v5` (no forward merges: `Chart.yaml` differs on every commit).

`.github/workflows/release.yml` runs on every push to `main`:
1. Prepares Keycloak theme tarball
2. Lints and validates Docker image availability
3. Packages the chart
4. Checks whether a GitHub release already exists for `chart.version`
5. If new version: pushes OCI artifact to Docker Hub and creates a GitHub release with a generated changelog

A merge that leaves `version` unchanged publishes nothing. So every PR that changes what the chart ships (templates, values, files, sub-charts) ends with its own commit, `chore: chart <version>`, that bumps `version` in `Chart.yaml` to the next one on its line (on `main`: `6.0.0-beta.N` → `6.0.0-beta.N+1`). In that commit, also run `helm-docs charts/yontrack`, which updates the version badge in `charts/yontrack/README.md`. Changes to docs, scripts or CI alone keep the version.

`.yontrack/ci.yaml` configures Yontrack's auto-versioning: when a Yontrack build on the upstream `main` branch is promoted to `RELEASE`, a PR is automatically opened updating `appVersion` in `Chart.yaml` (as on `v5`, which follows `RELEASE` on `release-5.5`). It follows `RELEASE`, not `GOLD`: `GOLD` only *starts* Yontrack's `release.yml`, while the build's version is still an rc candidate (`<version>-rc-<build>`), a tag on GHCR but never on Docker Hub, which `scripts/check-images.sh` rejects. `RELEASE` is granted once `release.yml` has published the images and rewritten the version, so `${VERSION}` is always a Docker Hub tag.

Until yontrack/yontrack#2070 lands, pre-releases are never granted `RELEASE`, so betas do not bump `appVersion` on their own: if one must reach the chart, set `appVersion` by hand to the version published on Docker Hub (as #155 did).

### Documentation Generation

`charts/yontrack/README.md` is auto-generated by `helm-docs` from inline comments in `values.yaml`. Do not edit it manually. When modifying values, update the corresponding `# -- description` comment above the value.
