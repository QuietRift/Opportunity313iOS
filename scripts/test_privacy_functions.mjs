import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source = name => stripTypeScriptTypes(readFileSync(new URL(`../supabase/functions/${name}/index.ts`,import.meta.url),'utf8').replace(/^import .*;\n/gm,''));
async function deletion({auth=true,confirmation='DELETE',apple=false,configured=true,subject='apple-owner',fail=false}={}) {
  let handler;const calls=[];
  const admin={auth:{getUser:async()=>({data:{user:auth?{id:'verified-owner',identities:apple?[{provider:'apple',identity_data:{sub:'apple-owner'}}]:[]}:null}}),admin:{deleteUser:async(id,soft)=>{calls.push(['delete',id,soft]);return {error:fail?new Error('fixture'):null};}}},rpc:async()=>({data:[]})};
  vm.runInNewContext(source('delete-account'),{createClient:()=>admin,Deno:{env:{get:name=>name.startsWith('APPLE_')?configured?(name==='APPLE_CLIENT_ID'?'app.bundle':'fixture-secret'):undefined:'fixture'},serve:fn=>handler=fn},Response,URLSearchParams,AbortSignal,atob,Set,console:{error(){}},fetch:async(url,options)=>{calls.push([url,new URLSearchParams(options.body).get('token_type_hint')]);return new Response(url.endsWith('/token')?JSON.stringify({refresh_token:'fixture-refresh',id_token:'header.'+btoa(JSON.stringify({sub:subject,aud:'app.bundle'}))+'.signature'}):'',{status:200});}});
  const response=await handler(new Request('https://fixture.invalid',{method:'POST',headers:auth?{Authorization:'Bearer fixture'}:{},body:JSON.stringify({confirmation,userID:'someone-else',appleAuthorizationCode:'fixture-code'})}));
  return {status:response.status,calls,body:await response.json()};
}
for(const options of [{auth:false},{confirmation:'no'},{apple:true,configured:false},{apple:true,subject:'different-user'},{fail:true}]){
 const result=await deletion(options);assert.notEqual(result.status,200);assert.notEqual(result.body.deleted,true);
 if(!options.fail)assert(!result.calls.some(c=>c[0]==='delete'));
}
let result=await deletion();assert.deepEqual(result.calls,[['delete','verified-owner',false]]);assert.equal(result.body.deleted,true);
result=await deletion({apple:true});assert.equal(result.status,200);assert(result.calls.some(c=>c[0].endsWith('/revoke')&&c[1]==='refresh_token'));

async function unsubscribe(method,valid=true,body){
 let handler;const calls=[];
 vm.runInNewContext(source('email-unsubscribe'),{createClient:()=>({rpc:async(name,params)=>{calls.push([name,params]);return {data:valid};}}),Deno:{env:{get:()=> 'fixture'},serve:fn=>handler=fn},Response,URL});
 const response=await handler(new Request('https://fixture.invalid?token=fixture',{method,...(body?{body}:{})}));
 return {status:response.status,calls,text:await response.text()};
}
result=await unsubscribe('GET');assert.equal(result.calls[0][1].apply_change,false);assert.equal(result.status,200);
result=await unsubscribe('POST');assert.equal(result.calls[0][1].apply_change,true);assert.equal(result.status,200);
result=await unsubscribe('POST',true,'List-Unsubscribe=One-Click');assert.equal(result.text,'');assert.equal(result.status,200);
assert.equal((await unsubscribe('POST',false)).status,400);
console.log('PASS: verified-owner-only hard deletion, confirmation/auth/failure safeguards, Apple setup/account matching/token revocation, scanner-safe GET, unsubscribe POST and RFC 8058 response. No live users or emails.');
