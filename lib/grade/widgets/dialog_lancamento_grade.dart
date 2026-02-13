import 'package:flutter/material.dart';

class DialogLancamentoGrade extends StatefulWidget {
  final String dia;
  final String turno;
  final int indice;
  final String? disciplinaIdInicial;
  final List<Map<String, dynamic>> disciplinas;
  final List<Map<String, dynamic>> professores;
  final String semestre;

  const DialogLancamentoGrade({
    super.key,
    required this.dia,
    required this.turno,
    required this.indice,
    this.disciplinaIdInicial,
    required this.disciplinas,
    required this.professores,
    required this.semestre,
  });

  @override
  State<DialogLancamentoGrade> createState() => _DialogLancamentoGradeState();
}

class _DialogLancamentoGradeState extends State<DialogLancamentoGrade> {
  String? disciplinaSelecionada;
  List<Map<String, dynamic>> itensAlocacao = [];

  // Controle de Dias
  final List<String> diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  final Map<String, bool> diasSelecionados = {};

  // Controle de Slots Detalhados
  final Map<String, bool> slotsSelecionados = {};

  @override
  void initState() {
    super.initState();

    // Inicializa dias
    for (var dia in diasSemana) {
      diasSelecionados[dia] = dia == widget.dia;
    }

    // Inicializa disciplina se fornecida
    disciplinaSelecionada = widget.disciplinaIdInicial;

    // Adiciona um item de professor vazio
    _adicionarItem();

    // Pré-seleciona o slot atual
    final slotAtual =
        '${widget.dia}-${_getTurnoCode(widget.turno)}${widget.indice}';
    slotsSelecionados[slotAtual] = true;
  }

  String _getTurnoCode(String turno) {
    if (turno == 'Manhã') return 'M';
    if (turno == 'Tarde') return 'T';
    if (turno == 'Noite') return 'N';
    return 'M';
  }

  void _adicionarItem() {
    Map<String, bool> diasItem = {};
    for (var dia in diasSemana) {
      diasItem[dia] = diasSelecionados[dia] == true;
    }

    itensAlocacao.add({
      'docente_id': null,
      'controller': TextEditingController(),
      'dias': diasItem,
    });
    setState(() {});
  }

  void _removerItem(int index) {
    if (itensAlocacao.length <= 1) return;
    setState(() {
      itensAlocacao[index]['controller'].dispose();
      itensAlocacao.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lançamento de Aula',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.dia} • ${widget.turno} • Horário #${widget.indice}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seleção de Disciplina
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.book,
                                  color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Disciplina',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: disciplinaSelecionada,
                            decoration: InputDecoration(
                              labelText: 'Selecione a disciplina',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            items: widget.disciplinas
                                .map((d) => DropdownMenuItem<String>(
                                      value: d['id'],
                                      child: Text(d['nome'] ?? 'Sem nome'),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => disciplinaSelecionada = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Docentes e Carga Horária
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person,
                                  color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Docentes e Carga Horária',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildListaProfessores(),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _adicionarItem,
                            icon: const Icon(Icons.add, size: 18),
                            label:
                                const Text('Adicionar Professor (Co-docência)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade300),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Seleção de Dias
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.date_range,
                                  color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Dias da Semana',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: diasSemana.map((dia) {
                              final isSelected = diasSelecionados[dia] == true;
                              return FilterChip(
                                label: Text(dia),
                                selected: isSelected,
                                selectedColor: Colors.orange.shade300,
                                checkmarkColor: Colors.white,
                                onSelected: (v) {
                                  setState(() {
                                    diasSelecionados[dia] = v;
                                    // Atualiza os dias de todos os professores
                                    for (var item in itensAlocacao) {
                                      final diasMap =
                                          item['dias'] as Map<String, bool>;
                                      if (!v) diasMap[dia] = false;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Seleção de Slots Detalhados
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  color: Colors.purple.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Horários Específicos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSelecaoSlots(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _salvar,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirmar Lançamento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaProfessores() {
    return Column(
      children: List.generate(itensAlocacao.length, (index) {
        final item = itensAlocacao[index];
        final diasMap = item['dias'] as Map<String, bool>;
        final chValue = double.tryParse(item['controller'].text) ?? 0;
        final horasAula = chValue / 15;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: item['docente_id'],
                        decoration: const InputDecoration(
                          labelText: 'Docente',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        isExpanded: true,
                        items: widget.professores
                            .map((p) => DropdownMenuItem<String>(
                                  value: p['id'],
                                  child: Text(p['apelido'],
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => item['docente_id'] = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: item['controller'],
                            decoration: const InputDecoration(
                              labelText: 'CH',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              suffixText: 'h',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${horasAula.toStringAsFixed(1)} h.a.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (itensAlocacao.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 22),
                        onPressed: () => _removerItem(index),
                        tooltip: 'Remover',
                      )
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Text('Dias:',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: diasSemana.map((dia) {
                            final isSelected = diasMap[dia] == true;
                            final isGlobalSelected =
                                diasSelecionados[dia] == true;

                            return GestureDetector(
                              onTap: isGlobalSelected
                                  ? () {
                                      setState(() {
                                        diasMap[dia] = !isSelected;
                                      });
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue.shade600
                                      : (isGlobalSelected
                                          ? Colors.grey.shade200
                                          : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  dia,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white
                                        : (isGlobalSelected
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade400),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSelecaoSlots() {
    final diasAtivos =
        diasSemana.where((d) => diasSelecionados[d] == true).toList();

    if (diasAtivos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Selecione pelo menos um dia da semana',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...['Manhã', 'Tarde', 'Noite'].map((turno) {
          final code = _getTurnoCode(turno);
          final maxSlots = turno == 'Noite' ? 5 : 6;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getTurnoColor(turno),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      turno,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getTurnoColor(turno),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(maxSlots, (i) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: diasAtivos.map((dia) {
                        final slot = '$dia-$code${i + 1}';
                        final isSelected = slotsSelecionados[slot] == true;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              slotsSelecionados[slot] = !isSelected;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _getTurnoColor(turno)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? _getTurnoColor(turno).withOpacity(0.8)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              '$dia-$code${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Color _getTurnoColor(String turno) {
    switch (turno) {
      case 'Manhã':
        return Colors.orange.shade600;
      case 'Tarde':
        return Colors.blue.shade600;
      case 'Noite':
        return Colors.indigo.shade600;
      default:
        return Colors.grey;
    }
  }

  void _salvar() {
    if (disciplinaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione uma disciplina')));
      return;
    }

    if (itensAlocacao.any((item) => item['docente_id'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecione os docentes para todas as linhas')));
      return;
    }

    // Slots Globais Selecionados
    final slotsAtivosGlobais = slotsSelecionados.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (slotsAtivosGlobais.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecione pelo menos um horário específico')));
      return;
    }

    List<Map<String, dynamic>> resultados = itensAlocacao.map((item) {
      final diasMap = item['dias'] as Map<String, bool>;

      // Dias deste professor
      final diasAtivosProf = diasSemana
          .where((d) => diasSelecionados[d] == true && diasMap[d] == true)
          .toList();

      // Slots deste professor
      final slotsAtivosProf = slotsAtivosGlobais.where((slot) {
        final diaDoSlot = slot.split('-')[0];
        return diasAtivosProf.contains(diaDoSlot);
      }).toList();

      return {
        'docente_id': item['docente_id'],
        'ch_alocada': double.tryParse(item['controller'].text) ?? 0,
        'slots': slotsAtivosProf,
      };
    }).toList();

    Navigator.pop(context, {
      'disciplina_id': disciplinaSelecionada,
      'professores': resultados,
      'semestre': widget.semestre,
    });
  }

  @override
  void dispose() {
    for (var item in itensAlocacao) {
      item['controller'].dispose();
    }
    super.dispose();
  }
}
