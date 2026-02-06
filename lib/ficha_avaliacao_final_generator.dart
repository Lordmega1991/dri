import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FichaAvaliacaoFinalGenerator {
  static final supabase = Supabase.instance.client;

  // --------------------------- GERAR FICHA DE AVALIAÇÃO FINAL ---------------------------
  static Future<void> generateFichaAvaliacaoFinal(
      Map<String, dynamic> defesa) async {
    final pdf = pw.Document();
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/ufpb.png')).buffer.asUint8List(),
    );

    // Carregar dados do banco
    final notasAvaliadores = await _carregarNotasDefesa(defesa['id']);
    final dadosFinais = await _carregarDadosFinaisDefesa(defesa['id']);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
        build: (pw.Context context) {
          return _buildFichaAvaliacaoFinal(
              defesa, logo, notasAvaliadores, dadosFinais);
        },
      ),
    );

    String nomeArquivo =
        'Ficha_Avaliacao_Final_${_formatarNomeArquivo(defesa['discente'] ?? 'aluno')}';
    await _salvarPdfComNome(pdf, nomeArquivo);
  }

  // --------------------------- CONSTRUIR FICHA DE AVALIAÇÃO FINAL ---------------------------
  static pw.Widget _buildFichaAvaliacaoFinal(
      Map<String, dynamic> defesa,
      pw.MemoryImage logo,
      List<Map<String, dynamic>> notasAvaliadores,
      Map<String, dynamic>? dadosFinais) {
    // Verificar se algum avaliador usou modo nota única
    final bool temModoNotaUnica = _verificarModoNotaUnica(notasAvaliadores);

    // Calcular notas de cada avaliador
    final notaOrientador = _calcularNotaFinalAvaliador(notasAvaliadores, 1);
    final notaMembro1 = _calcularNotaFinalAvaliador(notasAvaliadores, 2);
    final notaMembro2 = _calcularNotaFinalAvaliador(notasAvaliadores, 3);

    // Calcular média final
    final mediaFinal = _calcularMediaFinal(notasAvaliadores);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Cabeçalho com logo
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, height: 40),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('UNIVERSIDADE FEDERAL DA PARAÍBA',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 30),

        // Título principal
        pw.Center(
          child: pw.Text(
            'FICHA DE AVALIAÇÃO FINAL DE TCC 2',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        pw.SizedBox(height: 25),

        // Informações do aluno e trabalho
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildLinhaInfo(
                  'Aluno(a):', defesa['discente']?.toUpperCase() ?? ''),
              pw.SizedBox(height: 5),
              _buildLinhaInfo('Título:', defesa['titulo'] ?? ''),
              pw.SizedBox(height: 5),
              _buildLinhaInfo('Orientador(a):', defesa['orientador'] ?? ''),
              pw.SizedBox(height: 5),
              _buildLinhaInfo(
                  'Membro 1 da Banca Examinadora:', defesa['avaliador2'] ?? ''),
              pw.SizedBox(height: 5),
              _buildLinhaInfo(
                  'Membro 2 da Banca Examinadora:', defesa['avaliador3'] ?? ''),
            ],
          ),
        ),
        pw.SizedBox(height: 25),

        // Tabela de avaliação - COM NOTAS PREENCHIDAS
        pw.Table(
          border: pw.TableBorder.all(width: 1),
          columnWidths: {
            0: const pw.FlexColumnWidth(2), // Descrição dos itens (MENOR)
            1: const pw.FlexColumnWidth(1), // Nota Orientador
            2: const pw.FlexColumnWidth(1), // Nota Membro 1
            3: const pw.FlexColumnWidth(1), // Nota Membro 2
          },
          children: [
            // Cabeçalho da tabela
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Itens avaliados',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Orientador(a)',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Membro 1',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Membro 2',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),

            if (temModoNotaUnica) ...[
              // MODO NOTA ÚNICA - APENAS UMA LINHA COM NOTA GERAL
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Nota Geral (0 a 10)',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaFinalAvaliador(notasAvaliadores, 1) > 0
                          ? _calcularNotaFinalAvaliador(notasAvaliadores, 1)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaFinalAvaliador(notasAvaliadores, 2) > 0
                          ? _calcularNotaFinalAvaliador(notasAvaliadores, 2)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaFinalAvaliador(notasAvaliadores, 3) > 0
                          ? _calcularNotaFinalAvaliador(notasAvaliadores, 3)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // MODO NORMAL - TRABALHO ESCRITO E APRESENTAÇÃO SEPARADOS
              // Trabalho escrito - TEXTO NA MESMA LINHA
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Trabalho escrito (0 a 8,5)',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaEscritoAvaliador(notasAvaliadores, 1) > 0
                          ? _calcularNotaEscritoAvaliador(notasAvaliadores, 1)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaEscritoAvaliador(notasAvaliadores, 2) > 0
                          ? _calcularNotaEscritoAvaliador(notasAvaliadores, 2)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaEscritoAvaliador(notasAvaliadores, 3) > 0
                          ? _calcularNotaEscritoAvaliador(notasAvaliadores, 3)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),

              // Apresentação oral - TEXTO NA MESMA LINHA
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Apresentação oral (0 a 1,5)',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaApresentacaoAvaliador(notasAvaliadores, 1) >
                              0
                          ? _calcularNotaApresentacaoAvaliador(
                                  notasAvaliadores, 1)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaApresentacaoAvaliador(notasAvaliadores, 2) >
                              0
                          ? _calcularNotaApresentacaoAvaliador(
                                  notasAvaliadores, 2)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _calcularNotaApresentacaoAvaliador(notasAvaliadores, 3) >
                              0
                          ? _calcularNotaApresentacaoAvaliador(
                                  notasAvaliadores, 3)
                              .toStringAsFixed(1)
                          : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Nota final - TEXTO NA MESMA LINHA (SEMPRE APARECE)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Nota final (0 a 10)',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                ),
                pw.Container(
                  height: 30,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    notaOrientador > 0 ? notaOrientador.toStringAsFixed(1) : '',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.Container(
                  height: 30,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    notaMembro1 > 0 ? notaMembro1.toStringAsFixed(1) : '',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.Container(
                  height: 30,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    notaMembro2 > 0 ? notaMembro2.toStringAsFixed(1) : '',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // Média final e resultado - JUNTOS NO MESMO QUADRO COM MESMA LARGURA
        pw.Container(
          width: double.infinity, // MESMA LARGURA DA TABELA ACIMA
          child: pw.Table(
            border: pw.TableBorder.all(width: 1),
            columnWidths: {
              0: const pw.FlexColumnWidth(
                  2), // MESMA LARGURA DA COLUNA "Itens avaliados"
              1: const pw.FlexColumnWidth(
                  3), // LARGURA COMBINADA DAS 3 COLUNAS DE NOTAS
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Média final',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Resultado',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Container(
                    height: 40,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      mediaFinal > 0 ? mediaFinal.toStringAsFixed(1) : '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  pw.Container(
                    height: 40,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      dadosFinais?['resultado']?.toUpperCase() ?? '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // MAIS ESPAÇO entre a última tabela e o primeiro avaliador
        pw.SizedBox(height: 50),

        // Assinaturas - UMA EMBAIXO DA OUTRA COM MAIS ESPAÇO
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Assinatura do Orientador
            _buildAssinaturaVertical(defesa['orientador'] ?? ''),
            pw.SizedBox(height: 40), // MAIS ESPAÇO entre assinaturas

            // Assinatura do Membro 1
            _buildAssinaturaVertical(defesa['avaliador2'] ?? ''),
            pw.SizedBox(height: 40), // MAIS ESPAÇO entre assinaturas

            // Assinatura do Membro 2
            _buildAssinaturaVertical(defesa['avaliador3'] ?? ''),
          ],
        ),
        pw.SizedBox(height: 25),

        // Observações finais - CORRIGIDO
        pw.Text(
          'Observações finais:',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1), // QUADRO RETANGULAR
          ),
          child: pw.Text(
            dadosFinais?['observacoes_finais'] ??
                'Nenhuma observação registrada.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  // --------------------------- FUNÇÕES AUXILIARES ---------------------------
  static pw.Widget _buildLinhaInfo(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAssinaturaVertical(String nome) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 250,
          height: 1,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          nome,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // --------------------------- FUNÇÕES DE VERIFICAÇÃO DE MODO NOTA ÚNICA ---------------------------
  static bool _verificarModoNotaUnica(List<Map<String, dynamic>> notas) {
    for (var nota in notas) {
      if (nota['modo_nota_total'] == true) {
        return true;
      }
    }
    return false;
  }

  // --------------------------- FUNÇÕES DE BANCO DE DADOS ---------------------------
  static Future<List<Map<String, dynamic>>> _carregarNotasDefesa(
      int defesaId) async {
    try {
      final response =
          await supabase.from('notas').select().eq('defesa_id', defesaId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao carregar notas: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> _carregarDadosFinaisDefesa(
      int defesaId) async {
    try {
      final response = await supabase
          .from('dados_defesa_final')
          .select()
          .eq('defesa_id', defesaId)
          .maybeSingle();

      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      print('Erro ao carregar dados finais: $e');
      return null;
    }
  }

  // --------------------------- FUNÇÕES DE CÁLCULO DE NOTAS ---------------------------
  static double _calcularNotaFinalAvaliador(
      List<Map<String, dynamic>> notas, int numeroAvaliador) {
    try {
      final notaAvaliador = notas.firstWhere(
        (nota) => nota['avaliador_numero'] == numeroAvaliador,
        orElse: () => {},
      );

      if (notaAvaliador.isNotEmpty) {
        // Verificar se foi usado modo nota total
        final bool modoNotaTotal = notaAvaliador['modo_nota_total'] ?? false;

        if (modoNotaTotal && notaAvaliador['nota_total'] != null) {
          // Usar a nota total direta
          return notaAvaliador['nota_total'] ?? 0.0;
        } else {
          // Calcular pelos critérios individuais
          final notaEscrito =
              _calcularNotaEscritoAvaliador(notas, numeroAvaliador);
          final notaApresentacao =
              _calcularNotaApresentacaoAvaliador(notas, numeroAvaliador);
          return notaEscrito + notaApresentacao;
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static double _calcularNotaEscritoAvaliador(
      List<Map<String, dynamic>> notas, int numeroAvaliador) {
    try {
      final notaAvaliador = notas.firstWhere(
        (nota) => nota['avaliador_numero'] == numeroAvaliador,
        orElse: () => {},
      );

      if (notaAvaliador.isNotEmpty) {
        return (notaAvaliador['introducao'] ?? 0.0) +
            (notaAvaliador['problematizacao'] ?? 0.0) +
            (notaAvaliador['referencial'] ?? 0.0) +
            (notaAvaliador['desenvolvimento'] ?? 0.0) +
            (notaAvaliador['conclusoes'] ?? 0.0) +
            (notaAvaliador['forma'] ?? 0.0);
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static double _calcularNotaApresentacaoAvaliador(
      List<Map<String, dynamic>> notas, int numeroAvaliador) {
    try {
      final notaAvaliador = notas.firstWhere(
        (nota) => nota['avaliador_numero'] == numeroAvaliador,
        orElse: () => {},
      );

      if (notaAvaliador.isNotEmpty) {
        return (notaAvaliador['estruturacao'] ?? 0.0) +
            (notaAvaliador['clareza'] ?? 0.0) +
            (notaAvaliador['dominio'] ?? 0.0);
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static double _calcularMediaFinal(List<Map<String, dynamic>> notas) {
    if (notas.isEmpty) return 0.0;

    double somaTotal = 0.0;
    int avaliadoresComNota = 0;

    for (var nota in notas) {
      final notaFinal =
          _calcularNotaFinalAvaliador(notas, nota['avaliador_numero']);
      if (notaFinal > 0) {
        somaTotal += notaFinal;
        avaliadoresComNota++;
      }
    }

    return avaliadoresComNota > 0 ? somaTotal / avaliadoresComNota : 0.0;
  }

  // --------------------------- FUNÇÕES DE SALVAMENTO ---------------------------
  static Future<void> _salvarPdfComNome(
      pw.Document pdf, String nomeArquivo) async {
    final bytes = await pdf.save();

    if (!nomeArquivo.toLowerCase().endsWith('.pdf')) {
      nomeArquivo = '$nomeArquivo.pdf';
    }

    try {
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);
        return;
      }

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);
          return;
        }
        List<Directory>? dirs = await getExternalStorageDirectories(
            type: StorageDirectory.downloads);
        Directory? downloadDir =
            dirs != null && dirs.isNotEmpty ? dirs.first : null;
        downloadDir ??= await getExternalStorageDirectory();
        if (downloadDir == null) {
          await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);
          return;
        }
        final filePath = path.join(downloadDir.path, nomeArquivo);
        final file = File(filePath);
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
        return;
      }
      if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = path.join(dir.path, nomeArquivo);
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
        return;
      }
      final downloadsDir = await getDownloadsDirectory();
      final dir = downloadsDir ?? await getApplicationDocumentsDirectory();
      final filePath = path.join(dir.path, nomeArquivo);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } catch (e) {
      print('Erro ao salvar PDF: $e');
      await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);
    }
  }

  static String _formatarNomeArquivo(String nome) {
    String nomeLimpo =
        nome.replaceAll(RegExp(r'[^\w\sáàâãéèêíïóôõöúçñÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇÑ]'), '');
    nomeLimpo = nomeLimpo.trim().replaceAll(RegExp(r'\s+'), '_');
    return nomeLimpo;
  }
}
