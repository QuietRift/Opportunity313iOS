(() => {
  const role=document.body.dataset.accountType;
  if(!['parent','provider'].includes(role))return;
  const $=selector=>document.querySelector(selector);
  const api=window.Opportunity313Auth;
  const client=api.createSessionClient(`opportunity313-${role}-session`);
  const draftKey=`opportunity313-${role}-signup-draft`;
  const accountForm=$('#account-form'), setupForm=$('#setup-form');
  let mode='signup',busy=false,user=null,organizationID=null,confirmationEmail='',resendUntil=0,screen='account';
  let draft={}; try { draft=JSON.parse(sessionStorage.getItem(draftKey)||'{}'); } catch { /* No saved draft. */ }
  function persistDraft() { try { sessionStorage.setItem(draftKey,JSON.stringify(draft)); } catch { /* Keep in memory. */ } }
  function clearDraft() { draft={};try{sessionStorage.removeItem(draftKey);}catch{} }
  function message(selector,text) {$(selector).textContent=text;$(selector).hidden=!text;}
  function clearMessages(){message('#page-error','');message('#page-status','');}
  function showScreen(next) {
    screen=next;
    accountForm.hidden=false;$("#switch-mode").hidden=false;
    ['account','confirmation','profile','complete'].forEach(name=>{$(`#${name}-screen`).hidden=name!==next;});
    $('#session-recovery').hidden=true;
    $('#step-account').toggleAttribute('aria-current',false);$('#step-profile').toggleAttribute('aria-current',false);
    $(next==='account'||next==='confirmation'?'#step-account':'#step-profile').setAttribute('aria-current','step');
    if(next!=='account')$(`#${next}-screen`).focus();
  }
  function setBusy(value) {
    busy=value;$('#main').setAttribute('aria-busy',String(value));
    [accountForm,setupForm].forEach(form=>{form.querySelector('fieldset').disabled=value;});
    document.querySelectorAll('#main button').forEach(button=>{button.disabled=value;});
    $('#resend-email').disabled=value||Date.now()<resendUntil;
    document.querySelectorAll('#main a').forEach(link=>{link.setAttribute('aria-disabled',String(value));link.tabIndex=value?-1:0;});
    document.querySelectorAll('button[type=submit]').forEach(button=>{if(!button.dataset.label)button.dataset.label=button.textContent;button.textContent=value?'Please wait…':button.dataset.label;});
  }
  $('#main').addEventListener('click',event=>{if(busy&&event.target.closest('a'))event.preventDefault();});
  function setMode(next) {
    mode=next;clearMessages();showScreen('account');
    const signup=mode==='signup';
    $('#name-label').hidden=!signup;accountForm.elements.display_name.required=signup;
    $('#confirm-label').hidden=!signup;accountForm.elements.confirm_password.required=signup;
    $('#screen-title').textContent=signup?`Create your ${role} account`:`Sign in to your ${role} account`;
    $('#screen-description').textContent=signup?'Start with your name, email, and a password.':'Use your Opportunity313 email and password to continue.';
    $('#account-submit').textContent=signup?'Create account':'Sign in';$('#account-submit').dataset.label=$('#account-submit').textContent;
    $('#mode-prompt').textContent=signup?'Already have an account?':'New to Opportunity313?';$('#switch-mode').textContent=signup?'Sign in':'Create account';
    accountForm.elements.password.minLength=signup?8:1;accountForm.elements.password.autocomplete=signup?'new-password':'current-password';
    $('#password-help').textContent=signup?'Use at least 8 characters.':'Your existing account password.';
    accountForm.elements.password.value='';accountForm.elements.confirm_password.value='';validatePassword(false);
    resetPasswordVisibility();
    history.replaceState(null,'',`${location.pathname}${signup?'':'?mode=signin'}`);
  }
  function resetPasswordVisibility(){accountForm.elements.password.type='password';accountForm.elements.confirm_password.type='password';$('#toggle-password').textContent='Show';$('#toggle-password').setAttribute('aria-pressed','false');$('#toggle-password').setAttribute('aria-label','Show password');}
  function validatePassword(show=true) {
    const confirm=accountForm.elements.confirm_password;
    const mismatch=mode==='signup'&&confirm.value!==accountForm.elements.password.value;
    confirm.setCustomValidity(mismatch?'Passwords do not match.':'');
    const visible=show&&mismatch&&!!confirm.value;$('#password-error').hidden=!visible;confirm.setAttribute('aria-invalid',String(visible));
  }
  $('#toggle-password').addEventListener('click',()=>{const showing=accountForm.elements.password.type==='text';accountForm.elements.password.type=showing?'password':'text';accountForm.elements.confirm_password.type=showing?'password':'text';$('#toggle-password').textContent=showing?'Show':'Hide';$('#toggle-password').setAttribute('aria-pressed',String(!showing));$('#toggle-password').setAttribute('aria-label',showing?'Show password':'Hide password');});
  ['password','confirm_password'].forEach(name=>accountForm.elements[name].addEventListener('input',()=>validatePassword()));
  $('#switch-mode').addEventListener('click',()=>setMode(mode==='signup'?'signin':'signup'));
  accountForm.elements.email.value=draft.email||'';accountForm.elements.display_name.value=draft.display_name||'';
  accountForm.addEventListener('submit',async event=>{
    event.preventDefault();if(busy)return;validatePassword();if(!accountForm.reportValidity())return;
    const fields=new FormData(accountForm),email=String(fields.get('email')).trim(),password=String(fields.get('password'));
    const name=String(fields.get('display_name')||'').trim();
    if(mode==='signup'&&!name){message('#page-error','Enter your name to continue.');accountForm.elements.display_name.focus();return;}
    if(draft.email && draft.email!==email)clearDraft();
    draft={...draft,email,...(mode==='signup'?{display_name:name}:{})};persistDraft();clearMessages();setBusy(true);
    try {
      const body={email,password};
      // Metadata is display information only. The backend role is claimed after verified sign-in.
      if(mode==='signup')body.data={display_name:name,full_name:name};
      const result=await api.request(mode==='signup'?'/auth/v1/signup':'/auth/v1/token?grant_type=password',{method:'POST',body});
      if(!result?.access_token) {
        if(mode!=='signup')throw new Error('Sign-in could not be completed. Please try again.');
        confirmationEmail=email;$('#confirmation-email').textContent=email;accountForm.elements.password.value='';accountForm.elements.confirm_password.value='';resetPasswordVisibility();showScreen('confirmation');return;
      }
      client.save(result);accountForm.elements.password.value='';accountForm.elements.confirm_password.value='';resetPasswordVisibility();
      await prepareProfile();
    } catch(error) {
      message('#page-error',error.message);
      if(client.session)showRecovery();
      else if(error.code==='email_not_confirmed') {confirmationEmail=email;$('#confirmation-email').textContent=email;showScreen('confirmation');}
    } finally {setBusy(false);}
  });
  async function prepareProfile() {
    user=await client.request('/auth/v1/user');
    const roles=await client.request(`/rest/v1/user_roles?select=role&user_id=eq.${encodeURIComponent(user.id)}`);
    if(roles.length&&!roles.some(item=>item.role===role)) {
      await client.signOut();user=null;showScreen('account');
      throw new Error(`This login uses a different account type. Choose its account type or use a different email for your ${role} account.`);
    }
    if(!roles.length)await client.request('/rest/v1/rpc/claim_onboarding_role',{method:'POST',body:{requested_role:role}});
    const profiles=await client.request(`/rest/v1/profiles?select=display_name,neighborhood&user_id=eq.${encodeURIComponent(user.id)}&limit=1`);
    const name=draft.display_name||user.user_metadata?.full_name||profiles[0]?.display_name||'';
    $('#signed-in-email').textContent=user.email;
    if(role==='provider') {
      const memberships=await client.request(`/rest/v1/org_members?select=organization_id&user_id=eq.${encodeURIComponent(user.id)}&status=eq.active&limit=1`);
      if(memberships.length){clearDraft();location.assign('/provider/');return;}
      organizationID=null;
      for(const element of setupForm.elements) { if(element.name&&draft.profile?.[element.name]!==undefined)element.value=draft.profile[element.name]; }
      if(!setupForm.elements.contact_name.value)setupForm.elements.contact_name.value=name;
      if(!setupForm.elements.contact_email.value)setupForm.elements.contact_email.value=user.email;
    } else {
      setupForm.elements.display_name.value=draft.profile?.display_name||name;
      setupForm.elements.neighborhood.value=draft.profile?.neighborhood??profiles[0]?.neighborhood??'';
    }
    showScreen('profile');clearMessages();
  }
  function showRecovery(){ $('#session-recovery').hidden=false;accountForm.hidden=true;$('#switch-mode').hidden=true; }
  setupForm.addEventListener('input',()=>{draft.profile=Object.fromEntries(new FormData(setupForm));persistDraft();});
  setupForm.addEventListener('submit',async event=>{
    event.preventDefault();if(busy||!user)return;
    const fields=new FormData(setupForm),profile=Object.fromEntries([...fields].map(([key,value])=>[key,String(value).trim()]));
    if(role==='provider'&&profile.name.length<3){message('#page-error','Enter an organization name with at least 3 characters.');setupForm.elements.name.focus();return;}
    if(role==='parent'&&!profile.display_name){message('#page-error','Enter your name to continue.');setupForm.elements.display_name.focus();return;}
    if(profile.website&&!/^https?:\/\//i.test(profile.website)){message('#page-error','Use an http:// or https:// website address.');return;}
    draft.profile=profile;persistDraft();clearMessages();setBusy(true);
    try {
      if(role==='provider') {
        // Recheck membership before create: a retry or another tab may have already completed setup.
        if(!organizationID) {
          const memberships=await client.request(`/rest/v1/org_members?select=organization_id&user_id=eq.${encodeURIComponent(user.id)}&status=eq.active&limit=1`);
          if(memberships.length){clearDraft();location.assign('/provider/');return;}
        }
        const saved=await client.request('/rest/v1/rpc/save_organization_profile',{method:'POST',body:{target_organization_id:organizationID,profile}});
        const organization=Array.isArray(saved)?saved[0]:saved;
        if(!organization?.id)throw new Error('Check the provider workspace before trying again. The save response could not be read.');
        organizationID=organization.id;clearDraft();location.assign('/provider/');
      } else {
        await client.request('/auth/v1/user',{method:'PUT',body:{data:{full_name:profile.display_name,display_name:profile.display_name}}});
        const saved=await client.request(`/rest/v1/profiles?user_id=eq.${encodeURIComponent(user.id)}`,{method:'PATCH',headers:{Prefer:'return=representation'},body:{display_name:profile.display_name,neighborhood:profile.neighborhood||null}});
        if(!Array.isArray(saved)||!saved.length)throw new Error('Your profile could not be saved. Please try again.');
        $('#complete-name').textContent=profile.display_name;$('#complete-email').textContent=user.email;clearDraft();showScreen('complete');
      }
    } catch(error){message('#page-error',error.message);}finally{setBusy(false);}
  });
  $('#confirmed-signin').addEventListener('click',()=>{setMode('signin');accountForm.elements.email.value=confirmationEmail||draft.email||'';accountForm.elements.password.focus();});
  $('#different-email').addEventListener('click',()=>{confirmationEmail='';resendUntil=0;clearDraft();accountForm.reset();setMode('signup');accountForm.elements.email.focus();});
  $('#resend-email').addEventListener('click',async()=>{
    if(busy||Date.now()<resendUntil)return;clearMessages();setBusy(true);
    try{await api.request('/auth/v1/resend',{method:'POST',body:{type:'signup',email:confirmationEmail||draft.email}});resendUntil=Date.now()+30000;message('#page-status','Confirmation email requested. Check your inbox and spam folder. You can resend again in 30 seconds.');setTimeout(()=>{if(!busy)$('#resend-email').disabled=false;},30000);}
    catch(error){message('#page-error',error.message);}finally{setBusy(false);}
  });
  document.querySelectorAll('.switch-account').forEach(button=>button.addEventListener('click',async()=>{
    if(busy)return;setBusy(true);await client.signOut();user=null;organizationID=null;clearDraft();accountForm.reset();setupForm.reset();accountForm.hidden=false;$('#switch-mode').hidden=false;setMode('signin');message('#page-status','You’ve signed out.');setBusy(false);
  }));
  $('#retry-session').addEventListener('click',async()=>{if(busy)return;setBusy(true);clearMessages();try{await prepareProfile();accountForm.hidden=false;$('#switch-mode').hidden=false;}catch(error){message('#page-error',error.message);if(client.session)showRecovery();else{accountForm.hidden=false;$('#switch-mode').hidden=false;}}finally{setBusy(false);}});
  setMode(new URLSearchParams(location.search).get('mode')==='signin'?'signin':'signup');
  setBusy(false);
  if(client.session) {
    setBusy(true);prepareProfile().catch(error=>{message('#page-error',error.message);if(client.session)showRecovery();}).finally(()=>setBusy(false));
  }
})();
