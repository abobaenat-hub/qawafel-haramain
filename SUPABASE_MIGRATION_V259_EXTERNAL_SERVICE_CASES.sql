-- V259: One customer/family case with multiple external services
create table if not exists public.external_service_cases (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  customer_type text not null default 'individual' check (customer_type in ('individual','family')),
  beneficiary_count integer not null default 1 check (beneficiary_count > 0),
  beneficiaries text null,
  case_date date not null default current_date,
  notes text null,
  status text not null default 'open' check (status in ('open','closed')),
  created_by uuid null,
  created_at timestamptz not null default now()
);

alter table public.external_services add column if not exists case_id uuid null references public.external_service_cases(id) on delete set null;
create index if not exists external_service_cases_date_idx on public.external_service_cases(case_date, created_at desc);
create index if not exists external_service_cases_customer_idx on public.external_service_cases(customer_name);
create index if not exists external_services_case_idx on public.external_services(case_id);

alter table public.external_service_cases enable row level security;
drop policy if exists external_service_cases_select_auth on public.external_service_cases;
create policy external_service_cases_select_auth on public.external_service_cases for select to authenticated using (true);
drop policy if exists external_service_cases_insert_auth on public.external_service_cases;
create policy external_service_cases_insert_auth on public.external_service_cases for insert to authenticated with check (true);

-- One atomic operation: creates the customer case, records all service lines, and deducts each supplier cost from its wallet.
create or replace function public.record_external_service_case_v1(
  p_customer_name text,
  p_customer_type text,
  p_beneficiary_count integer,
  p_beneficiaries text,
  p_case_date date,
  p_case_notes text,
  p_items jsonb,
  p_created_by uuid
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_case_id uuid;
  v_item jsonb;
  v_wallet_id uuid;
  v_service_date date;
  v_supplier_id uuid;
  v_service_type text;
  v_supplier_cost_amount numeric;
  v_supplier_cost_currency text;
  v_customer_amount numeric;
  v_customer_currency text;
  v_fx_rate numeric;
  v_supplier_iqd_rate numeric;
  v_revenue numeric;
  v_profit numeric;
  v_cost_iqd numeric;
  v_revenue_iqd numeric;
  v_profit_iqd numeric;
  v_notes text;
begin
  if p_customer_name is null or trim(p_customer_name)='' then raise exception 'اسم العميل أو العائلة مطلوب'; end if;
  if p_customer_type not in ('individual','family') then raise exception 'نوع العميل غير مدعوم'; end if;
  if p_customer_type='family' and p_beneficiary_count < 2 then raise exception 'عدد المستفيدين للعائلة يجب أن يكون 2 فأكثر'; end if;
  if jsonb_array_length(coalesce(p_items,'[]'::jsonb)) < 1 then raise exception 'أضف خدمة واحدة على الأقل'; end if;

  insert into public.external_service_cases(customer_name,customer_type,beneficiary_count,beneficiaries,case_date,notes,created_by)
  values (trim(p_customer_name),p_customer_type,greatest(1,p_beneficiary_count),p_beneficiaries,p_case_date,p_case_notes,p_created_by)
  returning id into v_case_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_service_type := nullif(trim(v_item->>'service_type'),'');
    v_supplier_id := (v_item->>'supplier_id')::uuid;
    v_service_date := coalesce(nullif(v_item->>'service_date','')::date,p_case_date);
    v_supplier_cost_amount := (v_item->>'supplier_cost_amount')::numeric;
    v_supplier_cost_currency := v_item->>'supplier_cost_currency';
    v_customer_amount := (v_item->>'customer_amount')::numeric;
    v_customer_currency := v_item->>'customer_currency';
    v_fx_rate := coalesce((v_item->>'fx_rate')::numeric,1);
    v_supplier_iqd_rate := case when v_supplier_cost_currency='IQD' then 1 else coalesce((v_item->>'supplier_iqd_rate')::numeric,0) end;
    v_notes := nullif(trim(v_item->>'notes'),'');

    if v_service_type is null or v_supplier_id is null then raise exception 'بيانات الخدمة ناقصة'; end if;
    if v_supplier_cost_amount <= 0 or v_customer_amount <= 0 then raise exception 'المبالغ يجب أن تكون أكبر من صفر'; end if;
    if v_supplier_cost_currency not in ('SAR','USD','IQD') or v_customer_currency not in ('SAR','USD','IQD') then raise exception 'عملة غير مدعومة'; end if;
    if v_customer_currency <> v_supplier_cost_currency and v_fx_rate <= 0 then raise exception 'سعر التحويل مطلوب'; end if;
    if v_supplier_cost_currency <> 'IQD' and v_supplier_iqd_rate <= 0 then raise exception 'سعر العملة مقابل الدينار مطلوب'; end if;

    v_revenue := case when v_customer_currency=v_supplier_cost_currency then v_customer_amount else v_customer_amount*v_fx_rate end;
    v_profit := v_revenue-v_supplier_cost_amount;
    v_cost_iqd := v_supplier_cost_amount*v_supplier_iqd_rate;
    v_revenue_iqd := v_revenue*v_supplier_iqd_rate;
    v_profit_iqd := v_profit*v_supplier_iqd_rate;

    insert into public.supplier_wallet_transactions(
      supplier_id,transaction_type,currency,amount,amount_iqd,transaction_date,
      source_currency,source_amount,fx_rate,exchange_rate_to_iqd,description,created_by
    ) values (
      v_supplier_id,'withdrawal',v_supplier_cost_currency,v_supplier_cost_amount,v_cost_iqd,v_service_date,
      null,null,null,v_supplier_iqd_rate,
      'خدمة خارجية: '||v_service_type||' — '||trim(p_customer_name),p_created_by
    ) returning id into v_wallet_id;

    insert into public.external_services(
      case_id,customer_name,customer_type,beneficiary_count,beneficiaries,service_type,supplier_id,service_date,
      supplier_cost_amount,supplier_cost_currency,customer_amount,customer_currency,fx_rate,supplier_iqd_rate,
      revenue_in_cost_currency,profit_in_cost_currency,supplier_cost_iqd,revenue_iqd,profit_iqd,wallet_tx_id,notes,created_by
    ) values (
      v_case_id,trim(p_customer_name),p_customer_type,greatest(1,p_beneficiary_count),p_beneficiaries,v_service_type,v_supplier_id,v_service_date,
      v_supplier_cost_amount,v_supplier_cost_currency,v_customer_amount,v_customer_currency,v_fx_rate,v_supplier_iqd_rate,
      v_revenue,v_profit,v_cost_iqd,v_revenue_iqd,v_profit_iqd,v_wallet_id,v_notes,p_created_by
    );
  end loop;
  return v_case_id;
end;
$$;

grant execute on function public.record_external_service_case_v1(text,text,integer,text,date,text,jsonb,uuid) to authenticated;
