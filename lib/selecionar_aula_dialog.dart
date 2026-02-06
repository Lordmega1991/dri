// lib/selecionar_aula_dialog.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelecionarAulaDialog extends StatefulWidget {
  final String dia;
  final int horario;
  final String turno;
  final Map<String, dynamic>? aula;

  const SelecionarAulaDialog({
    super.key,
    required this.dia,
    required this.horario,
    required this.turno,
    this.aula,
  });

  @override
  State<SelecionarAulaDialog> createState() => _SelecionarAulaDialogState();
}

class _SelecionarAulaDialogState extends State<SelecionarAulaDialog> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> professores = [];
  List<Map<String, dynamic>> disciplinas = [];

  Map<String, dynamic>? selectedProfessor;
  Map<String, dynamic>? selectedDisciplina;

  @override
  void initState() {
    super.initState();
    _loadProfessores();
    _loadDisciplinas();

    // Seleciona os valores atuais se já tiver aula
    if (widget.aula != null) {
      selectedProfessor = widget.aula!['professor'] != null
          ? {'nome': widget.aula!['professor']}
          : null;
      selectedDisciplina = widget.aula!['disciplina'] != null
          ? {'nome': widget.aula!['disciplina']}
          : null;
    }
  }

  Future<void> _loadProfessores() async {
    final response =
        await supabase.from('professores').select('nome').order('nome');
    setState(() {
      professores = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _loadDisciplinas() async {
    final response =
        await supabase.from('disciplinas').select('nome').order('nome');
    setState(() {
      disciplinas = List<Map<String, dynamic>>.from(response);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          'Selecionar Aula - ${widget.dia} ${widget.horario} (${widget.turno})'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Professor
            DropdownButtonFormField<Map<String, dynamic>>(
              value: selectedProfessor,
              items: professores.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p['nome'] ?? ''),
                );
              }).toList(),
              onChanged: (v) => setState(() => selectedProfessor = v),
              decoration: const InputDecoration(labelText: 'Professor'),
            ),
            const SizedBox(height: 12),
            // Disciplina
            DropdownButtonFormField<Map<String, dynamic>>(
              value: selectedDisciplina,
              items: disciplinas.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(d['nome'] ?? ''),
                );
              }).toList(),
              onChanged: (v) => setState(() => selectedDisciplina = v),
              decoration: const InputDecoration(labelText: 'Disciplina'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (selectedProfessor == null || selectedDisciplina == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Selecione professor e disciplina')),
              );
              return;
            }

            Navigator.pop(context, {
              'professor': selectedProfessor!['nome'],
              'disciplina': selectedDisciplina!['nome'],
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
