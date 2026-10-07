"use strict";
const token = new URL(location.href).searchParams.get("token");
// Keep the signed preference token out of future navigation/referrer URLs.
history.replaceState(null, "", location.pathname);
const endpoint = "https://pinpurdjfbvxrwexzlre.supabase.co/functions/v1/email-unsubscribe?token=" + encodeURIComponent(token ?? "");
const status = document.querySelector("#status");
const form = document.querySelector("#unsubscribe");
const button = form.querySelector("button");
const retry = document.querySelector("#retry");
async function check() {
  retry.hidden = true;
  status.textContent = "Checking your unsubscribe link…";
  if (!token) { status.textContent = "Open the unsubscribe link in an Opportunity313 email to change your preferences."; return; }
  try {
    const response = await fetch(endpoint, { cache: "no-store", signal: AbortSignal.timeout(15000) });
    if (!response.ok) throw new Error(response.status === 400 ? "invalid" : "unavailable");
    status.textContent = "You’re in control of your email updates.";
    form.hidden = false;
  } catch (error) {
    status.textContent = error.message === "invalid" ? "This link is invalid or the account has been deleted. Open a link from your email, or use Email Preferences in the app." : "We couldn’t load your preferences. Please try again.";
    retry.hidden = error.message === "invalid";
  }
}
form.addEventListener("submit", async event => {
  event.preventDefault();
  button.disabled = true;
  status.textContent = "Updating your preferences…";
  try {
    const response = await fetch(endpoint, { method: "POST", cache: "no-store", signal: AbortSignal.timeout(15000) });
    const result = await response.json();
    if (!response.ok || result.unsubscribed !== true) throw new Error("unavailable");
    form.hidden = true;
    status.textContent = "You’re unsubscribed from optional Opportunity313 emails. Security and requested sign-in emails will continue.";
  } catch { status.textContent = "We couldn’t unsubscribe you. Please try again."; }
  finally { button.disabled = false; }
});
retry.addEventListener("click", check);
check();
