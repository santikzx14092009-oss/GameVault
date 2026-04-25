alter table public.products add column if not exists edition text not null default 'Standard';
alter table public.products drop constraint if exists products_edition_check;
alter table public.products add constraint products_edition_check check (edition in ('Standard','Ultimate'));

create or replace function public.is_staff()
returns boolean
language sql
stable
as $$
  select
    coalesce(auth.jwt()->>'email','') in ('santiagosilva14092009@gmail.com','suporte.gamevault@gmail.com')
    or exists (
      select 1 from public.profiles
      where id = auth.uid()
      and role in ('admin','suporte','gestor')
    );
$$;

insert into public.profiles (id, name, email, role)
select id, coalesce(raw_user_meta_data->>'name', 'Santiago'), email, 'admin'
from auth.users
where email in ('santiagosilva14092009@gmail.com','suporte.gamevault@gmail.com')
on conflict (id) do update set name = excluded.name, email = excluded.email, role = 'admin';

create or replace function public.admin_add_product(
  p_name text, p_platform text, p_edition text, p_category text,
  p_price numeric, p_old_price numeric, p_stock int, p_cover text, p_description text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare new_id uuid;
begin
  if not public.is_staff() then raise exception 'not admin'; end if;
  insert into public.products (name, platform, edition, category, price, old_price, discount, stock, cover, description, active)
  values (p_name, p_platform, coalesce(nullif(p_edition,''),'Standard'), p_category, p_price, p_old_price,
  greatest(0, round((1 - (p_price / nullif(p_old_price, 0))) * 100)::int), p_stock, p_cover, coalesce(p_description,''), true)
  returning id into new_id;
  return new_id;
end;
$$;

grant execute on function public.admin_add_product(text,text,text,text,numeric,numeric,int,text,text) to authenticated;

create or replace function public.admin_update_product_price(
  p_id uuid, p_price numeric, p_old_price numeric, p_stock int
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then raise exception 'not admin'; end if;
  update public.products
  set price = p_price,
      old_price = p_old_price,
      stock = p_stock,
      discount = greatest(0, round((1 - (p_price / nullif(p_old_price, 0))) * 100)::int)
  where id = p_id;
  return true;
end;
$$;

grant execute on function public.admin_update_product_price(uuid,numeric,numeric,int) to authenticated;

with games(name, platform, edition, category, price, old_price, stock, cover, description) as (
  values
  ('Grand Theft Auto V','Steam','Standard','Ação',14.99,29.99,80,'https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg','Mundo aberto em Los Santos com campanha criminal e modo online.'),
  ('GTA V Premium Edition','Steam','Ultimate','Ação',19.99,39.99,45,'https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg','Edição premium com GTA Online e conteúdo extra.'),
  ('Cyberpunk 2077','GOG.com','Standard','RPG',24.99,59.99,70,'https://cdn.akamai.steamstatic.com/steam/apps/1091500/header.jpg','RPG futurista em Night City com ação e escolhas.'),
  ('Cyberpunk 2077 Ultimate Edition','GOG.com','Ultimate','RPG',39.99,79.99,42,'https://cdn.akamai.steamstatic.com/steam/apps/1091500/header.jpg','Edição completa com aventura futurista e expansão.'),
  ('Red Dead Redemption 2','Steam','Standard','Aventura',19.99,59.99,66,'https://cdn.akamai.steamstatic.com/steam/apps/1174180/header.jpg','Western de mundo aberto com narrativa forte.'),
  ('Elden Ring','Steam','Standard','RPG',36.99,59.99,52,'https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg','Fantasia sombria com bosses lendários.'),
  ('Elden Ring Shadow Edition','Steam','Ultimate','RPG',54.99,79.99,30,'https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg','Edição completa para fãs de fantasia sombria.'),
  ('Hogwarts Legacy','Steam','Standard','Aventura',29.99,59.99,55,'https://cdn.akamai.steamstatic.com/steam/apps/990080/header.jpg','Aventura mágica em mundo aberto.'),
  ('Minecraft Java & Bedrock','PC','Standard','Sobrevivência',19.99,29.99,95,'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1672970/header.jpg','Construção, exploração e sobrevivência.'),
  ('The Witcher 3: Wild Hunt','GOG.com','Standard','RPG',9.99,39.99,90,'https://cdn.akamai.steamstatic.com/steam/apps/292030/header.jpg','RPG épico com monstros e escolhas.'),
  ('The Witcher 3 Complete Edition','GOG.com','Ultimate','RPG',14.99,49.99,62,'https://cdn.akamai.steamstatic.com/steam/apps/292030/header.jpg','Edição completa com expansões.'),
  ('Call of Duty Modern Warfare III','Steam','Standard','FPS',49.99,69.99,40,'https://cdn.akamai.steamstatic.com/steam/apps/2519060/header.jpg','FPS militar com ação intensa.'),
  ('EA Sports FC 26','PC','Standard','Desporto',54.99,69.99,38,'https://cdn.akamai.steamstatic.com/steam/apps/2195250/header.jpg','Futebol moderno com modos competitivos.'),
  ('NBA 2K26','PC','Standard','Desporto',49.99,69.99,34,'https://cdn.akamai.steamstatic.com/steam/apps/2878980/header.jpg','Basquetebol competitivo com carreira e online.'),
  ('Resident Evil 4','Steam','Standard','Terror',24.99,59.99,59,'https://cdn.akamai.steamstatic.com/steam/apps/2050650/header.jpg','Terror de sobrevivência com ação moderna.'),
  ('Forza Horizon 5','Xbox','Standard','Corrida',29.99,59.99,64,'https://cdn.akamai.steamstatic.com/steam/apps/1551360/header.jpg','Corridas em mundo aberto com carros premium.'),
  ('Forza Horizon 5 Premium Edition','Xbox','Ultimate','Corrida',49.99,99.99,25,'https://cdn.akamai.steamstatic.com/steam/apps/1551360/header.jpg','Edição premium com conteúdo extra.'),
  ('Marvel Spider-Man Remastered','Steam','Standard','Ação',34.99,59.99,48,'https://cdn.akamai.steamstatic.com/steam/apps/1817070/header.jpg','Ação em Nova Iorque com combate fluido.'),
  ('Marvel Spider-Man Miles Morales','Steam','Standard','Ação',29.99,49.99,47,'https://cdn.akamai.steamstatic.com/steam/apps/1817190/header.jpg','Aventura urbana com Miles Morales.'),
  ('Marvel Spider-Man 2','PlayStation','Standard','Ação',59.99,79.99,35,'https://image.api.playstation.com/vulcan/ap/rnd/202306/1219/97e9f5fa6e50c185d249956c6f198a2652a9217e69a59ecd.jpg','Aventura de super-heróis com Peter e Miles.'),
  ('God of War Ragnarök','PlayStation','Standard','Aventura',49.99,69.99,44,'https://cdn.akamai.steamstatic.com/steam/apps/2322010/header.jpg','Aventura nórdica com combate poderoso.'),
  ('Black Myth: Wukong','Steam','Standard','Ação RPG',44.99,59.99,41,'https://cdn.akamai.steamstatic.com/steam/apps/2358720/header.jpg','Ação RPG inspirada na mitologia chinesa.'),
  ('The Last of Us Part I','Steam','Standard','Aventura',34.99,59.99,39,'https://cdn.akamai.steamstatic.com/steam/apps/1888930/header.jpg','Sobrevivência emocional num mundo devastado.'),
  ('Ghost of Tsushima Director''s Cut','Steam','Ultimate','Aventura',44.99,59.99,43,'https://cdn.akamai.steamstatic.com/steam/apps/2215430/header.jpg','Ação samurai em mundo aberto.'),
  ('Assassin''s Creed Shadows','PC','Standard','Aventura',54.99,69.99,28,'https://cdn.akamai.steamstatic.com/steam/apps/3159330/header.jpg','Aventura no Japão feudal.'),
  ('Ready or Not','Steam','Standard','Tático',24.99,49.99,57,'https://cdn.akamai.steamstatic.com/steam/apps/1144200/header.jpg','FPS tático com operações policiais.'),
  ('Helldivers 2','Steam','Standard','Cooperação',29.99,39.99,50,'https://cdn.akamai.steamstatic.com/steam/apps/553850/header.jpg','Ação cooperativa contra ameaças alienígenas.'),
  ('Baldur''s Gate 3','GOG.com','Standard','RPG',44.99,59.99,36,'https://cdn.akamai.steamstatic.com/steam/apps/1086940/header.jpg','RPG de fantasia com escolhas profundas.'),
  ('Palworld','Steam','Standard','Sobrevivência',19.99,29.99,61,'https://cdn.akamai.steamstatic.com/steam/apps/1623730/header.jpg','Criaturas, exploração e sobrevivência.'),
  ('Tekken 8','Steam','Standard','Luta',39.99,69.99,33,'https://cdn.akamai.steamstatic.com/steam/apps/1778820/header.jpg','Jogo de luta moderno e competitivo.'),
  ('Mortal Kombat 1','Steam','Standard','Luta',29.99,69.99,32,'https://cdn.akamai.steamstatic.com/steam/apps/1971870/header.jpg','Luta brutal com história cinematográfica.'),
  ('Starfield','Steam','Standard','RPG',39.99,69.99,38,'https://cdn.akamai.steamstatic.com/steam/apps/1716740/header.jpg','RPG espacial com exploração e missões.'),
  ('The Elder Scrolls V: Skyrim Special Edition','Steam','Standard','RPG',9.99,39.99,77,'https://cdn.akamai.steamstatic.com/steam/apps/489830/header.jpg','RPG clássico de fantasia em mundo aberto.'),
  ('Fallout 4','Steam','Standard','RPG',7.99,19.99,85,'https://cdn.akamai.steamstatic.com/steam/apps/377160/header.jpg','RPG pós-apocalíptico com exploração.'),
  ('DOOM Eternal','Steam','Standard','FPS',12.99,39.99,74,'https://cdn.akamai.steamstatic.com/steam/apps/782330/header.jpg','FPS rápido com combate demoníaco.'),
  ('Hades','Steam','Standard','Roguelike',9.99,24.99,84,'https://cdn.akamai.steamstatic.com/steam/apps/1145360/header.jpg','Roguelike de ação com narrativa mitológica.'),
  ('Hades II','Steam','Standard','Roguelike',24.99,29.99,46,'https://cdn.akamai.steamstatic.com/steam/apps/1145350/header.jpg','Sequência roguelike com ação intensa.'),
  ('Sea of Thieves','Xbox','Standard','Aventura',19.99,39.99,58,'https://cdn.akamai.steamstatic.com/steam/apps/1172620/header.jpg','Aventura pirata cooperativa online.'),
  ('Dead Space','Steam','Standard','Terror',24.99,59.99,41,'https://cdn.akamai.steamstatic.com/steam/apps/1693980/header.jpg','Terror espacial com atmosfera intensa.'),
  ('Resident Evil Village','Steam','Standard','Terror',19.99,39.99,48,'https://cdn.akamai.steamstatic.com/steam/apps/1196590/header.jpg','Terror em primeira pessoa com ação.'),
  ('Resident Evil 2','Steam','Standard','Terror',9.99,39.99,68,'https://cdn.akamai.steamstatic.com/steam/apps/883710/header.jpg','Remake clássico de terror de sobrevivência.'),
  ('Resident Evil 3','Steam','Standard','Terror',9.99,39.99,63,'https://cdn.akamai.steamstatic.com/steam/apps/952060/header.jpg','Terror de sobrevivência contra Nemesis.'),
  ('Dying Light 2 Stay Human','Steam','Standard','Ação',24.99,59.99,45,'https://cdn.akamai.steamstatic.com/steam/apps/534380/header.jpg','Parkour e sobrevivência zombie em mundo aberto.'),
  ('Metro Exodus','Steam','Standard','FPS',7.99,29.99,70,'https://cdn.akamai.steamstatic.com/steam/apps/412020/header.jpg','FPS pós-apocalíptico com atmosfera forte.'),
  ('Hitman World of Assassination','Steam','Standard','Stealth',29.99,69.99,37,'https://cdn.akamai.steamstatic.com/steam/apps/1659040/header.jpg','Stealth premium com missões criativas.'),
  ('Far Cry 6','PC','Standard','Ação',19.99,59.99,51,'https://cdn.akamai.steamstatic.com/steam/apps/2369390/header.jpg','Ação em mundo aberto com revolução.'),
  ('Assassin''s Creed Valhalla','PC','Standard','Aventura',19.99,59.99,49,'https://cdn.akamai.steamstatic.com/steam/apps/2208920/header.jpg','Saga viking com exploração e combate.'),
  ('Assassin''s Creed Mirage','PC','Standard','Aventura',24.99,49.99,40,'https://cdn.akamai.steamstatic.com/steam/apps/3035570/header.jpg','Stealth clássico numa cidade histórica.'),
  ('Rainbow Six Siege','PC','Standard','FPS',7.99,19.99,93,'https://cdn.akamai.steamstatic.com/steam/apps/359550/header.jpg','FPS tático competitivo por equipas.'),
  ('The Crew Motorfest','PC','Standard','Corrida',29.99,69.99,39,'https://cdn.akamai.steamstatic.com/steam/apps/2698940/header.jpg','Corridas festival em mundo aberto.'),
  ('F1 25','PC','Standard','Corrida',54.99,69.99,29,'https://cdn.akamai.steamstatic.com/steam/apps/3059520/header.jpg','Simulação oficial de Fórmula 1.'),
  ('Euro Truck Simulator 2','Steam','Standard','Simulação',4.99,19.99,120,'https://cdn.akamai.steamstatic.com/steam/apps/227300/header.jpg','Simulador de camiões pela Europa.'),
  ('Cities Skylines II','Steam','Standard','Simulação',24.99,49.99,37,'https://cdn.akamai.steamstatic.com/steam/apps/949230/header.jpg','Construção e gestão de cidades modernas.'),
  ('Planet Zoo','Steam','Standard','Gestão',9.99,44.99,55,'https://cdn.akamai.steamstatic.com/steam/apps/703080/header.jpg','Gestão de jardim zoológico detalhado.'),
  ('Jurassic World Evolution 2','Steam','Standard','Gestão',12.99,59.99,43,'https://cdn.akamai.steamstatic.com/steam/apps/1244460/header.jpg','Gestão de parques com dinossauros.'),
  ('RimWorld','Steam','Standard','Estratégia',24.99,34.99,46,'https://cdn.akamai.steamstatic.com/steam/apps/294100/header.jpg','Simulador de colónia com histórias emergentes.'),
  ('Factorio','Steam','Standard','Estratégia',29.99,35.00,31,'https://cdn.akamai.steamstatic.com/steam/apps/427520/header.jpg','Automação industrial e construção eficiente.'),
  ('Satisfactory','Steam','Standard','Construção',24.99,39.99,42,'https://cdn.akamai.steamstatic.com/steam/apps/526870/header.jpg','Fábricas gigantes em mundo aberto.'),
  ('No Man''s Sky','Steam','Standard','Exploração',29.99,59.99,52,'https://cdn.akamai.steamstatic.com/steam/apps/275850/header.jpg','Exploração espacial com planetas infinitos.'),
  ('Subnautica','Steam','Standard','Sobrevivência',9.99,29.99,62,'https://cdn.akamai.steamstatic.com/steam/apps/264710/header.jpg','Sobrevivência subaquática alienígena.'),
  ('Subnautica Below Zero','Steam','Standard','Sobrevivência',12.99,29.99,48,'https://cdn.akamai.steamstatic.com/steam/apps/848450/header.jpg','Aventura gelada no universo Subnautica.'),
  ('ARK Survival Evolved','Steam','Standard','Sobrevivência',9.99,29.99,64,'https://cdn.akamai.steamstatic.com/steam/apps/346110/header.jpg','Sobrevivência com dinossauros e construção.'),
  ('Rust','Steam','Standard','Sobrevivência',26.99,39.99,53,'https://cdn.akamai.steamstatic.com/steam/apps/252490/header.jpg','Sobrevivência online competitiva.'),
  ('DayZ','Steam','Standard','Sobrevivência',24.99,49.99,42,'https://cdn.akamai.steamstatic.com/steam/apps/221100/header.jpg','Sobrevivência zombie multiplayer.'),
  ('Valheim','Steam','Standard','Sobrevivência',9.99,19.99,69,'https://cdn.akamai.steamstatic.com/steam/apps/892970/header.jpg','Sobrevivência viking cooperativa.'),
  ('Terraria','Steam','Standard','Aventura',4.99,9.99,140,'https://cdn.akamai.steamstatic.com/steam/apps/105600/header.jpg','Aventura 2D com exploração e crafting.'),
  ('Stardew Valley','Steam','Standard','Simulação',7.99,13.99,110,'https://cdn.akamai.steamstatic.com/steam/apps/413150/header.jpg','Quinta, amizade e aventura relaxante.'),
  ('Diablo IV','PC','Standard','RPG',34.99,69.99,39,'https://cdn.akamai.steamstatic.com/steam/apps/2344520/header.jpg','RPG de ação sombrio com loot.'),
  ('Path of Exile 2 Early Access','PC','Standard','RPG',24.99,29.99,40,'https://cdn.akamai.steamstatic.com/steam/apps/2694490/header.jpg','RPG de ação com builds profundas.'),
  ('Monster Hunter Wilds','Steam','Standard','Ação RPG',59.99,69.99,28,'https://cdn.akamai.steamstatic.com/steam/apps/2246340/header.jpg','Caça a monstros em ambientes vivos.'),
  ('Monster Hunter World','Steam','Standard','Ação RPG',14.99,29.99,60,'https://cdn.akamai.steamstatic.com/steam/apps/582010/header.jpg','Caça cooperativa com monstros gigantes.'),
  ('Dragon''s Dogma 2','Steam','Standard','RPG',39.99,64.99,32,'https://cdn.akamai.steamstatic.com/steam/apps/2054970/header.jpg','RPG de fantasia com companheiros e combate.'),
  ('Persona 5 Royal','Steam','Standard','RPG',29.99,59.99,44,'https://cdn.akamai.steamstatic.com/steam/apps/1687950/header.jpg','JRPG estiloso com história e combate por turnos.'),
  ('Metaphor ReFantazio','Steam','Standard','RPG',49.99,69.99,30,'https://cdn.akamai.steamstatic.com/steam/apps/2679460/header.jpg','RPG de fantasia dos criadores de Persona.'),
  ('Final Fantasy VII Remake Intergrade','Steam','Standard','RPG',39.99,79.99,34,'https://cdn.akamai.steamstatic.com/steam/apps/1462040/header.jpg','Remake moderno de um RPG lendário.'),
  ('Final Fantasy XVI','Steam','Standard','RPG',39.99,49.99,33,'https://cdn.akamai.steamstatic.com/steam/apps/2515020/header.jpg','RPG de ação com fantasia épica.'),
  ('Like a Dragon Infinite Wealth','Steam','Standard','RPG',39.99,69.99,31,'https://cdn.akamai.steamstatic.com/steam/apps/2072450/header.jpg','RPG moderno com humor e drama.'),
  ('Yakuza Like a Dragon','Steam','Standard','RPG',12.99,59.99,55,'https://cdn.akamai.steamstatic.com/steam/apps/1235140/header.jpg','RPG urbano com história marcante.'),
  ('Death Stranding Director''s Cut','Steam','Ultimate','Aventura',19.99,39.99,44,'https://cdn.akamai.steamstatic.com/steam/apps/1850570/header.jpg','Viagem cinematográfica num mundo destruído.'),
  ('Control Ultimate Edition','Steam','Ultimate','Ação',9.99,39.99,63,'https://cdn.akamai.steamstatic.com/steam/apps/870780/header.jpg','Ação sobrenatural com poderes e mistério.'),
  ('Silent Hill 2','Steam','Standard','Terror',49.99,69.99,27,'https://cdn.akamai.steamstatic.com/steam/apps/2124490/header.jpg','Terror psicológico moderno.'),
  ('Lies of P','Steam','Standard','Ação RPG',29.99,59.99,36,'https://cdn.akamai.steamstatic.com/steam/apps/1627720/header.jpg','Ação soulslike inspirada em Pinóquio.'),
  ('Armored Core VI Fires of Rubicon','Steam','Standard','Ação',34.99,59.99,38,'https://cdn.akamai.steamstatic.com/steam/apps/1888160/header.jpg','Combate de mechas rápido e técnico.'),
  ('Sekiro Shadows Die Twice','Steam','Standard','Ação',29.99,59.99,43,'https://cdn.akamai.steamstatic.com/steam/apps/814380/header.jpg','Ação samurai com combate preciso.'),
  ('Dark Souls III','Steam','Standard','RPG',29.99,59.99,41,'https://cdn.akamai.steamstatic.com/steam/apps/374320/header.jpg','RPG sombrio com desafio intenso.'),
  ('NieR Automata','Steam','Standard','Ação RPG',19.99,39.99,45,'https://cdn.akamai.steamstatic.com/steam/apps/524220/header.jpg','Ação filosófica com androides e mistério.'),
  ('Halo The Master Chief Collection','Xbox','Ultimate','FPS',14.99,39.99,63,'https://cdn.akamai.steamstatic.com/steam/apps/976730/header.jpg','Coleção clássica da saga Halo.'),
  ('Halo Infinite Campaign','Xbox','Standard','FPS',19.99,59.99,42,'https://cdn.akamai.steamstatic.com/steam/apps/1240440/header.jpg','Campanha sci-fi com combate Halo.'),
  ('Gears 5','Xbox','Standard','Ação',9.99,39.99,51,'https://cdn.akamai.steamstatic.com/steam/apps/1097840/header.jpg','Ação em terceira pessoa com campanha intensa.'),
  ('Microsoft Flight Simulator','Xbox','Standard','Simulação',39.99,69.99,30,'https://cdn.akamai.steamstatic.com/steam/apps/1250410/header.jpg','Simulação aérea realista.'),
  ('Age of Empires IV','Steam','Standard','Estratégia',19.99,39.99,50,'https://cdn.akamai.steamstatic.com/steam/apps/1466860/header.jpg','Estratégia histórica em tempo real.'),
  ('Total War Warhammer III','Steam','Standard','Estratégia',29.99,59.99,34,'https://cdn.akamai.steamstatic.com/steam/apps/1142710/header.jpg','Estratégia de fantasia em grande escala.'),
  ('Crusader Kings III','Steam','Standard','Estratégia',24.99,49.99,40,'https://cdn.akamai.steamstatic.com/steam/apps/1158310/header.jpg','Estratégia medieval com dinastias.'),
  ('Civilization VI','Steam','Standard','Estratégia',5.99,59.99,100,'https://cdn.akamai.steamstatic.com/steam/apps/289070/header.jpg','Estratégia por turnos para construir impérios.'),
  ('Frostpunk 2','Steam','Standard','Estratégia',34.99,44.99,29,'https://cdn.akamai.steamstatic.com/steam/apps/1601580/header.jpg','Gestão de sobrevivência numa cidade gelada.'),
  ('Anno 1800','PC','Standard','Estratégia',19.99,59.99,36,'https://cdn.akamai.steamstatic.com/steam/apps/916440/header.jpg','Construção de impérios industriais.'),
  ('Football Manager 2024','PC','Standard','Gestão',24.99,59.99,34,'https://cdn.akamai.steamstatic.com/steam/apps/2252570/header.jpg','Gestão profunda de clubes de futebol.'),
  ('Planet Coaster 2','Steam','Standard','Gestão',39.99,49.99,30,'https://cdn.akamai.steamstatic.com/steam/apps/2688950/header.jpg','Construção e gestão de parques temáticos.'),
  ('WWE 2K24','Steam','Standard','Desporto',29.99,59.99,35,'https://cdn.akamai.steamstatic.com/steam/apps/2315690/header.jpg','Wrestling com modos carreira e lendas.'),
  ('Street Fighter 6','Steam','Standard','Luta',29.99,59.99,39,'https://cdn.akamai.steamstatic.com/steam/apps/1364780/header.jpg','Luta competitiva com estilo moderno.'),
  ('Dragon Ball Sparking Zero','Steam','Standard','Luta',49.99,69.99,28,'https://cdn.akamai.steamstatic.com/steam/apps/1790600/header.jpg','Combates explosivos no universo Dragon Ball.'),
  ('Warhammer 40,000 Space Marine 2','Steam','Standard','Ação',44.99,59.99,31,'https://cdn.akamai.steamstatic.com/steam/apps/2183900/header.jpg','Ação brutal no universo Warhammer.'),
  ('Remnant II','Steam','Standard','Ação RPG',24.99,49.99,40,'https://cdn.akamai.steamstatic.com/steam/apps/1282100/header.jpg','Ação cooperativa com mundos perigosos.'),
  ('Borderlands 3','Steam','Standard','FPS',8.99,59.99,72,'https://cdn.akamai.steamstatic.com/steam/apps/397540/header.jpg','FPS looter shooter com humor e caos.')
)
insert into public.products (name, platform, edition, category, price, old_price, discount, stock, cover, description, active)
select name, platform, edition, category, price, old_price,
greatest(0, round((1 - (price / nullif(old_price, 0))) * 100)::int),
stock, cover, description, true
from games g
where not exists (
  select 1 from public.products p
  where lower(p.name) = lower(g.name)
  and p.platform = g.platform
  and coalesce(p.edition,'Standard') = g.edition
);

select 'OK - 100 jogos adicionados e edição de preços ativada' as resultado;
