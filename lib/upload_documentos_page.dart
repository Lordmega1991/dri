import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadDocumentosPage extends StatefulWidget {
  const UploadDocumentosPage({Key? key}) : super(key: key);

  @override
  State<UploadDocumentosPage> createState() => _UploadDocumentosPageState();
}

class _UploadDocumentosPageState extends State<UploadDocumentosPage> {
  final supabase = Supabase.instance.client;
  final nomeController = TextEditingController();

  PlatformFile? arquivoTermo;
  PlatformFile? arquivoTCC;

  bool _isUploading = false;
  String _uploadStatus = '';

  // ID da pasta padrão do Google Drive
  final String _driveFolderId = '1Fcgk8FIT8a5P5CoLjFPIZS1hMPvL0hlq';

  @override
  void initState() {
    super.initState();
    _preencherNomeUsuario();
  }

  Future<void> _preencherNomeUsuario() async {
    try {
      final session = supabase.auth.currentSession;
      final user = session?.user;
      if (user == null) return;

      final meta = user.userMetadata ?? {};
      String? nomeFromMeta = meta['full_name'] as String? ??
          meta['name'] as String? ??
          meta['given_name'] as String?;

      if (nomeFromMeta == null || nomeFromMeta.trim().isEmpty) {
        final email = user.email;
        if (email != null && email.contains('@')) {
          nomeFromMeta = email.split('@').first;
        }
      }

      if (nomeFromMeta != null && nomeFromMeta.isNotEmpty) {
        nomeController.text = nomeFromMeta;
        setState(() {});
      }
    } catch (e) {
      print('Erro ao obter nome do usuário: $e');
    }
  }

  Future<void> selecionarArquivo(bool isTCC) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        if (isTCC) {
          arquivoTCC = result.files.first;
        } else {
          arquivoTermo = result.files.first;
        }
      });

      _showSuccess('Arquivo selecionado: ${result.files.first.name}');
    }
  }

  // FUNÇÃO PRINCIPAL DE ENVIO
  Future<void> enviarArquivos() async {
    if (arquivoTermo == null || arquivoTCC == null) {
      _showError('Selecione ambos os arquivos antes de enviar.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Preparando upload...';
    });

    try {
      // Upload do Termo
      await _uploadArquivo(arquivoTermo!, 'Termo');

      // Upload do TCC
      await _uploadArquivo(arquivoTCC!, 'TCC');

      setState(() {
        _uploadStatus = '✅ Ambos os arquivos enviados com sucesso!';
      });

      _showSuccess('Termo e TCC enviados com sucesso!');

      // Limpar seleção após sucesso
      setState(() {
        arquivoTermo = null;
        arquivoTCC = null;
      });
    } catch (e) {
      setState(() {
        _uploadStatus = '❌ Erro no envio: $e';
      });
      _showError('Erro no upload: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // FUNÇÃO DE UPLOAD INDIVIDUAL
  Future<void> _uploadArquivo(PlatformFile arquivo, String tipo) async {
    final session = supabase.auth.currentSession;
    if (session == null) throw Exception('Usuário não autenticado');

    final nomeUsuario = nomeController.text.isNotEmpty
        ? nomeController.text.replaceAll(RegExp(r'[^\w\s]'), '').trim()
        : 'Usuario';

    final now = DateTime.now();
    final dataStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final nomeArquivo = '$nomeUsuario - $tipo - $dataStr.pdf';

    final bytes = arquivo.bytes;
    if (bytes == null) throw Exception('Arquivo não disponível');
    final fileData = base64.encode(bytes);

    setState(() {
      _uploadStatus = 'Enviando "$tipo"...';
    });

    // Registrar no histórico antes do upload
    final uploadRecord = await supabase
        .from('upload_history')
        .insert({
          'user_id': session.user.id,
          'file_name': nomeArquivo,
          'file_size': bytes.length,
          'status': 'uploading',
          'user_folder_id': _driveFolderId,
        })
        .select()
        .single();

    final uploadId = uploadRecord['id'];

    try {
      final response = await http.post(
        Uri.parse(
            'https://gptrgiilbdpnnftovpfs.supabase.co/functions/v1/upload-to-drive'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: json.encode({
          'fileName': nomeArquivo,
          'fileData': fileData,
          'folderId': _driveFolderId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Atualizar histórico com sucesso
        await supabase.from('upload_history').update({
          'drive_file_id': data['fileId'],
          'status': 'completed',
        }).eq('id', uploadId);

        setState(() {
          _uploadStatus = '✅ "$tipo" enviado com sucesso!';
        });
      } else {
        throw Exception(
            'Erro ao enviar $tipo: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Atualizar histórico com falha
      await supabase.from('upload_history').update({
        'status': 'failed',
      }).eq('id', uploadId);
      rethrow;
    }
  }

  // WIDGET DE ARQUIVOS
  Widget _arquivoTile(
      String label, PlatformFile? arquivo, VoidCallback onPressed) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(arquivo?.name ?? 'Nenhum arquivo selecionado'),
            if (arquivo != null)
              Text(
                '${(arquivo.size / 1024 / 1024).toStringAsFixed(2)} MB',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
          ),
          child: const Text('Selecionar'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLarge = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Envio de Termo e TCC'),
        backgroundColor: const Color(0xFF667eea),
      ),
      body: Padding(
        padding: EdgeInsets.all(isLarge ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informações do usuário
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.person,
                        size: 40, color: Color(0xFF667eea)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomeController.text.isNotEmpty
                                ? nomeController.text
                                : 'Usuário',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            supabase.auth.currentUser?.email ??
                                'Email não disponível',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '📁 Arquivos serão salvos na pasta da DRI',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Campos de upload
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nome do Aluno',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Nome completo do aluno',
                      ),
                    ),
                    const SizedBox(height: 20),

                    _arquivoTile('Termo de Compromisso', arquivoTermo,
                        () => selecionarArquivo(false)),
                    _arquivoTile('TCC/Projeto Final', arquivoTCC,
                        () => selecionarArquivo(true)),

                    const SizedBox(height: 30),

                    // Botão de envio
                    Center(
                      child: ElevatedButton.icon(
                        icon: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 8),
                          child: Text(
                            _isUploading
                                ? 'Enviando...'
                                : 'Enviar Ambos os Arquivos',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        onPressed: _isUploading ? null : enviarArquivos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Status do upload
                    if (_uploadStatus.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _uploadStatus,
                            style: const TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
