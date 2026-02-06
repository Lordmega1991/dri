// lib/planejamento/widgets/card_periodo_widget.dart
import 'package:flutter/material.dart';

class CardPeriodoWidget extends StatelessWidget {
  final String periodo;
  final List<Map<String, dynamic>> disciplinasPeriodo;
  final Map<String, List<Map<String, dynamic>>> detalhamento;
  final List<dynamic> alocacoes;
  final double chTotal;
  final double chAlocada;
  final double chRestante;
  final Function(String) onAlternarDisciplina;
  final VoidCallback onAdicionarDocente;
  final Function(Map<String, dynamic>) onEditarDocente;
  final Function(String) onRemoverAlocacao;
  final Function(String, String, Map<String, dynamic>)
      onEditarAlocacaoDetalhada;
  final Function(String, Map<String, dynamic>) onRemoverAlocacaoDetalhada;
  final Function(String) onAdicionarAlocacaoDetalhada;

  const CardPeriodoWidget({
    super.key,
    required this.periodo,
    required this.disciplinasPeriodo,
    required this.alocacoes, // Mantido para retrocompatibilidade ou resumo
    required this.detalhamento, // Novo
    required this.chTotal,
    required this.chAlocada,
    required this.chRestante,
    required this.onAlternarDisciplina,
    required this.onAdicionarDocente, // Depreciado, mas mantido por enquanto
    required this.onEditarDocente, // Depreciado
    required this.onRemoverAlocacao, // Depreciado
    required this.onEditarAlocacaoDetalhada,
    required this.onRemoverAlocacaoDetalhada,
    required this.onAdicionarAlocacaoDetalhada,
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
                    Expanded(child: _buildListaUnificada()),
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

  Widget _buildListaUnificada() {
    if (disciplinasPeriodo.isEmpty) {
      return _buildEmptyState('Nenhuma disciplina neste período');
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: disciplinasPeriodo.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final disc = disciplinasPeriodo[index];
        final alocacoesDisc = detalhamento[disc['id']] ?? [];
        final totalAlocado = alocacoesDisc.fold<double>(
            0, (sum, a) => sum + (a['ch_alocada'] ?? 0));
        final bool completa = totalAlocado >= (disc['ch_aula'] ?? 0);
        final bool desabilitada = disc['desabilitada'] == true;

        return Container(
          decoration: BoxDecoration(
            color: desabilitada ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: completa
                  ? const Color(0xFF10B981).withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: desabilitada
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF64748B).withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Column(
            children: [
              // Cabeçalho da Disciplina
              InkWell(
                onTap: () => onAlternarDisciplina(disc['id']),
                borderRadius: userInteractionBorderRadius(alocacoesDisc),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: desabilitada
                              ? const Color(0xFFCBD5E1)
                              : (completa
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF3B82F6)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              disc['nome_completo'] ?? disc['nome'],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: desabilitada
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF1E293B),
                                decoration: desabilitada
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!desabilitada) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: completa
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${totalAlocado.toInt()} / ${disc['ch_aula']}h',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: completa
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 20),
                          color: const Color(0xFF3B82F6),
                          onPressed: () =>
                              onAdicionarAlocacaoDetalhada(disc['id']),
                          tooltip: 'Adicionar Professor',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Lista de Professores Alocados
              if (alocacoesDisc.isNotEmpty && !desabilitada)
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: alocacoesDisc.map((aloc) {
                      return InkWell(
                        onTap: () => onEditarAlocacaoDetalhada(
                            disc['id'], aloc['docente_id'], aloc),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              const Icon(Icons.subdirectory_arrow_right_rounded,
                                  size: 16, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  aloc['docente_nome'] ?? 'Desconhecido',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              if (aloc['dias'] != null &&
                                  (aloc['dias'] as List).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    (aloc['dias'] as List)
                                        .map(
                                            (d) => d.toString().substring(0, 3))
                                        .join(', '),
                                    style: const TextStyle(
                                        fontSize: 10, color: Color(0xFF64748B)),
                                  ),
                                ),
                              Text(
                                '${aloc['ch_alocada']}h',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => onRemoverAlocacaoDetalhada(
                                    disc['id'], aloc),
                                child: const Icon(Icons.close_rounded,
                                    size: 14, color: Color(0xFFEF4444)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  BorderRadius userInteractionBorderRadius(List<dynamic> alocacoes) {
    if (alocacoes.isEmpty) {
      return BorderRadius.circular(12);
    }
    return const BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          message,
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
