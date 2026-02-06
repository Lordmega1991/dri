// lib/situacao_defesas_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'pdf_generator.dart';

class SituacaoDefesasPage extends StatefulWidget {
  const SituacaoDefesasPage({super.key});

  @override
  State<SituacaoDefesasPage> createState() => _SituacaoDefesasPageState();
}

class _SituacaoDefesasPageState extends State<SituacaoDefesasPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> defesas = [];
  Map<int, List<Map<String, dynamic>>> notasPorDefesa = {};
  List<String> semestres = [];
  String? semestreSelecionado;
  bool loading = true;

  // Controles de ordenação
  String _colunaOrdenada = 'data';
  bool _ordenacaoAscendente = true;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  // Função para encontrar o semestre mais recente
  String? _encontrarSemestreMaisRecente(List<String> semestres) {
    if (semestres.isEmpty) return null;

    // Ordena os semestres do mais recente para o mais antigo
    semestres.sort((a, b) {
      try {
        final partsA = a.split('.');
        final partsB = b.split('.');

        if (partsA.length != 2 || partsB.length != 2) return 0;

        final anoA = int.tryParse(partsA[0]) ?? 0;
        final semestreA = int.tryParse(partsA[1]) ?? 0;
        final anoB = int.tryParse(partsB[0]) ?? 0;
        final semestreB = int.tryParse(partsB[1]) ?? 0;

        // Primeiro compara o ano (decrescente), depois o semestre (decrescente)
        if (anoA != anoB) {
          return anoB.compareTo(anoA);
        } else {
          return semestreB.compareTo(semestreA);
        }
      } catch (e) {
        return 0;
      }
    });

    return semestres.first;
  }

  Future<void> carregarDados() async {
    setState(() {
      loading = true;
    });

    try {
      final responseDefesas = await supabase
          .from('dados_defesas')
          .select()
          .order('dia', ascending: true);

      final responseNotas = await supabase
          .from('notas')
          .select('*')
          .order('defesa_id', ascending: true)
          .order('avaliador_numero', ascending: true);

      setState(() {
        defesas =
            List<Map<String, dynamic>>.from(responseDefesas as List<dynamic>);

        notasPorDefesa = {};
        final notas =
            List<Map<String, dynamic>>.from(responseNotas as List<dynamic>);

        for (var nota in notas) {
          final defesaId = nota['defesa_id'];
          if (!notasPorDefesa.containsKey(defesaId)) {
            notasPorDefesa[defesaId] = [];
          }
          notasPorDefesa[defesaId]!.add(nota);
        }

        final semestresUnicos = defesas
            .map((defesa) => defesa['semestre']?.toString() ?? '')
            .where((semestre) => semestre.isNotEmpty)
            .toSet()
            .toList();

        semestres = semestresUnicos;

        // SEMPRE seleciona o semestre mais recente automaticamente
        semestreSelecionado = _encontrarSemestreMaisRecente(semestres);

        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar dados: $e")),
        );
      }
    }
  }

  List<Map<String, dynamic>> get defesasFiltradas {
    if (semestreSelecionado == null) return defesas;
    return defesas
        .where((defesa) => defesa['semestre'] == semestreSelecionado)
        .toList();
  }

  // Função para ordenar as defesas
  List<Map<String, dynamic>> _ordenarDefesas(
      List<Map<String, dynamic>> defesas) {
    defesas.sort((a, b) {
      int comparacao;
      switch (_colunaOrdenada) {
        case 'data':
          final dataA =
              a['dia'] != null ? DateTime.parse(a['dia']) : DateTime(0);
          final dataB =
              b['dia'] != null ? DateTime.parse(b['dia']) : DateTime(0);
          comparacao = dataA.compareTo(dataB);
          break;
        case 'discente':
          comparacao = (a['discente'] ?? '').compareTo(b['discente'] ?? '');
          break;
        case 'orientador':
          comparacao = (a['orientador'] ?? '').compareTo(b['orientador'] ?? '');
          break;
        case 'documentos':
          final docA = _getCheckboxValue(a, 'doc_outros_devolvido') ? 1 : 0;
          final docB = _getCheckboxValue(b, 'doc_outros_devolvido') ? 1 : 0;
          comparacao = docA.compareTo(docB);
          break;
        case 'nota_orientador':
          final notaA = _getNotaOrientador(a['id']) ?? 0;
          final notaB = _getNotaOrientador(b['id']) ?? 0;
          comparacao = notaA.compareTo(notaB);
          break;
        case 'nota_avaliador1':
          final notaA = _getNotaAvaliador1(a['id']) ?? 0;
          final notaB = _getNotaAvaliador1(b['id']) ?? 0;
          comparacao = notaA.compareTo(notaB);
          break;
        case 'nota_avaliador2':
          final notaA = _getNotaAvaliador2(a['id']) ?? 0;
          final notaB = _getNotaAvaliador2(b['id']) ?? 0;
          comparacao = notaA.compareTo(notaB);
          break;
        case 'tcc_devolvido':
          final tccA = _getCheckboxValue(a, 'doc_tcc_devolvido') ? 1 : 0;
          final tccB = _getCheckboxValue(b, 'doc_tcc_devolvido') ? 1 : 0;
          comparacao = tccA.compareTo(tccB);
          break;
        case 'termo_devolvido':
          final termoA = _getCheckboxValue(a, 'doc_termo_devolvido') ? 1 : 0;
          final termoB = _getCheckboxValue(b, 'doc_termo_devolvido') ? 1 : 0;
          comparacao = termoA.compareTo(termoB);
          break;
        default:
          final dataA =
              a['dia'] != null ? DateTime.parse(a['dia']) : DateTime(0);
          final dataB =
              b['dia'] != null ? DateTime.parse(b['dia']) : DateTime(0);
          comparacao = dataA.compareTo(dataB);
      }
      return _ordenacaoAscendente ? comparacao : -comparacao;
    });
    return defesas;
  }

  void _ordenarPorColuna(String coluna) {
    setState(() {
      if (_colunaOrdenada == coluna) {
        _ordenacaoAscendente = !_ordenacaoAscendente;
      } else {
        _colunaOrdenada = coluna;
        _ordenacaoAscendente = true;
      }
    });
  }

  double _calcularNotaTotal(Map<String, dynamic> nota) {
    // Se o modo_nota_total estiver ativo, usa a nota_total diretamente
    if (nota['modo_nota_total'] == true && nota['nota_total'] != null) {
      return (nota['nota_total'] as num).toDouble();
    }

    // Caso contrário, calcula a soma dos campos individuais
    double total = 0;
    final camposNota = [
      'introducao',
      'problematizacao',
      'referencial',
      'desenvolvimento',
      'conclusoes',
      'forma',
      'estruturacao',
      'clareza',
      'dominio'
    ];

    for (var campo in camposNota) {
      if (nota[campo] != null) {
        total += (nota[campo] as num).toDouble();
      }
    }

    return total;
  }

  double? _getNotaOrientador(int defesaId) {
    final notas = notasPorDefesa[defesaId];
    if (notas == null) return null;

    final notaOrientador = notas.firstWhere(
      (nota) => nota['avaliador_numero'] == 1,
      orElse: () => {},
    );

    if (notaOrientador.isEmpty) return null;
    return _calcularNotaTotal(notaOrientador);
  }

  double? _getNotaAvaliador1(int defesaId) {
    final notas = notasPorDefesa[defesaId];
    if (notas == null) return null;

    final notaAval1 = notas.firstWhere(
      (nota) => nota['avaliador_numero'] == 2,
      orElse: () => {},
    );

    if (notaAval1.isEmpty) return null;
    return _calcularNotaTotal(notaAval1);
  }

  double? _getNotaAvaliador2(int defesaId) {
    final notas = notasPorDefesa[defesaId];
    if (notas == null) return null;

    final notaAval2 = notas.firstWhere(
      (nota) => nota['avaliador_numero'] == 3,
      orElse: () => {},
    );

    if (notaAval2.isEmpty) return null;
    return _calcularNotaTotal(notaAval2);
  }

  bool _getCheckboxValue(Map<String, dynamic> defesa, String campo) {
    try {
      return defesa[campo] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _alternarDocumentoDevolvido(int defesaId, String campo) async {
    try {
      final defesaIndex =
          defesas.indexWhere((defesa) => defesa['id'] == defesaId);
      if (defesaIndex == -1) return;

      final novoValor = !_getCheckboxValue(defesas[defesaIndex], campo);

      await supabase
          .from('dados_defesas')
          .update({campo: novoValor}).eq('id', defesaId);

      setState(() {
        defesas[defesaIndex][campo] = novoValor;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_getNomeCampo(campo)} atualizado para ${novoValor ? 'Sim' : 'Não'}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getNomeCampo(String campo) {
    switch (campo) {
      case 'doc_tcc_devolvido':
        return 'TCC';
      case 'doc_termo_devolvido':
        return 'TERMO';
      case 'doc_outros_devolvido':
        return 'Documentos devolvidos';
      default:
        return 'Documento';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Moderno em Slate Blue
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF0C4A6E),
                borderRadius:
                    BorderRadius.only(bottomLeft: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SECRETARIA VIRTUAL",
                              style: TextStyle(
                                  color: Color(0xFF7DD3FC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5)),
                          Text("Situação das Defesas",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            PdfGenerator.generateSituacaoDefesasReport(
                                defesasFiltradas,
                                notasPorDefesa,
                                semestreSelecionado),
                        icon: const Icon(Icons.picture_as_pdf_rounded,
                            color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: carregarDados,
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Filtros Integrados
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded,
                        color: Color(0xFF0284C7), size: 20),
                    const SizedBox(width: 12),
                    const Text("Semestre:",
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF64748B))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: semestreSelecionado,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos os semestres',
                                    style: TextStyle(fontSize: 14)),
                              ),
                              ...semestres.map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        style: const TextStyle(fontSize: 14)),
                                  )),
                            ],
                            onChanged: (val) =>
                                setState(() => semestreSelecionado = val),
                          ),
                        ),
                      ),
                    ),
                    if (semestreSelecionado != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () =>
                            setState(() => semestreSelecionado = null),
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Tabela ou Feedback de Erro/Vazio
          if (loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0284C7))),
            )
          else if (defesasFiltradas.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("Nenhuma defesa encontrada",
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            _buildRowsSliver(),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildRowsSliver() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      final defesasOrdenadas = _ordenarDefesas(List.from(defesasFiltradas));
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildMobileDefesaCard(defesasOrdenadas[index]),
            childCount: defesasOrdenadas.length,
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: _buildTabelaExcel(),
        ),
      ),
    );
  }

  Widget _buildMobileDefesaCard(Map<String, dynamic> defesa) {
    final notaOrient = _getNotaOrientador(defesa['id']);
    final notaAval1 = _getNotaAvaliador1(defesa['id']);
    final notaAval2 = _getNotaAvaliador2(defesa['id']);

    List<double> notasValidas = [];
    if (notaOrient != null) notasValidas.add(notaOrient);
    if (notaAval1 != null) notasValidas.add(notaAval1);
    if (notaAval2 != null) notasValidas.add(notaAval2);
    double? mediaGeral = notasValidas.isNotEmpty
        ? notasValidas.reduce((a, b) => a + b) / notasValidas.length
        : null;

    final diaFormatado = defesa['dia'] != null
        ? DateFormat('dd/MM/yy').format(DateTime.parse(defesa['dia']))
        : '--/--/--';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(diaFormatado,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B))),
              _buildNotaBadge(mediaGeral, isMedia: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(defesa['discente']?.toString().toUpperCase() ?? '',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0C4A6E),
                  letterSpacing: -0.3)),
          Text(defesa['orientador'] ?? '',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniNota(notaOrient, "Orient."),
              _buildMiniNota(notaAval1, "Aval. 1"),
              _buildMiniNota(notaAval2, "Aval. 2"),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToggleItem("DOCS OK", 'doc_outros_devolvido', defesa),
              _buildToggleItem("TCC DEV.", 'doc_tcc_devolvido', defesa),
              _buildToggleItem("TERM. DEV.", 'doc_termo_devolvido', defesa),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniNota(double? nota, String label) {
    return Column(
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Text(nota?.toStringAsFixed(1) ?? '-',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: nota != null
                    ? const Color(0xFF0369A1)
                    : const Color(0xFFCBD5E1))),
      ],
    );
  }

  Widget _buildToggleItem(
      String label, String campo, Map<String, dynamic> defesa) {
    final valor = _getCheckboxValue(defesa, campo);
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Color(0xFF94A3B8))),
        const SizedBox(height: 6),
        _buildStatusToggle(defesa['id'], campo, valor),
      ],
    );
  }

  Widget _buildTabelaExcel() {
    final defesasOrdenadas = _ordenarDefesas(List.from(defesasFiltradas));

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: const Color(0xFFF1F5F9)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 52,
          dataRowMaxHeight: 52,
          dataRowMinHeight: 48,
          columnSpacing: 40,
          horizontalMargin: 24,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: [
            DataColumn(
                label: _buildHeaderCell('DATA', 'data'),
                onSort: (_, __) => _ordenarPorColuna('data')),
            DataColumn(
                label: _buildHeaderCell('NOME DO DISCENTE', 'discente'),
                onSort: (_, __) => _ordenarPorColuna('discente')),
            DataColumn(
                label: _buildHeaderCell('ORIENTADOR', 'orientador'),
                onSort: (_, __) => _ordenarPorColuna('orientador')),
            DataColumn(
                label: _buildHeaderCell('DOCS\nOK', 'documentos'),
                onSort: (_, __) => _ordenarPorColuna('documentos')),
            DataColumn(
                label: _buildHeaderCell('NOTAS\nORIENT.', 'nota_orientador')),
            DataColumn(
                label: _buildHeaderCell('NOTAS\nAV1', 'nota_avaliador1')),
            DataColumn(
                label: _buildHeaderCell('NOTAS\nAV2', 'nota_avaliador2')),
            DataColumn(label: _buildHeaderCell('MÉDIA\nGERAL', 'media_geral')),
            DataColumn(
                label: _buildHeaderCell('TCC\nDEV.', 'tcc_devolvido'),
                onSort: (_, __) => _ordenarPorColuna('tcc_devolvido')),
            DataColumn(
                label: _buildHeaderCell('TERMO\nDEV.', 'termo_devolvido'),
                onSort: (_, __) => _ordenarPorColuna('termo_devolvido')),
          ],
          rows: defesasOrdenadas.asMap().entries.map<DataRow>((entry) {
            final index = entry.key;
            final defesa = entry.value;
            final isEven = index % 2 == 0;

            final diaFormatado = defesa['dia'] != null
                ? DateFormat('dd/MM/yyyy').format(DateTime.parse(defesa['dia']))
                : '--/--/----';

            final notaOrient = _getNotaOrientador(defesa['id']);
            final notaAval1 = _getNotaAvaliador1(defesa['id']);
            final notaAval2 = _getNotaAvaliador2(defesa['id']);

            // Cálculo da média geral
            List<double> notasValidas = [];
            if (notaOrient != null) notasValidas.add(notaOrient);
            if (notaAval1 != null) notasValidas.add(notaAval1);
            if (notaAval2 != null) notasValidas.add(notaAval2);
            double? mediaGeral = notasValidas.isNotEmpty
                ? notasValidas.reduce((a, b) => a + b) / notasValidas.length
                : null;

            final documentosDevolvidos =
                _getCheckboxValue(defesa, 'doc_outros_devolvido');
            final tccDevolvido = _getCheckboxValue(defesa, 'doc_tcc_devolvido');
            final termoDevolvido =
                _getCheckboxValue(defesa, 'doc_termo_devolvido');

            return DataRow(
              color: WidgetStateProperty.all(isEven
                  ? Colors.white
                  : const Color(0xFFF1F5F9).withOpacity(0.5)),
              cells: [
                DataCell(Text(diaFormatado,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600))),
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Text(
                      defesa['discente']?.toString().toUpperCase() ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0C4A6E)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      defesa['orientador'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_buildStatusToggle(defesa['id'],
                    'doc_outros_devolvido', documentosDevolvidos)),
                DataCell(_buildNotaBadge(notaOrient)),
                DataCell(_buildNotaBadge(notaAval1)),
                DataCell(_buildNotaBadge(notaAval2)),
                DataCell(_buildNotaBadge(mediaGeral, isMedia: true)),
                DataCell(_buildStatusToggle(
                    defesa['id'], 'doc_tcc_devolvido', tccDevolvido)),
                DataCell(_buildStatusToggle(
                    defesa['id'], 'doc_termo_devolvido', termoDevolvido)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, String coluna) {
    bool isSorted = _colunaOrdenada == coluna;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: isSorted ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (isSorted) ...[
          const SizedBox(width: 4),
          Icon(
              _ordenacaoAscendente
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 12,
              color: const Color(0xFF0284C7)),
        ]
      ],
    );
  }

  Widget _buildNotaBadge(double? nota, {bool isMedia = false}) {
    if (nota == null)
      return const Center(
          child: Text('-', style: TextStyle(color: Color(0xFFCBD5E1))));

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isMedia ? const Color(0xFFF0FDFA) : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  isMedia ? const Color(0xFF5EEAD4) : const Color(0xFFBAE6FD),
              width: isMedia ? 1.5 : 1),
        ),
        child: Text(
          nota.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isMedia ? const Color(0xFF0F766E) : const Color(0xFF0369A1),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusToggle(int id, String campo, bool valor) {
    return Center(
      child: InkWell(
        onTap: () => _alternarDocumentoDevolvido(id, campo),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: valor ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: valor ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
              width: 1,
            ),
          ),
          child: Text(
            valor ? 'SIM' : 'NÃO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: valor ? const Color(0xFF166534) : const Color(0xFF991B1B),
            ),
          ),
        ),
      ),
    );
  }
}
