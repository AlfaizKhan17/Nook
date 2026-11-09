import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name.trim(),
        'phone': phone.trim(),
      },
    );

    final user = response.user;
    if (user == null) throw Exception('Registration failed.');

    // When email confirmation is enabled, Supabase may not create a session
    // yet. The database auth.users trigger creates the profile in that case.
    // With an active session, upsert also makes profile creation resilient.
    if (response.session != null) {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
      }, onConflict: 'id');
    }

    return response;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('No logged-in user.');
    }

    await _supabase
        .from('profiles')
        .update({
      'name': name,
      'phone': phone,
    })
        .eq('id', user.id);
  }
}