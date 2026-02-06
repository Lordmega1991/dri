// lib/planejamento/simulacao_pdf_helper.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class SimulacaoPDFHelper {
  static Future<void> exportarParaPDF({
    required String nomeSimulacao,
    required String semestreSelecionado,
    required String tipoPeriodo,
    required Map<String, Map<String, dynamic>> simulacaoAtual,
    required List<String> periodosAtivos,
    required double Function(String) getCHTotalDisciplinas,
    required double Function(String) getCHAlocada,
    required double Function(String) getCHRestante,
    required List<Map<String, dynamic>> Function(String)
        getDisciplinasPorPeriodo,
  }) async {
    try {
      final pdf = pw.Document();

      // 1. PRIMEIRA PÁGINA: Cabeçalho, Info e Resumo Geral
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(25),
          build: (pw.Context context) {
            return [
              _buildPDFHeader(),
              pw.SizedBox(height: 20),
              _buildPDFInfoSimulacao(
                  nomeSimulacao, semestreSelecionado, tipoPeriodo),
              pw.SizedBox(height: 15),
              _buildPDFResumoPeriodos(
                periodosAtivos,
                getCHTotalDisciplinas,
                getCHAlocada,
                getCHRestante,
              ),
            ];
          },
        ),
      );

      // 2. ADICIONAR UMA PÁGINA PARA CADA PERÍODO
      for (var periodo in periodosAtivos) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(25),
            header: (context) => pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Simulação: $nomeSimulacao',
                        style: pw.TextStyle(fontSize: 10)),
                    pw.Text('Período: $periodo',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 10),
              ],
            ),
            build: (pw.Context context) {
              return [
                _buildPDFDetalhePeriodoLadoALado(
                  periodo,
                  simulacaoAtual,
                  getDisciplinasPorPeriodo,
                  getCHTotalDisciplinas,
                  getCHAlocada,
                  getCHRestante,
                )
              ];
            },
          ),
        );
      }

      final pdfBytes = await pdf.save();
      final fileName =
          'Simulação_${nomeSimulacao.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: fileName,
        );
      } else {
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/$fileName");
        await file.writeAsBytes(pdfBytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      print('Erro ao exportar PDF no Helper: $e');
      rethrow;
    }
  }

  static pw.Widget _buildPDFHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SIMULAÇÃO DE CARGA HORÁRIA',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF1B5E20),
          ),
        ),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildPDFInfoSimulacao(
      String nome, String semestre, String tipoPeriodo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Nome: $nome',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Text(
                'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text(
                'Semestre: $semestre',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(width: 20),
              pw.Text(
                'Períodos: ${tipoPeriodo == 'impar' ? 'Ímpares' : 'Pares'}',
                style: pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPDFResumoPeriodos(
    List<String> periodos,
    double Function(String) getCHTotal,
    double Function(String) getCHAlocada,
    double Function(String) getCHRestante,
  ) {
    final periodosData = <pw.TableRow>[];

    periodosData.add(
      pw.TableRow(
        children: [
          _resumoHeaderCell('Período'),
          _resumoHeaderCell('CH Total'),
          _resumoHeaderCell('CH Alocada'),
          _resumoHeaderCell('CH Restante'),
          _resumoHeaderCell('Status'),
        ],
      ),
    );

    for (var periodo in periodos) {
      final chTotal = getCHTotal(periodo);
      final chAlocada = getCHAlocada(periodo);
      final chRestante = getCHRestante(periodo);
      final status = chRestante == 0 ? 'Completo' : 'Pendente';
      final statusColor = chRestante == 0
          ? PdfColor.fromInt(0xFF4CAF50)
          : PdfColor.fromInt(0xFFFF9800);

      periodosData.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
          ),
          children: [
            _resumoCell(periodo),
            _resumoCell('${chTotal.toStringAsFixed(1)}h'),
            _resumoCell('${chAlocada.toStringAsFixed(1)}h'),
            _resumoCell('${chRestante.toStringAsFixed(1)}h'),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: statusColor,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                status,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    double chTotalGeral = periodos.fold<double>(0, (t, p) => t + getCHTotal(p));
    double chAlocadaGeral =
        periodos.fold<double>(0, (t, p) => t + getCHAlocada(p));
    double chRestanteGeral =
        periodos.fold<double>(0, (t, p) => t + getCHRestante(p));

    periodosData.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
        children: [
          _resumoCell('TOTAL', bold: true),
          _resumoCell('${chTotalGeral.toStringAsFixed(1)}h', bold: true),
          _resumoCell('${chAlocadaGeral.toStringAsFixed(1)}h', bold: true),
          _resumoCell('${chRestanteGeral.toStringAsFixed(1)}h', bold: true),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Text(
              chRestanteGeral == 0 ? 'COMPLETO' : 'PENDENTE',
              style: pw.TextStyle(
                fontSize: 11,
                color: chRestanteGeral == 0
                    ? PdfColor.fromInt(0xFF4CAF50)
                    : PdfColor.fromInt(0xFFF44336),
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RESUMO POR PERÍODO',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1.2),
          },
          children: periodosData,
        ),
      ],
    );
  }

  static pw.Widget _resumoHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _resumoCell(String text, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 12,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: style,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildPDFDetalhePeriodoLadoALado(
    String periodo,
    Map<String, Map<String, dynamic>> simulacaoAtual,
    List<Map<String, dynamic>> Function(String) getDisciplinas,
    double Function(String) getTotal,
    double Function(String) getAlocada,
    double Function(String) getRestante,
  ) {
    final disciplinasPeriodo = getDisciplinas(periodo);
    final alocacoes = simulacaoAtual[periodo]?['alocacoes'] ?? [];
    final chTotal = getTotal(periodo);
    final chAlocada = getAlocada(periodo);
    final chRestante = getRestante(periodo);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFE8F5E9),
            border: pw.Border.all(color: PdfColor.fromInt(0xFF4CAF50)),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DETALHAMENTO: $periodo PERÍODO',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF1B5E20)),
              ),
              pw.Text(
                'Total: ${chTotal.toStringAsFixed(1)}h | Alocada: ${chAlocada.toStringAsFixed(1)}h | Restante: ${chRestante.toStringAsFixed(1)}h',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: chRestante == 0
                      ? PdfColor.fromInt(0xFF1B5E20)
                      : PdfColor.fromInt(0xFFE65100),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: _buildPDFColunaLadoALado(
                  'Disciplinas Ofertadas', disciplinasPeriodo, true),
            ),
            pw.SizedBox(width: 15),
            pw.Expanded(
              flex: 4,
              child: _buildPDFColunaLadoALado(
                  'Docentes Alocados', alocacoes, false),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPDFColunaLadoALado(
      String title, List<dynamic> items, bool isDisciplinas) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        items.isEmpty
            ? pw.Text(isDisciplinas ? 'Sem disciplinas' : 'Nenhuma alocação',
                style: pw.TextStyle(fontSize: 10))
            : pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(
                          isDisciplinas ? 0xFFF5F5F5 : 0xFFE8F5E9),
                    ),
                    children: [
                      _smallHeaderCell(isDisciplinas ? 'Nome' : 'Docente'),
                      _smallHeaderCell('CH'),
                    ],
                  ),
                  ...items.map((item) {
                    if (isDisciplinas) {
                      final isDes = item['desabilitada'] == true;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              item['nome_completo'],
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: isDes ? PdfColors.grey : PdfColors.black,
                                fontStyle: isDes
                                    ? pw.FontStyle.italic
                                    : pw.FontStyle.normal,
                                decoration: isDes
                                    ? pw.TextDecoration.lineThrough
                                    : pw.TextDecoration.none,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                '${item['ch_aula'].toStringAsFixed(1)}h',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: isDes
                                        ? PdfColors.grey
                                        : PdfColors.black),
                                textAlign: pw.TextAlign.center),
                          ),
                        ],
                      );
                    } else {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(item['docente_nome'],
                                style: pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                '${item['ch_alocada'].toStringAsFixed(1)}h',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromInt(0xFF1B5E20)),
                                textAlign: pw.TextAlign.center),
                          ),
                        ],
                      );
                    }
                  }).toList(),
                ],
              ),
      ],
    );
  }

  static pw.Widget _smallHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center),
    );
  }
}
