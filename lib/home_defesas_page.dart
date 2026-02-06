// lib/home_defesas_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cadastrar_defesa.dart';
import 'visualizar_defesa.dart';
import 'situacao_defesas_page.dart';
import 'upload_documentos_page.dart';
import 'relatorio_participantes_page.dart';
import 'minhas_defesas.dart';
import 'tcc/certificados_bancas_tcc.dart';
import 'tcc/calendario_defesas_page.dart';

class HomeDefesasPage extends StatefulWidget {
  const HomeDefesasPage({super.key});

  @override
  State<HomeDefesasPage> createState() => _HomeDefesasPageState();
}

class _HomeDefesasPageState extends State<HomeDefesasPage> {
  final supabase = Supabase.instance.client;
  int? userAccessLevel;

  @override
  void initState() {
    super.initState();
    _getUserAccessLevel();
  }

  Future<void> _getUserAccessLevel() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('users_access')
            .select('access_level')
            .eq('id', user.id)
            .single();

        setState(() {
          userAccessLevel = response['access_level'] as int;
        });
      }
    } catch (e) {
      print('Erro ao buscar nível de acesso do usuário: $e');
      setState(() {
        userAccessLevel = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Ultra-Compact Header (Back button Style)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE), // Azul leve aprimorado
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
                    Material(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF0C4A6E), size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "GERENCIAMENTO DE DEFESAS",
                            style: TextStyle(
                              color: Color(0xFF0C4A6E),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Bento Grid for Defense Options
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 900
                    ? 3
                    : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 78,
              ),
              delegate: SliverChildListDelegate([
                _BentoActionCard(
                  title: "Cadastrar Defesa",
                  subtitle: "Nova defesa de TCC",
                  icon: Icons.add_circle_outlined,
                  color: const Color(0xFF667eea),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CadastrarDefesaPage())),
                ),
                _BentoActionCard(
                  title: "Visualizar Defesas",
                  subtitle: "Consultar bancas cadastradas",
                  icon: Icons.visibility_outlined,
                  color: const Color(0xFF4facfe),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const VisualizarDefesaPage())),
                ),
                _BentoActionCard(
                  title: "Calendário",
                  subtitle: "Agenda de defesas",
                  icon: Icons.calendar_today_outlined,
                  color: const Color(0xFFe74c3c),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CalendarioDefesasPage())),
                ),
                _BentoActionCard(
                  title: "Minhas Bancas",
                  subtitle: "Bancas que participo",
                  icon: Icons.person_outlined,
                  color: const Color(0xFF5b8c00),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MinhasDefesasPage())),
                ),
                if (userAccessLevel == 4 || userAccessLevel == 5)
                  _BentoActionCard(
                    title: "Situação",
                    subtitle: "Acompanhar andamento",
                    icon: Icons.assessment_outlined,
                    color: const Color(0xFF4CAF50),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SituacaoDefesasPage())),
                  ),
                _BentoActionCard(
                  title: "Relatório",
                  subtitle: "Orientadores e avaliadores",
                  icon: Icons.people_outlined,
                  color: const Color(0xFF9C27B0),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RelatorioParticipantesPage())),
                ),
                if (userAccessLevel == 4 || userAccessLevel == 5)
                  _BentoActionCard(
                    title: "Certificados",
                    subtitle: "Emitir certificados de banca",
                    icon: Icons.workspace_premium_outlined,
                    color: const Color(0xFFFF9800),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CertificadosBancasTccPage())),
                  ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _BentoActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BentoActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_BentoActionCard> createState() => _BentoActionCardState();
}

class _BentoActionCardState extends State<_BentoActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
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
                color: _isHovered ? widget.color : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? widget.color.withOpacity(0.15)
                      : Colors.black.withOpacity(0.02),
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
                    color: widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
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
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _isHovered ? widget.color : Colors.grey.shade300,
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
