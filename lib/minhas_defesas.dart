// lib/minhas_defesas.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Para Clipboard

import 'pdf_generator.dart';
import 'ficha_avaliacao_generator.dart';
import 'notas_page.dart';
import 'cadastrar_defesa.dart';
import 'dados_defesa_final_page.dart';
import 'ficha_avaliacao_final_generator.dart';

class MinhasDefesasPage extends StatefulWidget {
  const MinhasDefesasPage({super.key});

  @override
  State<MinhasDefesasPage> createState() => _MinhasDefesasPageState();
}

class _MinhasDefesasPageState extends State<MinhasDefesasPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> defesas = [];
  List<Map<String, dynamic>> minhasDefesas = [];
  bool loading = true;
  bool mostrarFiltro2 = false;
  final filtroController1 = TextEditingController();
  final filtroController2 = TextEditingController();
  String filtroCampo1 = 'semestre';
  String filtroCampo2 = 'semestre';
  String? semestreMaisRecente;
  bool filtrosForamLimpos = false;
  String? meuNomeCompleto;

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
    _carregarMeuPerfil();
  }

  // Função para carregar o perfil do usuário atual
  Future<void> _carregarMeuPerfil() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('users_access')
            .select('full_name, nomecompleto')
            .eq('id', user.id)
            .single();

        if (response != null) {
          setState(() {
            // Prioriza nomecompleto, depois full_name
            meuNomeCompleto = response['nomecompleto'] ?? response['full_name'];
          });
        }
      }
    } catch (e) {
      print("Erro ao carregar perfil: $e");
    }

    // Carrega as defesas após obter o nome do usuário
    carregarDefesas();
  }

  // Função para encontrar o semestre mais recente
  String? _encontrarSemestreMaisRecente(List<Map<String, dynamic>> defesas) {
    final semestresUnicos = defesas
        .map((defesa) => defesa['semestre']?.toString() ?? '')
        .where((semestre) => semestre.isNotEmpty)
        .toSet()
        .toList();

    if (semestresUnicos.isEmpty) return null;

    // Ordena os semestres do mais recente para o mais antigo
    semestresUnicos.sort((a, b) {
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

    return semestresUnicos.first;
  }

  Future<void> carregarDefesas() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final response = await supabase
          .from('dados_defesas')
          .select()
          .order('dia', ascending: true);

      final defesasCarregadas =
          List<Map<String, dynamic>>.from(response as List);

      // Filtrar apenas as defesas em que o usuário participa
      final minhasDefesasCarregadas = defesasCarregadas.where((defesa) {
        if (meuNomeCompleto == null || meuNomeCompleto!.isEmpty) return false;
        final nome = meuNomeCompleto!.toLowerCase().trim();

        final check =
            (String? field) => field?.toLowerCase().contains(nome) ?? false;

        return check(defesa['orientador']) ||
            check(defesa['coorientador']) ||
            check(defesa['avaliador1']) ||
            check(defesa['avaliador2']) ||
            check(defesa['avaliador3']);
      }).toList();

      if (mounted) {
        setState(() {
          defesas = defesasCarregadas;
          minhasDefesas = minhasDefesasCarregadas;
          semestreMaisRecente =
              _encontrarSemestreMaisRecente(minhasDefesasCarregadas);

          // Filtro inicial pelo semestre mais recente
          if (semestreMaisRecente != null && !filtrosForamLimpos) {
            filtroController1.text = semestreMaisRecente!;
            minhasDefesas = minhasDefesasCarregadas
                .where((d) => d['semestre'] == semestreMaisRecente)
                .toList();
          }

          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
      debugPrint("Erro ao carregar defesas: $e");
    }
  }

  void atualizarFiltroLocal() {
    if (defesas.isEmpty) return;

    setState(() {
      minhasDefesas = defesas.where((defesa) {
        // Primeiro filtro: participação do usuário
        if (meuNomeCompleto == null || meuNomeCompleto!.isEmpty) return false;
        final meuNome = meuNomeCompleto!.toLowerCase().trim();
        final checkPart =
            (String? field) => field?.toLowerCase().contains(meuNome) ?? false;

        bool participa = checkPart(defesa['orientador']) ||
            checkPart(defesa['coorientador']) ||
            checkPart(defesa['avaliador1']) ||
            checkPart(defesa['avaliador2']) ||
            checkPart(defesa['avaliador3']);

        if (!participa) return false;

        // Segundo filtro: Campo de pesquisa 1
        if (filtroController1.text.isNotEmpty) {
          final valor = filtroController1.text.toLowerCase();
          final campo = filtroCampo1;
          final valorCampo = defesa[campo]?.toString().toLowerCase() ?? '';
          if (!valorCampo.contains(valor)) return false;
        }

        // Terceiro filtro: Campo de pesquisa 2 (se ativo)
        if (mostrarFiltro2 && filtroController2.text.isNotEmpty) {
          final valor = filtroController2.text.toLowerCase();
          final campo = filtroCampo2;
          final valorCampo = defesa[campo]?.toString().toLowerCase() ?? '';
          if (!valorCampo.contains(valor)) return false;
        }

        return true;
      }).toList();
    });
  }

  void aplicarFiltro(int numeroFiltro) async {
    final campo = numeroFiltro == 1 ? filtroCampo1 : filtroCampo2;
    final controller =
        numeroFiltro == 1 ? filtroController1 : filtroController2;

    if (campo == 'dia') {
      DateTime? dataSelecionada = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

      if (dataSelecionada != null) {
        controller.text = DateFormat('yyyy-MM-dd').format(dataSelecionada);
        atualizarFiltroLocal();
      }
    } else {
      atualizarFiltroLocal();
    }
  }

  void limparFiltros() {
    filtroController1.clear();
    filtroController2.clear();
    setState(() {
      mostrarFiltro2 = false;
      filtrosForamLimpos = true;
    });
    atualizarFiltroLocal();
  }

  void toggleFiltro2() {
    setState(() {
      mostrarFiltro2 = !mostrarFiltro2;
      if (!mostrarFiltro2) {
        filtroController2.clear();
      }
    });
    atualizarFiltroLocal();
  }

  // Função para editar defesa
  void _editarDefesa(Map<String, dynamic> defesa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CadastrarDefesaPage(defesaExistente: defesa),
      ),
    ).then((_) {
      carregarDefesas();
    });
  }

  // Função para abrir página de dados finais da defesa
  void _abrirDadosDefesaFinal(Map<String, dynamic> defesa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DadosDefesaFinalPage(
          defesaId: defesa['id'] ?? 0,
          defesa: defesa,
        ),
      ),
    ).then((_) {
      carregarDefesas();
    });
  }

  // Função para copiar credenciais
  void _copiarCredenciais(Map<String, dynamic> defesa) {
    final login = defesa['login'] ?? '';
    final senha = defesa['senha'] ?? '';

    if (login.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciais não disponíveis')),
      );
      return;
    }

    final credenciais = 'Login: $login\nSenha: $senha';
    Clipboard.setData(ClipboardData(text: credenciais));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Credenciais copiadas para a área de transferência!')),
    );
  }

  // Função para abrir página de notas
  void _abrirPaginaNotas(Map<String, dynamic> defesa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotasPage(
          defesaId: defesa['id'] ?? 0,
          defesa: defesa,
        ),
      ),
    );
  }

  // Função para mostrar popup de seleção de avaliadores para fichas individuais
  Future<void> _mostrarSelecaoAvaliadoresFichas(
      Map<String, dynamic> defesa) async {
    final avaliadoresDisponiveis = <Map<String, dynamic>>[];

    if (defesa['avaliador1'] != null &&
        defesa['avaliador1'].toString().isNotEmpty) {
      avaliadoresDisponiveis.add({
        'numero': 1,
        'nome': defesa['avaliador1'],
        'instituto': defesa['instituto_av1'] ?? ''
      });
    }

    if (defesa['avaliador2'] != null &&
        defesa['avaliador2'].toString().isNotEmpty) {
      avaliadoresDisponiveis.add({
        'numero': 2,
        'nome': defesa['avaliador2'],
        'instituto': defesa['instituto_av2'] ?? ''
      });
    }

    if (defesa['avaliador3'] != null &&
        defesa['avaliador3'].toString().isNotEmpty) {
      avaliadoresDisponiveis.add({
        'numero': 3,
        'nome': defesa['avaliador3'],
        'instituto': defesa['instituto_av3'] ?? ''
      });
    }

    if (avaliadoresDisponiveis.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nenhum avaliador cadastrado para esta defesa')),
        );
      }
      return;
    }

    // Criar uma cópia mutável para as seleções
    final selecoes = <int, bool>{};
    for (var avaliador in avaliadoresDisponiveis) {
      selecoes[avaliador['numero']] = false;
    }

    // Usar StatefulBuilder para gerenciar o estado corretamente
    if (!mounted) return;
    final selecionados = await showDialog<List<int>>(
      context: context,
      barrierDismissible: false, // Força o uso dos botões sugeridos
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0C4A6E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Text(
                  'Selecionar Avaliadores',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Escolha os membros para gerar as fichas:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ...avaliadoresDisponiveis.map((avaliador) {
                      final num = avaliador['numero'] as int;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: (selecoes[num] ?? false)
                              ? const Color(0xFFF0F9FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (selecoes[num] ?? false)
                                ? const Color(0xFF0284C7)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          activeColor: const Color(0xFF0284C7),
                          title: Text(
                            avaliador['nome'],
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          subtitle: avaliador['instituto'].toString().isNotEmpty
                              ? Text(
                                  avaliador['instituto'],
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          value: selecoes[num] ?? false,
                          onChanged: (value) {
                            setStateDialog(() {
                              selecoes[num] = value!;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, null),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancelar',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final result = selecoes.entries
                              .where((entry) => entry.value)
                              .map((entry) => entry.key)
                              .toList();

                          if (result.isEmpty) {
                            ScaffoldMessenger.of(stateContext).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Selecione pelo menos um avaliador'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, result);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Gerar Fichas',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (selecionados != null && selecionados.isNotEmpty) {
      try {
        await FichaAvaliacaoGenerator.generateFichasAvaliacaoSelecionadas(
            defesa, selecionados);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${selecionados.length} ficha(s) de avaliação gerada(s) com sucesso!',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erro ao gerar fichas individuais: $e"),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // Função para determinar o papel do usuário na defesa
  String _determinarMeuPapel(Map<String, dynamic> defesa) {
    if (meuNomeCompleto == null) return '';

    final meuNome = meuNomeCompleto!.toLowerCase().trim();
    final papeis = <String>[];

    if (defesa['orientador'] != null &&
        defesa['orientador']
            .toString()
            .toLowerCase()
            .trim()
            .contains(meuNome)) {
      papeis.add('Orientador');
    }

    if (defesa['coorientador'] != null &&
        defesa['coorientador']
            .toString()
            .toLowerCase()
            .trim()
            .contains(meuNome)) {
      papeis.add('Coorientador');
    }

    if (defesa['avaliador1'] != null &&
        defesa['avaliador1']
            .toString()
            .toLowerCase()
            .trim()
            .contains(meuNome)) {
      papeis.add('Avaliador 1');
    }

    if (defesa['avaliador2'] != null &&
        defesa['avaliador2']
            .toString()
            .toLowerCase()
            .trim()
            .contains(meuNome)) {
      papeis.add('Avaliador 2');
    }

    if (defesa['avaliador3'] != null &&
        defesa['avaliador3']
            .toString()
            .toLowerCase()
            .trim()
            .contains(meuNome)) {
      papeis.add('Avaliador 3');
    }

    return papeis.join(', ');
  }

  void _mostrarDetalhesDefesa(Map<String, dynamic> defesa, String dia) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text("DETALHES DA BANCA",
                      style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            defesa['discente']?.toString().toUpperCase() ??
                                'DISCENTE',
                            style: const TextStyle(
                                color: Color(0xFF0C4A6E),
                                fontSize: 24,
                                fontWeight: FontWeight.w900)),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _editarDefesa(defesa);
                        },
                        icon: const Icon(Icons.edit_document,
                            color: Color(0xFF0284C7)),
                        tooltip: "Editar Informações",
                      ),
                      IconButton(
                        onPressed: () => _copiarCredenciais(defesa),
                        icon: const Icon(Icons.vpn_key_rounded,
                            color: Color(0xFF0284C7)),
                        tooltip: "Copiar Credenciais",
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildModalInfoItem(Icons.title, "Título do Trabalho",
                      defesa['titulo'] ?? 'Não informado'),
                  _buildModalInfoItem(Icons.calendar_today, "Data e Horário",
                      "$dia às ${_formatarHora(defesa['hora'])}"),
                  _buildModalInfoItem(Icons.location_on, "Local/Link",
                      defesa['local'] ?? 'Não informado'),
                  const Divider(height: 48),
                  Text("MEMBROS DA BANCA",
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  _buildMemberTile("Orientador", defesa['orientador']),
                  if (defesa['coorientador'] != null)
                    _buildMemberTile("Coorientador", defesa['coorientador']),
                  _buildMemberTile("Avaliador 1", defesa['avaliador1']),
                  _buildMemberTile("Avaliador 2", defesa['avaliador2']),
                  if (defesa['avaliador3'] != null)
                    _buildMemberTile("Avaliador 3", defesa['avaliador3']),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMenuAction(
                          Icons.edit_note_rounded,
                          "Notas",
                          () => _abrirPaginaNotas(defesa),
                          const Color(0xFF0284C7)),
                      _buildMenuAction(
                          Icons.description_rounded,
                          "ATA",
                          () => PdfGenerator.generateAtaDefesa(defesa),
                          const Color(0xFF0C4A6E)),
                      _buildMenuAction(Icons.assignment_ind_rounded, "Fichas",
                          () {
                        Navigator.pop(
                            context); // Fecha o modal de detalhes primeiro
                        _mostrarSelecaoAvaliadoresFichas(defesa);
                      }, const Color(0xFF0284C7)),
                      _buildMenuAction(
                          Icons.check_circle_rounded,
                          "Aprovação",
                          () => PdfGenerator.generateFolhaAprovacao(defesa),
                          const Color(0xFF10B981)),
                      _buildMenuAction(
                          Icons.grading_rounded,
                          "Ficha Final",
                          () => FichaAvaliacaoFinalGenerator
                              .generateFichaAvaliacaoFinal(defesa),
                          const Color(0xFFF59E0B)),
                      _buildMenuAction(
                          Icons.playlist_add_check_rounded, "Dados Finais", () {
                        Navigator.pop(context);
                        _abrirDadosDefesaFinal(defesa);
                      }, const Color(0xFF6366F1)),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0284C7)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(String role, String? name) {
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: const Color(0xFFE0F2FE),
                radius: 14,
                child: Text(role[0],
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7)))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role,
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                  Text(name,
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuAction(
      IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  String _formatarNomeCampo(String campo) {
    final map = {
      'semestre': 'Semestre',
      'dia': 'Data',
      'discente': 'Discente',
      'orientador': 'Orientador',
      'coorientador': 'Coorientador',
      'avaliador1': 'Avaliador 1',
      'avaliador2': 'Avaliador 2',
      'avaliador3': 'Avaliador 3',
      'titulo': 'Título',
      'local': 'Local',
    };
    return map[campo] ?? campo;
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Header Moderno
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
                          Text("GESTÃO DE DEFESAS",
                              style: TextStyle(
                                  color: Color(0xFF7DD3FC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5)),
                          Text("Minhas Bancas",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Área de Filtros
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                children: [
                  _buildFiltrosBar(isLargeScreen),
                ],
              ),
            ),
          ),

          // Lista de Defesas
          if (loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0284C7))),
            )
          else if (minhasDefesas.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("Nenhuma banca encontrada",
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLargeScreen ? 2 : 1,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 180,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => cardDefesa(minhasDefesas[index]),
                  childCount: min(minhasDefesas.length,
                      minhasDefesas.length), // Fix to avoid potential issues
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildFiltrosBar(bool isLargeScreen) {
    return Container(
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
      child: Column(
        children: [
          Row(
            children: [
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
                      value: filtroCampo1,
                      isExpanded: true,
                      items: camposFiltro
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text(_formatarNomeCampo(c))))
                          .toList(),
                      onChanged: (val) => setState(() => filtroCampo1 = val!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: filtroController1,
                  onChanged: (_) => atualizarFiltroLocal(),
                  decoration: InputDecoration(
                    hintText: "Pesquisar...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              if (filtroController1.text.isNotEmpty)
                IconButton(
                    onPressed: _limparCampoPesquisa1,
                    icon: const Icon(Icons.clear)),
            ],
          ),
          if (mostrarFiltro2) ...[
            const SizedBox(height: 12),
            Row(
              children: [
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
                        value: filtroCampo2,
                        isExpanded: true,
                        items: camposFiltro
                            .map((c) => DropdownMenuItem(
                                value: c, child: Text(_formatarNomeCampo(c))))
                            .toList(),
                        onChanged: (val) => setState(() => filtroCampo2 = val!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: filtroController2,
                    onChanged: (_) => atualizarFiltroLocal(),
                    decoration: InputDecoration(
                      hintText: "Refinar busca...",
                      prefixIcon:
                          const Icon(Icons.filter_list_rounded, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: toggleFiltro2,
                icon: Icon(
                    mostrarFiltro2
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline,
                    size: 18),
                label: Text(mostrarFiltro2 ? "Menos filtros" : "Mais filtros"),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: limparFiltros,
                icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                label: const Text("Limpar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF475569),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _limparCampoPesquisa1() {
    filtroController1.clear();
    filtrosForamLimpos = true;
    atualizarFiltroLocal();
  }

  Widget cardDefesa(Map<String, dynamic> defesa) {
    final dia = defesa['dia'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(defesa['dia']))
        : '--/--/----';
    final meuPapel = _determinarMeuPapel(defesa);

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _mostrarDetalhesDefesa(defesa, dia),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(dia,
                          style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                    if (meuPapel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(meuPapel,
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(defesa['discente']?.toString().toUpperCase() ?? 'DISCENTE',
                    style: const TextStyle(
                        color: Color(0xFF0C4A6E),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(defesa['titulo'] ?? 'Sem título cadastrado',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.person_pin_rounded,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text("Orientador: ${defesa['orientador']}",
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.w600))),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: Color(0xFFCBD5E1)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  int min(int a, int b) => a < b ? a : b;
}
