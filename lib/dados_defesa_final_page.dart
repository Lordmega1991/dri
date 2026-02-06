import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DadosDefesaFinalPage extends StatefulWidget {
  final int defesaId;
  final Map<String, dynamic> defesa;

  const DadosDefesaFinalPage({
    super.key,
    required this.defesaId,
    required this.defesa,
  });

  @override
  State<DadosDefesaFinalPage> createState() => _DadosDefesaFinalPageState();
}

class _DadosDefesaFinalPageState extends State<DadosDefesaFinalPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _dataAprovacaoController =
      TextEditingController();
  final TextEditingController _resultadoController = TextEditingController();
  final TextEditingController _observacoesController = TextEditingController();

  DateTime? _dataAprovacao;
  bool _loading = true;
  bool _editando = false;
  Map<String, dynamic>? _dadosExistentes;

  @override
  void initState() {
    super.initState();
    _carregarDadosExistentes();
  }

  Future<void> _carregarDadosExistentes() async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await supabase
          .from('dados_defesa_final')
          .select()
          .eq('defesa_id', widget.defesaId)
          .maybeSingle();

      if (response != null) {
        _dadosExistentes = Map<String, dynamic>.from(response);
        _preencherCamposComDadosExistentes();
        _editando = false;
      } else {
        _editando = true;
      }
    } catch (e) {
      print('Erro ao carregar dados da defesa final: $e');
      _editando = true;
    }

    setState(() {
      _loading = false;
    });
  }

  void _preencherCamposComDadosExistentes() {
    if (_dadosExistentes != null) {
      if (_dadosExistentes!['data_aprovacao'] != null) {
        _dataAprovacao = DateTime.parse(_dadosExistentes!['data_aprovacao']);
        _dataAprovacaoController.text =
            DateFormat('dd/MM/yyyy').format(_dataAprovacao!);
      }
      _resultadoController.text = _dadosExistentes!['resultado'] ?? '';
      _observacoesController.text =
          _dadosExistentes!['observacoes_finais'] ?? '';
    }
  }

  Future<void> _selecionarData() async {
    final DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: _dataAprovacao ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667eea),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF667eea),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (dataSelecionada != null) {
      setState(() {
        _dataAprovacao = dataSelecionada;
        _dataAprovacaoController.text =
            DateFormat('dd/MM/yyyy').format(dataSelecionada);
      });
    }
  }

  Future<void> _salvarDados() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dataAprovacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data de aprovação')),
      );
      return;
    }

    final dados = {
      'defesa_id': widget.defesaId,
      'data_aprovacao': _dataAprovacao!.toIso8601String().split('T')[0],
      'resultado': _resultadoController.text.trim(),
      'observacoes_finais': _observacoesController.text.trim(),
    };

    try {
      if (_dadosExistentes != null) {
        // Atualizar dados existentes
        await supabase
            .from('dados_defesa_final')
            .update(dados)
            .eq('defesa_id', widget.defesaId);
      } else {
        // Inserir novos dados
        await supabase.from('dados_defesa_final').insert(dados);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados da defesa salvos com sucesso!')),
      );

      await _carregarDadosExistentes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar dados: $e')),
      );
    }
  }

  void _habilitarEdicao() {
    setState(() {
      _editando = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados Finais da Defesa'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          if (_dadosExistentes != null && !_editando)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _habilitarEdicao,
              tooltip: 'Editar Dados',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informações da defesa
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informações da Defesa',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF667eea),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoItem(
                                  'Discente', widget.defesa['discente'] ?? ''),
                              _buildInfoItem(
                                  'Título', widget.defesa['titulo'] ?? ''),
                              _buildInfoItem('Orientador',
                                  widget.defesa['orientador'] ?? ''),
                              if (widget.defesa['coorientador'] != null &&
                                  widget.defesa['coorientador']
                                      .toString()
                                      .isNotEmpty)
                                _buildInfoItem('Coorientador',
                                    widget.defesa['coorientador']),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_dadosExistentes != null && !_editando)
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
                                  'Dados já preenchidos. Clique no ícone de edição para modificar.',
                                  style: TextStyle(color: Colors.blue.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Data de Aprovação
                      TextFormField(
                        controller: _dataAprovacaoController,
                        decoration: InputDecoration(
                          labelText: 'Aprovado em *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _selecionarData,
                          ),
                        ),
                        readOnly: true,
                        onTap: _selecionarData,
                        validator: (value) {
                          if (_dataAprovacao == null) {
                            return 'Selecione a data de aprovação';
                          }
                          return null;
                        },
                        enabled: _editando,
                      ),
                      const SizedBox(height: 16),

                      // Resultado
                      TextFormField(
                        controller: _resultadoController,
                        decoration: const InputDecoration(
                          labelText: 'Resultado *',
                          border: OutlineInputBorder(),
                          hintText:
                              'Ex: Aprovado com distinção, Aprovado, etc.',
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o resultado da defesa';
                          }
                          return null;
                        },
                        enabled: _editando,
                      ),
                      const SizedBox(height: 16),

                      // Observações Finais
                      TextFormField(
                        controller: _observacoesController,
                        decoration: const InputDecoration(
                          labelText: 'Observações Finais',
                          border: OutlineInputBorder(),
                          hintText:
                              'Observações complementares sobre a defesa...',
                        ),
                        maxLines: 4,
                        enabled: _editando,
                      ),
                      const SizedBox(height: 24),

                      // Botão Salvar
                      if (_editando)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text(
                              'SALVAR DADOS DA DEFESA',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _salvarDados,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Não informado',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dataAprovacaoController.dispose();
    _resultadoController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }
}
