# NutriTrack — Estratégia de Caching & Limites (Open Food Facts + Supabase)

> Objetivo: reduzir chamadas à Open Food Facts (OFF) e consumo de espaço/IO no Supabase, garantindo UX rápida e estável.

---

## 1) Resumo executivo

* **Leituras por código de barras**: usar endpoint OFF `GET /api/v2/product/{barcode}` (limite alto → 100 req/min).
* **Pesquisas por texto**: evitar search-as-you-type; usar cache local + 1 chamada no *submit* (OFF `/search`, 10 req/min).
* **Cache no Supabase**: tabela `products` (só texto essencial) + `product_history` (por utilizador).
* **Evicção**: remover produtos não tocados há 90 dias e não referenciados no histórico.
* **Atualização**: *refresh* a cada 30 dias por produto (lazy, no primeiro acesso).
* **Sem imagens**: não guardar imagens nem URLs de imagem (apenas texto) para poupar espaço.

---

## 2) Limites relevantes

* **/product** (por barcode): 100 req/min → ok para scans.
* **/search** (texto): 10 req/min → **usar debounce e submit**.
* **Facet** (categorias/labels): 2 req/min → **evitar em UI**, usar job ocasional com cache.

---

## 3) Modelo de dados (cache “magro”)

### Tabelas

* **`products`** (cache global, leitura pública via RLS `select using (true)`)

  * `barcode` (PK), `name`, `brand`, `nutriscore` (A–E), `kcal_100g`, `sugars_100g`, `fat_100g`, `salt_100g`,
    `categories`, `ingredients_text`, `allergens`, `last_fetched_at` (timestamptz)
* **`product_history`** (por utilizador, com RLS)

  * `id`, `user_id`, `barcode`, `name`, `nutriscore`, macros resumidas, `scanned_at`

### Índices úteis

* `pg_trgm` para `name` e `brand` (pesquisa por texto)
* `idx_product_history_user_date` (`user_id`, `scanned_at desc`)

---

## 4) Políticas RLS

* `products`: leitura pública (somente `select`), escrituras somente de serviço (via edge function) **ou** do cliente autenticado (se aceitarmos).
* `product_history`: `for all using (auth.uid() = user_id)`; o utilizador só vê/insere os seus.

---

## 5) Regras de cache & atualização

### Quando consultar OFF

* **Scan por barcode**:

  1. *Cache-first*: tenta `products`.
  2. Se não existir **ou** `last_fetched_at < now() - 30 dias`, chamar OFF `/product/{barcode}` e fazer `upsert`.
* **Pesquisa por texto**:

  * Enquanto o user digita → **só cache local** (`products`).
  * No *submit* (ou debounce ≥ 600–800 ms) → **1 request** OFF `/search` (page\_size 20–40).
  * Guardar **apenas** campos essenciais dos resultados.

### Evicção

* Job diário (Edge Function + Cron) que apaga de `products` entradas não tocadas há **90 dias** e sem referência em `product_history`.

---

## 6) SQL — estrutura mínima

```sql
-- Extensão para trigram search
create extension if not exists pg_trgm;

-- Cache de produtos (texto apenas)
create table if not exists public.products (
  barcode text primary key,
  name text,
  brand text,
  nutriscore text check (nutriscore in ('A','B','C','D','E')),
  kcal_100g int,
  sugars_100g numeric,
  fat_100g numeric,
  salt_100g numeric,
  categories text,
  ingredients_text text,
  allergens text,
  last_fetched_at timestamptz default now()
);

-- Índices para pesquisa por nome/marca
create index if not exists idx_products_name_trgm on public.products using gin (name gin_trgm_ops);
create index if not exists idx_products_brand_trgm on public.products using gin (brand gin_trgm_ops);

-- Histórico do utilizador
create table if not exists public.product_history (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete cascade,
  barcode text not null,
  name text,
  nutriscore text check (nutriscore in ('A','B','C','D','E')),
  calories integer,
  sugars numeric,
  fats numeric,
  salt numeric,
  scanned_at timestamptz default now()
);
create index if not exists idx_product_history_user_date on public.product_history(user_id, scanned_at desc);

-- RLS
alter table public.products enable row level security;
create policy if not exists "read products cache" on public.products for select using (true);

alter table public.product_history enable row level security;
create policy if not exists "history_crud_self" on public.product_history
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

### UPSERT (refresco de cache)

```sql
insert into public.products (
  barcode, name, brand, nutriscore,
  kcal_100g, sugars_100g, fat_100g, salt_100g,
  categories, ingredients_text, allergens, last_fetched_at
) values (
  $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, now()
)
on conflict (barcode) do update set
  name = excluded.name,
  brand = excluded.brand,
  nutriscore = excluded.nutriscore,
  kcal_100g = excluded.kcal_100g,
  sugars_100g = excluded.sugars_100g,
  fat_100g = excluded.fat_100g,
  salt_100g = excluded.salt_100g,
  categories = excluded.categories,
  ingredients_text = excluded.ingredients_text,
  allergens = excluded.allergens,
  last_fetched_at = now();
```

### Evicção (retention)

```sql
delete from public.products p
where p.last_fetched_at < now() - interval '90 days'
  and not exists (
    select 1 from public.product_history h where h.barcode = p.barcode
  );
```

---

## 7) Regras de chamada (lado do app)

* **Debounce** input (≥ 600–800 ms) e mínimo 3 caracteres antes de pesquisar.
* **Cooldown** de 3–5 s entre *submits* de pesquisa para o mesmo termo.
* **Paginar** resultados (ex.: 20 por página).
* **Retry** com *exponential backoff* (p.ex., 500ms, 1s, 2s) apenas 2–3 tentativas.
* **Circuit breaker**: se OFF devolver 429/5xx, suspender buscas externas por 1–2 minutos e trabalhar só com cache.

---

## 8) Edge Function (opcional, recomendado)

* **Proxy OFF**: chamar OFF a partir de uma Edge Function (para esconder lógica/normalizar resposta/limitar requests por IP).
* **Cron diário**: executar a limpeza/evicção e (opcional) *refresh* de produtos muito populares.
* **Rate limiting server-side**: por `user_id`/IP para `/search`.

Pseudo-código de função proxy `/product/{barcode}`:

```ts
// 1) procurar em Supabase.products
// 2) se stale/miss → pedir à OFF → mapear → upsert
// 3) devolver payload magro ao cliente
```

---

## 9) Mapeamento OFF → modelo (texto-only)

Campos recomendados por 100g:

* `product.code` → `barcode`
* `product.product_name` → `name`
* `product.brands` → `brand`
* `product.nutriscore_grade` (A–E) → `nutriscore` (uppercase)
* `product.nutriments.energy-kcal_100g` → `kcal_100g`
* `...sugars_100g`, `...fat_100g`, `...salt_100g`
* `product.categories`, `product.ingredients_text`, `product.allergens`

---

## 10) Estimativa de espaço

* Registo "magro" ≈ **0.5–1.0 KB** (texto curto + índices).
* Com 500 MB (free), cabem **\~200k–600k** produtos *cacheados* (depende de índices/overhead).
* Evicção a 90 dias reduz crescimento e mantém DB estável.

---

## 11) Testes & Checklist

* [ ] Debounce ativo (≥ 600ms) e mínimo 3 chars.
* [ ] Pesquisa local retorna resultados instantâneos.
* [ ] Submit faz **1 request** OFF `/search` por termo.
* [ ] Scan por barcode faz cache-first e upsert.
* [ ] Evicção diária a correr (manual/cron) sem afetar histórico.
* [ ] RLS correta: `product_history` isolado por utilizador; `products` leitura pública.
* [ ] Logs/telemetria: contagem de misses/hits e erros 429/5xx.

---

## 12) Flags & Configs (.env)

* `CACHE_REFRESH_DAYS=30`
* `CACHE_EVICT_DAYS=90`
* `SEARCH_DEBOUNCE_MS=700`
* `SEARCH_PAGE_SIZE=20`
* `SEARCH_SUBMIT_COOLDOWN_MS=3000`

> Estas flags podem ser lidas pelo app e/ou Edge Functions para manter comportamento consistente entre ambientes.

---

## 13) Futuro (se houver tempo)

* Full-Text Search (FTS) com dicionário PT.
* Ranking por categoria (ex.: melhores iogurtes) usando materialized views.
* Sugestões de alternativas mais saudáveis: tabela `product_alternatives` (mapeada por categoria/nutriscore).

---

**Conclusão**: com cache-first, atualização a 30 dias, evicção a 90 dias e *debounce* nas buscas, o app permanece sob os limites da OFF e do Supabase, com uma UX rápida e previsível.
