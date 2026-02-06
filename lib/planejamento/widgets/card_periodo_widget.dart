// lib/planejamento/widgets/card_periodo_widget.dart
import 'package:flutter/material.dart';

class CardPeriodoWidget extends StatelessWidget {
  final String periodo;
  final List<Map<String, dynamic>> disciplinasPeriodo;
  final List<dynamic> alocacoes;
  final double chTotal;
  final double chAlocada;
  final double chRestante;
  final Function(String) onAlternarDisciplina;
  final VoidCallback onAdicionarDocente;
  final Function(Map<String, dynamic>) onEditarDocente;
  final Function(String) onRemoverAlocacao;

  const CardPeriodoWidget({
    super.key,
    required this.periodo,
    required this.disciplinasPeriodo,
    required this.alocacoes,
    required this.chTotal,
    required this.chAlocada,
    required this.chRestante,
    required this.onAlternarDisciplina,
    required this.onAdicionarDocente,
    required this.onEditarDocente,
    required this.onRemoverAlocacao,
  });

  @override
  Widget build(BuildContext context) {
    final bool isComplete = chRestante == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isComplete
              ? const Color(0xFF10B981).withOpacity(0.2)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildHeader(isComplete),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildResumoCH(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildContentListsSideBySide()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isComplete) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isComplete
            ? const Color(0xFF10B981).withOpacity(0.05)
            : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isComplete
                ? const Color(0xFF10B981).withOpacity(0.1)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFF10B981)
                      : const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                '$periodo Período',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          if (isComplete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF059669), size: 14),
                  SizedBox(width: 4),
                  const Text(
                    'Completo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumoCH() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItemResumo('CH Total', '${chTotal.toStringAsFixed(1)}h',
              const Color(0xFF64748B)),
          _buildVerticalDividerSimple(),
          _buildItemResumo('Alocada', '${chAlocada.toStringAsFixed(1)}h',
              const Color(0xFF3B82F6)),
          _buildVerticalDividerSimple(),
          _buildItemResumo(
            'Restante',
            '${chRestante.toStringAsFixed(1)}h',
            chRestante > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDividerSimple() {
    return Container(height: 20, width: 1, color: const Color(0xFFCBD5E1));
  }

  Widget _buildItemResumo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildContentListsSideBySide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna de Disciplinas
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Disciplinas',
                Icons.book_rounded,
                const Color(0xFF64748B),
                null,
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildColunaDisciplinas()),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Divisor Vertical
        Container(width: 1, color: const Color(0xFFF1F5F9)),
        const SizedBox(width: 16),
        // Coluna de Docentes
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Docentes',
                Icons.people_alt_rounded,
                const Color(0xFF3B82F6),
                onAdicionarDocente,
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildColunaDocentes()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, VoidCallback? onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 14, color: Color(0xFF3B82F6)),
            ),
          ),
      ],
    );
  }

  Widget _buildColunaDisciplinas() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: disciplinasPeriodo.isEmpty
          ? _buildEmptyState('Nenhuma disciplina')
          : Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: disciplinasPeriodo.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final disc = disciplinasPeriodo[index];
                  final bool des = disc['desabilitada'] == true;
                  return _buildDisciplinaItem(disc, des);
                },
              ),
            ),
    );
  }

  Widget _buildDisciplinaItem(Map<String, dynamic> disc, bool des) {
    return InkWell(
      onTap: () => onAlternarDisciplina(disc['id']),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                disc['nome_completo'] ?? disc['nome'],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: des ? FontWeight.w400 : FontWeight.w600,
                  color:
                      des ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                  decoration: des ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: des
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${disc['ch_aula']}h',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color:
                      des ? const Color(0xFF94A3B8) : const Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColunaDocentes() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: alocacoes.isEmpty
          ? _buildEmptyState('Sem aloc.')
          : Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: alocacoes.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final aloc = alocacoes[index];
                  return _buildDocenteItem(aloc);
                },
              ),
            ),
    );
  }

  Widget _buildDocenteItem(Map<String, dynamic> aloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  aloc['docente_nome'],
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${aloc['ch_alocada']}h',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionIconButton(Icons.edit_rounded,
                  const Color(0xFF64748B), () => onEditarDocente(aloc)),
              const SizedBox(width: 8),
              _buildActionIconButton(
                  Icons.close_rounded,
                  const Color(0xFFEF4444),
                  () => onRemoverAlocacao(aloc['docente_id'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionIconButton(
      IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Icon(icon, size: 12, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          message,
          style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
