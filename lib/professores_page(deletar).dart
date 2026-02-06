import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/cadastro_professor_dialog.dart';

class ProfessoresPage extends StatefulWidget {
  const ProfessoresPage({super.key});

  @override
  State<ProfessoresPage> createState() => _ProfessoresPageState();
}

class _ProfessoresPageState extends State<ProfessoresPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> professores = [];

  @override
  void initState() {
    super.initState();
    carregarProfessores();
  }

  Future<void> carregarProfessores() async {
    final response = await supabase
        .from('professores')
        .select(
            '*, professor_funcoes(funcao_id, funcoes_docentes(nome, carga_horaria))')
        .order('nome', ascending: true);

    setState(() {
      professores = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> excluirProfessor(String id) async {
    await supabase.from('professores').delete().eq('id', id);
    await carregarProfessores();
  }

  int calcularCargaHoraria(Map<String, dynamic> professor) {
    final funcoes = professor['professor_funcoes'] as List?;
    if (funcoes == null) return 0;
    return funcoes.fold<int>(
      0,
      (sum, f) => sum + ((f['funcoes_docentes']?['carga_horaria'] ?? 0) as int),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    int crossAxisCount;
    if (isMobile) {
      crossAxisCount = 1;
    } else if (screenWidth < 900) {
      crossAxisCount = 2;
    } else if (screenWidth < 1200) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade100,
        title: const Text('Professores', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: professores.isEmpty
                ? const Center(child: Text('Nenhum professor cadastrado.'))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          1.9, // cards mais largos, mais compactos
                    ),
                    itemCount: professores.length,
                    itemBuilder: (context, index) {
                      final professor = professores[index];
                      final funcoes =
                          (professor['professor_funcoes'] as List?) ?? [];
                      final carga = calcularCargaHoraria(professor);

                      return IntrinsicHeight(
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  professor['nome'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Carga: $carga h',
                                  style: const TextStyle(
                                      color: Colors.blueGrey, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                if (funcoes.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: funcoes.map((f) {
                                      final funcao = f['funcoes_docentes'];
                                      return Text(
                                          '- ${funcao?['nome'] ?? ''} (${funcao?['carga_horaria'] ?? 0}h)',
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1);
                                    }).toList(),
                                  )
                                else
                                  const Text('Nenhuma função.',
                                      style: TextStyle(fontSize: 11)),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (_) =>
                                              CadastroProfessorDialog(
                                            professor: professor,
                                          ),
                                        );
                                        await carregarProfessores();
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final confirmar =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title:
                                                const Text('Excluir Professor'),
                                            content: const Text(
                                                'Deseja realmente excluir este professor?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: const Text('Excluir'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmar == true) {
                                          await excluirProfessor(
                                              professor['id']);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => const CadastroProfessorDialog(),
                );
                await carregarProfessores();
              },
              label: const Text("Adicionar"),
              icon: const Icon(Icons.person_add_alt_1),
              backgroundColor: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }
}
