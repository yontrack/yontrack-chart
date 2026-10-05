# yontrack-chart

![Version: 6.0.0-alpha.3](https://img.shields.io/badge/Version-6.0.0--alpha.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 6.0-alpha.0](https://img.shields.io/badge/AppVersion-6.0--alpha.0-informational?style=flat-square)

A Helm chart for Kubernetes

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | postgresql | 16.7.27 |
| https://charts.bitnami.com/bitnami | rabbitmq | 16.0.14 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Node affinity for the Yontrack resources |
| auditTrail.minio.bucket | string | `"yontrack-audit-trail"` | Name of the bucket to create |
| auditTrail.minio.enabled | bool | `false` | Deploying a MinIO-compatible storage for the evidence |
| auditTrail.minio.existingSecret | string | `""` | Name of an existing secret holding the root user & password. When empty, they are generated. |
| auditTrail.minio.image.pullPolicy | string | `"IfNotPresent"` | Pull policy |
| auditTrail.minio.image.repository | string | `"pgsty/silo"` | Image of the MinIO-compatible server (Silo, the community fork of MinIO, which no longer publishes images) |
| auditTrail.minio.image.tag | string | `"RELEASE.2026-09-16T00-00-00Z"` | Version of the image |
| auditTrail.minio.persistence.accessMode | string | `"ReadWriteOnce"` | Access mode of the volume |
| auditTrail.minio.persistence.annotations | object | `{}` | Annotations of the PVC |
| auditTrail.minio.persistence.size | string | `"10Gi"` | Size of the volume |
| auditTrail.minio.persistence.storageClass | string | `""` | Storage class of the volume ("-" for none, empty for the default one) |
| auditTrail.minio.resources | object | `{}` | Resources of the MinIO container |
| auditTrail.minio.rootPasswordKey | string | `"rootPassword"` | Key of the root password in the secret |
| auditTrail.minio.rootUserKey | string | `"rootUser"` | Key of the root user in the secret |
| auditTrail.storage.accessKeyKey | string | `"accessKey"` | Key of the access key in the secret |
| auditTrail.storage.bucket | string | `""` | Name of the bucket, which must exist |
| auditTrail.storage.endpoint | string | `""` | S3 endpoint, like https://s3.<region>.amazonaws.com or https://<region>.digitaloceanspaces.com |
| auditTrail.storage.existingSecret | string | `""` | Name of an existing secret holding the access & secret keys |
| auditTrail.storage.maxSize | string | `""` | Maximum size of an evidence file, like 50MB. When empty, Yontrack's default applies (50MB). |
| auditTrail.storage.pathStyle | bool | `false` | Path-style access to the bucket (true for MinIO) |
| auditTrail.storage.region | string | `"us-east-1"` | Region of the bucket |
| auditTrail.storage.secretKeyKey | string | `"secretKey"` | Key of the secret key in the secret |
| auth | object | `{"admin":{"email":"admin@ontrack.local","force":false,"fullName":"Administrator","groupName":"Administrators"},"keycloak":{"account":{"url":"http://localhost:8008/realms/ontrack/account"},"bootstrap":{"bootstrapSecret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/bootstrap","usernameKey":"username"}},"generate":true,"passwordKey":"password","secretName":"ontrack-keycloak-bootstrap","usernameKey":"username"},"password":"admin","username":"admin"},"client":{"id":"yontrack-client","secret":"yontrack-client-secret"},"clientName":"yontrack-client","external":{"enabled":false,"url":"https://keycloak"},"image":"quay.io/keycloak/keycloak","ldap":{"bindCredential":"admin","bindCredentialSecret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/ldap"}},"secretName":"ontrack-ldap-credentials"},"bindDn":"cn=admin,dc=example,dc=com","components":{},"enabled":false,"groups":{"groupNameLdapAttribute":"cn","groupObjectClasses":"groupOfNames","groupsDn":"ou=groups,dc=example,dc=com","memberofLdapAttribute":"memberOf","membershipAttributeType":"DN","membershipLdapAttribute":"member","membershipUserLdapAttribute":"uid"},"id":"ldap-users","mappers":{"groups":{"preserveGroupInheritance":true},"name":{"attribute":"name","enabled":true}},"name":"ldap-users","rdnLDAPAttribute":"uid","searchScope":1,"testing":{"admin":{"password":"admin"},"enabled":false,"image":"osixia/openldap","provisioning":{"admin":{"sshaPassword":"{SSHA}cqhYu0IJNPgwklQuoENm6PtzGJLpPkgt"},"domain":{"extension":"com","name":"yontrack"},"enabled":true,"organisation":"Yontrack"},"resources":{},"tag":"1.5.0"},"url":"ldap://ldap:389","userObjectClasses":["inetOrgPerson"],"usernameLDAPAttribute":"uid","usersDn":"ou=users,dc=example,dc=com","uuidLDAPAttribute":"entryUUID","vendor":"other"},"logLevel":"INFO","name":"Yontrack","persistence":{"connection":{"database":"keycloak","password":"keycloak","secret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/postgres"}},"name":"keycloak-postgresql"},"username":"keycloak"},"image":{"pullPolicy":"IfNotPresent","repository":"bitnamilegacy/postgresql","tag":17},"pvc":{"accessMode":"ReadWriteOnce","annotations":{},"size":"5Gi","storageClass":null},"resources":{},"service":{"type":"ClusterIP"}},"realm":"ontrack","resources":{},"secret":{"enabled":false,"external":{"enabled":false,"refreshInterval":"6h","store":{"key":"client-secret","kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/client"}},"generate":true,"name":"ontrack-keycloak"},"service":{"ingressEnabled":true,"path":"keycloak","port":8080},"settings":{"accessTokenLifespan":3600,"admin":{"email":"","enabled":true,"firstName":"Admin","lastName":"User","password":"admin","secret":{"enabled":false,"external":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/admin","usernameKey":"username"}},"name":"yontrack-admin"},"username":"admin"},"enabled":true,"groups":[],"registrationAllowed":true,"resetPasswordAllowed":true,"ssoSessionIdleTimeout":3600,"users":[]},"tag":"26.2.5","verbose":false},"kind":"keycloak","next":{"secret":{"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/next-auth"}},"generate":true,"name":"ontrack-next-auth"}},"oidc":{"credentials":{"client":{"clientId":"<client id>","clientSecret":"<client secret>"},"secret":{"enabled":true,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/oidc"}},"secretName":"ontrack-oidc"}},"issuer":"","name":"OIDC","scope":"openid profile email","trailingSlash":false},"provisioning":true}` | Authentication |
| auth.admin | object | `{"email":"admin@ontrack.local","force":false,"fullName":"Administrator","groupName":"Administrators"}` | Configuration of the initial administrator |
| auth.admin.email | string | `"admin@ontrack.local"` | Their email |
| auth.admin.force | bool | `false` | Force the creation/update of the administrator user even if it already exists |
| auth.admin.fullName | string | `"Administrator"` | Their full name (if not provided) |
| auth.admin.groupName | string | `"Administrators"` | Group of administrators |
| auth.keycloak | object | `{"account":{"url":"http://localhost:8008/realms/ontrack/account"},"bootstrap":{"bootstrapSecret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/bootstrap","usernameKey":"username"}},"generate":true,"passwordKey":"password","secretName":"ontrack-keycloak-bootstrap","usernameKey":"username"},"password":"admin","username":"admin"},"client":{"id":"yontrack-client","secret":"yontrack-client-secret"},"clientName":"yontrack-client","external":{"enabled":false,"url":"https://keycloak"},"image":"quay.io/keycloak/keycloak","ldap":{"bindCredential":"admin","bindCredentialSecret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/ldap"}},"secretName":"ontrack-ldap-credentials"},"bindDn":"cn=admin,dc=example,dc=com","components":{},"enabled":false,"groups":{"groupNameLdapAttribute":"cn","groupObjectClasses":"groupOfNames","groupsDn":"ou=groups,dc=example,dc=com","memberofLdapAttribute":"memberOf","membershipAttributeType":"DN","membershipLdapAttribute":"member","membershipUserLdapAttribute":"uid"},"id":"ldap-users","mappers":{"groups":{"preserveGroupInheritance":true},"name":{"attribute":"name","enabled":true}},"name":"ldap-users","rdnLDAPAttribute":"uid","searchScope":1,"testing":{"admin":{"password":"admin"},"enabled":false,"image":"osixia/openldap","provisioning":{"admin":{"sshaPassword":"{SSHA}cqhYu0IJNPgwklQuoENm6PtzGJLpPkgt"},"domain":{"extension":"com","name":"yontrack"},"enabled":true,"organisation":"Yontrack"},"resources":{},"tag":"1.5.0"},"url":"ldap://ldap:389","userObjectClasses":["inetOrgPerson"],"usernameLDAPAttribute":"uid","usersDn":"ou=users,dc=example,dc=com","uuidLDAPAttribute":"entryUUID","vendor":"other"},"logLevel":"INFO","name":"Yontrack","persistence":{"connection":{"database":"keycloak","password":"keycloak","secret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/postgres"}},"name":"keycloak-postgresql"},"username":"keycloak"},"image":{"pullPolicy":"IfNotPresent","repository":"bitnamilegacy/postgresql","tag":17},"pvc":{"accessMode":"ReadWriteOnce","annotations":{},"size":"5Gi","storageClass":null},"resources":{},"service":{"type":"ClusterIP"}},"realm":"ontrack","resources":{},"secret":{"enabled":false,"external":{"enabled":false,"refreshInterval":"6h","store":{"key":"client-secret","kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/client"}},"generate":true,"name":"ontrack-keycloak"},"service":{"ingressEnabled":true,"path":"keycloak","port":8080},"settings":{"accessTokenLifespan":3600,"admin":{"email":"","enabled":true,"firstName":"Admin","lastName":"User","password":"admin","secret":{"enabled":false,"external":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/admin","usernameKey":"username"}},"name":"yontrack-admin"},"username":"admin"},"enabled":true,"groups":[],"registrationAllowed":true,"resetPasswordAllowed":true,"ssoSessionIdleTimeout":3600,"users":[]},"tag":"26.2.5","verbose":false}` | Configuration of the local Keycloak instance |
| auth.keycloak.account | object | `{"url":"http://localhost:8008/realms/ontrack/account"}` | Account management from Yontrack |
| auth.keycloak.account.url | string | `"http://localhost:8008/realms/ontrack/account"` | If set to not blank, URL to allow users to manage their own account |
| auth.keycloak.bootstrap | object | `{"bootstrapSecret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/bootstrap","usernameKey":"username"}},"generate":true,"passwordKey":"password","secretName":"ontrack-keycloak-bootstrap","usernameKey":"username"},"password":"admin","username":"admin"}` | Admin user for the admin console of Keycloak |
| auth.keycloak.bootstrap.bootstrapSecret | object | `{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/bootstrap","usernameKey":"username"}},"generate":true,"passwordKey":"password","secretName":"ontrack-keycloak-bootstrap","usernameKey":"username"}` | Secret for the bootstrapping |
| auth.keycloak.bootstrap.bootstrapSecret.enabled | bool | `false` | Enabling using a secret |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret | object | `{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/bootstrap","usernameKey":"username"}}` | Using an external secret |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret.enabled | bool | `false` | Creating the external secret definition |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret.refreshInterval | string | `"6h"` | Refresh interval |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret.store | object | `{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/bootstrap","usernameKey":"username"}` | Location of the secret to bind to |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret.store.name | string | `"vault-backend"` | Name of the secret store |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret.store.passwordKey | string | `"password"` | Password key |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret.store.path | string | `"ontrack/keycloak/bootstrap"` | Path to the secret in the store. The entry is expected to have the following keys: bindDn & bindCredential |
| auth.keycloak.bootstrap.bootstrapSecret.externalSecret.store.usernameKey | string | `"username"` | Username key |
| auth.keycloak.bootstrap.bootstrapSecret.generate | bool | `true` | Generating the secret (the password only, keeping the username) |
| auth.keycloak.bootstrap.bootstrapSecret.passwordKey | string | `"password"` | Secret key for the password |
| auth.keycloak.bootstrap.bootstrapSecret.secretName | string | `"ontrack-keycloak-bootstrap"` | Secret name |
| auth.keycloak.bootstrap.bootstrapSecret.usernameKey | string | `"username"` | Secret key for the username |
| auth.keycloak.bootstrap.password | string | `"admin"` | Password to connect to Bootstrap. Prefer using a secret. |
| auth.keycloak.bootstrap.username | string | `"admin"` | Username to connect to Bootstrap. Prefer using a secret. |
| auth.keycloak.client | object | `{"id":"yontrack-client","secret":"yontrack-client-secret"}` | Connection parameters to Keycloak |
| auth.keycloak.client.id | string | `"yontrack-client"` | Client ID |
| auth.keycloak.client.secret | string | `"yontrack-client-secret"` | Value of the client secret - should not be used in production |
| auth.keycloak.clientName | string | `"yontrack-client"` | Name of the Keycloak client |
| auth.keycloak.external | object | `{"enabled":false,"url":"https://keycloak"}` | If using an external Keycloak instance |
| auth.keycloak.external.enabled | bool | `false` | Enabling an external Keycloak instance |
| auth.keycloak.external.url | string | `"https://keycloak"` | URL to the external Keycloak instance |
| auth.keycloak.image | string | `"quay.io/keycloak/keycloak"` | Image of Keycloak to deploy |
| auth.keycloak.ldap | object | `{"bindCredential":"admin","bindCredentialSecret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/ldap"}},"secretName":"ontrack-ldap-credentials"},"bindDn":"cn=admin,dc=example,dc=com","components":{},"enabled":false,"groups":{"groupNameLdapAttribute":"cn","groupObjectClasses":"groupOfNames","groupsDn":"ou=groups,dc=example,dc=com","memberofLdapAttribute":"memberOf","membershipAttributeType":"DN","membershipLdapAttribute":"member","membershipUserLdapAttribute":"uid"},"id":"ldap-users","mappers":{"groups":{"preserveGroupInheritance":true},"name":{"attribute":"name","enabled":true}},"name":"ldap-users","rdnLDAPAttribute":"uid","searchScope":1,"testing":{"admin":{"password":"admin"},"enabled":false,"image":"osixia/openldap","provisioning":{"admin":{"sshaPassword":"{SSHA}cqhYu0IJNPgwklQuoENm6PtzGJLpPkgt"},"domain":{"extension":"com","name":"yontrack"},"enabled":true,"organisation":"Yontrack"},"resources":{},"tag":"1.5.0"},"url":"ldap://ldap:389","userObjectClasses":["inetOrgPerson"],"usernameLDAPAttribute":"uid","usersDn":"ou=users,dc=example,dc=com","uuidLDAPAttribute":"entryUUID","vendor":"other"}` | Configuration of Keycloak to use a LDAP for user federation |
| auth.keycloak.ldap.bindCredential | string | `"admin"` | Bind credentials Not recommended in production, better use a secret |
| auth.keycloak.ldap.bindCredentialSecret | object | `{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/ldap"}},"secretName":"ontrack-ldap-credentials"}` | Bind credentials in a secret |
| auth.keycloak.ldap.bindCredentialSecret.enabled | bool | `false` | Using a secret to store the credentials |
| auth.keycloak.ldap.bindCredentialSecret.externalSecret | object | `{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/ldap"}}` | Using an external secret |
| auth.keycloak.ldap.bindCredentialSecret.externalSecret.enabled | bool | `false` | Creating the external secret definition |
| auth.keycloak.ldap.bindCredentialSecret.externalSecret.refreshInterval | string | `"6h"` | Refresh interval |
| auth.keycloak.ldap.bindCredentialSecret.externalSecret.store | object | `{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/ldap"}` | Location of the secret to bind to |
| auth.keycloak.ldap.bindCredentialSecret.externalSecret.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| auth.keycloak.ldap.bindCredentialSecret.externalSecret.store.name | string | `"vault-backend"` | Name of the secret store |
| auth.keycloak.ldap.bindCredentialSecret.externalSecret.store.path | string | `"ontrack/keycloak/ldap"` | Path to the secret in the store. The entry is expected to have the following keys: bindDn & bindCredential |
| auth.keycloak.ldap.bindCredentialSecret.secretName | string | `"ontrack-ldap-credentials"` | Name of the secret This secret is expected to have the following keys: * bindDn * bindCredential |
| auth.keycloak.ldap.bindDn | string | `"cn=admin,dc=example,dc=com"` | Bind DN Prefer using a secret |
| auth.keycloak.ldap.components | object | `{}` | If defined, provides the _whole_ LDAP configuration in Keycloak (under the `components` node) |
| auth.keycloak.ldap.enabled | bool | `false` | Using a LDAP |
| auth.keycloak.ldap.groups | object | `{"groupNameLdapAttribute":"cn","groupObjectClasses":"groupOfNames","groupsDn":"ou=groups,dc=example,dc=com","memberofLdapAttribute":"memberOf","membershipAttributeType":"DN","membershipLdapAttribute":"member","membershipUserLdapAttribute":"uid"}` | Configuration of the LDAP groups |
| auth.keycloak.ldap.groups.groupsDn | string | `"ou=groups,dc=example,dc=com"` | Groups DN |
| auth.keycloak.ldap.id | string | `"ldap-users"` | ID of the LDAP federation in Keycloak |
| auth.keycloak.ldap.mappers | object | `{"groups":{"preserveGroupInheritance":true},"name":{"attribute":"name","enabled":true}}` | Mappers configurations |
| auth.keycloak.ldap.mappers.groups | object | `{"preserveGroupInheritance":true}` | `groups` mapper |
| auth.keycloak.ldap.mappers.groups.preserveGroupInheritance | bool | `true` | Preserve group inheritance |
| auth.keycloak.ldap.mappers.name | object | `{"attribute":"name","enabled":true}` | Mapping of the full name |
| auth.keycloak.ldap.mappers.name.attribute | string | `"name"` | LDAP attribute containing the full name |
| auth.keycloak.ldap.mappers.name.enabled | bool | `true` | Enabling the mapper |
| auth.keycloak.ldap.name | string | `"ldap-users"` | Name of the LDAP federation in Keycloak |
| auth.keycloak.ldap.rdnLDAPAttribute | string | `"uid"` | LDAP attributes: DN |
| auth.keycloak.ldap.searchScope | int | `1` | Search scope for the users 1: One Level 2: Subtree |
| auth.keycloak.ldap.testing | object | `{"admin":{"password":"admin"},"enabled":false,"image":"osixia/openldap","provisioning":{"admin":{"sshaPassword":"{SSHA}cqhYu0IJNPgwklQuoENm6PtzGJLpPkgt"},"domain":{"extension":"com","name":"yontrack"},"enabled":true,"organisation":"Yontrack"},"resources":{},"tag":"1.5.0"}` | Creating a testing LDAP instance |
| auth.keycloak.ldap.testing.admin | object | `{"password":"admin"}` | Admin user |
| auth.keycloak.ldap.testing.admin.password | string | `"admin"` | Its password |
| auth.keycloak.ldap.testing.enabled | bool | `false` | Enabling the creation of the LDAP test instance |
| auth.keycloak.ldap.testing.image | string | `"osixia/openldap"` | Image to be used for the LDAP service |
| auth.keycloak.ldap.testing.provisioning | object | `{"admin":{"sshaPassword":"{SSHA}cqhYu0IJNPgwklQuoENm6PtzGJLpPkgt"},"domain":{"extension":"com","name":"yontrack"},"enabled":true,"organisation":"Yontrack"}` | Provisioning of the LDAP |
| auth.keycloak.ldap.testing.provisioning.admin | object | `{"sshaPassword":"{SSHA}cqhYu0IJNPgwklQuoENm6PtzGJLpPkgt"}` | Admin user |
| auth.keycloak.ldap.testing.provisioning.admin.sshaPassword | string | `"{SSHA}cqhYu0IJNPgwklQuoENm6PtzGJLpPkgt"` | SSHA admin password `slappasswd -h {SSHA} -s admin` |
| auth.keycloak.ldap.testing.provisioning.domain | object | `{"extension":"com","name":"yontrack"}` | Domain name |
| auth.keycloak.ldap.testing.provisioning.enabled | bool | `true` | Is it enabled? |
| auth.keycloak.ldap.testing.provisioning.organisation | string | `"Yontrack"` | Organization name |
| auth.keycloak.ldap.testing.resources | object | `{}` | Resources to allocate |
| auth.keycloak.ldap.testing.tag | string | `"1.5.0"` | Tag to be used for the LDAP service |
| auth.keycloak.ldap.url | string | `"ldap://ldap:389"` | URL to the ldap |
| auth.keycloak.ldap.userObjectClasses | list | `["inetOrgPerson"]` | LDAP attributes: class for the user object |
| auth.keycloak.ldap.usernameLDAPAttribute | string | `"uid"` | LDAP attributes: username |
| auth.keycloak.ldap.usersDn | string | `"ou=users,dc=example,dc=com"` | Users DN |
| auth.keycloak.ldap.uuidLDAPAttribute | string | `"entryUUID"` | LDAP attributes: unique ID |
| auth.keycloak.ldap.vendor | string | `"other"` | Vendor name |
| auth.keycloak.logLevel | string | `"INFO"` | Log level for the local Keycloak instance |
| auth.keycloak.name | string | `"Yontrack"` | Name to use on the Signin page |
| auth.keycloak.persistence | object | `{"connection":{"database":"keycloak","password":"keycloak","secret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/postgres"}},"name":"keycloak-postgresql"},"username":"keycloak"},"image":{"pullPolicy":"IfNotPresent","repository":"bitnamilegacy/postgresql","tag":17},"pvc":{"accessMode":"ReadWriteOnce","annotations":{},"size":"5Gi","storageClass":null},"resources":{},"service":{"type":"ClusterIP"}}` | Persistence options for Keycloak |
| auth.keycloak.persistence.connection | object | `{"database":"keycloak","password":"keycloak","secret":{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/postgres"}},"name":"keycloak-postgresql"},"username":"keycloak"}` | Connection parameters |
| auth.keycloak.persistence.connection.database | string | `"keycloak"` | Database name |
| auth.keycloak.persistence.connection.password | string | `"keycloak"` | Password |
| auth.keycloak.persistence.connection.secret | object | `{"enabled":false,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/postgres"}},"name":"keycloak-postgresql"}` | Credentials stored in a secret |
| auth.keycloak.persistence.connection.secret.enabled | bool | `false` | Using the secret for the credentials |
| auth.keycloak.persistence.connection.secret.externalSecret | object | `{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/postgres"}}` | Using an external secret |
| auth.keycloak.persistence.connection.secret.externalSecret.enabled | bool | `false` | Creating the external secret definition |
| auth.keycloak.persistence.connection.secret.externalSecret.refreshInterval | string | `"6h"` | Refresh interval |
| auth.keycloak.persistence.connection.secret.externalSecret.store | object | `{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/postgres"}` | Location of the secret to bind to |
| auth.keycloak.persistence.connection.secret.externalSecret.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| auth.keycloak.persistence.connection.secret.externalSecret.store.name | string | `"vault-backend"` | Name of the secret store |
| auth.keycloak.persistence.connection.secret.externalSecret.store.path | string | `"ontrack/keycloak/postgres"` | The entry is expected to have the following keys: username & password |
| auth.keycloak.persistence.connection.secret.name | string | `"keycloak-postgresql"` | The secret is expected to have the following keys: username & password |
| auth.keycloak.persistence.connection.username | string | `"keycloak"` | Username |
| auth.keycloak.persistence.image | object | `{"pullPolicy":"IfNotPresent","repository":"bitnamilegacy/postgresql","tag":17}` | Image for Postgres |
| auth.keycloak.persistence.image.pullPolicy | string | `"IfNotPresent"` | Pull policy |
| auth.keycloak.persistence.image.repository | string | `"bitnamilegacy/postgresql"` | Image repository |
| auth.keycloak.persistence.image.tag | int | `17` | Image tag |
| auth.keycloak.persistence.pvc | object | `{"accessMode":"ReadWriteOnce","annotations":{},"size":"5Gi","storageClass":null}` | PVC setup |
| auth.keycloak.persistence.pvc.accessMode | string | `"ReadWriteOnce"` | PVC access mode |
| auth.keycloak.persistence.pvc.annotations | object | `{}` | Annotations for the PVC |
| auth.keycloak.persistence.pvc.size | string | `"5Gi"` | Disk size |
| auth.keycloak.persistence.pvc.storageClass | string | `nil` | If defined, storageClassName: <storageClass> If set to "-", storageClassName: "", which disables dynamic provisioning If undefined (the default) or set to null, no storageClassName spec is   set, choosing the default provisioner.  (gp2 on AWS, standard on   GKE, AWS & OpenStack) |
| auth.keycloak.persistence.resources | object | `{}` | Resources to allocate to Postgres |
| auth.keycloak.persistence.service | object | `{"type":"ClusterIP"}` | Postgres service |
| auth.keycloak.persistence.service.type | string | `"ClusterIP"` | Service type |
| auth.keycloak.realm | string | `"ontrack"` | Name of the realm to create in Keycloak to serve the Yontrack users |
| auth.keycloak.resources | object | `{}` | Resources to allocate to the local Keycloak instance |
| auth.keycloak.secret | object | `{"enabled":false,"external":{"enabled":false,"refreshInterval":"6h","store":{"key":"client-secret","kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/client"}},"generate":true,"name":"ontrack-keycloak"}` | Connection parameters to Keycloak stored in a secret |
| auth.keycloak.secret.enabled | bool | `false` | Using a secret to store the client secret |
| auth.keycloak.secret.external | object | `{"enabled":false,"refreshInterval":"6h","store":{"key":"client-secret","kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/client"}}` | External secret for the client secret |
| auth.keycloak.secret.external.enabled | bool | `false` | Creating the external secret definition |
| auth.keycloak.secret.external.refreshInterval | string | `"6h"` | Refresh interval |
| auth.keycloak.secret.external.store | object | `{"key":"client-secret","kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/keycloak/client"}` | Location of the secret to bind to |
| auth.keycloak.secret.external.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| auth.keycloak.secret.external.store.name | string | `"vault-backend"` | Name of the secret store |
| auth.keycloak.secret.external.store.path | string | `"ontrack/keycloak/client"` | Path to the secret in the store. |
| auth.keycloak.secret.generate | bool | `true` | Generating the client secret |
| auth.keycloak.secret.name | string | `"ontrack-keycloak"` | Name of the secret to use |
| auth.keycloak.service | object | `{"ingressEnabled":true,"path":"keycloak","port":8080}` | Service setup for the local Keycloak instance |
| auth.keycloak.service.ingressEnabled | bool | `true` | Enabling Keycloak in the Ingress |
| auth.keycloak.service.path | string | `"keycloak"` | Relative path for the local Keycloak instance (relatively to the Yontrack main URL) |
| auth.keycloak.service.port | int | `8080` | Port of the service for the local Keycloak instance |
| auth.keycloak.settings | object | `{"accessTokenLifespan":3600,"admin":{"email":"","enabled":true,"firstName":"Admin","lastName":"User","password":"admin","secret":{"enabled":false,"external":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/admin","usernameKey":"username"}},"name":"yontrack-admin"},"username":"admin"},"enabled":true,"groups":[],"registrationAllowed":true,"resetPasswordAllowed":true,"ssoSessionIdleTimeout":3600,"users":[]}` | Provisioning settings |
| auth.keycloak.settings.accessTokenLifespan | int | `3600` | Access Token Lifespan (in seconds) |
| auth.keycloak.settings.admin | object | `{"email":"","enabled":true,"firstName":"Admin","lastName":"User","password":"admin","secret":{"enabled":false,"external":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/admin","usernameKey":"username"}},"name":"yontrack-admin"},"username":"admin"}` | Initial Yontrack user to create |
| auth.keycloak.settings.admin.email | string | `""` | Email If not set, `auth.admin.email` is used |
| auth.keycloak.settings.admin.enabled | bool | `true` | Enabling the provisioning of the admin user |
| auth.keycloak.settings.admin.firstName | string | `"Admin"` | First name |
| auth.keycloak.settings.admin.lastName | string | `"User"` | Last name |
| auth.keycloak.settings.admin.password | string | `"admin"` | Password (would need to be changed) |
| auth.keycloak.settings.admin.secret | object | `{"enabled":false,"external":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/admin","usernameKey":"username"}},"name":"yontrack-admin"}` | Fetching the admin user from a secret |
| auth.keycloak.settings.admin.secret.enabled | bool | `false` | Using a secret to store the admin credentials (username & password keys) |
| auth.keycloak.settings.admin.secret.external | object | `{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/admin","usernameKey":"username"}}` | External secret for the admin credentials |
| auth.keycloak.settings.admin.secret.external.enabled | bool | `false` | Creating the external secret definition |
| auth.keycloak.settings.admin.secret.external.refreshInterval | string | `"6h"` | Refresh interval |
| auth.keycloak.settings.admin.secret.external.store | object | `{"kind":"ClusterSecretStore","name":"vault-backend","passwordKey":"password","path":"ontrack/keycloak/admin","usernameKey":"username"}` | Location of the secret to bind to |
| auth.keycloak.settings.admin.secret.external.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| auth.keycloak.settings.admin.secret.external.store.name | string | `"vault-backend"` | Name of the secret store |
| auth.keycloak.settings.admin.secret.external.store.path | string | `"ontrack/keycloak/admin"` | Path to the secret in the store. |
| auth.keycloak.settings.admin.secret.name | string | `"yontrack-admin"` | Name of the secret to use |
| auth.keycloak.settings.admin.username | string | `"admin"` | Username |
| auth.keycloak.settings.enabled | bool | `true` | Provisioning of Keycloak is enabled |
| auth.keycloak.settings.groups | list | `[]` | Names of the groups to create in the realm, carried in the `groups` claim. Not compatible with `auth.keycloak.ldap`. See `users` for existing installations. |
| auth.keycloak.settings.registrationAllowed | bool | `true` | Enabling users to register in the local instance of Keycloak |
| auth.keycloak.settings.resetPasswordAllowed | bool | `true` | Enabling users to reset their passwords |
| auth.keycloak.settings.ssoSessionIdleTimeout | int | `3600` | SSO idle time (in seconds) |
| auth.keycloak.settings.users | list | `[]` | Users to create in the realm, next to the `admin` user. Not compatible with `auth.keycloak.ldap`. Each user needs a `username`, an `email`, a `firstName`, a `lastName`, the `groups` it belongs to (declared in `groups`) and a `passwordSecret` (`name` & `key` of an existing secret containing its password, which must not contain `"` nor `\`). Passwords are never in the values nor in the rendered realm. On an existing installation, a post-install/post-upgrade job adds the missing groups & users to the realm: existing groups & users are left untouched (their passwords & groups are not updated). |
| auth.keycloak.tag | string | `"26.2.5"` | Version this image of Keycloak to deploy |
| auth.keycloak.verbose | bool | `false` | Starting the server in verbose mode |
| auth.kind | string | `"keycloak"` | Type of authentication |
| auth.next | object | `{"secret":{"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/next-auth"}},"generate":true,"name":"ontrack-next-auth"}}` | Unique secret used by Next Auth in Yontrack to create session cookies |
| auth.next.secret | object | `{"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/next-auth"}},"generate":true,"name":"ontrack-next-auth"}` | Secret definition |
| auth.next.secret.externalSecret | object | `{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/next-auth"}}` | Using an external secret |
| auth.next.secret.externalSecret.enabled | bool | `false` | Creating the external secret definition |
| auth.next.secret.externalSecret.refreshInterval | string | `"6h"` | Refresh interval |
| auth.next.secret.externalSecret.store | object | `{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/next-auth"}` | Location of the secret to bind to |
| auth.next.secret.externalSecret.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| auth.next.secret.externalSecret.store.name | string | `"vault-backend"` | Name of the secret store |
| auth.next.secret.externalSecret.store.path | string | `"ontrack/next-auth"` | The entry is expected to have the following keys: username & password |
| auth.next.secret.generate | bool | `true` | Generating the secret |
| auth.next.secret.name | string | `"ontrack-next-auth"` | Name of the secret The secret must have an `secret` entry |
| auth.oidc | object | `{"credentials":{"client":{"clientId":"<client id>","clientSecret":"<client secret>"},"secret":{"enabled":true,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/oidc"}},"secretName":"ontrack-oidc"}},"issuer":"","name":"OIDC","scope":"openid profile email","trailingSlash":false}` | OIDC configuration (disabled by default) |
| auth.oidc.credentials | object | `{"client":{"clientId":"<client id>","clientSecret":"<client secret>"},"secret":{"enabled":true,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/oidc"}},"secretName":"ontrack-oidc"}}` | Credentials used to contact the OIDC provider |
| auth.oidc.credentials.client | object | `{"clientId":"<client id>","clientSecret":"<client secret>"}` | ... or provided directly in the values (ok for testing) If a secret (or external secret) is provided, these values are not used |
| auth.oidc.credentials.client.clientId | string | `"<client id>"` | OIDC Client ID |
| auth.oidc.credentials.client.clientSecret | string | `"<client secret>"` | OIDC Client Secret |
| auth.oidc.credentials.secret | object | `{"enabled":true,"externalSecret":{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/oidc"}},"secretName":"ontrack-oidc"}` | Either stored in a secret (recommended) |
| auth.oidc.credentials.secret.enabled | bool | `true` | Enabling the secret |
| auth.oidc.credentials.secret.externalSecret | object | `{"enabled":false,"refreshInterval":"6h","store":{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/oidc"}}` | Depending on your setup, you can also just create an external secret definition, pointing to the actual secret in a secret provided like Vault or your cloud secret manager If not using an external secret, Yontrack expects you to create the secret manually. |
| auth.oidc.credentials.secret.externalSecret.enabled | bool | `false` | Enabling the creation of the external secret |
| auth.oidc.credentials.secret.externalSecret.refreshInterval | string | `"6h"` | Refresh interval |
| auth.oidc.credentials.secret.externalSecret.store | object | `{"kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/oidc"}` | Location of the secret to bind to |
| auth.oidc.credentials.secret.externalSecret.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| auth.oidc.credentials.secret.externalSecret.store.name | string | `"vault-backend"` | Name of the secret store |
| auth.oidc.credentials.secret.externalSecret.store.path | string | `"ontrack/oidc"` | Path to the secret in the store. The entry is expected to have the following keys: clientId & clientSecret |
| auth.oidc.credentials.secret.secretName | string | `"ontrack-oidc"` | The secret is expected to have the following keys: clientId & clientSecret |
| auth.oidc.issuer | string | `""` | OIDC issuer URL |
| auth.oidc.name | string | `"OIDC"` | Display name for your IdP (used for the login page) |
| auth.oidc.scope | string | `"openid profile email"` | OIDC scope |
| auth.oidc.trailingSlash | bool | `false` | Trailing slash for the issuer URL (used for Auth0) |
| auth.provisioning | bool | `true` | Provisioning of groups & initial administrator |
| elasticsearch.existingSecret | string | `""` | Name of an existing secret holding the password to connect to Elasticsearch |
| elasticsearch.existingSecretPasswordKey | string | `"password"` | Key of the password in the existing secret |
| elasticsearch.metrics.enabled | bool | `false` | Enabling the export of the metrics to Elasticsearch |
| elasticsearch.metrics.index | string | `"ontrack_metrics"` | Name of the Elasticsearch index for the metrics |
| elasticsearch.uris | string | `""` | URIs of the Elasticsearch cluster (comma-separated), required when the metrics export is enabled |
| elasticsearch.username | string | `""` | Username to connect to Elasticsearch |
| emptyDir | object | `{}` | In case you want to specify different resources for emptyDir than {} |
| extraContainers | list | `[]` | Array of extra containers to run alongside the Yontrack container  Example: - name: myapp-container   image: busybox   command: ['sh', '-c', 'echo Hello && sleep 3600']  |
| fullnameOverride | string | `""` | If defined, uses this name for the resource names instead of the using the chart name |
| global | object | `{"compatibility":{"openshift":{"adaptSecurityContext":"auto"}},"security":{"allowInsecureImages":true}}` | Global configuration for all sub-charts |
| global.compatibility | object | `{"openshift":{"adaptSecurityContext":"auto"}}` | Configuration for OpenShift |
| global.compatibility.openshift.adaptSecurityContext | string | `"auto"` | Whether to adapt the security context for OpenShift |
| global.security.allowInsecureImages | bool | `true` | Skips the image verification of the Bitnami sub-charts, which all deliberately point to the `bitnamilegacy/*` images. Without it, the RabbitMQ sub-chart refuses to render when it is the only Bitnami sub-chart (external Postgres). |
| image.pullPolicy | string | `"IfNotPresent"` | Pull policy |
| image.repository | string | `"yontrack/yontrack"` | Image to use for Yontrack (backend) |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | List of secrets used to pull images |
| includeVersionLabels | bool | `false` | When false (default), omits `helm.sh/chart` and `app.kubernetes.io/version` from all resource labels. Enable when you want standard Kubernetes recommended labels for observability/filtering. Keeping this false avoids noisy diffs in GitOps rendered-manifest workflows. |
| ingress.annotations | object | `{}` | Annotations for the Ingress |
| ingress.enabled | bool | `true` | Creating an Ingress for the Yontrack different services. This is required when using Keycloak. |
| ingress.host | string | `"ontrack.local"` | Host for Yontrack |
| ingress.ingressClassName | string | `""` | Ingress class name |
| ingress.tls.enabled | bool | `true` | Using TLS for Yontrack |
| ingress.tls.secretName | string | `""` | Name of the secret containing the TLS certificate If not provided, defaults to <host>-tls |
| ingress.uploads.annotations | object | `{}` | Annotations of the upload Ingress, overriding the default ones: `nginx.ingress.kubernetes.io/proxy-body-size` (auditTrail.storage.maxSize plus 1 MB) and `nginx.ingress.kubernetes.io/proxy-request-buffering: "off"` |
| ingress.uploads.enabled | bool | `true` | Rendering the evidence upload paths in a dedicated Ingress (same class, host, TLS & annotations as the main one, except the cert-manager ones). When disabled, the main Ingress serves them with its own body size limit. |
| initContainers | object | `{"image":{"repository":"busybox","tag":"1.37.0"},"resources":{"limits":{"cpu":"100m","memory":"50Mi"},"requests":{"cpu":"100m","memory":"50Mi"}}}` | General configuration of the init containers |
| initContainers.image | object | `{"repository":"busybox","tag":"1.37.0"}` | Configuration of the image used for the init containers |
| initContainers.image.repository | string | `"busybox"` | Image repository (including the registry) |
| initContainers.resources | object | `{"limits":{"cpu":"100m","memory":"50Mi"},"requests":{"cpu":"100m","memory":"50Mi"}}` | Resources for the init containers of Yontrack |
| initContainers.resources.limits.cpu | string | `"100m"` | CPU limits for the init containers |
| initContainers.resources.limits.memory | string | `"50Mi"` | Memory limits for the init containers |
| initContainers.resources.requests.cpu | string | `"100m"` | CPU request for the init containers |
| initContainers.resources.requests.memory | string | `"50Mi"` | Memory request for the init containers |
| keycloak-postgresql | object | `{"auth":{"database":"keycloak","password":"keycloak","username":"keycloak"},"image":{"repository":"bitnamilegacy/postgresql"}}` | Local database |
| keycloak-postgresql.auth | object | `{"database":"keycloak","password":"keycloak","username":"keycloak"}` | Authentication parameters |
| keycloak-postgresql.auth.database | string | `"keycloak"` | Name of the database to create |
| keycloak-postgresql.auth.password | string | `"keycloak"` | Credentials to be used |
| keycloak-postgresql.auth.username | string | `"keycloak"` | Credentials to be used |
| keycloak-postgresql.image.repository | string | `"bitnamilegacy/postgresql"` | See the announcement at https://hub.docker.com/r/bitnami/rabbitmq |
| management.service.annotations | object | `{}` | Annotations for the management service. Only used when specific == true |
| management.service.port | int | `8800` | Exposed port for the Yontrack management service. Must be different from `service.port`. |
| management.service.specific | bool | `false` | Set to true to have the management port exposed by another Service. By default, using the same service and two different named ports. Required to use a `service.type` other than ClusterIP, since the management port must never be exposed outside the cluster. |
| management.service.type | string | `"ClusterIP"` | Service type for the management. Only used when specific == true. Must be ClusterIP: the management port must never be exposed outside the cluster. |
| nameOverride | string | `""` | Name to use instead of the chart name |
| nodeSelector | object | `{}` | Node selectors for the Yontrack resources |
| ontrack.application_yaml | string | `""` | Application configuration file as a YAML content |
| ontrack.casc | object | `{"directory":"/var/ontrack/casc","enabled":true,"externalSecrets":{"enabled":false,"refreshInterval":"6h","secretKeys":[],"secretName":"ontrack-casc-secrets","store":{"kind":"ClusterSecretStore","name":"vault-backend"}},"map":"","mapValues":{"mapEntryName":"casc.yaml"},"reloading":{"cron":"","enabled":false},"secret":"","secrets":{"directory":"/var/ontrack/casc/mapping","mapping":"env","names":[]},"upload":{"enabled":false}}` | CasC configuration |
| ontrack.casc.directory | string | `"/var/ontrack/casc"` | Path where to mount the Casc files |
| ontrack.casc.enabled | bool | `true` | Is Casc enabled? |
| ontrack.casc.externalSecrets | object | `{"enabled":false,"refreshInterval":"6h","secretKeys":[],"secretName":"ontrack-casc-secrets","store":{"kind":"ClusterSecretStore","name":"vault-backend"}}` | List of external secrets to declare |
| ontrack.casc.externalSecrets.enabled | bool | `false` | Enabling the creation of the external secret |
| ontrack.casc.externalSecrets.refreshInterval | string | `"6h"` | Refresh interval |
| ontrack.casc.externalSecrets.secretKeys | list | `[]` | List of secret keys to create |
| ontrack.casc.externalSecrets.secretName | string | `"ontrack-casc-secrets"` | Name of the secret to create |
| ontrack.casc.externalSecrets.store | object | `{"kind":"ClusterSecretStore","name":"vault-backend"}` | Location of the secret to bind to |
| ontrack.casc.externalSecrets.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| ontrack.casc.externalSecrets.store.name | string | `"vault-backend"` | Name of the secret store |
| ontrack.casc.map | string | `""` | Config map containing all Casc files |
| ontrack.casc.mapValues | object | `{"mapEntryName":"casc.yaml"}` | Casc from values |
| ontrack.casc.mapValues.mapEntryName | string | `"casc.yaml"` | Name of the entry to hold the values |
| ontrack.casc.reloading | object | `{"cron":"","enabled":false}` | Auto reload configuration |
| ontrack.casc.reloading.cron | string | `""` | Auto reload cron schedule Leave empty to be a manual job only |
| ontrack.casc.reloading.enabled | bool | `false` | Auto reload activation |
| ontrack.casc.secret | string | `""` | Secret map containing all secret Casc files |
| ontrack.casc.secrets | object | `{"directory":"/var/ontrack/casc/mapping","mapping":"env","names":[]}` | Mapping of secrets |
| ontrack.casc.secrets.directory | string | `"/var/ontrack/casc/mapping"` | Directory where to map the secrets (for mapping = env) |
| ontrack.casc.secrets.mapping | string | `"env"` | Secret mapping mode |
| ontrack.casc.secrets.names | list | `[]` | List of secret names to mount |
| ontrack.casc.upload | object | `{"enabled":false}` | Uploading the Casc |
| ontrack.casc.upload.enabled | bool | `false` | Casc upload activation |
| ontrack.config.key_store | string | `"jdbc"` | Using the database to store the key by default |
| ontrack.config.license.key | string | `"eyJkYXRhIjoiZXlKdVlXMWxJam9pVXlJc0ltRnpjMmxuYm1WbElqb2lVSFZpYkdsaklpd2lkbUZzYVdSVmJuUnBiQ0k2SWpJd01qVXRNVEl0TXpFaUxDSnRZWGhRY205cVpXTjBjeUk2TVRBc0ltWmxZWFIxY21WeklqcGJleUpwWkNJNkltVjRkR1Z1YzJsdmJpNWxiblpwY205dWJXVnVkSE1pTENKbGJtRmliR1ZrSWpwbVlXeHpaU3dpWkdGMFlTSTZXM3NpYm1GdFpTSTZJbTFoZUVWdWRtbHliMjV0Wlc1MGN5SXNJblpoYkhWbElqb2lNQ0o5WFgxZExDSnRaWE56WVdkbElqb2lXVzkxSUdGeVpTQjFjMmx1WnlCaGJpQmxkbUZzZFdGMGFXOXVJR3hwWTJWdWMyVXVJbjA9Iiwic2lnbmF0dXJlIjoiTUVVQ0lFMWNjQWQxT25ZQXl2M3B4c3ZaQWc0eDE1Q3dmY3FjMFNNRm12ZUU5TVRDQWlFQTJJZHVsZEtxek5DU2Q2VHJNNGxsczhzVGlHWXQ3Nmw5bFRZQ3pFdDBKMjQ9In0="` | Provided license key An evaluation key is provided by default (valid until 2025-12-31, up to 10 projects, no extra features) |
| ontrack.config.secret_key_store.directory | string | `"/var/ontrack/key_store"` | Directory to use inside the container |
| ontrack.config.secret_key_store.external | object | `{"enabled":false,"refreshInterval":"6h","store":{"key":"key","kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/encryption"}}` | Using an external secret |
| ontrack.config.secret_key_store.external.enabled | bool | `false` | Activate the creation of the External secret |
| ontrack.config.secret_key_store.external.refreshInterval | string | `"6h"` | Refresh interval |
| ontrack.config.secret_key_store.external.store | object | `{"key":"key","kind":"ClusterSecretStore","name":"vault-backend","path":"ontrack/encryption"}` | Location of the secret to bind to |
| ontrack.config.secret_key_store.external.store.key | string | `"key"` | Name of the key in the external secret |
| ontrack.config.secret_key_store.external.store.kind | string | `"ClusterSecretStore"` | Scope of the secret store |
| ontrack.config.secret_key_store.external.store.name | string | `"vault-backend"` | Name of the secret store |
| ontrack.config.secret_key_store.external.store.path | string | `"ontrack/encryption"` | Path to the secret in the store. |
| ontrack.config.secret_key_store.secret_name | string | `"ontrack-key-store"` | Name of the secret |
| ontrack.env | list | `[]` | Arbitrary environment variables, using https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.35/#envvar-v1-core |
| ontrack.envMap | object | `{}` | Arbitrary environment variables (as a map) |
| ontrack.extraConfig.configmaps | list | `[]` | Arbitrary config map sources |
| ontrack.extraConfig.secrets | list | `[]` | Arbitrary secrets map sources |
| ontrack.management.metrics.tags.application | string | `"ontrack"` | Application tag to add to all exposed metrics |
| ontrack.persistence.accessMode | string | `"ReadWriteOnce"` | PVC access mode |
| ontrack.persistence.annotations | object | `{}` | Set annotations on pvc |
| ontrack.persistence.enabled | bool | `true` | Enabling the persistent storage |
| ontrack.persistence.size | string | `"5Gi"` | PVC initial size |
| ontrack.persistence.storageClass | string | `nil` | If defined, storageClassName: <storageClass> If set to "-", storageClassName: "", which disables dynamic provisioning If undefined (the default) or set to null, no storageClassName spec is   set, choosing the default provisioner.  (gp2 on AWS, standard on   GKE, AWS & OpenStack) |
| ontrack.podAnnotations | object | `{}` | Annotations for the Yontrack pod |
| ontrack.probes | object | `{"liveness":{"failureThreshold":3,"initialDelaySeconds":60,"periodSeconds":60,"timeoutSeconds":5},"readiness":{"failureThreshold":3,"initialDelaySeconds":60,"periodSeconds":60,"timeoutSeconds":5},"startup":{"failureThreshold":36,"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":5}}` | Probes configuration |
| ontrack.probes.liveness | object | `{"failureThreshold":3,"initialDelaySeconds":60,"periodSeconds":60,"timeoutSeconds":5}` | Liveness probe configuration |
| ontrack.probes.liveness.failureThreshold | int | `3` | Failure threshold of the liveness probe |
| ontrack.probes.liveness.initialDelaySeconds | int | `60` | Initial delay of the liveness probe |
| ontrack.probes.liveness.periodSeconds | int | `60` | Liveness probe interval |
| ontrack.probes.liveness.timeoutSeconds | int | `5` | Timeout of each liveness probe |
| ontrack.probes.readiness | object | `{"failureThreshold":3,"initialDelaySeconds":60,"periodSeconds":60,"timeoutSeconds":5}` | Readiness probe configuration |
| ontrack.probes.readiness.failureThreshold | int | `3` | Failure threshold of the readiness probe |
| ontrack.probes.readiness.initialDelaySeconds | int | `60` | Initial delay of the readiness probe |
| ontrack.probes.readiness.periodSeconds | int | `60` | Readiness probe interval |
| ontrack.probes.readiness.timeoutSeconds | int | `5` | Timeout of each readiness probe |
| ontrack.probes.startup | object | `{"failureThreshold":36,"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":5}` | Startup probe configuration. The startup budget is `initialDelaySeconds` + `failureThreshold` × `periodSeconds` (390 s by default): the first start runs all the database migrations. |
| ontrack.probes.startup.failureThreshold | int | `36` | Failure threshold at startup |
| ontrack.probes.startup.initialDelaySeconds | int | `30` | Initial delay at startup |
| ontrack.probes.startup.periodSeconds | int | `10` | Probe interval at startup |
| ontrack.probes.startup.timeoutSeconds | int | `5` | Timeout of each startup probe |
| ontrack.profiles | string | `"prod"` | Comma-separated list of active Spring profiles |
| ontrack.resources.limits.cpu | string | `"800m"` | Yontrack resources |
| ontrack.resources.limits.memory | string | `"2Gi"` | Yontrack resources |
| ontrack.resources.requests.cpu | string | `"800m"` | Yontrack resources |
| ontrack.ui.config | object | `{"customSignin":true}` | UI configuration |
| ontrack.ui.config.customSignin | bool | `true` | Using the custom signin page |
| ontrack.ui.image | string | `"yontrack/yontrack-ui"` | Image to use for the UI |
| ontrack.ui.podAnnotations | object | `{}` | Annotations for the Yontrack UI pod |
| ontrack.ui.replicas | int | `1` | Number of replicas for the UI (experimental) |
| ontrack.ui.resources | object | `{"limits":{"cpu":"800m","memory":"1Gi"},"requests":{"cpu":"800m","memory":"1Gi"}}` | Next UI resources |
| ontrack.ui.resources.limits.cpu | string | `"800m"` | Next UI resources |
| ontrack.ui.resources.limits.memory | string | `"1Gi"` | Next UI resources |
| ontrack.ui.resources.requests.cpu | string | `"800m"` | Next UI resources |
| ontrack.ui.resources.requests.memory | string | `"1Gi"` | Next UI resources |
| ontrack.ui.service.port | int | `3000` | Exposed port for the Yontrack IO |
| ontrack.url | string | `"http://localhost:3000"` | Yontrack root URL - must point to the UI service |
| openshift | object | `{"enabled":false}` | Configuration for OpenShift |
| openshift.enabled | bool | `false` | Whether to enable OpenShift specific resources (like Routes) |
| podAnnotations | object | `{}` | Annotations for all pods |
| podSecurityContext | object | `{}` | Security context for all pods |
| postgresql | object | `{"auth":{"database":"ontrack","password":"ontrack","username":"ontrack"},"image":{"repository":"bitnamilegacy/postgresql"},"local":true,"postgresFromEnv":false,"postgresqlUrl":""}` | Local database |
| postgresql.auth | object | `{"database":"ontrack","password":"ontrack","username":"ontrack"}` | Authentication parameters |
| postgresql.auth.database | string | `"ontrack"` | Name of the database to create |
| postgresql.auth.password | string | `"ontrack"` | Credentials to be used |
| postgresql.auth.username | string | `"ontrack"` | Credentials to be used |
| postgresql.image.repository | string | `"bitnamilegacy/postgresql"` | See the announcement at https://hub.docker.com/r/bitnami/rabbitmq |
| postgresql.local | bool | `true` | Enabling the local database |
| postgresql.postgresFromEnv | bool | `false` | For external database, using environment variables |
| postgresql.postgresqlUrl | string | `""` | For external database |
| rabbitmq | object | `{"auth":{"erlangCookie":"ontrack","password":"ontrack","username":"ontrack"},"image":{"repository":"bitnamilegacy/rabbitmq"}}` | Local RabbitMQ for message processing |
| replicaCount | int | `1` |  |
| securityContext | object | `{}` | Security context for the containers |
| service.annotations | object | `{}` | Annotations for the Yontrack service |
| service.port | int | `8080` | Exposed port for the Yontrack service |
| service.type | string | `"ClusterIP"` | Service type for the Yontrack service. Must be ClusterIP unless `management.service.specific` is true, since the management port must never be exposed outside the cluster. |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` | Node tolerations for the Yontrack resources |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
