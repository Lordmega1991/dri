import 'package:flutter/material.dart';

class DialogAlocacaoDetalhada extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> professores;
  final Map<String, dynamic>? alocacaoExistente; // Para edição
  final double chPadrao; // CH da disciplina

  const DialogAlocacaoDetalhada({
    super.key,
    required this.titulo,
    required this.professores,
    this.alocacaoExistente,
    this.chPadrao = 0,
  });

  @override
  State<DialogAlocacaoDetalhada> createState() =>
      _DialogAlocacaoDetalhadaState();
}

class _DialogAlocacaoDetalhadaState extends State<DialogAlocacaoDetalhada> {
  String? docenteSelecionado;
  final TextEditingController chController = TextEditingController();

  // Controle de Dias
  final List<String> diasSemana = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta'
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
      docenteSelecionado = aloc['docente_id'];
      chController.text = aloc['ch_alocada'].toString();

      // Carregar dias
      if (aloc['dias'] != null) {
        for (var dia in aloc['dias']) {
          diasSelecionados[dia] = true;
        }
      }

      // Carregar Slots
      if (aloc['slots'] != null) {
        for (var slot in aloc['slots']) {
          // O slot vem como "Dia-TurnoIndice" ex: "Segunda-M1"
          slotsSelecionados[slot] = true;
        }
      }

      turnoPredominante = aloc['turno'] ?? 'Manhã';
    } else {
      chController.text = widget.chPadrao.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Container(
        width: 600, // Força largura maior
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seleção de Docente e CH
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: docenteSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Docente',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      isExpanded: true,
                      items: widget.professores
                          .map((p) => DropdownMenuItem<String>(
                                value: p['id'],
                                child: Text(p['apelido'],
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => docenteSelecionado = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: chController,
                      decoration: const InputDecoration(
                        labelText: 'CH (h)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Seleção de Dias
              const Text('Dias da Semana',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
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

              const SizedBox(height: 20),

              // Seleção de Horários (Grid)
              const Text('Horários Específicos (Grade)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                  'Selecione os horários exatos para preencher a grade automaticamente.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
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

  Widget _buildGridHorarios() {
    // Apenas mostrar colunas dos dias selecionados para economizar espaço?
    // Melhor mostrar todos mas desabilitar os não selecionados.

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
        ..._buildTurnoRows('Manhã', 'M', 5), // Geralmente 5 ou 6 aulas
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
                          // Auto incrementar CH se selecionar? 50 min = 0.83h? Simplificar: deixa manual a CH.
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
    if (docenteSelecionado == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecione um docente')));
      return;
    }

    final diasAtivos =
        diasSemana.where((d) => diasSelecionados[d] == true).toList();
    final slotsAtivos = slotsSelecionados.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // Identificar turno predominante pelos slots
    // Lógica simples: primeiro slot
    String turno = 'Manhã';
    if (slotsAtivos.isNotEmpty) {
      if (slotsAtivos.first.contains('-T')) turno = 'Tarde';
      if (slotsAtivos.first.contains('-N')) turno = 'Noite';
    }

    Navigator.pop(context, {
      'docente_id': docenteSelecionado,
      'ch_alocada': double.tryParse(chController.text) ?? 0,
      'dias': diasAtivos,
      'turno': turno,
      'slots': slotsAtivos,
    });
  }
}
