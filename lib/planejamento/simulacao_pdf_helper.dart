// lib/planejamento/simulacao_pdf_helper.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
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
      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/ufpb.png')).buffer.asUint8List(),
      );

      // 2. CONTEÚDO UNIFICADO (Uma única MultiPage para fluxo contínuo)
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(25),
          // REMOVIDO header: ... para não repetir em todas as páginas
          build: (pw.Context context) {
            final List<pw.Widget> content = [];

            // Cabeçalho (Apenas na primeira página, pois é o primeiro item)
            content.add(_buildPDFHeader(
                logo, semestreSelecionado, nomeSimulacao, tipoPeriodo));

            content.add(pw.SizedBox(height: 20));
            content.add(_buildPDFInfoSimulacao(
                nomeSimulacao, semestreSelecionado, tipoPeriodo));
            content.add(pw.SizedBox(height: 15));
            content.add(_buildPDFResumoPeriodos(periodosAtivos,
                getCHTotalDisciplinas, getCHAlocada, getCHRestante));

            content.add(pw.SizedBox(height: 25));
            content.add(pw.Divider(thickness: 1));
            content.add(pw.SizedBox(height: 15));

            // Períodos
            for (var i = 0; i < periodosAtivos.length; i++) {
              final periodo = periodosAtivos[i];

              // Cabeçalho do Período
              content.add(pw.Container(
                  margin: pw.EdgeInsets.only(bottom: 10, top: i == 0 ? 0 : 20),
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(
                              color: PdfColors.grey, width: 0.5))),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Simulação: $nomeSimulacao',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Período: $periodo',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  )));

              // Conteúdo do Período (Agora retorna lista de widgets)
              content.addAll(_buildPDFDetalhePeriodoWidgets(
                periodo,
                simulacaoAtual,
                getDisciplinasPorPeriodo,
                getCHTotalDisciplinas,
                getCHAlocada,
                getCHRestante,
              ));
            }

            return content;
          },
        ),
      );

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

  static pw.Widget _buildPDFHeader(pw.MemoryImage logo, String semestre,
      String nomeSimulacao, String tipoPeriodo) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Image(logo, height: 30),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('UFPB - CCSA - DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Simulação de Carga Horária',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple700)),
                pw.Text(
                    '${semestre.isNotEmpty ? 'Semestre: $semestre' : ''} | $nomeSimulacao | ${tipoPeriodo == 'impar' ? 'Ímpares' : 'Pares'}',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.Spacer(),
            pw.Text(
                'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 0.5, color: PdfColors.purple),
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
          decoration: const pw.BoxDecoration(
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
          'RESUMO GERAL',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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

  // Renomeado e refatorado para retornar Lista de Widgets para melhor paginação
  static List<pw.Widget> _buildPDFDetalhePeriodoWidgets(
    String periodo,
    Map<String, Map<String, dynamic>> simulacaoAtual,
    List<Map<String, dynamic>> Function(String) getDisciplinas,
    double Function(String) getTotal,
    double Function(String) getAlocada,
    double Function(String) getRestante,
  ) {
    final disciplinasPeriodo = getDisciplinas(periodo);
    final periodoData = simulacaoAtual[periodo] ?? {};
    final detalhamento = periodoData['detalhamento'] as Map<String, dynamic>?;

    final chTotal = getTotal(periodo);
    final chAlocada = getAlocada(periodo);
    final chRestante = getRestante(periodo);

    final List<pw.Widget> widgets = [];

    // Barra de Status do Período
    widgets.add(pw.Container(
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
    ));

    widgets.add(pw.SizedBox(height: 15));

    // Se tiver detalhamento (novo formato), usa o layout hierárquico
    if (detalhamento != null && detalhamento.isNotEmpty) {
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(3), // Disciplina
          1: const pw.FlexColumnWidth(4), // Docentes Alocados + Dias/Turno
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Disciplina',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Docentes / Dias / Horários',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
          ...disciplinasPeriodo.map((disc) {
            final discId = disc['id'];
            final nome = disc['nome_completo'];
            final chDisc = disc['ch_aula'];
            final alocacoes = List.from(detalhamento[discId] ?? []);
            final isDes = disc['desabilitada'] == true;

            // Calcula CH total alocada nesta disciplina
            double chAlocadaDisc = 0;
            for (var a in alocacoes) {
              chAlocadaDisc += (a['ch_alocada'] ?? 0).toDouble();
            }

            return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: isDes ? PdfColors.grey50 : PdfColors.white),
                children: [
                  // Coluna Disciplina
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(nome,
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    decoration: isDes
                                        ? pw.TextDecoration.lineThrough
                                        : null,
                                    color: isDes
                                        ? PdfColors.grey
                                        : PdfColors.black)),
                            pw.Text(
                                'CH: ${chAlocadaDisc > 0 ? '${chAlocadaDisc}h / ' : ''}${chDisc}h',
                                style: const pw.TextStyle(
                                    fontSize: 8, color: PdfColors.grey700)),
                          ])),
                  // Coluna Docentes
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: alocacoes.isEmpty
                          ? pw.Text('-',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey))
                          : pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: alocacoes.map((aloc) {
                                final nomeDocente =
                                    aloc['docente_nome'] ?? 'Desconhecido';
                                final chDoc =
                                    (aloc['ch_alocada'] ?? 0).toDouble();
                                final slots =
                                    List<String>.from(aloc['slots'] ?? []);

                                final formatedSlots = _formatSlots(slots);
                                final finalText =
                                    '$nomeDocente (${chDoc.toStringAsFixed(1)}h)${formatedSlots.isNotEmpty ? ' - $formatedSlots' : ''}';

                                return pw.Container(
                                    margin: const pw.EdgeInsets.only(bottom: 2),
                                    child: pw.Row(children: [
                                      pw.Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const pw.BoxDecoration(
                                              shape: pw.BoxShape.circle,
                                              color: PdfColor.fromInt(
                                                  0xFF1B5E20))),
                                      pw.SizedBox(width: 4),
                                      pw.Expanded(
                                          child: pw.Text(
                                        finalText,
                                        style: pw.TextStyle(
                                            fontSize: 9,
                                            font: pw.Font
                                                .helvetica()), // Fonte mais legível
                                      ))
                                    ]));
                              }).toList()))
                ]);
          }).toList()
        ],
      ));
    } else {
      // Fallback para o layout antigo (apenas alocacoes gerais)
      widgets.add(pw.Row(
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
            child: _buildPDFColunaLadoALado('Docentes Alocados',
                List.from(periodoData['alocacoes'] ?? []), false),
          ),
        ],
      ));
    }

    return widgets;
  }

  static String _formatSlots(List<String> slots) {
    if (slots.isEmpty) return '';

    // Agrupar por dia e turno. Ex: "Segunda-M1", "Segunda-M2" -> "Segunda Manhã"
    // Entradas: "Segunda-M1", "Quarta-N2"
    // Saída desejada: 2º Manhã, 4º Noite

    final Map<String, Set<String>> diaTurnos = {};

    for (var slot in slots) {
      final parts = slot.split('-');
      if (parts.length < 2) continue;
      final dia = parts[0];
      final turnoCode = parts[1][0]; // M, T, N

      String turno = '';
      if (turnoCode == 'M')
        turno = 'Manhã';
      else if (turnoCode == 'T')
        turno = 'Tarde';
      else if (turnoCode == 'N') turno = 'Noite';

      if (!diaTurnos.containsKey(dia)) {
        diaTurnos[dia] = {};
      }
      diaTurnos[dia]!.add(turno);
    }

    List<String> results = [];
    // Ordenar dias
    final ordemDias = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado'
    ];

    for (var dia in ordemDias) {
      if (diaTurnos.containsKey(dia)) {
        String diaAbrev = '';
        if (dia == 'Segunda')
          diaAbrev = '2º';
        else if (dia == 'Terça')
          diaAbrev = '3º';
        else if (dia == 'Quarta')
          diaAbrev = '4º';
        else if (dia == 'Quinta')
          diaAbrev = '5º';
        else if (dia == 'Sexta')
          diaAbrev = '6º';
        else if (dia == 'Sábado') diaAbrev = 'Sáb';

        final turnos = diaTurnos[dia]!.join('/');
        results.add('$diaAbrev $turnos');
      }
    }

    return results.join(', ');
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
                style: const pw.TextStyle(fontSize: 10))
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
