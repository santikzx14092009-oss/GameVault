# GameVault Online - Passo a passo

## 1. Criar projeto Supabase

1. Vai a https://supabase.com
2. Cria conta
3. Clica em `New project`
4. Guarda a password da base de dados
5. Espera o projeto criar

## 2. Criar tabelas

1. No Supabase, vai a `SQL Editor`
2. Clica `New query`
3. Cola tudo do ficheiro `supabase-schema.sql`
4. Clica `Run`

## 3. Copiar chaves

1. Vai a `Project Settings`
2. Vai a `API`
3. Copia:
   - `Project URL`
   - `anon public key`

## 4. Meter no HTML

Abre `gamevault-online.html` e troca:

```js
const SUPABASE_URL = "COLOCA_AQUI_O_SUPABASE_URL";
const SUPABASE_ANON_KEY = "COLOCA_AQUI_O_SUPABASE_ANON_KEY";
```

pelas tuas chaves.

## 5. Criar a tua conta admin

1. Abre o site
2. Cria conta com o teu email
3. No Supabase, vai ao `Table Editor`
4. Abre a tabela `profiles`
5. Encontra o teu email
6. Muda `role` de `customer` para `admin`

Depois faz login novamente no site. O painel admin aparece.

## 6. Publicar

Publica o ficheiro `gamevault-online.html` como `index.html` no Vercel/Netlify.

Agora as compras, keys, cupoes, suporte e admin ficam online de verdade.
