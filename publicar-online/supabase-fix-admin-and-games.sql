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
    name, platform, edition, category, price, old_price, discount, stock, cover, description, active
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

insert into public.products
(name, platform, edition, category, price, old_price, discount, stock, cover, description, active)
values
('Grand Theft Auto V','Steam','Standard','Ação',14.99,29.99,50,80,'https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg','Mundo aberto em Los Santos com campanha criminal e modo online.',true),
('Grand Theft Auto V Premium Edition','Steam','Ultimate','Ação',19.99,39.99,50,45,'https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg','Edição premium com GTA Online e conteúdo extra.',true),
('Cyberpunk 2077','GOG.com','Standard','RPG',24.99,59.99,58,70,'https://cdn.akamai.steamstatic.com/steam/apps/1091500/header.jpg','RPG futurista em Night City com ação, escolhas e tecnologia.',true),
('Cyberpunk 2077 Ultimate Edition','GOG.com','Ultimate','RPG',39.99,79.99,50,42,'https://cdn.akamai.steamstatic.com/steam/apps/1091500/header.jpg','Edição completa com aventura futurista e conteúdo extra.',true),
('Red Dead Redemption 2','Steam','Standard','Aventura',19.99,59.99,67,66,'https://cdn.akamai.steamstatic.com/steam/apps/1174180/header.jpg','Western de mundo aberto com narrativa forte e exploração.',true),
('Elden Ring','Steam','Standard','RPG',36.99,59.99,38,52,'https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg','Fantasia sombria com bosses lendários e mundo aberto.',true),
('Elden Ring Shadow of the Erdtree Edition','Steam','Ultimate','RPG',54.99,79.99,31,30,'https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg','Edição completa para fãs de fantasia sombria e desafio.',true),
('Hogwarts Legacy','Steam','Standard','Aventura',29.99,59.99,50,55,'https://cdn.akamai.steamstatic.com/steam/apps/990080/header.jpg','Aventura mágica em mundo aberto no universo de Hogwarts.',true),
('Minecraft Java & Bedrock','PC','Standard','Sobrevivência',19.99,29.99,33,95,'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1672970/header.jpg','Construção, exploração e sobrevivência em mundos infinitos.',true),
('The Witcher 3: Wild Hunt','GOG.com','Standard','RPG',9.99,39.99,75,90,'https://cdn.akamai.steamstatic.com/steam/apps/292030/header.jpg','RPG épico com história profunda, monstros e escolhas marcantes.',true),
('The Witcher 3: Complete Edition','GOG.com','Ultimate','RPG',14.99,49.99,70,62,'https://cdn.akamai.steamstatic.com/steam/apps/292030/header.jpg','Edição completa com expansões e aventura épica.',true),
('Call of Duty: Modern Warfare III','Steam','Standard','FPS',49.99,69.99,29,40,'https://cdn.akamai.steamstatic.com/steam/apps/2519060/header.jpg','FPS militar com campanha, multijogador e ação intensa.',true),
('EA Sports FC 26','PC','Standard','Desporto',54.99,69.99,21,38,'https://cdn.akamai.steamstatic.com/steam/apps/2195250/header.jpg','Futebol moderno com clubes, modos competitivos e equipas famosas.',true),
('NBA 2K26','PC','Standard','Desporto',49.99,69.99,29,34,'https://cdn.akamai.steamstatic.com/steam/apps/2878980/header.jpg','Basquetebol competitivo com equipas, carreira e modos online.',true),
('Resident Evil 4','Steam','Standard','Terror',24.99,59.99,58,59,'https://cdn.akamai.steamstatic.com/steam/apps/2050650/header.jpg','Terror de sobrevivência com ação, tensão e remake moderno.',true),
('Forza Horizon 5','Xbox','Standard','Corrida',29.99,59.99,50,64,'https://cdn.akamai.steamstatic.com/steam/apps/1551360/header.jpg','Corridas em mundo aberto com carros premium e eventos.',true),
('Forza Horizon 5 Premium Edition','Xbox','Ultimate','Corrida',49.99,99.99,50,25,'https://cdn.akamai.steamstatic.com/steam/apps/1551360/header.jpg','Edição premium com conteúdo extra e expansão.',true),
('Marvel Spider-Man Remastered','Steam','Standard','Ação',34.99,59.99,42,48,'https://cdn.akamai.steamstatic.com/steam/apps/1817070/header.jpg','Ação em Nova Iorque com combate fluido e história cinematográfica.',true),
('Marvel Spider-Man 2','PlayStation','Standard','Ação',59.99,79.99,25,35,'https://image.api.playstation.com/vulcan/ap/rnd/202306/1219/97e9f5fa6e50c185d249956c6f198a2652a9217e69a59ecd.jpg','Aventura de super-heróis com Peter, Miles e vilões icónicos.',true),
('God of War Ragnarök','PlayStation','Standard','Aventura',49.99,69.99,29,44,'https://cdn.akamai.steamstatic.com/steam/apps/2322010/header.jpg','Aventura nórdica com combate poderoso e narrativa épica.',true),
('Black Myth: Wukong','Steam','Standard','Ação RPG',44.99,59.99,25,41,'https://cdn.akamai.steamstatic.com/steam/apps/2358720/header.jpg','Ação RPG inspirada na mitologia chinesa com bosses intensos.',true),
('The Last of Us Part I','Steam','Standard','Aventura',34.99,59.99,42,39,'https://cdn.akamai.steamstatic.com/steam/apps/1888930/header.jpg','Aventura emocional de sobrevivência num mundo devastado.',true),
('Ghost of Tsushima Director''s Cut','Steam','Ultimate','Aventura',44.99,59.99,25,43,'https://cdn.akamai.steamstatic.com/steam/apps/2215430/header.jpg','Ação samurai em mundo aberto com edição Director''s Cut.',true),
('Assassin''s Creed Shadows','PC','Standard','Aventura',54.99,69.99,21,28,'https://cdn.akamai.steamstatic.com/steam/apps/3159330/header.jpg','Aventura no Japão feudal com stealth, combate e exploração.',true),
('Ready or Not','Steam','Standard','Tático',24.99,49.99,50,57,'https://cdn.akamai.steamstatic.com/steam/apps/1144200/header.jpg','FPS tático realista com operações policiais intensas.',true),
('Helldivers 2','Steam','Standard','Cooperação',29.99,39.99,25,50,'https://cdn.akamai.steamstatic.com/steam/apps/553850/header.jpg','Ação cooperativa explosiva contra ameaças alienígenas.',true),
('Baldur''s Gate 3','GOG.com','Standard','RPG',44.99,59.99,25,36,'https://cdn.akamai.steamstatic.com/steam/apps/1086940/header.jpg','RPG de fantasia com escolhas profundas e combate estratégico.',true),
('Palworld','Steam','Standard','Sobrevivência',19.99,29.99,33,61,'https://cdn.akamai.steamstatic.com/steam/apps/1623730/header.jpg','Sobrevivência, criaturas e exploração num mundo aberto.',true),
('Tekken 8','Steam','Standard','Luta',39.99,69.99,43,33,'https://cdn.akamai.steamstatic.com/steam/apps/1778820/header.jpg','Jogo de luta moderno com combates intensos e personagens icónicas.',true),
('Mortal Kombat 1','Steam','Standard','Luta',29.99,69.99,57,32,'https://cdn.akamai.steamstatic.com/steam/apps/1971870/header.jpg','Luta brutal com história cinematográfica e modos competitivos.',true)
on conflict do nothing;

select 'OK - permissões corrigidas e jogos adicionados' as resultado;
