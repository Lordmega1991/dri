import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class CalendarioDefesasPage extends StatefulWidget {
  const CalendarioDefesasPage({super.key});

  @override
  State<CalendarioDefesasPage> createState() => _CalendarioDefesasPageState();
}

class _CalendarioDefesasPageState extends State<CalendarioDefesasPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> defesas = [];
  Map<String, List<Map<String, dynamic>>> defesasPorDia = {};
  List<Map<String, dynamic>> defesasSemData = [];
  bool loading = true;
  DateTime _currentMonth = DateTime.now();
  bool _dateFormattingInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('pt_BR', null);
    if (mounted) {
      setState(() {
        _dateFormattingInitialized = true;
      });
      carregarDefesas();
    }
  }

  Future<void> carregarDefesas() async {
    if (!_dateFormattingInitialized) return;

    setState(() => loading = true);

    try {
      final response = await supabase
          .from('dados_defesas')
          .select()
          .order('dia', ascending: true);

      final list = List<Map<String, dynamic>>.from(response as List);

      // Otimização: Agrupar defesas por dia em um Map para acesso O(1)
      final map = <String, List<Map<String, dynamic>>>{};
      final semData = <Map<String, dynamic>>[];

      for (var d in list) {
        if (d['dia'] == null) {
          semData.add(d);
        } else {
          final dateStr =
              DateFormat('yyyy-MM-dd').format(DateTime.parse(d['dia']));
          if (!map.containsKey(dateStr)) map[dateStr] = [];
          map[dateStr]!.add(d);
        }
      }

      setState(() {
        defesas = list;
        defesasPorDia = map;
        defesasSemData = semData;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _mostrarErro("Erro ao carregar defesas: $e");
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
    );
  }

  String _formatarHora(dynamic hora) {
    if (hora == null || hora.toString().isEmpty) return '';
    try {
      final parts = hora.toString().split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
      return hora.toString();
    } catch (e) {
      return hora.toString();
    }
  }

  void _navegarMes(int offset) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 1000;

    if (!_dateFormattingInitialized) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0C4A6E))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                _buildHeader(),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: loading
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(100),
                                child: CircularProgressIndicator()))
                        : _buildCalendarioGrid(),
                  ),
                ),
              ],
            ),
          ),
          if (isLargeScreen) _buildSidebar(),
        ],
      ),
      floatingActionButton: !isLargeScreen && defesasSemData.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showDefesasSemDataSheet,
              backgroundColor: Colors.orange.shade700,
              icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
              label: const Text("SEM DATA",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0C4A6E),
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32)),
        ),
        child: Row(
          children: [
            _backButton(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("GESTÃO DE DEFESAS",
                      style: TextStyle(
                          color: Color(0xFF7DD3FC),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  Text(
                      DateFormat('MMMM yyyy', 'pt_BR')
                          .format(_currentMonth)
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
            _navButton(Icons.chevron_left_rounded, () => _navegarMes(-1)),
            const SizedBox(width: 8),
            _navButton(Icons.chevron_right_rounded, () => _navegarMes(1)),
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

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildCalendarioGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startingWeekday = firstDay.weekday; // 1 (Mon) to 7 (Sun)

    // Ajustar para domingo ser o primeiro dia se necessário, mas aqui usaremos Seg-Dom padrão BR
    // startingWeekday: 1=Seg, ..., 7=Dom
    int emptyDays = startingWeekday - 1;

    return Column(
      children: [
        _buildDaysHeader(),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.8, // Drasticamente mais compacto
          ),
          itemCount: emptyDays + lastDay.day,
          itemBuilder: (context, index) {
            if (index < emptyDays) return const SizedBox();

            final day = index - emptyDays + 1;
            final date = DateTime(_currentMonth.year, _currentMonth.month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final defesasDoDia = defesasPorDia[dateStr] ?? [];
            final isToday =
                DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

            return _buildDayCell(day, isToday, defesasDoDia, date);
          },
        ),
      ],
    );
  }

  Widget _buildDaysHeader() {
    final dias = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM'];
    return Row(
      children: dias
          .map((d) => Expanded(
              child: Text(d,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1))))
          .toList(),
    );
  }

  Widget _buildDayCell(int day, bool isToday,
      List<Map<String, dynamic>> defesas, DateTime date) {
    bool temDefesa = defesas.isNotEmpty;

    return GestureDetector(
      onTap: temDefesa ? () => _mostrarDetalhesDia(date, defesas) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? const Color(0xFF0284C7)
                : (temDefesa
                    ? const Color(0xFFE0F2FE)
                    : const Color(0xFFF1F5F9)),
            width: isToday ? 1.5 : 1,
          ),
          boxShadow: temDefesa
              ? [
                  BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFF0284C7)
                    : (temDefesa
                        ? const Color(0xFFF0F9FF)
                        : Colors.transparent),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(day.toString(),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isToday
                              ? Colors.white
                              : const Color(0xFF1E293B))),
                  if (temDefesa)
                    Row(
                      children: [
                        Icon(Icons.school_rounded,
                            size: 14,
                            color: isToday
                                ? Colors.white
                                : const Color(0xFF0284C7)),
                        const SizedBox(width: 2),
                        Text("${defesas.length}",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isToday
                                    ? Colors.white
                                    : const Color(0xFF0284C7))),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: defesas.take(2).map((d) {
                    final nomeCompleto = (d['discente'] ?? "").toString();
                    final partes = nomeCompleto.trim().split(' ');
                    final nomeExibicao = partes.length >= 2
                        ? "${partes[0]} ${partes[1]}".toUpperCase()
                        : partes[0].toUpperCase();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        nomeExibicao,
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: isToday
                              ? const Color(0xFF0C4A6E)
                              : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  void _mostrarDetalhesDia(
      DateTime date, List<Map<String, dynamic>> defesasDia) {
    // Ordenar por hora
    defesasDia.sort((a, b) => (a['hora']?.toString() ?? '99:99')
        .compareTo(b['hora']?.toString() ?? '99:99'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
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
                const Icon(Icons.event_note_rounded, color: Color(0xFF0284C7)),
                const SizedBox(width: 12),
                Text(
                    DateFormat("dd 'de' MMMM", 'pt_BR')
                        .format(date)
                        .toUpperCase(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0C4A6E))),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: defesasDia.length,
                itemBuilder: (context, index) {
                  final d = defesasDia[index];
                  return _buildDefesaDetailCard(d);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefesaDetailCard(Map<String, dynamic> d) {
    final hora = _formatarHora(d['hora']);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFF0C4A6E),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(hora.isEmpty ? "--:--" : hora,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 12),
          Text(d['discente'] ?? "Discente",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(d['titulo'] ?? "Sem título",
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Expanded(
                  child: Text("Orientador: ${d['orientador']}",
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569)))),
            ],
          ),
          if (d['avaliador1'] != null &&
              d['avaliador1'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text("Avaliador 1: ${d['avaliador1']}",
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF475569)))),
              ],
            ),
          ],
          if (d['avaliador2'] != null &&
              d['avaliador2'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text("Avaliador 2: ${d['avaliador2']}",
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF475569)))),
              ],
            ),
          ],
          if (d['avaliador3'] != null &&
              d['avaliador3'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text("Avaliador 3: ${d['avaliador3']}",
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF475569)))),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(d['local'] ?? "Local não informado",
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PENDÊNCIAS",
                    style: TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
                Text("Defesas sem Data",
                    style: TextStyle(
                        color: Color(0xFF0C4A6E),
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Column(
                  children: [
                    Divider(height: 1, thickness: 1, color: Color(0xFF0C4A6E)),
                    SizedBox(height: 2),
                    Divider(height: 1, thickness: 1, color: Color(0xFF0C4A6E)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: defesasSemData.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: defesasSemData.length,
                    itemBuilder: (context, index) =>
                        _buildSidebarCard(defesasSemData[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarCard(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d['discente'],
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF9A3412))),
          const SizedBox(height: 4),
          Text(d['orientador'] ?? "",
              style: const TextStyle(fontSize: 11, color: Color(0xFFC2410C))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 48, color: Colors.green.shade100),
          const SizedBox(height: 16),
          const Text("Não há pendências",
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showDefesasSemDataSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text("DEFESAS SEM DATA AGENDADA",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0C4A6E))),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: defesasSemData.length,
                itemBuilder: (context, index) =>
                    _buildSidebarCard(defesasSemData[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
