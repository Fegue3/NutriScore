# 📦 Estrutura do Projeto NutriTrack

```plaintext
└─ nutritrack
   ├─ .gitignore
   ├─ README.md
   ├─ analysis_options.yaml
   ├─ pubspec.yaml
   ├─ .env.example
   ├─ android
   ├─ ios
   ├─ web
   ├─ macos
   ├─ windows
   ├─ linux
   ├─ lib
   │  ├─ main.dart
   │  ├─ app
   │  │  ├─ router
   │  │  │  └─ app_router.dart
   │  │  ├─ app_shell.dart
   │  │  └─ di.dart
   │  ├─ core
   │  │  ├─ theme.dart
   │  │  ├─ constants.dart
   │  │  ├─ env.dart
   │  │  └─ widgets
   │  │     └─ app_bottom_nav.dart
   │  ├─ data
   │  │  ├─ models
   │  │  │  └─ user_profile.dart
   │  │  ├─ sources
   │  │  │  ├─ supabase_client.dart
   │  │  │  └─ external_api_client.dart
   │  │  └─ repositories
   │  │     └─ auth_repository.dart
   │  ├─ features
   │  │  ├─ auth
   │  │  │  ├─ sign_in_screen.dart
   │  │  │  ├─ sign_up_screen.dart
   │  │  │  └─ session_guard.dart
   │  │  ├─ home
   │  │  │  └─ home_screen.dart
   │  │  ├─ nutrition
   │  │  │  └─ nutrition_screen.dart
   │  │  └─ settings
   │  │     └─ settings_screen.dart
   │  └─ utils
   │     └─ result.dart
   ├─ supabase
   │  ├─ README.md
   │  ├─ migrations
   │  │  └─ 0001_init.sql
   │  └─ seeds
   │     └─ 0001_demo.sql
   └─ docs
      ├─ env.md
      ├─ supabase-schema.md
      └─ design
         ├─ tokens.md
         ├─ components.md
         ├─ guidelines.md
         └─ screens.md
```