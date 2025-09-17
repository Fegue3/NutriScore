
# NutriScore — Supabase Schema Overview

> **Stack:** PostgreSQL (Supabase) • RLS enabled • Auth via `auth.users` • Extension: `pg_trgm`  
> **Objetivo:** suportar perfis de utilizador, preferências nutricionais, registo de refeições, cache de produtos (Open Food Facts, etc.) e histórico de scans.

---

## 1) Extensões

- `pg_trgm`: permite índices GIN com trigramas para pesquisa de texto “fuzzy” (nome/marca de produtos).

```sql
create extension if not exists pg_trgm;
```

---

## 2) Tabelas e Colunas

### 2.1 `public.profiles`
Perfil básico do utilizador (1:1 com `auth.users`).

| Coluna       | Tipo        | Notas                                                        |
|--------------|-------------|--------------------------------------------------------------|
| `id`         | `uuid` PK   | FK → `auth.users(id)`, `on delete cascade`                   |
| `full_name`  | `text`      | Nome do utilizador                                           |
| `created_at` | `timestamptz` | `default now()`                                            |
| `updated_at` | `timestamptz` | `default now()`                                            |

RLS: **ativado**

---

### 2.2 `public.preferences`
Preferências e metas do utilizador (1:1).

| Coluna          | Tipo          | Notas                                       |
|-----------------|---------------|---------------------------------------------|
| `user_id`       | `uuid` PK     | FK → `auth.users(id)`, `on delete cascade`  |
| `calorie_goal`  | `int`         | Meta calórica diária                        |
| `low_salt`      | `boolean`     | `default false`                             |
| `low_sugar`     | `boolean`     | `default false`                             |
| `low_fat`       | `boolean`     | `default false`                             |
| `created_at`    | `timestamptz` | `default now()`                             |
| `updated_at`    | `timestamptz` | `default now()`                             |

RLS: **ativado**

---

### 2.3 `public.meal_logs`
Registo de refeições dos utilizadores (1:N).

| Coluna       | Tipo           | Notas                                                                                   |
|--------------|----------------|-----------------------------------------------------------------------------------------|
| `id`         | `bigserial` PK |                                                                                         |
| `user_id`    | `uuid`         | FK → `auth.users(id)`, `on delete cascade`                                              |
| `meal_type`  | `text`         | **CHECK**: um de `('pequeno-almoço','almoço','jantar','snack')`, `default 'snack'`     |
| `item_name`  | `text`         | **NOT NULL**                                                                            |
| `calories`   | `int`          | `default 0`                                                                             |
| `protein`    | `numeric`      | `default 0`                                                                             |
| `carbs`      | `numeric`      | `default 0`                                                                             |
| `fat`        | `numeric`      | `default 0`                                                                             |
| `logged_at`  | `timestamptz`  | `default now()`                                                                         |

Índices:
```sql
create index if not exists idx_meal_logs_user_date on public.meal_logs(user_id, logged_at desc);
```
RLS: **ativado**

---

### 2.4 `public.products` (cache texto-only)
Cache de produtos (ex.: Open Food Facts). Leitura pública; escrita por utilizadores autenticados.

| Coluna            | Tipo     | Notas                                                                 |
|-------------------|----------|-----------------------------------------------------------------------|
| `barcode`         | `text` PK| Identificador do produto                                             |
| `name`            | `text`   | Nome                                                                 |
| `brand`           | `text`   | Marca                                                                |
| `categories`      | `text`   | Categorias                                                           |
| `ingredients_text`| `text`   | Ingredientes                                                         |
| `allergens`       | `text`   | Alergénios                                                           |
| `kcal_100g`       | `int`    | kcal por 100g                                                        |
| `sugars_100g`     | `numeric`| g de açúcar por 100g                                                 |
| `fat_100g`        | `numeric`| g de gordura por 100g                                                |
| `salt_100g`       | `numeric`| g de sal por 100g                                                    |
| `nutriscore`      | `text`   | **CHECK**: `('A','B','C','D','E')`                                   |
| `nova_group`      | `int`    | **CHECK**: entre `1` e `4`                                           |
| `ecoscore_grade`  | `text`   | **CHECK**: `('a','b','c','d','e')`                                   |
| `labels`          | `text`   | Rótulos (ex.: bio, vegan...)                                         |
| `last_fetched_at` | `timestamptz` | `default now()`                                                 |

Índices de pesquisa por trigramas:
```sql
create index if not exists idx_products_name_trgm on public.products using gin (name gin_trgm_ops);
create index if not exists idx_products_brand_trgm on public.products using gin (brand gin_trgm_ops);
```
RLS: **ativado**

---

### 2.5 `public.product_history`
Histórico de scans/pesquisas por utilizador (1:N). Captura o estado do produto no momento do scan.

| Coluna       | Tipo           | Notas                                           |
|--------------|----------------|-------------------------------------------------|
| `id`         | `bigserial` PK |                                                 |
| `user_id`    | `uuid`         | FK → `auth.users(id)`, `on delete cascade`      |
| `barcode`    | `text`         | Código do produto                               |
| `name`       | `text`         | Nome no momento do scan                         |
| `nutriscore` | `text`         | **CHECK**: `('A','B','C','D','E')`              |
| `calories`   | `int`          |                                                 |
| `sugars`     | `numeric`      |                                                 |
| `fats`       | `numeric`      |                                                 |
| `salt`       | `numeric`      |                                                 |
| `scanned_at` | `timestamptz`  | `default now()`                                 |

Índice:
```sql
create index if not exists idx_product_history_user_date on public.product_history(user_id, scanned_at desc);
```
RLS: **ativado**

---

## 3) Triggers e Funções utilitárias

### 3.1 `public.set_updated_at()`
Função de trigger que atualiza `updated_at` **antes** de `UPDATE`:

```sql
create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end$$;
```

Aplicada nas tabelas:
```sql
create trigger trg_profiles_updated before update on public.profiles
for each row execute function public.set_updated_at();

create trigger trg_prefs_updated before update on public.preferences
for each row execute function public.set_updated_at();
```

---

## 4) RLS — Row Level Security (Políticas)

### 4.1 `public.profiles`
- **SELECT**: o utilizador só lê o seu perfil.
- **INSERT/UPDATE**: apenas quando `auth.uid() = id`.

```sql
create policy if not exists "profiles_read_own" on public.profiles
  for select using (auth.uid() = id);

create policy if not exists "profiles_upsert_own" on public.profiles
  for insert with check (auth.uid() = id);

create policy if not exists "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);
```

### 4.2 `public.preferences`
- **SELECT/INSERT/UPDATE**: apenas quando `auth.uid() = user_id`.

```sql
create policy if not exists "prefs_read_own" on public.preferences
  for select using (auth.uid() = user_id);

create policy if not exists "prefs_upsert_own" on public.preferences
  for insert with check (auth.uid() = user_id);

create policy if not exists "prefs_update_own" on public.preferences
  for update using (auth.uid() = user_id);
```

### 4.3 `public.meal_logs`
- **CRUD completo** restrito ao dono do registo:

```sql
create policy if not exists "meals_crud_self" on public.meal_logs
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

### 4.4 `public.products`
- **Leitura pública** (qualquer utilizador).
- **INSERT/UPDATE** apenas para `auth.role() = 'authenticated'` (utilizadores autenticados).

```sql
create policy if not exists "products_read_all" on public.products
  for select using (true);

create policy if not exists "products_upsert_auth" on public.products
  for insert with check (auth.role() = 'authenticated');

create policy if not exists "products_update_auth" on public.products
  for update using (auth.role() = 'authenticated');
```

### 4.5 `public.product_history`
- **CRUD completo** restrito ao dono:

```sql
create policy if not exists "history_crud_self" on public.product_history
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

---

## 5) Resumo (em 6 pontos)

1. **Autenticação & Identidade** via `auth.users`; tabelas de domínio referenciam `auth.users(id)` com *cascade delete*.
2. **Perfis** (`profiles`) e **preferências** (`preferences`) são 1:1 com o utilizador, com `updated_at` auto-atualizado por trigger.
3. **Registo de refeições** (`meal_logs`) guarda o que o utilizador come (tipo de refeição, macros, kcal) com índice por `user_id+data`.
4. **Produtos** (`products`) é uma **cache** local de fontes externas (OFF), com leitura pública e escrita por autenticados; pesquisa rápida via `pg_trgm`.
5. **Histórico de scans** (`product_history`) fixa o estado do produto no momento da leitura, por utilizador, indexado por data.
6. **RLS** em todas as tabelas (exceto leitura pública de `products`) para assegurar que cada utilizador só vê/altera os seus próprios registos.

---

## 6) Exemplo de Upsert (cache `products`)

```sql
insert into public.products as p (
  barcode, name, brand, categories, ingredients_text, allergens,
  kcal_100g, sugars_100g, fat_100g, salt_100g,
  nutriscore, nova_group, ecoscore_grade, labels, last_fetched_at
) values (
  $1, $2, $3, $4, $5, $6,
  $7, $8, $9, $10,
  $11, $12, $13, $14, now()
)
on conflict (barcode) do update set
  name = excluded.name,
  brand = excluded.brand,
  categories = excluded.categories,
  ingredients_text = excluded.ingredients_text,
  allergens = excluded.allergens,
  kcal_100g = excluded.kcal_100g,
  sugars_100g = excluded.sugars_100g,
  fat_100g = excluded.fat_100g,
  salt_100g = excluded.salt_100g,
  nutriscore = excluded.nutriscore,
  nova_group = excluded.nova_group,
  ecoscore_grade = excluded.ecoscore_grade,
  labels = excluded.labels,
  last_fetched_at = now();
```

> **Nota:** ajustar os parâmetros `$1..$14` conforme o mapeamento da tua Edge Function/cliente.

---

## 7) Consultas úteis (snippets)

- **Top 10 refeições recentes do utilizador**
```sql
select *
from public.meal_logs
where user_id = auth.uid()
order by logged_at desc
limit 10;
```

- **Pesquisa por produtos por nome/marca (fuzzy)**
```sql
select barcode, name, brand, nutriscore
from public.products
where name % $1 or brand % $1   -- operador trigram
order by greatest(similarity(name, $1), similarity(brand, $1)) desc
limit 20;
```

- **Histórico de scans do utilizador (últimos 30 dias)**
```sql
select *
from public.product_history
where user_id = auth.uid()
  and scanned_at >= now() - interval '30 days'
order by scanned_at desc;
```

---

### 8) Sugestões rápidas (opcional)
- Consistência: `fats` → `fat` em `product_history` para alinhar com outras tabelas.
- Constraints: `CHECK (calories >= 0)`, `protein >= 0`, etc.
- Tipos: considerar `ENUM` para `meal_type` e `nutriscore`/`ecoscore_grade`.
- Precisão: `numeric(6,2)` para macros e sais/açúcares por consistência.

---

**Licença / Nota:** Este documento resume o schema fornecido, preparado para colar em `docs/supabase_schema.md` do projeto.
