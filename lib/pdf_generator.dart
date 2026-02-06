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

// Importação condicional para web
import 'dart:html' if (dart.library.io) 'dart:html' as web;

class PdfGenerator {
  static final supabase = Supabase.instance.client;

  // --------------------------- ATA DE DEFESA ---------------------------
  static Future<void> generateAtaDefesa(Map<String, dynamic> defesa) async {
    try {
      final pdf = pw.Document();

      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/ufpb.png')).buffer.asUint8List(),
      );

      // Carregar dados finais da defesa
      final dadosFinais = await _carregarDadosFinaisDefesa(defesa['id']);
      // Carregar notas dos avaliadores
      final notasAvaliadores = await _carregarNotasDefesa(defesa['id']);

      DateTime dataDefesa = defesa['dia'] != null
          ? DateTime.parse(defesa['dia'])
          : DateTime.now();
      String dataExtenso = _formatarDataPorExtensoFormal(dataDefesa);
      String horaFormatada = defesa['hora'] != null
          ? _formatarHoraFormal(defesa['hora'])
          : '--:--';

      // Calcular média final
      double mediaFinal = _calcularMediaFinal(notasAvaliadores);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(71, 50, 71, 85),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Image(logo, height: 35),
                    pw.SizedBox(width: 5),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('UNIVERSIDADE FEDERAL DA PARAÍBA',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        pw.Text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        pw.Text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),

                // Título sublinhado
                pw.Center(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                      ),
                    ),
                    child: pw.Text(
                      'ATA DE DEFESA DE TRABALHO DE CONCLUSÃO DE CURSO',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                pw.SizedBox(height: 40),

                // Corpo da Ata
                pw.Text(
                  '$dataExtenso, às $horaFormatada, realizou-se, ${defesa['local'] != null ? 'na(o) ${defesa['local']}' : 'local a definir'}, a defesa do Trabalho de Conclusão de Curso de Relações Internacionais do(a) aluno(a) ${defesa['discente']?.toUpperCase() ?? ''}, matrícula ${defesa['matricula'] ?? '__________'}, sob orientação do(a) ${defesa['orientador'] ?? ''}${defesa['coorientador'] != null && defesa['coorientador']!.isNotEmpty ? ' e coorientação do(a) ${defesa['coorientador']}' : ''} intitulado "${defesa['titulo'] ?? ''}". Pelos membros da banca foram atribuídas as seguintes notas:',
                  textAlign: pw.TextAlign.justify,
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 36),

                pw.Column(
                  children: [
                    _buildAvaliadorComNota(
                      nome: defesa['avaliador1'] ?? '',
                      nota: _obterNotaAvaliador(notasAvaliadores, 1),
                    ),
                    pw.SizedBox(height: 25),
                    _buildAvaliadorComNota(
                      nome: defesa['avaliador2'] ?? '',
                      nota: _obterNotaAvaliador(notasAvaliadores, 2),
                    ),
                    pw.SizedBox(height: 25),
                    _buildAvaliadorComNota(
                      nome: defesa['avaliador3'] ?? '',
                      nota: _obterNotaAvaliador(notasAvaliadores, 3),
                    ),
                  ],
                ),
                pw.SizedBox(height: 36),

                // Resultado e média final
                pw.Text(
                  'O(A) aluno(a) foi ${dadosFinais?['resultado']?.toUpperCase() ?? '________________________'} com a média final de ${mediaFinal > 0 ? mediaFinal.toStringAsFixed(1) : '__________'}.',
                  textAlign: pw.TextAlign.justify,
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 12),

                // Observações
                if (dadosFinais?['observacoes_finais'] != null &&
                    dadosFinais!['observacoes_finais'].toString().isNotEmpty)
                  pw.Text(
                    'Obs: ${dadosFinais['observacoes_finais']}',
                    textAlign: pw.TextAlign.justify,
                    style: pw.TextStyle(fontSize: 11),
                  )
                else
                  pw.Text(
                    'Obs:_________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________',
                    textAlign: pw.TextAlign.justify,
                    style: pw.TextStyle(fontSize: 11),
                  ),
                pw.SizedBox(height: 40),

                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Campus Universitário I - Cidade Universitária',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text('58.051-900 -- João Pessoa -- Paraíba -- Brasil',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text('Fone: (00 55) (83) 3216-7451',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.Text('E-mail: departamentori@ccsa.ufpb.br',
                          style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      String nomeArquivo =
          'Ata_Defesa - ${_formatarNomeArquivo(defesa['discente'] ?? 'defesa')}';
      await _salvarPdfComNome(pdf, nomeArquivo);
    } catch (e) {
      print('Erro ao gerar ata de defesa: $e');
      rethrow;
    }
  }

  // --------------------------- FOLHA DE APROVAÇÃO ---------------------------
  static Future<void> generateFolhaAprovacao(
      Map<String, dynamic> defesa) async {
    try {
      if (defesa['id'] == null) {
        throw Exception('ID da defesa não pode ser nulo');
      }

      final pdf = pw.Document();

      final dadosFinais = await _carregarDadosFinaisDefesa(defesa['id']);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(71, 50, 71, 50),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    defesa['discente']?.toUpperCase() ?? '',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    '"${defesa['titulo'] ?? ''}"',
                    style: pw.TextStyle(fontSize: 11),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.SizedBox(height: 20),

                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 5, child: pw.Container()),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        'Trabalho de Conclusão de Curso apresentado ao Curso de Relações Internacionais do Centro de Ciências Sociais Aplicadas (CCSA) da Universidade Federal da Paraíba (UFPB), como requisito parcial para obtenção do grau de bacharel(a) em Relações Internacionais.',
                        textAlign: pw.TextAlign.justify,
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),

                // Data aprovado(a)
                pw.Text(
                  dadosFinais?['data_aprovacao'] != null
                      ? 'Aprovado(a) em ${_formatarDataPorExtensoSimples(DateTime.parse(dadosFinais!['data_aprovacao']))}'
                      : 'Aprovado(a) em, ___ de _____________ de _____',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.left,
                ),

                // Espaços antes da primeira assinatura
                pw.SizedBox(height: 20),
                pw.SizedBox(height: 20),
                pw.SizedBox(height: 20),

                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('_' * 60),
                      pw.SizedBox(height: 8),
                      pw.Text('${defesa['orientador'] ?? ''} - (Orientador)'),
                      pw.SizedBox(height: 4),
                      pw.Text(defesa['instituto_av1'] ?? ''),
                      pw.SizedBox(height: 20),
                      pw.SizedBox(height: 20),
                      pw.SizedBox(height: 20),
                      pw.SizedBox(height: 20),
                      pw.Text('_' * 60),
                      pw.SizedBox(height: 8),
                      pw.Text(defesa['avaliador2'] ?? ''),
                      pw.SizedBox(height: 4),
                      pw.Text(defesa['instituto_av2'] ?? ''),
                      pw.SizedBox(height: 20),
                      pw.SizedBox(height: 20),
                      pw.SizedBox(height: 20),
                      pw.SizedBox(height: 20),
                      pw.Text('_' * 60),
                      pw.SizedBox(height: 8),
                      pw.Text(defesa['avaliador3'] ?? ''),
                      pw.SizedBox(height: 4),
                      pw.Text(defesa['instituto_av3'] ?? ''),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      String nomeArquivo =
          'Folha_Aprovacao - ${_formatarNomeArquivo(defesa['discente'] ?? 'aprovacao')}';
      await _salvarPdfComNome(pdf, nomeArquivo);
    } catch (e) {
      print('Erro ao gerar folha de aprovação: $e');
      rethrow;
    }
  }

  // --------------------------- RELATÓRIO DE PARTICIPANTES ---------------------------
  static Future<void> generateRelatorioParticipantesReport(
      List<dynamic> participantes, // Espera uma lista de Participante ou Map
      String? semestre,
      String? professor) async {
    try {
      final pdf = pw.Document();

      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/ufpb.png')).buffer.asUint8List(),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          header: (pw.Context context) => pw.Column(
            children: [
              pw.Row(
                children: [
                  pw.Image(logo, height: 30),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          'UFPB - CCSA - DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Relatório de Participações - Docentes',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.purple700)),
                      pw.Text(
                          '${semestre != null ? 'Semestre: $semestre' : 'Todos os Semestres'} | ${professor != null ? 'Docente: $professor' : 'Todos os Docentes'}',
                          style: pw.TextStyle(
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
          ),
          build: (pw.Context context) {
            return [
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4), // Professor
                  1: const pw.FixedColumnWidth(80), // Orientador
                  2: const pw.FixedColumnWidth(80), // Coorientador
                  3: const pw.FixedColumnWidth(80), // Avaliador
                  4: const pw.FixedColumnWidth(60), // Total
                },
                children: [
                  // Cabeçalho da Tabela
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.purple50),
                    children: [
                      _buildHeaderPdf('PROFESSOR'),
                      _buildHeaderPdf('ORIENTADOR'),
                      _buildHeaderPdf('COORIENTADOR'),
                      _buildHeaderPdf('AVALIADOR'),
                      _buildHeaderPdf('TOTAL'),
                    ],
                  ),
                  // Linhas de Dados ordenadas por regras de prioridade: Total > Orientador > Coorientador > Avaliador
                  ...(() {
                    final listaOrdenada = List.from(participantes);
                    listaOrdenada.sort((a, b) {
                      final aTot = a is Map ? (a['total'] ?? 0) : a.total;
                      final bTot = b is Map ? (b['total'] ?? 0) : b.total;
                      if (aTot != bTot) return bTot.compareTo(aTot);

                      final aOri =
                          a is Map ? (a['orientador'] ?? 0) : a.orientador;
                      final bOri =
                          b is Map ? (b['orientador'] ?? 0) : b.orientador;
                      if (aOri != bOri) return bOri.compareTo(aOri);

                      final aCoo =
                          a is Map ? (a['coorientador'] ?? 0) : a.coorientador;
                      final bCoo =
                          b is Map ? (b['coorientador'] ?? 0) : b.coorientador;
                      if (aCoo != bCoo) return bCoo.compareTo(aCoo);

                      final aAva =
                          a is Map ? (a['avaliador'] ?? 0) : a.avaliador;
                      final bAva =
                          b is Map ? (b['avaliador'] ?? 0) : b.avaliador;
                      return bAva.compareTo(aAva);
                    });
                    return listaOrdenada;
                  }())
                      .map((p) {
                    // Trata tanto objeto Participante quanto Map
                    final String nome = p is Map ? (p['nome'] ?? '') : p.nome;
                    final int orient =
                        p is Map ? (p['orientador'] ?? 0) : p.orientador;
                    final int coorient =
                        p is Map ? (p['coorientador'] ?? 0) : p.coorientador;
                    final int aval =
                        p is Map ? (p['avaliador'] ?? 0) : p.avaliador;
                    final int total = p is Map ? (p['total'] ?? 0) : p.total;

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(nome.toUpperCase(),
                              style: const pw.TextStyle(fontSize: 8)),
                        ),
                        _buildCellPdf(orient.toString()),
                        _buildCellPdf(coorient.toString()),
                        _buildCellPdf(aval.toString()),
                        _buildCellPdf(total.toString(), isBold: true),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
          footer: (pw.Context context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8)),
          ),
        ),
      );

      final nomeArquivo =
          'Relatorio_Participacoes_Docentes_${DateFormat('yyyyMMdd').format(DateTime.now())}';
      await _salvarPdfComNome(pdf, nomeArquivo);
    } catch (e) {
      print('Erro ao gerar relatório de participações: $e');
      rethrow;
    }
  }

  // --------------------------- RELATÓRIO DE SITUAÇÃO ---------------------------
  static Future<void> generateSituacaoDefesasReport(
      List<Map<String, dynamic>> defesas,
      Map<int, List<Map<String, dynamic>>> notasPorDefesa,
      String? semestre) async {
    try {
      final pdf = pw.Document();

      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/ufpb.png')).buffer.asUint8List(),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          header: (pw.Context context) => pw.Column(
            children: [
              pw.Row(
                children: [
                  pw.Image(logo, height: 30),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          'UFPB - CCSA - DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(
                          'Relatório de Situação das Defesas${semestre != null ? ' - Semestre $semestre' : ''}',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey700)),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Text(
                      'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
            ],
          ),
          build: (pw.Context context) {
            return [
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(55), // Data
                  1: const pw.FlexColumnWidth(3), // Discente
                  2: const pw.FlexColumnWidth(2.5), // Orientador
                  3: const pw.FixedColumnWidth(35), // Docs
                  4: const pw.FixedColumnWidth(38), // Nota O
                  5: const pw.FixedColumnWidth(38), // Nota 1
                  6: const pw.FixedColumnWidth(38), // Nota 2
                  7: const pw.FixedColumnWidth(42), // Média
                  8: const pw.FixedColumnWidth(35), // TCC
                  9: const pw.FixedColumnWidth(35), // Termo
                },
                children: [
                  // Cabeçalho da Tabela
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildHeaderPdf('DATA'),
                      _buildHeaderPdf('DISCENTE'),
                      _buildHeaderPdf('ORIENTADOR'),
                      _buildHeaderPdf('DOCS'),
                      _buildHeaderPdf('N.ORI'),
                      _buildHeaderPdf('N.AV1'),
                      _buildHeaderPdf('N.AV2'),
                      _buildHeaderPdf('MÉDIA'),
                      _buildHeaderPdf('TCC'),
                      _buildHeaderPdf('TERM'),
                    ],
                  ),
                  // Linhas de Dados
                  ...defesas.map((defesa) {
                    final notas = notasPorDefesa[defesa['id']] ?? [];
                    final nOri = _obterNotaAvaliador(notas, 1);
                    final nAv1 = _obterNotaAvaliador(notas, 2);
                    final nAv2 = _obterNotaAvaliador(notas, 3);

                    List<double> validas = [];
                    if (nOri.isNotEmpty) validas.add(double.parse(nOri));
                    if (nAv1.isNotEmpty) validas.add(double.parse(nAv1));
                    if (nAv2.isNotEmpty) validas.add(double.parse(nAv2));

                    String media = validas.isNotEmpty
                        ? (validas.reduce((a, b) => a + b) / validas.length)
                            .toStringAsFixed(1)
                        : '-';

                    return pw.TableRow(
                      children: [
                        _buildCellPdf(defesa['dia'] != null
                            ? DateFormat('dd/MM/yy')
                                .format(DateTime.parse(defesa['dia']))
                            : ''),
                        _buildCellPdf(
                            defesa['discente']?.toString().toUpperCase() ?? ''),
                        _buildCellPdf(defesa['orientador'] ?? ''),
                        _buildCellPdf(defesa['doc_outros_devolvido'] == true
                            ? 'Sim'
                            : 'Não'),
                        _buildCellPdf(nOri),
                        _buildCellPdf(nAv1),
                        _buildCellPdf(nAv2),
                        _buildCellPdf(media, isBold: true),
                        _buildCellPdf(defesa['doc_tcc_devolvido'] == true
                            ? 'Sim'
                            : 'Não'),
                        _buildCellPdf(defesa['doc_termo_devolvido'] == true
                            ? 'Sim'
                            : 'Não'),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
          footer: (pw.Context context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8)),
          ),
        ),
      );

      final nomeArquivo =
          'Relatorio_Situacao_Defesas${semestre != null ? '_$semestre' : ''}';
      await _salvarPdfComNome(pdf, nomeArquivo);
    } catch (e) {
      print('Erro ao gerar relatório: $e');
      rethrow;
    }
  }

  static pw.Widget _buildHeaderPdf(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        textAlign: pw.TextAlign.center,
        softWrap: false,
      ),
    );
  }

  static pw.Widget _buildCellPdf(String? text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: pw.Text(
        text ?? '',
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // --------------------------- FUNÇÕES AUXILIARES ---------------------------
  static pw.Widget _buildAvaliadorComNota(
      {required String nome, required String nota}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        pw.Container(
          width: 120,
          height: 40,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
          ),
          padding: const pw.EdgeInsets.only(left: 8),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'NOTA: $nota',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
        ),
        pw.SizedBox(width: 30),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Center(
                child: pw.Container(
                  width: 350,
                  height: 1,
                  color: PdfColors.black,
                ),
              ),
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    nome,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------- BANCO DE DADOS ---------------------------
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

  static String _obterNotaAvaliador(
      List<Map<String, dynamic>> notas, int numeroAvaliador) {
    try {
      final notaAvaliador = notas.firstWhere(
        (nota) => nota['avaliador_numero'] == numeroAvaliador,
        orElse: () => {},
      );

      if (notaAvaliador.isNotEmpty) {
        // Verificar se foi usado o modo nota total
        final bool modoNotaTotal = notaAvaliador['modo_nota_total'] ?? false;

        if (modoNotaTotal && notaAvaliador['nota_total'] != null) {
          // Usar a nota total direta
          final notaTotal = notaAvaliador['nota_total'];
          return notaTotal > 0 ? notaTotal.toStringAsFixed(1) : '';
        } else {
          // Calcular a nota pelos critérios individuais (modo antigo)
          final nfEscrito = (notaAvaliador['introducao'] ?? 0.0) +
              (notaAvaliador['problematizacao'] ?? 0.0) +
              (notaAvaliador['referencial'] ?? 0.0) +
              (notaAvaliador['desenvolvimento'] ?? 0.0) +
              (notaAvaliador['conclusoes'] ?? 0.0) +
              (notaAvaliador['forma'] ?? 0.0);

          final nfApresentacao = (notaAvaliador['estruturacao'] ?? 0.0) +
              (notaAvaliador['clareza'] ?? 0.0) +
              (notaAvaliador['dominio'] ?? 0.0);

          final notaFinal = nfEscrito + nfApresentacao;

          return notaFinal > 0 ? notaFinal.toStringAsFixed(1) : '';
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  static double _calcularMediaFinal(List<Map<String, dynamic>> notas) {
    if (notas.isEmpty) return 0.0;

    double somaTotal = 0.0;
    int avaliadoresComNota = 0;

    for (var nota in notas) {
      double notaFinal = 0.0;

      // Verificar se foi usado o modo nota total
      final bool modoNotaTotal = nota['modo_nota_total'] ?? false;

      if (modoNotaTotal && nota['nota_total'] != null) {
        // Usar a nota total direta
        notaFinal = nota['nota_total'] ?? 0.0;
      } else {
        // Calcular a nota pelos critérios individuais (modo antigo)
        final nfEscrito = (nota['introducao'] ?? 0.0) +
            (nota['problematizacao'] ?? 0.0) +
            (nota['referencial'] ?? 0.0) +
            (nota['desenvolvimento'] ?? 0.0) +
            (nota['conclusoes'] ?? 0.0) +
            (nota['forma'] ?? 0.0);

        final nfApresentacao = (nota['estruturacao'] ?? 0.0) +
            (nota['clareza'] ?? 0.0) +
            (nota['dominio'] ?? 0.0);

        notaFinal = nfEscrito + nfApresentacao;
      }

      if (notaFinal > 0) {
        somaTotal += notaFinal;
        avaliadoresComNota++;
      }
    }

    return avaliadoresComNota > 0 ? somaTotal / avaliadoresComNota : 0.0;
  }

  // --------------------------- SALVAR PDF (CORRIGIDO) ---------------------------
  static Future<void> _salvarPdfComNome(
      pw.Document pdf, String nomeArquivo) async {
    final bytes = await pdf.save();

    // Garantir que o nome do arquivo tenha extensão .pdf
    if (!nomeArquivo.toLowerCase().endsWith('.pdf')) {
      nomeArquivo = '$nomeArquivo.pdf';
    }

    try {
      // Para web - download direto
      if (kIsWeb) {
        _downloadPdfWeb(bytes, nomeArquivo);
        return;
      }

      // Para mobile/desktop
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
      // Fallback: usar printing se disponível
      await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);
    }
  }

  // Método específico para download na web
  static void _downloadPdfWeb(List<int> bytes, String nomeArquivo) {
    // Criar blob e fazer download
    final blob = web.Blob([bytes], 'application/pdf');
    final url = web.Url.createObjectUrlFromBlob(blob);
    final anchor = web.AnchorElement(href: url)
      ..setAttribute('download', nomeArquivo)
      ..click();
    web.Url.revokeObjectUrl(url);
  }

  // --------------------------- FORMATAÇÃO DE NOMES ---------------------------
  static String _formatarNomeArquivo(String nomeAluno) {
    String nomeLimpo = nomeAluno.replaceAll(
        RegExp(r'[^\w\sáàâãéèêíïóôõöúçñÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇÑ]'), '');
    nomeLimpo = nomeLimpo.trim().replaceAll(RegExp(r'\s+'), ' ');
    return nomeLimpo;
  }

  // --------------------------- FORMATAÇÃO DE DATAS ---------------------------
  static String _formatarDataPorExtensoFormal(DateTime data) {
    final meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];

    String diaExtenso = _numeroDiaPorExtenso(data.day);
    String anoExtenso = _numeroAnoPorExtenso(data.year);

    return 'Ao $diaExtenso dia de ${meses[data.month - 1]} de $anoExtenso';
  }

  static String _numeroDiaPorExtenso(int dia) {
    const dias = [
      '',
      'primeiro',
      'segundo',
      'terceiro',
      'quarto',
      'quinto',
      'sexto',
      'sétimo',
      'oitavo',
      'nono',
      'décimo',
      'décimo primeiro',
      'décimo segundo',
      'décimo terceiro',
      'décimo quarto',
      'décimo quinto',
      'décimo sexto',
      'décimo sétimo',
      'décimo oitavo',
      'décimo nono',
      'vigésimo',
      'vigésimo primeiro',
      'vigésimo segundo',
      'vigésimo terceiro',
      'vigésimo quarto',
      'vigésimo quinto',
      'vigésimo sexto',
      'vigésimo sétimo',
      'vigésimo oitavo',
      'vigésimo nono',
      'trigésimo',
      'trigésimo primeiro'
    ];
    return dias[dia];
  }

  static String _numeroAnoPorExtenso(int ano) {
    Map<int, String> unidades = {
      0: '',
      1: 'um',
      2: 'dois',
      3: 'três',
      4: 'quatro',
      5: 'cinco',
      6: 'seis',
      7: 'sete',
      8: 'oito',
      9: 'nove'
    };

    Map<int, String> dezenasEspeciais = {
      10: 'dez',
      11: 'onze',
      12: 'doze',
      13: 'treze',
      14: 'quatorze',
      15: 'quinze',
      16: 'dezesseis',
      17: 'dezessete',
      18: 'dezoito',
      19: 'dezenove'
    };

    Map<int, String> dezenas = {
      2: 'vinte',
      3: 'trinta',
      4: 'quarenta',
      5: 'cinquenta',
      6: 'sessenta',
      7: 'setenta',
      8: 'oitenta',
      9: 'noventa'
    };

    int milhar = ano ~/ 1000;
    int restoMilhar = ano % 1000;
    int centena = restoMilhar ~/ 100;
    int dezena = (restoMilhar % 100) ~/ 10;
    int unidade = restoMilhar % 10;

    String resultado = '';
    resultado += '${unidades[milhar] ?? ''} mil';

    if (restoMilhar > 0) {
      resultado += ' e ';
      if (restoMilhar < 10) {
        resultado += unidades[restoMilhar] ?? '';
      } else if (restoMilhar < 20) {
        resultado += dezenasEspeciais[restoMilhar] ?? '';
      } else {
        resultado += dezenas[dezena] ?? '';
        if (unidade > 0) {
          resultado += ' e ${unidades[unidade] ?? ''}';
        }
      }
    }

    return resultado;
  }

  static String _formatarHoraFormal(String hora) {
    try {
      final parsed = DateTime.parse('1970-01-01T$hora');
      return '${parsed.hour}h${parsed.minute.toString().padLeft(2, '0')}min';
    } catch (_) {
      return hora;
    }
  }

  static String _formatarDataPorExtensoSimples(DateTime data) {
    final meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];
    return '${data.day} de ${meses[data.month - 1]} de ${data.year}';
  }
}
