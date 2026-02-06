import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CadastroDocentesPage extends StatefulWidget {
  const CadastroDocentesPage({super.key});

  @override
  State<CadastroDocentesPage> createState() => _CadastroDocentesPageState();
}

class _CadastroDocentesPageState extends State<CadastroDocentesPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _apelidoController = TextEditingController();
  final _searchController = TextEditingController();
  DateTime? _dataAfastamento;

  bool _loading = false;
  bool _formLoading = false;
  bool _editando = false;
  String _docenteEditId = '';
  List<Map<String, dynamic>> _docentes = [];
  List<Map<String, dynamic>> _docentesFiltrados = [];

  // Variáveis para ordenação
  String _colunaOrdenacao = 'nome';
  bool _ordenacaoAscendente = true;

  @override
  void initState() {
    super.initState();
    _carregarDocentes();
    _searchController.addListener(_filtrarDocentes);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _matriculaController.dispose();
    _apelidoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDocentes() async {
    setState(() => _loading = true);

    try {
      final response =
          await supabase.from('docentes').select('*').order('nome');

      setState(() {
        _docentes = (response as List).cast<Map<String, dynamic>>();
        _docentesFiltrados = List.from(_docentes);
        _ordenarDocentes();
      });
    } catch (e) {
      _mostrarMensagem('Erro ao carregar: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filtrarDocentes() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() => _docentesFiltrados = List.from(_docentes));
    } else {
      setState(() {
        _docentesFiltrados = _docentes.where((docente) {
          final nome = docente['nome']?.toString().toLowerCase() ?? '';
          final email = docente['email']?.toString().toLowerCase() ?? '';
          final matricula =
              docente['matricula']?.toString().toLowerCase() ?? '';
          final apelido = docente['apelido']?.toString().toLowerCase() ?? '';

          return nome.contains(query) ||
              email.contains(query) ||
              matricula.contains(query) ||
              apelido.contains(query);
        }).toList();
      });
    }
    _ordenarDocentes();
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

  void _ordenarDocentes() {
    if (_docentesFiltrados.isEmpty) return;

    setState(() {
      _docentesFiltrados.sort((a, b) {
        dynamic valorA;
        dynamic valorB;

        switch (_colunaOrdenacao) {
          case 'status':
            final boolA = a['ativo'] ?? true;
            final boolB = b['ativo'] ?? true;
            return _ordenacaoAscendente
                ? boolA.compareTo(boolB)
                : boolB.compareTo(boolA);
          case 'afastado':
            final dataA = a['afastado_ate'] ?? '';
            final dataB = b['afastado_ate'] ?? '';
            return _ordenacaoAscendente
                ? dataA.compareTo(dataB)
                : dataB.compareTo(dataA);
          case 'nome':
            valorA = _removerTitulosParaOrdenacao(a['nome']?.toString() ?? '');
            valorB = _removerTitulosParaOrdenacao(b['nome']?.toString() ?? '');
            break;
          case 'email':
            valorA = a['email']?.toString().toLowerCase() ?? '';
            valorB = b['email']?.toString().toLowerCase() ?? '';
            break;
          case 'matricula':
            valorA = a['matricula']?.toString().toLowerCase() ?? '';
            valorB = b['matricula']?.toString().toLowerCase() ?? '';
            break;
          default:
            valorA = a[_colunaOrdenacao]?.toString().toLowerCase() ?? '';
            valorB = b[_colunaOrdenacao]?.toString().toLowerCase() ?? '';
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
      _ordenarDocentes();
    });
  }

  Future<void> _salvarDocente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _formLoading = true);

    try {
      final dados = {
        'nome': _nomeController.text.trim(),
        'email': _emailController.text.trim(),
        'matricula': _matriculaController.text.trim().isEmpty
            ? null
            : _matriculaController.text.trim(),
        'apelido': _apelidoController.text.trim().isEmpty
            ? null
            : _apelidoController.text.trim(),
        'afastado_ate': _dataAfastamento?.toIso8601String(),
        'ativo': _dataAfastamento == null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_editando) {
        await supabase.from('docentes').update(dados).eq('id', _docenteEditId);
        _mostrarMensagem('Docente atualizado com sucesso!');
      } else {
        await supabase.from('docentes').insert(dados);
        _mostrarMensagem('Docente cadastrado com sucesso!');
      }

      _resetarFormulario();
      _carregarDocentes();
    } on PostgrestException catch (e) {
      _mostrarMensagem(
          e.code == '23505'
              ? 'Email ou Matrícula já cadastrados!'
              : 'Erro: ${e.message}',
          isErro: true);
    } catch (e) {
      _mostrarMensagem('Ocorreu um erro: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _formLoading = false);
    }
  }

  void _editarDocente(Map<String, dynamic> docente) {
    setState(() {
      _editando = true;
      _docenteEditId = docente['id'];
      _nomeController.text = docente['nome'] ?? '';
      _emailController.text = docente['email'] ?? '';
      _matriculaController.text = docente['matricula'] ?? '';
      _apelidoController.text = docente['apelido'] ?? '';
      _dataAfastamento = docente['afastado_ate'] != null
          ? DateTime.parse(docente['afastado_ate'])
          : null;
    });
    // Scroll to top to see the form
  }

  Future<void> _alternarStatus(Map<String, dynamic> docente) async {
    final novoStatus = !(docente['ativo'] ?? true);
    try {
      await supabase
          .from('docentes')
          .update({'ativo': novoStatus}).eq('id', docente['id']);
      _mostrarMensagem('Docente ${novoStatus ? 'ativado' : 'desativado'}!');
      _carregarDocentes();
    } catch (e) {
      _mostrarMensagem('Erro ao alterar status: $e', isErro: true);
    }
  }

  void _resetarFormulario() {
    _formKey.currentState?.reset();
    _nomeController.clear();
    _emailController.clear();
    _matriculaController.clear();
    _apelidoController.clear();
    setState(() {
      _editando = false;
      _docenteEditId = '';
      _dataAfastamento = null;
    });
  }

  Future<void> _excluirDocente(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir Docente",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "Tem certeza que deseja excluir este docente permanentemente?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCELAR")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("EXCLUIR"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _loading = true);
    try {
      await supabase.from('docentes').delete().eq('id', id);
      _mostrarMensagem("Docente excluído com sucesso!");
      _carregarDocentes();
    } catch (e) {
      _mostrarMensagem("Erro ao excluir: $e", isErro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildFormSliver(),
          _buildTabelaHeaderSliver(),
          if (_loading && _docentes.isEmpty)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (_docentesFiltrados.isEmpty)
            const SliverFillRemaining(
                child: Center(child: Text("Nenhum docente encontrado.")))
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
        padding: EdgeInsets.fromLTRB(24, 48, 24, isMobile ? 16 : 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32)),
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
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ADMINISTRAÇÃO",
                          style: TextStyle(
                              color: const Color(0xFF38BDF8),
                              fontSize: isMobile ? 9 : 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5)),
                      Text("Cadastro de Docentes",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _carregarDocentes,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
    );
  }

  Widget _buildFormSliver() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8))
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
                            : Icons.person_add_alt_1_rounded,
                        color: const Color(0xFF0284C7),
                        size: 24),
                    const SizedBox(width: 12),
                    Text(_editando ? "EDITAR REGISTRO" : "NOVO CADASTRO",
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Color(0xFF0F172A))),
                    const Spacer(),
                    if (_editando)
                      TextButton.icon(
                        onPressed: _resetarFormulario,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text("CANCELAR",
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red[700]),
                      )
                  ],
                ),
                const SizedBox(height: 24),
                if (!isMobile) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          controller: _nomeController,
                          label: "Nome Completo",
                          hint: "Ex: Prof. Dr. João Silva",
                          icon: Icons.person_rounded,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _emailController,
                          label: "E-mail Institucional",
                          hint: "email@ufpb.br",
                          icon: Icons.email_rounded,
                          required: true,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _matriculaController,
                          label: "Siape / Matrícula",
                          hint: "Dados numéricos",
                          icon: Icons.badge_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _apelidoController,
                          label: "Nome Parlamentar / Apelido",
                          hint: "Como é conhecido",
                          icon: Icons.tag_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDatePickerField()),
                      const SizedBox(width: 24),
                      _buildSubmitButton(),
                    ],
                  ),
                ] else ...[
                  _buildTextField(
                    controller: _nomeController,
                    label: "Nome Completo",
                    hint: "Ex: Prof. Dr. João Silva",
                    icon: Icons.person_rounded,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: "E-mail Institucional",
                    hint: "email@ufpb.br",
                    icon: Icons.email_rounded,
                    required: true,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _matriculaController,
                          label: "Matrícula",
                          hint: "Dados",
                          icon: Icons.badge_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _apelidoController,
                          label: "Apelido",
                          hint: "Nome",
                          icon: Icons.tag_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDatePickerField(),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, child: _buildSubmitButton()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Afastado até",
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final data = await showDatePicker(
              context: context,
              initialDate: _dataAfastamento ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (data != null) setState(() => _dataAfastamento = data);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18,
                    color: _dataAfastamento != null
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _dataAfastamento != null
                        ? DateFormat('dd/MM/yyyy').format(_dataAfastamento!)
                        : "Selecionar data",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dataAfastamento != null
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_dataAfastamento != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _dataAfastamento = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _formLoading ? null : _salvarDocente,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _formLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(_editando ? "SALVAR" : "CADASTRAR",
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (required ? " *" : ""),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
            prefixIcon: icon != null
                ? Icon(icon, size: 18, color: const Color(0xFF94A3B8))
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0284C7), width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: required
              ? (val) => val == null || val.isEmpty ? "Obrigatório" : null
              : null,
        ),
      ],
    );
  }

  Widget _buildTabelaHeaderSliver() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("DOCENTES REGISTRADOS",
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5)),
                      const SizedBox(width: 8),
                      _buildCountBadge(_docentesFiltrados.length.toString(),
                          const Color(0xFF0284C7)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSearchField(),
                ],
              )
            : Row(
                children: [
                  const Text("DOCENTES REGISTRADOS",
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5)),
                  const SizedBox(width: 12),
                  _buildCountBadge(_docentesFiltrados.length.toString(),
                      const Color(0xFF0284C7)),
                  const Spacer(),
                  SizedBox(width: 250, child: _buildSearchField()),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: "Filtrar por nome, email...",
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 18, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }

  Widget _buildTabelaRowsSliver() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildDocenteCard(_docentesFiltrados[index]),
            childCount: _docentesFiltrados.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 52,
              dataRowMaxHeight: 56,
              columnSpacing: 40,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: [
                DataColumn(label: _buildSortableHeader('STATUS', 'status')),
                DataColumn(label: _buildSortableHeader('DOCENTE', 'nome')),
                DataColumn(label: _buildSortableHeader('EMAIL', 'email')),
                DataColumn(
                    label: _buildSortableHeader('MATRÍCULA', 'matricula')),
                DataColumn(
                    label: _buildSortableHeader('AFASTADO ATÉ', 'afastado')),
                const DataColumn(
                    label: Text('AÇÕES',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF94A3B8)))),
              ],
              rows: (_docentesFiltrados.asMap().entries.map<DataRow>((entry) {
                final idx = entry.key;
                final d = entry.value;
                final ativo = d['ativo'] ?? true;
                return DataRow(
                  color: WidgetStateProperty.all(idx % 2 == 0
                      ? Colors.white
                      : const Color(0xFFF1F5F9).withOpacity(0.5)),
                  cells: [
                    DataCell(_buildStatusBadge(ativo)),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['nome']?.toString().toUpperCase() ?? '',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: ativo
                                    ? const Color(0xFF0C4A6E)
                                    : const Color(0xFF94A3B8),
                                decoration:
                                    ativo ? null : TextDecoration.lineThrough)),
                        if (d['apelido'] != null)
                          Text(d['apelido'],
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    )),
                    DataCell(Text(d['email'] ?? '',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF475569)))),
                    DataCell(Text(d['matricula'] ?? '-',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF475569)))),
                    DataCell(Text(
                        d['afastado_ate'] != null
                            ? DateFormat('dd/MM/yyyy')
                                .format(DateTime.parse(d['afastado_ate']))
                            : '-',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF475569)))),
                    DataCell(Row(
                      children: [
                        IconButton(
                          onPressed: () => _editarDocente(d),
                          icon: const Icon(Icons.edit_rounded,
                              size: 18, color: Color(0xFF0284C7)),
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          onPressed: () => _alternarStatus(d),
                          icon: Icon(
                              ativo
                                  ? Icons.block_rounded
                                  : Icons.check_circle_rounded,
                              size: 18,
                              color:
                                  ativo ? Colors.red[400] : Colors.green[400]),
                          tooltip: ativo ? 'Desativar' : 'Ativar',
                        ),
                        IconButton(
                          onPressed: () => _excluirDocente(d['id']),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.red),
                          tooltip: 'Excluir',
                        ),
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

  Widget _buildDocenteCard(Map<String, dynamic> d) {
    final ativo = d['ativo'] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            children: [
              _buildStatusBadge(ativo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['nome']?.toString().toUpperCase() ?? '',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: ativo
                                ? const Color(0xFF0C4A6E)
                                : const Color(0xFF94A3B8),
                            decoration:
                                ativo ? null : TextDecoration.lineThrough,
                            letterSpacing: -0.3)),
                    if (d['apelido'] != null)
                      Text(d['apelido'],
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.email_outlined, d['email'] ?? '-'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildInfoRow(
                      Icons.badge_outlined, d['matricula'] ?? '-')),
              if (d['afastado_ate'] != null)
                Expanded(
                    child: _buildInfoRow(
                        Icons.event_busy_outlined,
                        DateFormat('dd/MM/yy')
                            .format(DateTime.parse(d['afastado_ate'])))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionCircle(Icons.edit_rounded, const Color(0xFF0284C7),
                  () => _editarDocente(d)),
              const SizedBox(width: 12),
              _buildActionCircle(
                  ativo ? Icons.block_rounded : Icons.check_circle_rounded,
                  ativo ? Colors.red[400]! : Colors.green[400]!,
                  () => _alternarStatus(d)),
              const SizedBox(width: 12),
              _buildActionCircle(Icons.delete_outline_rounded, Colors.red,
                  () => _excluirDocente(d['id'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActionCircle(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildSortableHeader(String label, String id) {
    final isSelected = _colunaOrdenacao == id;
    return InkWell(
      onTap: () => _mudarOrdenacao(id),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF94A3B8))),
          if (isSelected) ...[
            const SizedBox(width: 4),
            Icon(
                _ordenacaoAscendente
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: const Color(0xFF0284C7)),
          ]
        ],
      ),
    );
  }

  Widget _buildCountBadge(String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(count,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }

  Widget _buildStatusBadge(bool ativo) {
    final color = ativo ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(ativo ? "ATIVO" : "INATIVO",
          style: TextStyle(
              color: color, fontWeight: FontWeight.w900, fontSize: 9)),
    );
  }
}
