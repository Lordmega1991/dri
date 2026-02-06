import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/card_periodo_widget.dart';
import 'widgets/dialog_alocacao_detalhada.dart';
import 'simulacao_pdf_helper.dart';

class SimulacaoCHPage extends StatefulWidget {
  const SimulacaoCHPage({super.key});

  @override
  State<SimulacaoCHPage> createState() => _SimulacaoCHPageState();
}

class _SimulacaoCHPageState extends State<SimulacaoCHPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> disciplinas = [];
  List<Map<String, dynamic>> professores = [];
  List<Map<String, dynamic>> semestres = [];
  List<Map<String, dynamic>> simulacoesSalvas = [];

  String semestreSelecionado = '';
  String tipoPeriodo = 'impar'; // 'impar' ou 'par'

  // Controladores para os campos de texto
  final TextEditingController nomeSimulacaoController = TextEditingController();
  String? idSimulacaoEditando;

  // Estrutura para armazenar a simulação atual
  Map<String, Map<String, dynamic>> simulacaoAtual = {};

  // Períodos
  final List<String> periodosImpares = ['1º', '3º', '5º', '7º', '9º'];
  final List<String> periodosPares = ['2º', '4º', '6º', '8º'];

  @override
  void initState() {
    super.initState();
    _loadDados();
  }

  @override
  void dispose() {
    nomeSimulacaoController.dispose();
    super.dispose();
  }

  Future<void> _loadDados() async {
    await _loadSemestres();
    await _loadDisciplinas();
    await _loadProfessores();
    await _loadSimulacoesSalvas();

    // Define o semestre mais recente como padrão
    if (semestres.isNotEmpty && semestreSelecionado.isEmpty) {
      setState(() {
        semestreSelecionado = semestres.first['display'];
      });
    }
  }

  Future<void> _loadSemestres() async {
    final response = await supabase
        .from('semestres')
        .select('id, ano, semestre, data_inicio, data_fim')
        .order('ano', ascending: false)
        .order('semestre', ascending: false);

    setState(() {
      semestres = List<Map<String, dynamic>>.from(
        response.map((e) => {
              'id': e['id'],
              'ano': e['ano'],
              'semestre': e['semestre'],
              'data_inicio': e['data_inicio'],
              'data_fim': e['data_fim'],
              'display': '${e['ano']}.${e['semestre']}'
            }),
      );
    });
  }

  Future<void> _loadDisciplinas() async {
    try {
      final response = await supabase
          .from('disciplinas')
          .select('id, nome, nome_extenso, ch_aula, periodo, ppc, turno')
          .order('periodo')
          .order('nome');

      setState(() {
        disciplinas = List<Map<String, dynamic>>.from(
          response.map((e) {
            final ppc = e['ppc']?.toString().toLowerCase() ?? 'antigo';
            final turno = e['turno']?.toString() ?? '';
            final turnoTexto =
                turno.isNotEmpty ? ' (${turno[0].toUpperCase()})' : '';
            final ppcTexto = ppc == 'novo'
                ? ' (Novo)'
                : ppc == 'antigo'
                    ? ' (Antigo)'
                    : '';

            // Prioriza nome_extenso se existir
            final baseName = (e['nome_extenso'] != null &&
                    e['nome_extenso'].toString().isNotEmpty)
                ? e['nome_extenso']
                : e['nome'];

            final nomeCompleto = '$baseName$ppcTexto$turnoTexto';

            return {
              'id': e['id'],
              'nome': e['nome'], // Mantém sigla aqui se precisar
              'nome_completo': nomeCompleto, // Usa nome extenso
              'nome_extenso': e['nome_extenso'],
              'ch_aula': (e['ch_aula'] ?? 0).toDouble(),
              'periodo': e['periodo'] ?? 'N/A',
              'ppc': ppc,
              'turno': turno,
              'desabilitada': false,
            };
          }),
        );
      });
    } catch (e) {
      print('Erro ao carregar disciplinas: $e');
    }
  }

  Future<void> _loadProfessores() async {
    final response = await supabase
        .from('docentes')
        .select('id, nome, apelido, ativo')
        .eq('ativo', true)
        .order('apelido');

    setState(() {
      professores = List<Map<String, dynamic>>.from(
        response.map((e) => {
              'id': e['id'],
              'nome': e['nome'],
              'apelido': e['apelido'] ?? e['nome'],
              'ativo': e['ativo'] ?? true,
            }),
      );
    });
  }

  Future<void> _loadSimulacoesSalvas() async {
    try {
      final response = await supabase
          .from('simulacoes_ch')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        simulacoesSalvas = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Erro ao carregar simulações: $e');
    }
  }

  List<Map<String, dynamic>> _getDisciplinasPorPeriodo(String periodo) {
    return disciplinas
        .where((disciplina) => disciplina['periodo'] == periodo)
        .toList();
  }

  List<String> _getPeriodosAtivos() {
    return tipoPeriodo == 'impar' ? periodosImpares : periodosPares;
  }

  double _getCHTotalDisciplinas(String periodo) {
    final disciplinasPeriodo = _getDisciplinasPorPeriodo(periodo);
    return disciplinasPeriodo.fold<double>(0, (total, disciplina) {
      if (disciplina['desabilitada'] == true) {
        return total;
      }
      return total + (disciplina['ch_aula'] ?? 0);
    });
  }

  double _getCHAlocada(String periodo) {
    final periodoData = simulacaoAtual[periodo];
    if (periodoData == null) return 0;

    final alocacoes = periodoData['alocacoes'];
    if (alocacoes == null || alocacoes is! List) return 0;

    double total = 0;
    for (var alocacao in alocacoes) {
      if (alocacao is Map<String, dynamic>) {
        final ch = alocacao['ch_alocada'];
        if (ch is double) {
          total += ch;
        } else if (ch is int) {
          total += ch.toDouble();
        } else if (ch is String) {
          total += double.tryParse(ch) ?? 0;
        }
      }
    }
    return total;
  }

  double _getCHRestante(String periodo) {
    return _getCHTotalDisciplinas(periodo) - _getCHAlocada(periodo);
  }

  void _adicionarAlocacao(String periodo, String docenteId, double chAlocada) {
    setState(() {
      if (!simulacaoAtual.containsKey(periodo)) {
        simulacaoAtual[periodo] = {
          'alocacoes': <Map<String, dynamic>>[],
        };
      }

      final periodoData = simulacaoAtual[periodo]!;
      final alocacoes =
          List<Map<String, dynamic>>.from(periodoData['alocacoes'] ?? []);

      final index = alocacoes.indexWhere((a) => a['docente_id'] == docenteId);

      if (index >= 0) {
        alocacoes[index]['ch_alocada'] = chAlocada;
      } else {
        final professor = professores.firstWhere(
          (p) => p['id'] == docenteId,
          orElse: () => {'apelido': 'Desconhecido'},
        );

        alocacoes.add({
          'docente_id': docenteId,
          'docente_nome': professor['apelido'],
          'ch_alocada': chAlocada,
        });
      }

      simulacaoAtual[periodo]!['alocacoes'] = alocacoes;
    });
  }

  void _removerAlocacao(String periodo, String docenteId) {
    setState(() {
      final periodoData = simulacaoAtual[periodo];
      if (periodoData != null) {
        final alocacoes =
            List<Map<String, dynamic>>.from(periodoData['alocacoes'] ?? []);
        alocacoes.removeWhere((a) => a['docente_id'] == docenteId);
        simulacaoAtual[periodo]!['alocacoes'] = alocacoes;
      }
    });
  }

  void _alternarDisciplina(String disciplinaId) {
    setState(() {
      final index = disciplinas.indexWhere((d) => d['id'] == disciplinaId);
      if (index != -1) {
        disciplinas[index]['desabilitada'] =
            !disciplinas[index]['desabilitada'];
      }
    });
  }

  Future<void> _salvarSimulacao({bool comoNovo = false}) async {
    if (nomeSimulacaoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um nome para a simulação!')),
      );
      return;
    }

    if (semestreSelecionado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um semestre!')),
      );
      return;
    }

    try {
      final dadosParaSalvar = {
        'nome_simulacao': nomeSimulacaoController.text,
        'semestre': semestreSelecionado,
        'tipo_periodo': tipoPeriodo,
        'dados_simulacao': simulacaoAtual,
        'disciplinas_desabilitadas': disciplinas
            .where((d) => d['desabilitada'] == true)
            .map((d) => d['id'])
            .toList(),
      };

      if (idSimulacaoEditando != null && !comoNovo) {
        // Atualiza a simulação existente (Overwrite)
        await supabase
            .from('simulacoes_ch')
            .update(dadosParaSalvar)
            .eq('id', idSimulacaoEditando!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulação atualizada com sucesso!')),
        );
      } else {
        // Insere uma nova simulação
        final response = await supabase
            .from('simulacoes_ch')
            .insert(dadosParaSalvar)
            .select()
            .single();

        setState(() {
          idSimulacaoEditando = response['id'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(comoNovo
                  ? 'Simulação clonada com sucesso!'
                  : 'Simulação salva com sucesso!')),
        );
      }

      await _loadSimulacoesSalvas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar simulação: $e')),
      );
    }
  }

  Future<void> _carregarSimulacao(Map<String, dynamic> simulacao) async {
    setState(() {
      idSimulacaoEditando = simulacao['id'];
      nomeSimulacaoController.text = simulacao['nome_simulacao'];
      semestreSelecionado = simulacao['semestre'];
      tipoPeriodo = simulacao['tipo_periodo'];
      // Converter os dados de forma segura para o Flutter Web
      final Map<String, dynamic> rawDados =
          Map<String, dynamic>.from(simulacao['dados_simulacao'] ?? {});
      simulacaoAtual = rawDados.map((key, value) {
        return MapEntry(key, Map<String, dynamic>.from(value ?? {}));
      });

      final disciplinasDesabilitadas = List<String>.from(
        simulacao['disciplinas_desabilitadas'] ?? [],
      );

      for (var disciplina in disciplinas) {
        disciplina['desabilitada'] =
            disciplinasDesabilitadas.contains(disciplina['id']);
      }
    });
  }

  Future<void> _excluirSimulacao(String id) async {
    bool confirmado = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir Simulação'),
            content:
                const Text('Tem certeza que deseja excluir esta simulação?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmado) {
      try {
        await supabase.from('simulacoes_ch').delete().eq('id', id);
        if (idSimulacaoEditando == id) {
          _novaSimulacao();
        }
        await _loadSimulacoesSalvas();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulação excluída com sucesso!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir simulação: $e')),
        );
      }
    }
  }

  void _novaSimulacao() {
    setState(() {
      idSimulacaoEditando = null;
      nomeSimulacaoController.clear();
      simulacaoAtual = {};
      for (var disciplina in disciplinas) {
        disciplina['desabilitada'] = false;
      }
    });
  }

  Future<void> _exportarParaPDF() async {
    if (nomeSimulacaoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Digite o nome da simulação para exportar!')),
      );
      return;
    }

    try {
      await SimulacaoPDFHelper.exportarParaPDF(
        nomeSimulacao: nomeSimulacaoController.text,
        semestreSelecionado: semestreSelecionado,
        tipoPeriodo: tipoPeriodo,
        simulacaoAtual: simulacaoAtual,
        periodosAtivos: _getPeriodosAtivos(),
        getCHTotalDisciplinas: _getCHTotalDisciplinas,
        getCHAlocada: _getCHAlocada,
        getCHRestante: _getCHRestante,
        getDisciplinasPorPeriodo: _getDisciplinasPorPeriodo,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exportado com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodos = _getPeriodosAtivos();

    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Confirmar Saída'),
                content: const Text(
                    'Você salvou suas alterações? Se sair agora, dados não salvos serão perdidos.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false), // Não sair
                    child: const Text('Voltar'),
                  ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true), // Sair
                    child: const Text('Sair sem Salvar',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );

          if (shouldExit == true) {
            if (context.mounted) Navigator.pop(context);
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 600;

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                elevation: 0,
                centerTitle: false,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Simulação de Carga Horária',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    if (nomeSimulacaoController.text.isNotEmpty)
                      Text(
                        'Editando: ${nomeSimulacaoController.text}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                backgroundColor: const Color(0xFF0F172A),
                iconTheme: const IconThemeData(color: Colors.white),
                actions: _buildResponsiveActions(isMobile),
              ),
              body: DefaultTabController(
                key: ValueKey(tipoPeriodo),
                length: periodos.length,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF0F172A),
                                const Color(0xFF64748B).withOpacity(0.05),
                              ],
                              stops: const [0.0, 0.15],
                            ),
                          ),
                          padding:
                              const EdgeInsets.all(24.0).copyWith(bottom: 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildControlesModernos(),
                              const SizedBox(height: 20),
                              _buildSimulacoesSalvasSection(),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                      SliverAppBar(
                        pinned: true,
                        primary: false,
                        automaticallyImplyLeading: false,
                        backgroundColor: const Color(0xFFF8FAFC),
                        elevation: 0,
                        toolbarHeight: 0,
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(50),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: Color(0xFFE2E8F0), width: 1)),
                            ),
                            child: TabBar(
                              isScrollable: true,
                              labelColor: const Color(0xFF1E293B),
                              unselectedLabelColor: const Color(0xFF94A3B8),
                              indicatorColor: const Color(0xFF3B82F6),
                              labelStyle:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              tabs: periodos
                                  .map((p) => Tab(text: '$p Período'))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    children: periodos.map((periodo) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 16.0),
                        child: _buildCardPeriodo(periodo),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ));
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Tooltip(
        message: label,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildControlesModernos() {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isMobile = constraints.maxWidth < 600;

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: isMobile
            ? Column(
                children: [
                  _buildTextField(
                    controller: nomeSimulacaoController,
                    label: 'Nome da Simulação',
                    icon: Icons.edit_note_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    value: semestreSelecionado.isNotEmpty
                        ? semestreSelecionado
                        : null,
                    label: 'Semestre',
                    icon: Icons.calendar_today_rounded,
                    items: semestres
                        .map((s) => DropdownMenuItem<String>(
                              value: s['display'],
                              child: Text(s['display']),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => semestreSelecionado = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    value: tipoPeriodo,
                    label: 'Tipo de Período',
                    icon: Icons.layers_rounded,
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'impar',
                        child: Text('Períodos Ímpares'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'par',
                        child: Text('Períodos Pares'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => tipoPeriodo = v ?? 'impar'),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: nomeSimulacaoController,
                      label: 'Nome da Simulação',
                      icon: Icons.edit_note_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdown(
                      value: semestreSelecionado.isNotEmpty
                          ? semestreSelecionado
                          : null,
                      label: 'Semestre',
                      icon: Icons.calendar_today_rounded,
                      items: semestres
                          .map((s) => DropdownMenuItem<String>(
                                value: s['display'],
                                child: Text(s['display']),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => semestreSelecionado = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdown(
                      value: tipoPeriodo,
                      label: 'Tipo de Período',
                      icon: Icons.layers_rounded,
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'impar',
                          child: Text('Períodos Ímpares'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'par',
                          child: Text('Períodos Pares'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => tipoPeriodo = v ?? 'impar'),
                    ),
                  ),
                ],
              ),
      );
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true, // Adicionado para evitar overflow de texto
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildSimulacoesSalvasSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_rounded,
                color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 12),
            const Text(
              'Simulações Salvas',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${simulacoesSalvas.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ),
        children: [
          if (simulacoesSalvas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Nenhuma simulação encontrada.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            )
          else
            Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListView.separated(
                itemCount: simulacoesSalvas.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final simulacao = simulacoesSalvas[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        simulacao['nome_simulacao'],
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${simulacao['semestre']} • ${simulacao['tipo_periodo'] == 'impar' ? 'Ímpares' : 'Pares'}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.redAccent),
                            onPressed: () => _excluirSimulacao(simulacao['id']),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: () => _carregarSimulacao(simulacao),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(80, 32),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Carregar',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardPeriodo(String periodo) {
    final Map<String, dynamic> periodoData = simulacaoAtual[periodo] ?? {};
    final Map<String, dynamic> rawDetalhamento =
        periodoData['detalhamento'] ?? {};

    // Converter para o tipo esperado Map<String, List<Map<String, dynamic>>>
    final Map<String, List<Map<String, dynamic>>> detalhamentoTyped = {};
    rawDetalhamento.forEach((key, value) {
      if (value is List) {
        detalhamentoTyped[key] = List<Map<String, dynamic>>.from(value);
      }
    });

    return CardPeriodoWidget(
      periodo: periodo,
      disciplinasPeriodo: _getDisciplinasPorPeriodo(periodo),
      alocacoes: simulacaoAtual[periodo]?['alocacoes'] ?? [],
      detalhamento: detalhamentoTyped,
      chTotal: _getCHTotalDisciplinas(periodo),
      chAlocada: _getCHAlocada(periodo),
      chRestante: _getCHRestante(periodo),
      onAlternarDisciplina: _alternarDisciplina,
      onAdicionarDocente: () => _mostrarDialogAdicionarDocente(periodo),
      onEditarDocente: (aloc) => _mostrarDialogEditarDocente(periodo, aloc),
      onRemoverAlocacao: (docId) => _removerAlocacao(periodo, docId),
      onAdicionarAlocacaoDetalhada: (discId) =>
          _mostrarDialogAlocacaoDetalhada(periodo, discId),
      onEditarAlocacaoDetalhada: (discId, docenteId, aloc) =>
          _mostrarDialogAlocacaoDetalhada(periodo, discId,
              alocacaoExistente: aloc),
      onRemoverAlocacaoDetalhada: (discId, aloc) =>
          _removerAlocacaoDetalhada(periodo, discId, aloc),
    );
  }

  void _mostrarDialogAdicionarDocente(String periodo) {
    String? docenteSelecionado;
    final chController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Adicionar Docente - Período $periodo',
              style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: docenteSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Docente',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 14),
                items: professores
                    .map((professor) => DropdownMenuItem<String>(
                          value: professor['id'],
                          child: Text(professor['apelido'],
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (value) => docenteSelecionado = value,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: chController,
                decoration: const InputDecoration(
                  labelText: 'CH Alocada (horas)',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () {
                if (docenteSelecionado != null &&
                    chController.text.isNotEmpty) {
                  final chAlocada = double.tryParse(chController.text) ?? 0;
                  _adicionarAlocacao(periodo, docenteSelecionado!, chAlocada);
                  Navigator.pop(context);
                }
              },
              child: const Text('Adicionar', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogEditarDocente(
      String periodo, Map<String, dynamic> alocacao) {
    final chController =
        TextEditingController(text: alocacao['ch_alocada'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar CH - ${alocacao['docente_nome']}',
              style: const TextStyle(fontSize: 16)),
          content: TextField(
            controller: chController,
            decoration: const InputDecoration(
              labelText: 'CH Alocada (horas)',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 14),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () {
                if (chController.text.isNotEmpty) {
                  final chAlocada = double.tryParse(chController.text) ?? 0;
                  _adicionarAlocacao(
                      periodo, alocacao['docente_id'], chAlocada);
                  Navigator.pop(context);
                }
              },
              child: const Text('Salvar', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarDialogAlocacaoDetalhada(
      String periodo, String disciplinaId,
      {Map<String, dynamic>? alocacaoExistente}) async {
    final disciplina = disciplinas.firstWhere((d) => d['id'] == disciplinaId);

    // Calcular CH Disponível
    final chTotal = disciplina['ch_aula']?.toDouble() ?? 0.0;

    final periodoDataRef = simulacaoAtual[periodo] ?? {};
    final detalhamentoRef = periodoDataRef['detalhamento'] ?? {};
    final List<dynamic> alocacoesDaDisc = detalhamentoRef[disciplinaId] ?? [];

    double chJaAlocada = 0;
    for (var a in alocacoesDaDisc) {
      chJaAlocada += (a['ch_alocada'] ?? 0).toDouble();
    }

    double chDisponivel = chTotal - chJaAlocada;

    // Se for edição, devolve a CH da alocação atual para o saldo disponível
    if (alocacaoExistente != null) {
      chDisponivel += (alocacaoExistente['ch_alocada'] ?? 0).toDouble();
    }

    final resultado = await showDialog<dynamic>(
      context: context,
      builder: (context) => DialogAlocacaoDetalhada(
        titulo:
            '${disciplina['nome']} - ${alocacaoExistente == null ? 'Nova Alocação' : 'Editar'}',
        professores: professores,
        alocacaoExistente: alocacaoExistente,
        chPadrao: disciplina['ch_aula']?.toDouble() ?? 0,
        chDisponivel: chDisponivel,
      ),
    );

    if (resultado != null) {
      setState(() {
        if (!simulacaoAtual.containsKey(periodo)) {
          simulacaoAtual[periodo] = {};
        }

        final periodoData = simulacaoAtual[periodo]!;
        final Map<String, dynamic> rawDetalhamento =
            periodoData['detalhamento'] ?? {};
        final detalhamento = Map<String, dynamic>.from(rawDetalhamento);

        if (!detalhamento.containsKey(disciplinaId)) {
          detalhamento[disciplinaId] = [];
        }

        List<dynamic> listaAlocacoes =
            List.from(detalhamento[disciplinaId] ?? []);

        // Normalizar resultado para Lista
        List<Map<String, dynamic>> novosItens = [];
        if (resultado is List) {
          novosItens = List<Map<String, dynamic>>.from(resultado);
        } else if (resultado is Map) {
          novosItens = [Map<String, dynamic>.from(resultado)];
        }

        for (var item in novosItens) {
          final prof = professores.firstWhere(
              (p) => p['id'] == item['docente_id'],
              orElse: () => {'apelido': 'Desconhecido'});
          item['docente_nome'] = prof['apelido'];

          if (alocacaoExistente != null) {
            // Edição (assumindo que edição é sempre unitária por enquanto)
            final index = listaAlocacoes.indexOf(alocacaoExistente);
            if (index != -1) {
              listaAlocacoes[index] = item;
            }
          } else {
            // Novo
            listaAlocacoes.add(item);
          }
        }

        detalhamento[disciplinaId] = listaAlocacoes;
        periodoData['detalhamento'] = detalhamento;

        _recalcularAlocacoesPorPeriodo(periodo);
      });
    }
  }

  void _removerAlocacaoDetalhada(
      String periodo, String disciplinaId, Map<String, dynamic> alocacao) {
    setState(() {
      final periodoData = simulacaoAtual[periodo];
      if (periodoData == null) return;

      final Map<String, dynamic> rawDetalhamento =
          periodoData['detalhamento'] ?? {};
      final detalhamento = Map<String, dynamic>.from(rawDetalhamento);

      if (detalhamento.containsKey(disciplinaId)) {
        List<dynamic> lista = List.from(detalhamento[disciplinaId]);
        lista.remove(alocacao);
        detalhamento[disciplinaId] = lista;
        periodoData['detalhamento'] = detalhamento;

        _recalcularAlocacoesPorPeriodo(periodo);
      }
    });
  }

  void _recalcularAlocacoesPorPeriodo(String periodo) {
    final periodoData = simulacaoAtual[periodo];
    if (periodoData == null) return;

    final Map<String, dynamic> rawDetalhamento =
        periodoData['detalhamento'] ?? {};
    final Map<String, double> somaPorDocente = {};
    final Map<String, String> nomesPorDocente = {};

    rawDetalhamento.forEach((discId, listaAlocacoes) {
      if (listaAlocacoes is List) {
        for (var aloc in listaAlocacoes) {
          final docId = aloc['docente_id'];
          final ch = (aloc['ch_alocada'] ?? 0).toDouble();
          final nome = aloc['docente_nome'] ?? '';

          if (docId != null) {
            somaPorDocente[docId] = (somaPorDocente[docId] ?? 0) + ch;
            nomesPorDocente[docId] = nome;
          }
        }
      }
    });

    final List<Map<String, dynamic>> novasAlocacoes = [];
    somaPorDocente.forEach((docId, chTotal) {
      novasAlocacoes.add({
        'docente_id': docId,
        'docente_nome': nomesPorDocente[docId],
        'ch_alocada': chTotal,
      });
    });

    periodoData['alocacoes'] = novasAlocacoes;
  }

  Future<void> _efetivarNaGrade() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Efetivar Simulação na Grade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Deseja aplicar a simulação "${nomeSimulacaoController.text}" na grade de aulas do semestre $semestreSelecionado?'),
              const SizedBox(height: 12),
              const Text(
                  'ATENÇÃO: Toda a grade atual deste semestre será apagada antes da aplicação.',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aplicar e Substituir',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await supabase
          .from('grade_aulas')
          .delete()
          .eq('semestre', semestreSelecionado);

      final List<Map<String, dynamic>> inserts = [];

      simulacaoAtual.forEach((periodo, periodoData) {
        final Map<String, dynamic> detalhamento =
            periodoData['detalhamento'] ?? {};

        detalhamento.forEach((discId, listaAlocacoes) {
          if (listaAlocacoes is List) {
            for (var aloc in listaAlocacoes) {
              final docenteId = aloc['docente_id'];
              final List<dynamic> slots = aloc['slots'] ?? [];

              for (var slot in slots) {
                if (slot is String && slot.contains('-')) {
                  final parts = slot.split('-'); // [Segunda, M1]
                  if (parts.length >= 2) {
                    final dia = parts[0];
                    final timeCode = parts[1]; // M1

                    final turnoLetra = timeCode[0]; // M
                    final indiceStr = timeCode.substring(1); // 1
                    final indice = int.tryParse(indiceStr) ?? 0;

                    String turno = 'Manhã';
                    if (turnoLetra == 'T') turno = 'Tarde';
                    if (turnoLetra == 'N') turno = 'Noite';

                    int indiceGlobal = indice;
                    if (turno == 'Tarde') indiceGlobal += 6;
                    if (turno == 'Noite') indiceGlobal += 12;

                    inserts.add({
                      'semestre': semestreSelecionado,
                      'dia': dia,
                      'turno': turno,
                      'indice': indiceGlobal,
                      'disciplina_id': discId,
                      'professores': [docenteId],
                    });
                  }
                }
              }
            }
          }
        });
      });

      if (inserts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Nenhum horário definido na simulação para exportar.')));
        }
        return;
      }

      await supabase.from('grade_aulas').insert(inserts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Sucesso! ${inserts.length} aulas agendadas na grade.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao efetivar na grade: $e')));
      }
    }
  }

  List<Widget> _buildResponsiveActions(bool isMobile) {
    if (isMobile) {
      return [
        IconButton(
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          onPressed: _novaSimulacao,
          tooltip: 'Novo',
        ),
        IconButton(
          icon: const Icon(Icons.save_rounded, color: Color(0xFF3B82F6)),
          onPressed: () => _salvarSimulacao(),
          tooltip: 'Salvar',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'clonar':
                _salvarSimulacao(comoNovo: true);
                break;
              case 'grade':
                _efetivarNaGrade();
                break;
              case 'pdf':
                _exportarParaPDF();
                break;
            }
          },
          itemBuilder: (context) => [
            if (idSimulacaoEditando != null)
              const PopupMenuItem(
                value: 'clonar',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded,
                        size: 20, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 12),
                    Text('Clonar Simulação'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'grade',
              child: Row(
                children: [
                  Icon(Icons.grid_on_rounded, size: 20, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Aplicar na Grade'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      size: 20, color: Color(0xFFEF4444)),
                  SizedBox(width: 12),
                  Text('Exportar PDF'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ];
    }

    return [
      _buildActionButton(
        icon: Icons.add_rounded,
        label: 'Novo',
        onPressed: _novaSimulacao,
        color: Colors.white24,
      ),
      const SizedBox(width: 8),
      _buildActionButton(
        icon: Icons.save_rounded,
        label: 'Salvar',
        onPressed: () => _salvarSimulacao(),
        color: const Color(0xFF3B82F6),
      ),
      if (idSimulacaoEditando != null) ...[
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.copy_rounded,
          label: 'Clonar',
          onPressed: () => _salvarSimulacao(comoNovo: true),
          color: const Color(0xFF8B5CF6),
        ),
      ],
      const SizedBox(width: 8),
      _buildActionButton(
        icon: Icons.grid_on_rounded,
        label: 'Aplicar na Grade',
        onPressed: _efetivarNaGrade,
        color: Colors.green,
      ),
      const SizedBox(width: 8),
      _buildActionButton(
        icon: Icons.picture_as_pdf_rounded,
        label: 'PDF',
        onPressed: _exportarParaPDF,
        color: const Color(0xFFEF4444),
      ),
      const SizedBox(width: 12),
    ];
  }
}
