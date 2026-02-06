import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotasPage extends StatefulWidget {
  final int defesaId;
  final Map<String, dynamic> defesa;

  const NotasPage({
    super.key,
    required this.defesaId,
    required this.defesa,
  });

  @override
  State<NotasPage> createState() => _NotasPageState();
}

class _NotasPageState extends State<NotasPage> {
  final supabase = Supabase.instance.client;
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _notaTotalController = TextEditingController();
  bool _loading = true;
  bool _editando = false;
  Map<String, dynamic>? _notasExistentes;
  int? _avaliadorSelecionado;
  String? _nomeAvaliadorSelecionado;
  bool _modoNotaTotal = false;

  // Categorias e critérios baseados no PDF
  final Map<String, List<Map<String, dynamic>>> _categorias = {
    'Avaliação do Trabalho Escrito': [
      {
        'key': 'introducao',
        'label': 'Introdução e justificativa',
        'max': 1.0,
        'descricao':
            'Apresenta e contextualiza o tema, a justificativa e a relevância do trabalho para a área.',
      },
      {
        'key': 'problematizacao',
        'label': 'Problematização e metodologia',
        'max': 1.5,
        'descricao':
            'Temos objetivos (geral e específicos) claros; percebe-se o problema/pergunta de pesquisa de forma satisfatória; descreve ou segue procedimentos metodológicos adequados para o problema.',
      },
      {
        'key': 'referencial',
        'label': 'Referencial teórico e bibliográfico',
        'max': 2.0,
        'descricao':
            'Apresenta os elementos teóricos da área do conhecimento investigada, bem como a definição dos termos, conceitos, estado da arte e bibliografia acadêmica pertinentes ao tema da pesquisa.',
      },
      {
        'key': 'desenvolvimento',
        'label': 'Desenvolvimento e avaliação',
        'max': 2.5,
        'descricao':
            'Apresenta de forma suficiente as discussões, materiais e argumentos condizentes à proposta desenvolvida. Realiza as avaliações e argumentações necessárias para o alcance dos objetivos traçados',
      },
      {
        'key': 'conclusoes',
        'label': 'Conclusões',
        'max': 1.0,
        'descricao':
            'Apresenta os resultados alcançados e sua síntese pessoal, de modo a expressar sua compreensão sobre o assunto que foi objeto do trabalho e, eventualmente, sua contribuição pessoal para a área.',
      },
      {
        'key': 'forma',
        'label': 'Forma',
        'max': 0.5,
        'descricao':
            'Estrutura e coesão do texto; linguagem clara precisa e formalmente correta; e padrões da ABNT.',
      },
    ],
    'Avaliação da Apresentação Oral': [
      {
        'key': 'estruturacao',
        'label': 'Estruturação e ordenação do conteúdo',
        'max': 0.5,
        'descricao': 'Estruturação e ordenação do conteúdo da apresentação',
      },
      {
        'key': 'clareza',
        'label': 'Clareza, objetividade e fluência',
        'max': 0.5,
        'descricao': 'Clareza, objetividade e fluência na exposição das ideias',
      },
      {
        'key': 'dominio',
        'label': 'Domínio do tema',
        'max': 0.5,
        'descricao':
            'Domínio do tema desenvolvido e correspondência com trabalho escrito',
      },
    ],
  };

  // Lista de avaliadores disponíveis
  List<Map<String, dynamic>> get _avaliadoresDisponiveis {
    final avaliadores = <Map<String, dynamic>>[];

    if (widget.defesa['avaliador1'] != null &&
        widget.defesa['avaliador1'].toString().isNotEmpty) {
      avaliadores.add({
        'numero': 1,
        'nome': widget.defesa['avaliador1'],
        'instituto': widget.defesa['instituto_av1'] ?? ''
      });
    }

    if (widget.defesa['avaliador2'] != null &&
        widget.defesa['avaliador2'].toString().isNotEmpty) {
      avaliadores.add({
        'numero': 2,
        'nome': widget.defesa['avaliador2'],
        'instituto': widget.defesa['instituto_av2'] ?? ''
      });
    }

    if (widget.defesa['avaliador3'] != null &&
        widget.defesa['avaliador3'].toString().isNotEmpty) {
      avaliadores.add({
        'numero': 3,
        'nome': widget.defesa['avaliador3'],
        'instituto': widget.defesa['instituto_av3'] ?? ''
      });
    }

    return avaliadores;
  }

  @override
  void initState() {
    super.initState();
    _inicializarControllers();
    _mostrarSelecaoAvaliador();
  }

  void _inicializarControllers() {
    for (var categoria in _categorias.values) {
      for (var criterio in categoria) {
        _controllers[criterio['key']] = TextEditingController();
      }
    }
  }

  void _mostrarSelecaoAvaliador() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selecionarAvaliador();
    });
  }

  Future<void> _selecionarAvaliador() async {
    if (_avaliadoresDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nenhum avaliador cadastrado para esta defesa')),
      );
      Navigator.pop(context);
      return;
    }

    final selecionado = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar Avaliador'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _avaliadoresDisponiveis.length,
            itemBuilder: (context, index) {
              final avaliador = _avaliadoresDisponiveis[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      avaliador['numero'].toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(avaliador['nome']),
                  subtitle: avaliador['instituto'].toString().isNotEmpty
                      ? Text(avaliador['instituto'])
                      : null,
                  onTap: () => Navigator.pop(context, avaliador['numero']),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selecionado != null) {
      setState(() {
        _avaliadorSelecionado = selecionado;
        _nomeAvaliadorSelecionado = _avaliadoresDisponiveis
            .firstWhere((av) => av['numero'] == selecionado)['nome'];
      });
      await _carregarNotasExistentes();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _carregarNotasExistentes() async {
    if (_avaliadorSelecionado == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final response = await supabase
          .from('notas')
          .select()
          .eq('defesa_id', widget.defesaId)
          .eq('avaliador_numero', _avaliadorSelecionado!)
          .maybeSingle();

      if (response != null) {
        _notasExistentes = Map<String, dynamic>.from(response);

        // Verificar se foi salvo como nota total ou por critérios
        if (_notasExistentes!['nota_total'] != null) {
          _modoNotaTotal = true;
          _notaTotalController.text =
              _notasExistentes!['nota_total'].toString().replaceAll('.', ',');
        } else {
          _modoNotaTotal = false;
          _preencherCamposComNotasExistentes();
        }

        _editando = false;
      } else {
        _editando = true;
      }
    } catch (e) {
      print('Erro ao carregar notas: $e');
      _editando = true;
    }

    setState(() {
      _loading = false;
    });
  }

  void _preencherCamposComNotasExistentes() {
    if (_notasExistentes != null) {
      for (var categoria in _categorias.values) {
        for (var criterio in categoria) {
          final key = criterio['key'];
          final valor = _notasExistentes![key];
          if (valor != null) {
            _controllers[key]!.text = valor.toString().replaceAll('.', ',');
          }
        }
      }
    }
  }

  double _calcularNotaCategoria(String categoria) {
    double total = 0.0;
    for (var criterio in _categorias[categoria]!) {
      final texto = _controllers[criterio['key']]!.text.replaceAll(',', '.');
      final valor = double.tryParse(texto) ?? 0.0;
      total += valor;
    }
    return total;
  }

  double _calcularNotaFinal() {
    if (_modoNotaTotal) {
      final texto = _notaTotalController.text.replaceAll(',', '.');
      return double.tryParse(texto) ?? 0.0;
    }
    return _calcularNotaCategoria('Avaliação do Trabalho Escrito') +
        _calcularNotaCategoria('Avaliação da Apresentação Oral');
  }

  Future<void> _salvarNotas() async {
    if (_avaliadorSelecionado == null) return;

    final dados = {
      'defesa_id': widget.defesaId,
      'avaliador_numero': _avaliadorSelecionado!,
      'avaliador_nome': _nomeAvaliadorSelecionado!,
      'modo_nota_total': _modoNotaTotal,
    };

    if (_modoNotaTotal) {
      // Salvar apenas a nota total
      dados['nota_total'] =
          double.tryParse(_notaTotalController.text.replaceAll(',', '.')) ??
              0.0;
    } else {
      // Salvar por critérios
      for (var categoria in _categorias.values) {
        for (var criterio in categoria) {
          dados[criterio['key']] = double.tryParse(
                  _controllers[criterio['key']]!.text.replaceAll(',', '.')) ??
              0.0;
        }
      }
    }

    try {
      if (_notasExistentes != null) {
        // Atualizar notas existentes
        await supabase
            .from('notas')
            .update(dados)
            .eq('defesa_id', widget.defesaId)
            .eq('avaliador_numero', _avaliadorSelecionado!);
      } else {
        // Inserir novas notas
        await supabase.from('notas').insert(dados);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notas salvas com sucesso!')),
      );

      await _carregarNotasExistentes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar notas: $e')),
      );
    }
  }

  void _habilitarEdicao() {
    setState(() {
      _editando = true;
    });
  }

  void _trocarAvaliador() {
    _selecionarAvaliador();
  }

  void _alternarModoNota() {
    setState(() {
      _modoNotaTotal = !_modoNotaTotal;
      // Limpar campos ao alternar o modo
      if (_modoNotaTotal) {
        for (var controller in _controllers.values) {
          controller.clear();
        }
      } else {
        _notaTotalController.clear();
      }
    });
  }

  Widget _buildCampoNota(Map<String, dynamic> criterio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  criterio['label'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '(máx. ${criterio['max']})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            criterio['descricao'],
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controllers[criterio['key']],
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            decoration: const InputDecoration(
              labelText: 'Nota',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            enabled: _editando && !_modoNotaTotal,
          ),
        ],
      ),
    );
  }

  Widget _buildCampoNotaTotal() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nota Total',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Digite a nota final diretamente (máximo: 10,0)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notaTotalController,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            decoration: const InputDecoration(
              labelText: 'Nota Total (0-10)',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            enabled: _editando && _modoNotaTotal,
          ),
        ],
      ),
    );
  }

  Widget _buildResumoNotas() {
    final notaFinal = _calcularNotaFinal();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          if (!_modoNotaTotal) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nota Final do Trabalho Escrito:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_calcularNotaCategoria('Avaliação do Trabalho Escrito').toStringAsFixed(1)}/8,5',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _calcularNotaCategoria(
                                'Avaliação do Trabalho Escrito') >=
                            6.0
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nota Final da Apresentação:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_calcularNotaCategoria('Avaliação da Apresentação Oral').toStringAsFixed(1)}/1,5',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _calcularNotaCategoria(
                                'Avaliação da Apresentação Oral') >=
                            1.0
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _modoNotaTotal ? 'NOTA TOTAL:' : 'NOTA FINAL:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${notaFinal.toStringAsFixed(1)}/10,0',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: notaFinal >= 7.0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAvaliador() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                _avaliadorSelecionado.toString(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nomeAvaliadorSelecionado ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Avaliador $_avaliadorSelecionado',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: _trocarAvaliador,
              tooltip: 'Trocar Avaliador',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeletorModoNota() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modo de Lançamento de Notas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escolha como deseja lançar as notas:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _editando
                        ? () => setState(() => _modoNotaTotal = false)
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          !_modoNotaTotal ? Colors.blue.shade50 : null,
                      side: BorderSide(
                        color: !_modoNotaTotal ? Colors.blue : Colors.grey,
                        width: !_modoNotaTotal ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment,
                            color: !_modoNotaTotal ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Por Critérios',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  !_modoNotaTotal ? Colors.blue : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preencher cada critério',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  !_modoNotaTotal ? Colors.blue : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _editando
                        ? () => setState(() => _modoNotaTotal = true)
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          _modoNotaTotal ? Colors.green.shade50 : null,
                      side: BorderSide(
                        color: _modoNotaTotal ? Colors.green : Colors.grey,
                        width: _modoNotaTotal ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Icon(
                            Icons.star,
                            color: _modoNotaTotal ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nota Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  _modoNotaTotal ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nota final direta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _modoNotaTotal ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_avaliadorSelecionado == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Selecionar Avaliador')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançar Notas'),
        actions: [
          if (_notasExistentes != null && !_editando)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _habilitarEdicao,
              tooltip: 'Editar Notas',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderAvaliador(),
                    const SizedBox(height: 16),

                    if (_notasExistentes != null && !_editando)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Notas já lançadas para este avaliador. Clique no ícone de edição para modificar.',
                                style: TextStyle(color: Colors.blue.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // SELETOR DE MODO DE NOTA
                    if (_editando) _buildSeletorModoNota(),
                    const SizedBox(height: 16),

                    if (_modoNotaTotal) ...[
                      // MODO NOTA TOTAL
                      _buildCampoNotaTotal(),
                    ] else ...[
                      // MODO POR CRITÉRIOS
                      // AVALIAÇÃO DO TRABALHO ESCRITO
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AVALIAÇÃO DO TRABALHO ESCRITO (Máximo: 8,5 pontos)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),

                      ..._categorias['Avaliação do Trabalho Escrito']!
                          .map(_buildCampoNota)
                          .toList(),

                      const SizedBox(height: 24),

                      // AVALIAÇÃO DA APRESENTAÇÃO ORAL
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AVALIAÇÃO DA APRESENTAÇÃO ORAL (Máximo: 1,5 pontos)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),

                      ..._categorias['Avaliação da Apresentação Oral']!
                          .map(_buildCampoNota)
                          .toList(),

                      const SizedBox(height: 24),
                    ],

                    // RESUMO DAS NOTAS
                    _buildResumoNotas(),

                    const SizedBox(height: 24),

                    // BOTÃO SALVAR
                    if (_editando)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text(
                            'SALVAR NOTAS',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _salvarNotas,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _notaTotalController.dispose();
    super.dispose();
  }
}
