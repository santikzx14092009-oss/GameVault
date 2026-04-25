create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'Cliente',
  email text not null,
  role text not null default 'customer' check (role in ('customer','admin','suporte','gestor')),
  created_at timestamptz not null default now()
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  platform text not null,
  category text not null,
  price numeric not null,
  old_price numeric not null,
  discount int not null default 0,
  stock int not null default 0,
  edition text not null default 'Standard' check (edition in ('Standard','Ultimate')),
  cover text not null,
  description text default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount int not null check (discount between 1 and 90),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  customer_name text not null,
  customer_email text not null,
  payment_method text not null,
  total numeric not null,
  status text not null default 'PENDENTE' check (status in ('PENDENTE','CONFIRMADO','REJEITADO')),
  key text default '',
  created_at timestamptz not null default now()
);

create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  product_id uuid references products(id),
  product_name text not null,
  price numeric not null
);

create table if not exists visits (
  id int primary key default 1,
  count int not null default 0,
  check (id = 1)
);
insert into visits (id,count) values (1,0) on conflict (id) do nothing;

create table if not exists support_tickets (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  customer_name text not null,
  customer_email text not null,
  status text not null default 'espera',
  support_name text default '',
  created_at timestamptz not null default now()
);

create table if not exists support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references support_tickets(id) on delete cascade,
  sender_id uuid references auth.users(id),
  sender_name text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, name, email, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'name','Cliente'), new.email, 'customer');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

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
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin','suporte','gestor')
    );
$$;

create or replace function public.increment_visit()
returns int
language plpgsql
security definer
as $$
declare new_count int;
begin
  update public.visits set count = count + 1 where id = 1 returning count into new_count;
  return new_count;
end;
$$;

alter table profiles enable row level security;
alter table products enable row level security;
alter table coupons enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table visits enable row level security;
alter table support_tickets enable row level security;
alter table support_messages enable row level security;

drop policy if exists "profiles read own or staff" on profiles;
create policy "profiles read own or staff" on profiles for select using (id = auth.uid() or public.is_staff());
drop policy if exists "profiles staff update" on profiles;
create policy "profiles staff update" on profiles for update using (public.is_staff());

drop policy if exists "products public read" on products;
create policy "products public read" on products for select using (active = true or public.is_staff());
drop policy if exists "products staff insert" on products;
create policy "products staff insert" on products for insert with check (public.is_staff());
drop policy if exists "products staff update" on products;
create policy "products staff update" on products for update using (public.is_staff());

drop policy if exists "coupons public read" on coupons;
create policy "coupons public read" on coupons for select using (active = true or public.is_staff());
drop policy if exists "coupons staff insert" on coupons;
create policy "coupons staff insert" on coupons for insert with check (public.is_staff());
drop policy if exists "coupons staff update" on coupons;
create policy "coupons staff update" on coupons for update using (public.is_staff());

drop policy if exists "orders own or staff read" on orders;
create policy "orders own or staff read" on orders for select using (customer_id = auth.uid() or public.is_staff());
drop policy if exists "orders customer insert" on orders;
create policy "orders customer insert" on orders for insert with check (customer_id = auth.uid());
drop policy if exists "orders staff update" on orders;
create policy "orders staff update" on orders for update using (public.is_staff());
drop policy if exists "orders staff delete" on orders;
create policy "orders staff delete" on orders for delete using (public.is_staff());

drop policy if exists "order items own or staff read" on order_items;
create policy "order items own or staff read" on order_items for select using (
  exists (select 1 from orders where orders.id = order_items.order_id and (orders.customer_id = auth.uid() or public.is_staff()))
);
drop policy if exists "order items customer insert" on order_items;
create policy "order items customer insert" on order_items for insert with check (
  exists (select 1 from orders where orders.id = order_items.order_id and orders.customer_id = auth.uid())
);
drop policy if exists "order items staff delete" on order_items;
create policy "order items staff delete" on order_items for delete using (public.is_staff());

drop policy if exists "visits public read" on visits;
create policy "visits public read" on visits for select using (true);

drop policy if exists "support own or staff read" on support_tickets;
create policy "support own or staff read" on support_tickets for select using (customer_id = auth.uid() or public.is_staff());
drop policy if exists "support customer insert" on support_tickets;
create policy "support customer insert" on support_tickets for insert with check (customer_id = auth.uid());
drop policy if exists "support staff update" on support_tickets;
create policy "support staff update" on support_tickets for update using (public.is_staff());

drop policy if exists "support messages own or staff read" on support_messages;
create policy "support messages own or staff read" on support_messages for select using (
  exists (select 1 from support_tickets where support_tickets.id = support_messages.ticket_id and (support_tickets.customer_id = auth.uid() or public.is_staff()))
);
drop policy if exists "support messages logged insert" on support_messages;
create policy "support messages logged insert" on support_messages for insert with check (
  auth.uid() is not null and exists (
    select 1 from support_tickets
    where support_tickets.id = support_messages.ticket_id
    and (support_tickets.customer_id = auth.uid() or public.is_staff())
  )
);

insert into coupons (code, discount, active) values ('VAULT10', 10, true)
on conflict (code) do nothing;

insert into products (name, platform, category, price, old_price, discount, stock, cover, description, active) values
('Grand Theft Auto V','Steam','Acao',14.99,29.99,50,74,'https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg','Mundo aberto criminal em Los Santos com campanha e online.',true),
('Red Dead Redemption 2','Steam','Aventura',19.99,59.99,67,63,'https://cdn.akamai.steamstatic.com/steam/apps/1174180/header.jpg','Western de mundo aberto com narrativa premium.',true),
('Cyberpunk 2077','Steam','RPG',24.99,59.99,58,39,'https://cdn.akamai.steamstatic.com/steam/apps/1091500/header.jpg','RPG futurista em Night City com builds e historia.',true),
('Elden Ring','Steam','RPG',36.99,59.99,38,47,'https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg','Fantasia sombria com exploracao e bosses lendarios.',true)
on conflict do nothing;
