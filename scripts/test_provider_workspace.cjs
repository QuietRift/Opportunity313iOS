// Requires Playwright. Tests use local fixtures; no real sign-ins or backend writes.
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = process.env.PROVIDER_WEB_ROOT || path.resolve(__dirname, '../website');
const artifacts = process.env.PROVIDER_TEST_ARTIFACTS || path.join(require('node:os').tmpdir(), 'opportunity313-provider-tests');
fs.mkdirSync(artifacts, {recursive:true});
const userID = '00000000-0000-0000-0000-000000000001';
const orgID = '00000000-0000-0000-0000-000000000002';
const organization = {id:orgID,name:'Fixture Detroit Learning',organization_type:'nonprofit',description:'Fixture organization',contact_name:'Fixture contact',contact_email:'fixture@example.org',contact_phone:'313-555-0100',website:'https://example.org',service_area:'Detroit',address:'',city:'Detroit',verification_status:'pending'};
const items = [
 {id:'fixture-1',title:'Pending fixture',category:'Arts',summary:'Pending description',status:'pending_review',verification_status:'pending',created_at:'2026-10-01T12:00:00Z',is_free:true},
 {id:'fixture-2',registration_method:'in_app',title:'Approved fixture',category:'Sports',summary:'Approved description',status:'published',verification_status:'verified',created_at:'2026-10-01T12:00:00Z',is_free:true},
 {id:'fixture-3',title:'Rejected fixture',category:'Technology',summary:'Rejected description',status:'closed',verification_status:'rejected',created_at:'2026-10-01T12:00:00Z',is_free:true}
];
const server=http.createServer((req,res)=>{
 const url = new URL(req.url,'http://localhost');
 if(url.pathname==='/provider'){res.writeHead(301,{Location:'/provider/'});res.end();return;}
 const relative=url.pathname==='/provider/'?'provider/index.html':url.pathname.slice(1);
 const filename=path.resolve(root,relative);
 if(!filename.startsWith(path.resolve(root)+path.sep)){res.writeHead(403);res.end();return;}
 try { const body=fs.readFileSync(filename);res.setHeader('Content-Type',filename.endsWith('.css')?'text/css':filename.endsWith('.js')?'application/javascript':'text/html');res.end(body);}
 catch{res.writeHead(404);res.end();}
});
(async()=>{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base=`http://127.0.0.1:${server.address().port}`;
 const browser=await chromium.launch({headless:true, executablePath:process.env.PROVIDER_TEST_BROWSER || undefined});
 const context=await browser.newContext({viewport:{width:1440,height:1000},timezoneId:'America/Los_Angeles'});
 const page=await context.newPage();
 const errors=[];page.on('pageerror',error=>errors.push(error.message));
 let issueReports=[], reportPayloads=[], failReportOnce=true;
 let publishedUpdates=0, updatePayload, attended=false;
 let org={...organization},rows=items.map(item=>({...item})),profilePayload,opportunityPayload,failProfile=false,failList=false,role='provider',hasMembership=true,refreshes=0,signupConfirmation=false,logouts=0;
 const fulfill=(route,body,status=200)=>route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});
 await page.route('https://pinpurdjfbvxrwexzlre.supabase.co/**',async(route)=>{
  const request=route.request(),url=new URL(request.url()),body=request.postDataJSON();
  if(url.pathname==='/rest/v1/issue_reports'){assert.equal(url.searchParams.get('reporter_id'),`eq.${userID}`);return fulfill(route,issueReports);}
  if(url.pathname==='/rest/v1/rpc/native_submit_issue_report'){
   reportPayloads.push(body);
   const report={id:body.request_id_input,title:body.title_input,details:body.details_input,category:body.category_input,opportunity_name:'Approved fixture',status:'submitted',response:'',created_at:'2026-10-08T04:00:00Z'};
   if(!issueReports.some(r=>r.id===report.id))issueReports.push(report);
   if(failReportOnce){failReportOnce=false;return fulfill(route,{message:'Fixture network failure. Retry your report.'},503);}
   return fulfill(route,report);
  }
  if(url.pathname==='/rest/v1/rpc/native_opportunity_attendees')return fulfill(route,{registered_count:1,attended_count:attended?1:0,cancelled_count:0,remaining:9,attendees:[{id:'attendee-fixture',attendee_name:'Fixture Child <script>',status:attended?'used':'upcoming'}]});
  if(url.pathname==='/rest/v1/rpc/native_mark_opportunity_attendance'){assert.equal(body.registration_id_input,'attendee-fixture');attended=true;return fulfill(route,null);}
  if(url.pathname==='/rest/v1/rpc/native_publish_opportunity_update'){publishedUpdates++;updatePayload=body;return fulfill(route,2);}
  if(url.pathname==='/auth/v1/token'){if(url.search.includes('refresh_token'))refreshes++;return fulfill(route,{access_token:'fixture-token',refresh_token:'fixture-refresh',expires_in:3600,user:{id:userID,email:'fixture@example.org'}});}
  if(url.pathname==='/auth/v1/signup')return fulfill(route,signupConfirmation?{user:{id:userID}}:{access_token:'fixture-token',refresh_token:'fixture-refresh',expires_in:3600});
  if(url.pathname==='/auth/v1/resend')return fulfill(route,{});
  if(url.pathname==='/auth/v1/user')return fulfill(route,{id:userID,email:'fixture@example.org'});
  if(url.pathname==='/auth/v1/logout'){assert.equal(url.searchParams.get('scope'),'local');logouts++;return fulfill(route,{});}
  if(url.pathname==='/rest/v1/user_roles')return fulfill(route,role?[{role}]:[]);
  if(url.pathname==='/rest/v1/rpc/claim_onboarding_role'){assert.equal(body.requested_role,'provider');role='provider';return fulfill(route,'provider');}
  if(url.pathname==='/rest/v1/org_members')return fulfill(route,hasMembership?[{organization_id:orgID}]:[]);
  if(url.pathname==='/rest/v1/organizations')return fulfill(route,[org]);
  if(url.pathname==='/rest/v1/rpc/save_organization_profile'){
   profilePayload=body;if(failProfile)return fulfill(route,{message:'Fixture save failed. Try again.'},400);
   assert.equal(body.target_organization_id,hasMembership?orgID:null);
   org={...org,...body.profile};hasMembership=true;return fulfill(route,[org]);
  }
  if(url.pathname==='/rest/v1/opportunities'){
   if(request.method()==='POST'){opportunityPayload=body;rows.unshift({...body,id:'submitted-fixture',created_at:'2026-10-06T12:00:00Z',verification_status:'pending'});return fulfill(route,{});}
   if(failList)return fulfill(route,{message:'Fixture list unavailable'},500);
   const offset=Number(url.searchParams.get('offset')||0),limit=Number(url.searchParams.get('limit')||200);return fulfill(route,rows.slice(offset,offset+limit));
  }
  throw new Error(`Unexpected fixture API path: ${url.pathname}`);
 });
 async function clickView(label){await page.getByRole('navigation',{name:'Workspace sections'}).getByRole('button',{name:label,exact:true}).click();}
 async function signIn(){await page.locator('#account-action').click();await page.locator('#auth-form [name=email]').fill('fixture@example.org');await page.locator('#auth-form [name=password]').fill('fixture-only-password');await page.locator('#auth-submit').click();await page.waitForFunction(()=>!document.querySelector('#auth-dialog').open);}
 async function noOverflow(){assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'Unexpected page overflow');}
 await page.goto(`${base}/provider`);assert(page.url().includes('/provider/'));
 await page.getByText('Sample workspace',{exact:true}).first().waitFor();await noOverflow();
 await page.screenshot({path:path.join(artifacts,'desktop-dashboard.png'),fullPage:true});
 await clickView('Organization profile');assert(await page.locator('#profile-form [name=name]').isDisabled());
 await page.screenshot({path:path.join(artifacts,'desktop-profile.png'),fullPage:true});
 await clickView('Dashboard');
 for(const width of [1024,720,390]){await page.setViewportSize({width,height:1000});await noOverflow();await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.screenshot({path:path.join(artifacts,`dashboard-${width}.png`),fullPage:true});}
 await page.setViewportSize({width:1440,height:1000});
 await signIn();assert(await page.locator('#preview-banner').isHidden());assert.equal(await page.locator('#stat-rejected').textContent(),'1');
 await page.setViewportSize({width:390,height:1000});await noOverflow();
 await page.getByRole('button',{name:'Report an issue',exact:true}).click();
 await noOverflow();assert(await page.locator('#support-dialog').evaluate(dialog=>dialog.scrollWidth<=dialog.clientWidth+1),'Issue dialog overflow');
 await page.screenshot({path:path.join(artifacts,'provider-issue-mobile.png'),fullPage:true});
 await page.setViewportSize({width:1440,height:1000});
 await page.getByText('You haven’t submitted any reports yet.',{exact:true}).waitFor();
 const support=page.locator('#support-form');
 await support.locator('[name=category]').selectOption('registration');
 await support.locator('[name=opportunity_id]').selectOption('fixture-2');
 await support.locator('[name=title]').fill('Fixture ticket issue');
 await support.locator('[name=details]').fill('The ticket page shows <script> text and will not load.');
 await support.getByRole('button',{name:'Submit report',exact:true}).click();
 await page.getByText('Fixture network failure. Retry your report.',{exact:true}).waitFor();
 assert.equal(await support.locator('[name=title]').inputValue(),'Fixture ticket issue');
 await support.getByRole('button',{name:'Submit report',exact:true}).click();
 await page.locator('#support-reports h4').getByText('Fixture ticket issue',{exact:true}).waitFor();
 assert.equal(reportPayloads.length,2);assert.equal(reportPayloads[0].request_id_input,reportPayloads[1].request_id_input);assert.equal(issueReports.length,1);assert.equal(reportPayloads[1].opportunity_id_input,'fixture-2');assert.equal(reportPayloads[1].platform_input,'web');
 assert.equal(await page.locator('#support-reports .report-text').textContent(),'The ticket page shows <script> text and will not load.');
 issueReports[0].status='resolved';issueReports[0].response='The ticket problem is fixed. Please try again.';
 await page.getByRole('button',{name:'Refresh reports',exact:true}).click();
 await page.getByText('The ticket problem is fixed. Please try again.',{exact:true}).waitFor();
 await page.screenshot({path:path.join(artifacts,'provider-issue-report.png'),fullPage:true});
 await page.keyboard.press('Escape');
 await page.locator('[data-status=rejected]').click();assert.equal(await page.locator('#opportunity-rows tr').count(),1);
 await page.locator('#opportunity-rows').getByRole('button',{name:'Rejected fixture',exact:true}).click();assert.equal(await page.locator('#detail-status').textContent(),'Rejected');
 await page.keyboard.press('Escape');assert(!(await page.locator('#detail-dialog').evaluate(dialog=>dialog.open)));
 await page.locator('#opportunity-search').fill('no fixture matches');assert(await page.getByRole('heading',{name:'No matching submissions'}).isVisible());await page.locator('#opportunity-search').fill('');
 await page.locator('.filter[data-filter=all]').click();
 await page.locator('#opportunity-rows').getByRole('button',{name:'Approved fixture',exact:true}).click();
 await page.getByText('1 registered · 0 attended · 0 cancelled · 9 spots remaining',{exact:true}).waitFor();
 assert.equal(await page.locator('#roster-list strong').textContent(),'Fixture Child <script>');
 page.on('dialog',dialog=>dialog.accept());
 await page.getByRole('button',{name:'Mark attended',exact:true}).click();
 await page.getByText('1 registered · 1 attended · 0 cancelled · 9 spots remaining',{exact:true}).waitFor();
 await page.locator('#update-form [name=title]').fill('Location reminder');
 await page.locator('#update-form [name=body]').fill('Use the north entrance.');
 await page.locator('#update-form button[type=submit]').click();
 await page.getByText('Update delivered to 2 registered attendee and parent accounts.',{exact:true}).waitFor();
 assert.equal(publishedUpdates,1);assert.equal(updatePayload.opportunity_id_input,'fixture-2');assert.equal(updatePayload.body_input,'Use the north entrance.');
 await page.screenshot({path:path.join(artifacts,'provider-attendee-updates.png'),fullPage:true});
 await page.keyboard.press('Escape');
 await clickView('Organization profile');
 await page.locator('#profile-form [name=name]').fill('Edited Fixture Organization');await page.locator('#profile-form [name=contact_email]').fill('');
 failProfile=true;await page.locator('#profile-save').click();await page.locator('#profile-error').waitFor();assert.equal(await page.locator('#profile-form [name=name]').inputValue(),'Edited Fixture Organization');
 failProfile=false;await page.locator('#profile-save').click();await page.getByText('Organization profile saved.',{exact:true}).waitFor();
 assert.equal(profilePayload.profile.contact_email,'');assert(!('verification_status' in profilePayload.profile));assert(!('id' in profilePayload.profile));assert.equal(await page.locator('#org-name').textContent(),'Edited Fixture Organization');
 await page.locator('#profile-form [name=city]').fill('Unsaved Detroit edit');await page.locator('#refresh-workspace').click();await page.getByText('Workspace updated.',{exact:true}).waitFor();assert.equal(await page.locator('#profile-form [name=city]').inputValue(),'Unsaved Detroit edit');await page.locator('#profile-reset').click();
 await clickView('Dashboard');await page.locator('#view-overview .create-button').click();
 const editor=page.locator('#opportunity-form');
 await editor.locator('[name=title]').fill('New fixture submission');await editor.locator('[name=summary]').fill('Fixture submission details');await editor.locator('[name=starts_at]').fill('2026-11-10T10:00');await editor.locator('[name=location_name]').fill('Fixture center');await editor.locator('[name=in_app]').check();assert(await editor.locator('[name=registration_url]').isDisabled());await editor.getByRole('button',{name:'Submit for review'}).click();
 await page.getByText('Opportunity submitted. It is pending admin review.',{exact:true}).waitFor();assert.equal(opportunityPayload.registration_method,'in_app');assert.equal(opportunityPayload.registration_url,null);assert.equal(opportunityPayload.status,'pending_review');assert.equal(opportunityPayload.organization_id,orgID);assert.equal(opportunityPayload.created_by,userID);assert.equal(opportunityPayload.starts_at,'2026-11-10T15:00:00.000Z');
 // A failed refresh is visible, recoverable, and does not turn real records into sample data.
 failList=true;await page.locator('#refresh-workspace').click();await page.locator('#workspace-error').waitFor();assert(await page.locator('#preview-banner').isHidden());failList=false;await page.locator('#retry-workspace').click();await page.getByText('Workspace updated.',{exact:true}).waitFor();
 // Session refresh is shared across concurrent requests.
 await page.evaluate(()=>{const key='opportunity313-provider-session';const session=JSON.parse(sessionStorage.getItem(key));session.expires_at=0;sessionStorage.setItem(key,JSON.stringify(session));});await page.reload();await page.waitForFunction(()=>document.querySelector('#account-action').textContent==='Sign out'&&!document.querySelector('#refresh-workspace').disabled);assert.equal(refreshes,1);
 // Fetch all pages rather than truncating the dashboard at an API limit.
 rows=Array.from({length:205},(_,i)=>({...items[0],id:`pagination-${i}`,title:`Fixture opportunity ${i}`}));await page.locator('#refresh-workspace').click();await page.waitForFunction(()=>document.querySelector('#filter-all').textContent==='205');
 // Sign-out clears profile drafts and submission values. Other roles cannot use this workspace.
 await page.locator('#account-action').click();await page.getByText('You’ve signed out.',{exact:true}).waitFor();role='parent';await page.locator('#account-action').click();await page.locator('#auth-form [name=email]').fill('fixture@example.org');await page.locator('#auth-form [name=password]').fill('fixture-only-password');await page.locator('#auth-submit').click();await page.getByText('Use an Organization account for this workspace.',{exact:false}).waitFor();assert(await page.locator('#auth-dialog').evaluate(dialog=>dialog.open));await page.keyboard.press('Escape');
 // New accounts without roles complete onboarding with the same atomic profile RPC as iOS.
 role=null;hasMembership=false;await signIn();await page.getByRole('heading',{name:'Organization profile',exact:true}).waitFor();await page.locator('#profile-form [name=name]').fill('New Fixture Organization');await page.locator('#profile-form [name=city]').fill('Detroit');await page.locator('#profile-save').click();await page.getByText('Organization profile saved.',{exact:true}).waitFor();assert.equal(profilePayload.target_organization_id,null);
 // The workspace now links to the dedicated provider signup screen.
 await page.locator('#account-action').click();await page.locator('#account-action').click();assert.equal(await page.locator('#tab-signup').getAttribute('href'),'/signup/provider/');await page.keyboard.press('Escape');
 await page.setViewportSize({width:390,height:900});await clickView('Organization profile');await noOverflow();await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.screenshot({path:path.join(artifacts,'mobile-profile.png'),fullPage:true});
 assert.deepEqual(errors,[]);assert(logouts>=2,'Provider signout must revoke the local session');
 console.log('PASS: responsive preview, login, account isolation, editable profile/clear/error retention, approval filters/details, submission review status and Detroit timezone, recoverable refresh, session renewal, pagination, atomic onboarding, dedicated signup entry link. Issue form retry/draft retention, private history, response, linked opportunity and escaped text also passed. Fixtures only; no live writes.');
 await browser.close();await new Promise(resolve=>server.close(resolve));
})().catch(error=>{console.error(error);server.close();process.exit(1);});
