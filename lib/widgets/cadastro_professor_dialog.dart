import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cadastro_funcao_dialog.dart';

class CadastroProfessorDialog extends StatefulWidget {
  final Map<String, dynamic>? professor;

  const CadastroProfessorDialog({super.key, this.professor});

  @override
  State<CadastroProfessorDialog> createState() =>
      _CadastroProfessorDialogState();
}

class _CadastroProfessorDialogState extends State<CadastroProfessorDialog> {
  final supabase = Supabase.instance.client;
  final TextEditingController nomeController = TextEditingController();

  List<Map<String, dynamic>> funcoes = [];
  List<String> funcoesSelecionadas = [];

  @override
  void initState() {
    super.initState();
    carregarFuncoes();
    if (widget.professor != null) carregarDados();
  }

  Future<void> carregarFuncoes() async {
    final response = await supabase
        .from('funcoes_docentes')
        .select()
        .order('nome', ascending: true);
    setState(() {
      funcoes = List<Map<String, dynamic>>.from(response);
    });
  }

  void carregarDados() {
    nomeController.text = widget.professor?['nome'] ?? '';

    final relacoes = widget.professor?['professor_funcoes'] as List?;
    if (relacoes != null) {
      funcoesSelecionadas = relacoes
          .map((f) => f['funcoes_docentes']?['id'] ?? f['funcao_id'])
          .whereType<String>()
          .toList();
    }
  }

  Future<void> salvarProfessor() async {
    final nome = nomeController.text.trim();
    if (nome.isEmpty) return;

    String professorId;

    if (widget.professor != null) {
      professorId = widget.professor!['id'];
      await supabase
          .from('professores')
          .update({'nome': nome}).eq('id', professorId);
      await supabase
          .from('professor_funcoes')
          .delete()
          .eq('professor_id', professorId);
    } else {
      final response =
          await supabase.from('professores').insert({'nome': nome}).select();
      professorId = response.first['id'];
    }

    // Limitar a 3 funções
    final funcoesLimitadas = funcoesSelecionadas.take(3).toList();

    for (var funcaoId in funcoesLimitadas) {
      await supabase.from('professor_funcoes').insert({
        'professor_id': professorId,
        'funcao_id': funcaoId,
      });
    }

    if (context.mounted) Navigator.pop(context);
  }

  void abrirCadastroFuncoes() async {
    await showDialog(
      context: context,
      builder: (_) => const CadastroFuncaoDialog(),
    );
    await carregarFuncoes();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.professor == null
          ? 'Cadastrar Professor'
          : 'Editar Professor'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome do Professor'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Funções'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: abrirCadastroFuncoes,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...funcoes.map((f) {
              final id = f['id'] as String;
              final selecionado = funcoesSelecionadas.contains(id);
              return CheckboxListTile(
                value: selecionado,
                title: Text('${f['nome']} (${f['carga_horaria']}h)'),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      if (funcoesSelecionadas.length < 3) {
                        funcoesSelecionadas.add(id);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Máximo de 3 funções por docente.'),
                          ),
                        );
                      }
                    } else {
                      funcoesSelecionadas.remove(id);
                    }
                  });
                },
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Salvar'),
          onPressed: salvarProfessor,
        ),
      ],
    );
  }
}
