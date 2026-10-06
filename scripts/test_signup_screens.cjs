// Isolated browser fixtures. No real signups, emails, or database writes.
const {chromium}=require('playwright');
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=process.env.SIGNUP_WEB_ROOT||path.resolve(__dirname,'../website');
const artifacts=process.env.SIGNUP_TEST_ARTIFACTS||path.join(require('node:os').tmpdir(),'op313-signup-tests');fs.mkdirSync(artifacts,{recursive:true});
const server=http.createServer((req,res)=>{
 const pathname=new URL(req.url,'http://localhost').pathname;
 if(['/provider','/signup','/signup/parent','/signup/provider'].includes(pathname)){res.writeHead(301,{Location:`${pathname}/`});res.end();return;}
 const file=path.resolve(root,`.${pathname}${pathname.endsWith('/')?'index.html':''}`);
 if(!file.startsWith(path.resolve(root)+path.sep)){res.writeHead(403);res.end();return;}
 try{res.setHeader('Content-Type',file.endsWith('.js')?'application/javascript':file.endsWith('.css')?'text/css':'text/html');res.end(fs.readFileSync(file));}catch{res.writeHead(404);res.end();}
});
(async()=>{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const base=`http://127.0.0.1:${server.address().port}`;
 const browser=await chromium.launch({headless:true,executablePath:process.env.PROVIDER_TEST_BROWSER||undefined});
 const userID='00000000-0000-0000-0000-000000000031',orgID='00000000-0000-0000-0000-000000000032';
 const session={access_token:'fixture-access',refresh_token:'fixture-refresh',expires_in:3600};
 const contexts=[];
 async function fixture(options={}) {
  const context=await browser.newContext({viewport:{width:1440,height:1000}});contexts.push(context);const page=await context.newPage();
  const state={roles:[],membership:false,confirmation:false,failProfile:false,failRole:false,failSignIn:false,failSignup:false,signupCalls:0,claimCalls:0,refreshCalls:0,resendCalls:0,orgCalls:0,...options};
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.route('https://fonts.googleapis.com/**',route=>route.fulfill({body:''}));
  await page.route('https://pinpurdjfbvxrwexzlre.supabase.co/**',async route=>{
   const req=route.request(),url=new URL(req.url()),body=req.postDataJSON();
   const respond=(body,status=200)=>route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});
   if(url.pathname==='/auth/v1/signup'){state.signupCalls++;state.signupPayload=body;if(state.failSignup)return respond({msg:'Fixture signup unavailable'},503);return respond(state.confirmation?{id:userID}:session);}
   if(url.pathname==='/auth/v1/token'){if(url.searchParams.get('grant_type')==='refresh_token')state.refreshCalls++;if(state.failSignIn)return respond({msg:'Email not confirmed',error_code:'email_not_confirmed'},400);return respond(session);}
   if(url.pathname==='/auth/v1/resend'){state.resendCalls++;return respond({});}
   if(url.pathname==='/auth/v1/logout')return respond({});
   if(url.pathname==='/auth/v1/user'){if(req.method()==='PUT'){state.userPayload=body;return respond({id:userID});}return respond({id:userID,email:'fixture@example.org',user_metadata:{full_name:'Fixture Parent'}});}
   if(url.pathname==='/rest/v1/user_roles'){if(state.failRole)return respond({message:'Fixture role lookup unavailable'},500);return respond(state.roles.map(role=>({role})));}
   if(url.pathname==='/rest/v1/rpc/claim_onboarding_role'){state.claimCalls++;assert(['parent','provider'].includes(body.requested_role));state.roles=[body.requested_role];return respond(body.requested_role);}
   if(url.pathname==='/rest/v1/profiles'){if(req.method()==='PATCH'){state.parentPayload=body;assert.equal(url.searchParams.get('user_id'),`eq.${userID}`);assert.equal(req.headers()['prefer'],'return=representation');if(state.failProfile)return respond({message:'Fixture profile save failed'},400);return respond([{user_id:userID,...body}]);}return respond([{display_name:'Fixture Parent',neighborhood:'Detroit'}]);}
   if(url.pathname==='/rest/v1/org_members')return respond(state.membership?[{organization_id:orgID}]:[]);
   if(url.pathname==='/rest/v1/rpc/save_organization_profile'){state.orgCalls++;state.orgPayload=body;if(state.failProfile)return respond({message:'Fixture organization save failed'},400);state.membership=true;return respond({id:orgID,...body.profile,verification_status:'pending'});}
   if(url.pathname==='/rest/v1/organizations')return respond([{id:orgID,name:'Fixture Detroit Partners',organization_type:'nonprofit',verification_status:'pending'}]);
   if(url.pathname==='/rest/v1/opportunities')return respond([]);
   throw new Error(`Unexpected fixture path: ${url.pathname}`);
  });
  return {page,state,context,errors};
 }
 async function signup(page){await page.locator('#account-form [name=display_name]').fill('Fixture Guardian');await page.locator('#account-form [name=email]').fill('fixture@example.org');await page.locator('#account-form [name=password]').fill('fixture-only-password');await page.locator('#account-form [name=confirm_password]').fill('fixture-only-password');await page.locator('#account-submit').click();}
 async function signin(page){await page.locator('#account-form [name=email]').fill('fixture@example.org');await page.locator('#account-form [name=password]').fill('fixture-only-password');await page.locator('#account-submit').click();}
 async function screenshot(page,name){await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.screenshot({path:path.join(artifacts,name),fullPage:true});}
 async function noOverflow(page){assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'Horizontal page overflow');}
 const a=await fixture();await a.page.goto(`${base}/signup`);assert(a.page.url().endsWith('/signup/'));await screenshot(a.page,'account-choice-desktop.png');await a.page.getByRole('link',{name:'Parent or guardian',exact:false}).click();await a.page.getByRole('heading',{name:'Create your parent account'}).waitFor();await screenshot(a.page,'parent-signup-desktop.png');
 // Keyboard, password visibility and mismatch prevent API creation.
 await a.page.locator('#account-form [name=password]').fill('fixture-only-password');await a.page.locator('#account-form [name=confirm_password]').fill('different-password');assert(await a.page.locator('#password-error').isVisible());await a.page.locator('#toggle-password').click();assert.equal(await a.page.locator('#password').getAttribute('type'),'text');await a.page.locator('#account-submit').click();assert.equal(a.state.signupCalls,0);
 await signup(a.page);await a.page.locator('#profile-screen').waitFor();assert.deepEqual(a.state.roles,['parent']);assert.deepEqual(a.state.signupPayload.data,{display_name:'Fixture Guardian',full_name:'Fixture Guardian'});assert(!('role' in a.state.signupPayload));
 await a.page.locator('#setup-form [name=display_name]').fill('Fixture Edited Guardian');await a.page.locator('#setup-form [name=neighborhood]').fill('');a.state.failProfile=true;await a.page.locator('#setup-form button[type=submit]').click();await a.page.getByText('Fixture profile save failed',{exact:true}).waitFor();assert.equal(await a.page.locator('#setup-form [name=display_name]').inputValue(),'Fixture Edited Guardian');
 a.state.failProfile=false;await a.page.locator('#setup-form button[type=submit]').click();await a.page.locator('#complete-screen').waitFor();assert.equal(a.state.parentPayload.neighborhood,null);assert.equal(a.state.userPayload.data.full_name,'Fixture Edited Guardian');await screenshot(a.page,'parent-complete-desktop.png');
 await a.page.getByRole('button',{name:'Sign out',exact:true}).click();assert.equal(await a.page.evaluate(()=>sessionStorage.getItem('opportunity313-parent-session')),null);assert.equal(await a.page.evaluate(()=>sessionStorage.getItem('opportunity313-parent-signup-draft')),null);
 const b=await fixture({confirmation:true});await b.page.goto(`${base}/signup/provider/`);await screenshot(b.page,'provider-signup-desktop.png');await signup(b.page);await b.page.locator('#confirmation-screen').waitFor();assert.equal(b.state.claimCalls,0);assert.equal(await b.page.locator('#password').inputValue(),'');assert(await b.page.evaluate(()=>!JSON.stringify(sessionStorage).includes('fixture-only-password')));await screenshot(b.page,'confirmation-desktop.png');
 await b.page.reload();await b.page.locator('#switch-mode').click();await signin(b.page);await b.page.locator('#profile-screen').waitFor();assert.deepEqual(b.state.roles,['provider']);assert.equal(await b.page.locator('#setup-form [name=contact_email]').inputValue(),'fixture@example.org');await b.page.locator('#setup-form [name=name]').fill('Fixture Detroit Organization');await b.page.locator('#setup-form [name=city]').fill('Detroit');await b.page.locator('#setup-form summary').click();await b.page.locator('#setup-form [name=service_area]').fill('Detroit East Side');await screenshot(b.page,'provider-profile-desktop.png');
 // Draft survives a save failure and page reload. Retry uses the same account.
 b.state.failProfile=true;await b.page.locator('#setup-form button[type=submit]').click();await b.page.getByText('Fixture organization save failed',{exact:true}).waitFor();await b.page.reload();await b.page.locator('#profile-screen').waitFor();assert.equal(await b.page.locator('#setup-form [name=name]').inputValue(),'Fixture Detroit Organization');b.state.failProfile=false;await b.page.locator('#setup-form button[type=submit]').click();await b.page.waitForURL(`${base}/provider/`);await b.page.getByText('Fixture Detroit Partners',{exact:true}).first().waitFor();assert.equal(b.state.orgPayload.target_organization_id,null);assert.equal(b.state.orgPayload.profile.service_area,'Detroit East Side');assert(!('verification_status' in b.state.orgPayload.profile));assert.equal(b.state.signupCalls,1);
 // Existing provider skips creation; other roles cannot be converted by the page.
 const c=await fixture({roles:['provider'],membership:true});await c.page.goto(`${base}/signup/provider/?mode=signin`);await signin(c.page);await c.page.waitForURL(`${base}/provider/`);assert.equal(c.state.orgCalls,0);assert.equal(c.state.claimCalls,0);
 const d=await fixture({roles:['parent']});await d.page.goto(`${base}/signup/provider/?mode=signin`);await signin(d.page);await d.page.getByText('This login uses a different account type.',{exact:false}).waitFor();assert.equal(d.state.claimCalls,0);assert.equal(await d.page.evaluate(()=>sessionStorage.getItem('opportunity313-provider-session')),null);
 // Role lookup failure offers retry, without submitting the signup twice.
 const e=await fixture({failRole:true});await e.page.goto(`${base}/signup/parent/`);await signup(e.page);await e.page.locator('#retry-session').waitFor();e.state.failRole=false;await e.page.locator('#retry-session').click();await e.page.locator('#profile-screen').waitFor();assert.equal(e.state.signupCalls,1);assert.equal(e.state.claimCalls,1);
 // Confirmation, resend cooldown, and unconfirmed sign-in path.
 const f=await fixture({confirmation:true});await f.page.goto(`${base}/signup/parent/`);await signup(f.page);await f.page.locator('#confirmation-screen').waitFor();await f.page.locator('#resend-email').click();await f.page.getByText('Confirmation email requested.',{exact:false}).waitFor();assert(await f.page.locator('#resend-email').isDisabled());assert.equal(f.state.resendCalls,1);await f.page.locator('#confirmed-signin').click();f.state.failSignIn=true;await signin(f.page);await f.page.locator('#confirmation-screen').waitFor();assert.equal(f.state.claimCalls,0);
 // Failed signup retains fields; whitespace names never create accounts.
 const g=await fixture({failSignup:true});await g.page.goto(`${base}/signup/parent/`);await signup(g.page);await g.page.getByText('Fixture signup unavailable',{exact:true}).waitFor();assert.equal(await g.page.locator('#account-form [name=display_name]').inputValue(),'Fixture Guardian');assert.equal(await g.page.locator('#password').inputValue(),'fixture-only-password');await g.page.locator('#account-form [name=display_name]').fill('   ');await g.page.locator('#account-submit').click();assert.equal(g.state.signupCalls,1);
 // Restore expired session before using authenticated profile endpoints.
 const h=await fixture({roles:['parent']});await h.page.goto(`${base}/signup/parent/`);await h.page.evaluate(session=>sessionStorage.setItem('opportunity313-parent-session',JSON.stringify({...session,expires_at:1})),session);await h.page.reload();await h.page.locator('#profile-screen').waitFor();assert.equal(h.state.refreshCalls,1);
 const visual=await fixture();
 for(const role of ['parent','provider'])for(const width of [1024,720,390]){await visual.page.setViewportSize({width,height:1000});await visual.page.goto(`${base}/signup/${role}/`);await noOverflow(visual.page);await screenshot(visual.page,`${role}-signup-${width}.png`);}
 await visual.page.goto(`${base}/signup/`);await noOverflow(visual.page);await screenshot(visual.page,'account-choice-mobile.png');
 for(const item of [a,b,c,d,e,f,g,h,visual])assert.deepEqual(item.errors,[]);
 console.log('PASS: account choice, parent/provider signup, password validation, confirmation/resend, verified role onboarding, profile save/draft retry, existing account isolation, provider handoff, parent completion, expired session renewal, responsive layouts. Fixtures only; no live writes.');
 await browser.close();await new Promise(resolve=>server.close(resolve));
})().catch(error=>{console.error(error);server.close();process.exit(1);});
