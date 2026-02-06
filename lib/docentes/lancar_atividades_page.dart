import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LancarAtividadesPage extends StatefulWidget {
  const LancarAtividadesPage({super.key});

  @override
  State<LancarAtividadesPage> createState() => _LancarAtividadesPageState();
}

class _LancarAtividadesPageState extends State<LancarAtividadesPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _observacoesController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _searchController = TextEditingController();

  // Estado
  bool _loading = false;
  bool _formLoading = false;
  bool _pdfLoading = false;
  bool _editando = false;
  String _atividadeEditId = '';

  // Listas para dropdowns
  List<Map<String, dynamic>> _docentes = [];
  List<Map<String, dynamic>> _semestres = [];
  List<Map<String, dynamic>> _tiposAtividade = [];
  List<Map<String, dynamic>> _atividades = [];
  List<Map<String, dynamic>> _atividadesFiltradas = [];

  // Valores selecionados
  String? _docenteSelecionado;
  String? _semestreSelecionado;
  String? _tipoAtividadeSelecionado;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String? _filtroSemestre;

  // Variáveis para ordenação
  String _colunaOrdenacao = 'docente';
  bool _ordenacaoAscendente = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _searchController.addListener(_filtrarAtividades);
    _quantidadeController.text = '0'; // Valor padrão inicial
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    _quantidadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _loading = true);

    try {
      final docentesResponse =
          await supabase.from('docentes').select('*').order('nome');
      final semestresResponse = await supabase
          .from('semestres')
          .select('*')
          .order('ano', ascending: false)
          .order('semestre', ascending: false);
      final tiposResponse =
          await supabase.from('tipos_atividade').select('*').order('nome');
      final atividadesResponse =
          await supabase.from('atividades_docentes').select('''
        *,
        docentes(nome, email),
        semestres(ano, semestre),
        tipos_atividade(nome, categoria, unidade_medida)
      ''').order('created_at', ascending: false);

      setState(() {
        _docentes = (docentesResponse as List).cast<Map<String, dynamic>>();
        _semestres = (semestresResponse as List).cast<Map<String, dynamic>>();
        _tiposAtividade = (tiposResponse as List).cast<Map<String, dynamic>>();
        _atividades = (atividadesResponse as List).cast<Map<String, dynamic>>();
        _atividadesFiltradas = List.from(_atividades);

        if (_semestreSelecionado == null && _semestres.isNotEmpty) {
          _semestreSelecionado = _semestres.first['id']?.toString();
        }
        _ordenarAtividades(); // Inicia ordenado por Docente A-Z
      });
    } catch (e) {
      _mostrarMensagem('Erro ao carregar dados: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filtrarAtividades() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _atividadesFiltradas = _atividades.where((atividade) {
        final docente =
            atividade['docentes']?['nome']?.toString().toLowerCase() ?? '';
        final tipo =
            atividade['tipos_atividade']?['nome']?.toString().toLowerCase() ??
                '';
        final idSemestre = atividade['semestre_id']?.toString() ?? '';

        final matchesSearch =
            query.isEmpty || docente.contains(query) || tipo.contains(query);
        final matchesSemestre =
            _filtroSemestre == null || idSemestre == _filtroSemestre;

        return matchesSearch && matchesSemestre;
      }).toList();
      _ordenarAtividades();
    });
  }

  void _ordenarAtividades() {
    if (_atividadesFiltradas.isEmpty) return;

    setState(() {
      _atividadesFiltradas.sort((a, b) {
        dynamic valorA;
        dynamic valorB;

        switch (_colunaOrdenacao) {
          case 'docente':
            valorA = _removerTitulosParaOrdenacao(
                a['docentes']?['nome']?.toString() ?? '');
            valorB = _removerTitulosParaOrdenacao(
                b['docentes']?['nome']?.toString() ?? '');
            break;
          case 'atividade':
            valorA =
                (a['tipos_atividade']?['nome']?.toString() ?? '').toUpperCase();
            valorB =
                (b['tipos_atividade']?['nome']?.toString() ?? '').toUpperCase();
            break;
          case 'semestre':
            final semA = a['semestres'];
            final semB = b['semestres'];
            valorA = (semA?['ano'] ?? 0) * 10 + (semA?['semestre'] ?? 0);
            valorB = (semB?['ano'] ?? 0) * 10 + (semB?['semestre'] ?? 0);
            break;
          case 'quantidade':
            valorA = a['quantidade'] ?? 0.0;
            valorB = b['quantidade'] ?? 0.0;
            break;
          case 'inicio':
            valorA = a['data_inicio'] ?? '';
            valorB = b['data_inicio'] ?? '';
            break;
          case 'fim':
            valorA = a['data_fim'] ?? '';
            valorB = b['data_fim'] ?? '';
            break;
          default:
            valorA = '';
            valorB = '';
        }

        final resultado = valorA.compareTo(valorB);
        return _ordenacaoAscendente ? resultado : -resultado;
      });
    });
  }

  void _mudarOrdenacao(String coluna) {
    setState(() {
      if (_colunaOrdenacao == coluna) {
        _ordenacaoAscendente = !_ordenacaoAscendente;
      } else {
        _colunaOrdenacao = coluna;
        _ordenacaoAscendente = true;
      }
      _ordenarAtividades();
    });
  }

  // FUNÇÃO PARA REMOVER TÍTULOS (ORDENAÇÃO LIMPA)
  String _removerTitulosParaOrdenacao(String nome) {
    if (nome.isEmpty) return '';
    return nome
        .toUpperCase()
        .replaceAll(
            RegExp(r'\b(PROF(A)?|DR(A)?|ME|MA|PHD|MS|MSC)\.?\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _getPermitePeriodo() {
    if (_tipoAtividadeSelecionado == null) return false;
    final tipo = _tiposAtividade.firstWhere(
      (t) => t['id'] == _tipoAtividadeSelecionado,
      orElse: () => {'permite_periodo': false},
    );
    return tipo['permite_periodo'] ?? false;
  }

  Future<void> _salvarAtividade() async {
    if (!_formKey.currentState!.validate()) return;
    if (_docenteSelecionado == null ||
        _semestreSelecionado == null ||
        _tipoAtividadeSelecionado == null) {
      _mostrarMensagem('Selecione docente, semestre e tipo de atividade!',
          isErro: true);
      return;
    }

    final quantidadeText = _quantidadeController.text.trim();
    final quantidade = double.tryParse(quantidadeText);
    if (quantidade == null || quantidade < 0) {
      _mostrarMensagem('Quantidade/CH deve ser um número válido (0 ou mais)!',
          isErro: true);
      return;
    }

    setState(() => _formLoading = true);

    try {
      final tipoAtividade = _tiposAtividade
          .firstWhere((t) => t['id'] == _tipoAtividadeSelecionado);
      final permitePeriodo = tipoAtividade['permite_periodo'] ?? false;

      final dados = {
        'docente_id': _docenteSelecionado,
        'semestre_id': _semestreSelecionado,
        'tipo_atividade_id': _tipoAtividadeSelecionado,
        'descricao': tipoAtividade['nome'],
        'quantidade': quantidade,
        'data_inicio': _dataInicio?.toIso8601String().split('T').first,
        'data_fim': permitePeriodo
            ? _dataFim?.toIso8601String().split('T').first
            : null,
        'eh_por_periodo': permitePeriodo,
        'status': 'aprovado',
        'observacoes': _observacoesController.text.trim().isEmpty
            ? null
            : _observacoesController.text.trim(),
        'detalhes': {
          'unidade_medida': tipoAtividade['unidade_medida'],
          'categoria': tipoAtividade['categoria'],
        },
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_editando) {
        await supabase
            .from('atividades_docentes')
            .update(dados)
            .eq('id', _atividadeEditId);
        _mostrarMensagem('Atividade atualizada com sucesso!');
      } else {
        await supabase.from('atividades_docentes').insert(dados);
        _mostrarMensagem('Atividade lançada com sucesso!');
      }

      _limparFormulario();
      _carregarDados();
    } catch (e) {
      _mostrarMensagem('Erro ao salvar atividade: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _formLoading = false);
    }
  }

  void _editarAtividade(Map<String, dynamic> atividade) {
    setState(() {
      _editando = true;
      _atividadeEditId = atividade['id'];
      _docenteSelecionado = atividade['docente_id']?.toString();
      _semestreSelecionado = atividade['semestre_id']?.toString();
      _tipoAtividadeSelecionado = atividade['tipo_atividade_id']?.toString();
      _observacoesController.text = atividade['observacoes'] ?? '';
      _quantidadeController.text = atividade['quantidade'].toString();

      if (atividade['data_inicio'] != null) {
        _dataInicio = DateTime.parse(atividade['data_inicio']);
      }
      if (atividade['data_fim'] != null) {
        _dataFim = DateTime.parse(atividade['data_fim']);
      }
    });
  }

  void _clonarAtividade(Map<String, dynamic> atividade) {
    setState(() {
      _editando = false; // Novo registro baseado em um antigo
      _atividadeEditId = '';
      _docenteSelecionado = atividade['docente_id']?.toString();
      _semestreSelecionado = atividade['semestre_id']?.toString();
      _tipoAtividadeSelecionado = atividade['tipo_atividade_id']?.toString();
      _observacoesController.text = atividade['observacoes'] ?? '';
      _quantidadeController.text = atividade['quantidade'].toString();

      if (atividade['data_inicio'] != null) {
        _dataInicio = DateTime.parse(atividade['data_inicio']);
      }
      if (atividade['data_fim'] != null) {
        _dataFim = DateTime.parse(atividade['data_fim']);
      }
    });
    _mostrarMensagem('Informações clonadas! Ajuste o semestre e salve.');
  }

  Future<void> _excluirAtividade(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Tem certeza que deseja excluir esta atividade permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await supabase.from('atividades_docentes').delete().eq('id', id);
        _mostrarMensagem('Atividade excluída!');
        _carregarDados();
      } catch (e) {
        _mostrarMensagem('Erro ao excluir: $e', isErro: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _observacoesController.clear();
    _quantidadeController.text = '1';
    setState(() {
      _editando = false;
      _atividadeEditId = '';
      _docenteSelecionado = null;
      _tipoAtividadeSelecionado = null;
      _dataInicio = null;
      _dataFim = null;
    });
  }

  void _mostrarMensagem(String msg, {bool isErro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isErro ? Colors.red[700] : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatarData(String? dataString) {
    if (dataString == null) return '-';
    try {
      final data = DateTime.parse(dataString);
      return DateFormat('dd/MM/yyyy').format(data);
    } catch (e) {
      return '-';
    }
  }

  Future<void> _gerarRelatorioPDF() async {
    if (_atividadesFiltradas.isEmpty) {
      _mostrarMensagem('Não há dados para exportar!', isErro: true);
      return;
    }

    setState(() => _pdfLoading = true);

    try {
      final pdf = pw.Document();
      final now = DateTime.now();

      // Carregar Logo UFPB
      final logoData = await rootBundle.load('assets/ufpb.png');
      final logo = pw.MemoryImage(logoData.buffer.asUint8List());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          header: (pw.Context context) => pw.Column(
            children: [
              pw.Row(
                children: [
                  pw.Image(logo, height: 35),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          'UFPB - CCSA - DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Relatório de Lançamento de Atividades',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.purple700)),
                      pw.Text(
                          '${_filtroSemestre != null ? 'Filtro Semestre: $_filtroSemestre' : 'Todos os Semestres'}',
                          style: pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                          'Página ${context.pageNumber} de ${context.pagesCount}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5, color: PdfColors.purple),
              pw.SizedBox(height: 12),
            ],
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.purple700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration:
                  const pw.BoxDecoration(color: PdfColors.purple50),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3), // DOCENTE
                1: const pw.FlexColumnWidth(3.5), // ATIVIDADE
                2: const pw.FlexColumnWidth(1), // SEMESTRE
                3: const pw.FlexColumnWidth(1), // CH
                4: const pw.FlexColumnWidth(1.5), // INÍCIO
                5: const pw.FlexColumnWidth(1.5), // FIM
                6: const pw.FlexColumnWidth(4), // OBS
              },
              headers: [
                'DOCENTE',
                'ATIVIDADE',
                'SEM.',
                'CH',
                'INÍCIO',
                'FIM',
                'OBS'
              ],
              data: _atividadesFiltradas.map((a) {
                return [
                  (a['docentes'] is Map ? a['docentes']['nome'] : null) ?? '-',
                  (a['tipos_atividade'] is Map
                          ? a['tipos_atividade']['nome']
                          : null) ??
                      '-',
                  _formatarSemestre(
                      a['semestres'] is Map ? a['semestres'] : null),
                  (a['quantidade']?.toString() ?? '-'),
                  _formatarData(a['data_inicio']?.toString()),
                  _formatarData(a['data_fim']?.toString()),
                  (a['observacoes']?.toString() ?? '-'),
                ];
              }).toList(),
            ),
          ],
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('DRI - Sistema de Gestão Acadêmica',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Relatorio_Atividades_${DateFormat('yyyyMMdd').format(now)}.pdf',
      );

      _mostrarMensagem('Relatório gerado com sucesso!');
    } catch (e) {
      debugPrint('Erro PDF: $e');
      _mostrarMensagem('Erro ao gerar PDF: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  String _formatarSemestre(Map<String, dynamic>? semestre) {
    if (semestre == null) return '-';
    return '${semestre['ano']}.${semestre['semestre']}';
  }

  int? _getSortColumnIndex() {
    switch (_colunaOrdenacao) {
      case 'docente':
        return 0;
      case 'atividade':
        return 1;
      case 'semestre':
        return 2;
      case 'quantidade':
        return 3;
      case 'inicio':
        return 4;
      case 'fim':
        return 5;
      default:
        return null; // Or -1 if no column is sorted
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildFormSliver(),
          _buildTabelaHeaderSliver(),
          if (_loading && _atividades.isEmpty)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (_atividadesFiltradas.isEmpty)
            const SliverFillRemaining(
                child: Center(child: Text("Nenhuma atividade encontrada.")))
          else
            _buildTabelaRowsSliver(),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 32, 16, isMobile ? 12 : 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ADMINISTRAÇÃO",
                          style: TextStyle(
                              color: const Color(0xFF38BDF8),
                              fontSize: isMobile ? 7 : 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2)),
                      Text("Lançar Atividades",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _carregarDados,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSliver() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        _editando
                            ? Icons.edit_note_rounded
                            : Icons.add_task_rounded,
                        color: const Color(0xFF0284C7),
                        size: 18),
                    const SizedBox(width: 8),
                    Text(_editando ? "EDITAR ATIVIDADE" : "LANÇAR ATIVIDADE",
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Color(0xFF0F172A))),
                    const Spacer(),
                    if (_editando)
                      TextButton.icon(
                        onPressed: _limparFormulario,
                        icon: const Icon(Icons.close_rounded, size: 12),
                        label: const Text("CANCELAR",
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero),
                      )
                  ],
                ),
                const SizedBox(height: 16),
                if (!isMobile) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildDocenteDropdown(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSemestreDropdown(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildTipoDropdown(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _quantidadeController,
                          label: "Quantidade / CH",
                          hint: "Ex: 40",
                          icon: Icons.numbers_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePickerField(isInicio: true),
                      ),
                      if (_getPermitePeriodo()) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDatePickerField(isInicio: false),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _observacoesController,
                          label: "Observações",
                          hint: "Detalhes",
                          icon: Icons.notes_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildSubmitButton(),
                    ],
                  ),
                ] else ...[
                  _buildDocenteDropdown(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSemestreDropdown()),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildTextField(
                        controller: _quantidadeController,
                        label: "Qtd/CH",
                        hint: "CH",
                        icon: Icons.numbers_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTipoDropdown(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDatePickerField(isInicio: true)),
                      if (_getPermitePeriodo()) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _buildDatePickerField(isInicio: false)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _observacoesController,
                    label: "Observações",
                    hint: "Detalhes",
                    icon: Icons.notes_rounded,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: _buildSubmitButton()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocenteDropdown() {
    return _buildDropdown(
      label: "Docente",
      value: _docenteSelecionado,
      items: _docentes
          .map((d) => DropdownMenuItem(
              value: d['id'].toString(), child: Text(d['nome'] ?? '')))
          .toList(),
      onChanged: (val) => setState(() => _docenteSelecionado = val as String?),
      icon: Icons.person_rounded,
    );
  }

  Widget _buildSemestreDropdown() {
    return _buildDropdown(
      label: "Semestre",
      value: _semestreSelecionado,
      items: _semestres
          .map((s) => DropdownMenuItem(
              value: s['id'].toString(),
              child: Text('${s['ano']}.${s['semestre']}')))
          .toList(),
      onChanged: (val) => setState(() => _semestreSelecionado = val as String?),
      icon: Icons.calendar_month_rounded,
    );
  }

  Widget _buildTipoDropdown() {
    return _buildDropdown(
      label: "Tipo de Atividade",
      value: _tipoAtividadeSelecionado,
      items: _tiposAtividade
          .map((t) => DropdownMenuItem(
              value: t['id'].toString(), child: Text(t['nome'] ?? '')))
          .toList(),
      onChanged: (val) {
        setState(() {
          _tipoAtividadeSelecionado = val as String?;
          if (!_getPermitePeriodo()) _dataFim = null;
        });
      },
      icon: Icons.category_rounded,
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem<String>> items,
    required Function(dynamic) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.normal,
                fontSize: 10),
            prefixIcon: icon != null
                ? Icon(icon, size: 14, color: const Color(0xFF94A3B8))
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({required bool isInicio}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isInicio ? "Data Início" : "Data Fim",
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final data = await showDatePicker(
              context: context,
              initialDate:
                  (isInicio ? _dataInicio : _dataFim) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (data != null) {
              setState(() {
                if (isInicio)
                  _dataInicio = data;
                else
                  _dataFim = data;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14,
                    color: (isInicio ? _dataInicio : _dataFim) != null
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (isInicio ? _dataInicio : _dataFim) != null
                        ? DateFormat('dd/MM/yyyy')
                            .format((isInicio ? _dataInicio! : _dataFim!))
                        : "Selecionar",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: (isInicio ? _dataInicio : _dataFim) != null
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 34,
        width: 100,
        child: ElevatedButton(
          onPressed: _formLoading ? null : _salvarAtividade,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _formLoading
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 1.5))
              : Text(_editando ? "SALVAR" : "LANÇAR",
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _buildTabelaHeaderSliver() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("ATIVIDADES LANÇADAS",
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.4)),
                      const SizedBox(width: 6),
                      _buildCountBadge(_atividadesFiltradas.length.toString(),
                          const Color(0xFF0284C7)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildSearchField(),
                ],
              )
            : Row(
                children: [
                  const Text("ATIVIDADES LANÇADAS",
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.4)),
                  const SizedBox(width: 8),
                  _buildCountBadge(_atividadesFiltradas.length.toString(),
                      const Color(0xFF0284C7)),
                  const Spacer(),
                  Container(
                    width: 100,
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filtroSemestre,
                        hint: const Text("Semestre",
                            style: TextStyle(fontSize: 9)),
                        isExpanded: true,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A)),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text("TODOS")),
                          ..._semestres.map((s) => DropdownMenuItem(
                                value: s['id'].toString(),
                                child: Text('${s['ano']}.${s['semestre']}'),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _filtroSemestre = val);
                          _filtrarAtividades();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _pdfLoading ? null : _gerarRelatorioPDF,
                    icon: _pdfLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.picture_as_pdf_rounded,
                            color: Colors.red, size: 24),
                    tooltip: 'Exportar para PDF',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(width: 180, child: _buildSearchField()),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 28,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 10),
        decoration: InputDecoration(
          hintText: "Pesquisar...",
          hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 14, color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildCountBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildSortableHeader(String label, String coluna) {
    final selecionada = _colunaOrdenacao == coluna;
    return InkWell(
      onTap: () => _mudarOrdenacao(coluna),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: selecionada
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 4),
          if (selecionada)
            Icon(
              _ordenacaoAscendente
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 10,
              color: const Color(0xFF0284C7),
            )
          else
            const Icon(Icons.sort_rounded, size: 10, color: Color(0xFFE2E8F0)),
        ],
      ),
    );
  }

  Widget _buildTabelaRowsSliver() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildAtividadeCard(_atividadesFiltradas[index]),
            childCount: _atividadesFiltradas.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowMaxHeight: 60,
              columnSpacing: 60,
              horizontalMargin: 24,
              sortColumnIndex: _getSortColumnIndex(),
              sortAscending: _ordenacaoAscendente,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: [
                DataColumn(label: _buildSortableHeader('DOCENTE', 'docente')),
                DataColumn(
                    label: _buildSortableHeader('ATIVIDADE', 'atividade')),
                DataColumn(label: _buildSortableHeader('SEM.', 'semestre')),
                DataColumn(label: _buildSortableHeader('CH', 'quantidade')),
                DataColumn(label: _buildSortableHeader('INÍCIO', 'inicio')),
                DataColumn(label: _buildSortableHeader('FIM', 'fim')),
                const DataColumn(
                    label: Text('OBS',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF94A3B8)))),
                const DataColumn(
                    label: Text('AÇÕES',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF94A3B8)))),
              ],
              rows: (_atividadesFiltradas.asMap().entries.map<DataRow>((entry) {
                final idx = entry.key;
                final a = entry.value;
                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    return idx % 2 != 0
                        ? const Color(0xFFF8FAFC)
                        : Colors.white;
                  }),
                  cells: [
                    DataCell(Text(a['docentes']?['nome'] ?? '-',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0C4A6E)))),
                    DataCell(Text(a['tipos_atividade']?['nome'] ?? '-',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF475569)))),
                    DataCell(Text(_formatarSemestre(a['semestres']),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF475569)))),
                    DataCell(Text(a['quantidade']?.toString() ?? '-',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A)))),
                    DataCell(Text(_formatarData(a['data_inicio']),
                        style: const TextStyle(
                            fontSize: 8, color: Color(0xFF475569)))),
                    DataCell(Text(_formatarData(a['data_fim']),
                        style: const TextStyle(
                            fontSize: 8, color: Color(0xFF475569)))),
                    DataCell(Container(
                      width: 250,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(a['observacoes'] ?? '-',
                          style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF475569),
                              height: 1.4),
                          textAlign: TextAlign.justify,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            onPressed: () => _clonarAtividade(a),
                            icon: const Icon(Icons.copy_rounded,
                                size: 14, color: Colors.amber),
                            tooltip: 'Clonar para outro semestre'),
                        IconButton(
                            onPressed: () => _editarAtividade(a),
                            icon: const Icon(Icons.edit_rounded,
                                size: 14, color: Color(0xFF0284C7))),
                        IconButton(
                            onPressed: () => _excluirAtividade(a['id']),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 14, color: Colors.red)),
                      ],
                    )),
                  ],
                );
              }).toList()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAtividadeCard(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        a['docentes']?['nome']?.toString().toUpperCase() ?? '-',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0C4A6E),
                            letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text(a['tipos_atividade']?['nome'] ?? '-',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569))),
                  ],
                ),
              ),
              _buildCountBadge(
                  a['quantidade']?.toString() ?? '0', const Color(0xFF0284C7)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoMiniItem("Semestre", _formatarSemestre(a['semestres'])),
              _buildInfoMiniItem("Período",
                  "${_formatarData(a['data_inicio'])} - ${_formatarData(a['data_fim'])}"),
            ],
          ),
          if (a['observacoes'] != null &&
              a['observacoes'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                a['observacoes'],
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildCardAction(Icons.copy_rounded, Colors.amber,
                  () => _clonarAtividade(a), "Clonar"),
              const SizedBox(width: 8),
              _buildCardAction(Icons.edit_rounded, const Color(0xFF0284C7),
                  () => _editarAtividade(a), "Editar"),
              const SizedBox(width: 8),
              _buildCardAction(Icons.delete_outline_rounded, Colors.red,
                  () => _excluirAtividade(a['id']), "Excluir"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoMiniItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildCardAction(
      IconData icon, Color color, VoidCallback onTap, String label) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
