import {readFileSync} from 'node:fs';import {stripTypeScriptTypes} from 'node:module';import vm from 'node:vm';import assert from 'node:assert/strict';
const root=new URL('../supabase/functions/transactional-email/',import.meta.url);
const templates=stripTypeScriptTypes(readFileSync(new URL('templates.ts',root),'utf8').replace('export function','function'));
const context={};vm.runInNewContext(templates+';this.render=emailMessage;',context);
const kinds=['parent_welcome','provider_welcome','child_added','child_access_created','child_access_revoked','submission_pending','submission_approved','submission_rejected','submission_paused','organization_verified'];
for(const kind of kinds){const message=context.render(kind,{title:'<script>bad</script>'},'https://example.org/unsubscribe/?token=fixture');assert(message.subject);assert(message.text);assert(!message.html.includes('<script>'));assert(message.html.includes('href="https://example.org/unsubscribe/?token=fixture"'));assert(message.text.includes('Unsubscribe'));assert(!message.html.includes('O313-'));}
assert.throws(()=>context.render('unknown',{}));
const source=stripTypeScriptTypes(readFileSync(new URL('index.ts',root),'utf8').replace(/^import .*;\n/gm,''));
async function run({auth=true,configured=true,http=200,enabled=true,kind='parent_welcome',pageReady=true}={}){
 const calls=[];let handler;
 const admin={rpc:async(name,body)=>{calls.push([name,body]);if(name==='email_worker_secret')return {data:'fixture-secret'};if(name==='email_delivery_preferences')return {data:{enabled,token:'signed-fixture'}};if(name==='claim_transactional_emails')return {data:[{id:'message',lease_id:'lease',recipient_user_id:'recipient',kind,payload:{}}]};return {data:true};},auth:{admin:{getUserById:async()=>({data:{user:{email:'fixture@example.org',email_confirmed_at:'2026-01-01'}}})}}};
 let sent;
 vm.runInNewContext(source,{emailMessage:context.render,createClient:()=>admin,Deno:{env:{get:name=>name==='RESEND_API_KEY'||name==='EMAIL_FROM'?(configured?'fixture':undefined):name==='EMAIL_PUBLIC_BASE_URL'?'https://example.org':'https://fixture.invalid'},serve:fn=>handler=fn},Response,TextEncoder,crypto,AbortSignal,console,setTimeout:fn=>fn(),fetch:async(url,options)=>{if(url.endsWith('/unsubscribe/'))return new Response(pageReady?'<form id="unsubscribe">':'<h1>Homepage</h1>');sent={url,options};return new Response(JSON.stringify(http===200?{id:'accepted-id'}:{error:'fixture'}),{status:http});}});
 const response=await handler(new Request('https://fixture.invalid',{method:'POST',headers:auth?{'x-email-worker-secret':'fixture-secret'}:{}}));return {status:response.status,calls,sent};
}
let r=await run({auth:false});assert.equal(r.status,401);assert.equal(r.calls.length,0);
r=await run({configured:false});assert.equal(r.status,503);assert(!r.calls.some(c=>c[0]==='claim_transactional_emails'));
for(const [http,result] of [[200,'accepted'],[429,'retry'],[503,'retry'],[422,'failed']]){
 r=await run({http});assert.equal(r.status,200);const finish=r.calls.find(c=>c[0]==='finish_transactional_email')[1];assert.equal(finish.result,result);assert.equal(finish.target_lease,'lease');assert.equal(r.sent.options.headers['Idempotency-Key'],'op313-message');
 assert.deepEqual(JSON.parse(r.sent.options.body).to,['fixture@example.org']);
}
console.log('PASS: 10 templates, escaping/no codes, unknown template, private dispatcher, missing configuration preserves queue, sender acceptance/rate-limit/server failure/validation failure, stable idempotency and lease.');

r=await run({enabled:false});assert.equal(r.status,200);assert.equal(r.sent,undefined);assert.equal(r.calls.find(c=>c[0]==='finish_transactional_email')[1].result,'skipped');
r=await run({enabled:false,kind:'child_access_revoked'});assert(r.sent);assert.deepEqual(JSON.parse(r.sent.options.body).headers,{});
r=await run();const headers=JSON.parse(r.sent.options.body).headers;assert(headers['List-Unsubscribe'].includes('/functions/v1/email-unsubscribe?token='));assert.equal(headers['List-Unsubscribe-Post'],'List-Unsubscribe=One-Click');
console.log('PASS: real footer links, opt-out suppresses queued updates, essential security messages continue, RFC 8058 headers.');

r=await run({pageReady:false});assert.equal(r.status,503);assert(!r.calls.some(c=>c[0]==='claim_transactional_emails'));console.log('PASS: delivery waits for a published, working unsubscribe page before consuming the queue.');
