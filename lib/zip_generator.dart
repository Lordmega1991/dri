import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Importação condicional para web
import 'dart:html' if (dart.library.io) 'dart:html' as web;

class ZipGenerator {
  // ============================
  // GERAR TODOS OS DOCUMENTOS EM ZIP - VERSÃO SIMPLIFICADA
  // ============================

  static Future<void> generateAllDocumentsZip(
      Map<String, dynamic> defesa) async {
    final Archive archive = Archive();

    try {
      print('🔄 Iniciando geração de documentos em ZIP...');

      // 1. GERAR FICHA DE AVALIAÇÃO FINAL
      print('📋 Gerando Ficha de Avaliação Final...');
      try {
        final pdf = await _generateFichaFinalBytes(defesa);
        if (pdf != null) {
          final fileName =
              'Ficha_Avaliacao_Final_${_formatarNome(defesa['discente'] ?? 'aluno')}.pdf';
          archive.addFile(ArchiveFile(fileName, pdf.length, pdf));
          print('✅ Ficha Final gerada: $fileName');
        }
      } catch (e) {
        print('❌ Erro na Ficha Final: $e');
      }

      // 2. GERAR FICHAS DE AVALIAÇÃO INDIVIDUAIS
      print('📊 Gerando Fichas de Avaliação Individuais...');
      try {
        final avaliadores = [1, 2, 3];
        final pdf = await _generateFichasIndividuaisBytes(defesa, avaliadores);
        if (pdf != null) {
          final fileName =
              'Fichas_Avaliacao_${_formatarNome(defesa['discente'] ?? 'aluno')}.pdf';
          archive.addFile(ArchiveFile(fileName, pdf.length, pdf));
          print('✅ Fichas Individuais geradas: $fileName');
        }
      } catch (e) {
        print('❌ Erro nas Fichas Individuais: $e');
      }

      // 3. GERAR ATA DE DEFESA
      print('📄 Gerando Ata de Defesa...');
      try {
        final pdf = await _generateAtaDefesaBytes(defesa);
        if (pdf != null) {
          final fileName =
              'Ata_Defesa_${_formatarNome(defesa['discente'] ?? 'defesa')}.pdf';
          archive.addFile(ArchiveFile(fileName, pdf.length, pdf));
          print('✅ Ata de Defesa gerada: $fileName');
        }
      } catch (e) {
        print('❌ Erro na Ata de Defesa: $e');
      }

      // 4. GERAR FOLHA DE APROVAÇÃO
      print('📝 Gerando Folha de Aprovação...');
      try {
        final pdf = await _generateFolhaAprovacaoBytes(defesa);
        if (pdf != null) {
          final fileName =
              'Folha_Aprovacao_${_formatarNome(defesa['discente'] ?? 'aprovacao')}.pdf';
          archive.addFile(ArchiveFile(fileName, pdf.length, pdf));
          print('✅ Folha de Aprovação gerada: $fileName');
        }
      } catch (e) {
        print('❌ Erro na Folha de Aprovação: $e');
      }

      // VERIFICAR SE TEM ARQUIVOS NO ZIP
      if (archive.files.isEmpty) {
        throw Exception('Nenhum documento foi gerado para o ZIP');
      }

      print('🗜️ Compactando ${archive.files.length} arquivos...');

      // SALVAR O ZIP
      await _saveZipFile(archive, defesa);

      print('✅ ZIP gerado com sucesso!');
    } catch (e) {
      print('❌ Erro ao gerar ZIP: $e');
      rethrow;
    }
  }

  // ============================
  // MÉTODOS AUXILIARES PARA GERAR BYTES DOS PDFs
  // ============================

  static Future<Uint8List?> _generateFichaFinalBytes(
      Map<String, dynamic> defesa) async {
    try {
      final pdf = await _createFichaFinalPdf(defesa);
      return pdf;
    } catch (e) {
      print('Erro ao gerar ficha final: $e');
      return null;
    }
  }

  static Future<Uint8List?> _generateFichasIndividuaisBytes(
      Map<String, dynamic> defesa, List<int> avaliadores) async {
    try {
      final pdf = await _createFichasIndividuaisPdf(defesa, avaliadores);
      return pdf;
    } catch (e) {
      print('Erro ao gerar fichas individuais: $e');
      return null;
    }
  }

  static Future<Uint8List?> _generateAtaDefesaBytes(
      Map<String, dynamic> defesa) async {
    try {
      final pdf = await _createAtaDefesaPdf(defesa);
      return pdf;
    } catch (e) {
      print('Erro ao gerar ata de defesa: $e');
      return null;
    }
  }

  static Future<Uint8List?> _generateFolhaAprovacaoBytes(
      Map<String, dynamic> defesa) async {
    try {
      final pdf = await _createFolhaAprovacaoPdf(defesa);
      return pdf;
    } catch (e) {
      print('Erro ao gerar folha de aprovação: $e');
      return null;
    }
  }

  // ============================
  // MÉTODOS DE CRIAÇÃO DOS PDFs (VERSÃO SIMPLIFICADA)
  // ============================

  static Future<Uint8List> _createFichaFinalPdf(
      Map<String, dynamic> defesa) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  'FICHA DE AVALIAÇÃO FINAL',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Aluno: ${defesa['discente'] ?? ''}'),
              pw.Text('Orientador: ${defesa['orientador'] ?? ''}'),
              pw.Text('Título: ${defesa['titulo'] ?? ''}'),
              pw.SizedBox(height: 20),
              pw.Text('Documento gerado automaticamente'),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  static Future<Uint8List> _createFichasIndividuaisPdf(
      Map<String, dynamic> defesa, List<int> avaliadores) async {
    final pdf = pw.Document();

    for (int avaliador in avaliadores) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Center(
                  child: pw.Text(
                    'FICHA DE AVALIAÇÃO INDIVIDUAL',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Avaliador: $avaliador'),
                pw.Text('Aluno: ${defesa['discente'] ?? ''}'),
                pw.Text('Título: ${defesa['titulo'] ?? ''}'),
                pw.SizedBox(height: 20),
                pw.Text('Documento gerado automaticamente'),
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  static Future<Uint8List> _createAtaDefesaPdf(
      Map<String, dynamic> defesa) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  'ATA DE DEFESA',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Aluno: ${defesa['discente'] ?? ''}'),
              pw.Text('Data: ${defesa['dia'] ?? ''}'),
              pw.Text('Local: ${defesa['local'] ?? ''}'),
              pw.SizedBox(height: 20),
              pw.Text('Documento gerado automaticamente'),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  static Future<Uint8List> _createFolhaAprovacaoPdf(
      Map<String, dynamic> defesa) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  'FOLHA DE APROVAÇÃO',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Aluno: ${defesa['discente'] ?? ''}'),
              pw.Text('Orientador: ${defesa['orientador'] ?? ''}'),
              pw.Text('Título: ${defesa['titulo'] ?? ''}'),
              pw.SizedBox(height: 20),
              pw.Text('Documento gerado automaticamente'),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  // ============================
  // SALVAR ARQUIVO ZIP (VERSÃO SIMPLIFICADA)
  // ============================

  static Future<void> _saveZipFile(
      Archive archive, Map<String, dynamic> defesa) async {
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Falha ao criar arquivo ZIP');
    }

    final nomeAluno = defesa['discente'] ?? 'documentos';
    final nomeArquivo = 'Documentos_${_formatarNome(nomeAluno)}.zip';

    // Para WEB - download direto
    if (kIsWeb) {
      _downloadZipWeb(zipBytes, nomeArquivo);
      return;
    }

    // Para MOBILE/DESKTOP - Usar compartilhamento direto
    try {
      // Método mais simples: usar o package printing para compartilhar
      await Printing.sharePdf(
        bytes: Uint8List.fromList(zipBytes),
        filename: nomeArquivo,
      );
    } catch (e) {
      print('❌ Erro ao salvar ZIP: $e');
      // Fallback: tentar abrir o arquivo
      await _openZipFile(zipBytes, nomeArquivo);
    }
  }

  static Future<void> _openZipFile(List<int> bytes, String nomeArquivo) async {
    try {
      // Tenta salvar em um arquivo temporário e abrir
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$nomeArquivo');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } catch (e) {
      print('Erro ao abrir arquivo: $e');
      // Último recurso: apenas mostra mensagem de sucesso
      print(
          'ZIP gerado com sucesso, mas não foi possível abrir automaticamente');
    }
  }

  static void _downloadZipWeb(List<int> bytes, String nomeArquivo) {
    final blob = web.Blob([bytes], 'application/zip');
    final url = web.Url.createObjectUrlFromBlob(blob);
    final anchor = web.AnchorElement(href: url)
      ..setAttribute('download', nomeArquivo)
      ..click();
    web.Url.revokeObjectUrl(url);
    print('🌐 Download iniciado: $nomeArquivo');
  }

  // ============================
  // FORMATAÇÃO DE NOMES
  // ============================

  static String _formatarNome(String nome) {
    String nomeLimpo =
        nome.replaceAll(RegExp(r'[^\w\sáàâãéèêíïóôõöúçñÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇÑ]'), '');
    nomeLimpo = nomeLimpo.trim().replaceAll(RegExp(r'\s+'), '_');
    return nomeLimpo;
  }
}
