// lib/visualizar_defesa.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'pdf_generator.dart';
import 'ficha_avaliacao_generator.dart';
import 'ficha_avaliacao_final_generator.dart';
import 'cadastrar_defesa.dart';
import 'notas_page.dart';
import 'dados_defesa_final_page.dart';

class VisualizarDefesaPage extends StatefulWidget {
  const VisualizarDefesaPage({super.key});

  @override
  State<VisualizarDefesaPage> createState() => _VisualizarDefesaPageState();
}

class _VisualizarDefesaPageState extends State<VisualizarDefesaPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> defesas = [];
  bool loading = true;
  bool mostrarFiltro2 = false;

  final filtroController1 = TextEditingController();
  final filtroController2 = TextEditingController();
  String filtroCampo1 = 'semestre';
  String filtroCampo2 = 'discente';
  String? semestreMaisRecente;
  bool filtrosForamLimpos = false;

  // Controle de ordenação
  String _ordenacaoCampo = 'discente';
  bool _ordenacaoAsc = true;

  final List<String> camposFiltro = [
    'semestre',
    'dia',
    'discente',
    'orientador',
    'coorientador',
    'avaliador1',
    'avaliador2',
    'avaliador3',
    'titulo',
    'local',
  ];

  @override
  void initState() {
    super.initState();
    carregarDefesas();
  }

  @override
  void dispose() {
    filtroController1.dispose();
    filtroController2.dispose();
    super.dispose();
  }

  String? _encontrarSemestreMaisRecente(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return null;
    final semestres = data
        .map((e) => e['semestre']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (semestres.isEmpty) return null;

    semestres.sort((a, b) {
      try {
        final partsA = a.split('.');
        final partsB = b.split('.');
        if (partsA.length != 2 || partsB.length != 2) return 0;
        final anoA = int.tryParse(partsA[0]) ?? 0;
        final semA = int.tryParse(partsA[1]) ?? 0;
        final anoB = int.tryParse(partsB[0]) ?? 0;
        final semB = int.tryParse(partsB[1]) ?? 0;
        if (anoA != anoB) return anoB.compareTo(anoA);
        return semB.compareTo(semA);
      } catch (e) {
        return 0;
      }
    });
    return semestres.first;
  }

  Future<void> carregarDefesas(
      {String? c1, String? v1, String? c2, String? v2}) async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      var query = supabase.from('dados_defesas').select();
      if (v1 != null && v1.isNotEmpty)
        query = _aplicarFiltro(query, c1 ?? filtroCampo1, v1);
      if (mostrarFiltro2 && v2 != null && v2.isNotEmpty)
        query = _aplicarFiltro(query, c2 ?? filtroCampo2, v2);

      final response =
          await query.order(_ordenacaoCampo, ascending: _ordenacaoAsc);
      final list = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;
      setState(() {
        defesas = list;
        semestreMaisRecente = _encontrarSemestreMaisRecente(list);
        if (v1 == null &&
            v2 == null &&
            !filtrosForamLimpos &&
            semestreMaisRecente != null) {
          filtroCampo1 = 'semestre';
          filtroController1.text = semestreMaisRecente!;
          // Filtra localmente apenas no carregamento inicial se nenhum filtro foi passado
          defesas =
              list.where((e) => e['semestre'] == semestreMaisRecente).toList();
        }
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _mostrarErro("Erro: $e");
      }
    }
  }

  void _mudarOrdenacao(String campo) {
    setState(() {
      if (_ordenacaoCampo == campo) {
        _ordenacaoAsc = !_ordenacaoAsc;
      } else {
        _ordenacaoCampo = campo;
        _ordenacaoAsc = true;
      }
    });
    _executarPesquisa();
  }

  dynamic _aplicarFiltro(dynamic query, String campo, String valor) {
    if (campo == 'dia') return query.eq('dia', valor);
    return query.ilike(campo, '%$valor%');
  }

  Future<void> _handleFiltro(int num) async {
    final campo = num == 1 ? filtroCampo1 : filtroCampo2;
    final ctrl = num == 1 ? filtroController1 : filtroController2;

    if (campo == 'dia') {
      final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100));
      if (picked != null) {
        final dStr = DateFormat('yyyy-MM-dd').format(picked);
        ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
        carregarDefesas(
            c1: filtroCampo1,
            v1: num == 1 ? dStr : filtroController1.text,
            c2: mostrarFiltro2 ? filtroCampo2 : null,
            v2: num == 2
                ? dStr
                : (mostrarFiltro2 ? filtroController2.text : null));
      }
    } else {
      _executarPesquisa();
    }
  }

  void _executarPesquisa() {
    carregarDefesas(
        c1: filtroCampo1,
        v1: filtroController1.text,
        c2: mostrarFiltro2 ? filtroCampo2 : null,
        v2: mostrarFiltro2 ? filtroController2.text : null);
  }

  void _limparFiltros() {
    filtroController1.clear();
    filtroController2.clear();
    setState(() {
      mostrarFiltro2 = false;
      filtrosForamLimpos = true;
    });
    carregarDefesas();
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  void _mostrarSucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating));
  }

  String _formatarData(dynamic data) {
    if (data == null) return '-';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(data.toString()));
    } catch (e) {
      return '-';
    }
  }

  String _formatarHora(dynamic hora) {
    if (hora == null || hora.toString().isEmpty) return '--:--';
    try {
      final parts = hora.toString().split(':');
      if (parts.length >= 2) {
        final h = parts[0].padLeft(2, '0');
        final m = parts[1].padLeft(2, '0');
        return '$h:$m';
      }
      return hora.toString();
    } catch (e) {
      return hora.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: LayoutBuilder(builder: (context, constraints) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF0369A1).withOpacity(0.12),
                        blurRadius: 15,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _BentoActionBtn(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context)),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("SISTEMA DE GESTÃO",
                                    style: TextStyle(
                                        color: Color(0xFF0284C7),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0)),
                                Text("Visualizar Defesas",
                                    style: TextStyle(
                                        color: Color(0xFF0C4A6E),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5)),
                              ],
                            ),
                          ),
                          _BentoActionBtn(
                              icon: Icons.refresh_rounded,
                              onTap: carregarDefesas),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFiltroArea(),
                      const SizedBox(height: 12),
                      _buildSortAndTotalBar(),
                    ],
                  ),
                ),
              ),
            ),
            if (loading)
              const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF0C4A6E))))
            else if (defesas.isEmpty)
              _buildEmptyState()
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= defesas.length) return null;
                      return _DefenseCard(
                        defesa: defesas[index],
                        dia: _formatarData(defesas[index]['dia']),
                        onEdit: () => _editarDefesa(defesas[index]),
                        onNotes: () => _abrirPaginaNotas(defesas[index]),
                        onDetails: () => _mostrarDetalhesDefesa(defesas[index]),
                      );
                    },
                    childCount: defesas.length,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildFiltroArea() {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, fConstraints) {
              final isWide = fConstraints.maxWidth > 600;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: _buildFiltroInput(1)),
                    if (mostrarFiltro2) ...[
                      const SizedBox(width: 8),
                      Expanded(child: _buildFiltroInput(2)),
                    ],
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildFiltroInput(1),
                    if (mostrarFiltro2) ...[
                      const SizedBox(height: 8),
                      _buildFiltroInput(2),
                    ],
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => mostrarFiltro2 = !mostrarFiltro2),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                          mostrarFiltro2
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          size: 16,
                          color: const Color(0xFF0369A1)),
                      const SizedBox(width: 4),
                      Text(mostrarFiltro2 ? "Menos Filtros" : "Mais Filtros",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0369A1))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _limparFiltros,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded,
                          size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text("Limpar",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortAndTotalBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0C4A6E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: Color(0xFF0C4A6E)),
                const SizedBox(width: 6),
                Text(
                  "Total: ${defesas.length} ${defesas.length == 1 ? 'defesa' : 'defesas'}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0C4A6E),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Text("ORDENAR POR:",
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5)),
              const SizedBox(width: 8),
              _buildSortChip("NOME", 'discente'),
              const SizedBox(width: 4),
              _buildSortChip("DATA", 'dia'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String campo) {
    final isSelected = _ordenacaoCampo == campo;
    return GestureDetector(
      onTap: () => _mudarOrdenacao(campo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0C4A6E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  isSelected ? const Color(0xFF0C4A6E) : Colors.blue.shade100),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: const Color(0xFF0C4A6E).withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color:
                        isSelected ? Colors.white : const Color(0xFF64748B))),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _ordenacaoAsc
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 10,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroInput(int num) {
    final ctrl = num == 1 ? filtroController1 : filtroController2;
    return Container(
      height: 44,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100)),
      child: Row(
        children: [
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: num == 1 ? filtroCampo1 : filtroCampo2,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, size: 18),
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF0C4A6E),
                fontWeight: FontWeight.w700),
            items: camposFiltro
                .map((c) =>
                    DropdownMenuItem(value: c, child: Text(c.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() {
              if (num == 1)
                filtroCampo1 = v!;
              else
                filtroCampo2 = v!;
              ctrl.clear();
            }),
          ),
          Container(width: 1, height: 20, color: Colors.grey.shade200),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                  hintText: "Buscar...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8)),
              onSubmitted: (_) => _handleFiltro(num),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded,
                size: 18, color: Color(0xFF0284C7)),
            onPressed: () => _handleFiltro(num),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("Nenhuma defesa encontrada",
                style: TextStyle(
                    color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _limparFiltros, child: const Text("Limpar Filtros"))
          ],
        ),
      ),
    );
  }

  void _editarDefesa(Map<String, dynamic> d) {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CadastrarDefesaPage(defesaExistente: d)))
        .then((_) => carregarDefesas());
  }

  void _abrirPaginaNotas(Map<String, dynamic> d) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => NotasPage(defesaId: d['id'] ?? 0, defesa: d)));
  }

  void _mostrarDetalhesDefesa(Map<String, dynamic> d) {
    final dia = _formatarData(d['dia']);
    final hora = _formatarHora(d['hora']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DefenseDetailsSheet(
        defesa: d,
        dia: dia,
        hora: hora,
        onAction: (action) => _executeAction(action, d),
      ),
    );
  }

  Future<void> _excluirDefesa(Map<String, dynamic> d) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir Banca"),
        content: Text(
            "Deseja realmente excluir a banca de ${d['discente']}? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => loading = true);
      try {
        await supabase.from('dados_defesas').delete().eq('id', d['id']);
        _mostrarSucesso("Banca excluída com sucesso!");
        carregarDefesas();
      } catch (e) {
        _mostrarErro("Erro ao excluir: $e");
        setState(() => loading = false);
      }
    }
  }

  Future<void> _executeAction(String action, Map<String, dynamic> d) async {
    try {
      switch (action) {
        case 'ata':
          await PdfGenerator.generateAtaDefesa(d);
          break;
        case 'folha':
          await PdfGenerator.generateFolhaAprovacao(d);
          break;
        case 'ficha_final':
          await FichaAvaliacaoFinalGenerator.generateFichaAvaliacaoFinal(d);
          break;
        case 'fichas_ind':
          await _mostrarSelecaoAvaliadoresFichas(d);
          break;
        case 'dados_finais':
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      DadosDefesaFinalPage(defesaId: d['id'], defesa: d)));
          break;
        case 'edit':
          Navigator.pop(context); // Fecha o bottom sheet
          _editarDefesa(d);
          break;
        case 'notes':
          Navigator.pop(context); // Fecha o bottom sheet
          _abrirPaginaNotas(d);
          break;
        case 'copy':
          final txt = "Login: ${d['login']}\nSenha: ${d['senha']}";
          await Clipboard.setData(ClipboardData(text: txt));
          _mostrarSucesso("Copiado!");
          break;
        case 'delete':
          Navigator.pop(context); // Fecha o bottom sheet
          _excluirDefesa(d);
          break;
      }
      if (action != 'fichas_ind' &&
          action != 'dados_finais' &&
          action != 'copy') _mostrarSucesso("Sucesso!");
    } catch (e) {
      _mostrarErro("Erro: $e");
    }
  }

  Future<void> _mostrarSelecaoAvaliadoresFichas(Map<String, dynamic> d) async {
    final list = <int>[];
    if (d['avaliador1'] != null && d['avaliador1'].toString().isNotEmpty)
      list.add(1);
    if (d['avaliador2'] != null && d['avaliador2'].toString().isNotEmpty)
      list.add(2);
    if (d['avaliador3'] != null && d['avaliador3'].toString().isNotEmpty)
      list.add(3);

    if (list.isEmpty) {
      _mostrarErro("Sem avaliadores registrados");
      return;
    }

    final selecionados = await showDialog<List<int>>(
        context: context,
        builder: (context) =>
            _AvaliadoresPickerDialog(avaliadores: list, d: d));

    if (selecionados != null && selecionados.isNotEmpty) {
      await FichaAvaliacaoGenerator.generateFichasAvaliacaoSelecionadas(
          d, selecionados);
      _mostrarSucesso("Fichas geradas!");
    }
  }
}

class _BentoActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _BentoActionBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: const Color(0xFF0C4A6E), size: 20)),
      ),
    );
  }
}

class _DefenseCard extends StatelessWidget {
  final Map<String, dynamic> defesa;
  final String dia;
  final VoidCallback onEdit;
  final VoidCallback onNotes;
  final VoidCallback onDetails;

  const _DefenseCard(
      {required this.defesa,
      required this.dia,
      required this.onEdit,
      required this.onNotes,
      required this.onDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDetails,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.school_rounded,
                      color: Color(0xFF0284C7), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(defesa['discente'] ?? 'DISCENTE',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(dia,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF0284C7),
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                "• ${defesa['orientador']?.toString().toUpperCase() ?? 'N/A'}",
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                    overflow: TextOverflow.ellipsis)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DefenseDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> defesa;
  final String dia;
  final String hora;
  final Function(String) onAction;

  const _DefenseDetailsSheet(
      {required this.defesa,
      required this.dia,
      required this.hora,
      required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DETALHES DA DEFESA",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0284C7),
                              letterSpacing: 1.5)),
                      Text(defesa['discente'] ?? '-',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0C4A6E))),
                    ],
                  ),
                ),
                _PopupActionBtn(
                    icon: Icons.edit_note_rounded,
                    color: Colors.amber.shade700,
                    onTap: () => onAction('edit')),
                const SizedBox(width: 8),
                _PopupActionBtn(
                    icon: Icons.grade_rounded,
                    color: Colors.purple.shade600,
                    onTap: () => onAction('notes')),
                const SizedBox(width: 8),
                _PopupActionBtn(
                    icon: Icons.copy_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: () => onAction('copy')),
                const SizedBox(width: 8),
                _PopupActionBtn(
                    icon: Icons.delete_forever_rounded,
                    color: Colors.red.shade700,
                    onTap: () => onAction('delete')),
              ],
            ),
            const SizedBox(height: 24),
            _InfoRow(label1: "DATA", val1: dia, label2: "HORÁRIO", val2: hora),
            const SizedBox(height: 12),
            _InfoBoxWide(
                label: "LOCAL", value: defesa['local'] ?? 'Não informado'),
            const SizedBox(height: 12),
            _InfoBoxWide(
                label: "TÍTULO DO TRABALHO", value: defesa['titulo'] ?? '-'),
            const SizedBox(height: 32),
            const Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 16, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text("DOCUMENTOS ACADÊMICOS",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF64748B),
                        letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _BigActionBtn(
                    label: "ATA DEFESA",
                    icon: Icons.description,
                    color: Colors.blue,
                    onTap: () => onAction('ata')),
                _BigActionBtn(
                    label: "APROVAÇÃO",
                    icon: Icons.assignment_turned_in,
                    color: Colors.indigo,
                    onTap: () => onAction('folha')),
                _BigActionBtn(
                    label: "FICHA FINAL",
                    icon: Icons.grading,
                    color: Colors.orange,
                    onTap: () => onAction('ficha_final')),
                _BigActionBtn(
                    label: "FICHAS IND.",
                    icon: Icons.assignment_ind,
                    color: Colors.green,
                    onTap: () => onAction('fichas_ind')),
                _BigActionBtn(
                    label: "DADOS FINAIS",
                    icon: Icons.playlist_add_check_rounded,
                    color: Colors.purple,
                    onTap: () => onAction('dados_finais')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PopupActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 20)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label1, val1, label2, val2;
  const _InfoRow(
      {required this.label1,
      required this.val1,
      required this.label2,
      required this.val2});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _InfoBoxWide(label: label1, value: val1)),
        const SizedBox(width: 12),
        Expanded(child: _InfoBoxWide(label: label2, value: val2)),
      ],
    );
  }
}

class _InfoBoxWide extends StatelessWidget {
  final String label, value;
  const _InfoBoxWide({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155))),
        ],
      ),
    );
  }
}

class _BigActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BigActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 60) / 2,
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: color.withOpacity(0.8)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvaliadoresPickerDialog extends StatefulWidget {
  final List<int> avaliadores;
  final Map<String, dynamic> d;
  const _AvaliadoresPickerDialog({required this.avaliadores, required this.d});

  @override
  State<_AvaliadoresPickerDialog> createState() =>
      _AvaliadoresPickerDialogState();
}

class _AvaliadoresPickerDialogState extends State<_AvaliadoresPickerDialog> {
  final List<int> selecionados = [];
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text("Gerar Fichas",
          style: TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.avaliadores.map((n) {
            final nome = widget.d['avaliador$n'] ?? 'Avaliador $n';
            return CheckboxListTile(
              title: Text(nome,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              value: selecionados.contains(n),
              onChanged: (v) => setState(
                  () => v! ? selecionados.add(n) : selecionados.remove(n)),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR")),
        ElevatedButton(
          onPressed: selecionados.isEmpty
              ? null
              : () => Navigator.pop(context, selecionados),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C4A6E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text("GERAR"),
        ),
      ],
    );
  }
}
