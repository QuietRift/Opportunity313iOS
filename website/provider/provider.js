const SUPABASE_URL = "https://pinpurdjfbvxrwexzlre.supabase.co";
// The same publishable client key as the iOS app. Authorization is enforced by the backend.
const PUBLISHABLE_KEY = "sb_publishable_SE20ynXjKObWJ7AeOwfw8A_8lSAJ83q";
const SESSION_KEY = "opportunity313-provider-session";
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const escapeHTML = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const titleCase = (value) => String(value || "").replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
const profileKeys = ["name", "organization_type", "description", "website", "contact_name", "contact_email", "contact_phone", "service_area", "address", "city"];
const sample = [
  { id: "sample-1", title: "Future Builders Workshop", category: "Skilled Trades", status: "published", verification_status: "verified", created_at: "2026-09-19T12:00:00Z", summary: "Sample: a hands-on introduction to skilled trades for Detroit youth.", location_name: "Sample community center", is_free: true },
  { id: "sample-2", title: "Creative Studio Lab", category: "Arts", status: "pending_review", verification_status: "pending", created_at: "2026-09-22T12:00:00Z", summary: "Sample: an afternoon of drawing, design, and creative collaboration.", is_free: true },
  { id: "sample-3", title: "Saturday Skills Clinic", category: "Sports", status: "closed", verification_status: "rejected", created_at: "2026-09-24T12:00:00Z", summary: "Sample: a sports clinic submission that was not approved.", is_free: true }
];
const sampleOrganization = { name: "Detroit Community Partners", organization_type: "community_provider", description: "Sample organization connecting Detroit youth with local programs.", website: "https://example.org", contact_name: "Sample contact", contact_email: "hello@example.org", contact_phone: "", service_area: "Detroit", address: "", city: "Detroit", verification_status: "pending" };
const state = { session: null, user: null, org: null, opportunities: sample, preview: true, filter: "all", view: "overview", authMode: "signin", busy: 0, loading: false, epoch: 0, profileDirty: false, confirmationEmail: null };
let refreshPromise;
let loadPromise;

function showNotice(message, error = false) {
  const notice = $("#notice"); notice.textContent = message;
  notice.classList.toggle("error-banner", error); notice.hidden = false;
}
function showFormError(selector, message) { const element = $(selector); element.textContent = message; element.hidden = !message; }
function updateActions() {
  $("#account-action").textContent = state.session ? "Sign out" : "Sign in";
  $("#account-action").disabled = state.busy > 0 || state.loading;
  $("#refresh-workspace").hidden = !state.session;
  $("#refresh-workspace").disabled = state.busy > 0 || state.loading;
  $("#retry-workspace").disabled = state.loading;
  $("#load-status").hidden = !state.loading;
  $$(".create-button").forEach((button) => { button.disabled = state.busy > 0 || state.loading; });
}
function setBusy(form, busy) {
  if ((form.dataset.busy === "true") === busy) return;
  form.dataset.busy = String(busy); form.setAttribute("aria-busy", String(busy));
  state.busy += busy ? 1 : -1;
  $$(`#${form.id} button`).forEach((button) => {
    if (button.type === "submit") {
      if (!button.dataset.label) button.dataset.label = button.textContent;
      button.textContent = busy ? "Saving…" : button.dataset.label;
    }
    button.disabled = busy;
  });
  form.querySelectorAll("input,select,textarea").forEach((control) => {
    if (busy) control.dataset.wasDisabled = String(control.disabled);
    control.disabled = busy || control.dataset.wasDisabled === "true";
  });
  const dialog = form.closest("dialog");
  if (dialog) dialog.querySelectorAll("button").forEach((button) => { button.disabled = busy; });
  updateActions();
}
function saveSession(session) {
  state.session = session;
  try { if (session) sessionStorage.setItem(SESSION_KEY, JSON.stringify(session)); else sessionStorage.removeItem(SESSION_KEY); }
  catch { /* Keep the session in memory when storage is unavailable. */ }
}
async function request(path, { method = "GET", body, auth = true, refresh = true } = {}) {
  if (auth && refresh) await ensureFreshSession();
  const headers = { apikey: PUBLISHABLE_KEY, "Content-Type": "application/json" };
  if (auth && state.session?.access_token) headers.Authorization = `Bearer ${state.session.access_token}`;
  const response = await fetch(`${SUPABASE_URL}${path}`, { method, headers, signal: AbortSignal.timeout(20000), body: body === undefined ? undefined : JSON.stringify(body) });
  if (!response.ok) {
    let message = "Unable to complete the request. Please try again.";
    try { const data = await response.json(); message = data.msg || data.message || data.error_description || data.error || message; } catch { /* use fallback */ }
    throw new Error(typeof message === "string" ? message : "Please try again.");
  }
  if (response.status === 204) return null;
  const text = await response.text(); return text ? JSON.parse(text) : null;
}
async function ensureFreshSession() {
  if (!state.session) throw new Error("Please sign in to continue.");
  if (Date.now() < (state.session.expires_at || 0) * 1000 - 60000) return;
  if (!refreshPromise) {
    const epoch = state.epoch;
    refreshPromise = request("/auth/v1/token?grant_type=refresh_token", { method: "POST", body: { refresh_token: state.session.refresh_token }, auth: false }).then((session) => {
      if (epoch !== state.epoch) throw new Error("This session has ended. Please sign in again.");
      saveSession({ ...session, expires_at: Math.floor(Date.now() / 1000) + session.expires_in });
    }).finally(() => { refreshPromise = null; });
  }
  await refreshPromise;
}
async function fetchOpportunities() {
  const rows = [];
  while (true) {
    const page = await request(`/rest/v1/opportunities?select=*&organization_id=eq.${encodeURIComponent(state.org.id)}&order=created_at.desc,id.desc&limit=200&offset=${rows.length}`);
    rows.push(...page); if (page.length < 200) return rows;
  }
}
async function loadProvider() {
  if (loadPromise) return loadPromise;
  const epoch = state.epoch;
  state.loading = true; updateActions(); $("#workspace-error").hidden = true;
  loadPromise = (async () => {
    const user = await request("/auth/v1/user");
    const roles = await request(`/rest/v1/user_roles?select=role&user_id=eq.${encodeURIComponent(user.id)}`);
    if (!roles.length) await request("/rest/v1/rpc/claim_onboarding_role", { method: "POST", body: { requested_role: "provider" } });
    else if (!roles.some(({ role }) => role === "provider")) throw new Error("Use an Organization account for this workspace. Other account types keep their existing experiences in the app.");
    if (epoch !== state.epoch) return;
    state.user = user;
    const memberships = await request(`/rest/v1/org_members?select=organization_id&user_id=eq.${encodeURIComponent(user.id)}&status=eq.active&limit=1`);
    if (epoch !== state.epoch) return;
    state.preview = false;
    if (!memberships.length) {
      state.org = null; state.opportunities = []; render(); setView("organization");
      showNotice("Add your organization’s information to complete setup."); return;
    }
    const orgs = await request(`/rest/v1/organizations?select=*&id=eq.${encodeURIComponent(memberships[0].organization_id)}&limit=1`);
    if (!orgs.length) throw new Error("Your organization could not be loaded. Try refreshing the workspace.");
    if (epoch !== state.epoch) return;
    state.org = orgs[0];
    const opportunities = await fetchOpportunities();
    if (epoch !== state.epoch) return;
    state.opportunities = opportunities; render();
  })().finally(() => { state.loading = false; loadPromise = null; updateActions(); });
  return loadPromise;
}
async function reloadWorkspace() {
  try { await loadProvider(); showNotice("Workspace updated."); }
  catch (error) { $("#workspace-error-message").textContent = error.message; $("#workspace-error").hidden = false; }
}
function setView(view) {
  if (!["overview", "opportunities", "organization", "verification"].includes(view)) view = "overview";
  state.view = view;
  $$(".view").forEach((section) => { const active = section.id === `view-${view}`; section.classList.toggle("active", active); section.hidden = !active; });
  $$(".nav-item").forEach((button) => { const active = button.dataset.view === view; button.classList.toggle("active", active); if (active) button.setAttribute("aria-current", "page"); else button.removeAttribute("aria-current"); });
  $("#crumb").textContent = ({ overview: "Dashboard", opportunities: "Opportunities", organization: "Organization profile", verification: "Verification" })[view];
  history.replaceState(null, "", `#${view}`);
  window.scrollTo(0, 0);
}
function approvalStatus(item) {
  if (item.verification_status === "rejected") return "rejected";
  if (item.status === "pending_review") return "pending";
  if (item.status === "published") return "approved";
  return "other";
}
function statusLabel(item) { const status = approvalStatus(item); return status === "other" ? titleCase(item.status) : titleCase(status); }
function badge(item) { return `<span class="pill ${approvalStatus(item)}">${escapeHTML(statusLabel(item))}</span>`; }
function dateLabel(value, includeTime = false) {
  if (!value) return "Not provided";
  const parsed = new Date(value); if (Number.isNaN(parsed.getTime())) return "Not provided";
  return parsed.toLocaleString("en-US", { timeZone: "America/Detroit", month: "short", day: "numeric", year: "numeric", ...(includeTime ? { hour: "numeric", minute: "2-digit", timeZoneName: "short" } : {}) });
}
function renderProfile() {
  const org = state.preview ? sampleOrganization : state.org;
  $("#org-name").textContent = org?.name || "Set up your organization";
  $("#org-type").textContent = titleCase(org?.organization_type || "Organization account");
  $("#org-id").textContent = state.preview ? "Sample organization" : org?.id || "Assigned after setup";
  const status = org?.verification_status || "pending";
  $("#org-verification").textContent = titleCase(status);
  $("#org-verification").className = `pill ${status === "verified" ? "approved" : status === "rejected" ? "rejected" : "pending"}`;
  $("#overview-verification").textContent = state.preview ? "Pending (sample)" : titleCase(status);
  $("#verification-headline").textContent = status === "verified" ? "Organization verified" : status === "rejected" ? "Verification needs attention" : "Pending verification";
  $("#verification-description").textContent = state.preview ? "Sample status. Sign in to check your organization." : status === "verified" ? "Your profile is verified. Every opportunity still requires admin approval before publication." : "Complete your profile so the Opportunity313 team can review it. You can submit opportunities while verification is pending.";
  if (!state.profileDirty) profileKeys.forEach((key) => { $("#profile-form").elements[key].value = org?.[key] || (key === "organization_type" ? "nonprofit" : ""); });
  $("#profile-fields").disabled = state.preview || !state.user;
  $("#profile-save").disabled = state.preview || !state.user;
  $("#profile-reset").disabled = state.preview || !state.user;
  $("#profile-save").textContent = state.org ? "Save profile" : "Create organization";
  $("#profile-save").dataset.label = $("#profile-save").textContent;
  $("#profile-save-note").textContent = state.preview ? "Sign in to manage your organization profile." : "Organization ID and verification status are managed by Opportunity313.";
}
function render() {
  const opportunities = state.opportunities;
  ["pending", "approved", "rejected"].forEach((status) => { $(`#stat-${status}`).textContent = opportunities.filter((item) => approvalStatus(item) === status).length; });
  $("#filter-all").textContent = opportunities.length;
  $("#preview-banner").hidden = !state.preview;
  $("#workspace-subtitle").textContent = state.preview ? "Submit opportunities. Follow their review. Keep your profile up to date." : state.org?.name || "Finish your organization profile to get started.";
  $("#account-name").textContent = state.preview ? "Sample workspace" : state.org?.name || "Organization account";
  $("#account-email").textContent = state.preview ? "Sign in for your organization" : state.user?.email || "Signed in";
  $("#account-avatar").textContent = (state.org?.name || "O").charAt(0).toUpperCase();
  $("#recent-list").innerHTML = opportunities.length ? opportunities.slice(0, 4).map((item) => `<button class="recent-item" type="button" data-detail="${escapeHTML(item.id)}"><div><strong>${escapeHTML(item.title)}</strong><small>${escapeHTML(item.category)} · ${dateLabel(item.created_at)}</small></div>${badge(item)}</button>`).join("") : '<p class="empty-inline">No submissions yet. Start with a program your organization offers.</p>';
  renderOpportunities(); renderProfile(); updateActions();
}
function setFilter(filter) {
  state.filter = filter;
  $$(".filter").forEach((button) => { const active = button.dataset.filter === filter; button.classList.toggle("active", active); button.setAttribute("aria-pressed", String(active)); });
  renderOpportunities();
}
function renderOpportunities() {
  const query = $("#opportunity-search").value.trim().toLowerCase();
  const items = state.opportunities.filter((item) => (state.filter === "all" || approvalStatus(item) === state.filter) && (!query || `${item.title} ${item.category}`.toLowerCase().includes(query)));
  $("#opportunity-rows").innerHTML = items.map((item) => `<tr><td><button type="button" class="title-button" data-detail="${escapeHTML(item.id)}">${escapeHTML(item.title)}</button></td><td>${escapeHTML(item.category)}</td><td>${badge(item)}</td><td>${dateLabel(item.created_at)}</td><td><button type="button" class="text-button" data-detail="${escapeHTML(item.id)}" aria-label="View ${escapeHTML(item.title)}">View →</button></td></tr>`).join("");
  $(".table-scroll").hidden = !items.length; $("#opportunity-empty").hidden = !!items.length;
  const hasRecords = state.opportunities.length > 0;
  $("#opportunity-empty h2").textContent = hasRecords ? "No matching submissions" : "No submissions yet";
  $("#opportunity-empty p").textContent = hasRecords ? "Try another status or search term." : "Submit your first opportunity for admin review.";
  $("#opportunity-empty .create-button").hidden = hasRecords;
}
function openDetail(id) {
  const item = state.opportunities.find((opportunity) => opportunity.id === id); if (!item) return;
  $("#detail-title").textContent = item.title; $("#detail-summary").textContent = item.summary || "No description provided.";
  $("#detail-status").textContent = `${state.preview ? "Sample · " : ""}${statusLabel(item)}`;
  $("#detail-status").className = `pill ${approvalStatus(item)}`;
  const range = (min, max) => min == null && max == null ? "Not specified" : `${min ?? "Any"} – ${max ?? "Any"}`;
  const fields = [ ["Category", item.category], ["Format", item.opportunity_type], ["Submitted", dateLabel(item.created_at)], ["Eligibility", titleCase(item.gender_eligibility || "all")], ["Ages", range(item.age_min,item.age_max)], ["Grades",range(item.grade_min,item.grade_max)], ["Starts",dateLabel(item.starts_at,true)], ["Ends",dateLabel(item.ends_at,true)], ["Application deadline",dateLabel(item.deadline,true)], ["Location",item.location_name], ["Cost",item.is_free ? "Free" : item.cost_cents == null ? "Not provided" : new Intl.NumberFormat("en-US",{ style:"currency",currency:"USD" }).format(item.cost_cents/100)], ["Capacity", item.capacity], ["Transportation",item.transportation], ["Accessibility",item.accessibility], ["Parent requirements",item.parent_requirements], ["Registration link",item.registration_url] ];
  $("#detail-fields").innerHTML = fields.map(([label,value]) => `<div><dt>${escapeHTML(label)}</dt><dd>${escapeHTML(value ?? "Not provided")}</dd></div>`).join("");
  $("#detail-dialog").showModal();
}
async function signOut() {
  const session = state.session; state.epoch++;
  saveSession(null); state.user = null; state.org = null; state.preview = true; state.opportunities = sample; state.profileDirty = false;
  $("#workspace-error").hidden = true; $("#opportunity-form").reset(); closeDialog("auth-dialog"); closeDialog("opportunity-dialog"); closeDialog("detail-dialog");
  render(); showNotice("You’ve signed out.");
  if (session) { try { await fetch(`${SUPABASE_URL}/auth/v1/logout?scope=local`, { method:"POST", headers:{apikey:PUBLISHABLE_KEY,Authorization:`Bearer ${session.access_token}`},signal:AbortSignal.timeout(10000) }); } catch { /* Local session is cleared regardless. */ } }
}
function openEditor() {
  if (state.preview) { $("#auth-dialog").showModal(); return; }
  if (!state.org) { setView("organization"); showNotice("Create your organization profile before submitting an opportunity."); return; }
  $("#opportunity-dialog").showModal();
}
function closeDialog(id) { const dialog = document.getElementById(id); if (dialog.open) dialog.close(); }
function numberOrNull(value) { return value === "" || value == null ? null : Number(value); }
// datetime-local fields are explicitly Detroit time, even on computers in another timezone.
function dateOrNull(value) {
  if (!value) return null;
  const wall = new Date(`${value}:00Z`); if (Number.isNaN(wall.getTime())) throw new Error("Enter a valid date and time.");
  const formatter = new Intl.DateTimeFormat("sv-SE", { timeZone:"America/Detroit",year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",second:"2-digit",hourCycle:"h23" });
  let candidate = wall.getTime();
  for (let i=0;i<3;i++) { const parts=Object.fromEntries(formatter.formatToParts(candidate).map(({type,value})=>[type,value])); const displayed=Date.UTC(+parts.year,+parts.month-1,+parts.day,+parts.hour,+parts.minute,+parts.second); candidate += wall.getTime()-displayed; }
  const parts=Object.fromEntries(formatter.formatToParts(candidate).map(({type,value})=>[type,value]));
  if (`${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}` !== value) throw new Error("That Detroit time does not exist because of daylight saving time. Choose another time.");
  return new Date(candidate).toISOString();
}

$$("[data-view]").forEach((button) => button.addEventListener("click", () => setView(button.dataset.view)));
$$(".create-button").forEach((button) => button.addEventListener("click", openEditor));
$$("[data-status]").forEach((button) => button.addEventListener("click", () => { setFilter(button.dataset.status); setView("opportunities"); }));
$$(".filter").forEach((button) => button.addEventListener("click", () => setFilter(button.dataset.filter)));
$("#opportunity-search").addEventListener("input", renderOpportunities);
$("#workspace").addEventListener("click", (event) => { const button=event.target.closest("[data-detail]"); if (button) openDetail(button.dataset.detail); });
$("#account-action").addEventListener("click", () => state.session ? signOut() : $("#auth-dialog").showModal());
$("#preview-signin").addEventListener("click", () => $("#auth-dialog").showModal());
$("#refresh-workspace").addEventListener("click", reloadWorkspace); $("#retry-workspace").addEventListener("click", reloadWorkspace);
$$("[data-close]").forEach((button) => button.addEventListener("click", () => closeDialog(button.dataset.close)));
$$("dialog").forEach((dialog) => dialog.addEventListener("cancel", (event) => { if (state.busy) event.preventDefault(); }));
$("#profile-form").addEventListener("input", () => { state.profileDirty = true; });
$("#profile-reset").addEventListener("click", () => { state.profileDirty = false; showFormError("#profile-error", ""); renderProfile(); });

function setAuthMode(mode) {
  state.authMode = mode;
  ["signin","signup"].forEach((tab) => { const active=mode===tab; $(`#tab-${tab}`).classList.toggle("active",active); $(`#tab-${tab}`).setAttribute("aria-pressed",String(active)); });
  $("#auth-title").textContent = mode === "signin" ? "Sign in to your workspace" : "Create an Organization account";
  $("#auth-subtitle").textContent = mode === "signin" ? "Use the same Organization login as the iOS app." : "Start with your email, then add your organization’s information.";
  $("#auth-submit").textContent = mode === "signin" ? "Sign in" : "Create account"; $("#auth-submit").dataset.label = $("#auth-submit").textContent;
  const password=$("#auth-form").elements.password; password.autocomplete=mode==="signin"?"current-password":"new-password"; password.minLength=mode==="signin"?1:8;
  showFormError("#auth-error", "");
}
$("#tab-signin").addEventListener("click",()=>setAuthMode("signin")); $("#tab-signup").addEventListener("click",()=>setAuthMode("signup"));
$("#auth-form").addEventListener("submit", async (event) => {
  event.preventDefault(); const form=event.currentTarget; if (state.busy) return;
  const fields=new FormData(form); const email=String(fields.get("email")).trim(); const password=String(fields.get("password"));
  showFormError("#auth-error",""); setBusy(form,true);
  try {
    const result=await request(state.authMode==="signin"?"/auth/v1/token?grant_type=password":"/auth/v1/signup",{method:"POST",body:{email,password},auth:false});
    if (!result.access_token) {
      state.confirmationEmail=email; $("#confirmation-message").hidden=false; $("#confirmation-message").textContent="Check your email for the confirmation link. After confirming, return here to sign in."; $("#resend-confirmation").hidden=false; form.elements.password.value=""; setAuthMode("signin"); return;
    }
    state.epoch++; state.profileDirty=false; saveSession({...result,expires_at:Math.floor(Date.now()/1000)+result.expires_in});
    state.preview=false; state.opportunities=[];
    try { await loadProvider(); }
    catch (error) { await signOut(); $("#auth-dialog").showModal(); throw error; }
    closeDialog("auth-dialog"); form.reset(); $("#notice").hidden=!!state.org; $("#confirmation-message").hidden=true; $("#resend-confirmation").hidden=true;
  } catch(error) { showFormError("#auth-error",error.message); }
  finally { setBusy(form,false); }
});
$("#resend-confirmation").addEventListener("click",async (event)=>{
  const button=event.currentTarget; button.disabled=true;
  try { await request("/auth/v1/resend",{method:"POST",auth:false,body:{type:"signup",email:state.confirmationEmail}}); $("#confirmation-message").textContent="Confirmation email requested. Check your inbox and spam folder."; }
  catch(error){showFormError("#auth-error",error.message);} finally{button.disabled=false;}
});
$("#profile-form").addEventListener("submit",async(event)=>{
  event.preventDefault(); const form=event.currentTarget; if(state.busy || state.preview || !state.user)return;
  const fields=new FormData(form); const profile=Object.fromEntries(profileKeys.map((key)=>[key,String(fields.get(key)||"").trim()]));
  if(profile.website && (!/^https?:\/\//i.test(profile.website) || /\s/.test(profile.website))){showFormError("#profile-error","Enter a website starting with https:// or http://.");return;}
  showFormError("#profile-error","");setBusy(form,true);
  try {
    const saved=await request("/rest/v1/rpc/save_organization_profile",{method:"POST",body:{target_organization_id:state.org?.id||null,profile}});
    const organization=Array.isArray(saved)?saved[0]:saved;
    if(!organization?.id)throw new Error("The save response could not be read. Refresh the workspace before trying again.");
    state.org=organization;
    state.profileDirty=false; render(); showNotice("Organization profile saved.");
  }catch(error){showFormError("#profile-error",error.message);}finally{setBusy(form,false);renderProfile();}
});
$("#opportunity-form").addEventListener("submit",async(event)=>{
  event.preventDefault(); const form=event.currentTarget; if(state.busy || !state.org || state.preview)return;
  const fields=new FormData(form); showFormError("#opportunity-error","");
  try {
    const ageMin=numberOrNull(fields.get("age_min")),ageMax=numberOrNull(fields.get("age_max")),gradeMin=numberOrNull(fields.get("grade_min")),gradeMax=numberOrNull(fields.get("grade_max"));
    const startsAt=dateOrNull(fields.get("starts_at")),endsAt=dateOrNull(fields.get("ends_at")),deadline=dateOrNull(fields.get("deadline"));
    if(ageMin!==null && ageMax!==null && ageMin>ageMax)throw new Error("Minimum age must be less than or equal to maximum age.");
    if(gradeMin!==null && gradeMax!==null && gradeMin>gradeMax)throw new Error("Minimum grade must be less than or equal to maximum grade.");
    if(endsAt && endsAt<startsAt)throw new Error("End time must be after the start time.");
    const payload={organization_id:state.org.id,title:String(fields.get("title")).trim(),summary:String(fields.get("summary")).trim(),category:fields.get("category"),opportunity_type:fields.get("opportunity_type"),age_min:ageMin,age_max:ageMax,grade_min:gradeMin,grade_max:gradeMax,gender_eligibility:fields.get("gender_eligibility"),starts_at:startsAt,ends_at:endsAt,deadline,cost_cents:Math.round(Number(fields.get("cost")||0)*100),is_free:Number(fields.get("cost")||0)===0,location_name:String(fields.get("location_name")).trim(),neighborhood:String(fields.get("neighborhood")||"").trim()||null,transportation:String(fields.get("transportation")||"").trim()||null,meals_provided:fields.has("meals_provided"),accessibility:String(fields.get("accessibility")||"").trim()||null,parent_requirements:String(fields.get("parent_requirements")||"").trim()||null,registration_method:"provider_submission",registration_url:String(fields.get("registration_url")||"").trim()||null,capacity:numberOrNull(fields.get("capacity")),status:"pending_review",created_by:state.user.id};
    if(!payload.title || !payload.summary || !payload.location_name)throw new Error("Enter a title, description, and location before submitting.");
    if(payload.registration_url && !/^https?:\/\//i.test(payload.registration_url))throw new Error("Use an http or https registration link.");
    setBusy(form,true);
    await request("/rest/v1/opportunities",{method:"POST",body:payload});
    closeDialog("opportunity-dialog");form.reset();$("#opportunity-search").value="";setFilter("all");setView("opportunities");showNotice("Opportunity submitted. It is pending admin review.");
    try{state.opportunities=await fetchOpportunities();render();}catch(error){$("#workspace-error-message").textContent=`Your submission was saved, but the list could not refresh. ${error.message}`;$("#workspace-error").hidden=false;}
  }catch(error){showFormError("#opportunity-error",error.message);}finally{setBusy(form,false);}
});

setView(location.hash.slice(1));render();setAuthMode("signin");
try {
  const saved=JSON.parse(sessionStorage.getItem(SESSION_KEY)||"null");
  if(saved?.refresh_token){saveSession(saved);state.preview=false;state.opportunities=[];render();loadProvider().catch((error)=>{ $("#workspace-error-message").textContent=`Unable to restore the workspace: ${error.message} You can retry or sign out.`;$("#workspace-error").hidden=false; });}
}catch{saveSession(null);}
