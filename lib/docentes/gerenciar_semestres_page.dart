// lib/docentes/gerenciar_semestres_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class GerenciarSemestresPage extends StatefulWidget {
  const GerenciarSemestresPage({super.key});

  @override
  State<GerenciarSemestresPage> createState() => _GerenciarSemestresPageState();
}

class _GerenciarSemestresPageState extends State<GerenciarSemestresPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _anoController = TextEditingController();
  final _semestreController = TextEditingController();
  DateTime? _dataInicio;
  DateTime? _dataFim;

  bool _loading = false;
  bool _editando = false;
  String _semestreEditId = '';
  List<Map<String, dynamic>> _semestres = [];
  List<Map<String, dynamic>> _semestresFiltrados = [];
  final _searchController = TextEditingController();

  // Variável para controle de permissões
  int _userAccessLevel = 1;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _searchController.addListener(_filtrarSemestres);
  }

  @override
  void dispose() {
    _anoController.dispose();
    _semestreController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('users_access')
            .select('access_level')
            .eq('id', user.id)
            .single();

        setState(() {
          _userAccessLevel = response['access_level'] ?? 1;
        });
      }
      _carregarSemestres();
    } catch (e) {
      _carregarSemestres();
    }
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
        _semestresFiltrados = List.from(_semestres);
      });
    } catch (e) {
      _mostrarErro('Erro ao carregar semestres: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filtrarSemestres() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _semestresFiltrados = List.from(_semestres);
      } else {
        _semestresFiltrados = _semestres.where((semestre) {
          final ano = semestre['ano']?.toString() ?? '';
          final semestreNum = semestre['semestre']?.toString() ?? '';
          return ano.contains(query) || semestreNum.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _salvarSemestre() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataInicio == null || _dataFim == null) {
      _mostrarErro('Selecione as datas de início e fim!');
      return;
    }

    setState(() => _loading = true);
    try {
      final dados = {
        'ano': int.parse(_anoController.text),
        'semestre': int.parse(_semestreController.text),
        'data_inicio': _dataInicio!.toIso8601String().split('T')[0],
        'data_fim': _dataFim!.toIso8601String().split('T')[0],
      };

      if (_editando) {
        await supabase
            .from('semestres')
            .update(dados)
            .eq('id', _semestreEditId);
        _mostrarSucesso('Semestre atualizado com sucesso!');
      } else {
        await supabase.from('semestres').insert(dados);
        _mostrarSucesso('Semestre cadastrado com sucesso!');
      }

      _limparFormulario();
      await _carregarSemestres();
    } on PostgrestException catch (e) {
      if (e.code == '23505')
        _mostrarErro('Já existe um semestre com este ano e período!');
      else if (e.code == '23514')
        _mostrarErro('O semestre deve ser 1 ou 2!');
      else
        _mostrarErro('Erro ao salvar semestre: ${e.message}');
    } catch (e) {
      _mostrarErro('Erro ao salvar semestre: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _editarSemestre(Map<String, dynamic> semestre) {
    setState(() {
      _editando = true;
      _semestreEditId = semestre['id'];
      _anoController.text = semestre['ano']?.toString() ?? '';
      _semestreController.text = semestre['semestre']?.toString() ?? '';
      _dataInicio = DateTime.parse(semestre['data_inicio']);
      _dataFim = DateTime.parse(semestre['data_fim']);
    });
  }

  Future<void> _excluirSemestre(Map<String, dynamic> semestre) async {
    final confirmacao = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirmar Exclusão',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Tem certeza que deseja excluir o semestre ${semestre['ano']}.${semestre['semestre']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmacao == true) {
      try {
        await supabase.from('semestres').delete().eq('id', semestre['id']);
        _mostrarSucesso('Semestre excluído com sucesso!');
        await _carregarSemestres();
      } catch (e) {
        _mostrarErro('Erro ao excluir semestre: $e');
      }
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _anoController.clear();
    _semestreController.clear();
    setState(() {
      _editando = false;
      _semestreEditId = '';
      _dataInicio = null;
      _dataFim = null;
    });
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
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

  Future<void> _selecionarDataInicio() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF0C4A6E))),
          child: child!),
    );
    if (picked != null) setState(() => _dataInicio = picked);
  }

  Future<void> _selecionarDataFim() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataFim ??
          (_dataInicio ?? DateTime.now()).add(const Duration(days: 180)),
      firstDate: _dataInicio ?? DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF0C4A6E))),
          child: child!),
    );
    if (picked != null) setState(() => _dataFim = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Modern Bento
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0369A1).withOpacity(0.12),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF0C4A6E), size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("CONFIGURAÇÕES DO SISTEMA",
                              style: TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0)),
                          Text("Gerenciar Semestres",
                              style: TextStyle(
                                  color: Color(0xFF0C4A6E),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                    if (_editando)
                      IconButton(
                        onPressed: _limparFormulario,
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF0C4A6E)),
                        tooltip: 'Cancelar Edição',
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Form Bento Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                                _anoController, 'Ano', Icons.calendar_month,
                                isNum: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(_semestreController,
                                'Semestre (1 ou 2)', Icons.looks_one,
                                isNum: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateButton(
                                'Início', _dataInicio, _selecionarDataInicio),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateButton(
                                'Fim', _dataFim, _selecionarDataFim),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _salvarSemestre,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C4A6E),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                _editando
                                    ? "ATUALIZAR SEMESTRE"
                                    : "CADASTRAR NOVO SEMESTRE",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Pesquisar semestre...",
                          hintStyle:
                              const TextStyle(fontSize: 13, color: Colors.grey),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Colors.grey, size: 20),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 16, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filtrarSemestres();
                                  },
                                  padding: EdgeInsets.zero,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C4A6E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "${_semestresFiltrados.length}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Table Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text('PERÍODO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B)))),
                    Expanded(
                        flex: 2,
                        child: Text('INÍCIO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B)))),
                    Expanded(
                        flex: 2,
                        child: Text('FIM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B)))),
                    Expanded(
                        flex: 1,
                        child: Text('DIAS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B)))),
                    SizedBox(
                        width: 60,
                        child: Text("AÇÕES",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B)))),
                  ],
                ),
              ),
            ),
          ),

          // Semestres List
          _loading && _semestres.isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final s = _semestresFiltrados[index];
                        final isLast = index == _semestresFiltrados.length - 1;
                        final dataInicio = DateTime.parse(s['data_inicio']);
                        final dataFim = DateTime.parse(s['data_fim']);
                        final duracao = dataFim.difference(dataInicio).inDays;

                        return Container(
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? Colors.white
                                : const Color(0xFFE2E8F0),
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade100)),
                            borderRadius: isLast
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(12))
                                : null,
                          ),
                          child: InkWell(
                            onTap: () => _editarSemestre(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text("${s['ano']}.${s['semestre']}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A))),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(_formatarData(s['data_inicio']),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF334155))),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(_formatarData(s['data_fim']),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF334155))),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text("$duracao",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B))),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _ActionBtn(
                                            icon: Icons.edit_rounded,
                                            color: Colors.blue,
                                            onPressed: () =>
                                                _editarSemestre(s)),
                                        const SizedBox(width: 4),
                                        _ActionBtn(
                                            icon: Icons.delete_outline_rounded,
                                            color: Colors.red,
                                            onPressed: () =>
                                                _excluirSemestre(s)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _semestresFiltrados.length,
                    ),
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool isNum = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF0C4A6E)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold)),
                Text(
                    date != null
                        ? DateFormat('dd/MM/yyyy').format(date)
                        : 'Selecionar',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: Color(0xFF0C4A6E)),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: color),
        onPressed: onPressed,
        hoverColor: color.withOpacity(0.1),
        splashRadius: 18,
      ),
    );
  }
}
