# Ambiente & Secrets

Cria um `.env` local (baseado no `.env.example`) e **não commits**.

Variáveis:
- `SUPABASE_URL=https://YOUR-ref.supabase.co`
- `SUPABASE_ANON_KEY=YOUR-ANON-KEY`

Como correr localmente:
```bash
flutter run \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
