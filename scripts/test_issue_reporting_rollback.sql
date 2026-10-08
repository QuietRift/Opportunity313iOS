begin;
create temporary table issue_fixture as select
 (select user_id from public.user_roles where role='parent' limit 1) parent_id,
 (select user_id from public.user_roles where role='youth' limit 1) child_id,
 (select user_id from public.user_roles where role='provider' limit 1) provider_id,
 (select user_id from public.user_roles where role='admin' limit 1) admin_id,
 (select id from public.opportunities where status='published' limit 1) opportunity_id,
 gen_random_uuid() report_id,gen_random_uuid() child_report_id,gen_random_uuid() hidden_opportunity_id;
grant select on issue_fixture to authenticated;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'FAILED: %',message; end if; end $$;
select pg_temp.assert_true((select parent_id is not null and child_id is not null and admin_id is not null and provider_id is not null and opportunity_id is not null from issue_fixture),'Required role fixtures exist');
insert into public.opportunities select (jsonb_populate_record(null::public.opportunities,to_jsonb(o)||jsonb_build_object('id',f.hidden_opportunity_id,'title','Issue rollback hidden fixture','status','pending_review','is_demo',true))).* from public.opportunities o cross join issue_fixture f where o.id=f.opportunity_id;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from issue_fixture),true);
do $$ declare f record; report jsonb; retry jsonb;
begin
 select * into f from issue_fixture;
 begin
  perform public.native_submit_issue_report(gen_random_uuid(),'other','x','too short','ios');
  raise exception 'FAILED: Invalid report accepted';
 exception when raise_exception then if sqlerrm like 'FAILED:%' then raise; end if; end;
 begin
  perform public.native_submit_issue_report(gen_random_uuid(),'opportunity','Hidden opportunity','Should not reveal a draft title','ios',f.hidden_opportunity_id);
  raise exception 'FAILED: Hidden opportunity accepted';
 exception when raise_exception then if sqlerrm like 'FAILED:%' then raise; end if; perform pg_temp.assert_true(sqlerrm='Opportunity unavailable. Submit a general report instead','Hidden opportunity denied'); end;
 report:=public.native_submit_issue_report(f.report_id,'registration',' Ticket problem ',' QR code does not load when I open my ticket. ','ios',f.opportunity_id,'1.0 (1)');
 retry:=public.native_submit_issue_report(f.report_id,'registration','Ticket problem','QR code does not load when I open my ticket.','ios',f.opportunity_id,'1.0 (1)');
 perform pg_temp.assert_true(report->>'id'=retry->>'id','Retry preserves report ID');
 perform pg_temp.assert_true(report->>'status'='submitted' and report->>'title'='Ticket problem','Submitted status and trimmed input');
 perform pg_temp.assert_true((select count(*)=1 from public.issue_reports where id=f.report_id),'Owner can read submitted report');
 begin
  update public.issue_reports set status='resolved' where id=f.report_id;
  raise exception 'FAILED: Reporter directly changed status';
 exception when insufficient_privilege then null; end;
 begin
  perform public.native_review_issue_report(f.report_id,'resolved','Looks fixed',1);
  raise exception 'FAILED: Reporter reviewed own report';
 exception when raise_exception then if sqlerrm like 'FAILED:%' then raise; end if; perform pg_temp.assert_true(sqlerrm='Administrator access required','Non-admin review denied'); end;
end $$;
select set_config('request.jwt.claim.sub',(select child_id::text from issue_fixture),true);
select pg_temp.assert_true((select count(*)=0 from public.issue_reports where id=(select report_id from issue_fixture)),'Child cannot read parent report');
select public.native_submit_issue_report(child_report_id,'app','Child fixture issue','The saved page will not load on this device.','ios')->>'status' from issue_fixture;
do $$ declare f record;
begin
 select * into f from issue_fixture;
 begin
  perform public.native_submit_issue_report(f.report_id,'app','Collision attempt','Cannot claim another user request identifier.','ios');
  raise exception 'FAILED: Request ID collision returned another report';
 exception when raise_exception then if sqlerrm like 'FAILED:%' then raise; end if; perform pg_temp.assert_true(sqlerrm='Invalid report request','Cross-account retry denied'); end;
end $$;
select set_config('request.jwt.claim.sub',(select provider_id::text from issue_fixture),true);
select pg_temp.assert_true((select count(*)=0 from public.issue_reports where id in (select report_id from issue_fixture union select child_report_id from issue_fixture)),'Provider cannot see family reports');
select set_config('request.jwt.claim.sub',(select admin_id::text from issue_fixture),true);
do $$ declare f record; first_review jsonb; resolved jsonb; retry jsonb;
begin
 select * into f from issue_fixture;
 perform pg_temp.assert_true((select count(*)=2 from public.issue_reports where id in(f.report_id,f.child_report_id)),'Admin sees all reporters');
 first_review:=public.native_review_issue_report(f.report_id,'in_review','We are looking into the ticket display.',1);
 perform pg_temp.assert_true(first_review->>'version'='2','Review increments version');
 begin
  perform public.native_review_issue_report(f.report_id,'resolved','',2);
  raise exception 'FAILED: Empty resolution accepted';
 exception when raise_exception then if sqlerrm like 'FAILED:%' then raise; end if; perform pg_temp.assert_true(sqlerrm='Add a response explaining the resolution','Resolution explanation required'); end;
 begin
  perform public.native_review_issue_report(f.report_id,'resolved','This stale update should fail.',1);
  raise exception 'FAILED: Stale review overwrote new review';
 exception when raise_exception then if sqlerrm like 'FAILED:%' then raise; end if; perform pg_temp.assert_true(sqlerrm='This report changed. Refresh before saving','Stale review rejected'); end;
 resolved:=public.native_review_issue_report(f.report_id,'resolved','The ticket display is fixed. Please reopen My Tickets.',2);
 retry:=public.native_review_issue_report(f.report_id,'resolved','The ticket display is fixed. Please reopen My Tickets.',2);
 perform pg_temp.assert_true(resolved->>'version'='3' and resolved=retry,'Review retry idempotent');
end $$;
select set_config('request.jwt.claim.sub',(select parent_id::text from issue_fixture),true);
select pg_temp.assert_true((select status='resolved' and response like 'The ticket display%' from public.issue_reports where id=(select report_id from issue_fixture)),'Owner can read admin response');
select pg_temp.assert_true((select count(*)=0 from public.issue_reports where id=(select child_report_id from issue_fixture)),'Parent cannot read child private report');
do $$ declare counter integer;
begin
 for counter in 1..4 loop
  perform public.native_submit_issue_report(gen_random_uuid(),'other','Rate limit fixture','A separate rolled-back test report.','web');
 end loop;
 begin
  perform public.native_submit_issue_report(gen_random_uuid(),'other','Sixth fixture report','This must be denied by the rate limit.','web');
  raise exception 'FAILED: Rate limit bypassed';
 exception when raise_exception then if sqlerrm like 'FAILED:%' then raise; end if; perform pg_temp.assert_true(sqlerrm like 'You have sent several reports.%','Rate limit enforced'); end;
 -- Successful-response retries remain safe even at the rate limit.
 perform public.native_submit_issue_report((select report_id from issue_fixture),'registration','Ticket problem','QR code does not load when I open my ticket.','ios');
end $$;
reset role;
select pg_temp.assert_true((select count(*)=2 from private.issue_report_actions where report_id=(select report_id from issue_fixture)),'Two review actions audited without duplicate retry');
select pg_temp.assert_true(not has_function_privilege('anon','public.native_submit_issue_report(uuid,text,text,text,text,uuid,text)','execute'),'Anonymous submissions denied');
select pg_temp.assert_true(not has_table_privilege('authenticated','public.issue_reports','insert'),'Cannot insert forged reporter or status');
select 'PASS: issue submission, validation, retry, owner/child/provider isolation, admin reviews, resolution, stale conflict, audit, rate limit, anonymous and direct-write denial' result;
rollback;
