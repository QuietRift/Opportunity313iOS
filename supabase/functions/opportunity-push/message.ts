export function pushMessage(opportunityID: string, eventID: string) {
  return { message: {
    topic: "published_opportunities",
    notification: { title: "New Opportunity313 opportunity", body: "A new opportunity is available. Tap to view details." },
    data: { opportunity_id: opportunityID, event_id: eventID },
    android: { ttl: "3600s", notification: { channel_id: "new_opportunities", tag: opportunityID } },
    apns: { headers: { "apns-push-type": "alert", "apns-priority": "10", "apns-collapse-id": opportunityID, "apns-expiration": String(Math.floor(Date.now() / 1000) + 3600) }, payload: { aps: { sound: "default" } } },
  } };
}

export async function firebaseAccessToken(account: { client_email: string; private_key: string }) {
  const encode = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const json = (value: unknown) => encode(new TextEncoder().encode(JSON.stringify(value)));
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${json({ alg: "RS256", typ: "JWT" })}.${json({ iss: account.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 })}`;
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), c => c.charCodeAt(0)), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));
  const response = await fetch("https://oauth2.googleapis.com/token", { method: "POST", signal: AbortSignal.timeout(15000), headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${encode(signature)}` }) });
  const body = await response.json();
  if (!response.ok || typeof body.access_token !== "string") throw new Error("sender_auth_failed");
  return body.access_token;
}
