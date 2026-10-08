// Public client configuration shared with the iOS app. Backend roles and RLS authorize access.
window.Opportunity313Auth = (() => {
  const url = 'https://pinpurdjfbvxrwexzlre.supabase.co';
  const key = 'sb_publishable_SE20ynXjKObWJ7AeOwfw8A_8lSAJ83q';
  async function request(path, {method='GET', body, session, headers:extraHeaders={}}={}) {
    const headers = {apikey:key, 'Content-Type':'application/json', ...extraHeaders};
    if (session?.access_token) headers.Authorization = `Bearer ${session.access_token}`;
    let response;
    try { response = await fetch(`${url}${path}`, {method, headers, signal:AbortSignal.timeout(20000), body:body===undefined?undefined:JSON.stringify(body)}); }
    catch { throw new Error('Could not connect to Opportunity313. Check your connection and try again.'); }
    if (!response.ok) {
      let data={}; try { data=await response.json(); } catch { /* Fall back to a safe message. */ }
      const message=data.msg || data.message || data.error_description || data.error;
      const error=new Error(typeof message==='string'?message:'Unable to complete the request. Please try again.');
      error.status=response.status; error.code=data.error_code || data.code; throw error;
    }
    if (response.status===204) return null;
    const text=await response.text(); return text?JSON.parse(text):null;
  }
  function createSessionClient(storageKey) {
    let session=null, refreshPromise;
    try { const saved=JSON.parse(sessionStorage.getItem(storageKey)||'null'); if(saved?.refresh_token)session=saved; } catch { /* Start signed out. */ }
    function save(value) {
      session=value?{...value, expires_at:value.expires_at || Math.floor(Date.now()/1000)+Number(value.expires_in || 3600)}:null;
      try { if(session)sessionStorage.setItem(storageKey,JSON.stringify(session)); else sessionStorage.removeItem(storageKey); } catch { /* In-memory session still works. */ }
    }
    async function authenticatedRequest(path, options={}) {
      if(!session)throw new Error('Please sign in to continue.');
      if(Date.now()>=Number(session.expires_at || 0)*1000-60000) {
        if(!refreshPromise)refreshPromise=request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:session.refresh_token}}).then(save).finally(()=>{refreshPromise=null;});
        await refreshPromise;
      }
      return request(path,{...options,session});
    }
    async function signOut() {
      const current=session; save(null);
      if(current) { try { await request('/auth/v1/logout?scope=local',{method:'POST',session:current}); } catch { /* Local credentials are cleared even if offline. */ } }
    }
    return {get session(){return session;},save,request:authenticatedRequest,signOut};
  }
  return {url,key,request,createSessionClient};
})();
