// lib/cadastrar_defesa.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class CadastrarDefesaPage extends StatefulWidget {
  final Map<String, dynamic>? defesaExistente;

  const CadastrarDefesaPage({super.key, this.defesaExistente});

  @override
  State<CadastrarDefesaPage> createState() => _CadastrarDefesaPageState();
}

class _CadastrarDefesaPageState extends State<CadastrarDefesaPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final semestreController = TextEditingController();
  DateTime? dia;
  TimeOfDay? hora;
  final discenteController = TextEditingController();
  final matriculaController = TextEditingController();
  final orientadorController = TextEditingController();
  final coorientadorController = TextEditingController();
  final avaliador1Controller = TextEditingController();
  final institutoAv1Controller = TextEditingController();
  final avaliador2Controller = TextEditingController();
  final institutoAv2Controller = TextEditingController();
  final avaliador3Controller = TextEditingController();
  final institutoAv3Controller = TextEditingController();
  final tituloController = TextEditingController();
  final localController = TextEditingController();

  String? loginGerado;
  String? senhaGerada;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.defesaExistente != null) {
      _preencherCamposComDefesaExistente();
    } else {
      _gerarCredenciais();
    }
  }

  void _preencherCamposComDefesaExistente() {
    final defesa = widget.defesaExistente!;
    semestreController.text = defesa['semestre'] ?? '';
    if (defesa['dia'] != null) dia = DateTime.parse(defesa['dia']);
    if (defesa['hora'] != null) {
      final parts = defesa['hora'].toString().split(':');
      hora = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    discenteController.text = defesa['discente'] ?? '';
    matriculaController.text = defesa['matricula']?.toString() ?? '';
    orientadorController.text = defesa['orientador'] ?? '';
    coorientadorController.text = defesa['coorientador'] ?? '';
    avaliador1Controller.text = defesa['avaliador1'] ?? '';
    institutoAv1Controller.text = defesa['instituto_av1'] ?? '';
    avaliador2Controller.text = defesa['avaliador2'] ?? '';
    institutoAv2Controller.text = defesa['instituto_av2'] ?? '';
    avaliador3Controller.text = defesa['avaliador3'] ?? '';
    institutoAv3Controller.text = defesa['instituto_av3'] ?? '';
    tituloController.text = defesa['titulo'] ?? '';
    localController.text = defesa['local'] ?? '';
    loginGerado = defesa['login'];
    senhaGerada = defesa['senha'];
  }

  String _gerarStringAleatoria(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _gerarCredenciais() async {
    String novoLogin;
    String novaSenha;
    bool loginExiste;
    do {
      novoLogin = _gerarStringAleatoria(6);
      novaSenha = _gerarStringAleatoria(6);
      final response = await supabase
          .from('dados_defesas')
          .select('login')
          .eq('login', novoLogin);
      loginExiste = response.isNotEmpty;
    } while (loginExiste);
    setState(() {
      loginGerado = novoLogin;
      senhaGerada = novaSenha;
    });
  }

  String _removerPrefixos(String nomeCompleto) {
    final prefixos = [
      'Prof. Dr. ',
      'Prof. Dra. ',
      'Prof. Me. ',
      'Prof. Ma. ',
      'Profa. Dra. ',
      'Profa. Dr. ',
      'Profa. Me. ',
      'Profa. Ma. ',
      'Prof. ',
      'Profa. ',
      'Dr. ',
      'Dra. ',
      'Me. ',
      'Ma. '
    ];
    String nomeLimpo = nomeCompleto;
    for (String prefixo in prefixos) {
      if (nomeLimpo.startsWith(prefixo)) {
        nomeLimpo = nomeLimpo.substring(prefixo.length).trim();
        break;
      }
    }
    return nomeLimpo.trim();
  }

  Future<List<Map<String, dynamic>>> _buscarDocentes() async {
    try {
      final response = await supabase
          .from('diversos')
          .select('item, descricao')
          .eq('descricao', 'docente');
      final list = <Map<String, dynamic>>[];
      for (var item in response) {
        if (item['item'] != null && item['item'].toString().isNotEmpty) {
          final nomeCompleto = item['item'];
          list.add({
            'nome': nomeCompleto,
            'nome_limpo': _removerPrefixos(nomeCompleto)
          });
        }
      }
      list.sort((a, b) => a['nome_limpo'].compareTo(b['nome_limpo']));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _obterSugestoesSemestre() async {
    final agora = DateTime.now();
    final anoAtual = agora.year;
    final mesAtual = agora.month;

    // Semestre atual
    final semAtual = mesAtual <= 6 ? 1 : 2;
    final semestre1 = "$anoAtual.$semAtual";

    // Próximo semestre
    int anoProx = anoAtual;
    int semProx = semAtual + 1;
    if (semProx > 2) {
      semProx = 1;
      anoProx++;
    }
    final semestre2 = "$anoProx.$semProx";

    return [
      {'nome': semestre1},
      {'nome': semestre2},
    ];
  }

  Future<List<Map<String, dynamic>>> _buscarInstituicoes() async {
    try {
      final response = await supabase
          .from('diversos')
          .select('item, descricao')
          .eq('descricao', 'instituicao');
      final list = <Map<String, dynamic>>[];
      for (var item in response) {
        if (item['item'] != null && item['item'].toString().isNotEmpty) {
          list.add({'nome': item['item']});
        }
      }
      list.sort((a, b) => a['nome'].compareTo(b['nome']));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<void> _mostrarSelecao({
    required String titulo,
    required Future<List<Map<String, dynamic>>> Function() buscarDados,
    required Function(String) onSelecionar,
    String tipo = 'docente',
  }) async {
    final dados = await buscarDados();
    if (dados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum dado encontrado')));
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(tipo == 'docente' ? Icons.person : Icons.business,
                color: const Color(0xFF0C4A6E)),
            const SizedBox(width: 12),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0C4A6E))),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 500,
          child: ListView.builder(
            itemCount: dados.length,
            itemBuilder: (context, index) {
              final item = dados[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: index.isEven ? Colors.white : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(item['nome'],
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: Color(0xFF0C4A6E), size: 20),
                  onTap: () {
                    Navigator.pop(context);
                    onSelecionar(item['nome']);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> salvarDefesa() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dados = {
        'semestre': semestreController.text,
        'dia': dia != null ? DateFormat('yyyy-MM-dd').format(dia!) : null,
        'hora': hora != null
            ? '${hora!.hour.toString().padLeft(2, '0')}:${hora!.minute.toString().padLeft(2, '0')}'
            : null,
        'discente': discenteController.text,
        'matricula': int.tryParse(matriculaController.text),
        'orientador': orientadorController.text,
        'coorientador': coorientadorController.text.isNotEmpty
            ? coorientadorController.text
            : null,
        'avaliador1': avaliador1Controller.text.isNotEmpty
            ? avaliador1Controller.text
            : null,
        'instituto_av1': institutoAv1Controller.text.isNotEmpty
            ? institutoAv1Controller.text
            : null,
        'avaliador2': avaliador2Controller.text.isNotEmpty
            ? avaliador2Controller.text
            : null,
        'instituto_av2': institutoAv2Controller.text.isNotEmpty
            ? institutoAv2Controller.text
            : null,
        'avaliador3': avaliador3Controller.text.isNotEmpty
            ? avaliador3Controller.text
            : null,
        'instituto_av3': institutoAv3Controller.text.isNotEmpty
            ? institutoAv3Controller.text
            : null,
        'titulo': tituloController.text,
        'local': localController.text.isNotEmpty ? localController.text : null,
        'login': loginGerado,
        'senha': senhaGerada,
      };

      if (widget.defesaExistente != null) {
        await supabase
            .from('dados_defesas')
            .update(dados)
            .eq('id', widget.defesaExistente!['id']);
        _mostrarSucesso("Defesa atualizada com sucesso!");
      } else {
        await supabase.from('dados_defesas').insert(dados);
        _mostrarSucesso("Defesa cadastrada com sucesso!");
      }
      Navigator.pop(context);
    } catch (e) {
      _mostrarErro("Erro ao salvar: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarSucesso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating));
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final isEditando = widget.defesaExistente != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          // Bento Header
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("GESTÃO DE DEFESAS",
                              style: TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0)),
                          Text(
                              isEditando
                                  ? "Editar Registro"
                                  : "Cadastrar Nova Defesa",
                              style: const TextStyle(
                                  color: Color(0xFF0C4A6E),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.all(isLargeScreen ? 32 : 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status / Credentials Card
                      _buildInfoCard(isEditando),
                      const SizedBox(height: 24),

                      _buildSectionTitle(
                          "INFORMAÇÕES BÁSICAS", Icons.info_outline),
                      _buildBentoRow([
                        Expanded(
                            child: _buildSelectField(
                                semestreController,
                                "Semestre Letivo *",
                                Icons.school_outlined,
                                'semestre',
                                "Selecionar Semestre",
                                true)),
                      ]),
                      _buildBentoRow([
                        Expanded(flex: 1, child: _buildDatePicker()),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: _buildTimePicker()),
                      ]),
                      _buildTextField(
                          localController,
                          "Local ou Link da Defesa",
                          Icons.location_on_outlined),

                      const SizedBox(height: 24),
                      _buildSectionTitle(
                          "DADOS DO DISCENTE", Icons.person_outline),
                      _buildTextField(
                          discenteController, "Nome do Aluno *", Icons.person,
                          obrigatorio: true),
                      _buildTextField(matriculaController, "Matrícula",
                          Icons.badge_outlined,
                          isNum: true),

                      const SizedBox(height: 24),
                      _buildSectionTitle(
                          "ORIENTAÇÃO", Icons.supervisor_account_outlined),
                      _buildSelectField(
                          orientadorController,
                          "Orientador *",
                          Icons.supervisor_account,
                          'docente',
                          "Selecionar Orientador",
                          true),
                      const SizedBox(height: 12),
                      _buildSelectField(
                          coorientadorController,
                          "Coorientador",
                          Icons.person_add_alt_1_outlined,
                          'docente',
                          "Selecionar Coorientador",
                          false),

                      const SizedBox(height: 24),
                      _buildSectionTitle(
                          "BANCA EXAMINADORA", Icons.groups_outlined),
                      _buildAvaliadorPair(
                          1, avaliador1Controller, institutoAv1Controller),
                      const SizedBox(height: 16),
                      _buildAvaliadorPair(
                          2, avaliador2Controller, institutoAv2Controller),
                      const SizedBox(height: 16),
                      _buildAvaliadorPair(
                          3, avaliador3Controller, institutoAv3Controller),

                      const SizedBox(height: 24),
                      _buildSectionTitle(
                          "TRABALHO FINAL", Icons.menu_book_outlined),
                      _buildTextField(tituloController,
                          "Título da Tese/Trabalho *", Icons.title_rounded,
                          obrigatorio: true, maxLines: 3),

                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _isLoading ? null : salvarDefesa,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C4A6E),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: const Color(0xFF0C4A6E).withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(
                                isEditando
                                    ? "ATUALIZAR DADOS"
                                    : "FINALIZAR CADASTRO",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isEditando) {
    if (isEditando) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100)),
        child: Row(
          children: [
            const Icon(Icons.edit_note, color: Colors.blue),
            const SizedBox(width: 12),
            const Text("Você está editando um registro existente.",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("CREDENCIAIS DE ACESSO",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.green,
                      letterSpacing: 1)),
              IconButton(
                icon: const Icon(Icons.copy_all_rounded,
                    color: Colors.green, size: 20),
                onPressed: () {
                  final texto =
                      "Dados de acesso para a defesa:\nLogin: $loginGerado\nSenha: $senhaGerada";
                  Clipboard.setData(ClipboardData(text: texto));
                  _mostrarSucesso("Copiado para a área de transferência!");
                },
                tooltip: "Copiar credenciais",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Importante: Estes dados devem ser enviados aos avaliadores externos para acesso ao sistema.",
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF065F46),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCredItem("LOGIN", loginGerado ?? "..."),
              const SizedBox(width: 48),
              _buildCredItem("SENHA", senhaGerada ?? "..."),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCredItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
        Text(val,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF065F46))),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0284C7)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildBentoRow(List<Widget> children) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: children));
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool obrigatorio = false, bool isNum = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNum
            ? TextInputType.number
            : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF0C4A6E)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: obrigatorio
            ? (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null
            : null,
      ),
    );
  }

  Widget _buildSelectField(TextEditingController ctrl, String label,
      IconData icon, String tipo, String titulo, bool obrigatorio) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF0C4A6E)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7)),
            onPressed: () => _mostrarSelecao(
                titulo: titulo,
                buscarDados: () async {
                  if (tipo == 'docente') return _buscarDocentes();
                  if (tipo == 'instituicao') return _buscarInstituicoes();
                  if (tipo == 'semestre') return _obterSugestoesSemestre();
                  return [];
                },
                onSelecionar: (v) => setState(() => ctrl.text = v),
                tipo: tipo),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: obrigatorio
            ? (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null
            : null,
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: dia ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100));
        if (d != null) setState(() => dia = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            const Icon(Icons.calendar_month,
                size: 20, color: Color(0xFF0C4A6E)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("DATA DA DEFESA",
                    style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold)),
                Text(
                    dia != null
                        ? DateFormat('dd/MM/yyyy').format(dia!)
                        : "Selecionar",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(
            context: context, initialTime: hora ?? TimeOfDay.now());
        if (t != null) setState(() => hora = t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            const Icon(Icons.access_time_filled,
                size: 20, color: Color(0xFF0C4A6E)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("HORA INÍCIO",
                    style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold)),
                Text(hora != null ? hora!.format(context) : "Selecionar",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvaliadorPair(
      int num, TextEditingController cNome, TextEditingController cInst) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _buildSelectField(
              cNome,
              "Nome do Avaliador $num",
              Icons.person_outline,
              'docente',
              "Selecionar Avaliador $num",
              false),
          _buildSelectField(
              cInst,
              "Instituição do Avaliador $num",
              Icons.business_outlined,
              'instituicao',
              "Selecionar Instituição",
              false),
        ],
      ),
    );
  }
}
