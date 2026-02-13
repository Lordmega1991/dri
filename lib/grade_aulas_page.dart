import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grade_pdf_helper.dart';
import 'grade/widgets/dialog_lancamento_grade.dart';

class GradeAulasPage extends StatefulWidget {
  const GradeAulasPage({super.key});

  @override
  State<GradeAulasPage> createState() => _GradeAulasPageState();
}

class _GradeAulasPageState extends State<GradeAulasPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  final List<String> diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  final List<String> turnos = ['Manhã', 'Tarde', 'Noite'];

  final Map<String, int> totalHorarios = {
    'Manhã': 6,
    'Tarde': 6,
    'Noite': 4,
  };

  final Map<String, List<String>> horariosPorTurno = {
    'Manhã': [
      '07h às 08h',
      '08h às 09h',
      '09h às 10h',
      '10h às 11h',
      '11h às 12h',
      '12h às 13h'
    ],
    'Tarde': [
      '13h às 14h',
      '14h às 15h',
      '15h às 16h',
      '16h às 17h',
      '17h às 18h',
      '18h às 19h'
    ],
    'Noite': [
      '19h às 19h50',
      '19h50 às 20h40',
      '20h40 às 21h30',
      '21h30 às 22h20'
    ],
  };

  Map<String, List<Map<String, dynamic>>> grade = {};
  List<Map<String, dynamic>> professores = [];
  List<Map<String, dynamic>> disciplinas = [];
  List<Map<String, dynamic>> atividadesAdministrativas = [];
  List<Map<String, dynamic>> semestres = [];
  String semestreAtual = '';
  Map<String, num> cargaHorariaProfessores = {};
  // OTIMIZAÇÃO: Cache da lista ordenada para a sidebar
  List<MapEntry<String, num>> _professoresOrdenados = [];
  Map<String, List<Map<String, dynamic>>> detalhesProfessores = {};
  Map<String, List<Map<String, dynamic>>> horariosProfessores = {};

  // Variáveis para controle de loading
  bool _isLoading = true;
  bool _isLoadingSemestre = false;

  // Variável para armazenar o nível de acesso do usuário
  int _userAccessLevel = 1;
  bool _isLoadingUserAccess = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Método para inicializar todos os dados
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Primeiro carrega o nível de acesso do usuário
      await _carregarDadosUsuario();

      // Depois carrega os dados básicos
      await Future.wait([
        _loadProfessores(),
        _loadDisciplinas(),
        _loadSemestres(),
      ]);

      // Depois carrega a grade do semestre atual
      if (semestreAtual.isNotEmpty) {
        await _loadGrade();
      }
    } catch (e) {
      print('Erro ao inicializar dados: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Carrega os dados do usuário
  Future<void> _carregarDadosUsuario() async {
    try {
      // Obtém o usuário atual
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Busca o nível de acesso do usuário
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
        setState(() {
          _isLoadingUserAccess = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar dados do usuário: $e');
      setState(() {
        _isLoadingUserAccess = false;
      });
    }
  }

  // Verifica se o usuário tem permissão para adicionar/editar/excluir
  bool _usuarioPodeEditar() {
    return _userAccessLevel == 5;
  }

  // Verifica se o usuário pode pelo menos gerar PDF (incluindo nível 3)
  bool _podeGerarPDF() {
    return _userAccessLevel >= 3;
  }

  // Função para mostrar mensagem de acesso negado
  void _mostrarMensagemAcessoNegado() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Você não tem permissão para executar esta ação',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Método para recarregar tudo quando o semestre muda
  Future<void> _onSemestreChanged(String novoSemestre) async {
    if (novoSemestre == semestreAtual) return;

    setState(() {
      _isLoadingSemestre = true;
      semestreAtual = novoSemestre;
    });

    try {
      await _loadGrade();
    } catch (e) {
      print('Erro ao carregar grade do semestre: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados do semestre: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingSemestre = false;
      });
    }
  }

  Future<void> _loadSemestres() async {
    try {
      final response = await supabase
          .from('semestres')
          .select('id, ano, semestre, data_inicio, data_fim')
          .order('ano', ascending: false)
          .order('semestre', ascending: false);

      setState(() {
        semestres = List<Map<String, dynamic>>.from(
          response.map((e) => {
                'id': e['id'],
                'ano': e['ano'],
                'semestre': e['semestre'],
                'data_inicio': e['data_inicio'],
                'data_fim': e['data_fim'],
                'display': '${e['ano']}.${e['semestre']}'
              }),
        );

        // Define o semestre mais recente como padrão apenas se não houver um já selecionado
        if (semestres.isNotEmpty && semestreAtual.isEmpty) {
          semestreAtual = semestres.first['display'];
        } else if (semestres.isNotEmpty &&
            !semestres.any((s) => s['display'] == semestreAtual)) {
          // Se o semestre atual não existe mais na lista, usa o mais recente
          semestreAtual = semestres.first['display'];
        } else if (semestres.isEmpty) {
          // Se não houver semestres cadastrados, usa o atual baseado na data
          final now = DateTime.now();
          final ano = now.year;
          final semestre = now.month <= 6 ? 1 : 2;
          semestreAtual = '$ano.$semestre';
        }
      });
    } catch (e) {
      print('Erro ao carregar semestres: $e');
      // Fallback para semestre atual baseado na data
      final now = DateTime.now();
      final ano = now.year;
      final semestre = now.month <= 6 ? 1 : 2;
      setState(() {
        semestreAtual = '$ano.$semestre';
      });
    }
  }

  Future<void> _loadProfessores() async {
    try {
      final response = await supabase
          .from('docentes')
          .select('id, nome, apelido')
          .eq('ativo', true);
      setState(() {
        professores = List<Map<String, dynamic>>.from(
          response.map((e) => {
                'id': e['id'],
                'nome': e['nome'].toString(),
                'apelido': e['apelido']?.toString() ?? e['nome'].toString()
              }),
        );
        professores
            .sort((a, b) => (a['apelido'] ?? '').compareTo(b['apelido'] ?? ''));
      });
    } catch (e) {
      print('Erro ao carregar professores: $e');
    }
  }

  Future<void> _loadDisciplinas() async {
    try {
      final response = await supabase
          .from('disciplinas')
          .select('id, nome, nome_extenso, periodo, turno, ppc');
      setState(() {
        disciplinas = List<Map<String, dynamic>>.from(
          response.map((e) => {
                'id': e['id'],
                'nome': e['nome'].toString(),
                'nome_extenso':
                    e['nome_extenso']?.toString() ?? e['nome'].toString(),
                'periodo': e['periodo']?.toString() ?? '',
                'turno': e['turno']?.toString() ?? '',
                'ppc': e['ppc']?.toString() ?? '',
              }),
        );
        disciplinas
            .sort((a, b) => (a['nome'] ?? '').compareTo(b['nome'] ?? ''));
      });
    } catch (e) {
      print('Erro ao carregar disciplinas: $e');
    }
  }

  Future<void> _loadAtividadesAdministrativasPorSemestre(
      String semestreSelecionado) async {
    try {
      // Encontra o ID do semestre selecionado
      final semestre = semestres.firstWhere(
        (s) => s['display'] == semestreSelecionado,
        orElse: () => {},
      );

      if (semestre.isEmpty) {
        setState(() {
          atividadesAdministrativas = [];
        });
        return;
      }

      final semestreId = semestre['id'];

      // Carrega atividades administrativas APROVADAS do semestre específico
      final response = await supabase.from('atividades_docentes').select('''
            id, 
            docente_id, 
            descricao, 
            quantidade, 
            data_inicio, 
            data_fim, 
            detalhes,
            tipo_atividade_id,
            tipos_atividade!inner(nome, categoria)
          ''').eq('status', 'aprovado').eq('semestre_id', semestreId);

      // Filtra apenas atividades da categoria administrativa
      final atividadesFiltradas = List<Map<String, dynamic>>.from(
        response.where((atividade) {
          final categoria =
              atividade['tipos_atividade']?['categoria']?.toString() ?? '';
          return categoria.toLowerCase() == 'administrativa';
        }).map((e) => {
              'id': e['id'],
              'docente_id': e['docente_id'],
              'descricao': e['descricao'].toString(),
              'quantidade': (e['quantidade'] ?? 0) as num,
              'data_inicio': e['data_inicio'],
              'data_fim': e['data_fim'],
              'detalhes': e['detalhes'] ?? {},
              'tipo_atividade': e['tipos_atividade']?['nome'] ?? '',
              'categoria': e['tipos_atividade']?['categoria'] ?? '',
            }),
      );

      setState(() {
        atividadesAdministrativas = atividadesFiltradas;
      });
    } catch (e) {
      print('Erro ao carregar atividades administrativas: $e');
      setState(() {
        atividadesAdministrativas = [];
      });
    }
  }

  Future<void> _loadGrade() async {
    if (semestreAtual.isEmpty) return;
    try {
      // Primeiro carrega as atividades administrativas do semestre atual
      await _loadAtividadesAdministrativasPorSemestre(semestreAtual);

      // 1. Carrega a GRADE (Essencial - Slots)
      final responseGrade = await supabase
          .from('grade_aulas')
          .select(
              'id, dia, turno, indice, disciplina_id, professores, semestre, disciplinas!inner(id, nome, nome_extenso, periodo, turno, ppc, ch_aula)')
          .eq('semestre', semestreAtual);

      // 2. Tenta carregar ALOCAÇÕES (Opcional - CH exata)
      // Se falhar (tabela não existe ou erro de FK), segue sem elas e usa fallback
      List<dynamic> responseAlocacoes = [];
      try {
        responseAlocacoes = await supabase
            .from('alocacoes_docentes')
            .select(
                'docente_id, disciplina_id, ch_alocada, disciplina:disciplinas!inner(id, nome, nome_extenso, periodo, turno, ppc)')
            .eq('semestre', semestreAtual);
      } catch (e) {
        debugPrint(
            'Aviso: Não foi possível carregar alocacoes_docentes. Usando cálculo por slots. Erro: $e');
      }

      // OTIMIZAÇÃO: Mapear professores por ID para busca O(1)
      final professoresMap = {for (var p in professores) p['id'].toString(): p};

      Map<String, List<Map<String, dynamic>>> temp = {};
      Map<String, num> cargaHorariaTemp = {};
      Map<String, List<Map<String, dynamic>>> detalhesTemp = {};
      Map<String, List<Map<String, dynamic>>> horariosTemp = {};

      // Mapa auxiliar para saber se a CH do professor/disciplina já foi processada via tabela nova
      // Chave: docenteId-disciplinaId
      final Set<String> chProcessadaViaAlocacao = {};

      // Processa as atividades administrativas dos professores
      Map<String, int> cargaHorariaAtividades = {};
      Map<String, List<Map<String, dynamic>>> atividadesPorProfessor = {};

      for (var atividade in atividadesAdministrativas) {
        final docenteId = atividade['docente_id'].toString();
        // Busca O(1)
        final professor = professoresMap[docenteId] ??
            {'apelido': 'Professor não encontrado'};
        final nomeProfessor = professor['apelido'];
        final descricao = atividade['descricao'] ?? 'Atividade Administrativa';
        final quantidadeNum = atividade['quantidade'] ?? 0;
        final quantidade =
            quantidadeNum is int ? quantidadeNum : quantidadeNum.toInt();

        // Inicializa carga horária se necessário
        cargaHorariaTemp.putIfAbsent(nomeProfessor, () => 0);
        cargaHorariaTemp[nomeProfessor] =
            (cargaHorariaTemp[nomeProfessor] ?? 0) + quantidade;

        cargaHorariaAtividades[nomeProfessor] =
            (cargaHorariaAtividades[nomeProfessor] ?? 0) + quantidade as int;

        if (!atividadesPorProfessor.containsKey(nomeProfessor)) {
          atividadesPorProfessor[nomeProfessor] = [];
        }
        atividadesPorProfessor[nomeProfessor]!.add({
          'tipo': 'atividade',
          'nome': descricao,
          'carga_horaria': quantidade,
          'semestre': semestreAtual,
        });
      }

      // A. Processa ALOCAÇÕES (Fonte da Verdade para CH NOVA)
      for (var alocacao in responseAlocacoes) {
        final docenteId = alocacao['docente_id'].toString();
        final professor = professoresMap[docenteId];

        if (professor != null) {
          final nomeProfessor = professor['apelido'];
          final chAlocada = (alocacao['ch_alocada'] ?? 0).toDouble() / 15.0;

          // Soma CH total
          cargaHorariaTemp.putIfAbsent(nomeProfessor, () => 0);
          cargaHorariaTemp[nomeProfessor] =
              (cargaHorariaTemp[nomeProfessor] ?? 0) + chAlocada;

          // Detalhes da disciplina para o relatório
          final Map<String, dynamic> discInfo =
              Map<String, dynamic>.from(alocacao['disciplina'] ?? {});
          final disciplinaId = discInfo['id'].toString();
          final disciplinaNome = discInfo['nome'] ?? 'Disciplina';
          final disciplinaNomeExtenso =
              discInfo['nome_extenso'] ?? disciplinaNome;
          final periodo = discInfo['periodo']?.toString() ?? '';
          final turnoDisc = discInfo['turno']?.toString() ?? '';
          final ppc = discInfo['ppc']?.toString() ?? '';

          // Marca como processada
          chProcessadaViaAlocacao.add('$docenteId-$disciplinaId');

          if (!detalhesTemp.containsKey(nomeProfessor)) {
            detalhesTemp[nomeProfessor] = [];
          }

          detalhesTemp[nomeProfessor]!.add({
            'tipo': 'disciplina',
            'nome': disciplinaNome,
            'nome_extenso': disciplinaNomeExtenso,
            'carga_horaria': chAlocada,
            'semestre': semestreAtual,
            'periodo': periodo,
            'turno': turnoDisc,
            'ppc': ppc,
          });
        }
      }

      // B. Processa GRADE (Visualização + Fallback de CH ANTIGA)
      for (var item in responseGrade) {
        final key = '${item['dia']}-${item['turno']}-${item['indice']}';

        // Extração robusta das informações da disciplina
        final dynamic joinedDisc = item['disciplinas'];
        // Conversão defensiva para Map<String, dynamic>
        final Map<String, dynamic> discInfo = Map<String, dynamic>.from(
            (joinedDisc is List && joinedDisc.isNotEmpty)
                ? joinedDisc[0]
                : (joinedDisc is Map ? joinedDisc : <String, dynamic>{}));

        final disciplinaId = item['disciplina_id'].toString();
        final disciplinaNome =
            discInfo['nome'] ?? 'Disciplina não especificada';
        final disciplinaNomeExtenso =
            discInfo['nome_extenso'] ?? disciplinaNome;
        final dia = item['dia'].toString();
        final turno = item['turno'].toString();
        final indice = item['indice'] as int;
        final semestre = item['semestre']?.toString() ?? '';
        final horarioCompleto = _getHorarioCompleto(turno, indice);

        final periodo = discInfo['periodo']?.toString() ?? '';
        final turnoDisc = discInfo['turno']?.toString() ?? '';
        final ppc = discInfo['ppc']?.toString() ?? '';

        List<String> nomesProfessores = [];
        if (item['professores'] != null &&
            (item['professores'] as List).isNotEmpty) {
          final professoresIds = (item['professores'] as List).cast<String>();

          for (var professorId in professoresIds) {
            final professor = professoresMap[professorId] ??
                {'apelido': 'Professor não encontrado'};
            final nomeProfessor = professor['apelido'];
            nomesProfessores.add(nomeProfessor);

            // Adiciona horário ao professor (Visualização)
            if (!horariosTemp.containsKey(nomeProfessor)) {
              horariosTemp[nomeProfessor] = [];
            }
            horariosTemp[nomeProfessor]!.add({
              'disciplina': disciplinaNome,
              'disciplina_extenso': disciplinaNomeExtenso,
              'dia': dia,
              'turno': turno,
              'horario': horarioCompleto,
              'indice': indice,
              'semestre': semestre,
            });

            // LÓGICA HÍBRIDA:
            // Se já processamos a CH desse professor/disciplina via tabela nova, NÃO faz nada.
            // Se NÃO processamos (dado antigo ou tabela nova vazia), CALCULAMOS via slots.
            if (!chProcessadaViaAlocacao
                .contains('$professorId-$disciplinaId')) {
              // Fallback: Cálculo por slot (1h / num_professores)
              final double pesoSlot = 1.0 / professoresIds.length;

              cargaHorariaTemp.putIfAbsent(nomeProfessor, () => 0);
              cargaHorariaTemp[nomeProfessor] =
                  (cargaHorariaTemp[nomeProfessor] ?? 0) + pesoSlot;

              // Adiciona ou atualiza detalhesTemp para dados antigos
              if (!detalhesTemp.containsKey(nomeProfessor)) {
                detalhesTemp[nomeProfessor] = [];
              }

              final disciplinaExistente =
                  detalhesTemp[nomeProfessor]!.firstWhere(
                (d) => d['nome'] == disciplinaNome && d['tipo'] == 'disciplina',
                orElse: () => {},
              );

              if (disciplinaExistente.isEmpty) {
                detalhesTemp[nomeProfessor]!.add({
                  'tipo': 'disciplina',
                  'nome': disciplinaNome,
                  'nome_extenso': disciplinaNomeExtenso,
                  'carga_horaria': pesoSlot,
                  'semestre': semestre,
                  'periodo': periodo,
                  'turno': turnoDisc,
                  'ppc': ppc,
                });
              } else {
                final index =
                    detalhesTemp[nomeProfessor]!.indexOf(disciplinaExistente);
                detalhesTemp[nomeProfessor]![index]['carga_horaria'] =
                    (detalhesTemp[nomeProfessor]![index]['carga_horaria']
                            as num) +
                        pesoSlot;
              }
            }
          }
        }

        if (!temp.containsKey(key)) {
          temp[key] = [];
        }

        temp[key]!.add({
          'id': item['id'],
          'disciplina_id': item['disciplina_id'],
          'disciplina_nome': disciplinaNome,
          'disciplina_nome_extenso': disciplinaNomeExtenso,
          'professores_ids': item['professores'] ?? [],
          'professores_nomes': nomesProfessores,
          'semestre': semestre,
          'periodo': periodo,
          'turno': turnoDisc,
          'ppc': ppc,
        });
      }

      // Combina carga horária
      Map<String, num> cargaHorariaCompleta = {};
      Map<String, List<Map<String, dynamic>>> detalhesCompletos = {};

      cargaHorariaAtividades.forEach((nomeProfessor, cargaAtividades) {
        final cargaAtual = cargaHorariaCompleta[nomeProfessor] ?? 0;
        cargaHorariaCompleta[nomeProfessor] = cargaAtual + cargaAtividades;

        if (!detalhesCompletos.containsKey(nomeProfessor)) {
          detalhesCompletos[nomeProfessor] = [];
        }
        detalhesCompletos[nomeProfessor]!
            .addAll(atividadesPorProfessor[nomeProfessor] ?? []);
      });

      cargaHorariaTemp.forEach((nomeProfessor, cargaAulas) {
        final cargaAtual = cargaHorariaCompleta[nomeProfessor] ?? 0;
        cargaHorariaCompleta[nomeProfessor] = cargaAtual + cargaAulas;

        if (!detalhesCompletos.containsKey(nomeProfessor)) {
          detalhesCompletos[nomeProfessor] = [];
        }
        detalhesCompletos[nomeProfessor]!
            .addAll(detalhesTemp[nomeProfessor] ?? []);
      });

      // OTIMIZAÇÃO: Ordernar lista de detalhes - JÁ feito aqui para evitar no build
      final listaOrdenada = cargaHorariaCompleta.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        grade = temp;
        cargaHorariaProfessores = cargaHorariaCompleta;
        _professoresOrdenados = listaOrdenada;
        detalhesProfessores = detalhesCompletos;
        horariosProfessores = horariosTemp;
      });
    } catch (e) {
      print('Erro ao carregar grade: $e');
      rethrow;
    }
  }

  // Método para recarregar todos os dados
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadProfessores(),
        _loadDisciplinas(),
        _loadSemestres(),
      ]);

      if (semestreAtual.isNotEmpty) {
        await _loadGrade();
      }
    } catch (e) {
      print('Erro ao recarregar dados: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // MÉTODO PARA MOSTRAR NOME DA DISCIPLINA NO DROPDOWN
  String _getNomeDisciplinaDisplay(Map<String, dynamic> disciplina) {
    final nome = disciplina['nome'] ?? '';
    final nomeExtenso = disciplina['nome_extenso'] ?? '';
    final periodo = disciplina['periodo'] ?? '';
    final turno = disciplina['turno'] ?? '';
    final ppc = disciplina['ppc'] ?? '';

    String display = nome;
    if (nomeExtenso.isNotEmpty && nomeExtenso != nome) {
      display = '$nome - $nomeExtenso';
    }

    List<String> details = [];
    if (periodo.isNotEmpty) details.add('Período: $periodo');
    if (turno.isNotEmpty) details.add('Turno: $turno');
    if (ppc.isNotEmpty) details.add('PPC: $ppc');

    if (details.isNotEmpty) {
      display += '\n[${details.join(' | ')}]';
    }

    return display;
  }

  // MÉTODO PARA OBTER SIGLA DA DISCIPLINA
  static String _getSiglaDisciplina(String nomeCompleto) {
    if (nomeCompleto.length <= 8) return nomeCompleto.toUpperCase();

    final palavras = nomeCompleto.split(' ');
    if (palavras.length > 1) {
      return palavras
          .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
          .join('');
    }

    return nomeCompleto.substring(0, 3).toUpperCase();
  }

  Future<void> _abrirDialogLancamentoLote() async {
    // Verifica se o usuário tem permissão
    if (!_usuarioPodeEditar()) {
      _mostrarMensagemAcessoNegado();
      return;
    }

    String? disciplinaId;
    Map<String, dynamic>? disciplinaDados;
    List<Map<String, dynamic>> professoresAlocacao = [];
    Map<String, Map<String, List<int>>> horariosSelecionados = {};
    final semestreController = TextEditingController(text: semestreAtual);

    // Adiciona um professor inicial
    void _adicionarProfessor(StateSetter setModalState) {
      setModalState(() {
        professoresAlocacao.add({
          'id': null,
          'ch_controller': TextEditingController(),
        });
      });
    }

    void _removerProfessor(int index, StateSetter setModalState) {
      if (professoresAlocacao.length <= 1) return;
      setModalState(() {
        professoresAlocacao[index]['ch_controller'].dispose();
        professoresAlocacao.removeAt(index);
      });
    }

    professoresAlocacao.add({
      'id': null,
      'ch_controller': TextEditingController(),
    });

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9),
            child: StatefulBuilder(builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_chart, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lançamento em Lote',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Adicione múltiplas aulas de uma vez',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Semestre
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month,
                                        color: Colors.indigo.shade700,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Semestre',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: semestreController,
                                  decoration: InputDecoration(
                                    labelText: 'Semestre',
                                    hintText: 'Ex: 2024.1',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    suffixIcon: PopupMenuButton<String>(
                                      icon: const Icon(Icons.arrow_drop_down),
                                      onSelected: (String value) {
                                        semestreController.text = value;
                                        setModalState(() {});
                                      },
                                      itemBuilder: (BuildContext context) {
                                        return semestres
                                            .map((semestre) =>
                                                PopupMenuItem<String>(
                                                  value: semestre['display'],
                                                  child:
                                                      Text(semestre['display']),
                                                ))
                                            .toList();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Disciplina
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.book,
                                        color: Colors.blue.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Disciplina',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () async {
                                    final selecionada =
                                        await _abrirDialogSelecaoDisciplina();
                                    if (selecionada != null) {
                                      setModalState(() {
                                        disciplinaId = selecionada['id'];
                                        disciplinaDados = selecionada;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 15),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            disciplinaDados != null
                                                ? _getNomeDisciplinaDisplay(
                                                    disciplinaDados!)
                                                : 'Selecione uma disciplina...',
                                            style: TextStyle(
                                              color: disciplinaDados != null
                                                  ? Colors.black
                                                  : Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.search,
                                            color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Docentes e Carga Horária
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person,
                                        color: Colors.green.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Docentes e Carga Horária',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(professoresAlocacao.length,
                                    (index) {
                                  final prof = professoresAlocacao[index];
                                  final chValue = double.tryParse(
                                          prof['ch_controller'].text) ??
                                      0;
                                  final horasAula = chValue / 15;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child:
                                                DropdownButtonFormField<String>(
                                              value: prof['id'],
                                              decoration: const InputDecoration(
                                                labelText: 'Docente',
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 14),
                                              ),
                                              isExpanded: true,
                                              items: professores
                                                  .map((p) =>
                                                      DropdownMenuItem<String>(
                                                        value: p['id'],
                                                        child: Text(
                                                            p['apelido'],
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                      ))
                                                  .toList(),
                                              onChanged: (v) => setModalState(
                                                  () => prof['id'] = v),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 1,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                TextFormField(
                                                  controller:
                                                      prof['ch_controller'],
                                                  decoration:
                                                      const InputDecoration(
                                                    labelText: 'CH',
                                                    border:
                                                        OutlineInputBorder(),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 14),
                                                    suffixText: 'h',
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  onChanged: (_) =>
                                                      setModalState(() {}),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${horasAula.toStringAsFixed(1)} h.a.',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (professoresAlocacao.length > 1)
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 22),
                                              onPressed: () =>
                                                  _removerProfessor(
                                                      index, setModalState),
                                              tooltip: 'Remover',
                                            )
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _adicionarProfessor(setModalState),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text(
                                      'Adicionar Professor (Co-docência)'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade700,
                                    side: BorderSide(
                                        color: Colors.green.shade300),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Dias e Horários (Grid)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.grid_on,
                                        color: Colors.purple.shade700,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Dias e Horários',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Selecione os dias e horários específicos para as aulas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Chips de seleção de dias
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: diasSemana.map((dia) {
                                    final temDiaSelecionado =
                                        _temDiaSelecionadoLote(
                                            horariosSelecionados, dia);
                                    return FilterChip(
                                      label: Text(dia),
                                      selected: temDiaSelecionado,
                                      selectedColor: Colors.purple.shade300,
                                      checkmarkColor: Colors.white,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          _toggleDiaCompletoLote(
                                              horariosSelecionados,
                                              dia,
                                              selected);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                // Grid de horários
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Table(
                                    border: TableBorder.all(
                                        color: Colors.grey.shade200),
                                    columnWidths: const {
                                      0: FixedColumnWidth(50), // Label turno
                                    },
                                    children: [
                                      // Header Dias
                                      TableRow(
                                        decoration: BoxDecoration(
                                            color: Colors.grey.shade50),
                                        children: [
                                          const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Text('')),
                                          ...diasSemana.map((d) => Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                  d.substring(0, 3),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: _temDiaSelecionadoLote(
                                                            horariosSelecionados,
                                                            d)
                                                        ? Colors.black
                                                        : Colors.grey,
                                                  ),
                                                ),
                                              )),
                                        ],
                                      ),
                                      // Manhã
                                      ..._buildTurnoRowsLote('Manhã', 'M', 5,
                                          horariosSelecionados, setModalState),
                                      // Tarde
                                      ..._buildTurnoRowsLote('Tarde', 'T', 5,
                                          horariosSelecionados, setModalState),
                                      // Noite
                                      ..._buildTurnoRowsLote('Noite', 'N', 4,
                                          horariosSelecionados, setModalState),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (disciplinaId == null ||
                                professoresAlocacao
                                    .any((p) => p['id'] == null) ||
                                horariosSelecionados.isEmpty ||
                                semestreController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Preencha todos os campos!'),
                                ),
                              );
                              return;
                            }

                            // Converter professoresAlocacao para o formato esperado
                            List<String> professoresIds = professoresAlocacao
                                .map((p) => p['id'] as String)
                                .toList();

                            await _salvarLancamentoLote(
                              disciplinaId!,
                              professoresIds,
                              horariosSelecionados,
                              semestreController.text,
                            );

                            // Limpar controllers
                            for (var prof in professoresAlocacao) {
                              prof['ch_controller'].dispose();
                            }

                            if (mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Confirmar Lançamento'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  int _getIndiceGlobal(String turno, int indiceNoTurno) {
    switch (turno) {
      case 'Manhã':
        return indiceNoTurno;
      case 'Tarde':
        return indiceNoTurno + 6;
      case 'Noite':
        return indiceNoTurno + 12;
      default:
        return indiceNoTurno;
    }
  }

  // Verifica se um dia tem algum horário selecionado
  bool _temDiaSelecionadoLote(
      Map<String, Map<String, List<int>>> horariosSelecionados, String dia) {
    final slots = horariosSelecionados[dia];
    if (slots == null) return false;
    return slots.values.any((list) => list.isNotEmpty);
  }

  // Toggle de um dia completo (seleciona/desseleciona todos os horários do dia)
  void _toggleDiaCompletoLote(
      Map<String, Map<String, List<int>>> horariosSelecionados,
      String dia,
      bool selected) {
    if (selected) {
      if (!horariosSelecionados.containsKey(dia)) {
        horariosSelecionados[dia] = {};
      }
    } else {
      horariosSelecionados.remove(dia);
    }
  }

  // Constrói as linhas da tabela para um turno específico
  List<TableRow> _buildTurnoRowsLote(
    String labelTurno,
    String prefixo,
    int qtd,
    Map<String, Map<String, List<int>>> horariosSelecionados,
    StateSetter setModalState,
  ) {
    List<TableRow> rows = [];
    for (int i = 1; i <= qtd; i++) {
      final slot = '$prefixo$i';
      rows.add(TableRow(
        children: [
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: _getCorTurno(labelTurno).withOpacity(0.1),
              child: Text(
                slot,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ...diasSemana.map((dia) {
            final diaHabilitado = horariosSelecionados.containsKey(dia);

            // Verifica se este slot específico está selecionado
            bool slotSelecionado = false;
            if (diaHabilitado &&
                horariosSelecionados[dia]!.containsKey(labelTurno)) {
              final indiceGlobal = _getIndiceGlobal(labelTurno, i);
              slotSelecionado = horariosSelecionados[dia]![labelTurno]!
                  .contains(indiceGlobal);
            }

            return TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: InkWell(
                onTap: diaHabilitado
                    ? () {
                        setModalState(() {
                          final indiceGlobal = _getIndiceGlobal(labelTurno, i);
                          if (!horariosSelecionados[dia]!
                              .containsKey(labelTurno)) {
                            horariosSelecionados[dia]![labelTurno] = [];
                          }
                          if (slotSelecionado) {
                            horariosSelecionados[dia]![labelTurno]!
                                .remove(indiceGlobal);
                          } else {
                            horariosSelecionados[dia]![labelTurno]!
                                .add(indiceGlobal);
                          }
                        });
                      }
                    : null,
                child: Container(
                  height: 32,
                  color: !diaHabilitado
                      ? Colors.grey.shade100
                      : slotSelecionado
                          ? _getCorTurno(labelTurno).withOpacity(0.6)
                          : Colors.white,
                  child: Center(
                    child: slotSelecionado
                        ? Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            );
          }),
        ],
      ));
    }
    return rows;
  }

  // Retorna a cor para cada turno
  Color _getCorTurno(String turno) {
    switch (turno) {
      case 'Manhã':
        return Colors.orange;
      case 'Tarde':
        return Colors.blue;
      case 'Noite':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Future<void> _salvarLancamentoLote(
    String disciplinaId,
    List<String> professoresIds,
    Map<String, Map<String, List<int>>> horariosSelecionados,
    String semestre,
  ) async {
    try {
      int aulasSalvas = 0;

      for (var entry in horariosSelecionados.entries) {
        final dia = entry.key;
        final turnosDoDia = entry.value;

        for (var turnoEntry in turnosDoDia.entries) {
          final turno = turnoEntry.key;
          final indices = turnoEntry.value;

          for (var indiceGlobal in indices) {
            final indiceNoTurno = _getIndiceNoTurno(indiceGlobal);

            final key = '$dia-$turno-$indiceNoTurno';
            final aulasExistentes = grade[key] ?? [];

            bool jaExiste = false;
            for (var aula in aulasExistentes) {
              if (aula['disciplina_id'] == disciplinaId &&
                  _listasIguais(
                      aula['professores_ids'] ?? [], professoresIds) &&
                  aula['semestre'] == semestre) {
                jaExiste = true;
                break;
              }
            }

            if (!jaExiste) {
              await supabase.from('grade_aulas').insert({
                'dia': dia,
                'turno': turno,
                'indice': indiceNoTurno,
                'disciplina_id': disciplinaId,
                'professores': professoresIds,
                'semestre': semestre,
              });
              aulasSalvas++;
            }
          }
        }
      }

      await _loadGrade();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$aulasSalvas aulas salvas com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  bool _listasIguais(List<dynamic> lista1, List<dynamic> lista2) {
    if (lista1.length != lista2.length) return false;
    for (var i = 0; i < lista1.length; i++) {
      if (lista1[i] != lista2[i]) return false;
    }
    return true;
  }

  Future<void> _abrirDialogEdicaoAula(
      String dia, String turno, int indice) async {
    final key = '$dia-$turno-$indice';
    final aulas = grade[key] ?? [];

    // Se já existem aulas, mostrar opções
    if (aulas.isNotEmpty) {
      await _visualizarAulasExistentes(dia, turno, indice, aulas);
    } else {
      // Se não há aulas, abrir diretamente o diálogo de adição
      await _abrirDialogAdicaoDetalhada(dia, turno, indice);
    }
  }

  Future<void> _visualizarAulasExistentes(String dia, String turno, int indice,
      List<Map<String, dynamic>> aulas) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Aulas - $dia $turno ($indice)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: aulas.length,
                    itemBuilder: (context, index) {
                      final aula = aulas[index];
                      final disciplinaSigla =
                          _getSiglaDisciplina(aula['disciplina_nome'] ?? '');
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            '$disciplinaSigla - ${aula['disciplina_nome_extenso'] ?? aula['disciplina_nome'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Professores: ${(aula['professores_nomes'] as List).join(', ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Semestre: ${aula['semestre'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: _usuarioPodeEditar()
                              ? IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () async {
                                    await _excluirAula(aula['id']);
                                    Navigator.pop(context);
                                    _abrirDialogEdicaoAula(dia, turno, indice);
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                    if (_usuarioPodeEditar()) ...[
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _abrirDialogAdicaoDetalhada(dia, turno, indice);
                        },
                        child: const Text('Adicionar Aula'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirDialogAdicaoDetalhada(
      String dia, String turno, int indice) async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogLancamentoGrade(
        dia: dia,
        turno: turno,
        indice: indice,
        disciplinas: disciplinas,
        professores: professores,
        semestre: semestreAtual,
      ),
    );

    if (resultado != null && mounted) {
      await _salvarLancamentoDetalhado(resultado);
    }
  }

  Future<void> _salvarLancamentoDetalhado(Map<String, dynamic> dados) async {
    try {
      final disciplinaId = dados['disciplina_id'] as String;
      final professores = dados['professores'] as List<Map<String, dynamic>>;
      final semestre = dados['semestre'] as String;

      // Consolidar slots por dia-turno-indice
      final Map<String, Map<String, dynamic>> consolidated = {};

      for (var prof in professores) {
        final docenteId = prof['docente_id'] as String;
        final List<dynamic> slots = prof['slots'] ?? [];

        for (var slot in slots) {
          if (slot is String && slot.contains('-')) {
            final parts = slot.split('-'); // [Seg, M1]
            if (parts.length >= 2) {
              final dia = parts[0];
              final timeCode = parts[1]; // M1

              final turnoLetra = timeCode[0]; // M
              final indiceStr = timeCode.substring(1); // 1
              final indice = int.tryParse(indiceStr) ?? 0;

              String turno = 'Manhã';
              if (turnoLetra == 'T') turno = 'Tarde';
              if (turnoLetra == 'N') turno = 'Noite';

              final compositeKey = '$dia-$turno-$indice-$disciplinaId';

              if (!consolidated.containsKey(compositeKey)) {
                consolidated[compositeKey] = {
                  'semestre': semestre,
                  'dia': dia,
                  'turno': turno,
                  'indice': indice,
                  'disciplina_id': disciplinaId,
                  'professores': [],
                };
              }

              final List listProfs = consolidated[compositeKey]!['professores'];
              if (!listProfs.contains(docenteId)) {
                listProfs.add(docenteId);
              }
            }
          }
        }
      }

      // Inserir no banco
      final inserts = consolidated.values.toList();

      if (inserts.isNotEmpty) {
        await supabase.from('grade_aulas').insert(inserts);
        await _loadGrade();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${inserts.length} aula(s) salva(s) com sucesso!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  Future<void> _excluirAula(String aulaId) async {
    // Verifica se o usuário tem permissão
    if (!_usuarioPodeEditar()) {
      _mostrarMensagemAcessoNegado();
      return;
    }

    try {
      await supabase.from('grade_aulas').delete().eq('id', aulaId);
      await _loadGrade();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aula excluída com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  Future<void> _abrirDialogIndividual(
      String dia, String turno, int indice) async {
    // Verifica se o usuário tem permissão
    if (!_usuarioPodeEditar()) {
      _mostrarMensagemAcessoNegado();
      return;
    }

    String? disciplinaId;
    Map<String, dynamic>? disciplinaDados;
    List<String> professoresSelecionados = [];
    final semestreController = TextEditingController(text: semestreAtual);

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Adicionar Aula - $dia $turno ($indice)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CAMPO SEMESTRE
                    TextField(
                      controller: semestreController,
                      decoration: InputDecoration(
                        labelText: 'Semestre',
                        hintText: 'Ex: 2024.1',
                        border: const OutlineInputBorder(),
                        suffixIcon: PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            semestreController.text = value;
                            setModalState(() {});
                          },
                          itemBuilder: (BuildContext context) {
                            return semestres
                                .map((semestre) => PopupMenuItem<String>(
                                      value: semestre['display'],
                                      child: Text(semestre['display']),
                                    ))
                                .toList();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Disciplina:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final selecionada =
                            await _abrirDialogSelecaoDisciplina();
                        if (selecionada != null) {
                          setModalState(() {
                            disciplinaId = selecionada['id'];
                            disciplinaDados = selecionada;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                disciplinaDados != null
                                    ? _getNomeDisciplinaDisplay(
                                        disciplinaDados!)
                                    : 'Selecione uma disciplina...',
                                style: TextStyle(
                                  color: disciplinaDados != null
                                      ? Colors.black
                                      : Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(Icons.search, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Professores:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: professores.length,
                        itemBuilder: (context, index) {
                          final professor = professores[index];
                          return CheckboxListTile(
                            dense: true,
                            title: Text(professor['apelido']!),
                            value: professoresSelecionados
                                .contains(professor['id']),
                            onChanged: (bool? value) {
                              setModalState(() {
                                if (value == true) {
                                  professoresSelecionados.add(professor['id']!);
                                } else {
                                  professoresSelecionados
                                      .remove(professor['id']!);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            if (disciplinaId == null ||
                                professoresSelecionados.isEmpty ||
                                semestreController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Selecione uma disciplina, professores e informe o semestre!'),
                                ),
                              );
                              return;
                            }

                            await _salvarHorarioIndividual(
                                dia,
                                turno,
                                indice,
                                disciplinaId!,
                                professoresSelecionados,
                                semestreController.text);
                            if (mounted) Navigator.pop(context);
                          },
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _abrirDialogSelecaoDisciplina() async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String filtro = '';
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(builder: (context, setState) {
              final filtradas = disciplinas.where((d) {
                final searchContent =
                    ('${d['nome']} ${d['nome_extenso']} ${d['periodo']} ${d['turno']} ${d['ppc']}')
                        .toLowerCase();
                return searchContent.contains(filtro.toLowerCase());
              }).toList();

              return Column(
                children: [
                  const Text(
                    'Selecionar Disciplina',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Pesquisar...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        filtro = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtradas.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final d = filtradas[index];
                        final ppc = d['ppc']?.toString() ?? 'N/A';
                        final per = d['periodo']?.toString() ?? 'N/A';
                        final tur = d['turno']?.toString() ?? 'N/A';

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.pop(context, d),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d['nome']} - ${d['nome_extenso']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildTag(Icons.history_edu, 'PPC: $ppc',
                                          Colors.blue),
                                      const SizedBox(width: 8),
                                      _buildTag(Icons.calendar_view_day,
                                          'Período: $per', Colors.green),
                                      const SizedBox(width: 8),
                                      _buildTag(Icons.access_time, tur,
                                          Colors.orange),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _salvarHorarioIndividual(String dia, String turno, int indice,
      String disciplinaId, List<String> professoresIds, String semestre) async {
    try {
      await supabase.from('grade_aulas').insert({
        'dia': dia,
        'turno': turno,
        'indice': indice,
        'disciplina_id': disciplinaId,
        'professores': professoresIds,
        'semestre': semestre,
      });

      await _loadGrade();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aula salva com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  Future<void> _limparTodaGrade() async {
    // Verifica se o usuário tem permissão
    if (!_usuarioPodeEditar()) {
      _mostrarMensagemAcessoNegado();
      return;
    }

    // Primeiro, pedir para selecionar o semestre
    String? semestreSelecionado = semestreAtual;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecionar Semestre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecione o semestre que deseja limpar:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: semestreSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Semestre',
                  border: OutlineInputBorder(),
                ),
                items: [
                  ...semestres
                      .map((semestre) => DropdownMenuItem<String>(
                            value: semestre['display'],
                            child: Text(semestre['display']),
                          ))
                      .toList(),
                  const DropdownMenuItem<String>(
                    value: 'todos',
                    child: Text('TODOS OS SEMESTRES'),
                  ),
                ],
                onChanged: (value) {
                  semestreSelecionado = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, semestreSelecionado);
              },
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    ).then((selectedSemester) async {
      if (selectedSemester == null) return;

      // Agora pedir confirmação
      bool confirmado = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                selectedSemester == 'todos'
                    ? 'Limpar TODOS os Semestres'
                    : 'Limpar Semestre $selectedSemester',
              ),
              content: Text(
                selectedSemester == 'todos'
                    ? 'Tem certeza que deseja apagar TODAS as aulas de TODOS os semestres? Esta ação não pode ser desfeita.'
                    : 'Tem certeza que deseja apagar TODAS as aulas do semestre $selectedSemester? Esta ação não pode ser desfeita.',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Limpar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (confirmado) {
        await _executarLimpezaGrade(selectedSemester);
      }
    });
  }

  Future<void> _executarLimpezaGrade(String semestre) async {
    try {
      int aulasRemovidas = 0;

      if (semestre == 'todos') {
        // Limpar todos os semestres
        final response = await supabase.from('grade_aulas').select('id');

        if (response.isNotEmpty) {
          for (var item in response) {
            await supabase.from('grade_aulas').delete().eq('id', item['id']);
            aulasRemovidas++;
          }
        }
      } else {
        // Limpar apenas o semestre selecionado
        final response = await supabase
            .from('grade_aulas')
            .select('id')
            .eq('semestre', semestre);

        if (response.isNotEmpty) {
          for (var item in response) {
            await supabase.from('grade_aulas').delete().eq('id', item['id']);
            aulasRemovidas++;
          }
        }
      }

      await _loadGrade();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              semestre == 'todos'
                  ? 'Toda a grade foi limpa! $aulasRemovidas aulas removidas.'
                  : 'Semestre $semestre limpo! $aulasRemovidas aulas removidas.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao limpar grade: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getHorarioCompleto(String turno, int indice) {
    // Garante que o índice seja o relativo ao turno (1..6 ou 1..4)
    final indiceRelativo = _getIndiceNoTurno(indice);

    final horarios = horariosPorTurno[turno];
    if (horarios == null) return '';

    if (indiceRelativo < 1 || indiceRelativo > horarios.length) return '';

    return horarios[indiceRelativo - 1];
  }

  String _getTurnoDoHorario(int indice) {
    if (indice <= 6) return 'Manhã';
    if (indice <= 12) return 'Tarde';
    return 'Noite';
  }

  String _getHorarioFormatado(int indice) {
    final turno = _getTurnoDoHorario(indice);
    final indiceNoTurno = _getIndiceNoTurno(indice);
    return horariosPorTurno[turno]?[indiceNoTurno - 1] ?? '';
  }

  int _getIndiceNoTurno(int indice) {
    if (indice <= 6) return indice;
    if (indice <= 12) return indice - 6;
    return indice - 12;
  }

  Color _getTurnoColor(String turno) {
    switch (turno) {
      case 'Manhã':
        return Colors.amber.shade100;
      case 'Tarde':
        return Colors.deepOrange.shade100;
      case 'Noite':
        return Colors.indigo.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  void _onHorarioTap(String dia, String turno, int indice) {
    if (_usuarioPodeEditar()) {
      _abrirDialogEdicaoAula(dia, turno, indice);
    } else {
      _mostrarMensagemAcessoNegado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double cellWidth = 160;
    final totalHorarios = 16;
    final double cellHeight = 120.0;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade800, Colors.indigo.shade900],
            ),
          ),
        ),
        title: Row(
          children: [
            const Text('Grade de Aulas',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  _isLoadingSemestre
                      ? Container(
                          width: 16,
                          height: 16,
                          padding: const EdgeInsets.all(2),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : DropdownButton<String>(
                          value: semestreAtual,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          dropdownColor: Colors.blue.shade800,
                          underline: Container(),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.white),
                          items: [
                            ...semestres
                                .map((semestre) => DropdownMenuItem<String>(
                                      value: semestre['display'],
                                      child: Text(
                                        semestre['display'],
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ))
                                .toList(),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              _onSemestreChanged(newValue);
                            }
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Recarregar dados',
          ),
          if (_usuarioPodeEditar()) ...[
            IconButton(
              icon: const Icon(Icons.add_chart),
              onPressed: _abrirDialogLancamentoLote,
              tooltip: 'Lançamento em Lote',
            ),
          ],
          if (_podeGerarPDF())
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _gerarPDFDetalhado,
              tooltip: 'Gerar PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando dados...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: Row(
                children: [
                  Container(
                    width: 350,
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(color: Colors.grey.shade300)),
                      color: Colors.grey[50],
                    ),
                    child: _buildSidebar(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: [
                            Container(
                              height: 60,
                              child: Row(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 60,
                                    margin: const EdgeInsets.all(4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.indigo.shade50,
                                          Colors.indigo.shade100,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.indigo.shade200
                                              .withOpacity(0.5)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'HORÁRIO',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo.shade900,
                                      ),
                                    ),
                                  ),
                                  ...diasSemana.map((dia) {
                                    return Container(
                                      width: cellWidth,
                                      height: 60,
                                      margin: const EdgeInsets.all(4),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.blue.shade50,
                                            Colors.blue.shade100,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.blue.shade200
                                                .withOpacity(0.5)),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        dia,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    ...List.generate(totalHorarios, (i) {
                                      final indice = i + 1;
                                      final turno = _getTurnoDoHorario(indice);
                                      final horario =
                                          _getHorarioFormatado(indice);

                                      return Container(
                                        width: 120,
                                        height: cellHeight,
                                        margin: const EdgeInsets.all(4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.grey.shade50,
                                              Colors.grey.shade100,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                          border: Border.all(
                                              color: Colors.grey.shade100,
                                              width: 1.5),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '$indice',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              horario,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getTurnoColor(turno)
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                turno,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey.shade800,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                ...diasSemana.map((dia) {
                                  return Column(
                                    children: [
                                      ...List.generate(totalHorarios, (i) {
                                        final indice = i + 1;
                                        final turno =
                                            _getTurnoDoHorario(indice);
                                        final key =
                                            '$dia-$turno-${_getIndiceNoTurno(indice)}';
                                        final aulas = grade[key] ?? [];

                                        return GestureDetector(
                                          onTap: () => _onHorarioTap(dia, turno,
                                              _getIndiceNoTurno(indice)),
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: Container(
                                              width: cellWidth,
                                              height: cellHeight,
                                              margin: const EdgeInsets.all(4),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: aulas.isEmpty
                                                    ? Colors.white
                                                    : _getTurnoColor(turno)
                                                        .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: aulas.isEmpty
                                                      ? Colors.grey.shade200
                                                      : _getTurnoColor(turno)
                                                          .withOpacity(0.4),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  if (aulas.isNotEmpty)
                                                    BoxShadow(
                                                      color:
                                                          _getTurnoColor(turno)
                                                              .withOpacity(0.2),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 3),
                                                    )
                                                  else
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.03),
                                                      blurRadius: 4,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                ],
                                              ),
                                              child: _buildAulaContent(aulas),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _usuarioPodeEditar()
          ? FloatingActionButton(
              onPressed: _limparTodaGrade,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              tooltip: 'Limpar grade',
              child: const Icon(Icons.delete_forever),
            )
          : null,
    );
  }

  Widget _buildSidebar() {
    // Usa a lista já ordenada em cache
    final professoresOrdenados = _professoresOrdenados;

    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Row(
            children: [
              Icon(Icons.people, size: 20),
              SizedBox(width: 8),
              Text(
                'DOCENTES - DETALHES',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: professoresOrdenados.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Nenhum docente com aulas atribuídas',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: professoresOrdenados.length,
                  itemBuilder: (context, index) {
                    final entry = professoresOrdenados[index];
                    final professor = entry.key;
                    final cargaHoraria = entry.value;
                    final detalhes = detalhesProfessores[professor] ?? [];

                    final List<Widget> detalhesWidgets = [];

                    if (detalhes.isNotEmpty) {
                      detalhesWidgets.add(const Divider(height: 1));
                      detalhesWidgets.add(const SizedBox(height: 8));

                      for (final detalhe in detalhes) {
                        final isDisciplina = detalhe['tipo'] == 'disciplina';
                        final nome = detalhe['nome'] ?? '';
                        final nomeExtenso = detalhe['nome_extenso'] ?? nome;
                        final ch = detalhe['carga_horaria'] ?? 0;
                        final sigla = _getSiglaDisciplina(nome);

                        detalhesWidgets.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: isDisciplina
                                        ? Colors.green
                                        : Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isDisciplina
                                            ? '$sigla - $nomeExtenso'
                                            : nome,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDisciplina
                                        ? Colors.green.shade50
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${ch.toStringAsFixed(1)} h.a. (${(ch * 15).toStringAsFixed(0)}h)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDisciplina
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    } else {
                      detalhesWidgets.add(
                        Text(
                          'Sem atividades atribuídas',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    professor,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Text(
                                    '${cargaHoraria.toStringAsFixed(1)} h.a. (${(cargaHoraria * 15).toStringAsFixed(0)}h)',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (detalhesWidgets.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              ...detalhesWidgets,
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAulaContent(List<Map<String, dynamic>> aulas) {
    if (aulas.isEmpty) {
      return const Center(
        child: Text(
          '+',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: aulas.length,
      itemBuilder: (context, index) {
        final aula = aulas[index];
        final disciplinaNome = aula['disciplina_nome'] ?? '';
        final professores = (aula['professores_nomes'] as List).join(', ');
        final disciplinaSigla = _getSiglaDisciplina(disciplinaNome);

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(text: '$disciplinaSigla'),
                    TextSpan(
                      text: ' - $professores',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _gerarPDFDetalhado() async {
    try {
      await GradePDFHelper.gerarPDFDetalhado(
        grade: grade,
        cargaHorariaProfessores: cargaHorariaProfessores,
        detalhesProfessores: detalhesProfessores,
        horariosProfessores: horariosProfessores,
        diasSemana: diasSemana,
        getTurnoDoHorario: _getTurnoDoHorario,
        getIndiceNoTurno: _getIndiceNoTurno,
        getHorarioFormatado: _getHorarioFormatado,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF gerado com sucesso!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
