import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EmissaoDiplomasPage extends StatefulWidget {
  const EmissaoDiplomasPage({Key? key}) : super(key: key);

  @override
  State<EmissaoDiplomasPage> createState() => _EmissaoDiplomasPageState();
}

class _EmissaoDiplomasPageState extends State<EmissaoDiplomasPage> {
  final supabase = Supabase.instance.client;
  final nomeController = TextEditingController();

  final Map<String, PlatformFile?> arquivos = {
    'RG do discente': null,
    'Certidão de Nascimento ou Casamento': null,
    'Certidão de Quitação Eleitoral': null,
    'Certificado de Conclusão do Ensino Médio': null,
    'Ato de Naturalização (se aplicável)': null,
    'Declaração de Nada Consta da Biblioteca': null,
    'Certificado de Reservista ou Alistamento Militar': null,
  };

  bool _isUploading = false;
  String _uploadStatus = '';
  final String _driveFolderId =
      '1Fcgk8FIT8a5P5CoLjFPIZS1hMPvL0hlq'; // Pasta padrão no Drive

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

  Future<void> selecionarArquivo(String docNome) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        arquivos[docNome] = result.files.first;
      });
      _showSuccess('Selecionado: ${result.files.first.name}');
    }
  }

  Future<void> enviarTodosArquivos() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      _showError('Usuário não autenticado.');
      return;
    }

    final arquivosSelecionados =
        arquivos.entries.where((e) => e.value != null).toList();

    if (arquivosSelecionados.isEmpty) {
      _showError('Selecione ao menos um arquivo antes de enviar.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Iniciando envio...';
    });

    try {
      for (final entry in arquivosSelecionados) {
        final nomeDoc = entry.key;
        final arquivo = entry.value!;
        await _uploadArquivo(arquivo, nomeDoc, session);
      }

      _showSuccess('✅ Todos os documentos enviados com sucesso!');
      setState(() {
        arquivos.updateAll((key, value) => null);
        _uploadStatus = 'Envio concluído.';
      });
    } catch (e) {
      _showError('Erro ao enviar arquivos: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadArquivo(
      PlatformFile arquivo, String docNome, Session session) async {
    final nomeUsuario =
        nomeController.text.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final now = DateTime.now();
    final dataStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final nomeArquivo = '$nomeUsuario - $docNome - $dataStr.pdf';

    final bytes = arquivo.bytes;
    if (bytes == null) throw Exception('Arquivo sem conteúdo');
    final fileData = base64.encode(bytes);

    setState(() => _uploadStatus = 'Enviando "$docNome"...');

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
      await supabase.from('upload_history').update({
        'drive_file_id': data['fileId'],
        'status': 'completed',
      }).eq('id', uploadId);
    } else {
      await supabase.from('upload_history').update({
        'status': 'failed',
      }).eq('id', uploadId);
      throw Exception('Erro no upload: ${response.body}');
    }
  }

  Widget _arquivoTile(
      String label, PlatformFile? arquivo, VoidCallback onPressed) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(arquivo?.name ?? 'Nenhum arquivo selecionado'),
        trailing: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea)),
          child: const Text('Selecionar'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emissão de Diplomas - Documentos'),
        backgroundColor: const Color(0xFF667eea),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF667eea)),
                title: Text(
                  nomeController.text.isNotEmpty
                      ? nomeController.text
                      : 'Usuário',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(supabase.auth.currentUser?.email ?? 'Sem email'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: arquivos.keys.map((docNome) {
                  return _arquivoTile(docNome, arquivos[docNome],
                      () => selecionarArquivo(docNome));
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : enviarTodosArquivos,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Enviando...' : 'Enviar Todos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            if (_uploadStatus.isNotEmpty)
              Text(_uploadStatus,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }
}
