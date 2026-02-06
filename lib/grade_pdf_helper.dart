import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

class GradePDFHelper {
  // Cores personalizadas para o PDF
  static const PdfColor primaryBlue = PdfColor.fromInt(0xFF1565C0); // Blue 800
  static const PdfColor accentBlue = PdfColor.fromInt(0xFFE3F2FD); // Blue 50
  static const PdfColor headerGrey = PdfColor.fromInt(0xFFF5F5F5); // Grey 100
  static const PdfColor morningColor = PdfColor.fromInt(0xFFFFF8E1); // Amber 50
  static const PdfColor afternoonColor =
      PdfColor.fromInt(0xFFFBE9E7); // Deep Orange 50
  static const PdfColor nightColor = PdfColor.fromInt(0xFFE8EAF6); // Indigo 50
  static const PdfColor textMain = PdfColor.fromInt(0xFF212121); // Grey 900
  static const PdfColor textSecondary =
      PdfColor.fromInt(0xFF757575); // Grey 600

  static Future<void> gerarPDFDetalhado({
    required Map<String, List<Map<String, dynamic>>> grade,
    required Map<String, int> cargaHorariaProfessores,
    required Map<String, List<Map<String, dynamic>>> detalhesProfessores,
    required Map<String, List<Map<String, dynamic>>> horariosProfessores,
    required List<String> diasSemana,
    required String Function(int) getTurnoDoHorario,
    required Function(int) getIndiceNoTurno,
    required Function(int) getHorarioFormatado,
  }) async {
    final pdf = pw.Document();

    // Carregar logo da UFPB
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/ufpb.png')).buffer.asUint8List(),
    );

    // Página 1: Grade Completa (Landscape fixa)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildProfessionalHeader(logo, 'GRADE DE AULAS COMPLETA',
                  context.pageNumber, context.pagesCount),
              pw.SizedBox(height: 15),
              _buildResumoGeralPDF(grade, cargaHorariaProfessores),
              pw.SizedBox(height: 15),
              _buildGradePDFCompleta(grade, diasSemana, getTurnoDoHorario,
                  getIndiceNoTurno, getHorarioFormatado),
            ],
          );
        },
      ),
    );

    // Páginas dos professores - AUTOMÁTICAS (MultiPage)
    if (cargaHorariaProfessores.isNotEmpty) {
      final professoresOrdenados = cargaHorariaProfessores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context context) => _buildProfessionalHeader(logo,
              'DETALHES DOS DOCENTES', context.pageNumber, context.pagesCount),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 10),
              ...professoresOrdenados.map((entry) {
                final professor = entry.key;
                final cargaHoraria = entry.value;
                final detalhes = detalhesProfessores[professor] ?? [];
                final diasTurnos =
                    _getDiasTurnosProfessor(professor, horariosProfessores);

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Header do Professor
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: const pw.BoxDecoration(
                            color: headerGrey,
                            borderRadius: pw.BorderRadius.vertical(
                                top: pw.Radius.circular(6)),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(professor.toUpperCase(),
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: pw.BoxDecoration(
                                  color: primaryBlue,
                                  borderRadius: pw.BorderRadius.circular(10),
                                ),
                                child: pw.Text('TOTAL: $cargaHoraria H',
                                    style: pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.white,
                                        fontWeight: pw.FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        // Conteúdo: Atividades e Horários
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                flex: 3,
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('ATIVIDADES ATRIBUÍDAS',
                                        style: pw.TextStyle(
                                            fontSize: 7,
                                            fontWeight: pw.FontWeight.bold,
                                            color: textSecondary)),
                                    pw.SizedBox(height: 4),
                                    ...detalhes.map((detalhe) {
                                      final isDisciplina =
                                          detalhe['tipo'] == 'disciplina';
                                      final nome = detalhe['nome'] ?? '';
                                      final nomeExtenso =
                                          detalhe['nome_extenso'] ?? nome;
                                      final ch = detalhe['carga_horaria'] ?? 0;

                                      String infoAtividade = isDisciplina
                                          ? '$nome - $nomeExtenso ($ch h)'
                                          : '$nome ($ch h)';

                                      return pw.Padding(
                                        padding:
                                            const pw.EdgeInsets.only(bottom: 2),
                                        child: pw.Row(
                                          children: [
                                            pw.Container(
                                              width: 4,
                                              height: 4,
                                              margin: const pw.EdgeInsets.only(
                                                  right: 5),
                                              decoration: pw.BoxDecoration(
                                                color: isDisciplina
                                                    ? PdfColors.green700
                                                    : PdfColors.orange700,
                                                shape: pw.BoxShape.circle,
                                              ),
                                            ),
                                            pw.Expanded(
                                              child: pw.Text(infoAtividade,
                                                  style: const pw.TextStyle(
                                                      fontSize: 7.5)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                              pw.VerticalDivider(
                                  width: 20, color: PdfColors.grey200),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('DISPONIBILIDADE NA GRADE',
                                        style: pw.TextStyle(
                                            fontSize: 7,
                                            fontWeight: pw.FontWeight.bold,
                                            color: textSecondary)),
                                    pw.SizedBox(height: 4),
                                    pw.Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: diasTurnos.map((diaTurno) {
                                        return pw.Container(
                                          padding:
                                              const pw.EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 2),
                                          decoration: pw.BoxDecoration(
                                            color: accentBlue,
                                            borderRadius:
                                                pw.BorderRadius.circular(3),
                                          ),
                                          child: pw.Text(
                                              '${diaTurno['dia']} (${diaTurno['turno']})',
                                              style: pw.TextStyle(
                                                  fontSize: 6.5,
                                                  color: primaryBlue,
                                                  fontWeight:
                                                      pw.FontWeight.bold)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ];
          },
        ),
      );
    }

    // Página final: Resumo de Disciplinas
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildProfessionalHeader(logo, 'RESUMO DE DISCIPLINAS',
                  context.pageNumber, context.pagesCount),
              pw.SizedBox(height: 15),
              _buildResumoDisciplinasPDF(grade),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Relatório Administrativo de Grade Horária',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey500,
                          fontStyle: pw.FontStyle.italic)),
                  pw.Text(
                      'Emitido em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await pdf.save(),
    );
  }

  static pw.Widget _buildProfessionalHeader(
      pw.MemoryImage logo, String titulo, int paginaAtual, int? totalPaginas) {
    String paginacao = totalPaginas == 0 || totalPaginas == null
        ? 'PÁGINA $paginaAtual'
        : 'PÁGINA $paginaAtual DE $totalPaginas';

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(bottom: pw.BorderSide(color: primaryBlue, width: 1.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Image(logo, height: 40),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('UNIVERSIDADE FEDERAL DA PARAÍBA',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: textMain)),
                pw.Text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: textMain)),
                pw.Text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: textMain)),
                pw.SizedBox(height: 4),
                pw.Text(titulo,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryBlue)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: accentBlue,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  paginacao,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'SISTEMA DRI',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          children: [
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildResumoGeralPDF(
      Map<String, List<Map<String, dynamic>>> grade,
      Map<String, int> cargaHorariaProfessores) {
    final totalAulas =
        grade.values.fold<int>(0, (total, aulas) => total + aulas.length);
    final totalProfessores = cargaHorariaProfessores.length;
    final totalDisciplinas = <String>{};

    for (var entry in grade.entries) {
      for (var aula in entry.value) {
        if (aula['disciplina_nome'] != null) {
          totalDisciplinas.add(aula['disciplina_nome']);
        }
      }
    }

    return pw.Row(
      children: [
        _buildStatCard(
            'Aulas Atribuídas', totalAulas.toString(), PdfColors.blue700),
        pw.SizedBox(width: 10),
        _buildStatCard(
            'Docentes Ativos', totalProfessores.toString(), PdfColors.green700),
        pw.SizedBox(width: 10),
        _buildStatCard('Disciplinas', totalDisciplinas.length.toString(),
            PdfColors.orange700),
        pw.SizedBox(width: 10),
        _buildStatCard(
            'Ocupação Grade', '${grade.length} horários', PdfColors.purple700),
      ],
    );
  }

  static pw.Widget _buildGradePDFCompleta(
      Map<String, List<Map<String, dynamic>>> grade,
      List<String> diasSemana,
      String Function(int) getTurnoDoHorario,
      Function(int) getIndiceNoTurno,
      Function(int) getHorarioFormatado) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        for (int i = 1; i <= diasSemana.length; i++)
          i: const pw.FlexColumnWidth(1.0),
      },
      children: [
        // Cabeçalho dos Dias
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: primaryBlue),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('HORÁRIO',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center),
            ),
            ...diasSemana.map((dia) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(dia.toUpperCase(),
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                )),
          ],
        ),
        // Corpo da Grade
        ...List.generate(16, (index) {
          final indice = index + 1;
          final turno = getTurnoDoHorario(indice);
          final horario = getHorarioFormatado(indice);
          final rowColor = _getTurnoColorPDF(turno);

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowColor),
            children: [
              // Coluna Horário
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('$indiceº ($turno)',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey700)),
                    pw.Text(horario,
                        style:
                            const pw.TextStyle(fontSize: 7, color: textMain)),
                  ],
                ),
              ),
              // Colunas dos Dias
              ...diasSemana.map((dia) {
                final key = '$dia-$turno-${getIndiceNoTurno(indice)}';
                final aulas = grade[key] ?? [];
                return pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  constraints: const pw.BoxConstraints(minHeight: 35),
                  child: _buildCelulaGradeModern(aulas),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildCelulaGradeModern(List<Map<String, dynamic>> aulas) {
    if (aulas.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: aulas.map((aula) {
        final disciplinaNome = aula['disciplina_nome'] ?? '';
        final professores = (aula['professores_nomes'] as List).join(', ');
        final sigla = getSiglaDisciplina(disciplinaNome);

        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 2),
          padding: const pw.EdgeInsets.all(3),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(2),
            border: pw.Border.all(color: PdfColors.blue100, width: 0.5),
          ),
          child: pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 6),
              children: [
                pw.TextSpan(
                    text: sigla,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, color: primaryBlue)),
                pw.TextSpan(
                    text: '\n$professores',
                    style: const pw.TextStyle(color: textMain, fontSize: 5.5)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildResumoDisciplinasPDF(
      Map<String, List<Map<String, dynamic>>> grade) {
    final disciplinasUtilizadas = <String, Map<String, dynamic>>{};

    for (var entry in grade.entries) {
      for (var aula in entry.value) {
        final disciplinaNome = aula['disciplina_nome'] ?? '';
        final disciplinaNomeExtenso =
            aula['disciplina_nome_extenso'] ?? disciplinaNome;

        if (!disciplinasUtilizadas.containsKey(disciplinaNome)) {
          disciplinasUtilizadas[disciplinaNome] = {
            'nome': disciplinaNome,
            'nome_extenso': disciplinaNomeExtenso,
            'aulas': 0,
            'professores': <String>{},
          };
        }

        disciplinasUtilizadas[disciplinaNome]!['aulas'] =
            (disciplinasUtilizadas[disciplinaNome]!['aulas'] as int) + 1;

        final professores = aula['professores_nomes'] as List;
        for (var professor in professores) {
          (disciplinasUtilizadas[disciplinaNome]!['professores'] as Set<String>)
              .add(professor);
        }
      }
    }

    final disciplinasList = disciplinasUtilizadas.values.toList()
      ..sort((a, b) => (b['aulas'] as int).compareTo(a['aulas'] as int));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(60), // Sigla
        1: const pw.FlexColumnWidth(2.0), // Nome
        2: const pw.FixedColumnWidth(40), // Aulas
        3: const pw.FlexColumnWidth(1.5), // Professores
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: headerGrey),
          children: [
            _buildTableHeaderCell('SIGLA'),
            _buildTableHeaderCell('NOME DA DISCIPLINA'),
            _buildTableHeaderCell('AULAS'),
            _buildTableHeaderCell('PROFESSORES ATRIBUÍDOS'),
          ],
        ),
        ...disciplinasList.map((disciplina) {
          final sigla = getSiglaDisciplina(disciplina['nome'] ?? '');
          final nomeExtenso = disciplina['nome_extenso'] ?? '';
          final aulas = disciplina['aulas'] as int;
          final professoresArr =
              (disciplina['professores'] as Set<String>).toList()..sort();

          return pw.TableRow(
            children: [
              _buildTableCell(sigla, isBold: true, color: primaryBlue),
              _buildTableCell(nomeExtenso),
              _buildTableCell(aulas.toString(), align: pw.TextAlign.center),
              _buildTableCell(professoresArr.join(', ')),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _buildTableCell(String text,
      {bool isBold = false,
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor color = textMain}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color)),
    );
  }

  static PdfColor _getTurnoColorPDF(String turno) {
    switch (turno) {
      case 'Manhã':
        return morningColor;
      case 'Tarde':
        return afternoonColor;
      case 'Noite':
        return nightColor;
      default:
        return PdfColors.white;
    }
  }

  static String getSiglaDisciplina(String nomeCompleto) {
    if (nomeCompleto.length <= 8) return nomeCompleto.toUpperCase();

    final palavras = nomeCompleto.split(' ');
    if (palavras.length > 1) {
      return palavras
          .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
          .join('');
    }

    return nomeCompleto.substring(0, 3).toUpperCase();
  }

  static List<Map<String, String>> _getDiasTurnosProfessor(String professor,
      Map<String, List<Map<String, dynamic>>> horariosProfessores) {
    final horarios = horariosProfessores[professor] ?? [];
    final diasTurnos = <String, Map<String, String>>{};

    for (var horario in horarios) {
      final dia = horario['dia'] ?? '';
      final turno = horario['turno'] ?? '';
      final key = '$dia-$turno';

      if (!diasTurnos.containsKey(key)) {
        diasTurnos[key] = {'dia': dia, 'turno': turno};
      }
    }

    final listaDiasTurnos = diasTurnos.values.toList();

    final ordemDias = {
      'Seg': 1,
      'Ter': 2,
      'Qua': 3,
      'Qui': 4,
      'Sex': 5,
      'Sáb': 6
    };
    final ordemTurnos = {'Manhã': 1, 'Tarde': 2, 'Noite': 3};

    listaDiasTurnos.sort((a, b) {
      final diaA = ordemDias[a['dia']] ?? 7;
      final diaB = ordemDias[b['dia']] ?? 7;
      if (diaA != diaB) return diaA.compareTo(diaB);
      final turnoA = ordemTurnos[a['turno']] ?? 4;
      final turnoB = ordemTurnos[b['turno']] ?? 4;
      return turnoA.compareTo(turnoB);
    });

    return listaDiasTurnos;
  }
}
