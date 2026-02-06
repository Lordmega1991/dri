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

class FichaAvaliacaoGenerator {
  static final supabase = Supabase.instance.client;

  // --------------------------- GERAR FICHAS PARA AVALIADORES SELECIONADOS ---------------------------
  static Future<void> generateFichasAvaliacaoSelecionadas(
      Map<String, dynamic> defesa, List<int> avaliadoresSelecionados) async {
    final pdf = pw.Document();
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/ufpb.png')).buffer.asUint8List(),
    );

    // Carregar notas existentes
    final notasExistentes = await _carregarNotasDefesa(defesa['id']);

    // Gerar ficha para cada avaliador selecionado
    for (int numeroAvaliador in avaliadoresSelecionados) {
      final avaliador = _obterAvaliadorPorNumero(defesa, numeroAvaliador);
      if (avaliador != null) {
        final notasAvaliador =
            _obterNotasAvaliador(notasExistentes, numeroAvaliador);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(
                50, 30, 50, 30), // Reduzidas margens superior e inferior
            build: (pw.Context context) {
              return _buildFichaAvaliacaoComNotas(
                  defesa, avaliador['nome'], logo, notasAvaliador);
            },
          ),
        );
      }
    }

    // Verificar se alguma página foi adicionada
    bool temPaginas = false;
    try {
      final bytes = await pdf.save();
      temPaginas = bytes.isNotEmpty;
    } catch (e) {
      temPaginas = false;
    }

    if (temPaginas) {
      String nomeArquivo =
          'Fichas_Avaliacao_${_formatarNomeArquivo(defesa['discente'] ?? 'aluno')}';
      await _salvarPdfComNome(pdf, nomeArquivo);
    } else {
      throw Exception(
          'Nenhuma ficha foi gerada. Verifique os avaliadores selecionados.');
    }
  }

  // --------------------------- CARREGAR NOTAS DA DEFESA ---------------------------
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

  // --------------------------- OBTER AVALIADOR POR NÚMERO ---------------------------
  static Map<String, dynamic>? _obterAvaliadorPorNumero(
      Map<String, dynamic> defesa, int numero) {
    switch (numero) {
      case 1:
        return defesa['avaliador1'] != null &&
                defesa['avaliador1'].toString().isNotEmpty
            ? {
                'numero': 1,
                'nome': defesa['avaliador1'],
                'instituto': defesa['instituto_av1'] ?? ''
              }
            : null;
      case 2:
        return defesa['avaliador2'] != null &&
                defesa['avaliador2'].toString().isNotEmpty
            ? {
                'numero': 2,
                'nome': defesa['avaliador2'],
                'instituto': defesa['instituto_av2'] ?? ''
              }
            : null;
      case 3:
        return defesa['avaliador3'] != null &&
                defesa['avaliador3'].toString().isNotEmpty
            ? {
                'numero': 3,
                'nome': defesa['avaliador3'],
                'instituto': defesa['instituto_av3'] ?? ''
              }
            : null;
      default:
        return null;
    }
  }

  // --------------------------- OBTER NOTAS DO AVALIADOR ---------------------------
  static Map<String, dynamic>? _obterNotasAvaliador(
      List<Map<String, dynamic>> notasExistentes, int numeroAvaliador) {
    try {
      return notasExistentes.firstWhere(
        (nota) => nota['avaliador_numero'] == numeroAvaliador,
        orElse: () => {},
      );
    } catch (e) {
      return null;
    }
  }

  // --------------------------- CONSTRUIR FICHA COM NOTAS (MANTENDO LAYOUT ORIGINAL) ---------------------------
  static pw.Widget _buildFichaAvaliacaoComNotas(Map<String, dynamic> defesa,
      String avaliador, pw.MemoryImage logo, Map<String, dynamic>? notas) {
    // Verificar se foi usado modo nota total
    final bool modoNotaTotal = notas?['modo_nota_total'] ?? false;
    final double? notaTotal = notas?['nota_total'];

    // Calcular totais se houver notas
    double nfEscrito = 0.0;
    double nfApresentacao = 0.0;

    if (notas != null && notas.isNotEmpty) {
      if (modoNotaTotal && notaTotal != null) {
        // Se foi usado modo nota total, preencher os totais com a nota total
        nfEscrito = notaTotal;
        nfApresentacao = 0.0;
      } else {
        // Calcular pelos critérios individuais
        nfEscrito = (notas['introducao'] ?? 0.0) +
            (notas['problematizacao'] ?? 0.0) +
            (notas['referencial'] ?? 0.0) +
            (notas['desenvolvimento'] ?? 0.0) +
            (notas['conclusoes'] ?? 0.0) +
            (notas['forma'] ?? 0.0);

        nfApresentacao = (notas['estruturacao'] ?? 0.0) +
            (notas['clareza'] ?? 0.0) +
            (notas['dominio'] ?? 0.0);
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Cabeçalho (ORIGINAL)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, height: 30),
            pw.SizedBox(width: 5),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('UNIVERSIDADE FEDERAL DA PARAÍBA',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 7)),
                pw.Text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 7)),
                pw.Text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 7)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20), // Reduzido de 25 para 20

        // Título principal (ORIGINAL)
        pw.Center(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1, color: PdfColors.black),
              ),
            ),
            child: pw.Text(
              'FICHA DE AVALIAÇÃO INDIVIDUAL DA BANCA EXAMINADORA DE TCC',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 20), // Reduzido de 25 para 20

        // OBSERVAÇÃO SE FOI USADO MODO NOTA TOTAL
        if (modoNotaTotal && notaTotal != null) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.yellow100,
              border: pw.Border.all(color: PdfColors.amber, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Icon(
                  pw.IconData(0x1F4CA), // Ícone de gráfico/nota
                  size: 12,
                  color: PdfColors.amber,
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    'OBS: Esta avaliação foi realizada através de nota única. '
                    'Nota total atribuída: ${notaTotal.toStringAsFixed(1)}/10,0',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12), // Reduzido de 15 para 12
        ],

        // Informações do aluno (ORIGINAL)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Aluno(a): ',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.TextSpan(
                      text: defesa['discente']?.toUpperCase() ?? '',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Título: ',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.TextSpan(
                      text: defesa['titulo'] ?? '',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 15), // Reduzido de 20 para 15

        // PRIMEIRA PARTE: Avaliação do trabalho escrito EM TABELA (ORIGINAL COM NOTAS)
        pw.Center(
          child: pw.Text(
            'Avaliação de Trabalho de Conclusão de Curso',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
        ),
        pw.SizedBox(height: 8), // Reduzido de 10 para 8

        // Tabela para avaliação do trabalho escrito COM NOTAS
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            // Introdução e justificativa
            _buildLinhaTabelaComNota(
              'Introdução e justificativa (até 1,0 ponto)',
              'Apresenta e contextualiza o tema, a justificativa e a relevância do trabalho para a área.',
              modoNotaTotal ? null : notas?['introducao'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Problematização e metodologia
            _buildLinhaTabelaComNota(
              'Problematização e metodologia do trabalho (até 1,5 pontos)',
              'Temos objetivos (geral e específicos) claros; percebe-se o problema/pergunta de pesquisa de forma satisfatória; descreve ou segue procedimentos metodológicos adequados para o problema.',
              modoNotaTotal ? null : notas?['problematizacao'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Referencial teórico
            _buildLinhaTabelaComNota(
              'Referencial teórico e bibliográfico (até 2,0 pontos)',
              'Apresenta os elementos teóricos da área do conhecimento investigada, bem como a definição dos termos, conceitos, estado da arte e bibliografia acadêmica pertinentes ao tema da pesquisa.',
              modoNotaTotal ? null : notas?['referencial'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Desenvolvimento e avaliação
            _buildLinhaTabelaComNota(
              'Desenvolvimento e avaliação (até 2,5 pontos)',
              'Apresenta de forma suficiente as discussões,materiais e argumentos condizentes à proposta desenvolvida.Realiza as avaliações e argumentações necessárias para o alcance dos objetivos traçados',
              modoNotaTotal ? null : notas?['desenvolvimento'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Conclusões
            _buildLinhaTabelaComNota(
              'Conclusões (até 1,0 pontos)',
              'Apresenta os resultados alcançados e sua síntese pessoal, de modo a expressar sua compreensão sobre o assunto que foi objeto do trabalho e, eventualmente, sua contribuição pessoal para a área.',
              modoNotaTotal ? null : notas?['conclusoes'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Forma
            _buildLinhaTabelaComNota(
              'Forma (até 0,5 ponto)',
              'Estrutura e coesão do texto; linguagem clara precisa e formalmente correta; e padrões da ABNT.',
              modoNotaTotal ? null : notas?['forma'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Nota final do trabalho escrito - COM FUNDO CINZA E NOTA
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Nota final da avaliação do trabalho escrito (soma das notas, máximo 8,5)',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ),
                pw.Container(
                  height: 25,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    notas != null && notas.isNotEmpty
                        ? nfEscrito.toStringAsFixed(1)
                        : '',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(left: pw.BorderSide(width: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 15), // Reduzido de 20 para 15

        // SEGUNDA PARTE: Avaliação da apresentação oral EM TABELA (ORIGINAL COM NOTAS)
        pw.Center(
          child: pw.Text(
            'Avaliação da apresentação oral e arguição',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
        ),
        pw.SizedBox(height: 8), // Reduzido de 10 para 8

        // Tabela para avaliação da apresentação oral COM NOTAS
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            // Estruturação
            _buildLinhaTabelaSimplesComNota(
              'Estruturação e ordenação do conteúdo da apresentação (até 0,5 pontos)',
              modoNotaTotal ? null : notas?['estruturacao'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Clareza
            _buildLinhaTabelaSimplesComNota(
              'Clareza, objetividade e fluência na exposição das ideias (até 0,5 pontos)',
              modoNotaTotal ? null : notas?['clareza'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Domínio
            _buildLinhaTabelaSimplesComNota(
              'Domínio do tema desenvolvido e correspondência com trabalho escrito (até 0,5 pontos)',
              modoNotaTotal ? null : notas?['dominio'] ?? 0.0,
              modoNotaTotal: modoNotaTotal,
            ),

            // Nota final da apresentação oral - COM FUNDO CINZA E NOTA
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Nota final da apresentação oral (soma das notas, máximo 1,5)',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ),
                pw.Container(
                  height: 25,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    notas != null && notas.isNotEmpty
                        ? nfApresentacao.toStringAsFixed(1)
                        : '',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(left: pw.BorderSide(width: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),

        // ESPAÇO ADICIONAL ENTRE TABELA E ASSINATURA (ORIGINAL)
        pw.SizedBox(height: 15), // Reduzido de 20 para 15
        pw.SizedBox(height: 15), // Reduzido de 20 para 15

        // Linha de assinatura (ORIGINAL - APENAS NOME E LINHA) - MANTIDO SEMPRE
        pw.Center(
          child: pw.Column(
            children: [
              pw.Container(
                width: 250,
                height: 1,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                avaliador, // NOME DO AVALIADOR MANTIDO SEMPRE
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Função auxiliar para construir linhas da tabela com descrição E NOTA (MANTENDO FORMATO ORIGINAL)
  static pw.TableRow _buildLinhaTabelaComNota(
      String titulo, String descricao, double? nota,
      {bool modoNotaTotal = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                titulo,
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                descricao,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        pw.Container(
          height: 40,
          alignment: pw.Alignment.center,
          child: pw.Text(
            modoNotaTotal
                ? '-'
                : (nota != null && nota > 0 ? nota.toStringAsFixed(1) : ''),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: modoNotaTotal
                  ? PdfColors.grey
                  : (nota != null && nota > 0
                      ? PdfColors.black
                      : PdfColors.grey),
            ),
          ),
          decoration: pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(width: 0.5)),
          ),
        ),
      ],
    );
  }

  // Função auxiliar para construir linhas da tabela simples (sem descrição) E NOTA (MANTENDO FORMATO ORIGINAL)
  static pw.TableRow _buildLinhaTabelaSimplesComNota(
      String titulo, double? nota,
      {bool modoNotaTotal = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            titulo,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Container(
          height: 25,
          alignment: pw.Alignment.center,
          child: pw.Text(
            modoNotaTotal
                ? '-'
                : (nota != null && nota > 0 ? nota.toStringAsFixed(1) : ''),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: modoNotaTotal
                  ? PdfColors.grey
                  : (nota != null && nota > 0
                      ? PdfColors.black
                      : PdfColors.grey),
            ),
          ),
          decoration: pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(width: 0.5)),
          ),
        ),
      ],
    );
  }

  // ... (mantenha as funções _salvarPdfComNome e _formatarNomeArquivo existentes)
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
