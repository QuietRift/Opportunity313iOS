import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { pushMessage, firebaseAccessToken } from "./message.ts";

const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json" } });
const sameSecret = async (a: string, b: string) => {
  const hash = async (s: string) => new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
  const [left, right] = await Promise.all([hash(a), hash(b)]);
  let difference = 0; for (let i = 0; i < left.length; i++) difference |= left[i] ^ right[i];
  return difference === 0;
};
Deno.serve(async request => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "Service unavailable" }, 503);
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  try {
    const supplied = request.headers.get("x-push-worker-secret");
    if (!supplied) return json({ error: "Authentication required" }, 401);
    const { data: secret, error: secretError } = await admin.rpc("push_worker_secret");
    if (secretError || !secret || !await sameSecret(supplied, secret)) return json({ error: "Authentication required" }, 401);
    const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!raw) return json({ error: "Push sender is not configured" }, 503);
    const account = JSON.parse(raw);
    if (!account.project_id || !account.client_email || !account.private_key) return json({ error: "Push sender is not configured" }, 503);
    // Authenticate the sender before claiming messages: missing/bad setup consumes no attempts.
    const accessToken = await firebaseAccessToken(account);
    const { data: events, error } = await admin.rpc("claim_opportunity_push_events");
    if (error) throw new Error("claim_failed");
    let accepted = 0;
    for (const event of events ?? []) {
      let result = "retry", messageID: string | null = null, errorCode: string | null = null;
      try {
        // Recheck publication immediately before sending; the queue is not public authority.
        const { data: opportunity, error: readError } = await admin.from("opportunities").select("status,is_demo,deadline").eq("id", event.opportunity_id).maybeSingle();
        if (readError) throw new Error("publication_lookup_failed");
        if (!opportunity || opportunity.status !== "published" || opportunity.is_demo || (opportunity.deadline && new Date(opportunity.deadline) < new Date()) || new Date(event.created_at).getTime() < Date.now() - 86400000) {
          result = "skipped"; errorCode = "no_longer_public";
        } else {
          const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
            method: "POST", signal: AbortSignal.timeout(15000), headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
            body: JSON.stringify(pushMessage(event.opportunity_id, event.id)),
          });
          const body = await response.json().catch(() => ({}));
          if (response.ok && typeof body.name === "string") { result = "accepted"; messageID = body.name; accepted++; }
          else { errorCode = `sender_http_${response.status}`; result = response.status === 429 || response.status >= 500 ? "retry" : "failed"; }
        }
      } catch { errorCode = "push_request_failed"; }
      const { data: finished, error: finishError } = await admin.rpc("finish_opportunity_push_event", { target_id: event.id, target_lease: event.lease_id, result, message_id: messageID, error_code: errorCode });
      if (finishError || finished !== true) throw new Error("finish_failed");
    }
    return json({ accepted });
  } catch {
    console.error("Opportunity push processing unavailable; expired leases can retry.");
    return json({ error: "Push processing unavailable" }, 503);
  }
});
