const SUPABASE_URL = "https://pinpurdjfbvxrwexzlre.supabase.co";
// This publishable client key is also used by the iOS app. It is not an admin key.
const PUBLISHABLE_KEY = "sb_publishable_SE20ynXjKObWJ7AeOwfw8A_8lSAJ83q";
const SESSION_KEY = "opportunity313-provider-session";

const sample = [
  { id: "sample-1", title: "Future Builders Workshop", category: "Skilled Trades", status: "published", created_at: "2026-09-19T12:00:00Z" },
  { id: "sample-2", title: "Creative Studio Lab", category: "Arts", status: "pending_review", created_at: "2026-09-22T12:00:00Z" },
  { id: "sample-3", title: "Saturday Skills Clinic", category: "Sports", status: "draft", created_at: "2026-09-24T12:00:00Z" }
];
const state = { session: null, user: null, org: null, opportunities: sample, preview: true, filter: "all", view: "overview", authMode: "signin" };
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const escapeHTML = (value) => String(value ?? "").replace(/[&<>"']/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]);
const titleCase = (value) => String(value || "").replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());

function showNotice(message, error = false) {
  const notice = $("#notice");
  notice.textContent = message;
  notice.classList.toggle("error", error);
  notice.hidden = false;
  clearTimeout(showNotice.timeout);
  showNotice.timeout = setTimeout(() => { notice.hidden = true; }, 7000);
}

function setBusy(form, busy) {
  const button = form.querySelector('button[type="submit"]');
  if (!button) return;
  if (!button.dataset.label) button.dataset.label = button.innerHTML;
  button.disabled = busy;
  button.innerHTML = busy ? "Please wait…" : button.dataset.label;
}

function showFormError(selector, message) {
  const element = $(selector);
  element.textContent = message;
  element.hidden = !message;
}

async function request(path, { method = "GET", body, auth = true, refresh = true } = {}) {
  if (auth && refresh) await ensureFreshSession();
  const headers = { apikey: PUBLISHABLE_KEY, "Content-Type": "application/json" };
  if (auth && state.session?.access_token) headers.Authorization = `Bearer ${state.session.access_token}`;
  const response = await fetch(`${SUPABASE_URL}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  if (!response.ok) {
    let detail = "Please try again.";
    try { const data = await response.json(); detail = data.msg || data.message || data.error_description || data.error || detail; } catch { /* keep the generic message */ }
    throw new Error(typeof detail === "string" ? detail : "Please try again.");
  }
  if (response.status === 204) return null;
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

function saveSession(session) {
  state.session = session;
  if (session) sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
  else sessionStorage.removeItem(SESSION_KEY);
}

async function ensureFreshSession() {
  if (!state.session) throw new Error("Please sign in to continue.");
  if (Date.now() < (state.session.expires_at || 0) * 1000 - 60000) return;
  const refreshed = await request("/auth/v1/token?grant_type=refresh_token", { method: "POST", body: { refresh_token: state.session.refresh_token }, auth: false });
  saveSession({ ...refreshed, expires_at: Math.floor(Date.now() / 1000) + refreshed.expires_in });
}

async function loadProvider() {
  const authUser = await request("/auth/v1/user");
  state.user = authUser;
  const roles = await request(`/rest/v1/user_roles?select=role&user_id=eq.${encodeURIComponent(authUser.id)}`);
  if (!roles?.length) await request("/rest/v1/rpc/claim_onboarding_role", { method: "POST", body: { requested_role: "provider" } });
  else if (!roles.some(({ role }) => role === "provider" || role === "athletics")) {
    await signOut(false);
    throw new Error("This account is not a provider account. Please use a provider login.");
  }
  const memberships = await request(`/rest/v1/org_members?select=organization_id&user_id=eq.${encodeURIComponent(authUser.id)}&status=eq.active&limit=1`);
  if (!memberships?.length) {
    state.org = null;
    state.opportunities = [];
    state.preview = false;
    render();
    $("#setup-dialog").showModal();
    return;
  }
  const orgs = await request(`/rest/v1/organizations?select=*&id=eq.${encodeURIComponent(memberships[0].organization_id)}&limit=1`);
  if (!orgs?.length) throw new Error("Your organization could not be loaded.");
  state.org = orgs[0];
  state.opportunities = await request(`/rest/v1/opportunities?select=id,title,category,status,created_at,summary&organization_id=eq.${encodeURIComponent(state.org.id)}&order=created_at.desc&limit=100`);
  state.preview = false;
  render();
}

function closeDialog(selector) { if ($(selector).open) $(selector).close(); }
function setView(view) {
  state.view = view;
  $$(".view").forEach((section) => section.classList.toggle("active", section.id === `view-${view}`));
  $$(".nav-item").forEach((button) => button.classList.toggle("active", button.dataset.view === view));
  $("#crumb").textContent = titleCase(view);
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function statusLabel(status) {
  return ({ pending_review: "Awaiting review", published: "Published", draft: "Draft", draft_ai: "Draft", closed: "Closed", paused: "Paused" })[status] || titleCase(status);
}

function dateLabel(date) {
  if (!date) return "—";
  const parsed = new Date(date);
  return Number.isNaN(parsed.getTime()) ? "—" : parsed.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function render() {
  const opportunities = state.opportunities || [];
  const pending = opportunities.filter((item) => item.status === "pending_review").length;
  const published = opportunities.filter((item) => item.status === "published").length;
  const displayName = state.preview ? "Detroit" : (state.org?.name || state.user?.email?.split("@")[0] || "Provider").split(" ")[0];
  $("#greeting-name").textContent = displayName;
  $("#stat-total").textContent = opportunities.length;
  $("#stat-pending").textContent = pending;
  $("#stat-published").textContent = published;
  $("#filter-all").textContent = opportunities.length;
  $("#nav-count").textContent = opportunities.length;
  $("#preview-banner").hidden = !state.preview;
  $("#account-name").textContent = state.preview ? "Provider preview" : state.org?.name || "Provider account";
  $("#account-email").textContent = state.preview ? "Preview workspace" : state.user?.email || "Signed in";
  $("#account-avatar").textContent = (state.org?.name || "Provider").charAt(0).toUpperCase();
  $("#snapshot-caption").textContent = state.preview ? "Illustrative opportunities" : "Your workspace, all in one place";
  $("#org-name").textContent = state.preview ? "Detroit Community Partners" : state.org?.name || "Your organization";
  $("#org-description").textContent = state.preview ? "A place where Detroit youth discover what’s possible." : state.org?.description || "Add a description to introduce your work to families.";
  $("#org-type").textContent = state.preview ? "Community provider" : titleCase(state.org?.organization_type || "—");
  $("#org-contact").textContent = state.preview ? "hello@example.org" : state.org?.contact_email || state.user?.email || "—";
  $("#org-website").textContent = state.preview ? "example.org" : state.org?.website || "—";
  const verification = state.preview ? "pending" : state.org?.verification_status;
  const verified = verification === "verified";
  $("#org-status-title").textContent = verified ? "Organization verified" : verification === "rejected" ? "Verification needs attention" : "Verification in progress";
  $("#org-status-copy").textContent = verified ? "Your organization is verified. The Opportunity313 team reviews submitted opportunities before publication." : "New organizations can share opportunities while verification is pending. The Opportunity313 team reviews their submissions before publication.";
  $("#verification-headline").textContent = verified ? "Your organization is verified" : "Your organization’s status";
  $("#verification-description").textContent = verified ? "Your organization’s verification is complete." : "Verification is pending. You can still submit opportunities for review by the Opportunity313 team.";
  $("#recent-list").innerHTML = opportunities.length ? opportunities.slice(0, 3).map((item) => `<article class="recent-item"><span class="recent-icon">${escapeHTML(item.category?.charAt(0) || "O")}</span><div><strong>${escapeHTML(item.title)}</strong><small>${escapeHTML(item.category)} · ${dateLabel(item.created_at)}</small></div><span class="pill ${escapeHTML(item.status)}">${statusLabel(item.status)}</span></article>`).join("") : '<div class="empty-inline">No opportunities yet. Create your first one to get started.</div>';
  renderOpportunities();
}

function renderOpportunities() {
  const query = $("#opportunity-search").value.trim().toLowerCase();
  const items = state.opportunities.filter((item) => {
    const statusMatch = state.filter === "all" || item.status === state.filter || (state.filter === "draft" && item.status === "draft_ai");
    return statusMatch && (!query || `${item.title} ${item.category}`.toLowerCase().includes(query));
  });
  $("#opportunity-rows").innerHTML = items.map((item) => `<tr><td><span class="row-icon">${escapeHTML(item.category?.charAt(0) || "O")}</span><span class="table-title">${escapeHTML(item.title)}</span></td><td>${escapeHTML(item.category)}</td><td><span class="pill ${escapeHTML(item.status)}">${statusLabel(item.status)}</span></td><td>${dateLabel(item.created_at)}</td><td aria-label="${escapeHTML(item.title)}">↗</td></tr>`).join("");
  $("#opportunity-empty").hidden = items.length > 0;
  $(".table-scroll").hidden = items.length === 0;
}

async function signOut(showMessage = true) {
  try { if (state.session) await request("/auth/v1/logout", { method: "POST", refresh: false }); } catch { /* local sign-out still completes */ }
  saveSession(null);
  state.user = null;
  state.org = null;
  state.preview = true;
  state.opportunities = sample;
  $("#account-menu").hidden = true;
  closeDialog("#setup-dialog");
  render();
  if (showMessage) showNotice("You’ve signed out.");
}

function openEditor() {
  if (state.preview) { $("#auth-dialog").showModal(); return; }
  if (!state.org) { $("#setup-dialog").showModal(); return; }
  $("#opportunity-dialog").showModal();
}

function numberOrNull(value) { return value === "" || value == null ? null : Number(value); }
function dateOrNull(value) { return value ? new Date(value).toISOString() : null; }

$$("[data-view]").forEach((button) => button.addEventListener("click", () => setView(button.dataset.view)));
$$(".create-button").forEach((button) => button.addEventListener("click", openEditor));
$("#preview-signin").addEventListener("click", () => $("#auth-dialog").showModal());
$("#topbar-help").addEventListener("click", () => setView("verification"));
$("#account-button").addEventListener("click", () => { if (state.preview) $("#auth-dialog").showModal(); else $("#account-menu").hidden = !$("#account-menu").hidden; });
$("#mobile-account").addEventListener("click", () => { if (state.preview) $("#auth-dialog").showModal(); else signOut(); });
$("#sign-out").addEventListener("click", () => signOut());
$("#setup-signout").addEventListener("click", () => signOut());
$("#opportunity-search").addEventListener("input", renderOpportunities);
$$(".filter").forEach((button) => button.addEventListener("click", () => { state.filter = button.dataset.filter; $$(".filter").forEach((filter) => filter.classList.toggle("active", filter === button)); renderOpportunities(); }));

function setAuthMode(mode) {
  state.authMode = mode;
  $("#tab-signin").classList.toggle("active", mode === "signin");
  $("#tab-signup").classList.toggle("active", mode === "signup");
  $("#auth-title").textContent = mode === "signin" ? "Sign in to Opportunity313." : "Create your provider account.";
  $("#auth-subtitle").textContent = mode === "signin" ? "Use your provider account to manage your organization’s opportunities." : "Start with your work email. You’ll add organization details next.";
  $("#auth-submit").innerHTML = mode === "signin" ? 'Sign in <span aria-hidden="true">→</span>' : 'Create account <span aria-hidden="true">→</span>';
  $("#auth-submit").dataset.label = $("#auth-submit").innerHTML;
  $("#auth-form [name=password]").autocomplete = mode === "signin" ? "current-password" : "new-password";
  showFormError("#auth-error", "");
}
$("#tab-signin").addEventListener("click", () => setAuthMode("signin"));
$("#tab-signup").addEventListener("click", () => setAuthMode("signup"));

$("#auth-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  showFormError("#auth-error", "");
  setBusy(form, true);
  try {
    const fields = new FormData(form);
    const email = String(fields.get("email")).trim();
    const password = String(fields.get("password"));
    const endpoint = state.authMode === "signin" ? "/auth/v1/token?grant_type=password" : "/auth/v1/signup";
    const result = await request(endpoint, { method: "POST", body: { email, password }, auth: false });
    if (!result.access_token) {
      closeDialog("#auth-dialog");
      showNotice("Check your email for a confirmation link, then return and sign in.");
      return;
    }
    saveSession({ ...result, expires_at: Math.floor(Date.now() / 1000) + result.expires_in });
    await loadProvider();
    closeDialog("#auth-dialog");
    form.reset();
    showNotice(state.org ? `Welcome to ${state.org.name}.` : "Account ready. Add your organization to continue.");
  } catch (error) { showFormError("#auth-error", error.message); }
  finally { setBusy(form, false); }
});

$("#setup-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  showFormError("#setup-error", "");
  setBusy(form, true);
  try {
    const fields = new FormData(form);
    await request("/rest/v1/rpc/register_provider_organization", { method: "POST", body: { organization_name: String(fields.get("organization_name")).trim(), requested_type: fields.get("requested_type"), organization_description: String(fields.get("organization_description")).trim() || null } });
    closeDialog("#setup-dialog");
    await loadProvider();
    showNotice("Your organization is ready. Verification is pending; opportunities can be sent for review.");
  } catch (error) { showFormError("#setup-error", error.message); }
  finally { setBusy(form, false); }
});

$("#opportunity-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  showFormError("#opportunity-error", "");
  const fields = new FormData(form);
  const ageMin = numberOrNull(fields.get("age_min"));
  const ageMax = numberOrNull(fields.get("age_max"));
  const gradeMin = numberOrNull(fields.get("grade_min"));
  const gradeMax = numberOrNull(fields.get("grade_max"));
  const startsAt = dateOrNull(fields.get("starts_at"));
  const endsAt = dateOrNull(fields.get("ends_at"));
  const deadline = dateOrNull(fields.get("deadline"));
  if (ageMin !== null && ageMax !== null && ageMin > ageMax) { showFormError("#opportunity-error", "Minimum age must be less than or equal to maximum age."); return; }
  if (gradeMin !== null && gradeMax !== null && gradeMin > gradeMax) { showFormError("#opportunity-error", "Minimum grade must be less than or equal to maximum grade."); return; }
  if (endsAt && endsAt < startsAt) { showFormError("#opportunity-error", "End date must be after the start date."); return; }
  setBusy(form, true);
  try {
    const payload = { organization_id: state.org.id, title: String(fields.get("title")).trim(), summary: String(fields.get("summary")).trim(), category: fields.get("category"), opportunity_type: fields.get("opportunity_type"), age_min: ageMin, age_max: ageMax, grade_min: gradeMin, grade_max: gradeMax, gender_eligibility: fields.get("gender_eligibility"), starts_at: startsAt, ends_at: endsAt, deadline, cost_cents: Math.round(Number(fields.get("cost") || 0) * 100), is_free: Number(fields.get("cost") || 0) === 0, location_name: String(fields.get("location_name")).trim(), neighborhood: String(fields.get("neighborhood") || "").trim() || null, transportation: String(fields.get("transportation") || "").trim() || null, meals_provided: fields.has("meals_provided"), accessibility: String(fields.get("accessibility") || "").trim() || null, parent_requirements: String(fields.get("parent_requirements") || "").trim() || null, registration_method: "provider_submission", registration_url: String(fields.get("registration_url") || "").trim() || null, capacity: numberOrNull(fields.get("capacity")), status: "pending_review", created_by: state.user.id };
    await request("/rest/v1/opportunities", { method: "POST", body: payload });
    state.opportunities = await request(`/rest/v1/opportunities?select=id,title,category,status,created_at,summary&organization_id=eq.${encodeURIComponent(state.org.id)}&order=created_at.desc&limit=100`);
    closeDialog("#opportunity-dialog");
    form.reset();
    render();
    setView("opportunities");
    showNotice("Opportunity submitted for review.");
  } catch (error) { showFormError("#opportunity-error", error.message); }
  finally { setBusy(form, false); }
});

render();
try {
  const saved = JSON.parse(sessionStorage.getItem(SESSION_KEY) || "null");
  if (saved?.refresh_token) { saveSession(saved); loadProvider().catch(async (error) => { await signOut(false); showNotice(`Session ended: ${error.message}`, true); }); }
} catch { sessionStorage.removeItem(SESSION_KEY); }
