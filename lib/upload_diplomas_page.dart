import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadDiplomasPage extends StatefulWidget {
  const UploadDiplomasPage({super.key});

  @override
  State<UploadDiplomasPage> createState() => _UploadDiplomasPageState();
}

class _UploadDiplomasPageState extends State<UploadDiplomasPage> {
  final supabase = Supabase.instance.client;
  bool uploading = false;
  String? _folderId;
  String? _userName;

  // ✅ CONTROLE DOS 7 DOCUMENTOS
  final Map<String, Uint8List?> _documentos = {
    'identificacao_civil': null,
    'certidao_nascimento_casamento': null,
    'quitação_eleitoral': null,
    'conclusao_ensino_medio': null,
    'declaracao_nada_consta_biblioteca': null,
    'certificado_reservista': null,
    'ato_naturalizacao': null,
  };

  final Map<String, String> _nomesArquivos = {
    'identificacao_civil': '',
    'certidao_nascimento_casamento': '',
    'quitação_eleitoral': '',
    'conclusao_ensino_medio': '',
    'declaracao_nada_consta_biblioteca': '',
    'certificado_reservista': '',
    'ato_naturalizacao': '',
  };

  @override
  void initState() {
    super.initState();
    _getUserFolder();
  }

  Future<void> _getUserFolder() async {
    final user = supabase.auth.currentUser!;
    setState(() {
      _userName =
          user.userMetadata?['full_name'] ?? user.email?.split('@').first;
    });

    try {
      final pasta = await supabase
          .from('user_folder_diplomas')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      setState(() {
        _folderId = pasta?['folder_id'] as String?;
      });
    } catch (e) {
      print('Erro ao buscar pasta do usuário: $e');
    }
  }

  Future<void> _pickDocument(String documentType, String documentName) async {
    if (_folderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Criando pasta...')),
      );
      await _createUserFolder();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _documentos[documentType] = result.files.first.bytes;
      _nomesArquivos[documentType] = result.files.first.name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$documentName selecionado!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _uploadAllDocuments() async {
    if (_folderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasta não encontrada.')),
      );
      return;
    }

    final documentosSelecionados =
        _documentos.entries.where((entry) => entry.value != null).toList();

    if (documentosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um documento.')),
      );
      return;
    }

    setState(() => uploading = true);

    int uploadsSucesso = 0;
    int uploadsErro = 0;

    for (final doc in documentosSelecionados) {
      try {
        await _enviarArquivo(doc.value!, _getNomeArquivoFormatado(doc.key));
        uploadsSucesso++;
      } catch (e) {
        print('Erro no upload de ${doc.key}: $e');
        uploadsErro++;
      }
    }

    setState(() => uploading = false);

    if (uploadsErro == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$uploadsSucesso documento(s) enviado(s)!'),
          backgroundColor: Colors.green,
        ),
      );
      _limparDocumentos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$uploadsSucesso sucesso(s), $uploadsErro erro(s)'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _getNomeArquivoFormatado(String documentType) {
    final nomeUsuario = _userName?.replaceAll(' ', '_') ?? 'usuario';
    final nomesDocumentos = {
      'identificacao_civil': 'Identificacao_Civil',
      'certidao_nascimento_casamento': 'Certidao_Nascimento_Casamento',
      'quitação_eleitoral': 'Quitacao_Eleitoral',
      'conclusao_ensino_medio': 'Conclusao_Ensino_Medio',
      'declaracao_nada_consta_biblioteca': 'Declaracao_Nada_Consta_Biblioteca',
      'certificado_reservista': 'Certificado_Reservista',
      'ato_naturalizacao': 'Ato_Naturalizacao',
    };

    return '$nomeUsuario-${nomesDocumentos[documentType]}.pdf';
  }

  void _limparDocumentos() {
    setState(() {
      for (var key in _documentos.keys) {
        _documentos[key] = null;
        _nomesArquivos[key] = '';
      }
    });
  }

  Future<void> _createUserFolder() async {
    setState(() => uploading = true);

    try {
      final user = supabase.auth.currentUser!;
      final nomeUsuario =
          user.userMetadata?['full_name'] ?? user.email!.split('@').first;

      final session = supabase.auth.currentSession;
      final token = session?.accessToken;
      if (token == null) throw Exception('Usuário não autenticado');

      final response = await http.post(
        Uri.parse('https://us-central1-dri-ufpb.cloudfunctions.net/criarPasta'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'nomePasta': nomeUsuario}),
      );

      if (response.statusCode != 200) {
        throw Exception('Erro ao criar pasta: ${response.body}');
      }

      final data = json.decode(response.body);
      final folderId = data['idPasta'] as String?;
      if (folderId == null) throw Exception('ID da pasta não retornado');

      await supabase.from('user_folder_diplomas').insert({
        'user_id': user.id,
        'folder_id': folderId,
      });

      setState(() {
        _folderId = folderId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pasta criada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar pasta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => uploading = false);
    }
  }

  Future<void> _enviarArquivo(Uint8List fileBytes, String fileName) async {
    final session = supabase.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) throw Exception('Usuário não autenticado');

    final fileBase64 = base64Encode(fileBytes);

    final uri = Uri.parse(
        'https://us-central1-dri-ufpb.cloudfunctions.net/uploadDiploma');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'folderId': _folderId,
        'file': fileBase64,
        'fileName': fileName,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception('Erro ao enviar arquivo: ${errorData['mensagem']}');
    }

    final responseData = json.decode(response.body);
    if (responseData['status'] != 'sucesso') {
      throw Exception('Erro no upload: ${responseData['mensagem']}');
    }
  }

  Widget _buildDocumentCard(
      String documentType, String title, String description,
      {bool obrigatorio = true}) {
    final hasFile = _documentos[documentType] != null;
    final fileName = _nomesArquivos[documentType];
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    // ✅ LAYOUT DIFERENCIADO PARA MOBILE
    if (!isLargeScreen) {
      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: hasFile
                ? Colors.green
                : const Color(0xFF667eea).withOpacity(0.3),
            width: hasFile ? 2.0 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ CABEÇALHO MOBILE
              Row(
                children: [
                  if (hasFile)
                    Icon(Icons.check_circle, color: Colors.green, size: 20)
                  else
                    Icon(Icons.upload_file,
                        color: const Color(0xFF667eea), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF667eea),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!obrigatorio) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: const Text(
                                  'Opcional',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ✅ NOME DO ARQUIVO (se houver)
              if (hasFile && (fileName?.isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    fileName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // ✅ BOTÕES MOBILE
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          hasFile ? Icons.change_circle : Icons.upload,
                          size: 18,
                        ),
                        label: Text(
                          hasFile ? 'Alterar' : 'Selecionar PDF',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () => _pickDocument(documentType, title),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              hasFile ? Colors.orange : const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      width: 44,
                      child: IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () {
                          setState(() {
                            _documentos[documentType] = null;
                            _nomesArquivos[documentType] = '';
                          });
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ✅ LAYOUT WEB (MANTIDO COMO ESTAVA)
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              hasFile ? Colors.green : const Color(0xFF667eea).withOpacity(0.3),
          width: hasFile ? 2.0 : 1.0,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        height: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasFile)
                  Icon(Icons.check_circle, color: Colors.green, size: 16)
                else
                  Icon(Icons.upload_file,
                      color: const Color(0xFF667eea), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF667eea),
                                height: 1.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!obrigatorio) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Text(
                                'Opcional',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasFile && (fileName?.isNotEmpty ?? false))
              Text(
                fileName != null && fileName.length > 25
                    ? '${fileName!.substring(0, 25)}...'
                    : fileName!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green[700],
                  fontStyle: FontStyle.italic,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        hasFile ? Icons.change_circle : Icons.upload,
                        size: 16,
                      ),
                      label: Text(
                        hasFile ? 'Alterar' : 'Selecionar PDF',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: () => _pickDocument(documentType, title),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            hasFile ? Colors.orange : const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasFile) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () {
                        setState(() {
                          _documentos[documentType] = null;
                          _nomesArquivos[documentType] = '';
                        });
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    // ✅ LISTA DE DOCUMENTOS ORGANIZADA COM RESERVISTA OPCIONAL
    final documentos = [
      {
        'type': 'identificacao_civil',
        'title': '1. Identificação Civil',
        'description': 'RG com foto, número e órgão expedidor',
        'obrigatorio': true
      },
      {
        'type': 'certidao_nascimento_casamento',
        'title': '2. Certidão Civil',
        'description': 'Certidão de nascimento ou casamento',
        'obrigatorio': true
      },
      {
        'type': 'quitação_eleitoral',
        'title': '3. Quitação Eleitoral',
        'description': 'Certidão atualizada sem pendências',
        'obrigatorio': true
      },
      {
        'type': 'conclusao_ensino_medio',
        'title': '4. Ensino Médio',
        'description': 'Certificado de conclusão',
        'obrigatorio': true
      },
      {
        'type': 'declaracao_nada_consta_biblioteca',
        'title': '5. Nada Consta Biblioteca',
        'description': 'Declaração de quitação',
        'obrigatorio': true
      },
      {
        'type': 'certificado_reservista',
        'title': '6. Reservista (Homens)',
        'description': 'Certificado militar - opcional',
        'obrigatorio': false
      },
      {
        'type': 'ato_naturalizacao',
        'title': '7. Naturalização',
        'description': 'Ato DOU (estrangeiros)',
        'obrigatorio': false
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Documentos para Diploma',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ CABEÇALHO
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Documentação Necessária',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Usuário: ${_userName ?? 'Carregando...'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pasta: ${_folderId != null ? 'Configurada ✓' : 'Não criada'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _folderId != null
                            ? Colors.green[100]
                            : Colors.orange[100],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ✅ LAYOUT RESPONSIVO
            Expanded(
              child: SingleChildScrollView(
                child: isLargeScreen
                    ?
                    // ✅ WEB: GRID 2x4
                    GridView.count(
                        crossAxisCount: 5,
                        crossAxisSpacing: 35,
                        mainAxisSpacing: 25,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.2,
                        children: documentos.map((doc) {
                          return _buildDocumentCard(
                            doc['type'] as String,
                            doc['title'] as String,
                            doc['description'] as String,
                            obrigatorio: doc['obrigatorio'] as bool,
                          );
                        }).toList(),
                      )
                    :
                    // ✅ MOBILE: LISTA VERTICAL SIMPLIFICADA
                    Column(
                        children: documentos.map((doc) {
                          return _buildDocumentCard(
                            doc['type'] as String,
                            doc['title'] as String,
                            doc['description'] as String,
                            obrigatorio: doc['obrigatorio'] as bool,
                          );
                        }).toList(),
                      ),
              ),
            ),

            // ✅ BOTÃO DE UPLOAD
            Container(
              padding: const EdgeInsets.only(top: 16),
              width: double.infinity,
              child: uploading
                  ? Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enviando documentos...',
                          style: TextStyle(
                            fontSize: isLargeScreen ? 20 : 16,
                            color: const Color(0xFF667eea),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_upload, size: 20),
                        label: Text(
                          'Enviar Todos os Documentos',
                          style: TextStyle(
                              fontSize: isLargeScreen ? 16 : 14,
                              fontWeight: FontWeight.w600),
                        ),
                        onPressed: _uploadAllDocuments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
