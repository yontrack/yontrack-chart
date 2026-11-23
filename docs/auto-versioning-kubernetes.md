# Kubernetes post-processing of auto-versioning

<!-- TOC -->
* [Enabling](#enabling)
* [Namespace of the Jobs](#namespace-of-the-jobs)
* [Allowed images and Secrets](#allowed-images-and-secrets)
* [Permissions](#permissions)
* [NetworkPolicy](#networkpolicy)
* [Other settings](#other-settings)
* [Using it in an auto-versioning configuration](#using-it-in-an-auto-versioning-configuration)
<!-- TOC -->

Since Yontrack 6.0.3, the post-processing of an auto-versioning PR can run as a **Kubernetes Job**, in the cluster
Yontrack runs in: Yontrack clones the upgrade branch, runs the image and command of the auto-versioning configuration
in the working copy, then commits and pushes the result. See the
[Yontrack documentation](https://github.com/yontrack/yontrack/blob/main/ontrack-docs/docs/content/integrations/auto-versioning/kubernetes.md)
of this post-processing.

The chart enables it, grants the backend the permissions it needs, and can isolate the Jobs on the network. All the
values are under `autoVersioning.kubernetes`.

## Enabling

```yaml
autoVersioning:
  kubernetes:
    enabled: true
    namespace: yontrack-av
    allowed:
      images:
        - "eclipse-temurin:21"
        - "node:22*"
      secrets:
        - npm-token
    networkPolicy:
      enabled: true
```

With `enabled: true`, the Yontrack backend pod mounts the token of its service account
(`automountServiceAccountToken: true`): the post-processing calls the Kubernetes API with it. No other pod of the chart
mounts this token, whether the post-processing is enabled or not.

## Namespace of the Jobs

The Jobs, and the Secrets holding their Git credentials, are created in `autoVersioning.kubernetes.namespace`, or in
the namespace of the release when it is empty.

Prefer a **dedicated namespace**, holding only the Secrets the post-processing may expose:

* in the namespace of the release, the backend may delete any Secret, including the ones of the chart (the Role cannot
  name the Secrets of the Jobs in advance);
* in the namespace of the release, the Job pods are on the same network as Postgres and RabbitMQ, which the
  NetworkPolicies of the chart (`networkPolicy.enabled`) open to all the pods of the namespace.

The chart does not create this namespace:

```bash
kubectl create namespace yontrack-av
```

## Allowed images and Secrets

Yontrack runs only the images matching `autoVersioning.kubernetes.allowed.images` (`*` matches any characters, and the
pattern must match the whole image name), and exposes only the Secrets listed in
`autoVersioning.kubernetes.allowed.secrets`. **Both lists are empty by default, which denies every image and every
Secret**: with the post-processing enabled and no allowed image, every post-processing fails, and the notes of the
release warn about it.

The allowed Secrets must exist in the namespace of the Jobs. Yontrack never reads them: the Jobs get them as
environment variables.

```bash
kubectl -n yontrack-av create secret generic npm-token --from-literal=token=...
```

If the images come from a private registry, list the pull secrets, which must also exist in the namespace of the
Jobs, in `autoVersioning.kubernetes.job.imagePullSecrets`. The `imagePullSecrets` of the chart are not used for the
Jobs.

## Permissions

With `autoVersioning.kubernetes.rbac.create: true` (the default), the chart renders a `Role` and a `RoleBinding` in the
namespace of the Jobs, for the service account of the chart:

| API group | Resource   | Verbs                          |
|-----------|------------|--------------------------------|
| `batch`   | `jobs`     | create, get, list, delete      |
|           | `pods`     | get, list                      |
|           | `pods/log` | get                            |
|           | `secrets`  | create, delete                 |

When RBAC is managed outside the chart, set `rbac.create: false` and grant these permissions to the service account
of the chart (`serviceAccount.name`) in the namespace of the Jobs. Without them, the post-processings fail, and are
not retried.

## NetworkPolicy

With `autoVersioning.kubernetes.networkPolicy.enabled: true`, the chart renders a NetworkPolicy in the namespace of the
Jobs, for their pods (`app.kubernetes.io/managed-by: yontrack`):

* no ingress: Yontrack polls the Jobs, nothing connects to them;
* egress to the DNS (port 53, UDP & TCP), and to any destination on the TCP ports 443 & 22: the Git server, and the
  registries the command may need. The Job pods cannot reach Postgres, RabbitMQ or Yontrack.

`autoVersioning.kubernetes.networkPolicy.egress` replaces these egress rules, for example to restrict them to some
addresses:

```yaml
autoVersioning:
  kubernetes:
    networkPolicy:
      enabled: true
      egress:
        - ports:
            - port: 53
              protocol: UDP
            - port: 53
              protocol: TCP
        - to:
            - ipBlock:
                cidr: 140.82.112.0/20
          ports:
            - port: 443
              protocol: TCP
```

A NetworkPolicy only applies when the network plugin of the cluster enforces them.

## Other settings

The other values (harness image, Git author, timeouts, user & group of the pods, resources of the command) are left
to `null`: Yontrack's defaults then apply. Their description, with these defaults, is in the
[values of the chart](../charts/yontrack/README.md), under `autoVersioning.kubernetes`.

## Using it in an auto-versioning configuration

In the auto-versioning configuration of a branch:

```yaml
postProcessing: kubernetes
postProcessingConfig:
  dockerImage: eclipse-temurin:21
  dockerCommand: ./gradlew dependencies --write-locks -Pversion="$VERSION"
  secrets:
    - secret: npm-token
      key: token
      env: NPM_TOKEN
```

`dockerImage` must match `allowed.images`, and every `secret` must be in `allowed.secrets`.
