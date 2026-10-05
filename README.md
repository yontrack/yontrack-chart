Yontrack Helm Chart
==================

This Helm chart is compatible with Helm 3 and allows the installation of Yontrack in a Kubernetes cluster.

<!-- TOC -->
* [Yontrack Helm Chart](#yontrack-helm-chart)
* [Usage](#usage)
* [References](#references)
* [License key](#license-key)
* [Ingress configuration](#ingress-configuration)
* [Authentication](#authentication)
  * [Default local Keycloak instance](#default-local-keycloak-instance)
  * [OIDC for Okta](#oidc-for-okta)
  * [OIDC for Auth0](#oidc-for-auth0)
  * [LDAP](#ldap)
    * [Using a secret for the LDAP credentials](#using-a-secret-for-the-ldap-credentials)
    * [Keycloak LDAP configuration](#keycloak-ldap-configuration)
    * [Active Directory support](#active-directory-support)
  * [Management of users in Yontrack](#management-of-users-in-yontrack)
  * [Logging authentication](#logging-authentication)
  * [Next Auth secret](#next-auth-secret)
  * [Configuration of groups](#configuration-of-groups)
    * [Keycloak database](#keycloak-database)
    * [LDAP in Keycloak](#ldap-in-keycloak)
    * [Okta](#okta)
* [Using a managed database](#using-a-managed-database)
* [Exporting metrics to Elasticsearch](#exporting-metrics-to-elasticsearch)
* [Audit trail evidence storage](#audit-trail-evidence-storage)
  * [External S3-compatible storage](#external-s3-compatible-storage)
  * [Bundled MinIO-compatible storage](#bundled-minio-compatible-storage)
* [Configuration as code (CasC)](#configuration-as-code-casc)
  * [Secrets mappings](#secrets-mappings)
    * [Using environment variables](#using-environment-variables)
    * [Using secret files](#using-secret-files)
  * [CasC directly in values](#casc-directly-in-values)
* [Using a K8S secret for the encryption keys](#using-a-k8s-secret-for-the-encryption-keys)
  * [Generating the secrets from scratch (new installation)](#generating-the-secrets-from-scratch-new-installation)
  * [Copying the secrets (existing installation)](#copying-the-secrets-existing-installation)
  * [Creating the secret in K8S](#creating-the-secret-in-k8s)
  * [Using an external secret for the decryption key](#using-an-external-secret-for-the-decryption-key)
* [OpenShift support](#openshift-support)
* [GitOps / rendered manifests](#gitops--rendered-manifests)
* [Upgrading to 6.x](#upgrading-to-6x)
* [Change log](#change-log)
  * [6.0](#60)
  * [1.0](#10)
  * [0.13](#013)
  * [0.12](#012)
  * [0.11](#011)
  * [0.10](#010)
* [Development](#development)
  * [Template tests](#template-tests)
  * [Documentation generation](#documentation-generation)
<!-- TOC -->

# Usage

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

The Yontrack Helm chart is available as an OCI Helm chart in Docker Hub.

```
helm install yontrack oci://registry-1.docker.io/yontrack/yontrack-chart
```

> [!NOTE]
> The chart used to be published as `oci://registry-1.docker.io/nemerosa/yontrack-chart`.
> For compatibility, it is still published there for all 5.x versions, but **6.x versions
> are only published** to `oci://registry-1.docker.io/yontrack/yontrack-chart`.

> [!TIP]
> 6.x prereleases (`6.0.0-alpha.N`, ...) are ignored by Helm unless you pass `--devel`
> or an explicit `--version`.

To uninstall the chart:

```
helm delete yontrack
```

This installs the following services:

* Yontrack itself
* a Postgres 17 database
* a RabbitMQ message broker

Elasticsearch is no longer needed since 6.0: Yontrack searches in its Postgres database.
It can still be used as a target for the [metrics export](#exporting-metrics-to-elasticsearch).

The default authentication mechanism, if no other configuration is provided, relies on Keycloak
and its own database and two additional services are installed:

* a Keycloak instance configured for storing users
* a Postgres 17 database for Keycloak

> Other authentication options are available. See [authentication](#authentication) below.

# References

See [`charts/yontrack/README.md`](charts/yontrack/README.md) for
the list of all values.

# License key

By default, Yontrack comes with a limited license key, suitable only for evaluation purposes.

When you buy a license key, you have to set it in your configuration:

```yaml
ontrack:
  config:
    license:
      key: "your license key"
```

# Ingress configuration

> The ingress configuration is _required_ if using the default Keycloak setup.

The minimal setup looks like:

```yaml
ontrack:
  url: "https://<host>>"
ingress:
  enabled: true
  annotations:
  # kubernetes.io/ingress.class: nginx
  # cert-manager.io/cluster-issuer: letsencrypt-prod
  host: <host>
```

The following URLs are available:

* `<host>` - the main Yontrack URL to access its UI
* `<host>/graphql` - access to the Yontrack GraphQL API
* `<host>/keycloak` - if the default Keycloak setup is enabled, access to the admin console of Keycloak

> The Yontrack management port (8800) serves unauthenticated endpoints and is never routed.
> The Service exposing it must be of type `ClusterIP`: to expose the Yontrack service with another type,
> set `management.service.specific: true` so that the management port gets its own `ClusterIP` service.

# Authentication

By default, the Yontrack Helm chart sets up an instance of Keycloak, configured to store users for Yontrack.

## Default local Keycloak instance

> See [Keycloak authentication](docs/keycloak.md)

## OIDC for Okta

Yontrack can bypass the Keycloak component altogether and use your own OIDC IdP.

The configuration below works for Okta, but a setup of [Auth0](#oidc-for-auth0) is provided after.

The following values are needed:

```yaml
ontrack:
  # Yontrack root URL
  url: https://****
auth:
  # Enabling OIDC authentication
  kind: oidc
  # Key used for the generation of cookies by the Next Auth frontend
  secret: <openssl rand -hex 32>
  oidc:
    # Display name for your IdP (used for the login page)
    name: <display name for the provider>
    # OIDC issuer URL
    issuer: https://****.okta.com
    # Credentials used to contact the OIDC provider
    credentials:
      # Either stored in a secret (recommended)
      secret:
        # Using a secret
        enabled: true
        # The secret is expected to have the following keys: clientId & clientSecret
        secretName: <secret name>
        # -- Depending on your setup, you can also just create an external secret
        # definition, pointing to the actual secret in a secret provided like
        # Vault or your cloud secret manager
        # If not using an external secret, Yontrack expects you to create the
        # secret manually.
        externalSecret:
          # -- Enabling the creation of the external secret
          enabled: false
          # -- Refresh interval
          refreshInterval: 6h
          # -- Location of the secret to bind to
          store:
            # -- Name of the secret store
            name: vault-backend
            # -- Scope of the secret store
            kind: ClusterSecretStore
            # -- Path to the secret in the store.
            # The entry is expected to have the following keys: clientId & clientSecret
            path: ontrack/oidc
      # ... or provided directly in the values (ok for testing)
      # If a secret (or external secret) is provided, these values are not used
      # clientId: <client id>
      # clientSecret: <client secret>
  # Okta specifics: the JWT emitted by this IdP is not fully OIDC compliant
  jwt:
    # The `typ` attribute emitted by Okta does is not the expected "JWT" value
    typ: application/okta-internal-at+jwt
    # The email in the access token is contained in the `sub` claim
    claims:
      email: sub
```

## OIDC for Auth0

If you're using Auth0 as an OIDC provider, the setup is slightly more complex.

See the dedicated documentation at [`auth0`](docs/auth0.md).

## LDAP

The local Keycloak instance can be configured to use an external LDAP for the management of the Yontrack users:

* Keycloak acts as a proxy
* Keycloak is in read-only mode for the target LDAP (users can be accessed and used for authentication, but not updated)

Use the following values, at a minimum:

```yaml
auth:
  keycloak:
    settings:
      admin:
        enabled: false
    ldap:
      enabled: true
      url: <url to the LDAP>
      usersDn: ou=users,dc=example,dc=com
      bindDn: cn=admin,dc=example,dc=com
      bindCredential: admin
```

There are other [options](charts/yontrack/values.yaml) to configure the mapping of the user fields
in the LDAP to the ones that Keycloak expects. The default mappings are suitable for OpenLDAP.

Yontrack uses Keycloak as a relay to the LDAP, so attention must be given to the settings of
Keycloak as well, in terms of security.

### Using a secret for the LDAP credentials

Using the `bindDn` and `bindCredential` value is not recommended to store the credentials to connect
to the LDAP.

You can use an existing secret by using:

```yaml
auth:
  keycloak:
    ldap:
      bindCredentialSecret:
        enabled: true
        secretName: ontrack-ldap-credentials
```

You can also create an external secret definition to point to your secret store:

```yaml
auth:
  keycloak:
    ldap:
      bindCredentialSecret:
        enabled: true
        externalSecret:
          enabled: true
          refreshInterval: 6h
          store:
            name: vault-backend
            kind: ClusterSecretStore
            path: ontrack/test/v5/ldap
```

### Keycloak LDAP configuration

Values under `auth.keycloak.ldap` can be used to configure the LDAP settings in Keycloak:

```yaml
auth:
  keycloak:
    ldap:
      # -- LDAP attributes: username
      usernameLDAPAttribute: uid
      # -- LDAP attributes: DN
      rdnLDAPAttribute: uid
      # -- LDAP attributes: unique ID
      uuidLDAPAttribute: entryUUID
      # -- LDAP attributes: class for the user object
      userObjectClasses: inetOrgPerson
```

If you need more control on the mapping attributes, you can override the `components` node
of the Keycloak configuration:

```yaml
auth:
  keycloak:
    ldap:
      components:
      # Your config here
```

> See the [values](charts/yontrack/values.yaml) for more information.


### Active Directory support

For Active Directory, you can use the following values for the LDAP configuration:

```yaml
auth:
  keycloak:
    ldap:
      vendor: Active Directory
      usernameLDAPAttribute: sAMAccountName
      rdnLDAPAttribute: cn
      uuidLDAPAttribute: objectGUID
      userObjectClasses: ["person", "organizationalPerson", "user"]
```

## Management of users in Yontrack

For any user connecting to Yontrack through any authentication provider, upon login,
an account is created in Yontrack to hold their authorizations and relationships
to objects in Yontrack. Are stored:

* their username
* their email
* their full name (if available, defaults to the email)

If the `auth.provisioning` is set to `true` (that's the default), a default group
is created with the name "Administrators", with all the rights to administrate Yontrack.

For any user logging with the email defined at `auth.admin.email` (defaults to `admin@ontrack.local`
but should be changed), the account created for this user will be linked automatically
to the "Administrators" group.

In short, to designate which user is the super admin, set the following values:

```yaml
auth:
  admin:
    email: <email of the super user>
```

## Logging authentication

If you face troubles with the authentication, you can add some logging instructions:

```yaml
ontrack:
  config:
    security:
      authorization:
        jwt:
          debug:true
```

## Next Auth secret

The Next Auth secret used to generate cookies on the client side
is automatically generated.

In case more control is needed (like reusing an existing secret),
you can tune its configuration using:

```yaml
auth:
  next:
    secret:
      name: ontrack-next-auth
      generate: false
```

To use an external secret:

```yaml
auth:
  next:
    secret:
      name: ontrack-next-auth
      generate: false
      externalSecret:
        enabled: true
        refreshInterval: 6h
        store:
          name: vault-backend
          kind: ClusterSecretStore
          path: ontrack/next-auth
```

In this example, the Vault secret must have a `secret` entry containing the secret value.

## Configuration of groups

If groups set in the IdP are passed in the `groups` claim of the JWT access token, Yontrack
has access to them, and they can be mapped to actual Yontrack groups to grant authorisations
to groups of people belonging to same group.

The way to setup the groups depend on the IdP you are using.

### Keycloak database

You can configure the users and the groups directly in Keycloak, or declare them in the values
(not compatible with the [LDAP in Keycloak](#ldap-in-keycloak)):

```yaml
auth:
  keycloak:
    settings:
      groups:
        - scanners
      users:
        - username: scanner
          email: scanner@example.com
          firstName: Security
          lastName: Scanner
          groups:
            - scanners
          passwordSecret:
            name: yontrack-scanner
            key: password
```

* all the fields are required; `groups` must be declared in `auth.keycloak.settings.groups`
* the password of each user is read from an existing secret: it is never in the values nor in the rendered realm,
  and must not contain `"` nor `\`
* these users are created next to the `auth.keycloak.settings.admin` user

Keycloak imports the realm only when it does not exist yet. For an existing installation,
a post-install/post-upgrade job (`<release>-keycloak-users`) adds the missing groups & users to the realm,
using the Keycloak bootstrap administrator credentials (see [Keycloak authentication](docs/keycloak.md)).
Groups & users which already exist in the realm are left untouched: changing the password or the groups of an
existing user in the values has no effect, and removing a user from the values does not delete it.

> The job needs the Keycloak bootstrap administrator credentials to still be valid: if this account has been
> deleted or its password changed in Keycloak only, the job fails, and so does the `helm install/upgrade`.

> The `groups` claim is automatically configured to be injected into the JWT access token.

### LDAP in Keycloak

When an external LDAP is enabled in Keycloak, you need to configure how the LDAP groups are detected
by Keycloak.

The mapping defaults to:

```yaml
auth:
  keycloak:
    ldap:
      groups:
        # -- Groups DN
        groupsDn: "ou=groups,dc=example,dc=com"
        membershipAttributeType: DN
        membershipUserLdapAttribute: uid
        membershipLdapAttribute: member
        memberofLdapAttribute: memberOf
        groupNameLdapAttribute: cn
        groupObjectClasses: groupOfNames
```

> The `groups` claim is automatically configured to be injected into the JWT access token.

### Okta

If you want to use Okta groups in the group mappings in Yontrack, go to _Sign On_ section of
the application and make sure to select a list of groups (using a filter):

![Okta groups](docs/auth-okta-groups.png)

# Using a managed database

In order to use a managed database, create a values file and fill the URL and credentials to access the database:

```yaml
postgresql:
  local: false
  auth:
    username: ontrack
    password: "*****"
  postgresqlUrl: "jdbc:postgresql://<host>:<port>/ontrack?sslmode=require"
```

Then, run the installation using this values file:

```bash
helm install -f values.yaml yontrack oci://registry-1.docker.io/yontrack/yontrack-chart
```

The setup of the Postgres service will be skipped and Yontrack will be configured to use the remote database.

Alternatively, if your connection parameters are in environment variables, you can skip this configuration altogether:

```yaml
postgresql:
  local: false
  postgresFromEnv: true
```

This requires the following environmment variables to be set:

* `SPRING_DATASOURCE_URL` - complete JDBC URL, like `jdbc:postgresql://<host>:<port>/ontrack?sslmode=require`
* `SPRING_DATASOURCE_USERNAME` - username for the connection
* `SPRING_DATASOURCE_PASSWORD` - password for the connection

> [!IMPORTANT]
> Yontrack 6 needs the `pg_trgm` extension of Postgres for its search. It creates it at its first start
> (`CREATE EXTENSION IF NOT EXISTS pg_trgm`), which works when its database user owns the database:
> `pg_trgm` is a trusted extension since Postgres 13, including on RDS, Cloud SQL and Azure.
> Otherwise, create it beforehand, once, in the Yontrack database, as a user who can.
> See [Search index](https://github.com/yontrack/yontrack/blob/main/ontrack-docs/docs/content/operations/search-index.md).

# Exporting metrics to Elasticsearch

Yontrack can export its metrics to an Elasticsearch cluster. This is disabled by default and the chart
does not deploy any Elasticsearch: point it to an existing cluster.

```yaml
elasticsearch:
  metrics:
    enabled: true
    # Optional, defaults to ontrack_metrics
    index: ontrack_metrics
  uris: https://elasticsearch.example.com:9200
  # Optional credentials
  username: yontrack
  # Existing secret holding the password
  existingSecret: yontrack-elasticsearch
  existingSecretPasswordKey: password
```

When the export is enabled, the Elasticsearch health indicator is part of the health of Yontrack.

# Audit trail evidence storage

The audit trail of Yontrack 6 stores its evidence files in an S3-compatible bucket.
Without any storage, the audit trail still works, but evidence is not available: Yontrack
reports a `DEGRADED` (not `DOWN`) health and shows a warning.

The storage is configured by the `auditTrail.storage` values, mapped to the
`ontrack.extension.audit-trail.storage.*` properties of Yontrack. The credentials are only read
from an existing secret.

## External S3-compatible storage

Create a secret holding the access & secret keys:

```bash
kubectl create secret generic yontrack-evidence \
  --from-literal=accessKey=<access key> \
  --from-literal=secretKey=<secret key>
```

and point the storage to the bucket, which must exist:

```yaml
auditTrail:
  storage:
    endpoint: https://fra1.digitaloceanspaces.com
    bucket: yontrack-evidence
    region: fra1
    # Optional, defaults to 50MB
    maxSize: 50MB
    existingSecret: yontrack-evidence
    # Keys in the secret (these are the defaults)
    accessKeyKey: accessKey
    secretKeyKey: secretKey
```

| Provider            | `endpoint`                                | `region`    | `pathStyle` |
|---------------------|-------------------------------------------|-------------|-------------|
| AWS S3              | `https://s3.<region>.amazonaws.com`       | `<region>`  | `false`     |
| DigitalOcean Spaces | `https://<region>.digitaloceanspaces.com` | `<region>`  | `false`     |
| MinIO               | `http://<host>:9000`                      | any         | `true`      |

Keep the bucket private, and back it up yourself: it is not part of the database backups.
See the [audit trail documentation](https://github.com/yontrack/yontrack/blob/main/ontrack-docs/docs/content/audit-trail/index.md)
of Yontrack.

## Bundled MinIO-compatible storage

For testing or small installations, the chart can deploy its own storage, off by default:

```yaml
auditTrail:
  minio:
    enabled: true
    # Optional, these are the defaults
    bucket: yontrack-audit-trail
    persistence:
      size: 10Gi
```

It deploys [Silo](https://github.com/pgsty/silo), the community fork of MinIO (MinIO Inc. no longer
publishes images), as a single node with its own volume, and creates the bucket when it starts.
Yontrack then uses it: endpoint, bucket, path-style access and credentials. The bundled MinIO
cannot be combined with an external storage: `auditTrail.storage.endpoint`, `bucket` and
`existingSecret` must be left empty (`region` and `maxSize` still apply).

The root credentials are generated in a secret, unless `auditTrail.minio.existingSecret` names an
existing one, holding them under the `auditTrail.minio.rootUserKey` & `rootPasswordKey` keys
(`rootUser` & `rootPassword` by default).

# Configuration as code (CasC)

Casc is enabled by default in Yontrack starting from version 5.

Casc can take its values from a configuration map and/or a secret:

```yaml
ontrack:
  casc:
    enabled: true
    map: some-config-map-name
    secret: some-secret-name
```

Both must contain entries called `<any-name>.yaml` containing some YAML Casc code.

## Secrets mappings

Casc files can contain `{{ secret.name.property }}` which are extrapolated using environment variables or secret files.

### Using environment variables

The default behaviour is to use environment variables. The name of the environment variable to consider is:
`SECRET_<NAME>_<PROPERTY>`.

For example, if YAML Casc fragment contains:

```yaml
ontrack:
  config:
    github:
      - name: github.com
        token: {{ secret.github.token }}
```

Given a `ontrack-github` K8S secret containing the secret token in its `token` property, you can just set the following
values for the chart:

```yaml
ontrack:
  casc:
    enabled: true
    map: some-config-map-name
  env:
    - name: SECRET_GITHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: "ontrack-github"
          key: "token"
```

### Using secret files

Instead of using environment variables, you can also map secrets to files and tell Yontrack to refer to the secrets in
the files.

Given the example above:

```yaml
ontrack:
  config:
    github:
      - name: github.com
        token: {{ secret.github.token }}
```

You can map the `ontrack-github` K8S secret onto a volume and tell Yontrack to use this volume:

```yaml
ontrack:
  casc:
    enabled: true
    map: some-config-map-name
    secrets:
      mapping: file
      names:
        - ontrack-github
```

## CasC directly in values

You can use the `casc` top value to declare the Casc configuration directly in the values:

```yaml
casc:
  ontrack:
    config:
      github:
        - name: github.com
          token: {{ secret.github.token }}
```

# Using a K8S secret for the encryption keys

Yontrack encrypts the credentials used to connect to external systems, using an AES256 key.

This key is by default stored into the database itself, which is OK to get started, but this has two issues:

* it's not very secure since the key used to encrypts credentials in the database is stored in the database
* when migrating an Yontrack installation from a file store, it's not easy to migrate

When using the Yontrack Helm chart, you can use a K8S secret to store this encryption key.

There are two scenarios.

## Generating the secrets from scratch (new installation)

````bash
openssl rand 256 > net.nemerosa.ontrack.security.EncryptionServiceImpl.encryption
````

## Copying the secrets (existing installation)

To get the existing key from Yontrack, use:

```bash
# For Ontrack V4
curl --user admin https://<ontrack>/rest/admin/encryption | base64 -d > net.nemerosa.ontrack.security.EncryptionServiceImpl.encryption
# For Ontrack V3
curl --user admin https://<ontrack>/admin/encryption | base64 -d > net.nemerosa.ontrack.security.EncryptionServiceImpl.encryption
```

In both cases (V3 & V4), the username MUST be `admin`. No other user, even one with the `Administrators` role, will be
accepted.

## Creating the secret in K8S

Given the `net.nemerosa.ontrack.security.EncryptionServiceImpl.encryption` file, generate a secret in the same namespace
as Yontrack:

```bash
kubectl create secret generic ontrack-key-store --from-file=net.nemerosa.ontrack.security.EncryptionServiceImpl.encryption
```

Configure the Yontrack values to use this secret:

```yaml
ontrack:
  config:
    key_store: secret
    # If need be, the default secret name - ontrack-key-store - can be configured here
    # secret_key_store:
    #   secret_name: "ontrack-key-store"
```

## Using an external secret for the decryption key

You can store the AES 256 decryption key in a secret store (like Vault):

```yaml
ontrack:
  config:
    key_store: secret
    secret_key_store:
      external:
        enabled: true
        refreshInterval: 6h
        store:
          name: vault-backend
          kind: ClusterSecretStore
          path: ontrack/encryption
          key: key
```

# OpenShift support

The chart has some support for OpenShift. To enable it, set `openshift.enabled` to `true`.

```bash
helm install ontrack ontrack/yontrack-chart --set openshift.enabled=true
```

When enabled:
* an OpenShift `Route` is created instead of a standard `Ingress`.
* default security contexts are more likely to be compatible with OpenShift restricted SCC.
* init containers are also configured with security contexts.

For the sub-charts (PostgreSQL, RabbitMQ), the `global.compatibility.openshift.adaptSecurityContext` is set to `auto` by default to help them run on OpenShift.

# GitOps / rendered manifests

When using a GitOps workflow (e.g. ArgoCD, Flux) where Helm templates are rendered and committed to a
git repository, every chart or app version bump would normally produce a diff touching every resource,
because `helm.sh/chart` and `app.kubernetes.io/version` are included in all resource labels by default.

To suppress this churn, these two labels are **omitted by default**. Set `includeVersionLabels: true`
to re-enable them (useful for observability tooling that relies on these labels for filtering):

```yaml
includeVersionLabels: true
```

# Upgrading to 6.x

Chart 6.x installs Yontrack 6, which no longer needs Elasticsearch: the chart does not deploy it anymore.
See also the [migration guide](https://github.com/yontrack/yontrack/blob/main/ontrack-docs/docs/content/appendix/migration-to-v6.md) of Yontrack.

* Remove `elasticsearch.enabled` and the other settings of the former Elasticsearch sub-chart from your values.
  Rendering fails if `elasticsearch.enabled` is still `true`.
* If you used an external Elasticsearch for the metrics, see [Exporting metrics to Elasticsearch](#exporting-metrics-to-elasticsearch).
  The `SPRING_ELASTICSEARCH_*` environment variables are no longer needed otherwise.
* After the upgrade, the volume of the former Elasticsearch instance is kept but no longer used.
  The search is rebuilt from the Postgres database at the first start of Yontrack 6. Delete the volume with:

```bash
kubectl delete pvc data-<release>-elasticsearch-master-0
```

* With a [managed database](#using-a-managed-database), check the `pg_trgm` prerequisite.
* The legacy `oci://registry-1.docker.io/nemerosa/yontrack-chart` location only receives 5.x versions.

# Change log

| Version        | Postgres | Elasticsearch | Rabbit MQ | Kubernetes | Minimal Yontrack version |
|----------------|----------|---------------|-----------|------------|-------------------------|
| [6.0.x](#60)   | 17       | optional (metrics only) | 4 | 1.24  | 6.0                     |
| [5.0.x](#10)   | 17       | 9             | 4         | 1.24       | 5.0.0                   |
| [0.13.x](#013) | 15       | 7             | 3         | 1.24       | 4.12.3                  |
| [0.12.x](#012) | 15       | 7             | 3         | 1.24       | 4.11.0                  |
| [0.11.x](#011) | 15       | 7             | 3         | 1.24       | 4.8.12                  |
| [0.10.x](#010) | 15       | 7             | 3         | 1.24       | 4.8.1                   |
| 0.9.x          | 15       | 7             | 3         | 1.24       | 4.7.20                  |
| 0.8.x          | 11       | 7             | 3         | 1.24       | 4.7.13                  |

## 6.0

* Support for Yontrack 6
* Elasticsearch is no longer bundled, only used for the optional [metrics export](#exporting-metrics-to-elasticsearch)
* [Audit trail evidence storage](#audit-trail-evidence-storage), with an optional bundled MinIO-compatible storage
* See [Upgrading to 6.x](#upgrading-to-6x)

## 1.0

* Support for Ontrack V5
* Support for the license key has [changed](#license-key)
* Support for the different [authentication options](#authentication)

## 0.13

* Upgrade of minor versions for Elasticsearch & RabbitMQ

## 0.12

* Support for license keys:

```yaml
ontrack:
  config:
    license:
      type: embedded
      key: ....
```

## 0.11

* Support for the `fixed` license:

```yaml
ontrack:
  config:
    license:
      type: fixed
      fixed:
        name: Premium
        assignee: Nemerosa
        active: true
        validUntil: 2024-12-31T12:00:00
        maxProjects: 0
```

## 0.10

* Support for [Next UI](#enabling-next-ui)

* **BREAKING** Ingress setup has been simplified, only the `ontrack.url` value is needed; no `path` must be provided any
  longer. Hosts and TLS setup must be provided as usual

Before:

```yaml
ingress:
  enabled: true
  annotations:
  # ...
  hosts:
    - host: ${host}
      paths:
        - path: "/"
  tls:
    - secretName: ${host}-tls
      hosts:
        - ${host}
```

Now:

```yaml
ontrack:
  url: https://${host}
ingress:
  enabled: true
  annotations:
  # ...
  hosts:
    - host: ${host}
  tls:
    - secretName: ${host}-tls
      hosts:
        - ${host}
```

# Development

## Template tests

Assertions on the rendered templates (Keycloak users & groups, management port never routed)
are run by the CI and can be run locally (requires `helm`, `jq` and `yq`):

```bash
./scripts/test-templates.sh
```

## Documentation generation

The list of values for the chart are documented into this `README`
file automatically by running [`helm-docs`](https://github.com/norwoodj/helm-docs).

> Follow its documentation for the installation of the tool.

To generate the documentation, just run:

```bash
helm-docs
```

The [`charts/yontrack/README.md`](charts/yontrack/README.md) is generated
and referred to from the main `README`.

In the [`charts/yontrack/values.yaml`](charts/yontrack/values.yaml) file,
documentation of the values must be introduced using comments
prefixed by `# --`.
