import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CertificadosBancasTccPage extends StatefulWidget {
  const CertificadosBancasTccPage({super.key});

  @override
  State<CertificadosBancasTccPage> createState() =>
      _CertificadosBancasTccPageState();
}

class _CertificadosBancasTccPageState extends State<CertificadosBancasTccPage> {
  final GlobalKey _certificadoKey = GlobalKey();
  final SupabaseClient _supabase = Supabase.instance.client;

  String? docenteSelecionado;
  String? semestreSelecionado;
  bool carregando = false;
  bool carregandoFiltros = true;

  List<String> docentes = [];
  List<String> semestres = [];

  List<Map<String, dynamic>> todasDefesas = [];
  List<Map<String, dynamic>> defesasSelecionadas = [];
  Map<String, bool> defesasCheckbox = {};

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  Future<void> _inicializarDados() async {
    setState(() => carregandoFiltros = true);
    await Future.wait([
      _carregarSemestres(),
      _carregarDocentes(),
    ]);
    setState(() => carregandoFiltros = false);
  }

  Future<void> _carregarSemestres() async {
    try {
      final response = await _supabase
          .from('dados_defesas')
          .select('semestre')
          .order('semestre', ascending: false);

      final semestresUnicos = response
          .map((item) => item['semestre']?.toString() ?? '')
          .where((semestre) => semestre.isNotEmpty)
          .toSet()
          .toList();

      semestresUnicos.sort((a, b) {
        try {
          final partsA = a.split('.');
          final partsB = b.split('.');
          if (partsA.length != 2 || partsB.length != 2) return b.compareTo(a);
          final anoA = int.parse(partsA[0]);
          final semA = int.parse(partsA[1]);
          final anoB = int.parse(partsB[0]);
          final semB = int.parse(partsB[1]);
          if (anoA != anoB) return anoB.compareTo(anoA);
          return semB.compareTo(semA);
        } catch (e) {
          return b.compareTo(a);
        }
      });

      setState(() {
        semestres = semestresUnicos;
        if (semestres.isNotEmpty) semestreSelecionado = semestres.first;
      });
    } catch (e) {
      debugPrint('Erro ao carregar semestres: $e');
    }
  }

  Future<void> _carregarDocentes() async {
    try {
      final response = await _supabase
          .from('dados_defesas')
          .select('avaliador1, avaliador2, avaliador3, orientador');

      final todosDocentes = <String>{};

      for (var item in response) {
        _adicionarSeValido(todosDocentes, item['avaliador1']);
        _adicionarSeValido(todosDocentes, item['avaliador2']);
        _adicionarSeValido(todosDocentes, item['avaliador3']);
        _adicionarSeValido(todosDocentes, item['orientador']);
      }

      setState(() {
        docentes = todosDocentes.toList()..sort();
      });
    } catch (e) {
      debugPrint('Erro ao carregar docentes: $e');
    }
  }

  void _adicionarSeValido(Set<String> set, dynamic valor) {
    if (valor != null && valor.toString().trim().isNotEmpty) {
      set.add(valor.toString().trim());
    }
  }

  Future<void> _carregarDefesas() async {
    if (docenteSelecionado == null || semestreSelecionado == null) return;

    setState(() => carregando = true);

    try {
      final response = await _supabase
          .from('dados_defesas')
          .select()
          .eq('semestre', semestreSelecionado!)
          .or('avaliador1.eq."$docenteSelecionado",avaliador2.eq."$docenteSelecionado",avaliador3.eq."$docenteSelecionado",orientador.eq."$docenteSelecionado"')
          .order('dia', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);
      final mapeadas = list.map((d) {
        String funcao = '';
        if (d['orientador'] == docenteSelecionado) {
          funcao = 'ORIENTADOR(A)';
        } else {
          funcao = 'EXAMINADOR(A)';
        }

        return {
          'id': d['id'],
          'aluno': d['discente'] ?? 'N/I',
          'tema': d['titulo'] ?? 'N/I',
          'data': d['dia'] ?? '',
          'funcao': funcao,
        };
      }).toList();

      setState(() {
        todasDefesas = mapeadas;
        defesasSelecionadas = [];
        defesasCheckbox = {for (var d in mapeadas) d['id'].toString(): false};
      });
    } catch (e) {
      debugPrint('Erro ao carregar defesas: $e');
    } finally {
      setState(() => carregando = false);
    }
  }

  void _toggleDefesa(Map<String, dynamic> defesa, bool? values) {
    setState(() {
      final id = defesa['id'].toString();
      defesasCheckbox[id] = values ?? false;
      if (defesasCheckbox[id]!) {
        defesasSelecionadas.add(defesa);
      } else {
        defesasSelecionadas.removeWhere((d) => d['id'] == defesa['id']);
      }
    });
  }

  void _selecionarTudo(bool value) {
    setState(() {
      defesasSelecionadas.clear();
      for (var d in todasDefesas) {
        defesasCheckbox[d['id'].toString()] = value;
        if (value) defesasSelecionadas.add(d);
      }
    });
  }

  Future<void> _exportarCertificado() async {
    if (defesasSelecionadas.isEmpty) {
      _notificar('Selecione ao menos uma defesa', Colors.orange);
      return;
    }

    try {
      RenderRepaintBoundary boundary = _certificadoKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      // Aumentamos o pixelRatio para 12.0 e capturamos em resolução nativa
      // para garantir nitidez absoluta mesmo em zooms extremos.
      ui.Image image = await boundary.toImage(pixelRatio: 12.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      String nomeLimpo = docenteSelecionado!
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .toLowerCase();
      String fileName = 'Certificado_Bancas_$nomeLimpo.png';

      await FileSaver.instance
          .saveFile(name: fileName, bytes: pngBytes, fileExtension: 'png');

      _notificar('Certificado exportado com sucesso!', Colors.green);
    } catch (e) {
      _notificar('Erro ao exportar: $e', Colors.red);
    }
  }

  void _notificar(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildFilterCard(),
                const SizedBox(height: 16),
                _buildDefesasSection(),
                if (defesasSelecionadas.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildPreviewHeader(),
                  _buildPreviewCertificado(),
                  const SizedBox(height: 40),
                ],
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: defesasSelecionadas.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _exportarCertificado,
              backgroundColor: const Color(0xFF0C4A6E),
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: const Text("BAIXAR CERTIFICADO",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0C4A6E),
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _backButton(),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("GESTÃO DE DEFESAS",
                        style: TextStyle(
                            color: Color(0xFF7DD3FC),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    Text("Certificados de Bancas",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _backButton() {
    return Material(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text("FILTROS DE GERAÇÃO",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            bool isWide = constraints.maxWidth > 600;
            return isWide
                ? Row(
                    children: [
                      Expanded(flex: 1, child: _buildSemestreDropdown()),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildDocenteSelector()),
                    ],
                  )
                : Column(
                    children: [
                      _buildSemestreDropdown(),
                      const SizedBox(height: 12),
                      _buildDocenteSelector(),
                    ],
                  );
          }),
        ],
      ),
    );
  }

  Widget _buildSemestreDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Semestre",
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8))),
        const SizedBox(height: 6),
        Container(
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
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: semestres.map((s) {
                return DropdownMenuItem(value: s, child: Text(s));
              }).toList(),
              onChanged: (v) {
                setState(() {
                  semestreSelecionado = v;
                  _carregarDefesas();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocenteSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Docente / Avaliador",
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8))),
        const SizedBox(height: 6),
        InkWell(
          onTap: _mostrarBuscaDocente,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    docenteSelecionado ?? "Selecionar docente...",
                    style: TextStyle(
                        color: docenteSelecionado == null
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search_rounded,
                    size: 20, color: Color(0xFF0284C7)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarBuscaDocente() {
    showDialog(
      context: context,
      builder: (context) {
        List<String> filtrados = List.from(docentes);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Buscar docente...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) {
                  setDialogState(() {
                    filtrados = docentes
                        .where((d) => d.toLowerCase().contains(v.toLowerCase()))
                        .toList();
                  });
                },
              ),
              content: SizedBox(
                width: 400,
                height: 400,
                child: ListView.builder(
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(filtrados[index],
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      onTap: () {
                        setState(() {
                          docenteSelecionado = filtrados[index];
                          _carregarDefesas();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDefesasSection() {
    if (carregando) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: Color(0xFF0C4A6E)),
      ));
    }

    if (todasDefesas.isEmpty) {
      if (docenteSelecionado == null) return const SizedBox();
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("Nenhuma banca encontrada para este filtro",
                style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${todasDefesas.length} BANCAS ENCONTRADAS",
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF64748B),
                    letterSpacing: 1)),
            TextButton(
              onPressed: () => _selecionarTudo(
                  defesasSelecionadas.length != todasDefesas.length),
              child: Text(
                  defesasSelecionadas.length == todasDefesas.length
                      ? "Desmarcar Todos"
                      : "Selecionar Todos",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...todasDefesas.map((d) => _buildDefesaCard(d)),
      ],
    );
  }

  Widget _buildDefesaCard(Map<String, dynamic> d) {
    bool selecionado = defesasCheckbox[d['id'].toString()] ?? false;
    DateTime? data = d['data'].isNotEmpty ? DateTime.tryParse(d['data']) : null;
    String dataStr =
        data != null ? DateFormat('dd/MM/yyyy').format(data) : 'N/I';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                selecionado ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
            width: selecionado ? 2 : 1),
      ),
      child: CheckboxListTile(
        value: selecionado,
        onChanged: (v) => _toggleDefesa(d, v),
        activeColor: const Color(0xFF0284C7),
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(d['aluno'],
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d['tema'],
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                _badge(
                    d['funcao'],
                    d['funcao'] == 'ORIENTADOR(A)'
                        ? Colors.orange
                        : Colors.blue),
                const SizedBox(width: 8),
                Text(dataStr,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 9,
              fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildPreviewHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF0284C7)),
          SizedBox(width: 8),
          Text("PRÉ-VISUALIZAÇÃO",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildPreviewCertificado() {
    // Escala para caber na tela
    double screenWidth = MediaQuery.of(context).size.width;
    // O certificado agora tem 15% do tamanho A4 Retrato (595 * 0.15 = 89.25)
    double baseWidth = 89.25;
    double scale = (screenWidth - 32) / baseWidth;
    if (scale > 1.0) scale = 1.0;

    return Center(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 89.25, // 15% de A4 Retrato (595 * 0.15)
          height: 100.0,
          child: FittedBox(
            fit: BoxFit.contain,
            child: RepaintBoundary(
              key: _certificadoKey,
              child: SizedBox(
                width: 595,
                height: 500,
                child: _CertificadoDesign(
                  docente: docenteSelecionado ?? "",
                  semestre: semestreSelecionado ?? "",
                  defesas: defesasSelecionadas,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CertificadoDesign extends StatelessWidget {
  final String docente;
  final String semestre;
  final List<Map<String, dynamic>> defesas;

  const _CertificadoDesign({
    required this.docente,
    required this.semestre,
    required this.defesas,
  });

  @override
  Widget build(BuildContext context) {
    String determineFuncao() {
      bool temOrientador = defesas.any((d) => d['funcao'] == 'ORIENTADOR(A)');
      bool temExaminador = defesas.any((d) => d['funcao'] == 'EXAMINADOR(A)');
      if (temOrientador && temExaminador)
        return "ORIENTADOR(A) E EXAMINADOR(A)";
      if (temOrientador) return "ORIENTADOR(A)";
      return "EXAMINADOR(A)";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF0C4A6E), width: 15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("UNIVERSIDADE FEDERAL DA PARAÍBA",
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  const Text("CENTRO DE CIÊNCIAS SOCIAIS APLICADAS",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Text("DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS - $semestre",
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 11)),
                ],
              ),
              const Icon(Icons.school_rounded,
                  size: 60, color: Color(0xFF0C4A6E)),
            ],
          ),
          const SizedBox(height: 15),
          const Text("CERTIFICADO",
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0C4A6E),
                  letterSpacing: 4)),
          const SizedBox(height: 15),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                  color: Colors.black, fontSize: 16, height: 1.5),
              children: [
                const TextSpan(text: " Certificamos que "),
                TextSpan(
                    text: docente.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: " participou, na condição de "),
                TextSpan(
                    text: determineFuncao(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                    text:
                        ", das Bancas de Defesa de Trabalho de Conclusão de Curso (TCC) ${() {
                  if (defesas.isEmpty) return "";
                  List<String> datasUnicas = defesas
                      .map((d) {
                        DateTime? dt = DateTime.tryParse(d['data'].toString());
                        return dt != null
                            ? DateFormat('dd/MM/yyyy').format(dt)
                            : '-';
                      })
                      .toSet()
                      .toList()
                    ..sort();

                  if (datasUnicas.length == 1) {
                    return "defendida no dia ${datasUnicas.first}";
                  } else {
                    String lista = datasUnicas
                        .sublist(0, datasUnicas.length - 1)
                        .join(", ");
                    return "defendidas nos dias $lista e ${datasUnicas.last}";
                  }
                }()}, conforme listagem abaixo:"),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Table Header
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: const Row(
              children: [
                Expanded(
                    flex: 30,
                    child: Text("ALUNO",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 10))),
                Expanded(
                    flex: 70,
                    child: Text("TÍTULO DO TRABALHO",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 10))),
              ],
            ),
          ),
          // Table Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: defesas.length,
            itemBuilder: (context, index) {
              final d = defesas[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                        flex: 30,
                        child: Text(d['aluno'],
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    Expanded(
                        flex: 70,
                        child: Text(d['tema'],
                            style: const TextStyle(fontSize: 9))),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Divider(thickness: 1, color: Color(0xFF0C4A6E)),
          const SizedBox(height: 5),
          Text(
            "João Pessoa, ${DateFormat("dd 'de' MMMM 'de' yyyy", "pt_BR").format(DateTime.now())}",
            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
