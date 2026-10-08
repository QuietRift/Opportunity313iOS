import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { emailMessage } from "./templates.ts";

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json" } });
const sameSecret = async (a: string, b: string) => {
  const hash = async (value: string) => new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
  const [left, right] = await Promise.all([hash(a), hash(b)]);
  let difference = 0; for (let i = 0; i < left.length; i++) difference |= left[i] ^ right[i];
  return difference === 0;
};
Deno.serve(async request => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL"), serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "Service unavailable" }, 503);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  try {
    const supplied = request.headers.get("x-email-worker-secret");
    if (!supplied) return json({ error: "Authentication required" }, 401);
    const { data: expected, error: secretError } = await admin.rpc("email_worker_secret");
    if (secretError || !expected || !await sameSecret(supplied, expected)) return json({ error: "Authentication required" }, 401);
    const apiKey = Deno.env.get("RESEND_API_KEY"), from = Deno.env.get("EMAIL_FROM");
    // Missing setup does not consume queued messages or retry attempts.
    if (!apiKey || !from) return json({ error: "Email sender is not configured" }, 503);
    const publicBase = (Deno.env.get("EMAIL_PUBLIC_BASE_URL") ?? "https://www.opportunity313.com").replace(/\/$/, "");
    if (!publicBase.startsWith("https://")) return json({ error: "A secure email preference page is required" }, 503);
    const preferencePage = await fetch(`${publicBase}/unsubscribe/`, { signal: AbortSignal.timeout(10000) });
    if (!preferencePage.ok || !(await preferencePage.text()).includes('id="unsubscribe"')) {
      return json({ error: "Publish the email preference page before activating delivery" }, 503);
    }
    const { data: messages, error } = await admin.rpc("claim_transactional_emails", { batch_size: 5 });
    if (error) throw new Error("queue_claim_failed");
    let accepted = 0, failed = 0;
    for (const message of messages ?? []) {
      let result = "retry", messageID: string | null = null, errorCode: string | null = null;
      try {
        const { data, error: userError } = await admin.auth.admin.getUserById(message.recipient_user_id);
        if (userError) throw new Error("recipient_lookup_failed");
        const user = data.user;
        if (!user?.email || !user.email_confirmed_at || user.email.endsWith(".invalid") || (user.banned_until && new Date(user.banned_until) > new Date())) {
          result = "skipped"; errorCode = "recipient_unavailable";
        } else {
          const { data: preferences, error: preferenceError } = await admin.rpc("email_delivery_preferences", { recipient: user.id ?? message.recipient_user_id });
          if (preferenceError || !preferences?.token) throw new Error("preferences_unavailable");
          const essential = ["child_access_created", "child_access_revoked"].includes(message.kind);
          if (!essential && !preferences.enabled) {
            result = "skipped"; errorCode = "unsubscribed";
          } else {
          const unsubscribeURL = `${publicBase}/unsubscribe/?token=${encodeURIComponent(preferences.token)}`;
          const oneClickURL = `${url}/functions/v1/email-unsubscribe?token=${encodeURIComponent(preferences.token)}`;
          const content = emailMessage(message.kind, message.payload, unsubscribeURL);
          const headers = essential ? {} : { "List-Unsubscribe": `<${oneClickURL}>`, "List-Unsubscribe-Post": "List-Unsubscribe=One-Click" };
          const response = await fetch("https://api.resend.com/emails", {
            method: "POST", signal: AbortSignal.timeout(15000),
            headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json", "Idempotency-Key": `op313-${message.id}` },
            body: JSON.stringify({ from, to: [user.email], ...content, headers }),
          });
          const body = await response.json().catch(() => ({}));
          if (response.ok && typeof body.id === "string") { result = "accepted"; messageID = body.id; accepted++; }
          else { errorCode = `sender_http_${response.status}`; result = response.status === 429 || response.status >= 500 ? "retry" : "failed"; }
          }
        }
      } catch (cause) {
        errorCode = cause instanceof Error && cause.message === "unsupported_template" ? "unsupported_template" : "delivery_request_failed";
        if (errorCode === "unsupported_template") result = "failed";
      }
      const { data: completed, error: completeError } = await admin.rpc("finish_transactional_email", {
        target_id: message.id, target_lease: message.lease_id, result, message_id: messageID, error_code: errorCode,
      });
      if (completeError || completed !== true) throw new Error("queue_finish_failed");
      if (result === "failed" || result === "retry") failed++;
      // Keep under the sender's default request limit.
      await new Promise(resolve => setTimeout(resolve, 600));
    }
    return json({ accepted, failed });
  } catch {
    console.error("Transactional email processing failed; pending leases can retry.");
    return json({ error: "Email processing unavailable" }, 503);
  }
});
