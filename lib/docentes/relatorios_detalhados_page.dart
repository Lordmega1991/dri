import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RelatoriosDetalhadosPage extends StatefulWidget {
  const RelatoriosDetalhadosPage({super.key});

  @override
  State<RelatoriosDetalhadosPage> createState() =>
      _RelatoriosDetalhadosPageState();
}

class _RelatoriosDetalhadosPageState extends State<RelatoriosDetalhadosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _semestres = [];
  List<Map<String, dynamic>> _docentes = [];

  // Seleção de Semestres para Comparação
  Map<String, dynamic>? _semestreA;
  Map<String, dynamic>? _semestreB;

  // Métrica Selecionada
  String _metricaSelecionada = 'Todas';
  final List<Map<String, dynamic>> _metricsOptions = [
    {'id': 'Todas', 'label': 'Geral', 'icon': Icons.analytics_rounded},
    {'id': 'Aulas', 'label': 'Aulas', 'icon': Icons.menu_book_rounded},
    {'id': 'Bancas', 'label': 'Bancas', 'icon': Icons.school_rounded},
    {
      'id': 'Manuais',
      'label': 'Atv. Acadêmicas',
      'icon': Icons.assignment_rounded
    },
  ];

  // Dados Agregados para o Gráfico
  Map<String, Map<String, double>> _comparativoAtividades = {};

  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _carregando = true);
    try {
      final results = await Future.wait([
        _supabase
            .from('semestres')
            .select()
            .order('ano', ascending: false)
            .order('semestre', ascending: false),
        _supabase.from('docentes').select().order('nome'),
      ]);

      setState(() {
        _semestres = List<Map<String, dynamic>>.from(results[0] as List);
        _docentes = List<Map<String, dynamic>>.from(results[1] as List);

        if (_semestres.length >= 2) {
          _semestreA = _semestres[0];
          _semestreB = _semestres[1];
        } else if (_semestres.isNotEmpty) {
          _semestreA = _semestres[0];
        }
      });

      if (_semestreA != null && _semestreB != null) {
        await _gerarComparativo();
      }
    } catch (e) {
      _mostrarErro('Erro ao carregar dados: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _gerarComparativo() async {
    if (_semestreA == null || _semestreB == null) return;
    setState(() => _carregando = true);

    try {
      final results = await Future.wait([
        _fetchDadosSemestre(_semestreA!),
        _fetchDadosSemestre(_semestreB!),
      ]);

      final Map<String, Map<String, double>> novoComparativo = {};
      for (var d in _docentes) {
        final nome = d['apelido'] ?? d['nome'];
        novoComparativo[nome] = {'A': 0, 'B': 0};
      }

      _processarParaMapa(novoComparativo, results[0], 'A');
      _processarParaMapa(novoComparativo, results[1], 'B');

      setState(() {
        _comparativoAtividades = novoComparativo;
      });
    } catch (e) {
      _mostrarErro('Erro na comparação: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchDadosSemestre(
      Map<String, dynamic> semestre) async {
    final semestreId = semestre['id'];
    final semestreStr = '${semestre['ano']}.${semestre['semestre']}';

    final results = await Future.wait([
      _supabase
          .from('atividades_docentes')
          .select('*, docentes(nome, apelido)')
          .eq('semestre_id', semestreId)
          .eq('status', 'aprovado'),
      _supabase
          .from('grade_aulas')
          .select('*, disciplinas(*)')
          .eq('semestre', semestreStr),
      _supabase.from('dados_defesas').select().eq('semestre', semestreStr),
    ]);

    return {
      'atividades': List<Map<String, dynamic>>.from(results[0] as List),
      'aulas': List<Map<String, dynamic>>.from(results[1] as List),
      'defesas': List<Map<String, dynamic>>.from(results[2] as List),
    };
  }

  void _processarParaMapa(Map<String, Map<String, double>> mapa,
      Map<String, List<Map<String, dynamic>>> dados, String label) {
    if (_metricaSelecionada == 'Todas' || _metricaSelecionada == 'Manuais') {
      for (var atv in dados['atividades']!) {
        final nome = atv['docentes']?['apelido'] ?? atv['docentes']?['nome'];
        if (nome != null && mapa.containsKey(nome)) {
          mapa[nome]![label] = (mapa[nome]![label] ?? 0) + 1;
        }
      }
    }

    if (_metricaSelecionada == 'Todas' || _metricaSelecionada == 'Aulas') {
      for (var aula in dados['aulas']!) {
        final profIds = aula['professores'] as List?;
        if (profIds != null) {
          for (var pId in profIds) {
            final docente =
                _docentes.firstWhere((d) => d['id'] == pId, orElse: () => {});
            final nome = docente['apelido'] ?? docente['nome'];
            if (nome != null && mapa.containsKey(nome)) {
              mapa[nome]![label] = (mapa[nome]![label] ?? 0) + 0.5;
            }
          }
        }
      }
    }

    if (_metricaSelecionada == 'Todas' || _metricaSelecionada == 'Bancas') {
      for (var d in dados['defesas']!) {
        final orientador = d['orientador']?.toString().toLowerCase() ?? '';
        final ava1 = d['avaliador1']?.toString().toLowerCase() ?? '';
        final ava2 = d['avaliador2']?.toString().toLowerCase() ?? '';
        final ava3 = d['avaliador3']?.toString().toLowerCase() ?? '';

        for (var doc in _docentes) {
          final nomeDoc = doc['nome'].toString().toLowerCase();
          final apelidoDoc = (doc['apelido'] ?? '').toString().toLowerCase();
          bool envolve = orientador.contains(nomeDoc) ||
              ava1.contains(nomeDoc) ||
              ava2.contains(nomeDoc) ||
              ava3.contains(nomeDoc);
          if (!envolve && apelidoDoc.isNotEmpty) {
            envolve = orientador.contains(apelidoDoc) ||
                ava1.contains(apelidoDoc) ||
                ava2.contains(apelidoDoc) ||
                ava3.contains(apelidoDoc);
          }
          if (envolve) {
            final nomeExibicao = doc['apelido'] ?? doc['nome'];
            if (mapa.containsKey(nomeExibicao)) {
              mapa[nomeExibicao]![label] =
                  (mapa[nomeExibicao]![label] ?? 0) + 1;
            }
          }
        }
      }
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildControlPanel(),
          if (_carregando)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else
            _buildChartAreaSliver(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text("Dashboard Vertical",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 20)
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _buildSemesterDropdown(
                          "Base (A)",
                          _semestreA,
                          (v) => setState(() => _semestreA = v),
                          const Color(0xFF6366F1))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildSemesterDropdown(
                          "Comparação (B)",
                          _semestreB,
                          (v) => setState(() => _semestreB = v),
                          const Color(0xFFF59E0B))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildMetricsSelector(),
            const SizedBox(height: 12),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterDropdown(
      String label, dynamic value, ValueChanged onChanged, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        DropdownButtonFormField<Map<String, dynamic>>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
          items: _semestres
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text("${s['ano']}.${s['semestre']}",
                      style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (v) {
            onChanged(v);
            _gerarComparativo();
          },
        ),
      ],
    );
  }

  Widget _buildMetricsSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _metricsOptions.map((opt) {
          final isSelected = _metricaSelecionada == opt['id'];
          return GestureDetector(
            onTap: () {
              setState(() => _metricaSelecionada = opt['id']);
              _gerarComparativo();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(opt['icon'],
                      size: 14,
                      color:
                          isSelected ? Colors.white : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(opt['label'],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF1E293B))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem("Semestre A", const Color(0xFF6366F1)),
        const SizedBox(width: 16),
        _legendItem("Semestre B", const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildChartAreaSliver() {
    if (_comparativoAtividades.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox());

    final sortedDocentes = _comparativoAtividades.keys.toList()
      ..sort((a, b) => (_comparativoAtividades[b]!['A'] ?? 0)
          .compareTo(_comparativoAtividades[a]!['A'] ?? 0));

    double maxVal = 2.0;
    for (var entry in _comparativoAtividades.values) {
      if (entry['A']! > maxVal) maxVal = entry['A']!;
      if (entry['B']! > maxVal) maxVal = entry['B']!;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          height: 450,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
              ]),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: sortedDocentes.map((docente) {
                final valA = _comparativoAtividades[docente]!['A']!;
                final valB = _comparativoAtividades[docente]!['B']!;
                if (valA == 0 && valB == 0) return const SizedBox();
                return _buildVerticalBarGroup(docente, valA, valB, maxVal);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalBarGroup(
      String docente, double valA, double valB, double max) {
    const maxHeight = 300.0;
    return Container(
      margin: const EdgeInsets.only(right: 32),
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _verticalBar(valA, max, maxHeight, const Color(0xFF6366F1)),
              const SizedBox(width: 4),
              _verticalBar(valB, max, maxHeight, const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                docente,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalBar(double val, double max, double maxHeight, Color color) {
    final height = max > 0 ? (val / max) * maxHeight : 2.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(val.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          width: 14,
          height: height.clamp(2.0, maxHeight),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2))
            ],
          ),
        ),
      ],
    );
  }
}
