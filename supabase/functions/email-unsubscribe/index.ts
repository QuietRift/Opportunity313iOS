import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const headers = { "Content-Type": "application/json", "Cache-Control": "no-store", "Referrer-Policy": "no-referrer", "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "content-type, apikey, x-client-info" };
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers });
Deno.serve(async request => {
  if (request.method === "OPTIONS") return new Response(null, { headers });
  if (!["GET", "POST"].includes(request.method)) return json({ error: "Method not allowed" }, 405);
  const token = new URL(request.url).searchParams.get("token");
  if (!token || token.length > 110) return json({ error: "This unsubscribe link is invalid." }, 400);
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "Please try again shortly." }, 503);
  try {
    const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    // GET only validates. Mail scanners cannot unsubscribe by visiting a link.
    const { data: valid, error } = await admin.rpc("unsubscribe_email", { token, apply_change: request.method === "POST" });
    if (error) throw error;
    if (valid !== true) return json({ error: "This unsubscribe link is invalid or the account was deleted." }, 400);
    // RFC 8058 one-click POST needs a successful empty response, without login.
    if (request.method === "POST" && (await request.text()) === "List-Unsubscribe=One-Click") return new Response(null, { status: 200, headers });
    return json(request.method === "POST" ? { unsubscribed: true } : { valid: true });
  } catch {
    return json({ error: "We couldn’t update your email preferences. Please try again." }, 503);
  }
});
