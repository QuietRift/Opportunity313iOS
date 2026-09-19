import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const normalize = (value: string) => value.trim().toUpperCase().replace(/\s+/g, "");
const digest = async (value: string) => {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
};
const randomCode = () => {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  const raw = [...bytes].map((byte) => alphabet[byte % alphabet.length]).join("");
  return `O313-${raw.slice(0, 4)}-${raw.slice(4, 8)}-${raw.slice(8)}`;
};
const maximumAge = (ageBand: string) => {
  const parts = ageBand.replaceAll("-", "–").split("–").map((part) => Number(part.trim()));
  return parts.length === 2 && parts.every(Number.isFinite) ? parts[1] : null;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publishableKey || !serviceKey) return json({ error: "Service unavailable" }, 503);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  try {
    const body = await request.json();
    const action = body.action;
    if (!["redeem", "generate", "revoke"].includes(action)) return json({ error: "Unknown action." }, 400);

    if (action === "redeem") {
      const code = normalize(String(body.code ?? ""));
      if (!/^O313-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(code)) {
        return json({ error: "Enter a valid Opportunity313 access code." }, 400);
      }

      const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
      const fingerprint = await digest(forwarded + "|" + (request.headers.get("user-agent") ?? "unknown"));
      const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
      const { count } = await admin.from("child_access_attempts")
        .select("id", { count: "exact", head: true })
        .eq("client_fingerprint", fingerprint)
        .gte("attempted_at", since);
      if ((count ?? 0) >= 10) return json({ error: "Too many attempts. Try again later." }, 429);

      const codeHash = await digest(code);
      const { data: credential } = await admin.from("child_access_credentials")
        .select("youth_profile_id,auth_user_id,expires_at,revoked_at")
        .eq("code_hash", codeHash)
        .maybeSingle();

      const valid = credential && !credential.revoked_at && new Date(credential.expires_at) > new Date();
      await admin.from("child_access_attempts").insert({ client_fingerprint: fingerprint, succeeded: Boolean(valid) });
      if (!valid) return json({ error: "That access code is invalid or expired." }, 401);

      return json({
        email: `child-${credential.youth_profile_id}@access.opportunity313.invalid`,
        password: code,
      });
    }

    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return json({ error: "Authentication required." }, 401);
    const token = authorization.slice(7);
    const authClient = createClient(url, publishableKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await authClient.auth.getUser(token);
    if (userError || !userData.user) return json({ error: "Authentication required." }, 401);
    const parentID = userData.user.id;
    const profileID = String(body.youthProfileId ?? "");

    const { data: relationship } = await admin.from("guardian_relationships")
      .select("id")
      .eq("guardian_user_id", parentID)
      .eq("youth_profile_id", profileID)
      .eq("status", "active")
      .maybeSingle();
    if (!relationship) return json({ error: "You do not manage this child profile." }, 403);

    const { data: profile } = await admin.from("youth_profiles")
      .select("id,age_band,user_id,account_type")
      .eq("id", profileID)
      .single();
    if (!profile || maximumAge(profile.age_band) === null || maximumAge(profile.age_band)! >= 18) {
      return json({ error: "Child access is only available for profiles under 18." }, 400);
    }

    if (action === "generate" && profile.account_type !== "parent_managed") {
      return json({ error: "Access codes are only available for parent-managed profiles." }, 400);
    }

    const { data: existing, error: credentialError } = await admin.from("child_access_credentials")
      .select("auth_user_id")
      .eq("youth_profile_id", profileID)
      .maybeSingle();

    if (credentialError) throw credentialError;

    if (action === "revoke") {
      const authUserID = profile.user_id ?? existing?.auth_user_id;
      if (authUserID === parentID) return json({ error: "Cannot revoke your own account here." }, 400);
      if (authUserID) {
        // Suspend sign-in without deleting email identities or their ticket history.
        const { error } = await admin.auth.admin.updateUserById(authUserID, { ban_duration: "876000h" });
        if (error) throw error;
      }
      await admin.from("child_access_credentials").delete().eq("youth_profile_id", profileID).throwOnError();
      if (authUserID) {
        await admin.from("user_roles").delete().eq("user_id", authUserID).eq("role", "youth").throwOnError();
      }
      // Unlink ownership so existing JWTs no longer grant access to this profile.
      // Keep guardian links, saves, and the profile ID; new codes can restore access.
      await admin.from("youth_profiles").update({ user_id: null, account_type: "parent_managed" })
        .eq("id", profileID).select("id").single().throwOnError();
      if (authUserID && profile.account_type === "parent_managed") {
        const { error } = await admin.auth.admin.deleteUser(authUserID);
        if (error) throw error;
      }
      return json({ revoked: true });
    }

    if (action !== "generate") return json({ error: "Unknown action." }, 400);

    const accessCode = randomCode();
    const email = `child-${profileID}@access.opportunity313.invalid`;
    let authUserID = existing?.auth_user_id ?? profile.user_id;

    if (authUserID) {
      const { error } = await admin.auth.admin.updateUserById(authUserID, {
        email, password: accessCode, email_confirm: true,
        app_metadata: { account_kind: "parent_managed_child" },
      });
      if (error) throw error;
    } else {
      const { data, error } = await admin.auth.admin.createUser({
        email, password: accessCode, email_confirm: true,
        app_metadata: { account_kind: "parent_managed_child" },
      });
      if (error) throw error;
      authUserID = data.user.id;
    }

    await admin.from("youth_profiles").update({ user_id: authUserID }).eq("id", profileID);
    await admin.from("user_roles").upsert({ user_id: authUserID, role: "youth", assigned_by: parentID });
    await admin.from("child_access_credentials").upsert({
      youth_profile_id: profileID,
      auth_user_id: authUserID,
      code_hash: await digest(accessCode),
      code_hint: accessCode.slice(-4),
      expires_at: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000).toISOString(),
      revoked_at: null,
      created_by: parentID,
      updated_at: new Date().toISOString(),
    });

    return json({ code: accessCode, expiresAt: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000).toISOString() });
  } catch (error) {
    console.error(error);
    return json({ error: "Unable to manage child access right now." }, 500);
  }
});
