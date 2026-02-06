// lib/gestao_docentes_page.dart
import 'package:flutter/material.dart';
import 'docentes/cadastro_docentes_page.dart';
import 'docentes/tipos_atividade_page.dart';
import 'docentes/lancar_atividades_page.dart';
import 'docentes/relatorio_consolidado_page.dart';
import 'docentes/relatorios_detalhados_page.dart';

class GestaoDocentesPage extends StatefulWidget {
  const GestaoDocentesPage({super.key});

  @override
  State<GestaoDocentesPage> createState() => _GestaoDocentesPageState();
}

class _GestaoDocentesPageState extends State<GestaoDocentesPage> {
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
                            "GESTÃO DE DOCENTES",
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

          // Bento Grid for Docentes Options
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
                  title: "Cadastrar Docentes",
                  subtitle: "Novos docentes no sistema",
                  icon: Icons.person_add_rounded,
                  color: const Color(0xFF4CAF50),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CadastroDocentesPage())),
                ),
                _BentoActionCard(
                  title: "Lançar Atividades",
                  subtitle: "Aulas, bancas e funções",
                  icon: Icons.assignment_add,
                  color: const Color(0xFF2196F3),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LancarAtividadesPage())),
                ),
                _BentoActionCard(
                  title: "Relatórios Consolidados",
                  subtitle: "Visualizar por semestre",
                  icon: Icons.analytics_rounded,
                  color: const Color(0xFF9C27B0),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RelatorioConsolidadoPage())),
                ),
                _BentoActionCard(
                  title: "Relatórios Detalhados",
                  subtitle: "Atividades por docente",
                  icon: Icons.list_alt_rounded,
                  color: const Color(0xFFFF9800),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RelatoriosDetalhadosPage())),
                ),
                _BentoActionCard(
                  title: "Tipos de Atividade",
                  subtitle: "Categorias e pesos",
                  icon: Icons.category_rounded,
                  color: const Color(0xFF607D8B),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TiposAtividadePage())),
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
