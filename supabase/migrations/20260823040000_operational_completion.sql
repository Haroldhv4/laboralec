-- Laboral EC - cierre del MVP operativo.
-- Idempotente: puede aplicarse aunque parte del esquema ya exista.

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete cascade,
  reminder_type text not null default 'custom',
  title text not null,
  due_date date not null,
  status text not null default 'pending' check (status in ('pending','done','dismissed')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists reminders_company_due_idx
  on public.reminders(company_id, due_date);

alter table public.reminders enable row level security;

drop policy if exists reminders_owner_all on public.reminders;
create policy reminders_owner_all
  on public.reminders
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.companies c
      where c.id = reminders.company_id
        and c.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.companies c
      where c.id = reminders.company_id
        and c.owner_id = (select auth.uid())
    )
  );

grant select, insert, update, delete on public.reminders to authenticated;

-- Asegura índices útiles para los nuevos flujos.
create index if not exists overtime_records_employee_date_idx
  on public.overtime_records(employee_id, work_date);
create index if not exists vacation_periods_employee_start_idx
  on public.vacation_periods(employee_id, period_start);
create index if not exists payroll_periods_company_period_idx
  on public.payroll_periods(company_id, year desc, month desc);
create index if not exists settlements_company_created_idx
  on public.settlements(company_id, created_at desc);
