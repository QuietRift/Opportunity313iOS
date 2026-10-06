import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=readFileSync(process.argv[2] ?? new URL('../supabase/functions/child-access/index.ts', import.meta.url),'utf8').replace(/^import .*;\n/,'');
async function run(options={}) {
  const calls=[]; let handler;
  const profile={id:'child',age_band:'9-12',account_type:options.type??'youth_account',user_id:options.user===undefined?'child-user':options.user};
  if(options.age)profile.age_band=options.age;
  const admin={auth:{admin:{async updateUserById(id,value){calls.push(['ban',id,value]);return {error:options.fail==='ban'?new Error('ban failed'):null};},async createUser(value){calls.push(['createUser',value]);return {data:{user:{id:'new-child-user'}},error:null};},async deleteUser(id){calls.push(['deleteUser',id]);return {error:null};}}},from(table){
    let op='select', value;
    const query={select(){return query},eq(){return query},update(v){op='update';value=v;return query},upsert(v){op='upsert';value=v;return query},delete(){op='delete';return query},single(){return query},maybeSingle(){return query},throwOnError(){return query},then(resolve,reject){
      if(op!=='select')calls.push([op,table,value]);
      if(options.fail===table && op!=='select')return Promise.reject(new Error('write failed')).then(resolve,reject);
      const data=table==='guardian_relationships'?(options.unrelated?null:{id:'relationship'}):table==='youth_profiles'?profile:null;
      return Promise.resolve({data,error:options.fail==='credential-read'&&table==='child_access_credentials'?new Error('read failed'):null}).then(resolve,reject);
    }};return query;
  }};
  const auth={auth:{getUser:async()=>({data:{user:options.badAuth?null:{id:'parent'}},error:null})}};
  vm.runInNewContext(stripTypeScriptTypes(source),{Deno:{env:{get:()=> 'configured'},serve:fn=>handler=fn},createClient:(_u,_k,opts)=>opts.global?auth:admin,Response,TextEncoder,crypto,console:{error(){}},Date});
  const headers=options.noAuth?{}:{Authorization:'Bearer test'};
  const response=await handler(new Request('https://example.test',{method:'POST',headers,body:JSON.stringify({action:options.action??'revoke',youthProfileId:'child'})}));
  return {status:response.status,body:await response.json(),calls};
}
for(const type of ['youth_account','parent_managed']){
 const r=await run({type});assert.equal(r.status,200);assert.equal(r.body.revoked,true);
 assert(r.calls.some(c=>c[0]==='ban'&&c[1]==='child-user'));
 assert(r.calls.some(c=>c[0]==='update'&&c[1]==='youth_profiles'&&c[2].user_id===null&&c[2].account_type==='parent_managed'));
 assert.equal(r.calls.some(c=>c[0]==='deleteUser'),type==='parent_managed');
 assert(!r.calls.some(c=>c[0]==='delete'&&['youth_profiles','guardian_relationships','opportunity_saves'].includes(c[1])));
}
for(const [options,status] of [[{noAuth:true},401],[{badAuth:true},401],[{unrelated:true},403],[{age:'18-24'},400],[{age:'unknown'},400],[{user:'parent'},400],[{action:'generate'},400],[{action:'other'},400]]){
 const r=await run(options);assert.equal(r.status,status);assert.equal(r.calls.length,0);
}
for(const fail of ['ban','credential-read','child_access_credentials','user_roles','youth_profiles']){
 const r=await run({fail});assert.equal(r.status,500);assert.notEqual(r.body.revoked,true);
}
const repeat=await run({type:'parent_managed',user:null});assert.equal(repeat.status,200);assert(!repeat.calls.some(c=>c[0]==='ban'));
for (const user of [null,'child-user']) {
 const r=await run({type:'parent_managed',user,action:'generate'});
 assert.equal(r.status,200);assert.match(r.body.code,/^O313-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/);
 const saved=r.calls.find(c=>c[0]==='upsert'&&c[1]==='child_access_credentials')[2];
 assert.equal(saved.code_hash.length,64);assert(!JSON.stringify(saved).includes(r.body.code));assert.equal(saved.expires_at,r.body.expiresAt);
}
for (const fail of ['youth_profiles','user_roles','child_access_credentials']) {
 const r=await run({type:'parent_managed',user:null,action:'generate',fail});assert.equal(r.status,500);assert.equal(r.body.code,undefined);
 assert.equal(r.calls.some(c=>c[0]==='deleteUser'),fail==='youth_profiles');
}
console.log('21 child-access regression cases passed, including generation, hashed storage, and failed-write handling.');
