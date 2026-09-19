begin;
-- Run within a transaction after the migration; all fixture changes roll back.
create temporary table ticket_test_context as
 select (select user_id from public.user_roles where role='parent' limit 1) parent_id,
 (select user_id from public.user_roles where role='youth' limit 1) other_id,
 (select user_id from public.user_roles where role='admin' limit 1) admin_id,
 a.id allocation_id,a.event_id,null::uuid ticket_id,null::text token,null::text replacement,null::uuid hold_id
 from public.ticket_allocations a join public.events e on e.id=a.event_id where e.is_demo and a.active limit 1;
grant select,update on ticket_test_context to authenticated;
update public.events set starts_at=now()+interval '1 day',sales_open_at=now()-interval '1 day',sales_close_at=now()+interval '12 hours',event_status='on_sale' where id=(select event_id from ticket_test_context);
update public.ticket_allocations set capacity=1,purchase_limit_per_user=2 where id=(select allocation_id from ticket_test_context);
set local role authenticated;
do $$ declare c record; issued record; n integer; result_value text; before_count integer; begin
 select * into c from ticket_test_context;
 if c.parent_id is null or c.other_id is null or c.admin_id is null then raise exception 'Missing test role'; end if;
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 if jsonb_array_length(public.native_ticket_events(false))=0 then raise exception 'Event list empty'; end if;
 begin
  perform * from public.native_reserve_tickets(c.allocation_id,2,'test-overcapacity');
  raise exception 'Overcapacity unexpectedly succeeded';
 exception when others then if sqlerrm not like '%Not enough tickets%' then raise; end if; end;
 select * into issued from public.native_reserve_tickets(c.allocation_id,1,'test-reserve-one');
 if issued.ticket_id is null or length(issued.token)<>64 then raise exception 'No confirmed ticket'; end if;
 update ticket_test_context set ticket_id=issued.ticket_id,token=issued.token;
 select count(*) into n from public.native_reserve_tickets(c.allocation_id,1,'test-reserve-one');
 if n<>0 then raise exception 'Retry issued duplicate'; end if;
 if not exists(select 1 from jsonb_array_elements(public.native_ticket_wallet()) x where x->>'id'=issued.ticket_id::text) then raise exception 'Owner ticket missing'; end if;
 perform set_config('request.jwt.claims',json_build_object('sub',c.other_id,'role','authenticated')::text,true);
 if exists(select 1 from jsonb_array_elements(public.native_ticket_wallet()) x where x->>'id'=issued.ticket_id::text) then raise exception 'Ticket leaked'; end if;
 begin perform public.native_replace_ticket_code(issued.ticket_id); raise exception 'Unrelated recovery allowed'; exception when others then if sqlerrm<>'Ticket unavailable' then raise; end if; end;
 begin perform public.native_cancel_ticket(issued.ticket_id); raise exception 'Unrelated cancellation allowed'; exception when others then if sqlerrm<>'Ticket unavailable' then raise; end if; end;
 begin perform * from public.scan_ticket(issued.token,c.event_id); raise exception 'Unrelated check-in allowed'; exception when others then if sqlerrm<>'Event staff access required' then raise; end if; end;
 begin perform public.native_ticket_wallet(c.event_id); raise exception 'Roster leaked'; exception when others then if sqlerrm<>'Event staff access required' then raise; end if; end;
 begin perform * from public.native_reserve_tickets(c.allocation_id,1,'test-other-capacity'); raise exception 'Oversold'; exception when others then if sqlerrm not like '%Not enough tickets%' then raise; end if; end;
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 perform public.native_cancel_ticket(issued.ticket_id);
 perform public.native_cancel_ticket(issued.ticket_id); -- Idempotent cancellation.
 select * into issued from public.native_reserve_tickets(c.allocation_id,1,'test-released-spot');
 update ticket_test_context set ticket_id=issued.ticket_id,token=issued.token,replacement=public.native_replace_ticket_code(issued.ticket_id);
 select * into c from ticket_test_context;
 perform set_config('request.jwt.claims',json_build_object('sub',c.admin_id,'role','authenticated')::text,true);
 select result::text into result_value from public.scan_ticket(c.token,c.event_id);
 if result_value<>'invalid' then raise exception 'Replaced code still works'; end if;
 select result::text into result_value from public.scan_ticket(c.replacement,c.event_id);
 if result_value<>'accepted' then raise exception 'Valid code rejected'; end if;
 select result::text into result_value from public.scan_ticket(c.replacement,c.event_id);
 if result_value<>'duplicate' then raise exception 'Duplicate admission accepted'; end if;
 if not exists(select 1 from jsonb_array_elements(public.native_ticket_wallet(c.event_id)) x where x->>'id'=c.ticket_id::text and x->>'status'='scanned') then raise exception 'Roster did not refresh'; end if;
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 begin perform public.native_cancel_ticket(c.ticket_id); raise exception 'Scanned ticket cancelled'; exception when others then if sqlerrm not like '%Only unused tickets%' then raise; end if; end;
end $$;
reset role;
-- Reclaim only rollback test rows to test a held reservation during cancellation.
update public.tickets set status='void' where id=(select ticket_id from ticket_test_context);
set local role authenticated;
do $$ declare c record; h public.ticket_holds%rowtype; begin
 select * into c from ticket_test_context;
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 h := public.create_ticket_hold(c.allocation_id,1,'test-event-cancel-hold');
 update ticket_test_context set hold_id=h.id;
end $$;
reset role;
update public.events set event_status='cancelled' where id=(select event_id from ticket_test_context);
set local role authenticated;
do $$ declare c record; begin
 select * into c from ticket_test_context;
 perform set_config('request.jwt.claims',json_build_object('sub',c.parent_id,'role','authenticated')::text,true);
 begin perform * from public.issue_ticket(c.hold_id); raise exception 'Cancelled event issued tickets'; exception when others then if sqlerrm not like '%Reservations are closed%' then raise; end if; end;
 perform set_config('request.jwt.claims',json_build_object('sub',c.admin_id,'role','authenticated')::text,true);
 begin perform * from public.scan_ticket(c.replacement,c.event_id); raise exception 'Cancelled event admitted'; exception when others then if sqlerrm not like '%Check-in is closed%' then raise; end if; end;
end $$;
reset role;
do $$ begin
 if has_function_privilege('anon','public.native_reserve_tickets(uuid,integer,text)','execute') or has_function_privilege('anon','public.native_ticket_wallet(uuid)','execute') then raise exception 'Anonymous ticket endpoint access'; end if;
end $$;

rollback;
select 'PASS: native ticket workflow; all test changes rolled back' as result;
