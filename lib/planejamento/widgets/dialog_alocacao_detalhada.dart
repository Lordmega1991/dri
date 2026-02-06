import 'package:flutter/material.dart';

class DialogAlocacaoDetalhada extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> professores;
  final Map<String, dynamic>? alocacaoExistente; // Para edição
  final double chPadrao; // CH da disciplina
  final double chDisponivel; // CH restante para alocar

  const DialogAlocacaoDetalhada({
    super.key,
    required this.titulo,
    required this.professores,
    this.alocacaoExistente,
    this.chPadrao = 0,
    required this.chDisponivel,
  });

  @override
  State<DialogAlocacaoDetalhada> createState() =>
      _DialogAlocacaoDetalhadaState();
}

class _DialogAlocacaoDetalhadaState extends State<DialogAlocacaoDetalhada> {
  // Lista de itens de alocação (Docente + CH)
  List<Map<String, dynamic>> itensAlocacao = [];

  // Controle de Dias
  final List<String> diasSemana = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado'
  ];
  final Map<String, bool> diasSelecionados = {};

  // Controle de Turno Detalhado
  // M1..M6, T1..T6, N1..N5
  final Map<String, bool> slotsSelecionados = {};

  String turnoPredominante = 'Manhã';

  @override
  void initState() {
    super.initState();

    // Inicializa dias
    for (var dia in diasSemana) {
      diasSelecionados[dia] = false;
    }

    if (widget.alocacaoExistente != null) {
      final aloc = widget.alocacaoExistente!;

      itensAlocacao.add({
        'docente_id': aloc['docente_id'],
        'ch': aloc['ch_alocada'].toString(),
        'controller':
            TextEditingController(text: aloc['ch_alocada'].toString()),
      });

      // Carregar dias
      if (aloc['dias'] != null) {
        for (var dia in aloc['dias']) {
          diasSelecionados[dia] = true;
        }
      }

      // Carregar Slots
      if (aloc['slots'] != null) {
        for (var slot in aloc['slots']) {
          slotsSelecionados[slot] = true;
        }
      }

      turnoPredominante = aloc['turno'] ?? 'Manhã';
    } else {
      // Novo: Começa com um item vazio
      _adicionarItem();
    }
  }

  void _adicionarItem() {
    // Inicializa dias selecionados para o novo item
    // Se houver seleção global/anterior, poderiamos copiar?
    // Por padrão vamos deixar todos marcados ou desmarcados?
    // Melhor marcar todos que estão no global?
    // Vamos iniciar com todos marcados para facilitar (assumindo compartilhamento),
    // e o usuário desmarca se quiser dividir.
    Map<String, bool> diasItem = {};
    for (var dia in diasSemana) {
      diasItem[dia] = true;
    }

    itensAlocacao.add({
      'docente_id': null,
      'ch': '',
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
    // Calcular CH Total usada nos inputs
    double currentTotal = 0;
    for (var item in itensAlocacao) {
      currentTotal += double.tryParse(item['controller'].text) ?? 0;
    }
    double remaining = widget.chDisponivel - currentTotal;
    // Se estiver editando, o chDisponivel já incluiu o valor anterior, então remaining deve ser calculado com cuidado.
    // Mas a lógica de widget.chDisponivel vinda de fora já está correta (Total - UsadoPorOutros).

    // Se remaining < 0, erro visual?

    return AlertDialog(
      title: Text(widget.titulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Container(
        width: 700, // Aumentado para caber os dias
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lista de Docentes e CH
              _buildListaProfessores(),

              if (widget.alocacaoExistente == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: TextButton.icon(
                    onPressed: _adicionarItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar outro docente'),
                  ),
                ),

              if (remaining < 0)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                      'Atenção: Total excede o disponível em ${(remaining * -1).toStringAsFixed(1)}h',
                      style: TextStyle(color: Colors.red)),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                      'Disponível restante: ${remaining.toStringAsFixed(1)}h',
                      style: TextStyle(color: Colors.green)),
                ),

              const SizedBox(height: 20),

              // Seleção de Dias GLOBAL (Define quais dias a disciplina acontece)
              const Text('Grade Horária da Disciplina (Selecione slots)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Text(
                  'Marque abaixo os dias e horários que a disciplina é ofertada.\nEm seguida, ajuste (acima) quais docentes assumem quais dias.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),

              const SizedBox(height: 12),

              const Text('Dias da Semana (Habilita colunas)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Wrap(
                spacing: 8,
                children: diasSemana.map((dia) {
                  return FilterChip(
                    label: Text(dia.substring(0, 3)),
                    selected: diasSelecionados[dia] == true,
                    onSelected: (bool selected) {
                      setState(() {
                        diasSelecionados[dia] = selected;
                      });
                    },
                    selectedColor: Colors.blue.withOpacity(0.2),
                    checkmarkColor: Colors.blue,
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              _buildGridHorarios(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvar,
          child: const Text('Confirmar Alocação'),
        ),
      ],
    );
  }

  Widget _buildListaProfessores() {
    return Column(
      children: List.generate(itensAlocacao.length, (index) {
        final item = itensAlocacao[index];
        final diasMap = item['dias'] as Map<String, bool>;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: item['docente_id'],
                        decoration: const InputDecoration(
                          labelText: 'Docente',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
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
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: item['controller'],
                        decoration: const InputDecoration(
                          labelText: 'CH',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (widget.alocacaoExistente == null &&
                        itensAlocacao.length > 1)
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.red, size: 20),
                        onPressed: () => _removerItem(index),
                        tooltip: 'Remover',
                      )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Dias deste prof:',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    // Mini chips para seleção dos dias DO PROFESSOR
                    ...diasSemana.map((dia) {
                      final isSelected = diasMap[dia] == true;
                      // Apenas habilitado se o dia GLOBAL estiver selecionado?
                      // Sim, se o dia não existe na disciplina, o prof não pode pegar.
                      final isGlobalSelected = diasSelecionados[dia] == true;

                      return GestureDetector(
                        onTap: isGlobalSelected
                            ? () {
                                setState(() {
                                  diasMap[dia] = !isSelected;
                                });
                              }
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                              color: isSelected && isGlobalSelected
                                  ? Colors.blue
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: isGlobalSelected
                                      ? Colors.blue.withOpacity(0.5)
                                      : Colors.grey.shade300)),
                          child: Text(dia.substring(0, 1),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected && isGlobalSelected
                                      ? Colors.white
                                      : (isGlobalSelected
                                          ? Colors.black
                                          : Colors.grey))),
                        ),
                      );
                    }).toList()
                  ],
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGridHorarios() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const {
        0: FixedColumnWidth(50), // Label turno
      },
      children: [
        // Header Dias
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: [
            const Padding(padding: EdgeInsets.all(4), child: Text('')),
            ...diasSemana.map((d) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(d.substring(0, 3),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: diasSelecionados[d] == true
                              ? Colors.black
                              : Colors.grey)),
                )),
          ],
        ),
        // Manhã
        ..._buildTurnoRows('Manhã', 'M', 5),
        // Tarde
        ..._buildTurnoRows('Tarde', 'T', 5),
        // Noite
        ..._buildTurnoRows('Noite', 'N', 4),
      ],
    );
  }

  List<TableRow> _buildTurnoRows(String labelTurno, String prefixo, int qtd) {
    List<TableRow> rows = [];
    for (int i = 1; i <= qtd; i++) {
      rows.add(TableRow(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: _getCorTurno(labelTurno).withOpacity(0.1),
            child: Text('$prefixo$i',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          ...diasSemana.map((dia) {
            final key = '$dia-$prefixo$i';
            final habilitado = diasSelecionados[dia] == true;
            final selecionado = slotsSelecionados[key] == true;

            return TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: InkWell(
                onTap: habilitado
                    ? () {
                        setState(() {
                          slotsSelecionados[key] = !selecionado;
                        });
                      }
                    : null,
                child: Container(
                  height: 30,
                  color: habilitado
                      ? (selecionado
                          ? _getCorTurno(labelTurno)
                          : Colors.transparent)
                      : Colors.grey.shade50,
                  child: habilitado && selecionado
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            );
          }),
        ],
      ));
    }
    return rows;
  }

  Color _getCorTurno(String turno) {
    switch (turno) {
      case 'Manhã':
        return Colors.orange;
      case 'Tarde':
        return Colors.blue;
      case 'Noite':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  void _salvar() {
    if (itensAlocacao.any((item) => item['docente_id'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecione os docentes para todas as linhas')));
      return;
    }

    double totalCH = 0;
    for (var item in itensAlocacao) {
      totalCH += double.tryParse(item['controller'].text) ?? 0;
    }

    if (totalCH > widget.chDisponivel) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'A CH total ($totalCH) excede o limite disponível de ${widget.chDisponivel}h')));
      return;
    }

    // Slots Globais Selecionados
    final slotsAtivosGlobais = slotsSelecionados.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    String turno = 'Manhã';
    if (slotsAtivosGlobais.isNotEmpty) {
      if (slotsAtivosGlobais.first.contains('-T')) turno = 'Tarde';
      if (slotsAtivosGlobais.first.contains('-N')) turno = 'Noite';
    }

    List<Map<String, dynamic>> resultados = itensAlocacao.map((item) {
      final diasMap = item['dias'] as Map<String, bool>;

      // Dias deste professor: Intersecção entre Dias Globais e Dias do Professor
      final diasAtivosProf = diasSemana
          .where((d) => diasSelecionados[d] == true && diasMap[d] == true)
          .toList();

      // Slots deste professor: Slots Globais que pertencem aos Dias Ativos do Professor
      final slotsAtivosProf = slotsAtivosGlobais.where((slot) {
        final diaDoSlot = slot.split('-')[0]; // "Segunda-M1" -> "Segunda"
        return diasAtivosProf.contains(diaDoSlot);
      }).toList();

      return {
        'docente_id': item['docente_id'],
        'ch_alocada': double.tryParse(item['controller'].text) ?? 0,
        'dias': diasAtivosProf,
        'turno': turno,
        'slots': slotsAtivosProf,
      };
    }).toList();

    Navigator.pop(context, resultados);
  }
}
