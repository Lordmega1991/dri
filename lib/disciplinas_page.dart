// lib/disciplinas_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DisciplinasPage extends StatefulWidget {
  const DisciplinasPage({super.key});

  @override
  State<DisciplinasPage> createState() => _DisciplinasPageState();
}

class _DisciplinasPageState extends State<DisciplinasPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> disciplinas = [];
  List<Map<String, dynamic>> disciplinasFiltradas = [];
  final TextEditingController _pesquisaController = TextEditingController();

  // Variáveis para ordenação
  String _colunaOrdenacao = 'nome';
  bool _ordenacaoAscendente = true;

  // Variável para armazenar o nível de acesso do usuário
  int _userAccessLevel = 1;
  bool _isLoadingUserAccess = true;

  // Opções para os dropdowns
  final List<String> periodos = [
    '1º',
    '2º',
    '3º',
    '4º',
    '5º',
    '6º',
    '7º',
    '8º',
    '9º',
    '10º'
  ];
  final List<String> turnos = ['Matutino', 'Vespertino', 'Noturno', 'Integral'];
  final List<String> ppcOptions = ['antigo', 'novo'];

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _pesquisaController.addListener(() {
      _filtrarDisciplinas(_pesquisaController.text);
    });
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
          _isLoadingUserAccess = false;
        });
      } else {
        setState(() => _isLoadingUserAccess = false);
      }
      _carregarDisciplinas();
    } catch (e) {
      setState(() => _isLoadingUserAccess = false);
      _carregarDisciplinas();
    }
  }

  Future<void> _carregarDisciplinas() async {
    final response = await supabase.from('disciplinas').select().order('nome');
    setState(() {
      disciplinas = List<Map<String, dynamic>>.from(response);
      disciplinasFiltradas = disciplinas;
      _ordenarDisciplinas();
    });
  }

  bool _podeAdicionar() => _userAccessLevel >= 3;
  bool _podeEditarOuExcluir() => _userAccessLevel >= 4;

  void _mostrarMensagemAcessoNegado() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Acesso restrito para o seu nível de usuário.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _filtrarDisciplinas(String texto) {
    final filtro = texto.toLowerCase();
    setState(() {
      disciplinasFiltradas = disciplinas.where((disciplina) {
        final nome = (disciplina['nome'] ?? '').toString().toLowerCase();
        final nomeExtenso =
            (disciplina['nome_extenso'] ?? '').toString().toLowerCase();
        final periodo = (disciplina['periodo'] ?? '').toString().toLowerCase();
        final turno = (disciplina['turno'] ?? '').toString().toLowerCase();
        return nome.contains(filtro) ||
            nomeExtenso.contains(filtro) ||
            periodo.contains(filtro) ||
            turno.contains(filtro);
      }).toList();
      _ordenarDisciplinas();
    });
  }

  void _ordenarDisciplinas() {
    disciplinasFiltradas.sort((a, b) {
      dynamic valorA;
      dynamic valorB;

      switch (_colunaOrdenacao) {
        case 'nome':
          valorA = a['nome']?.toString().toLowerCase() ?? '';
          valorB = b['nome']?.toString().toLowerCase() ?? '';
          break;
        case 'periodo':
          valorA = a['periodo']?.toString().toLowerCase() ?? '';
          valorB = b['periodo']?.toString().toLowerCase() ?? '';
          break;
        case 'turno':
          valorA = a['turno']?.toString().toLowerCase() ?? '';
          valorB = b['turno']?.toString().toLowerCase() ?? '';
          break;
        case 'ppc':
          valorA = a['ppc']?.toString().toLowerCase() ?? '';
          valorB = b['ppc']?.toString().toLowerCase() ?? '';
          break;
        default:
          valorA = a['nome']?.toString().toLowerCase() ?? '';
          valorB = b['nome']?.toString().toLowerCase() ?? '';
      }

      int resultado;
      if (valorA is String && valorB is String) {
        resultado = valorA.compareTo(valorB);
      } else if (valorA is int && valorB is int) {
        resultado = valorA.compareTo(valorB);
      } else {
        resultado = valorA.toString().compareTo(valorB.toString());
      }
      return _ordenacaoAscendente ? resultado : -resultado;
    });
  }

  void _alterarOrdenacao(String coluna) {
    setState(() {
      if (_colunaOrdenacao == coluna) {
        _ordenacaoAscendente = !_ordenacaoAscendente;
      } else {
        _colunaOrdenacao = coluna;
        _ordenacaoAscendente = true;
      }
      _ordenarDisciplinas();
    });
  }

  String? _formatarPeriodo(String? periodo) {
    if (periodo == null || periodo.isEmpty) return null;
    final clean = periodo.replaceAll('º', '').trim();
    if (clean.isEmpty) return null;
    return '${clean}º';
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
                          Text("GESTÃO DO SEMESTRE",
                              style: TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0)),
                          Text("Disciplinas",
                              style: TextStyle(
                                  color: Color(0xFF0C4A6E),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                    if (_podeAdicionar())
                      FloatingActionButton.small(
                        onPressed: () => _adicionarOuEditarDisciplina(),
                        backgroundColor: const Color(0xFF0C4A6E),
                        child: const Icon(Icons.add, color: Colors.white),
                        elevation: 2,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Search and Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
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
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _pesquisaController,
                        decoration: const InputDecoration(
                          hintText: "Nome, período ou turno...",
                          hintStyle:
                              TextStyle(fontSize: 13, color: Colors.grey),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.grey, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
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
                        "${disciplinasFiltradas.length}",
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
                child: Row(
                  children: [
                    _buildSortableHeader('DISCIPLINA', 'nome', flex: 3),
                    _buildSortableHeader('PERÍODO', 'periodo', flex: 1),
                    _buildSortableHeader('TURNO', 'turno', flex: 1),
                    _buildSortableHeader('PPC', 'ppc', flex: 1),
                    const SizedBox(
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

          // Disciplinas List
          _isLoadingUserAccess
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final d = disciplinasFiltradas[index];
                        final isLast = index == disciplinasFiltradas.length - 1;
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
                            onTap: () => _adicionarOuEditarDisciplina(d),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(d['nome'] ?? '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                color: Color(0xFF0F172A),
                                                height: 1.1)),
                                        if (d['nome_extenso'] != null)
                                          Text(d['nome_extenso'],
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                  height: 1.0),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                        _formatarPeriodo(
                                                d['periodo']?.toString()) ??
                                            '-',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155))),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(d['turno'] ?? '-',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B))),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                        d['ppc']?.toString().toUpperCase() ??
                                            '-',
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
                                        _TableActionBtn(
                                          icon: Icons.edit_rounded,
                                          color: _podeEditarOuExcluir()
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                          onPressed: () =>
                                              _adicionarOuEditarDisciplina(d),
                                        ),
                                        const SizedBox(width: 4),
                                        _TableActionBtn(
                                          icon: Icons.delete_outline_rounded,
                                          color: _podeEditarOuExcluir()
                                              ? Colors.red
                                              : Colors.grey.shade300,
                                          onPressed: () =>
                                              _excluirDisciplina(d),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: disciplinasFiltradas.length,
                    ),
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String title, String column,
      {required int flex}) {
    final isSelected = _colunaOrdenacao == column;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _alterarOrdenacao(column),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B))),
              if (isSelected)
                Icon(
                    _ordenacaoAscendente
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    size: 14,
                    color: const Color(0xFF0284C7)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _adicionarOuEditarDisciplina([Map<String, dynamic>? d]) async {
    // Se d for null, é inclusão. Se não for, é alteração.
    if (d == null) {
      if (!_podeAdicionar()) {
        _mostrarMensagemAcessoNegado();
        return;
      }
    } else {
      if (!_podeEditarOuExcluir()) {
        _mostrarMensagemAcessoNegado();
        return;
      }
    }

    final nomeCtrl = TextEditingController(text: d?['nome'] ?? '');
    final nomeExtCtrl = TextEditingController(text: d?['nome_extenso'] ?? '');
    final chCtrl =
        TextEditingController(text: d?['ch_aula']?.toString() ?? '60');
    final periodoCtrl = TextEditingController(
        text: d?['periodo']?.toString().replaceAll('º', '') ?? '');
    String? turno = d?['turno'] ?? 'Matutino';
    String? ppc = d?['ppc'] ?? 'novo';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(d == null ? "Nova Disciplina" : "Editar Disciplina",
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(
                  nomeCtrl, "Sigla/Nome Curto (Ex: TCC1)", Icons.short_text),
              _buildField(nomeExtCtrl, "Nome Completo", Icons.title),
              _buildField(chCtrl, "Carga Horária", Icons.timer, isNum: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: periodos.contains(_formatarPeriodo(periodoCtrl.text))
                    ? _formatarPeriodo(periodoCtrl.text)
                    : null,
                decoration: InputDecoration(
                    labelText: 'Período',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                items: periodos
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) =>
                    periodoCtrl.text = v?.replaceAll('º', '') ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: turnos.contains(turno) ? turno : turnos.first,
                decoration: InputDecoration(
                    labelText: 'Turno',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                items: turnos
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => turno = v,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: ppcOptions.contains(ppc) ? ppc : ppcOptions.first,
                decoration: InputDecoration(
                    labelText: 'PPC',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                items: ppcOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => ppc = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C4A6E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final dados = {
                'nome': nomeCtrl.text.trim(),
                'nome_extenso': nomeExtCtrl.text.trim(),
                'ch_aula': int.tryParse(chCtrl.text) ?? 0,
                'periodo': _formatarPeriodo(periodoCtrl.text),
                'turno': turno,
                'ppc': ppc,
              };
              try {
                if (d == null)
                  await supabase.from('disciplinas').insert(dados);
                else
                  await supabase
                      .from('disciplinas')
                      .update(dados)
                      .eq('id', d['id']);
                _carregarDisciplinas();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Erro: $e"), backgroundColor: Colors.red));
              }
            },
            child: const Text("SALVAR"),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon,
      {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _excluirDisciplina(Map<String, dynamic> d) async {
    if (!_podeEditarOuExcluir()) {
      _mostrarMensagemAcessoNegado();
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text("Deseja realmente excluir a disciplina ${d['nome']}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("NÃO")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("SIM, EXCLUIR",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar == true) {
      await supabase.from('disciplinas').delete().eq('id', d['id']);
      _carregarDisciplinas();
    }
  }
}

class _TableActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _TableActionBtn({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

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
