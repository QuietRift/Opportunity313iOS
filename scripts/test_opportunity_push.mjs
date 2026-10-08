import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const root = new URL('../supabase/functions/opportunity-push/', import.meta.url);
const messageSource = stripTypeScriptTypes(readFileSync(new URL('message.ts',root),'utf8').replace(/export /g,''));
const messageContext = {Date,TextEncoder,crypto,atob,btoa,AbortSignal,URLSearchParams,fetch:async()=>new Response(JSON.stringify({access_token:'fixture-token'}))};
vm.runInNewContext(messageSource+';this.render=pushMessage;this.token=firebaseAccessToken;', messageContext);
const payload = messageContext.render('public-opportunity','event');
assert.equal(payload.message.topic,'published_opportunities');
assert.equal(payload.message.android.notification.channel_id,'new_opportunities');
assert.equal(payload.message.apns.headers['apns-push-type'],'alert');
assert.equal(payload.message.data.opportunity_id,'public-opportunity');
assert(!JSON.stringify(payload).includes('child'));
const pair=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',hash:'SHA-256',modulusLength:2048,publicExponent:new Uint8Array([1,0,1])},true,['sign','verify']);
const pem=Buffer.from(await crypto.subtle.exportKey('pkcs8',pair.privateKey)).toString('base64');
assert.equal(await messageContext.token({client_email:'fixture@example.invalid',private_key:`-----BEGIN PRIVATE KEY-----\n${pem}\n-----END PRIVATE KEY-----`}), 'fixture-token');
const source=stripTypeScriptTypes(readFileSync(new URL('index.ts',root),'utf8').replace(/^import .*;\n/gm,''));
async function run({auth='valid',configured=true,http=200,publication='published',demo=false,expired=false,old=false,registration=false}={}) {
    const calls=[];let handler,sent;
    const admin={rpc:async(name,body)=>{calls.push([name,body]);if(name==='claim_registration_push_events')return {data:registration?[{id:'registration-event',lease_id:'registration-lease',token:'private-device-token',notification_id:'private-update',opportunity_id:'registered-opportunity'}]:[]};if(name==='push_worker_secret')return {data:'fixture-secret'};if(name==='claim_opportunity_push_events')return {data:[{id:'event',opportunity_id:'opportunity',lease_id:'lease',created_at:new Date(Date.now()-(old?90000000:0)).toISOString()}]};return {data:true};},from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:{status:publication,is_demo:demo,deadline:expired?'2020-01-01':null}})})})})};
    vm.runInNewContext(source,{pushMessage:messageContext.render,firebaseAccessToken:async()=> 'fixture-token',createClient:()=>admin,Deno:{env:{get:name=> name==='FIREBASE_SERVICE_ACCOUNT_JSON'?(configured?JSON.stringify({project_id:'fixture',client_email:'fixture',private_key:'fixture'}):undefined):'fixture'},serve:fn=>handler=fn},Response,TextEncoder,crypto,AbortSignal,console,Date,fetch:async(url,options)=>{sent={url,options};return new Response(JSON.stringify(http===200?{name:'accepted-name'}:{error:'fixture'}),{status:http});}});
    const response=await handler(new Request('https://fixture.invalid',{method:'POST',headers:auth==='missing'?{}:{'x-push-worker-secret':auth==='valid'?'fixture-secret':'wrong'}}));
    return {status:response.status,calls,sent};
}
for (const auth of ['missing','wrong']) {const r=await run({auth});assert.equal(r.status,401);assert(!r.calls.some(([n])=>n==='claim_opportunity_push_events'));}
let r=await run({configured:false});assert.equal(r.status,503);assert(!r.calls.some(([n])=>n==='claim_opportunity_push_events'));
for(const [http,result] of [[200,'accepted'],[429,'retry'],[503,'retry'],[400,'failed']]) {r=await run({http});assert.equal(r.status,200);const finish=r.calls.find(([n])=>n==='finish_opportunity_push_event')[1];assert.equal(finish.result,result);assert.equal(finish.target_lease,'lease');}
for(const options of [{publication:'pending_review'},{publication:'rejected'},{demo:true},{expired:true},{old:true}]) {r=await run(options);assert(!r.sent);assert.equal(r.calls.find(([n])=>n==='finish_opportunity_push_event')[1].result,'skipped');}
for (const [http,success,permanent] of [[200,true,false],[429,false,false],[503,false,false],[400,false,true]]) {
 r=await run({registration:true,http});assert.equal(r.status,200);
 const finish=r.calls.find(([n])=>n==='finish_registration_push_event')[1];assert.equal(finish.success,success);assert.equal(finish.permanent_failure,permanent);
 const message=JSON.parse(r.sent.options.body).message;assert.equal(message.token,'private-device-token');assert.equal(message.data.registration_update_id,'private-update');assert(!('topic' in message));assert(!JSON.stringify(message.notification).includes('private'));
}
console.log('PASS: targeted registration token dispatch, generic private lock-screen text, registration retry/permanent failures,  both platform payloads, real RSA credential signing fixture, private dispatch, missing setup preserves queue, accepted/retry/permanent errors, publication/demo/deadline/age suppression. No messages sent.');
