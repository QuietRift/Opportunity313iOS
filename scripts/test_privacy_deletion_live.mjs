// Run only for a disposable fixture made specifically for the privacy QA workflow.
// This permanently deletes that fixture and its test children, never real accounts.
import {readFileSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const file=process.argv[2],fixture=JSON.parse(readFileSync(file,'utf8'));
assert(fixture.email.endsWith('@privacy-test.invalid'));
const base='https://pinpurdjfbvxrwexzlre.supabase.co';
const key='sb_publishable_SE20ynXjKObWJ7AeOwfw8A_8lSAJ83q';
async function api(path,body,token,method='POST',allowError=false){
 const response=await fetch(base+path,{method,headers:{apikey:key,Authorization:`Bearer ${token??key}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 const data=await response.json().catch(()=>null);
 if(!allowError&&!response.ok)throw new Error(`${path}: HTTP ${response.status}`);
 return {status:response.status,data};
}
const parent=(await api('/auth/v1/token?grant_type=password',{email:fixture.email,password:fixture.password})).data;
assert.equal(parent.user.id,fixture.userID);
async function childSession(id){
 const code=(await api('/functions/v1/child-access',{action:'generate',youthProfileId:id},parent.access_token)).data.code;
 const credentials=(await api('/functions/v1/child-access',{action:'redeem',code})).data;
 return (await api('/auth/v1/token?grant_type=password',credentials)).data;
}
const firstExists=(await api(`/rest/v1/youth_profiles?id=eq.${fixture.childID}&select=id`,null,parent.access_token,'GET')).data.length > 0;
if(firstExists) {
const first=await childSession(fixture.childID);
assert.equal((await api('/functions/v1/child-access',{action:'delete',youthProfileId:fixture.childID},parent.access_token)).data.deleted,true);
assert.deepEqual((await api(`/rest/v1/youth_profiles?id=eq.${fixture.childID}&select=id`,null,parent.access_token,'GET')).data,[]);
assert([401,403].includes((await api('/auth/v1/user',null,first.access_token,'GET',true)).status));
}
const secondID=(await api('/rest/v1/rpc/create_parent_managed_youth',{first_name_input:'Disposable deletion cascade',age_band_input:'9-12',grade_input:4,gender_input:'girl',interests_input:['Arts'],accessibility_preferences_input:[],relationship_input:'parent'},parent.access_token)).data;
fixture.cascadeChildID=secondID;writeFileSync(file,JSON.stringify(fixture),{mode:0o600});
const second=await childSession(secondID);
assert.equal((await api('/functions/v1/delete-account',{confirmation:'DELETE'},parent.access_token)).data.deleted,true);
assert([401,403].includes((await api('/auth/v1/user',null,parent.access_token,'GET',true)).status));
assert([401,403].includes((await api('/auth/v1/user',null,second.access_token,'GET',true)).status));
assert.equal((await api('/rest/v1/youth_profiles?select=id',null,parent.access_token,'GET',true)).status,403);
assert.equal((await fetch(base+'/functions/v1/email-unsubscribe?token='+encodeURIComponent(fixture.unsubscribeToken))).status,400);
fixture.cleanedUp=true;writeFileSync(file,JSON.stringify(fixture),{mode:0o600});
console.log('PASS: deployed permanent child deletion, Auth identity removal, parent hard deletion with sole-child cascade, stale JWT denial, expired unsubscribe capability. Disposable fixture cleaned up; no real accounts or emails.');
