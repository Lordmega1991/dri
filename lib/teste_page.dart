// teste_page.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class TestePage extends StatefulWidget {
  final String folderId;
  final String nomeUsuario;

  const TestePage(
      {super.key, required this.folderId, required this.nomeUsuario});

  @override
  State<TestePage> createState() => _TestePageState();
}

class _TestePageState extends State<TestePage> {
  final supabase = Supabase.instance.client;

  PlatformFile? arquivoTermo;
  PlatformFile? arquivoTCC;

  bool _isUploading = false;
  String _uploadStatus = '';

  Future<void> selecionarArquivo(bool isTCC) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
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

  Future<void> enviarArquivos() async {
    if (arquivoTermo == null && arquivoTCC == null) {
      _showError('Selecione pelo menos um arquivo.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Preparando upload...';
    });

    try {
      if (arquivoTermo != null) await _uploadArquivo(arquivoTermo!, 'Termo');
      if (arquivoTCC != null) await _uploadArquivo(arquivoTCC!, 'TCC');

      setState(() {
        _uploadStatus = '✅ Arquivos enviados com sucesso!';
        arquivoTermo = null;
        arquivoTCC = null;
      });

      _showSuccess('Upload concluído!');
    } catch (e) {
      _showError('Erro no upload: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadArquivo(PlatformFile arquivo, String tipo) async {
    final session = supabase.auth.currentSession;
    if (session == null) throw Exception('Usuário não autenticado');

    final nomeUsuario =
        widget.nomeUsuario.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final now = DateTime.now();
    final dataStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final nomeArquivo = '$nomeUsuario - $tipo - $dataStr.pdf';

    final bytes = arquivo.bytes;
    if (bytes == null) throw Exception('Arquivo não disponível');
    final fileData = base64.encode(bytes);

    setState(() => _uploadStatus = 'Enviando "$tipo"...');

    // Inserir registro no Supabase
    final uploadRecord = await supabase
        .from('upload_history')
        .insert({
          'user_id': session.user.id,
          'file_name': nomeArquivo,
          'file_size': bytes.length,
          'status': 'uploading',
          'user_folder_id': widget.folderId,
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
          'folderId': widget.folderId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        await supabase.from('upload_history').update({
          'drive_file_id': data['fileId'],
          'status': 'completed',
        }).eq('id', uploadId);
      } else {
        throw Exception('Erro ao enviar $tipo: ${response.statusCode}');
      }
    } catch (e) {
      await supabase.from('upload_history').update({
        'status': 'failed',
      }).eq('id', uploadId);
      rethrow;
    }
  }

  Widget _arquivoTile(
      String label, PlatformFile? arquivo, VoidCallback onPressed) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(arquivo?.name ?? 'Nenhum arquivo selecionado'),
        trailing: ElevatedButton(
          onPressed: onPressed,
          child: const Text('Selecionar'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload - ${widget.nomeUsuario}'),
        backgroundColor: const Color(0xFF667eea),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _arquivoTile('Termo', arquivoTermo, () => selecionarArquivo(false)),
            _arquivoTile('TCC', arquivoTCC, () => selecionarArquivo(true)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _isUploading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(
                    _isUploading ? 'Enviando...' : 'Enviar Todos os Arquivos',
                    style: const TextStyle(fontSize: 16)),
              ),
              onPressed: _isUploading ? null : enviarArquivos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            if (_uploadStatus.isNotEmpty)
              Text(_uploadStatus, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green));
}
