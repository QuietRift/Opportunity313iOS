type Message = { subject: string; text: string; html: string };
export function emailMessage(kind: string, payload: Record<string, unknown>): Message {
  const title = typeof payload.title === "string" ? payload.title.slice(0, 200) : "Your opportunity";
  const messages: Record<string, [string, string]> = {
    parent_welcome: ["Welcome to Opportunity313", "Your Parent account is ready. Sign in to the Opportunity313 app and open Children to add a profile for each child. Children under 18 use the private code you receive after adding their profile."],
    provider_welcome: ["Welcome to Opportunity313", "Your Provider account is ready. Finish your organization profile in the app or at https://www.opportunity313.com/provider/. Every submitted opportunity requires admin review before it becomes public."],
    child_added: ["A child profile was added to your account", "A child profile was added to your Opportunity313 Parent account. Return to the app to view the profile and its private access code. If code creation failed, retry there; you do not need to add the child again."],
    child_access_created: ["A child access code was created or replaced", "A private sign-in code was created or replaced for a child in your Opportunity313 account. Save or share the code from the app. You can replace or revoke access from the child's profile. Codes and passwords are never included in these emails."],
    child_access_revoked: ["Child sign-in access was revoked", "Child sign-in access was revoked for a profile you manage in Opportunity313. The child's profile remains in your Parent account. You can generate a new code from the child's profile when you want to restore access."],
    submission_pending: ["Opportunity submitted for review", `We received “${title}”. Its status is Pending. An administrator must approve it before it appears publicly. View its status in your organization workspace.`],
    submission_approved: ["Your opportunity was approved", `“${title}” was approved and published on Opportunity313. View it in your organization workspace.`],
    submission_rejected: ["Your opportunity was not approved", `“${title}” was reviewed and was not approved for publication. View its Rejected status in your organization workspace. Contact the Opportunity313 team for next steps. Internal admin notes are not included in this email.`],
    submission_paused: ["Your opportunity was paused", `“${title}” has been paused. View its status in your organization workspace.`],
    organization_verified: ["Your organization was verified", `“${title}” is now verified on Opportunity313. Each opportunity still requires separate admin approval before publication.`],
  };
  const message = messages[kind];
  if (!message) throw new Error("unsupported_template");
  const [subject, body] = message;
  const text = `${body}\n\nOpen the Opportunity313 app. Providers can also sign in at https://www.opportunity313.com/provider/.\n\nIf you did not make this change, review your account access and contact the Opportunity313 team. This is an account notification, not a marketing message.`;
  const escape = (value: string) => value.replace(/[&<>"']/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[char]!));
  return { subject, text, html: `<div style="font-family:Arial,sans-serif;max-width:580px;margin:auto;color:#10253d"><h1 style="font-size:24px">Opportunity<span style="color:#f64f1b">313</span></h1><h2>${escape(subject)}</h2>${text.split("\n\n").map(paragraph => `<p style="line-height:1.6">${escape(paragraph)}</p>`).join("")}</div>` };
}
