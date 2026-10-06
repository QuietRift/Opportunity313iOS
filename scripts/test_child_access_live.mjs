// Run only with the disposable, .invalid fixture created for this check.
import {readFileSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const fixture=JSON.parse(readFileSync(process.argv[2],'utf8'));
const root=process.argv[3];
const config=readFileSync(`${root}/website/shared/auth.js`,'utf8');
const key=config.match(/sb_publishable_[A-Za-z0-9_-]+/)?.[0] ?? config.match(/eyJ[A-Za-z0-9_.-]+/)?.[0];
if(!key)throw new Error('Public project key not found');
const base='https://pinpurdjfbvxrwexzlre.supabase.co';
async function api(path,body,token,method='POST',allowError=false){
 const response=await fetch(base+path,{method,headers:{apikey:key,Authorization:`Bearer ${token??key}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 const raw=await response.text(); const data=raw?JSON.parse(raw):null;
 if(!allowError&&!response.ok)throw new Error(`${path}: HTTP ${response.status} ${data.message??data.error??''}`);
 return {status:response.status,data};
}
const parent=(await api('/auth/v1/token?grant_type=password',{email:fixture.email,password:fixture.password})).data;
const token=parent.access_token;
const created=fixture.childID ? {data:fixture.childID} : await api('/rest/v1/rpc/create_parent_managed_youth',{first_name_input:'Disposable code check',age_band_input:'9-12',grade_input:4,gender_input:'girl',interests_input:['Arts'],accessibility_preferences_input:[],relationship_input:'parent'},token);
fixture.childID=created.data;writeFileSync(process.argv[2],JSON.stringify(fixture),{mode:0o600});
const code=(await api('/functions/v1/child-access',{action:'generate',youthProfileId:fixture.childID},token)).data.code;
assert.match(code,/^O313-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/);
const redeemed=(await api('/functions/v1/child-access',{action:'redeem',code})).data;
const child=(await api('/auth/v1/token?grant_type=password',redeemed)).data;
fixture.childUserID=child.user.id;writeFileSync(process.argv[2],JSON.stringify(fixture),{mode:0o600});
let profiles=await api('/rest/v1/youth_profiles?select=id,account_type',null,child.access_token,'GET');
assert.deepEqual(profiles.data.map(x=>x.id),[fixture.childID]);assert.equal(profiles.data[0].account_type,'parent_managed');
let prohibited=await api(`/rest/v1/youth_profiles?id=eq.${fixture.childID}`,{first_name:'Unauthorized rename'},child.access_token,'PATCH',true);assert.equal(prohibited.status,403);
await api(`/rest/v1/youth_profiles?id=eq.${fixture.childID}`,{interests:['Technology']},child.access_token,'PATCH');
const replacement=(await api('/functions/v1/child-access',{action:'generate',youthProfileId:fixture.childID},token)).data.code;
assert.notEqual(code,replacement);assert.equal((await api('/functions/v1/child-access',{action:'redeem',code},null,'POST',true)).status,401);
const revoked=await api('/functions/v1/child-access',{action:'revoke',youthProfileId:fixture.childID},token);assert.equal(revoked.data.revoked,true);
profiles=await api('/rest/v1/youth_profiles?select=id',null,child.access_token,'GET');assert.deepEqual(profiles.data,[]);
assert.equal((await api('/functions/v1/child-access',{action:'redeem',code:replacement},null,'POST',true)).status,401);
const remaining=await api(`/rest/v1/youth_profiles?id=eq.${fixture.childID}&select=id`,null,token,'GET');assert.equal(remaining.data.length,1);
console.log('PASS: live create, generate, redeem, child sign-in, scoped profile, interests-only edit, rotation, old-code rejection, revocation, stale-session denial, parent retains profile. No codes or credentials logged.');
