import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatefulWidget {
  final String currentUserId; // ID do usuário logado

  const ManageUsersPage({
    super.key,
    required this.currentUserId,
  });

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> usersFuture;

  @override
  void initState() {
    super.initState();
    usersFuture = fetchUsers();
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final response = await supabase
        .from('users_access')
        .select()
        .order('nomecompleto', ascending: true);
    return response;
  }

  /// Descrição dos níveis
  String getAccessLevelDescription(int level) {
    switch (level) {
      case 0:
        return 'Bloqueado';
      case 1:
        return 'Leitor (somente visualizar)';
      case 2:
        return 'Usuário (ações básicas)';
      case 3:
        return 'Gestor (alterações maiores)';
      case 4:
        return 'Administrador (módulos restritos)';
      case 5:
        return 'Super Admin (acesso total)';
      default:
        return 'Desconhecido';
    }
  }

  /// Cores dos níveis
  Color getAccessLevelColor(int level) {
    switch (level) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.yellow.shade800;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  /// Atualiza nível no banco
  Future<void> updateAccessLevel(String userId, int newLevel) async {
    await supabase.from('users_access').update({
      'access_level': newLevel,
    }).eq('id', userId);

    setState(() {
      usersFuture = fetchUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gerenciar Usuários"),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: usersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final String id = user['id'];
              final String nome = user['nomecompleto'] ?? 'Sem nome';
              final int level = user['access_level'] ?? 0;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(nome),
                  subtitle: Text(
                    'Nível: ${getAccessLevelDescription(level)}',
                    style: TextStyle(
                      color: getAccessLevelColor(level),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: id == widget.currentUserId
                      ? const Text(
                          "Você",
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        )
                      : DropdownButton<int>(
                          value: level,
                          onChanged: (value) {
                            if (value != null) {
                              updateAccessLevel(id, value);
                            }
                          },
                          items: [
                            for (int i = 0; i <= 5; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  '$i - ${getAccessLevelDescription(i)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
