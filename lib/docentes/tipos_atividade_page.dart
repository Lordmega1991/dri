import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TiposAtividadePage extends StatefulWidget {
  const TiposAtividadePage({super.key});

  @override
  State<TiposAtividadePage> createState() => _TiposAtividadePageState();
}

class _TiposAtividadePageState extends State<TiposAtividadePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _unidadeMedidaController = TextEditingController();

  bool _loading = false;
  bool _editando = false;
  String _tipoAtividadeEditId = '';
  List<Map<String, dynamic>> _tiposAtividade = [];
  List<Map<String, dynamic>> _tiposAtividadeFiltrados = [];
  final _searchController = TextEditingController();

  // Opções pré-definidas
  final List<String> _categoriasOptions = [
    'Ensino',
    'Pesquisa',
    'Extensão',
    'Administrativa',
    'Outra'
  ];

  final List<String> _unidadesMedidaOptions = [
    'horas',
    'quantidade',
    'pontos',
    'outro'
  ];

  @override
  void initState() {
    super.initState();
    _carregarTiposAtividade();
    _searchController.addListener(_filtrarTiposAtividade);
    _unidadeMedidaController.text = 'horas'; // Valor padrão
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _categoriaController.dispose();
    _descricaoController.dispose();
    _unidadeMedidaController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarTiposAtividade() async {
    setState(() => _loading = true);

    try {
      final response = await supabase
          .from('tipos_atividade')
          .select('*')
          .order('categoria')
          .order('nome');

      setState(() {
        _tiposAtividade = (response as List).cast<Map<String, dynamic>>();
        _tiposAtividadeFiltrados = List.from(_tiposAtividade);
      });
    } catch (e) {
      _mostrarErro('Erro ao carregar tipos de atividade: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filtrarTiposAtividade() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() => _tiposAtividadeFiltrados = List.from(_tiposAtividade));
    } else {
      setState(() {
        _tiposAtividadeFiltrados = _tiposAtividade.where((tipo) {
          final nome = tipo['nome']?.toString().toLowerCase() ?? '';
          final categoria = tipo['categoria']?.toString().toLowerCase() ?? '';
          final descricao = tipo['descricao']?.toString().toLowerCase() ?? '';

          return nome.contains(query) ||
              categoria.contains(query) ||
              descricao.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _salvarTipoAtividade() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final dados = {
        'nome': _nomeController.text.trim(),
        'categoria': _categoriaController.text.trim(),
        'descricao': _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        'unidade_medida': _unidadeMedidaController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_editando) {
        await supabase
            .from('tipos_atividade')
            .update(dados)
            .eq('id', _tipoAtividadeEditId);
        _mostrarSucesso('Tipo de atividade atualizado!');
      } else {
        await supabase.from('tipos_atividade').insert(dados);
        _mostrarSucesso('Tipo de atividade cadastrado!');
      }

      _limparFormulario();
      await _carregarTiposAtividade();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        _mostrarErro('Já existe um tipo de atividade com este nome!');
      } else {
        _mostrarErro('Erro ao salvar: ${e.message}');
      }
    } catch (e) {
      _mostrarErro('Erro ao salvar: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _editarTipoAtividade(Map<String, dynamic> tipoAtividade) {
    setState(() {
      _editando = true;
      _tipoAtividadeEditId = tipoAtividade['id'];
      _nomeController.text = tipoAtividade['nome'] ?? '';
      _categoriaController.text = tipoAtividade['categoria'] ?? '';
      _descricaoController.text = tipoAtividade['descricao'] ?? '';
      _unidadeMedidaController.text =
          tipoAtividade['unidade_medida'] ?? 'horas';
    });
  }

  Future<void> _excluirTipoAtividade(Map<String, dynamic> tipoAtividade) async {
    final confirmacao = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
            'Tem certeza que deseja excluir o tipo de atividade "${tipoAtividade['nome']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmacao == true) {
      try {
        await supabase
            .from('tipos_atividade')
            .delete()
            .eq('id', tipoAtividade['id']);

        _mostrarSucesso('Tipo de atividade excluído!');
        await _carregarTiposAtividade();
      } catch (e) {
        _mostrarErro('Erro ao excluir: $e');
      }
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nomeController.clear();
    _categoriaController.clear();
    _descricaoController.clear();
    _unidadeMedidaController.text = 'horas';
    setState(() {
      _editando = false;
      _tipoAtividadeEditId = '';
    });
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatarData(String? dataString) {
    if (dataString == null) return 'N/A';
    try {
      final data = DateTime.parse(dataString);
      return DateFormat('dd/MM/yy').format(data);
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editando ? 'Editar Tipo de Atividade' : 'Tipos de Atividade',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 40,
        actions: [
          if (_editando)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: _limparFormulario,
              tooltip: 'Cancelar',
              padding: const EdgeInsets.all(6),
            ),
        ],
      ),
      body: _loading && _tiposAtividade.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FORMULÁRIO DE CADASTRO
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _editando
                                  ? 'EDITAR TIPO DE ATIVIDADE'
                                  : 'NOVO TIPO DE ATIVIDADE',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667eea),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                // Nome
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _nomeController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'Nome*',
                                      labelStyle: TextStyle(fontSize: 12),
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 10),
                                      isDense: false,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Nome obrigatório';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Categoria (Dropdown)
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: _categoriaController.text.isEmpty
                                        ? null
                                        : _categoriaController.text,
                                    onChanged: (value) {
                                      _categoriaController.text = value ?? '';
                                    },
                                    items: _categoriasOptions.map((categoria) {
                                      return DropdownMenuItem(
                                        value: categoria,
                                        child: Text(categoria,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    decoration: const InputDecoration(
                                      labelText: 'Categoria*',
                                      labelStyle: TextStyle(fontSize: 12),
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 10),
                                      isDense: false,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Selecione uma categoria';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Unidade de Medida (Dropdown)
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    value: _unidadeMedidaController.text,
                                    onChanged: (value) {
                                      _unidadeMedidaController.text =
                                          value ?? 'horas';
                                    },
                                    items:
                                        _unidadesMedidaOptions.map((unidade) {
                                      return DropdownMenuItem(
                                        value: unidade,
                                        child: Text(unidade,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    decoration: const InputDecoration(
                                      labelText: 'Unidade*',
                                      labelStyle: TextStyle(fontSize: 12),
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 10),
                                      isDense: false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // BOTÕES
                                SizedBox(
                                  width: 140,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _loading
                                              ? null
                                              : _salvarTipoAtividade,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF667eea),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            minimumSize: const Size(0, 34),
                                          ),
                                          child: _loading
                                              ? const SizedBox(
                                                  height: 14,
                                                  width: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 1.5),
                                                )
                                              : Text(
                                                  _editando
                                                      ? 'ATUALIZAR'
                                                      : 'CADASTRAR',
                                                  style: const TextStyle(
                                                      fontSize: 11),
                                                ),
                                        ),
                                      ),
                                      if (_editando) ...[
                                        const SizedBox(width: 6),
                                        SizedBox(
                                          width: 50,
                                          child: OutlinedButton(
                                            onPressed: _limparFormulario,
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              minimumSize: const Size(0, 34),
                                            ),
                                            child: const Text(
                                              'CANCELAR',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Descrição (campo maior)
                            TextFormField(
                              controller: _descricaoController,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Descrição (opcional)',
                                labelStyle: TextStyle(fontSize: 12),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                                isDense: false,
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // CABEÇALHO DA TABELA
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Text(
                          'TIPOS DE ATIVIDADE CADASTRADOS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF764ba2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _tiposAtividadeFiltrados.length.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Pesquisar por nome, categoria...',
                              hintStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              isDense: false,
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 14),
                                      onPressed: () {
                                        _searchController.clear();
                                        _filtrarTiposAtividade();
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 24, minHeight: 24),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: _carregarTiposAtividade,
                          tooltip: 'Recarregar',
                          padding: const EdgeInsets.all(4),
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),

                  // TABELA ESTILO EXCEL
                  _tiposAtividadeFiltrados.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.category_outlined,
                                  size: 36, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Nenhum tipo de atividade encontrado',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Cadastre os primeiros tipos de atividade',
                                style:
                                    TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : Card(
                          elevation: 1,
                          child: Column(
                            children: [
                              // CABEÇALHO DA TABELA
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  border: const Border(
                                    bottom: BorderSide(
                                        color: Colors.grey, width: 0.8),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    // Nome
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          'NOME',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Categoria
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          'CATEGORIA',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Unidade
                                    Expanded(
                                      flex: 1,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          'UNIDADE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Descrição
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          'DESCRIÇÃO',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Data
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          'CADASTRO',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Ações
                                    SizedBox(
                                      width: 80,
                                      child: Center(
                                        child: Text(
                                          'AÇÕES',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // LINHAS DA TABELA
                              ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: _tiposAtividadeFiltrados.length,
                                itemBuilder: (context, index) {
                                  final tipo = _tiposAtividadeFiltrados[index];
                                  return _buildTableRow(tipo, index);
                                },
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> tipo, int index) {
    Color _getCorCategoria(String categoria) {
      switch (categoria.toLowerCase()) {
        case 'ensino':
          return Colors.blue;
        case 'pesquisa':
          return Colors.green;
        case 'extensão':
          return Colors.orange;
        case 'administrativa':
          return Colors.purple;
        default:
          return Colors.grey;
      }
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey[50],
        border: const Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // COLUNA NOME
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                tipo['nome'] ?? 'N/A',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // COLUNA CATEGORIA
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCorCategoria(tipo['categoria'] ?? '')
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _getCorCategoria(tipo['categoria'] ?? '')
                        .withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  tipo['categoria'] ?? 'N/A',
                  style: TextStyle(
                    fontSize: 10,
                    color: _getCorCategoria(tipo['categoria'] ?? ''),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // COLUNA UNIDADE
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                tipo['unidade_medida'] ?? 'horas',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // COLUNA DESCRIÇÃO
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                tipo['descricao'] ?? 'Sem descrição',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // COLUNA DATA
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _formatarData(tipo['created_at']),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // COLUNA AÇÕES
          SizedBox(
            width: 80,
            child: Center(
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 14, color: Colors.grey),
                offset: const Offset(0, 45),
                onSelected: (value) {
                  switch (value) {
                    case 'editar':
                      _editarTipoAtividade(tipo);
                      break;
                    case 'excluir':
                      _excluirTipoAtividade(tipo);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 14),
                        const SizedBox(width: 6),
                        Text('Editar', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excluir',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 14, color: Colors.red),
                        const SizedBox(width: 6),
                        Text('Excluir',
                            style: TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
