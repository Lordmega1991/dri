import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'notas_avaliador_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginAvaliadorController = TextEditingController();
  final _senhaAvaliadorController = TextEditingController();
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  // Login com Google (OAuth) para Docentes e Discentes
  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );

      // O registro na users_access será tratado automaticamente pelo main.dart
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar com Google: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Acesso rápido para avaliadores
  Future<void> _acessoAvaliador() async {
    final login = _loginAvaliadorController.text.trim();
    final senha = _senhaAvaliadorController.text.trim();

    if (login.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha login e senha')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('dados_defesas')
          .select()
          .eq('login', login)
          .eq('senha', senha)
          .single();

      if (response != null) {
        final defesa = response as Map<String, dynamic>;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotasAvaliadorPage(defesa: defesa),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciais inválidas')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Credenciais inválidas ou defesa não encontrada')),
      );
    }
    setState(() => _isLoading = false);
  }

  void _showAvaliadorLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.groups_outlined, color: Color(0xFF667eea)),
            SizedBox(width: 8),
            Text('Acesso Avaliador'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use as credenciais fornecidas pela coordenação',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _loginAvaliadorController,
              decoration: const InputDecoration(
                labelText: 'Login',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _senhaAvaliadorController,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                    _acessoAvaliador();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5b8c00),
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Acessar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Column(
                  children: [
                    Text(
                      'Departamento de Relações Internacionais',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Secretaria Digital',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Column(
                  children: [
                    _buildAccessCard(
                      icon: Icons.groups_outlined,
                      title: 'Avaliadores de Banca',
                      subtitle: 'Acesso com credenciais fornecidas',
                      color: const Color(0xFF5b8c00),
                      onTap: _showAvaliadorLoginDialog,
                    ),
                    const SizedBox(height: 20),
                    _buildAccessCard(
                      icon: Icons.school_outlined,
                      title: 'Docentes',
                      subtitle: 'Acesso com Google',
                      color: const Color(0xFF667eea),
                      onTap: _loginWithGoogle,
                    ),
                    const SizedBox(height: 20),
                    _buildAccessCard(
                      icon: Icons.person_outlined,
                      title: 'Discentes',
                      subtitle: 'Acesso com Google',
                      color: const Color(0xFF764ba2),
                      onTap: _loginWithGoogle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: double.infinity,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
