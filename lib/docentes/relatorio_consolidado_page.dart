import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RelatorioConsolidadoPage extends StatefulWidget {
  const RelatorioConsolidadoPage({super.key});

  @override
  State<RelatorioConsolidadoPage> createState() =>
      _RelatorioConsolidadoPageState();
}

class _RelatorioConsolidadoPageState extends State<RelatorioConsolidadoPage> {
  final supabase = Supabase.instance.client;

  // Estado
  bool _loading = false;
  List<Map<String, dynamic>> _semestres = [];
  String? _semestreSelecionado;
  Map<String, dynamic>? _dadosRelatorio;
  List<Map<String, dynamic>> _atividadesDetalhadas = [];

  @override
  void initState() {
    super.initState();
    _carregarSemestres();
  }

  Future<void> _carregarSemestres() async {
    setState(() => _loading = true);

    try {
      final response = await supabase
          .from('semestres')
          .select('*')
          .order('ano', ascending: false)
          .order('semestre', ascending: false);

      setState(() {
        _semestres = (response as List).cast<Map<String, dynamic>>();
        if (_semestres.isNotEmpty) {
          _semestreSelecionado = _semestres.first['id']?.toString();
          _carregarRelatorio();
        }
      });
    } catch (e) {
      _mostrarErro('Erro ao carregar semestres: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _carregarRelatorio() async {
    if (_semestreSelecionado == null) return;

    setState(() => _loading = true);

    try {
      // Buscar dados do semestre selecionado
      final semestre = _semestres.firstWhere(
        (s) => s['id']?.toString() == _semestreSelecionado,
        orElse: () => {},
      );

      // Buscar atividades dos docentes no semestre
      final atividadesResponse = await supabase
          .from('atividades_docentes')
          .select('''
            *,
            docentes(nome, email, matricula),
            tipos_atividade(nome, categoria, unidade_medida)
          ''')
          .eq('semestre_id', _semestreSelecionado!)
          .eq('status', 'aprovado');

      final atividades =
          (atividadesResponse as List).cast<Map<String, dynamic>>();

      // Buscar defesas no semestre
      final semestreFormatado = '${semestre['ano']}.${semestre['semestre']}';
      final defesasResponse = await supabase
          .from('dados_defesas')
          .select('*')
          .eq('semestre', semestreFormatado);

      final defesas = (defesasResponse as List).cast<Map<String, dynamic>>();

      // Buscar grade de aulas no semestre
      final gradeResponse = await supabase.from('grade_aulas').select('''
            *,
            disciplinas(nome)
          ''').eq('semestre', semestreFormatado);

      final gradeAulas = (gradeResponse as List).cast<Map<String, dynamic>>();

      // Buscar todos os professores para mapeamento
      final professoresResponse =
          await supabase.from('docentes').select('id, nome, apelido');
      final listaProfessores =
          (professoresResponse as List).cast<Map<String, dynamic>>();

      // Processar dados para o relatório consolidado
      final dadosProcessados = _processarDadosRelatorio(
        atividades,
        defesas,
        gradeAulas,
        semestre,
        listaProfessores,
      );

      setState(() {
        _dadosRelatorio = dadosProcessados;
        _atividadesDetalhadas = atividades;
      });
    } catch (e, stack) {
      debugPrint('Erro no relatório: $e\n$stack');
      _mostrarErro('Erro ao carregar relatório: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _limparNome(String? n) {
    if (n == null) return '';
    return n
        .toUpperCase()
        .replaceAll(
            RegExp(r'\b(PROF(A)?|DR(A)?|ME|MA|PHD|MS|MSC)\.?\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Map<String, dynamic> _processarDadosRelatorio(
    List<Map<String, dynamic>> atividades,
    List<Map<String, dynamic>> defesas,
    List<Map<String, dynamic>> gradeAulas,
    Map<String, dynamic> semestre,
    List<Map<String, dynamic>> listaProfessores,
  ) {
    final atividadesPorDocente = <String, Map<String, dynamic>>{};
    final totaisPorCategoria = <String, double>{};
    final totaisPorTipo = <String, double>{};

    final profPorId = {
      for (var p in listaProfessores) p['id']?.toString() ?? '': p
    };
    final idPorNomeLimpo = {
      for (var p in listaProfessores)
        _limparNome(p['apelido'] ?? p['nome']): p['id']?.toString() ?? ''
    };

    void inicializarDocente(String id, String nome,
        [String? email, String? matricula]) {
      if (!atividadesPorDocente.containsKey(id)) {
        atividadesPorDocente[id] = {
          'nome': nome,
          'email': email,
          'matricula': matricula,
          'categorias': <String, double>{},
          'tipos': <String, double>{},
          'total_geral': 0.0,
        };
      }
    }

    for (final atividade in atividades) {
      final docente = atividade['docentes'];
      final tipoAtividade = atividade['tipos_atividade'];
      final docenteId = docente?['id']?.toString() ?? 'sem_id';
      final docenteNome = docente?['nome'] ?? 'Docente não identificado';
      final categoria = tipoAtividade?['categoria'] ?? 'Outros';
      final tipoNome = tipoAtividade?['nome'] ?? 'Atividade não identificada';
      final quantidade = (atividade['quantidade'] as num?)?.toDouble() ?? 0;

      inicializarDocente(
          docenteId, docenteNome, docente?['email'], docente?['matricula']);

      atividadesPorDocente[docenteId]!['categorias'][categoria] =
          (atividadesPorDocente[docenteId]!['categorias'][categoria] ?? 0.0) +
              quantidade;
      atividadesPorDocente[docenteId]!['tipos'][tipoNome] =
          (atividadesPorDocente[docenteId]!['tipos'][tipoNome] ?? 0.0) +
              quantidade;
      atividadesPorDocente[docenteId]!['total_geral'] += quantidade;

      totaisPorCategoria[categoria] =
          (totaisPorCategoria[categoria] ?? 0.0) + quantidade;
    }

    for (final aula in gradeAulas) {
      final professoresIds = aula['professores'] as List<dynamic>? ?? [];
      for (final pIdRaw in professoresIds) {
        final pId = pIdRaw.toString();
        final prof = profPorId[pId];
        final nome = prof?['apelido'] ?? prof?['nome'] ?? 'Docente ID: $pId';

        inicializarDocente(pId, nome);

        atividadesPorDocente[pId]!['categorias']['Ensino'] =
            (atividadesPorDocente[pId]!['categorias']['Ensino'] ?? 0.0) + 1.0;
        atividadesPorDocente[pId]!['total_geral'] += 1.0;

        totaisPorCategoria['Ensino'] =
            (totaisPorCategoria['Ensino'] ?? 0.0) + 1.0;
      }
    }

    final defesasPorOrientador = <String, int>{};
    for (final defesa in defesas) {
      final orientadorNome = defesa['orientador']?.toString().trim() ?? '';
      final nomeLimpo = _limparNome(orientadorNome);
      final pId = idPorNomeLimpo[nomeLimpo];

      defesasPorOrientador[orientadorNome] =
          (defesasPorOrientador[orientadorNome] ?? 0) + 1;

      if (pId != null) {
        inicializarDocente(pId, profPorId[pId]?['apelido'] ?? orientadorNome);
        const double chDefesa = 2.0;
        atividadesPorDocente[pId]!['categorias']['Ensino'] =
            (atividadesPorDocente[pId]!['categorias']['Ensino'] ?? 0.0) +
                chDefesa;
        atividadesPorDocente[pId]!['total_geral'] += chDefesa;

        totaisPorCategoria['Ensino'] =
            (totaisPorCategoria['Ensino'] ?? 0.0) + chDefesa;
      }
    }

    return {
      'semestre': semestre,
      'atividades_por_docente': atividadesPorDocente,
      'totais_categoria': totaisPorCategoria,
      'totais_tipo': totaisPorTipo,
      'total_defesas': defesas.length,
      'defesas_por_orientador': defesasPorOrientador,
      'total_aulas': gradeAulas.length,
      'resumo_geral': {
        'total_docentes': atividadesPorDocente.length,
        'total_atividades': atividades.length,
        'total_horas':
            totaisPorCategoria.values.fold(0.0, (sum, value) => sum + value),
        'total_defesas': defesas.length,
        'total_aulas': gradeAulas.length,
      },
    };
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportarDados() async {
    if (_dadosRelatorio == null) return;

    final semestre = _dadosRelatorio!['semestre'];
    final resumo = _dadosRelatorio!['resumo_geral'];

    final csvContent = StringBuffer();

    final inicio = semestre['data_inicio'] != null
        ? DateFormat('dd/MM/yyyy')
            .format(DateTime.parse(semestre['data_inicio']))
        : 'N/A';
    final fim = semestre['data_fim'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(semestre['data_fim']))
        : 'N/A';

    csvContent.writeln(
        'RELATÓRIO CONSOLIDADO - ${semestre['ano']}.${semestre['semestre']}');
    csvContent.writeln('Período: $inicio - $fim');
    csvContent.writeln();

    csvContent.writeln('RESUMO GERAL');
    csvContent.writeln('Docentes,${resumo['total_docentes']}');
    csvContent.writeln('Atividades,${resumo['total_atividades']}');
    csvContent.writeln('Horas,${resumo['total_horas'].toStringAsFixed(1)}');
    csvContent.writeln('Defesas,${resumo['total_defesas']}');
    csvContent.writeln('Aulas,${resumo['total_aulas']}');
    csvContent.writeln();

    csvContent.writeln('ATIVIDADES POR DOCENTE');
    csvContent
        .writeln('Docente,Total Horas,Ensino,Pesquisa,Extensão,Administrativa');
    for (final docente in _dadosRelatorio!['atividades_por_docente'].values) {
      csvContent.writeln(
          '${docente['nome']},${docente['total_geral'].toStringAsFixed(1)},${(docente['categorias']['Ensino'] ?? 0.0).toStringAsFixed(1)},${(docente['categorias']['Pesquisa'] ?? 0.0).toStringAsFixed(1)},${(docente['categorias']['Extensão'] ?? 0.0).toStringAsFixed(1)},${(docente['categorias']['Administrativa'] ?? 0.0).toStringAsFixed(1)}');
    }
    csvContent.writeln();

    csvContent.writeln('TOTAIS POR CATEGORIA');
    csvContent.writeln('Categoria,Total Horas');
    for (final entry in _dadosRelatorio!['totais_categoria'].entries) {
      csvContent.writeln('${entry.key},${entry.value.toStringAsFixed(1)}');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dados para Exportação'),
        content: SingleChildScrollView(
          child: Text(csvContent.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _mostrarSucesso('Dados prontos para exportação!');
            },
            child: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Relatório Consolidado',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 40,
        actions: [
          if (_dadosRelatorio != null)
            IconButton(
              icon: const Icon(Icons.file_download, size: 18),
              onPressed: _exportarDados,
              tooltip: 'Exportar Dados',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text(
                            'SEMESTRE:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667eea),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _semestreSelecionado,
                              isExpanded: true,
                              items: _semestres
                                  .map<DropdownMenuItem<String>>((semestre) {
                                return DropdownMenuItem<String>(
                                  value: semestre['id']?.toString(),
                                  child: Text(
                                    '${semestre['ano']}.${semestre['semestre']} ${semestre['data_inicio'] != null ? "- ${DateFormat('dd/MM/yyyy').format(DateTime.parse(semestre['data_inicio']))}" : ""}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _semestreSelecionado = value);
                                _carregarRelatorio();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 16),
                            onPressed: _carregarRelatorio,
                            tooltip: 'Atualizar',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_dadosRelatorio != null) ...[
                    Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RESUMO GERAL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF764ba2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildInfoCardWidget(
                                    'Docentes',
                                    _dadosRelatorio!['resumo_geral']
                                            ['total_docentes']
                                        .toString()),
                                _buildInfoCardWidget(
                                    'Atividades',
                                    _dadosRelatorio!['resumo_geral']
                                            ['total_atividades']
                                        .toString()),
                                _buildInfoCardWidget(
                                    'Horas',
                                    _dadosRelatorio!['resumo_geral']
                                            ['total_horas']
                                        .toStringAsFixed(1)),
                                _buildInfoCardWidget(
                                    'Defesas',
                                    _dadosRelatorio!['resumo_geral']
                                            ['total_defesas']
                                        .toString()),
                                _buildInfoCardWidget(
                                    'Aulas',
                                    _dadosRelatorio!['resumo_geral']
                                            ['total_aulas']
                                        .toString()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ATIVIDADES POR DOCENTE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF764ba2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 12,
                                headingRowHeight: 32,
                                dataRowHeight: 28,
                                columns: const [
                                  DataColumn(
                                      label: Text('Docente',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Total Horas',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Ensino',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Pesquisa',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Extensão',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Administrativa',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                ],
                                rows:
                                    (_dadosRelatorio!['atividades_por_docente']
                                            as Map)
                                        .values
                                        .map<DataRow>((docente) {
                                  return DataRow(cells: [
                                    DataCell(Text(docente['nome'] ?? '',
                                        style: const TextStyle(fontSize: 10))),
                                    DataCell(Text(
                                        (docente['total_geral'] as num? ?? 0.0)
                                            .toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 10))),
                                    DataCell(Text(
                                        (docente['categorias']?['Ensino']
                                                    as num? ??
                                                0.0)
                                            .toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 10))),
                                    DataCell(Text(
                                        (docente['categorias']?['Pesquisa']
                                                    as num? ??
                                                0.0)
                                            .toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 10))),
                                    DataCell(Text(
                                        (docente['categorias']?['Extensão']
                                                    as num? ??
                                                0.0)
                                            .toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 10))),
                                    DataCell(Text(
                                        (docente['categorias']
                                                        ?['Administrativa']
                                                    as num? ??
                                                0.0)
                                            .toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 10))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAIS POR CATEGORIA',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF764ba2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 12,
                                headingRowHeight: 32,
                                dataRowHeight: 28,
                                columns: const [
                                  DataColumn(
                                      label: Text('Categoria',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Total Horas',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                ],
                                rows: (_dadosRelatorio!['totais_categoria']
                                        as Map)
                                    .entries
                                    .map<DataRow>((entry) {
                                  return DataRow(cells: [
                                    DataCell(Text(entry.key.toString(),
                                        style: const TextStyle(fontSize: 10))),
                                    DataCell(Text(
                                        (entry.value as num? ?? 0.0)
                                            .toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 10))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_dadosRelatorio!['defesas_por_orientador'].isNotEmpty)
                      Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DEFESAS POR ORIENTADOR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF764ba2),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 12,
                                  headingRowHeight: 32,
                                  dataRowHeight: 28,
                                  columns: const [
                                    DataColumn(
                                        label: Text('Orientador',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Quantidade',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold))),
                                  ],
                                  rows: (_dadosRelatorio![
                                          'defesas_por_orientador'] as Map)
                                      .entries
                                      .map<DataRow>((entry) {
                                    return DataRow(cells: [
                                      DataCell(Text(entry.key.toString(),
                                          style:
                                              const TextStyle(fontSize: 10))),
                                      DataCell(Text(entry.value.toString(),
                                          style:
                                              const TextStyle(fontSize: 10))),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ] else if (_semestreSelecionado != null) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.analytics_outlined,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Nenhum dado encontrado para este semestre',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCardWidget(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 10, color: Color(0xFF667eea))),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea))),
        ],
      ),
    );
  }
}
