import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });
Deno.serve(async request => {
  if (request.method === "OPTIONS") return new Response(null, { headers: cors });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const token = request.headers.get("Authorization")?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return json({ error: "Sign in to delete your account." }, 401);
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "Account deletion is temporarily unavailable." }, 503);
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  try {
    const { data: { user }, error } = await admin.auth.getUser(token);
    if (error || !user) return json({ error: "Sign in again to delete your account." }, 401);
    const body = await request.json().catch(() => ({}));
    if (body.confirmation !== "DELETE") return json({ error: "Confirm permanent deletion first." }, 400);
    // The target is always the verified session owner, never a supplied user ID.
    const apple = user.identities?.find(identity => identity.provider === "apple");
    if (apple) {
      const clientID = Deno.env.get("APPLE_CLIENT_ID"), clientSecret = Deno.env.get("APPLE_CLIENT_SECRET");
      if (!clientID || !clientSecret) return json({ error: "Apple account deletion is awaiting Apple sign-in setup. Please try again after setup is complete." }, 503);
      if (typeof body.appleAuthorizationCode !== "string" || !body.appleAuthorizationCode) return json({ error: "Confirm with Apple before deleting your account." }, 400);
      const exchange = await fetch("https://appleid.apple.com/auth/token", { method: "POST", signal: AbortSignal.timeout(15000), body: new URLSearchParams({ client_id: clientID, client_secret: clientSecret, code: body.appleAuthorizationCode, grant_type: "authorization_code" }) });
      const tokens = await exchange.json();
      if (!exchange.ok || !tokens.refresh_token || typeof tokens.id_token !== "string") throw new Error("apple_exchange_failed");
      // This token was obtained directly from Apple's TLS endpoint using our secret.
      const claims = JSON.parse(atob(tokens.id_token.split(".")[1].replace(/-/g,"+").replace(/_/g,"/")));
      if (claims.sub !== apple.identity_data?.sub || claims.aud !== clientID) return json({ error: "Use the Apple account linked to this profile." }, 403);
      const revoked = await fetch("https://appleid.apple.com/auth/revoke", { method: "POST", signal: AbortSignal.timeout(15000), body: new URLSearchParams({ client_id: clientID, client_secret: clientSecret, token: tokens.refresh_token, token_type_hint: "refresh_token" }) });
      if (!revoked.ok) throw new Error("apple_revocation_failed");
    }
    const { data: objects, error: objectsError } = await admin.rpc("account_storage_objects", { target_user: user.id });
    if (objectsError) throw objectsError;
    for (const bucket of new Set<string>((objects ?? []).map((object: { bucket_id: string }) => object.bucket_id))) {
      const names = objects.filter((object: { bucket_id: string }) => object.bucket_id === bucket).map((object: { name: string }) => object.name);
      for (let offset = 0; offset < names.length; offset += 100) {
        const { error } = await admin.storage.from(bucket).remove(names.slice(offset, offset + 100));
        if (error) throw error;
      }
    }
    // Hard deletion cascades sessions/identities and invokes atomic app-data cleanup.
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id, false);
    if (deleteError) throw deleteError;
    return json({ deleted: true });
  } catch {
    console.error("Account deletion failed; no success was reported.");
    return json({ error: "We couldn’t finish deleting your account. Please try again." }, 503);
  }
});
