# NutriScore — Supabase Schema Overview

> **Stack:** PostgreSQL (Supabase) • RLS enabled • Auth via `auth.users` • Extension: `pg_trgm`
> **Objetivo:** suportar perfis de utilizador, preferências nutricionais, registo de refeições, cache de produtos (Open Food Facts, etc.) e histórico de scans.

---

## 1) Extensões

* `pg_trgm`: permite índices GIN com trigramas para pesquisa de texto “fuzzy” (nome/marca de produtos).

```sql
create extension if not exists pg_trgm;
```

---

## 2) Tipos (ENUMs)

```sql
create type meal_type as enum ('pequeno-almoço','almoço','jantar','snack');
create type nutriscore_grade as enum ('A','B','C','D','E');
create type ecoscore_grade as enum ('a','b','c','d','e');
```

---

## 3) Tabelas e Colunas

### 3.1 `public.profiles`

Perfil básico do utilizador (1:1 com `auth.users`).

| Coluna       | Tipo          | Notas                                      |
| ------------ | ------------- | ------------------------------------------ |
| `id`         | `uuid` PK     | FK → `auth.users(id)`, `on delete cascade` |
| `full_name`  | `text`        | Nome do utilizador                         |
| `created_at` | `timestamptz` | `default now()`                            |
| `updated_at` | `timestamptz` | `default now()`                            |

---

### 3.2 `public.preferences`

Preferências e metas do utilizador (1:1).

| Coluna         | Tipo          | Notas                                      |
| -------------- | ------------- | ------------------------------------------ |
| `user_id`      | `uuid` PK     | FK → `auth.users(id)`, `on delete cascade` |
| `calorie_goal` | `int`         | `check (calorie_goal >= 0)`                |
| `low_salt`     | `boolean`     | `default false`                            |
| `low_sugar`    | `boolean`     | `default false`                            |
| `low_fat`      | `boolean`     | `default false`                            |
| `created_at`   | `timestamptz` | `default now()`                            |
| `updated_at`   | `timestamptz` | `default now()`                            |

---

### 3.3 `public.meal_logs`

Registo de refeições dos utilizadores (1\:N).

| Coluna      | Tipo           | Notas                                      |
| ----------- | -------------- | ------------------------------------------ |
| `id`        | `bigserial` PK |                                            |
| `user_id`   | `uuid`         | FK → `auth.users(id)`, `on delete cascade` |
| `meal_type` | `meal_type`    | `default 'snack'`                          |
| `item_name` | `text`         | **NOT NULL**                               |
| `calories`  | `int`          | `default 0 check (calories >= 0)`          |
| `protein`   | `numeric(6,2)` | `default 0 check (protein >= 0)`           |
| `carbs`     | `numeric(6,2)` | `default 0 check (carbs >= 0)`             |
| `fat`       | `numeric(6,2)` | `default 0 check (fat >= 0)`               |
| `logged_at` | `timestamptz`  | `default now()`                            |

Índice:

```sql
create index if not exists idx_meal_logs_user_date on public.meal_logs(user_id, logged_at desc);
```

---

### 3.4 `public.products` (cache texto-only)

Cache de produtos (ex.: Open Food Facts). Leitura pública; escrita por utilizadores autenticados.

| Coluna             | Tipo               | Notas                                |
| ------------------ | ------------------ | ------------------------------------ |
| `barcode`          | `text` PK          | Identificador do produto             |
| `name`             | `text`             | Nome                                 |
| `brand`            | `text`             | Marca                                |
| `categories`       | `text`             | Categorias                           |
| `ingredients_text` | `text`             | Ingredientes                         |
| `allergens`        | `text`             | Alergénios                           |
| `kcal_100g`        | `int`              | `check (kcal_100g >= 0)`             |
| `sugars_100g`      | `numeric(6,2)`     | `check (sugars_100g >= 0)`           |
| `fat_100g`         | `numeric(6,2)`     | `check (fat_100g >= 0)`              |
| `salt_100g`        | `numeric(6,2)`     | `check (salt_100g >= 0)`             |
| `nutriscore`       | `nutriscore_grade` |                                      |
| `nova_group`       | `int`              | `check (nova_group between 1 and 4)` |
| `ecoscore_grade`   | `ecoscore_grade`   |                                      |
| `labels`           | `text`             | Rótulos (ex.: bio, vegan...)         |
| `last_fetched_at`  | `timestamptz`      | `default now()`                      |

Índices:

```sql
create index if not exists idx_products_name_trgm on public.products using gin (name gin_trgm_ops);
create index if not exists idx_products_brand_trgm on public.products using gin (brand gin_trgm_ops);
```

---

### 3.5 `public.product_history`

Histórico de scans/pesquisas por utilizador (1\:N).

| Coluna       | Tipo               | Notas                                      |
| ------------ | ------------------ | ------------------------------------------ |
| `id`         | `bigserial` PK     |                                            |
| `user_id`    | `uuid`             | FK → `auth.users(id)`, `on delete cascade` |
| `barcode`    | `text`             | Código do produto                          |
| `name`       | `text`             | Nome no momento do scan                    |
| `nutriscore` | `nutriscore_grade` |                                            |
| `calories`   | `int`              | `check (calories >= 0)`                    |
| `sugars`     | `numeric(6,2)`     | `check (sugars >= 0)`                      |
| `fat`        | `numeric(6,2)`     | `check (fat >= 0)`                         |
| `salt`       | `numeric(6,2)`     | `check (salt >= 0)`                        |
| `scanned_at` | `timestamptz`      | `default now()`                            |

Índice:

```sql
create index if not exists idx_product_history_user_date on public.product_history(user_id, scanned_at desc);
```

---

## 4) Triggers

### 4.1 `public.set_updated_at()`

```sql
create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end$$;

create trigger trg_profiles_updated before update on public.profiles
for each row execute function public.set_updated_at();

create trigger trg_prefs_updated before update on public.preferences
for each row execute function public.set_updated_at();
```

---

## 5) RLS — Row Level Security (Políticas)

### 5.1 `public.profiles`

```sql
drop policy if exists "profiles_read_own" on public.profiles;
create policy "profiles_read_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_upsert_own" on public.profiles;
create policy "profiles_upsert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);
```

---

### 5.2 `public.preferences`

```sql
drop policy if exists "prefs_read_own" on public.preferences;
create policy "prefs_read_own" on public.preferences
  for select using (auth.uid() = user_id);

drop policy if exists "prefs_upsert_own" on public.preferences;
create policy "prefs_upsert_own" on public.preferences
  for insert with check (auth.uid() = user_id);

drop policy if exists "prefs_update_own" on public.preferences;
create policy "prefs_update_own" on public.preferences
  for update using (auth.uid() = user_id);
```

---

### 5.3 `public.meal_logs`

```sql
drop policy if exists "meals_crud_self" on public.meal_logs;
create policy "meals_crud_self" on public.meal_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

---

### 5.4 `public.products`

```sql
drop policy if exists "products_read_all" on public.products;
create policy "products_read_all" on public.products
  for select using (true);

drop policy if exists "products_upsert_auth" on public.products;
create policy "products_upsert_auth" on public.products
  for insert with check (auth.role() = 'authenticated');

drop policy if exists "products_update_auth" on public.products;
create policy "products_update_auth" on public.products
  for update using (auth.role() = 'authenticated');
```

---

### 5.5 `public.product_history`

```sql
drop policy if exists "history_crud_self" on public.product_history;
create policy "history_crud_self" on public.product_history
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

---

## 6) Resumo

1. **Autenticação**: via `auth.users`; FKs com *cascade delete*.
2. **Perfis** e **preferências**: 1:1, `updated_at` via trigger.
3. **Refeições**: logs por utilizador, macros validados.
4. **Produtos**: cache local, fuzzy search (`pg_trgm`).
5. **Histórico**: snapshots de scans com índice temporal.
6. **RLS**: cada utilizador só acede aos seus dados.

---
