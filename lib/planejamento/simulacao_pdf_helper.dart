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
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
        ),
      );

      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/ufpb.png')).buffer.asUint8List(),
      );

      // 1. PÁGINA INICIAL: Resumo e Dados Gerais
      pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30), // Margem um pouco maior
          build: (pw.Context context) {
            return [
              _buildPDFHeader(
                  logo, semestreSelecionado, nomeSimulacao, tipoPeriodo),
              pw.SizedBox(height: 20),
              _buildPDFInfoSimulacao(
                  nomeSimulacao, semestreSelecionado, tipoPeriodo),
              pw.SizedBox(height: 15),
              _buildPDFResumoPeriodos(periodosAtivos, getCHTotalDisciplinas,
                  getCHAlocada, getCHRestante),
            ];
          }));

      // 2. PÁGINAS POR PERÍODO (Um por página)
      for (var periodo in periodosAtivos) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            // Header simples para cada período, apenas indicando a simulação e página, se necessário
            build: (pw.Context context) {
              return [
                pw.Container(
                    padding: const pw.EdgeInsets.only(bottom: 10),
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
                                fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    )),
                pw.SizedBox(height: 20),
                ..._buildPDFDetalhePeriodoWidgets(
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

      // 3. PÁGINA FINAL: Resumo por Docente
      pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return [
              pw.Text('RESUMO FINAL POR DOCENTE',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple800)),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              _buildResumoDocentes(
                  simulacaoAtual, periodosAtivos, getDisciplinasPorPeriodo),
            ];
          }));

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

  static pw.Widget _buildResumoDocentes(
    Map<String, Map<String, dynamic>> simulacaoAtual,
    List<String> periodosAtivos,
    List<Map<String, dynamic>> Function(String) getDisciplinas,
  ) {
    // 1. Coletar dados
    final Map<String, Map<String, dynamic>> docentesMap = {};

    for (var periodo in periodosAtivos) {
      final periodoData = simulacaoAtual[periodo] ?? {};
      final detalhamento =
          periodoData['detalhamento'] as Map<String, dynamic>? ?? {};
      final disciplinas = getDisciplinas(periodo);

      for (var disc in disciplinas) {
        if (disc['desabilitada'] == true) continue;

        final discId = disc['id'];
        final discNome = disc['nome_completo']; // Usando nome completo
        final alocacoes = List.from(detalhamento[discId] ?? []);

        for (var aloc in alocacoes) {
          final docId = aloc['docente_id'];
          final docNome = aloc['docente_nome'] ?? 'Desconhecido';
          final ch = (aloc['ch_alocada'] ?? 0).toDouble();
          final slots = List<String>.from(aloc['slots'] ?? []);

          if (!docentesMap.containsKey(docId)) {
            docentesMap[docId] = {
              'nome': docNome,
              'ch_total': 0.0,
              'alocacoes': <Map<String, dynamic>>[],
            };
          }

          docentesMap[docId]!['ch_total'] += ch;
          (docentesMap[docId]!['alocacoes'] as List).add({
            'disciplina': discNome,
            'ch': ch,
            'slots': _formatSlots(slots),
            'periodo': periodo,
          });
        }
      }
    }

    // 2. Ordenar por nome
    final sortedKeys = docentesMap.keys.toList()
      ..sort((a, b) => (docentesMap[a]!['nome'] as String)
          .compareTo(docentesMap[b]!['nome'] as String));

    // 3. Montar Tabela
    return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(3), // Docente
          1: const pw.FlexColumnWidth(5), // Disciplinas/Horários
        },
        children: [
          pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableHeader('Docente / CH Total'),
                _tableHeader('Disciplinas Assumidas (Período - CH - Horário)'),
              ]),
          ...sortedKeys.map((docId) {
            final data = docentesMap[docId]!;
            final alocacoes = data['alocacoes'] as List<Map<String, dynamic>>;

            return pw.TableRow(children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(data['nome'],
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                                color: PdfColors.green50,
                                borderRadius: pw.BorderRadius.circular(4),
                                border:
                                    pw.Border.all(color: PdfColors.green200)),
                            child: pw.Text(
                                'Total: ${(data['ch_total'] as double).toStringAsFixed(1)}h',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.green800)))
                      ])),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: alocacoes.map((aloc) {
                        return pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 4),
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                    bottom: pw.BorderSide(
                                        color: PdfColors.grey200, width: 0.5))),
                            child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Container(
                                      width: 4,
                                      height: 4,
                                      margin: const pw.EdgeInsets.only(top: 3),
                                      decoration: const pw.BoxDecoration(
                                          shape: pw.BoxShape.circle,
                                          color: PdfColors.blueGrey)),
                                  pw.SizedBox(width: 6),
                                  pw.Expanded(
                                      child: pw.RichText(
                                          text: pw.TextSpan(
                                              style: const pw.TextStyle(
                                                  fontSize: 9),
                                              children: [
                                        pw.TextSpan(
                                            text: '[${aloc['periodo']}º Per] ',
                                            style: const pw.TextStyle(
                                                color: PdfColors.grey700,
                                                fontSize: 8)),
                                        pw.TextSpan(
                                            text: '${aloc['disciplina']}',
                                            style: pw.TextStyle(
                                                fontWeight:
                                                    pw.FontWeight.bold)),
                                        pw.TextSpan(
                                            text:
                                                ' (${aloc['ch'].toStringAsFixed(0)}h)'),
                                        if ((aloc['slots'] as String)
                                            .isNotEmpty)
                                          pw.TextSpan(
                                              text: ' - ${aloc['slots']}',
                                              style: const pw.TextStyle(
                                                  fontSize: 8,
                                                  color:
                                                      PdfColors.blueGrey800)),
                                      ])))
                                ]));
                      }).toList()))
            ]);
          }).toList()
        ]);
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)));
  }

  static pw.Widget _buildPDFHeader(pw.MemoryImage logo, String semestre,
      String nomeSimulacao, String tipoPeriodo) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Image(logo, height: 40),
            pw.SizedBox(width: 15),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('UFPB - CCSA - DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text('Simulação de Carga Horária',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple800)),
                pw.Text(
                    '${semestre.isNotEmpty ? 'Semestre: $semestre' : ''} | $nomeSimulacao | ${tipoPeriodo == 'impar' ? 'Ímpares' : 'Pares'}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(
                'Data de Emissão',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ])
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1, color: PdfColors.purple800),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildPDFInfoSimulacao(
      String nome, String semestre, String tipoPeriodo) {
    return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Nome: $nome',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Semestre: $semestre',
                style: const pw.TextStyle(fontSize: 12)),
            pw.Text(
                'Tipo: ${tipoPeriodo == 'impar' ? 'Períodos Ímpares' : 'Períodos Pares'}',
                style: const pw.TextStyle(fontSize: 12)),
          ],
        ));
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
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
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
                  fontSize: 10,
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
                fontSize: 10,
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
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
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
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
            color: PdfColors.grey800),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _resumoCell(String text, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: style,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

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

    // Barra de Status do Período - Mais compacta
    widgets.add(pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE8F5E9),
        border: pw.Border.all(color: PdfColor.fromInt(0xFF4CAF50)),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'DETALHAMENTO',
            style: pw.TextStyle(
                fontSize: 11,
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

    widgets.add(pw.SizedBox(height: 10));

    // Layout hierárquico
    if (detalhamento != null && detalhamento.isNotEmpty) {
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(3), // Disciplina
          1: const pw.FlexColumnWidth(4), // Docentes Alocados
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text('Disciplina',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text('Docentes / Dias / Horários',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
          ...disciplinasPeriodo.map((disc) {
            final discId = disc['id'];
            final nome = disc['nome_completo']; // Nome completo
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
                      padding: const pw.EdgeInsets.all(5),
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
                      padding: const pw.EdgeInsets.all(5),
                      child: alocacoes.isEmpty
                          ? pw.Text('-',
                              style: const pw.TextStyle(
                                  fontSize: 8, color: PdfColors.grey))
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
                                          width: 3,
                                          height: 3,
                                          margin:
                                              const pw.EdgeInsets.only(top: 3),
                                          decoration: const pw.BoxDecoration(
                                              shape: pw.BoxShape.circle,
                                              color: PdfColor.fromInt(
                                                  0xFF1B5E20))),
                                      pw.SizedBox(width: 4),
                                      pw.Expanded(
                                          child: pw.Text(finalText,
                                              style: const pw.TextStyle(
                                                  fontSize: 9)))
                                    ]));
                              }).toList()))
                ]);
          }).toList()
        ],
      ));
    } else {
      widgets.add(pw.Text('Sem dados de alocação para este período.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)));
    }

    return widgets;
  }

  static String _formatSlots(List<String> slots) {
    if (slots.isEmpty) return '';
    final Map<String, Set<String>> diaTurnos = {};
    for (var slot in slots) {
      final parts = slot.split('-');
      if (parts.length < 2) continue;
      final dia = parts[0];
      final turnoCode = parts[1][0];
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
}
