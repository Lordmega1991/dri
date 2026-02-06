// auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Verificar se o usuário está autenticado e criar registro se necessário
  Future<void> handleUserAfterAuth(int accessLevel) async {
    final User? user = supabase.auth.currentUser;

    if (user != null) {
      await _createUserAccessRecord(
        user.id,
        user.email ?? '',
        user.userMetadata?['full_name'] ?? user.email ?? 'Usuário',
        accessLevel,
      );
    }
  }

  // Criar ou atualizar registro na tabela users_access
  Future<void> _createUserAccessRecord(
      String userId, String email, String fullName, int accessLevel) async {
    try {
      await supabase.from('users_access').upsert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'access_level': accessLevel,
        'allowed_pages': _getAllowedPages(accessLevel),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Erro ao criar registro de acesso: $e');
    }
  }

  // Definir páginas permitidas baseado no nível de acesso
  List<String> _getAllowedPages(int accessLevel) {
    switch (accessLevel) {
      case 1: // Discente
        return ['home', 'projetos', 'perfil'];
      case 2: // Docente
        return ['home', 'projetos', 'avaliacoes', 'perfil'];
      default:
        return ['home', 'perfil'];
    }
  }
}
