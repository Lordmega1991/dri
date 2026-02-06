import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ColacaoGrauPage extends StatefulWidget {
  final String folderId;
  final String nomeUsuario;

  const ColacaoGrauPage(
      {super.key, required this.folderId, required this.nomeUsuario});

  @override
  State<ColacaoGrauPage> createState() => _ColacaoGrauPageState();
}

class _ColacaoGrauPageState extends State<ColacaoGrauPage> {
  final supabase = Supabase.instance.client;

  Map<String, PlatformFile?> arquivos = {
    'RG': null,
    'CertidaoNascimento': null,
    'QuitacaoEleitoral': null,
    'ConclusaoEnsinoMedio': null,
    'Naturalizacao': null,
    'NadaConstaBiblioteca': null,
    'CertificadoReservista': null,
  };

  bool _isUploading = false;
  String _uploadStatus = '';

  Future<void> selecionarArquivo(String chave) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        arquivos[chave] = result.files.first;
      });
      _showSuccess('Arquivo selecionado: ${result.files.first.name}');
    }
  }

  Future<void> enviarTodosArquivos() async {
    if (arquivos.values.any((a) => a == null)) {
      _showError('Selecione todos os arquivos antes de enviar.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Preparando upload...';
    });

    try {
      for (var entry in arquivos.entries) {
        await _uploadArquivo(entry.value!, entry.key);
      }

      setState(() {
        _uploadStatus = '✅ Todos os arquivos enviados com sucesso!';
      });

      _showSuccess('Todos os arquivos enviados com sucesso!');

      // Limpar seleção após envio
      setState(() {
        arquivos.updateAll((key, value) => null);
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
      await supabase.from('upload_history').update({
        'status': 'failed',
      }).eq('id', uploadId);
      rethrow;
    }
  }

  Widget _arquivoTile(String chave, String label) {
    final arquivo = arquivos[chave];
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(arquivo?.name ?? 'Nenhum arquivo selecionado'),
        trailing: ElevatedButton(
          onPressed: () => selecionarArquivo(chave),
          child: const Text('Selecionar'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Colação de Grau - Emissão de Diplomas'),
        backgroundColor: const Color(0xFFFF9800),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _arquivoTile(
                      'RG', 'Documentação oficial de identificação (RG)'),
                  _arquivoTile('CertidaoNascimento',
                      'Certidão de Nascimento ou Casamento'),
                  _arquivoTile(
                      'QuitacaoEleitoral', 'Certidão de Quitação Eleitoral'),
                  _arquivoTile('ConclusaoEnsinoMedio',
                      'Prova de Conclusão do Ensino Médio'),
                  _arquivoTile(
                      'Naturalizacao', 'Ato de Naturalização (estrangeiros)'),
                  _arquivoTile('NadaConstaBiblioteca',
                      'Declaração de “nada consta” da Biblioteca'),
                  _arquivoTile('CertificadoReservista',
                      'Certificado de Reservista/Alistamento'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
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
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(
                  _isUploading ? 'Enviando...' : 'Enviar Todos os Arquivos',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              onPressed: _isUploading ? null : enviarTodosArquivos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_uploadStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _uploadStatus,
                  textAlign: TextAlign.center,
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
