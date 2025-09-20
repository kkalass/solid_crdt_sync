# **Security Considerations**

This document outlines important security practices related to Solid OIDC authentication, particularly concerning the configuration of redirect_uri values in the client-config.json file.

**Important:** These security considerations apply to **any client-side application** using Solid OIDC authentication, not just applications built with pacors. The vulnerabilities described here are inherent to OAuth 2.0/OIDC flows when using insecure redirect URI patterns, regardless of the application framework.

## **Understanding Solid OIDC Client Configuration**

In Solid OIDC, the `client_id` is a URL pointing to a publicly accessible JSON document that the application developer controls (e.g., `https://myapp.com/client-config.json`). This document contains critical security configuration, including:

```json
{
  "client_id": "https://myapp.com/client-config.json",
  "client_name": "My Application",
  "redirect_uris": [
    "https://myapp.com/callback",
    "com.myapp://auth"
  ],
  "grant_types": ["authorization_code"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
```

The `redirect_uris` array is the **allowlist** of URIs that the Solid Pod will accept as valid redirect destinations during authentication. When a client initiates authentication, it must specify a `redirect_uri` that exactly matches one of the URIs in this pre-registered list.

## **The Role of the redirect_uri**

The redirect_uri is a critical security mechanism in OAuth 2.0 and OIDC. After a user authenticates, the authorization server redirects the user's browser back to this URI with a temporary authorization code. The client application must be listening at this URI to receive the code and exchange it for an access token.

It is **essential** that only the legitimate application can receive this redirect. Allowing an attacker to intercept the authorization code can lead to credential theft.

## **Why Loopback Redirects (localhost) are a Security Risk**

Using a generic loopback or localhost redirect URI (e.g., http://localhost:8080) is **strongly discouraged** for most applications. This practice opens up two significant attack vectors:

### **1. Authorization Code Interception**

A malicious application installed on the same machine can bind to the same port your application uses. If the user authenticates for your application, the redirect containing the authorization code could be sent to the malicious app instead of yours.

**PKCE Protection:** Solid OIDC implementations use PKCE (Proof Key for Code Exchange), which significantly mitigates this attack. Even if an attacker intercepts the authorization code, they cannot exchange it for tokens without the original code verifier that only the legitimate client possesses. However, this protection assumes the attacker cannot also intercept the initial authorization request containing the code challenge.

### **2. Client Impersonation (More Severe)**

This attack allows a malicious application to obtain tokens by impersonating your application.

1. **Initiation**: A malicious app initiates the login flow using your app's public client_id. It specifies a redirect_uri pointing to a loopback server that it controls (e.g., http://127.0.0.1:12345).  
2. **User Consent**: The user is directed to the Solid server and sees the consent screen showing your legitimate application's name. The user, believing the request is genuine, approves it.  
3. **Code Theft**: The authorization server, if configured to allow loopback redirects for your client, sends the authorization code to the attacker's server.  
4. **Token Exchange**: The attacker, having initiated the flow with their own PKCE challenge, can now successfully exchange the stolen code for an access token, gaining access to the user's data as your application.

**PKCE does not prevent this attack.** PKCE protects a legitimate code from being stolen in transit; it does not prevent an attacker from initiating their own flow to get their own code by impersonating your client.

**Why Custom URI Schemes and Domain Redirects Prevent This Attack:**

- **Custom URI Schemes (iOS/Android/macOS)**: The operating system enforces that only the application that registered a custom scheme (e.g., `com.myapp://auth`) can receive redirects to that scheme. A malicious app cannot register the same scheme or intercept redirects intended for another app's scheme.

- **HTTPS Domain Redirects (Web)**: The browser's same-origin policy ensures that only the web application served from the registered domain can receive the redirect. A malicious application cannot intercept redirects sent to `https://myapp.com/callback` unless it has compromised that specific domain, but then it controls the client profile json document anyways.

- **Localhost Vulnerability**: Any application on the local machine can potentially bind to any available port. There's no system-level protection preventing a malicious app from listening on `http://127.0.0.1:8080` if your legitimate app isn't currently running or using that port.

## **Platform-Specific Recommendations**

The choice of redirect_uri should be based on the most secure mechanism available for the target platform.

| Platform | Recommended redirect_uri Type | Security Notes |
| :---- | :---- | :---- |
| **iOS / Android** | **Custom URI Scheme** (e.g., com.myapp://auth) | **Highest Security.** The mobile OS guarantees that only your application can register and handle its specific URI scheme, providing robust protection against interception and impersonation. This is the **required** method for mobile. |
| **macOS** | **Custom URI Scheme** (e.g., com.myapp://auth) | **Highest Security.** Like iOS, macOS provides robust URI scheme registration that prevents hijacking. Apps must declare their custom schemes in Info.plist, and the system ensures only the registered app can handle that scheme. This is the **preferred** method for macOS apps. |
| **Web Application** | **HTTPS URL** (e.g., https://myapp.com/callback) | **High Security.** The browser's same-origin policy ensures that only your web application can read the response from the redirect. The URI must be specific and pre-registered. |
| **Desktop (Windows, Linux)** | **Loopback IP with Dynamic Port** (e.g., http://127.0.0.1:\[port\]) | **Accepted Standard (with caveats).** Unlike macOS and mobile platforms, Windows and Linux do not have universally robust systems for preventing custom URI scheme hijacking. The IETF best practice ([RFC 8252](https://www.rfc-editor.org/rfc/rfc8252.html)) is to use the loopback IP address (127.0.0.1 is preferred over localhost). For each auth flow, the app should dynamically bind to a random, high-numbered port and use that exact URI in the request. While this still carries the risk of client impersonation if the user is tricked, it is the current industry standard for these desktop platforms where more secure alternatives are not available. |

### **Conclusion for this Library**

The pacors framework helps developers avoid common OAuth security pitfalls by providing clear guidance on secure redirect URI patterns. The recommendations below apply to any application using Solid OIDC authentication:

For any application built with this library, especially those targeting Flutter:

* **Critical Understanding**: The client-config.json applies to ALL platforms using the same client ID. Including localhost redirects compromises security for mobile and web applications.

* **Recommended Approach**:
  - **Mobile apps (iOS/Android)**: Use custom URI schemes (e.g., `com.myapp://auth`)
  - **macOS apps**: Use custom URI schemes (e.g., `com.myapp://auth`)
  - **Desktop users (Windows/Linux)**: Direct them to use your web application instead of providing native desktop apps

* **Avoid Native Windows/Linux Apps**: Rather than compromising security with localhost redirects, provide a web application for Windows/Linux users. This maintains security while ensuring broad platform coverage.
