alter table public.products
add column if not exists edition text not null default 'Standard';

alter table public.products
drop constraint if exists products_edition_check;

alter table public.products
add constraint products_edition_check
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

create or replace function public.admin_add_product(
  p_name text,
  p_platform text,
  p_edition text,
  p_category text,
  p_price numeric,
  p_old_price numeric,
  p_stock int,
  p_cover text,
  p_description text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
  user_email text;
begin
  user_email := coalesce(auth.jwt()->>'email', '');

  if user_email not in ('santiagosilva14092009@gmail.com','suporte.gamevault@gmail.com')
     and not exists (
       select 1
       from public.profiles
       where id = auth.uid()
       and role in ('admin','suporte','gestor')
     ) then
    raise exception 'not admin';
  end if;

  insert into public.products (
    name,
    platform,
    edition,
    category,
    price,
    old_price,
    discount,
    stock,
    cover,
    description,
    active
  )
  values (
    p_name,
    p_platform,
    coalesce(nullif(p_edition,''), 'Standard'),
    p_category,
    p_price,
    p_old_price,
    greatest(0, round((1 - (p_price / nullif(p_old_price, 0))) * 100)::int),
    p_stock,
    p_cover,
    coalesce(p_description, ''),
    true
  )
  returning id into new_id;

  return new_id;
end;
$$;

grant execute on function public.admin_add_product(text,text,text,text,numeric,numeric,int,text,text) to authenticated;

insert into public.profiles (id, name, email, role)
select
  id,
  coalesce(raw_user_meta_data->>'name', 'Santiago'),
  email,
  'admin'
from auth.users
where email in ('santiagosilva14092009@gmail.com','suporte.gamevault@gmail.com')
on conflict (id)
do update set
  name = excluded.name,
  email = excluded.email,
  role = 'admin';

select 'OK - admin_add_product criado' as resultado;
