// Hand-rolled FCM HTTP v1 OAuth2 JWT-bearer flow (Web Crypto, RS256)
// against a service-account JSON (FCM_SERVICE_ACCOUNT_JSON secret) --
// avoids pulling in a client library of uncertain esm.sh compatibility
// for the one call this needs. Mirrors smile_0_1's _shared/fcm.ts.

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedServiceAccount: ServiceAccount | null = null;

function getServiceAccount(): ServiceAccount {
  if (cachedServiceAccount) return cachedServiceAccount;
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT_JSON is not set for this Edge Function.");
  cachedServiceAccount = JSON.parse(raw) as ServiceAccount;
  return cachedServiceAccount;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

function base64Url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.token;
  }
  const sa = getServiceAccount();
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claims))}`;
  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${base64Url(new Uint8Array(signature))}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!tokenResponse.ok) {
    throw new Error(`FCM OAuth token request failed: ${await tokenResponse.text()}`);
  }
  const tokenJson = await tokenResponse.json();
  cachedAccessToken = {
    token: tokenJson.access_token,
    expiresAt: Date.now() + tokenJson.expires_in * 1000,
  };
  return cachedAccessToken.token;
}

/** Data-only push -- no notification payload, the app decides what to do. */
export async function sendDataMessage(fcmToken: string, data: Record<string, string>): Promise<void> {
  const sa = getServiceAccount();
  const accessToken = await getAccessToken();
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        data,
        android: { priority: "high" },
      },
    }),
  });
  if (!response.ok) {
    throw new Error(`FCM send failed: ${await response.text()}`);
  }
}

/**
 * Human-visible push (smile-app), unlike sendDataMessage above --
 * Android/iOS show this in the system tray automatically whenever the app
 * isn't in the foreground, no local-notification plumbing needed on the
 * client for that case. Throws with a message containing the FCM error
 * code (e.g. "UNREGISTERED") on failure, so callers can prune a dead token.
 */
export async function sendNotification(
  fcmToken: string,
  notification: { title: string; body: string },
  data?: Record<string, string>,
): Promise<void> {
  const sa = getServiceAccount();
  const accessToken = await getAccessToken();
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification,
        data: data ?? {},
        android: { priority: "high" },
      },
    }),
  });
  if (!response.ok) {
    throw new Error(`FCM send failed: ${await response.text()}`);
  }
}
