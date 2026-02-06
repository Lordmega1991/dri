// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_defesas_page.dart';
import 'manage_users_page.dart';
import 'login_page.dart';
import 'envio_documentos_secretaria.dart';
import 'gerenciamento_semestre_page.dart';
import 'gestao_docentes_page.dart';
import 'minhas_defesas.dart';

class HomePage extends StatefulWidget {
  final User currentUser;
  const HomePage({super.key, required this.currentUser});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  Map<String, dynamic>? userData;
  int minhasBancasCount = 0;
  List<Map<String, dynamic>> proximasBancas = [];

  @override
  void initState() {
    super.initState();
    fetchUserAccess();
  }

  Future<void> fetchUserAccess() async {
    final user = widget.currentUser;
    try {
      final response = await supabase
          .from('users_access')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          userData = response as Map<String, dynamic>?;
        });

        // Após carregar dados do usuário, buscar bancas
        final fullName = userData?['nomecompleto'] ?? userData?['full_name'];
        if (fullName != null) {
          final hoje = DateTime.now().toIso8601String().split('T')[0];
          final defesasResp = await supabase
              .from('dados_defesas')
              .select()
              .or('orientador.ilike.%$fullName%,coorientador.ilike.%$fullName%,avaliador1.ilike.%$fullName%,avaliador2.ilike.%$fullName%,avaliador3.ilike.%$fullName%')
              .gte('dia', hoje)
              .order('dia', ascending: true);

          if (mounted) {
            setState(() {
              proximasBancas =
                  List<Map<String, dynamic>>.from(defesasResp as List);
              minhasBancasCount = proximasBancas.length;
              loading = false;
            });
          }
        } else {
          setState(() => loading = false);
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar dados do usuário: $e');
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Bom dia";
    if (hour < 18) return "Boa tarde";
    return "Boa noite";
  }

  List<_MenuData> _getAvailableMenus(int accessLevel) {
    final menus = <_MenuData>[];

    final envioDocs = _MenuData(
      icon: Icons.upload_file_rounded,
      title: "Secretaria",
      subtitle: "Envio de Documentos",
      color: const Color(0xFF3B82F6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const EnvioDocumentosSecretariaPage()),
      ),
    );

    final gerenSemestre = _MenuData(
      icon: Icons.calendar_month_rounded,
      title: "Semestre",
      subtitle: "Aulas e Atividades",
      color: const Color(0xFF6366F1),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GerenciamentoSemestrePage()),
      ),
    );

    final defesasTcc = _MenuData(
      icon: Icons.school_rounded,
      title: "TCC",
      subtitle: "Bancas de Defesa",
      color: const Color(0xFF8B5CF6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HomeDefesasPage()),
      ),
    );

    final gerenUsuarios = _MenuData(
      icon: Icons.people_rounded,
      title: "Usuários",
      subtitle: "Gestão de Acessos",
      color: const Color(0xFF10B981),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManageUsersPage(
            currentUserId: widget.currentUser.id,
          ),
        ),
      ),
    );

    final gestaoDocentes = _MenuData(
      icon: Icons.assignment_rounded,
      title: "Docentes",
      subtitle: "Relatórios e Horários",
      color: const Color(0xFFF59E0B),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GestaoDocentesPage()),
      ),
    );

    // Filter menus based on access level
    if (accessLevel == 1) {
      menus.add(envioDocs);
    } else if (accessLevel >= 2 && accessLevel <= 3) {
      menus.addAll([gerenSemestre, defesasTcc, envioDocs]);
    } else if (accessLevel >= 4) {
      menus.addAll([
        gerenSemestre,
        defesasTcc,
        gestaoDocentes, // Agora em 3º
        envioDocs, // Agora em 4º
        gerenUsuarios, // Agora em 5º
      ]);
    }

    return menus;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        ),
      );
    }

    final accessLevel = userData?['access_level'] ?? 0;
    if (accessLevel == 0) return _buildAccessDenied();

    final menus = _getAvailableMenus(accessLevel);
    final user = widget.currentUser;
    final fullName = user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        user.email?.split('@').first ??
        'Usuário';
    final photoUrl = user.userMetadata?['avatar_url'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Ultra-Compact Header - Enhanced Standout
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color:
                    const Color(0xFFE0F2FE), // Azul leve um pouco mais saturado
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0369A1).withOpacity(0.12),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: BorderDirectional(
                  bottom: BorderSide(color: Colors.blue.shade100, width: 1),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      width: 50, // Aumentado levemente
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? const Icon(Icons.person_rounded,
                                color: Color(0xFF0284C7), size: 26)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getGreeting().toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            fullName,
                            style: const TextStyle(
                              color: Color(0xFF0C4A6E), // Azul escuro profundo
                              fontSize: 18, // Aumentado
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _HeaderAction(
                      icon: Icons.logout_rounded,
                      onTap: () => _handleLogout(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Alerta de Bancas
          if (minhasBancasCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildBancaAlert(),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Institutional Title Centralized - Highly Legible
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Text(
                  "SECRETARIA VIRTUAL - DRI UFPB",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0369A1),
                    fontSize: 16, // Aumentado significativamente
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontFamily: 'Roboto', // Garantindo uma fonte limpa
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Bento Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 900
                    ? 3
                    : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent:
                    72, // Reduzido para ~40% do tamanho anterior (de 120 para 72)
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final menu = menus[index];
                  return _BentoCard(menu: menu);
                },
                childCount: menus.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.lock_person_rounded,
                    size: 64, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 32),
              const Text(
                "Acesso Restrito",
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Sua conta ainda não possui as permissões necessárias. Por favor, solicite a liberação na secretaria do curso.",
                style: TextStyle(
                    fontSize: 16, color: Colors.grey.shade600, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _handleLogout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text("Sair da Conta",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildBancaAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFEDD5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notification_important_rounded,
                color: Color(0xFFF97316), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("BANCAS ATRIBUÍDAS",
                    style: TextStyle(
                        color: Color(0xFF9A3412),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
                Text(
                  "Você foi convidado para $minhasBancasCount ${minhasBancasCount == 1 ? 'banca' : 'bancas'} em breve!",
                  style: const TextStyle(
                      color: Color(0xFF7C2D12),
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MinhasDefesasPage()),
              );
            },
            child: const Text("VER AGORA",
                style: TextStyle(
                    color: Color(0xFFF97316),
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.grey.shade600, size: 20),
        ),
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _MenuData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _BentoCard extends StatefulWidget {
  final _MenuData menu;
  const _BentoCard({required this.menu});

  @override
  State<_BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<_BentoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.menu.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered ? widget.menu.color : Colors.grey.shade300,
                width: _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? widget.menu.color.withOpacity(0.15)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: _isHovered ? 12 : 6,
                  offset: _isHovered ? const Offset(0, 6) : const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.menu.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.menu.color.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    widget.menu.icon,
                    color: widget.menu.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.menu.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.menu.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded, // Ícone de seta mais moderno
                  color: _isHovered ? widget.menu.color : Colors.grey.shade300,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
