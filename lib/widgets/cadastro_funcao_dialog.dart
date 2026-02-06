import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastroFuncaoDialog extends StatefulWidget {
  const CadastroFuncaoDialog({super.key});

  @override
  State<CadastroFuncaoDialog> createState() => _CadastroFuncaoDialogState();
}

class _CadastroFuncaoDialogState extends State<CadastroFuncaoDialog> {
  final supabase = Supabase.instance.client;
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController cargaController = TextEditingController();

  String? editarId;
  List<Map<String, dynamic>> funcoes = [];

  @override
  void initState() {
    super.initState();
    carregarFuncoes();
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

  Future<void> salvarFuncao() async {
    final nome = nomeController.text.trim();
    final carga = int.tryParse(cargaController.text.trim()) ?? 0;

    if (nome.isEmpty) return;

    if (editarId != null) {
      await supabase.from('funcoes_docentes').update(
          {'nome': nome, 'carga_horaria': carga}).eq('id', editarId ?? '');
    } else {
      await supabase
          .from('funcoes_docentes')
          .insert({'nome': nome, 'carga_horaria': carga});
    }

    nomeController.clear();
    cargaController.clear();
    editarId = null;
    await carregarFuncoes();
  }

  Future<void> excluirFuncao(String id) async {
    await supabase.from('funcoes_docentes').delete().eq('id', id);
    await carregarFuncoes();
  }

  void editarFuncao(Map<String, dynamic> funcao) {
    setState(() {
      editarId = funcao['id'];
      nomeController.text = funcao['nome'] ?? '';
      cargaController.text = funcao['carga_horaria']?.toString() ?? '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gerenciar Funções'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome da Função'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: cargaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carga Horária (h)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              onPressed: salvarFuncao,
              label: Text(editarId == null ? 'Cadastrar' : 'Salvar Edição'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text('Funções Cadastradas',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (var f in funcoes)
              ListTile(
                title: Text(f['nome']),
                subtitle: Text('Carga: ${f['carga_horaria']}h'),
                trailing: Wrap(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => editarFuncao(f),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => excluirFuncao(f['id']),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Fechar'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
