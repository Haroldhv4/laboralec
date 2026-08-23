-- Laboral EC - esquema operativo del MVP.
-- Mantiene el aislamiento por empresa usando el owner_id de public.companies.

alter table public.companies drop constraint if exists companies_region_check;
alter table public.companies add constraint companies_region_check
  check (region is null or region in ('costa_insular', 'sierra_amazonia'));

alter table public.employees drop constraint if exists employees_identification_type_check;
alter table public.employees add constraint employees_identification_type_check
  check (identification_type in ('cedula', 'passport', 'ruc', 'other'));

alter table public.employees drop constraint if exists employees_status_check;
alter table public.employees add constraint employees_status_check
  check (status in ('active', 'inactive'));

alter table public.contracts drop constraint if exists contracts_contract_type_check;
alter table public.contracts add constraint contracts_contract_type_check
  check (contract_type in ('indefinite', 'fixed_term', 'temporary', 'eventual', 'seasonal', 'other'));

alter table public.contracts drop constraint if exists contracts_workday_type_check;
alter table public.contracts add constraint contracts_workday_type_check
  check (workday_type in ('full_time', 'part_time'));

alter table public.contracts drop constraint if exists contracts_thirteenth_payment_mode_check;
alter table public.contracts add constraint contracts_thirteenth_payment_mode_check
  check (thirteenth_payment_mode in ('monthly', 'accumulated'));

alter table public.contracts drop constraint if exists contracts_fourteenth_payment_mode_check;
alter table public.contracts add constraint contracts_fourteenth_payment_mode_check
  check (fourteenth_payment_mode in ('monthly', 'accumulated'));

alter table public.contracts drop constraint if exists contracts_reserve_fund_payment_mode_check;
alter table public.contracts add constraint contracts_reserve_fund_payment_mode_check
  check (reserve_fund_payment_mode in ('monthly', 'iess'));

alter table public.contracts drop constraint if exists contracts_status_check;
alter table public.contracts add constraint contracts_status_check
  check (status in ('active', 'ended', 'suspended'));

create table if not exists public.payroll_periods (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  year integer not null check (year between 2000 and 2100),
  month integer not null check (month between 1 and 12),
  status text not null default 'draft' check (status in ('draft','calculated','closed')),
  calculated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, year, month)
);

create table if not exists public.payroll_entries (
  id uuid primary key default gen_random_uuid(),
  payroll_period_id uuid not null references public.payroll_periods(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  contract_id uuid not null references public.contracts(id) on delete restrict,
  base_salary numeric(14,2) not null default 0 check (base_salary >= 0),
  gross_income numeric(14,2) not null default 0 check (gross_income >= 0),
  employee_iess numeric(14,2) not null default 0 check (employee_iess >= 0),
  other_deductions numeric(14,2) not null default 0 check (other_deductions >= 0),
  net_pay numeric(14,2) not null default 0,
  employer_iess numeric(14,2) not null default 0 check (employer_iess >= 0),
  employer_cost numeric(14,2) not null default 0 check (employer_cost >= 0),
  calculation_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(payroll_period_id, employee_id)
);

create table if not exists public.payroll_items (
  id uuid primary key default gen_random_uuid(),
  payroll_entry_id uuid not null references public.payroll_entries(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  code text not null,
  label text not null,
  item_type text not null check (item_type in ('income','deduction','employer_cost','provision')),
  amount numeric(14,2) not null default 0,
  base_amount numeric(14,6),
  rate numeric(14,8),
  quantity numeric(14,6),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.overtime_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  contract_id uuid not null references public.contracts(id) on delete cascade,
  work_date date not null,
  start_time time,
  end_time time,
  hours numeric(8,2) not null check (hours > 0 and hours <= 24),
  overtime_type text not null check (overtime_type in ('supplementary_50','extraordinary_100','night_25')),
  hourly_base numeric(14,6) not null check (hourly_base >= 0),
  multiplier numeric(10,6) not null check (multiplier >= 0),
  amount numeric(14,2) not null check (amount >= 0),
  status text not null default 'pending' check (status in ('pending','approved','paid','cancelled')),
  calculation_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.vacation_periods (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  contract_id uuid not null references public.contracts(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  earned_days numeric(8,2) not null default 0 check (earned_days >= 0),
  taken_days numeric(8,2) not null default 0 check (taken_days >= 0),
  paid_days numeric(8,2) not null default 0 check (paid_days >= 0),
  monetary_value numeric(14,2) not null default 0 check (monetary_value >= 0),
  calculation_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (period_end >= period_start),
  check (taken_days + paid_days <= earned_days)
);

create table if not exists public.terminations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  contract_id uuid not null references public.contracts(id) on delete restrict,
  termination_date date not null,
  cause_code text not null,
  cause_label text,
  status text not null default 'draft' check (status in ('draft','calculated','completed','cancelled')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.settlements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  termination_id uuid not null unique references public.terminations(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  contract_id uuid not null references public.contracts(id) on delete restrict,
  calculation_date date not null default current_date,
  income_total numeric(14,2) not null default 0,
  benefits_total numeric(14,2) not null default 0,
  indemnifications_total numeric(14,2) not null default 0,
  deductions_total numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  status text not null default 'draft' check (status in ('draft','calculated','finalized','void')),
  legal_engine_version text not null,
  warnings jsonb not null default '[]'::jsonb,
  calculation_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.settlement_items (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null references public.settlements(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  code text not null,
  label text not null,
  category text not null check (category in ('income','benefit','indemnification','deduction')),
  base_amount numeric(14,6),
  quantity numeric(14,6),
  rate numeric(14,8),
  amount numeric(14,2) not null,
  legal_source_code text,
  explanation text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete cascade,
  reminder_type text not null,
  title text not null,
  due_date date not null,
  status text not null default 'pending' check (status in ('pending','done','dismissed')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists payroll_periods_company_idx on public.payroll_periods(company_id);
create index if not exists payroll_entries_company_idx on public.payroll_entries(company_id);
create index if not exists payroll_entries_employee_idx on public.payroll_entries(employee_id);
create index if not exists payroll_items_entry_idx on public.payroll_items(payroll_entry_id);
create index if not exists overtime_company_employee_date_idx on public.overtime_records(company_id, employee_id, work_date);
create index if not exists vacation_company_employee_idx on public.vacation_periods(company_id, employee_id);
create index if not exists terminations_company_employee_idx on public.terminations(company_id, employee_id);
create index if not exists settlements_company_employee_idx on public.settlements(company_id, employee_id);
create index if not exists settlement_items_settlement_idx on public.settlement_items(settlement_id);
create index if not exists reminders_company_due_idx on public.reminders(company_id, due_date);

alter table public.payroll_periods enable row level security;
alter table public.payroll_entries enable row level security;
alter table public.payroll_items enable row level security;
alter table public.overtime_records enable row level security;
alter table public.vacation_periods enable row level security;
alter table public.terminations enable row level security;
alter table public.settlements enable row level security;
alter table public.settlement_items enable row level security;
alter table public.reminders enable row level security;

-- Las políticas se recrean para que la migración sea repetible durante desarrollo.
drop policy if exists payroll_periods_owner_all on public.payroll_periods;
create policy payroll_periods_owner_all on public.payroll_periods for all to authenticated
  using (exists (select 1 from public.companies c where c.id = payroll_periods.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = payroll_periods.company_id and c.owner_id = (select auth.uid())));

drop policy if exists payroll_entries_owner_all on public.payroll_entries;
create policy payroll_entries_owner_all on public.payroll_entries for all to authenticated
  using (exists (select 1 from public.companies c where c.id = payroll_entries.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = payroll_entries.company_id and c.owner_id = (select auth.uid())));

drop policy if exists payroll_items_owner_all on public.payroll_items;
create policy payroll_items_owner_all on public.payroll_items for all to authenticated
  using (exists (select 1 from public.companies c where c.id = payroll_items.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = payroll_items.company_id and c.owner_id = (select auth.uid())));

drop policy if exists overtime_records_owner_all on public.overtime_records;
create policy overtime_records_owner_all on public.overtime_records for all to authenticated
  using (exists (select 1 from public.companies c where c.id = overtime_records.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = overtime_records.company_id and c.owner_id = (select auth.uid())));

drop policy if exists vacation_periods_owner_all on public.vacation_periods;
create policy vacation_periods_owner_all on public.vacation_periods for all to authenticated
  using (exists (select 1 from public.companies c where c.id = vacation_periods.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = vacation_periods.company_id and c.owner_id = (select auth.uid())));

drop policy if exists terminations_owner_all on public.terminations;
create policy terminations_owner_all on public.terminations for all to authenticated
  using (exists (select 1 from public.companies c where c.id = terminations.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = terminations.company_id and c.owner_id = (select auth.uid())));

drop policy if exists settlements_owner_all on public.settlements;
create policy settlements_owner_all on public.settlements for all to authenticated
  using (exists (select 1 from public.companies c where c.id = settlements.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = settlements.company_id and c.owner_id = (select auth.uid())));

drop policy if exists settlement_items_owner_all on public.settlement_items;
create policy settlement_items_owner_all on public.settlement_items for all to authenticated
  using (exists (select 1 from public.companies c where c.id = settlement_items.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = settlement_items.company_id and c.owner_id = (select auth.uid())));

drop policy if exists reminders_owner_all on public.reminders;
create policy reminders_owner_all on public.reminders for all to authenticated
  using (exists (select 1 from public.companies c where c.id = reminders.company_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.companies c where c.id = reminders.company_id and c.owner_id = (select auth.uid())));

grant select, insert, update, delete on
  public.payroll_periods,
  public.payroll_entries,
  public.payroll_items,
  public.overtime_records,
  public.vacation_periods,
  public.terminations,
  public.settlements,
  public.settlement_items,
  public.reminders
  to authenticated;
