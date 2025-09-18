import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/env.dart';
import '../data/repositories/auth_repository.dart';

class DI {
  DI._();
  static final DI I = DI._();

  late final SupabaseClient supabase;
  late final AuthRepository authRepository;

  Future<void> init() async {
    final supa = await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    supabase = supa.client;

    authRepository = AuthRepository(supabase);
  }
}

// Exporta um atalho global
final di = DI.I;
