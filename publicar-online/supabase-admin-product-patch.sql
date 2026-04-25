alter table public.products
add column if not exists edition text not null default 'Standard'
check (edition in ('Standard','Ultimate'));

create or replace function public.is_staff()
returns boolean
language sql
stable
as $$
  select
    coalesce(auth.jwt()->>'email','') in (
      'santiagosilva14092009@gmail.com',
      'suporte.gamevault@gmail.com'
    )
    or exists (
      select 1
      from public.profiles
      where id = auth.uid()
      and role in ('admin','suporte','gestor')
    );
$$;

insert into public.profiles (id, name, email, role)
select
  id,
  coalesce(raw_user_meta_data->>'name', 'Santiago'),
  email,
  case
    when email in ('santiagosilva14092009@gmail.com','suporte.gamevault@gmail.com') then 'admin'
    else 'customer'
  end
from auth.users
where email in ('santiagosilva14092009@gmail.com','suporte.gamevault@gmail.com')
on conflict (id)
do update set
  name = excluded.name,
  email = excluded.email,
  role = 'admin';

select id, email, role
from public.profiles
where email in ('santiagosilva14092009@gmail.com','suporte.gamevault@gmail.com');
