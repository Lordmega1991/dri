import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';
import { supabase } from './supabaseClient';

export interface Defesa {
    id: number;
    discente: string;
    matricula?: string;
    titulo: string;
    dia: string;
    hora: string;
    local: string;
    orientador: string;
    coorientador?: string;
    avaliador1: string;
    avaliador2: string;
    avaliador3: string;
    instituto_av1?: string;
    instituto_av2?: string;
    instituto_av3?: string;
    semestre: string;
    [key: string]: any;
}

const meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
];

// Helper para formatar data por extenso formal (Ex: Ao vigésimo dia de...)
const dataExtensoFormal = (dateStr: string) => {
    if (!dateStr) return 'Ao ___ dia de _____________ de _____';
    const date = new Date(dateStr + 'T12:00:00');

    const diasExtenso = [
        '', 'primeiro', 'segundo', 'terceiro', 'quarto', 'quinto', 'sexto', 'sétimo', 'oitavo', 'nono', 'décimo',
        'décimo primeiro', 'décimo segundo', 'décimo terceiro', 'décimo quarto', 'décimo quinto', 'décimo sexto', 'décimo sétimo', 'décimo oitavo', 'décimo nono', 'vigésimo',
        'vigésimo primeiro', 'vigésimo segundo', 'vigésimo terceiro', 'vigésimo quarto', 'vigésimo quinto', 'vigésimo sexto', 'vigésimo sétimo', 'vigésimo oitavo', 'vigésimo nono', 'trigésimo', 'trigésimo primeiro'
    ];

    const anosExtenso: Record<number, string> = {
        2024: 'dois mil e vinte e quatro',
        2025: 'dois mil e vinte e cinco',
        2026: 'dois mil e vinte e seis',
        2027: 'dois mil e vinte e sete',
        2028: 'dois mil e vinte e oito',
        2029: 'dois mil e vinte e nove',
        2030: 'dois mil e trinta'
    };

    const dia = diasExtenso[date.getDate()];
    const mes = meses[date.getMonth()];
    const ano = anosExtenso[date.getFullYear()] || date.getFullYear().toString();

    return `Ao ${dia} dia de ${mes} de ${ano}`;
};

const formatarHoraFormal = (hora: string) => {
    if (!hora) return '--:--';
    const parts = hora.split(':');
    if (parts.length >= 2) {
        const h = parseInt(parts[0]);
        const m = parts[1].padStart(2, '0');
        return `${h}h${m}min`;
    }
    return hora;
};

// Conversão de pontos (pt) para mm (1 pt = 0.352778 mm)
const ptToMm = (pt: number) => pt * 0.352778;

const loadImage = (url: string): Promise<{ data: string, ratio: number }> => {
    return new Promise((resolve) => {
        const img = new Image();
        img.onload = () => {
            const canvas = document.createElement('canvas');
            canvas.width = img.width;
            canvas.height = img.height;
            const ctx = canvas.getContext('2d');
            ctx?.drawImage(img, 0, 0);
            resolve({
                data: canvas.toDataURL('image/png'),
                ratio: img.height / img.width
            });
        };
        img.src = url;
    });
};

export const generateAta = async (defesa: Defesa) => {
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
    const width = doc.internal.pageSize.getWidth();
    const height = doc.internal.pageSize.getHeight();

    // Margens compactas para garantir 1 página
    const marginL = 25;
    const marginT = 15;
    const marginR = 25;
    const contentWidth = width - marginL - marginR;

    // Logo UFPB com proporção preservada e altura casando com o cabeçalho
    const logo = await loadImage('/assets/ufpb.png');
    // Altura do cabeçalho de 3 linhas (aprox 12mm considerando gaps)
    const logoH = 14;
    const logoW = logoH / logo.ratio;
    doc.addImage(logo.data, 'PNG', marginL, marginT, logoW, logoH);

    // Cabeçalho - Alinhado ao lado do logo
    doc.setFont('times', 'bold');
    doc.setFontSize(9);
    const headerX = marginL + logoW + 4; // 4mm de gap
    // Ajuste fino para centralizar verticalmente o texto com o logo de 14mm
    doc.text('UNIVERSIDADE FEDERAL DA PARAÍBA', headerX, marginT + 4);
    doc.text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS', headerX, marginT + 8.5);
    doc.text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS', headerX, marginT + 13);

    // Título - Ajustado conforme a altura do logo
    const titleY = marginT + logoH + 12;
    doc.setFontSize(12);
    doc.text('ATA DE DEFESA DE TRABALHO DE CONCLUSÃO DE CURSO', width / 2, titleY, { align: 'center' });
    const titleW = doc.getTextWidth('ATA DE DEFESA DE TRABALHO DE CONCLUSÃO DE CURSO');
    doc.setLineWidth(0.4);
    doc.line(width / 2 - (titleW / 2), titleY + 1, width / 2 + (titleW / 2), titleY + 1);

    // Buscar dados
    const { data: notas } = await supabase.from('notas').select('*').eq('defesa_id', defesa.id);
    const { data: dadosFinais } = await supabase.from('dados_defesa_final').select('*').eq('defesa_id', defesa.id).maybeSingle();

    const obterNota = (num: number) => {
        const n = notas?.find(nt => nt.avaliador_numero === num);
        return n ? n.nota_total?.toFixed(1) : '';
    };

    // Corpo da Ata
    let y = titleY + 18;
    doc.setFont('times', 'normal');
    doc.setFontSize(12);

    const coorientadorTexto = (defesa.coorientador && defesa.coorientador !== 'null' && defesa.coorientador !== '')
        ? ` e coorientação do(a) ${defesa.coorientador}`
        : '';

    const texto = `${dataExtensoFormal(defesa.dia)}, às ${formatarHoraFormal(defesa.hora)}, realizou-se, ${defesa.local ? `na(o) ${defesa.local}` : 'local a definir'}, a defesa do Trabalho de Conclusão de Curso de Relações Internacionais do(a) aluno(a) ${defesa.discente.toUpperCase()}, matrícula ${defesa.matricula || '__________'}, sob orientação do(a) ${defesa.orientador}${coorientadorTexto} intitulado "${defesa.titulo}". Pelos membros da banca foram atribuídas as seguintes notas:`;

    const splitText = doc.splitTextToSize(texto, contentWidth);
    doc.text(splitText, marginL, y, { align: 'justify', lineHeightFactor: 1.3, maxWidth: contentWidth });

    y += (splitText.length * 6) + 12;

    // Seção de Avaliadores
    const bancas = [
        { nome: defesa.orientador, nota: obterNota(1) },
        { nome: defesa.avaliador2, nota: obterNota(2) },
        { nome: defesa.avaliador3, nota: obterNota(3) },
    ].filter(b => b.nome && b.nome !== 'null');

    bancas.forEach((b) => {
        const boxW = 45;
        const boxH = 12;
        doc.setLineWidth(0.3);
        doc.rect(marginL, y, boxW, boxH);
        doc.setFont('times', 'bold');
        doc.setFontSize(12); // Aumentado
        doc.text('NOTA:', marginL + 3, y + 7.5);
        if (b.nota) {
            doc.text(b.nota, marginL + 25, y + 7.5, { align: 'center' });
        }

        const lineW = 92;
        const lineStart = width - marginR - lineW;
        const lineY = y + 4.5;
        doc.line(lineStart, lineY, lineStart + lineW, lineY);

        doc.setFontSize(11); // Aumentado
        doc.text(b.nome, lineStart + (lineW / 2), lineY + 5.5, { align: 'center' });

        y += 19;
    });

    // Espaço de uma linha após o último docente
    y += 8;

    // Média e Resultado
    let mediaVal = 0;
    if (notas && notas.length > 0) {
        mediaVal = notas.reduce((acc, n) => acc + (n.nota_total || 0), 0) / notas.length;
    }

    doc.setFont('times', 'normal');
    doc.setFontSize(12); // Aumentado

    doc.text('O(A) aluno(a) foi ', marginL, y);
    const resultLabelW = doc.getTextWidth('O(A) aluno(a) foi ');
    const resValue = dadosFinais?.resultado?.toUpperCase() || '';
    doc.text(resValue, marginL + resultLabelW + 5, y);
    doc.line(marginL + resultLabelW, y + 0.5, marginL + resultLabelW + 70, y + 0.5);

    const mediaLabel = ' com a média final de ';
    const mediaMargin = marginL + resultLabelW + 70;
    doc.text(mediaLabel, mediaMargin, y);
    const mediaLabelW = doc.getTextWidth(mediaLabel);
    const mediaStr = mediaVal > 0 ? mediaVal.toFixed(1) : '';
    doc.text(mediaStr, mediaMargin + mediaLabelW + 5, y);
    doc.line(mediaMargin + mediaLabelW, y + 0.5, mediaMargin + mediaLabelW + 20, y + 0.5);

    // Observações
    y += 12;
    doc.text('Obs:', marginL, y);
    doc.line(marginL + 10, y + 0.5, width - marginR, y + 0.5);

    for (let i = 1; i <= 3; i++) {
        doc.line(marginL, y + (i * 7.5) + 0.5, width - marginR, y + (i * 7.5) + 0.5);
    }

    if (dadosFinais?.observacoes_finais) {
        doc.setFontSize(10.5); // Aumentado
        doc.text(dadosFinais.observacoes_finais, marginL + 12, y - 0.5, { maxWidth: contentWidth - 12 });
    }

    // Rodapé
    doc.setFontSize(10); // Aumentado
    const footerY = height - 28;
    doc.text('Campus Universitário I - Cidade Universitária', width / 2, footerY, { align: 'center' });
    doc.text('58.051-900 -- João Pessoa -- Paraíba -- Brasil', width / 2, footerY + 4, { align: 'center' });
    doc.text('Fone: (00 55) (83) 3216-7451', width / 2, footerY + 8, { align: 'center' });
    doc.text('E-mail: departamentori@ccsa.ufpb.br', width / 2, footerY + 12, { align: 'center' });

    doc.save(`Ata_Defesa_${defesa.discente.replace(/\s+/g, '_')}.pdf`);
};

export const generateFolhaAprovacao = async (defesa: Defesa) => {
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
    const width = doc.internal.pageSize.getWidth();

    // Mesmas margens da ATA (Padronização A4)
    const marginL = 25;
    const marginT = 15;
    const marginR = 25;
    const contentWidth = width - marginL - marginR;

    const { data: dadosFinais } = await supabase.from('dados_defesa_final').select('*').eq('defesa_id', defesa.id).maybeSingle();

    let y = marginT + 10; // Começa um pouco abaixo para dar respiro no topo

    // Nome do Aluno (Centralizado, Negrito, 16pt)
    doc.setFont('times', 'bold');
    doc.setFontSize(16);
    doc.text(defesa.discente.toUpperCase(), width / 2, y, { align: 'center' });
    y += 30; // Reduzido de 40

    // Título (Centralizado, Normal, 12pt, aspas) - Aumentado 1pt
    doc.setFont('times', 'normal');
    doc.setFontSize(12);
    const titulo = `"${defesa.titulo}"`;
    const splitTitulo = doc.splitTextToSize(titulo, contentWidth);
    doc.text(splitTitulo, width / 2, y, { align: 'center' });
    y += 25; // Reduzido de 35

    // Texto de Aprovação (Coluna Direita - Flex 5 de 10) - Aumentado 1pt
    doc.setFontSize(11);
    const texto = 'Trabalho de Conclusão de Curso apresentado ao Curso de Relações Internacionais do Centro de Ciências Sociais Aplicadas (CCSA) da Universidade Federal da Paraíba (UFPB), como requisito parcial para obtenção do grau de bacharel(a) em Relações Internacionais.';
    const colWidth = contentWidth / 2;
    const splitTexto = doc.splitTextToSize(texto, colWidth);

    // Para alinhar à direita mantendo o justify, o X deve ser o início da coluna direita
    const textStartX = width - marginR - colWidth;
    doc.text(splitTexto, textStartX, y, { align: 'justify', lineHeightFactor: 1.3, maxWidth: colWidth });
    y += (splitTexto.length * 6) + 30;

    // Resultado / Data de Aprovação - Aumentado 1pt
    doc.setFont('times', 'bold');
    doc.setFontSize(12);

    let dataAprov = 'Aprovado(a) em, ___ de _____________ de _____';
    if (dadosFinais?.data_aprovacao) {
        const d = new Date(dadosFinais.data_aprovacao + 'T12:00:00');
        dataAprov = `Aprovado(a) em ${d.getDate()} de ${meses[d.getMonth()]} de ${d.getFullYear()}`;
    }
    doc.text(dataAprov, marginL, y);
    y += 35; // Reduzido de 45

    // Assinaturas (Linhas Centralizadas)
    const assinaturas = [
        { nome: defesa.orientador, label: '(Orientador)', inst: defesa.instituto_av1 || '' },
        { nome: defesa.avaliador2, label: '', inst: defesa.instituto_av2 || '' },
        { nome: defesa.avaliador3, label: '', inst: defesa.instituto_av3 || '' },
    ].filter(a => a.nome && a.nome !== 'null' && a.nome !== '');

    assinaturas.forEach((a) => {
        const lineW = 100;
        const startX = (width - lineW) / 2;
        doc.setLineWidth(0.3);
        doc.line(startX, y, startX + lineW, y);

        doc.setFontSize(12); // Aumentado 1pt
        doc.text(`${a.nome}${a.label ? ` - ${a.label}` : ''}`, width / 2, y + 5, { align: 'center' });

        if (a.inst) {
            doc.setFontSize(10); // Aumentado 1pt
            doc.setFont('times', 'normal');
            doc.text(a.inst, width / 2, y + 9.5, { align: 'center' });
            doc.setFont('times', 'bold');
        }
        y += 35; // Aumentado de 26 para 35 para dar mais espaço às assinaturas
    });

    doc.save(`Folha_Aprovacao_${defesa.discente.replace(/\s+/g, '_')}.pdf`);
};

export const generateFichaIndividual = async (defesa: Defesa, avaliadorIndex: number, autoSave = true) => {
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
    const width = doc.internal.pageSize.getWidth();

    // Margens padronizadas (Reduzidas para caber fonte maior)
    const marginL = 15;
    const marginT = 10;
    const marginR = 15;
    const contentWidth = width - marginL - marginR;

    const avaliadorNome = defesa[`avaliador${avaliadorIndex}`];
    if (!avaliadorNome) return null;

    const { data: nota } = await supabase.from('notas').select('*').eq('defesa_id', defesa.id).eq('avaliador_numero', avaliadorIndex).maybeSingle();

    // Logo UFPB com cabeçalho
    const logo = await loadImage('/assets/ufpb.png');
    const logoH = 14;
    const logoW = logoH / logo.ratio;
    doc.addImage(logo.data, 'PNG', marginL, marginT, logoW, logoH);

    // ALTA NITIDEZ: Garantir cores pretas puras
    doc.setTextColor(0);
    doc.setDrawColor(0);

    doc.setFont('times', 'bold');
    doc.setFontSize(11);
    const headerX = marginL + logoW + 4;
    doc.text('UNIVERSIDADE FEDERAL DA PARAÍBA', headerX, marginT + 4);
    doc.text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS', headerX, marginT + 8.5);
    doc.text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS', headerX, marginT + 13);

    let y = marginT + logoH + 10;

    // Título sublinhado - Alta Nitidez
    doc.setFontSize(13);
    const title = 'FICHA DE AVALIAÇÃO INDIVIDUAL DA BANCA EXAMINADORA DE TCC';
    const titleWidth = doc.getTextWidth(title);
    doc.text(title, width / 2, y, { align: 'center' });
    doc.setLineWidth(0.4);
    doc.line((width - titleWidth) / 2, y + 1.5, (width + titleWidth) / 2, y + 1.5);
    y += 12;

    const isNotaTotal = nota?.modo_nota_total;

    // BANNER NOTA ÚNICA
    if (isNotaTotal) {
        doc.setLineWidth(0.3);
        doc.rect(marginL, y, contentWidth, 10);
        doc.setFontSize(12);
        doc.setFont('times', 'bold');
        doc.text(`OBS: Avaliação via nota única. Nota total: ${nota.nota_total?.toFixed(1) || ''}/10,0`, marginL + 4, y + 6.5);
        y += 15;
    }

    // Info Box - Alta Nitidez (Ajuste dinâmico ao título)
    doc.setFontSize(13);
    doc.setFont('times', 'normal');

    const alunoText = `Aluno(a): ${defesa.discente.toUpperCase()}`;
    const tituloText = `Título: ${defesa.titulo}`;
    const splitTitulo = doc.splitTextToSize(tituloText, contentWidth - 8);

    const lineHeight = 6; // Altura aproximada de cada linha de texto 13pt
    const boxHeight = 10 + (splitTitulo.length * lineHeight) + 3; // Base + linhas + margem

    doc.rect(marginL, y, contentWidth, boxHeight);
    doc.text(alunoText, marginL + 4, y + 8);
    doc.text(splitTitulo, marginL + 4, y + 15);

    y += boxHeight + 10;

    doc.setFont('times', 'bold');
    doc.setFontSize(13);
    doc.text('Avaliação de Trabalho de Conclusão de Curso', width / 2, y, { align: 'center' });
    y += 8;

    // Função para formatar nota: se for 0 ou nulo, retorna vazio
    const fmtNota = (val: any) => {
        if (isNotaTotal) return '-';
        return (val !== null && val !== undefined && val > 0) ? val.toFixed(1) : '';
    };

    // Tabela Trabalho Escrito
    autoTable(doc, {
        startY: y,
        margin: { left: marginL, right: marginR },
        head: [['Critérios de Avaliação do Trabalho Escrito', 'Nota']],
        body: [
            [{ content: 'Introdução e justificativa (até 1,0 ponto)\nApresenta e contextualiza o tema, a justificativa e a relevância do trabalho para a área.', styles: { fontSize: 11 } }, fmtNota(nota?.introducao)],
            [{ content: 'Problematização e metodologia (até 1,5 pontos)\nTemos objetivos claros; percebe-se o problema de pesquisa; descreve procedimentos metodológicos adequados.', styles: { fontSize: 11 } }, fmtNota(nota?.problematizacao)],
            [{ content: 'Referencial teórico e bibliográfico (até 2,0 pontos)\nApresenta os elementos teóricos, termos, conceitos e bibliografia acadêmica pertinentes.', styles: { fontSize: 11 } }, fmtNota(nota?.referencial)],
            [{ content: 'Desenvolvimento e avaliação (até 2,5 pontos)\nApresenta discussões e argumentos condizentes à proposta. Realiza argumentações necessárias.', styles: { fontSize: 11 } }, fmtNota(nota?.desenvolvimento)],
            [{ content: 'Conclusões (até 1,0 pontos)\nApresenta os resultados alcançados e sua síntese pessoal sobre o assunto.', styles: { fontSize: 11 } }, fmtNota(nota?.conclusoes)],
            [{ content: 'Forma (até 0,5 ponto)\nEstrutura e coesão do texto; linguagem clara e formalmente correta; padrões da ABNT.', styles: { fontSize: 11 } }, fmtNota(nota?.forma)],
            [
                { content: 'Nota final da avaliação do trabalho escrito (máximo 8,5)', styles: { fontStyle: 'bold' } },
                { content: isNotaTotal ? (nota?.nota_total?.toFixed(1) || '') : ((nota?.introducao || 0) + (nota?.problematizacao || 0) + (nota?.referencial || 0) + (nota?.desenvolvimento || 0) + (nota?.conclusoes || 0) + (nota?.forma || 0)).toFixed(1), styles: { fontStyle: 'bold' } }
            ]
        ],
        theme: 'grid',
        styles: { font: 'times', fontSize: 12, halign: 'center', valign: 'middle', textColor: 0, lineColor: 0, lineWidth: 0.3 },
        columnStyles: { 0: { halign: 'left', cellWidth: contentWidth - 25 }, 1: { cellWidth: 25 } },
        headStyles: { fillColor: 255, textColor: 0, fontStyle: 'bold', lineWidth: 0.3 }
    });

    y = (doc as any).lastAutoTable.finalY + 8;

    // Tabela Apresentação Oral
    doc.setFont('times', 'bold');
    doc.setFontSize(13);
    doc.text('Avaliação da apresentação oral e arguição', width / 2, y, { align: 'center' });
    y += 6;

    autoTable(doc, {
        startY: y,
        margin: { left: marginL, right: marginR },
        head: [['Critérios de Avaliação da Apresentação Oral', 'Nota']],
        body: [
            [{ content: 'Estruturação e ordenação do conteúdo da apresentação (até 0,5 pontos)', styles: { fontSize: 11 } }, fmtNota(nota?.estruturacao)],
            [{ content: 'Clareza, objetividade e fluência na exposição das ideias (até 0,5 pontos)', styles: { fontSize: 11 } }, fmtNota(nota?.clareza)],
            [{ content: 'Domínio do tema desenvolvido e correspondência com trabalho escrito (até 0,5 pontos)', styles: { fontSize: 11 } }, fmtNota(nota?.dominio)],
            [
                { content: 'Nota final da apresentação oral (máximo 1,5)', styles: { fontStyle: 'bold' } },
                { content: isNotaTotal ? '0.0' : ((nota?.estruturacao || 0) + (nota?.clareza || 0) + (nota?.dominio || 0)).toFixed(1), styles: { fontStyle: 'bold' } }
            ]
        ],
        theme: 'grid',
        styles: { font: 'times', fontSize: 12, halign: 'center', valign: 'middle', textColor: 0, lineColor: 0, lineWidth: 0.3 },
        columnStyles: { 0: { halign: 'left', cellWidth: contentWidth - 25 }, 1: { cellWidth: 25 } },
        headStyles: { fillColor: 255, textColor: 0, fontStyle: 'bold', lineWidth: 0.3 }
    });

    y = (doc as any).lastAutoTable.finalY + 20;
    doc.setLineWidth(0.4);
    doc.line(width / 2 - 45, y, width / 2 + 45, y);
    doc.setFont('times', 'bold');
    doc.setFontSize(13);
    doc.text(avaliadorNome, width / 2, y + 6, { align: 'center' });

    if (autoSave) {
        doc.save(`Ficha_Avaliacao_${avaliadorNome.replace(/\s+/g, '_')}.pdf`);
    }
    return doc;
};

// Nova função para gerar fichas selecionadas ou todas
export const generateFichasAvaliacao = async (defesa: Defesa, indices: number[]) => {
    // Para manter o comportamento de baixar separado ou um PDF único (o usuário pediu "escolher qual salvar")
    // Vamos gerar e baixar cada um separadamente para maior clareza, 
    // ou o usuário pode querer um único PDF com várias páginas.
    // Pelo pedido "salvar em pdf escolhendo que docentes", gerar separado é mais flexível.

    for (const index of indices) {
        await generateFichaIndividual(defesa, index);
    }
};

export const generateFichaFinal = async (defesa: Defesa) => {
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
    const width = doc.internal.pageSize.getWidth();
    const height = doc.internal.pageSize.getHeight();

    // Margens padronizadas
    const marginL = 25;
    const marginT = 15;
    const marginR = 25;
    const contentWidth = width - marginL - marginR;

    const [notasRes, dadosRes] = await Promise.all([
        supabase.from('notas').select('*').eq('defesa_id', defesa.id),
        supabase.from('dados_defesa_final').select('*').eq('defesa_id', defesa.id).maybeSingle()
    ]);

    const notas = notasRes.data || [];
    const dadosFinais = dadosRes.data;

    // Logo UFPB com cabeçalho
    const logo = await loadImage('/assets/ufpb.png');
    const logoH = 14;
    const logoW = logoH / logo.ratio;
    doc.addImage(logo.data, 'PNG', marginL, marginT, logoW, logoH);

    doc.setFont('times', 'bold');
    doc.setFontSize(9);
    const headerX = marginL + logoW + 4;
    doc.text('UNIVERSIDADE FEDERAL DA PARAÍBA', headerX, marginT + 4);
    doc.text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS', headerX, marginT + 8.5);
    doc.text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS', headerX, marginT + 13);

    let y = marginT + logoH + 12;

    // Título Principal
    doc.setFontSize(14);
    doc.text('FICHA DE AVALIAÇÃO FINAL DE TCC 2', width / 2, y, { align: 'center' });
    y += 12;

    // Quadro de Informações Dinâmico
    doc.setFontSize(11);
    const alunoTxt = `Aluno(a): ${defesa.discente.toUpperCase()}`;
    const tituloTxt = `Título: ${defesa.titulo}`;
    const orientadorTxt = `Orientador(a): ${defesa.orientador}`;
    const membro1Txt = `Membro 1: ${defesa.avaliador2 || ''}`;
    const membro2Txt = `Membro 2: ${defesa.avaliador3 || ''}`;

    const splitTitulo = doc.splitTextToSize(tituloTxt, contentWidth - 8);
    const lineGap = 6;
    const internalPadding = 6;

    // Altura da caixa: padding superior + padding inferior + linhas (aluno + titulo + orientador + m1 + m2)
    // aluno (1 line) + titulo (n lines) + orientador/m1/m2 (3 lines) = n + 4 lines
    const totalLinesInside = 1 + splitTitulo.length + 3;
    const boxHeight = (totalLinesInside * lineGap) + 4; // 4mm de ajuste fino

    doc.rect(marginL, y, contentWidth, boxHeight);

    let currentBoxY = y + internalPadding;
    doc.text(alunoTxt, marginL + 4, currentBoxY);
    currentBoxY += lineGap;

    doc.text(splitTitulo, marginL + 4, currentBoxY);
    currentBoxY += (splitTitulo.length * lineGap);

    doc.text(orientadorTxt, marginL + 4, currentBoxY);
    currentBoxY += lineGap;

    doc.text(membro1Txt, marginL + 4, currentBoxY);
    currentBoxY += lineGap;

    doc.text(membro2Txt, marginL + 4, currentBoxY);

    y += boxHeight + 10;

    // Lógica de Notas
    const temModoNotaUnica = notas.some(n => n.modo_nota_total === true);

    const obterNotaParte = (num: number, parte: 'escrito' | 'apresentacao' | 'total') => {
        const n = notas.find(nt => nt.avaliador_numero === num);
        if (!n) return '';

        if (n.modo_nota_total) {
            return parte === 'total' ? n.nota_total?.toFixed(1) || '' : '---';
        }

        if (parte === 'escrito') {
            const val = (n.introducao || 0) + (n.problematizacao || 0) + (n.referencial || 0) + (n.desenvolvimento || 0) + (n.conclusoes || 0) + (n.forma || 0);
            return val > 0 ? val.toFixed(1) : '0.0';
        }
        if (parte === 'apresentacao') {
            const val = (n.estruturacao || 0) + (n.clareza || 0) + (n.dominio || 0);
            return val > 0 ? val.toFixed(1) : '0.0';
        }
        return n.nota_total?.toFixed(1) || '';
    };

    // Tabela de Notas
    const tableBody = [];
    if (temModoNotaUnica) {
        tableBody.push(['Nota Geral (0 a 10)', obterNotaParte(1, 'total'), obterNotaParte(2, 'total'), obterNotaParte(3, 'total')]);
    } else {
        tableBody.push(['Trabalho escrito (0 a 8,5)', obterNotaParte(1, 'escrito'), obterNotaParte(2, 'escrito'), obterNotaParte(3, 'escrito')]);
        tableBody.push(['Apresentação oral (0 a 1,5)', obterNotaParte(1, 'apresentacao'), obterNotaParte(2, 'apresentacao'), obterNotaParte(3, 'apresentacao')]);
        tableBody.push([
            { content: 'Nota final (0 a 10)', styles: { fontStyle: 'bold', fillColor: [240, 240, 240] } },
            { content: obterNotaParte(1, 'total'), styles: { fontStyle: 'bold', fillColor: [240, 240, 240] } },
            { content: obterNotaParte(2, 'total'), styles: { fontStyle: 'bold', fillColor: [240, 240, 240] } },
            { content: obterNotaParte(3, 'total'), styles: { fontStyle: 'bold', fillColor: [240, 240, 240] } }
        ]);
    }

    autoTable(doc, {
        startY: y,
        margin: { left: marginL, right: marginR },
        head: [['Itens avaliados', 'Orientador(a)', 'Membro 1', 'Membro 2']],
        body: tableBody,
        theme: 'grid',
        styles: { font: 'times', fontSize: 10, halign: 'center' },
        columnStyles: { 0: { halign: 'left', cellWidth: 'auto' } },
        headStyles: { fillColor: [230, 230, 230], textColor: 0, fontStyle: 'bold' }
    });

    y = (doc as any).lastAutoTable.finalY + 12;

    // Resumo Média/Resultado
    const media = notas.length > 0 ? (notas.reduce((acc, n) => acc + (n.nota_total || 0), 0) / notas.length).toFixed(1) : '---';

    autoTable(doc, {
        startY: y,
        margin: { left: marginL, right: marginR },
        head: [['Média Final', 'Resultado']],
        body: [[media, dadosFinais?.resultado?.toUpperCase() || '---']],
        theme: 'grid',
        styles: { font: 'times', fontSize: 11, halign: 'center', fontStyle: 'bold' },
        headStyles: { fillColor: [230, 230, 230], textColor: 0 }
    });

    y = (doc as any).lastAutoTable.finalY + 25;

    // Assinaturas
    const avaliadores = [
        { nome: defesa.orientador, label: '(Orientador)' },
        { nome: defesa.avaliador2, label: '(Membro 1)' },
        { nome: defesa.avaliador3, label: '(Membro 2)' },
    ].filter(a => a.nome && a.nome !== 'null');

    avaliadores.forEach((a) => {
        doc.setLineWidth(0.3);
        doc.line(marginL, y, marginL + 90, y);
        doc.setFont('times', 'bold');
        doc.setFontSize(10);
        doc.text(`${a.nome} ${a.label}`, marginL, y + 5);
        y += 16;
    });

    // Observações Finais
    y += 4;
    doc.setFontSize(11);
    doc.text('Observações finais:', marginL, y);
    y += 4;
    doc.setFont('times', 'normal');
    doc.setFontSize(10);
    const obs = dadosFinais?.observacoes_finais || 'Nenhuma observação registrada.';
    const splitObs = doc.splitTextToSize(obs, contentWidth - 8);
    const obsBoxH = Math.max(15, (splitObs.length * 5) + 6);
    doc.rect(marginL, y, contentWidth, obsBoxH);
    doc.text(splitObs, marginL + 4, y + 6);

    doc.save(`Ficha_Final_${defesa.discente.replace(/\s+/g, '_')}.pdf`);
};

export const generateCertificado = async (defesa: Defesa, membroNome: string, tipo: 'orientador' | 'avaliador') => {
    const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
    const width = doc.internal.pageSize.getWidth();
    const height = doc.internal.pageSize.getHeight();

    doc.setDrawColor(12, 74, 110);
    doc.setLineWidth(4);
    doc.rect(5, 5, width - 10, height - 10);
    doc.setLineWidth(1);
    doc.rect(8, 8, width - 16, height - 16);

    doc.setFont('times', 'bold');
    doc.setFontSize(14);
    doc.text('UNIVERSIDADE FEDERAL DA PARAÍBA', 20, 25);
    doc.setFontSize(12);
    doc.text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS', 20, 31);
    doc.setFontSize(10);
    doc.text(`DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS - SEMESTRE ${defesa.semestre}`, 20, 36);

    doc.setFontSize(50);
    doc.setTextColor(12, 74, 110);
    doc.text('CERTIFICADO', width / 2, 70, { align: 'center', charSpace: 2 });

    doc.setTextColor(0);
    doc.setFontSize(18);
    doc.setFont('times', 'normal');

    let y = 100;

    let dataFormatada = '___ de _____________ de _____';
    if (defesa.dia) {
        const d = new Date(defesa.dia + 'T12:00:00');
        dataFormatada = `${d.getDate()} de ${meses[d.getMonth()]} de ${d.getFullYear()}`;
    }

    const texto = `Certificamos que ${membroNome.toUpperCase()} participou, na condição de ${tipo === 'orientador' ? 'ORIENTADOR(A)' : 'EXAMINADOR(A)'}, da Banca de Defesa de Trabalho de Conclusão de Curso (TCC) de ${defesa.discente.toUpperCase()}, realizada no dia ${dataFormatada}, com o trabalho intitulado:`;
    const splitText = doc.splitTextToSize(texto, width - 60);
    doc.text(splitText, width / 2, y, { align: 'center' });
    y += (splitText.length * 10) + 5;

    doc.setFont('times', 'italic');
    doc.setFontSize(16);
    doc.text(`"${defesa.titulo}"`, width / 2, y, { align: 'center', maxWidth: width - 80 });

    doc.setFont('times', 'normal');
    doc.setFontSize(12);
    doc.line(width / 2 - 40, height - 40, width / 2 + 40, height - 40);
    doc.text('Coordenação de TCC - DRI/UFPB', width / 2, height - 35, { align: 'center' });

    doc.save(`Certificado_${membroNome.replace(/\s+/g, '_')}.pdf`);
};

export const generateSituacaoDefesasReport = async (
    defesas: any[],
    notas: any[],
    semestre: string
) => {
    const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
    const width = doc.internal.pageSize.getWidth();

    const logo = await loadImage('/assets/ufpb.png');
    doc.addImage(logo.data, 'PNG', 15, 10, 14 / logo.ratio, 14);

    doc.setFont('times', 'bold');
    doc.setFontSize(10);
    doc.text('UFPB - CCSA - DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS', 35, 15);
    doc.setFontSize(12);
    doc.setTextColor(12, 74, 110);
    doc.text(`Relatório de Situação das Defesas - Semestre ${semestre}`, 35, 20);

    const getNotaFinal = (defesaId: number, avaliadorNumero: number) => {
        const nota = notas.find(n => n.defesa_id === defesaId && n.avaliador_numero === avaliadorNumero);
        if (!nota) return '-';
        if (nota.modo_nota_total) return nota.nota_total?.toFixed(1) || '-';
        const fields = ['introducao', 'problematizacao', 'referencial', 'desenvolvimento', 'conclusoes', 'forma', 'estruturacao', 'clareza', 'dominio'];
        const total = fields.reduce((acc, field) => acc + (nota[field] || 0), 0);
        return total.toFixed(1);
    };

    const tableData = defesas.map(d => {
        const n1 = getNotaFinal(d.id, 1);
        const n2 = getNotaFinal(d.id, 2);
        const n3 = getNotaFinal(d.id, 3);
        const valids = [n1, n2, n3].filter(n => n !== '-').map(n => parseFloat(n));
        const media = valids.length > 0 ? (valids.reduce((a, b) => a + b, 0) / valids.length).toFixed(1) : '-';

        return [
            d.dia ? new Intl.DateTimeFormat('pt-BR').format(new Date(d.dia + 'T12:00:00')) : '--/--/--',
            d.discente.toUpperCase(),
            d.orientador || '',
            d.doc_outros_devolvido ? 'SIM' : 'NÃO',
            n1, n2, n3, media,
            d.doc_tcc_devolvido ? 'SIM' : 'NÃO',
            d.doc_termo_devolvido ? 'SIM' : 'NÃO'
        ];
    });

    autoTable(doc, {
        startY: 30,
        head: [['DATA', 'DISCENTE', 'ORIENTADOR', 'DOCS', 'N.ORI', 'N.AV1', 'N.AV2', 'MÉDIA', 'TCC', 'TERM']],
        body: tableData,
        theme: 'grid',
        styles: { font: 'times', fontSize: 8, halign: 'center' },
        headStyles: { fillColor: [12, 74, 110], textColor: 255 },
        columnStyles: {
            1: { halign: 'left', cellWidth: 'auto' },
            2: { halign: 'left', cellWidth: 'auto' }
        }
    });

    doc.save(`Relatorio_Situacao_Defesas_${semestre}.pdf`);
};

export const generateParticipacoesDocentesReport = async (
    participationStats: any[],
    totalDefesas: number,
    totalParticipations: number,
    semestre: string
) => {
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
    const width = doc.internal.pageSize.getWidth();

    // Cabeçalho
    const logo = await loadImage('/assets/ufpb.png');
    doc.addImage(logo.data, 'PNG', 15, 10, 14 / logo.ratio, 14);

    doc.setFont('times', 'bold');
    doc.setFontSize(10);
    doc.text('UFPB - CCSA - DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS', 35, 15);

    doc.setFontSize(14);
    doc.setTextColor(128, 0, 128); // Roxo como no anexo
    doc.text('Relatório de Participações - Docentes', 35, 21);

    doc.setFontSize(10);
    doc.setTextColor(100);
    doc.text(`Semestre: ${semestre} | Todos os Docentes`, 35, 26);

    const now = new Date().toLocaleString('pt-BR');
    doc.text(`Data: ${now}`, width - 15, 21, { align: 'right' });

    doc.setLineWidth(0.5);
    doc.setDrawColor(128, 0, 128);
    doc.line(15, 30, width - 15, 30);

    const tableData = participationStats.map(p => [
        p.nome.toUpperCase(),
        p.orientador,
        p.coorientador,
        p.avaliador,
        p.total
    ]);

    autoTable(doc, {
        startY: 35,
        head: [['PROFESSOR', 'ORIENTADOR', 'COORIENTADOR', 'AVALIADOR', 'TOTAL']],
        body: tableData,
        theme: 'grid',
        styles: { font: 'times', fontSize: 8, halign: 'center', cellPadding: 2 },
        headStyles: { fillColor: [243, 232, 255], textColor: [0, 0, 0], fontStyle: 'bold' },
        columnStyles: {
            0: { halign: 'left', cellWidth: 'auto' },
            4: { fontStyle: 'bold' }
        },
        alternateRowStyles: { fillColor: [250, 250, 250] }
    });

    const finalY = (doc as any).lastAutoTable.finalY + 10;

    doc.setFontSize(9);
    doc.setFont('times', 'bold');
    doc.setTextColor(0);
    doc.text(`RESUMO DO SEMESTRE:`, 15, finalY);

    doc.setFont('times', 'normal');
    doc.text(`Total de Bancas Realizadas: ${totalDefesas}`, 15, finalY + 5);
    doc.text(`Total de Participações em Bancas: ${totalParticipations}`, 15, finalY + 10);
    doc.text(`Quantidade de Docentes Diferentes Participantes: ${participationStats.length}`, 15, finalY + 15);

    doc.save(`Relatorio_Participacoes_Docentes_${semestre}.pdf`);
};
