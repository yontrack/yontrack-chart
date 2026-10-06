# Entra authentication

<!-- TOC -->
* [Application Registration in Entra](#application-registration-in-entra)
* [Yontrack Configuration](#yontrack-configuration)
* [Sign-out](#sign-out)
<!-- TOC -->

## Application Registration in Entra

Register OIDC application in Entra:
* Use client secret (value to be provided in k8s secret for Yontrack) 
* Redirect URI: `<yontrack-root-url>/api/auth/callback/oidc`
* Redirect URI for the sign-out: `<yontrack-root-url>/api/auth/signout-complete` (see [Sign-out](#sign-out))
* Set version 2 for the access token in the manifest:
```json
{
  "accessTokenAcceptedVersion": 2
}
```
* Add optional claims to the access token:
```json
{
  "optionalClaims": {
    "idToken": [],
    "accessToken": [
      {
        "name": "email",
        "source": null,
        "essential": false,
        "additionalProperties": []
      },
      {
        "name": "preferred_username",
        "source": null,
        "essential": false,
        "additionalProperties": []
      }
    ],
    "saml2Token": []
  }
}
```
* Define required app roles, e.g. Admin and Viewer :
```json
{
  "appRoles": [
    {
      "allowedMemberTypes": [
        "User"
      ],
      "description": "Admin",
      "displayName": "Admin",
      "isEnabled": true,
      "origin": "Application",
      "value": "Admin"
    },
    {
      "allowedMemberTypes": [
        "User"
      ],
      "description": "Viewer",
      "displayName": "Viewer",
      "isEnabled": true,
      "origin": "Application",
      "value": "Viewer"
    }
  ]
}
```

## Yontrack Configuration

Assuming the application is registered in Entra directory (tenant) ID `3218d323-8bde-4bf1-b1c9-b157fa174c11` 
with application ID `61b85f3c-7b10-4b12-8e0d-1bb3feec1707`:

```yaml
auth:
  kind: oidc
  oidc:
    # Arbitrary name that will be displayed on the login page
    name: Microsoft 
    issuer: https://login.microsoftonline.com/3218d323-8bde-4bf1-b1c9-b157fa174c11/v2.0
    credentials:
      secret:
        # Secret containing following keys:
        #  clientId: 61b85f3c-7b10-4b12-8e0d-1bb3feec1707
        #  clientSecret: myrandomsecret
        secretName: oidc-secret
    scope: openid profile email 61b85f3c-7b10-4b12-8e0d-1bb3feec1707/.default offline_access
  jwt:
    # Application ID URI as displayed in Entra
    audience: api://61b85f3c-7b10-4b12-8e0d-1bb3feec1707

ontrack:
  env:
    - name: ONTRACK_CONFIG_SECURITY_AUTHORIZATION_JWT_CLAIMS_GROUPS
      value: roles
```

Configure group mapping the usual way, IDP groups will be available exactly as defined in the Entra application. 

## Sign-out

By default (`auth.oidc.federatedSignOut: true`), signing out of Yontrack also signs the browser out of Entra,
and therefore out of the other Microsoft applications (Outlook, Teams, ...) using the same session.
Entra only accepts a post-logout redirect URI registered as a redirect URI of the application:
`<yontrack-root-url>/api/auth/signout-complete`.

To sign users out of Yontrack only, keeping their Entra session:

```yaml
auth:
  oidc:
    federatedSignOut: false
```
