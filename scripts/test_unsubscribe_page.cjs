// Local browser fixtures; no live email or preference writes.
const {chromium}=require('playwright');
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../website');
const artifacts=process.env.PRIVACY_TEST_ARTIFACTS||'/private/tmp/op313-privacy-browser';fs.mkdirSync(artifacts,{recursive:true});
const server=http.createServer((req,res)=>{const pathname=new URL(req.url,'http://localhost').pathname;const file=path.resolve(root,'.'+pathname+(pathname.endsWith('/')?'index.html':''));if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}try{res.setHeader('Content-Type',file.endsWith('.js')?'application/javascript':file.endsWith('.css')?'text/css':'text/html');res.end(fs.readFileSync(file));}catch{res.writeHead(404);res.end();}});
(async()=>{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,executablePath:process.env.PROVIDER_TEST_BROWSER||undefined});
 try {
  for(const width of [390,1440]){
   const page=await browser.newPage({viewport:{width,height:900}});let posts=0,valid=true,fail=false;
   await page.route('https://pinpurdjfbvxrwexzlre.supabase.co/**',async route=>{const method=route.request().method();if(method==='POST')posts++;await route.fulfill({status:!valid?400:fail?503:200,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(!valid?{error:'Invalid'}:method==='POST'?{unsubscribed:true}:{valid:true})});});
   await page.goto(`http://127.0.0.1:${server.address().port}/unsubscribe/?token=fixture`);
   await page.getByRole('button',{name:'Unsubscribe from optional emails'}).waitFor();assert.equal(posts,0);assert(!page.url().includes('token='));
   assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
   await page.screenshot({path:path.join(artifacts,`unsubscribe-${width}.png`),fullPage:true});
   fail=true;await page.getByRole('button',{name:'Unsubscribe from optional emails'}).click();await page.getByText('We couldn’t unsubscribe you. Please try again.').waitFor();
   fail=false;await page.getByRole('button',{name:'Unsubscribe from optional emails'}).click();await page.getByText('You’re unsubscribed from optional Opportunity313 emails.',{exact:false}).waitFor();assert.equal(posts,2);
   valid=false;await page.goto(`http://127.0.0.1:${server.address().port}/unsubscribe/?token=invalid`);await page.getByText('This link is invalid or the account has been deleted.',{exact:false}).waitFor();assert.equal(await page.locator('#unsubscribe').isVisible(),false);
   await page.goto(`http://127.0.0.1:${server.address().port}/unsubscribe/`);await page.getByText('Open the unsubscribe link in an Opportunity313 email',{exact:false}).waitFor();
   await page.close();
  }
  console.log('PASS: phone/desktop layouts, no unsubscribe on GET, token removed from URL, explicit opt-out, retryable failure, success, invalid/missing links.');
 }finally{await browser.close();server.close();}
})().catch(error=>{console.error(error);server.close();process.exitCode=1;});
