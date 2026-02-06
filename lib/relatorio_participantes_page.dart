import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'pdf_generator.dart';

class RelatorioParticipantesPage extends StatefulWidget {
  const RelatorioParticipantesPage({super.key});

  @override
  State<RelatorioParticipantesPage> createState() =>
      _RelatorioParticipantesPageState();
}

class _RelatorioParticipantesPageState
    extends State<RelatorioParticipantesPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> defesas = [];
  List<Participante> participantes = [];
  List<String> todosProfessores = [];
  List<String> semestres = [];

  bool loading = true;
  String? semestreSelecionado;
  String? professorSelecionado;

  // Controles de ordenação
  String _colunaOrdenada = 'total';
  bool _ordenacaoAscendente = false;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() => loading = true);

    try {
      final response = await supabase
          .from('dados_defesas')
          .select()
          .order('semestre', ascending: false)
          .order('dia', ascending: true);

      final defesasCarregadas =
          List<Map<String, dynamic>>.from(response as List<dynamic>);

      // Busca semestres reais da tabela oficial 'semestres'
      final semestresResponse = await supabase
          .from('semestres')
          .select('ano, semestre')
          .order('ano', ascending: false)
          .order('semestre', ascending: false);

      final semestresUnicos = (semestresResponse as List)
          .map((s) => "${s['ano']}.${s['semestre']}")
          .toList();

      // Extrai todos os professores independentemente do filtro
      final profSet = <String>{};
      for (var d in defesasCarregadas) {
        if (d['orientador'] != null)
          profSet.add(d['orientador'].toString().trim());
        if (d['coorientador'] != null)
          profSet.add(d['coorientador'].toString().trim());
        if (d['avaliador1'] != null)
          profSet.add(d['avaliador1'].toString().trim());
        if (d['avaliador2'] != null)
          profSet.add(d['avaliador2'].toString().trim());
        if (d['avaliador3'] != null)
          profSet.add(d['avaliador3'].toString().trim());
      }
      final profList = profSet.where((s) => s.isNotEmpty).toList()..sort();

      setState(() {
        defesas = defesasCarregadas;
        semestres = semestresUnicos;
        todosProfessores = profList;
        // Inicialmente mostra o semestre mais recente
        semestreSelecionado =
            semestresUnicos.isNotEmpty ? semestresUnicos.first : null;
      });

      gerarRelatorio();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar dados: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _limparNome(String n) {
    return n
        .toUpperCase()
        .replaceAll(
            RegExp(r'\b(PROF(A)?|DR(A)?|ME|MA|PHD|MS|MSC)\.?\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+'), ' ') // Normaliza espaços extras
        .trim();
  }

  void gerarRelatorio() {
    final participantesMap = <String, Participante>{};

    // Filtra defesas com base nos seletores
    final defesasParaProcessar = defesas.where((d) {
      final matchSemestre =
          semestreSelecionado == null || d['semestre'] == semestreSelecionado;
      return matchSemestre;
    }).toList();

    for (final d in defesasParaProcessar) {
      // Pequena limpeza para comparação robusta
      final orientadorOrig = d['orientador']?.toString().trim() ?? '';
      final coorientadorOrig = d['coorientador']?.toString().trim() ?? '';
      final av1Orig = d['avaliador1']?.toString().trim() ?? '';
      final av2Orig = d['avaliador2']?.toString().trim() ?? '';
      final av3Orig = d['avaliador3']?.toString().trim() ?? '';

      final orientadorLimpo = _limparNome(orientadorOrig);
      final coorientadorLimpo = _limparNome(coorientadorOrig);

      // 1. Processar Orientador
      if (orientadorLimpo.isNotEmpty) {
        participantesMap.putIfAbsent(
            orientadorLimpo, () => Participante(nome: orientadorOrig));
        participantesMap[orientadorLimpo]!.adicionarOrientador();
      }

      // 2. Processar Coorientador
      if (coorientadorLimpo.isNotEmpty) {
        participantesMap.putIfAbsent(
            coorientadorLimpo, () => Participante(nome: coorientadorOrig));
        participantesMap[coorientadorLimpo]!.adicionarCoorientador();
      }

      // 3. Processar Avaliadores ÚNICOS na banca
      // (evitando double count e não contando se for O/CO)
      final avaliadoresLimpos = <String>{};
      if (av1Orig.isNotEmpty) avaliadoresLimpos.add(_limparNome(av1Orig));
      if (av2Orig.isNotEmpty) avaliadoresLimpos.add(_limparNome(av2Orig));
      if (av3Orig.isNotEmpty) avaliadoresLimpos.add(_limparNome(av3Orig));

      for (var avLimpo in avaliadoresLimpos) {
        if (avLimpo.isNotEmpty &&
            avLimpo != orientadorLimpo &&
            avLimpo != coorientadorLimpo) {
          // Busca o nome original para exibir (pode usar o do AV1, AV2 ou AV3 se não houver de O/CO)
          String nomeParaExibir = '';
          if (avLimpo == _limparNome(av1Orig))
            nomeParaExibir = av1Orig;
          else if (avLimpo == _limparNome(av2Orig))
            nomeParaExibir = av2Orig;
          else
            nomeParaExibir = av3Orig;

          participantesMap.putIfAbsent(
              avLimpo, () => Participante(nome: nomeParaExibir));
          participantesMap[avLimpo]!.adicionarAvaliador();
        }
      }
    }

    var lista = participantesMap.values.toList();

    // Filtro por Professor específico na lista final
    if (professorSelecionado != null && professorSelecionado!.isNotEmpty) {
      final profFiltroLimpo = _limparNome(professorSelecionado!);
      lista =
          lista.where((p) => _limparNome(p.nome) == profFiltroLimpo).toList();
    }

    _ordenarLista(lista);

    setState(() {
      participantes = lista;
    });
  }

  void _ordenarLista(List<Participante> lista) {
    lista.sort((a, b) {
      int comp;
      switch (_colunaOrdenada) {
        case 'nome':
          comp = _limparNome(a.nome).compareTo(_limparNome(b.nome));
          break;
        case 'orientador':
          comp = a.orientador.compareTo(b.orientador);
          break;
        case 'coorientador':
          comp = a.coorientador.compareTo(b.coorientador);
          break;
        case 'avaliador':
          comp = a.avaliador.compareTo(b.avaliador);
          break;
        case 'total':
          comp = a.total.compareTo(b.total);
          break;
        default:
          comp = a.total.compareTo(b.total);
      }
      return _ordenacaoAscendente ? comp : -comp;
    });
  }

  void _mudarOrdenacao(String coluna) {
    setState(() {
      if (_colunaOrdenada == coluna) {
        _ordenacaoAscendente = !_ordenacaoAscendente;
      } else {
        _colunaOrdenada = coluna;
        _ordenacaoAscendente = false;
      }
      _ordenarLista(participantes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          _buildFiltros(),
          if (loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (participantes.isEmpty)
            const SliverFillRemaining(
                child: Center(child: Text("Nenhuma participação encontrada.")))
          else
            _buildTabela(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ESTATÍSTICAS",
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF38BDF8),
                    letterSpacing: 1)),
            Text("Participações Docentes",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => PdfGenerator.generateRelatorioParticipantesReport(
              participantes, semestreSelecionado, professorSelecionado),
          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFiltros() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: "Semestre",
                      value: semestreSelecionado,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text("Todos os semestres")),
                        ...semestres.map(
                            (s) => DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      onChanged: (val) {
                        setState(() => semestreSelecionado = val);
                        gerarRelatorio();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Docente",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        SearchAnchor(
                          viewHintText: "Pesquisar docente...",
                          builder: (BuildContext context,
                              SearchController controller) {
                            return InkWell(
                              onTap: () => controller.openView(),
                              child: Container(
                                height: 48,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        professorSelecionado ??
                                            "Todos os docentes",
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.search_rounded,
                                        size: 18, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            );
                          },
                          suggestionsBuilder: (BuildContext context,
                              SearchController controller) {
                            final String query = controller.text.toLowerCase();
                            final filtered = todosProfessores
                                .where((p) => p.toLowerCase().contains(query))
                                .toList();

                            return [
                              if (query.isEmpty ||
                                  "todos os docentes".contains(query))
                                ListTile(
                                  title: const Text("Todos os docentes",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  onTap: () {
                                    setState(() => professorSelecionado = null);
                                    gerarRelatorio();
                                    controller.closeView(null);
                                  },
                                ),
                              ...filtered.map((p) => ListTile(
                                    title: Text(p),
                                    onTap: () {
                                      setState(() => professorSelecionado = p);
                                      gerarRelatorio();
                                      controller.closeView(p);
                                    },
                                  )),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(Icons.groups_rounded, "Docentes",
                      participantes.length.toString()),
                  _buildStat(
                      Icons.assignment_ind_rounded,
                      "Total de Participações",
                      participantes
                          .fold(0, (sum, p) => sum + p.total)
                          .toString()),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      {required String label,
      required dynamic value,
      required List<DropdownMenuItem> items,
      required Function(dynamic) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0284C7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.bold)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
          ],
        )
      ],
    );
  }

  Widget _buildTabela() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12, left: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    "Dica: Toque nos títulos das colunas para ordenar a lista",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 52,
                  dataRowMaxHeight: 52,
                  dataRowMinHeight: 48,
                  columnSpacing: 40,
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: [
                    DataColumn(
                        label: _buildHeaderCell('PROFESSOR', 'nome'),
                        onSort: (_, __) => _mudarOrdenacao('nome')),
                    DataColumn(
                        label: _buildHeaderCell('ORIENT.', 'orientador'),
                        onSort: (_, __) => _mudarOrdenacao('orientador')),
                    DataColumn(
                        label: _buildHeaderCell('COORIENT.', 'coorientador'),
                        onSort: (_, __) => _mudarOrdenacao('coorientador')),
                    DataColumn(
                        label: _buildHeaderCell('AVAL.', 'avaliador'),
                        onSort: (_, __) => _mudarOrdenacao('avaliador')),
                    DataColumn(
                        label: _buildHeaderCell('TOTAL', 'total'),
                        onSort: (_, __) => _mudarOrdenacao('total')),
                  ],
                  rows: participantes.asMap().entries.map<DataRow>((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final isEven = idx % 2 == 0;
                    return DataRow(
                      color: WidgetStateProperty.all(isEven
                          ? Colors.white
                          : const Color(0xFFF1F5F9).withOpacity(0.5)),
                      cells: [
                        DataCell(Text(p.nome.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0C4A6E)))),
                        DataCell(_buildCountBadge(
                            p.orientador, const Color(0xFF0284C7))),
                        DataCell(_buildCountBadge(
                            p.coorientador, const Color(0xFF64748B))),
                        DataCell(_buildCountBadge(
                            p.avaliador, const Color(0xFF0F766E))),
                        DataCell(_buildTotalBadge(p.total)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, String id) {
    final isSelected = _colunaOrdenada == id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isSelected
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF94A3B8))),
        if (isSelected)
          Icon(
              _ordenacaoAscendente
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 12,
              color: const Color(0xFF0284C7)),
      ],
    );
  }

  Widget _buildCountBadge(int count, Color color) {
    if (count == 0)
      return const Center(
          child: Text('0',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)));
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(count.toString(),
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }

  Widget _buildTotalBadge(int total) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8)),
        child: Text(total.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12)),
      ),
    );
  }
}

class Participante {
  final String nome;
  int orientador = 0;
  int coorientador = 0;
  int avaliador = 0;
  Participante({required this.nome});
  void adicionarOrientador() => orientador++;
  void adicionarCoorientador() => coorientador++;
  void adicionarAvaliador() => avaliador++;
  int get total => orientador + coorientador + avaliador;
}
