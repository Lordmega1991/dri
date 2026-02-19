'use client'

import { useState, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'
import Link from 'next/link'
import { ArrowLeft, FileText, Download, Loader2 } from 'lucide-react'

// Constants matching Dart helper
const COLORS = {
    MANHA: '#FFF8E1', // Amber 50
    TARDE: '#FBE9E7', // Deep Orange 50
    NOITE: '#E8EAF6', // Indigo 50
    HEADER: '#F5F5F5',
    PRIMARY: '#1565C0',
    TEXT_MAIN: '#212121',
    TEXT_SEC: '#757575'
}

const DIAS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
const TURNOS = ['Manhã', 'Tarde', 'Noite']
const HORARIOS = {
    'Manhã': ['07h-08h', '08h-09h', '09h-10h', '10h-11h', '11h-12h', '12h-13h'],
    'Tarde': ['13h-14h', '14h-15h', '15h-16h', '16h-17h', '17h-18h', '18h-19h'],
    'Noite': ['19h-19h50', '19h50-20h40', '20h40-21h30', '21h30-22h20']
}

function RelatoriosContent() {
    const searchParams = useSearchParams()
    const semestreId = searchParams.get('id') || ''
    const [generating, setGenerating] = useState(false)

    const generatePDF = async () => {
        setGenerating(true)
        try {
            // 1. Fetch All Data
            const [year, period] = semestreId.split('.')
            const [gradeRes, profRes, alocRes, semRes] = await Promise.all([
                supabase.from('grade_aulas').select('*').eq('semestre', semestreId),
                supabase.from('docentes').select('*').eq('ativo', true).order('nome'),
                supabase.from('alocacoes_docentes').select('*, disciplina:disciplinas(nome, periodo, turno)').eq('semestre', semestreId).is('simulacao_id', null),
                supabase.from('semestres').select('id').eq('ano', parseInt(year)).eq('semestre', parseInt(period)).single()
            ])

            let atividades: any[] = []
            if (semRes.data) {
                const ativRes = await supabase
                    .from('atividades_docentes')
                    .select('*, tipos_atividade(nome, categoria)')
                    .eq('semestre_id', semRes.data.id)
                    .eq('status', 'aprovado')
                atividades = ativRes.data || []
            }

            const grade = gradeRes.data || []
            const professores = profRes.data || []
            const alocacoes = alocRes.data || []

            // 2. Initialize PDF
            const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' })

            // --- PROFESSIONAL HEADER HELPER ---
            const addProfessionalHeader = (title: string, pWidth: number) => {
                doc.setDrawColor(21, 101, 192) // Primary Blue
                doc.setLineWidth(0.5)
                doc.line(14, 25, pWidth - 14, 25)

                doc.setFont('helvetica', 'bold')
                doc.setFontSize(9)
                doc.setTextColor(33, 33, 33)
                doc.text('UNIVERSIDADE FEDERAL DA PARAÍBA', 14, 12)
                doc.text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS', 14, 16)
                doc.text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS', 14, 20)

                doc.setFontSize(14)
                doc.setTextColor(21, 101, 192)
                doc.text(title.toUpperCase(), pWidth - 14, 20, { align: 'right' })

                doc.setFontSize(8)
                doc.setTextColor(117, 117, 117)
                doc.setFont('helvetica', 'italic')
                doc.text(`Semestre: ${semestreId} | DRI-SISTEMA`, pWidth - 14, 12, { align: 'right' })

                doc.setTextColor(0, 0, 0)
                doc.setFont('helvetica', 'normal')
            }

            // --- PAGE 1: RESUMO E STATS ---
            const pageWidth = doc.internal.pageSize.getWidth()
            addProfessionalHeader('Resumo de Alocações', pageWidth)

            const profsWithData = professores.map(prof => {
                const pAlocs = alocacoes.filter(a => a.docente_id === prof.id)
                const pAtivs = atividades.filter((a: any) => a.docente_id === prof.id)
                const chAula = pAlocs.reduce((s, a) => s + (a.ch_alocada || 0), 0)
                const chAdm = pAtivs.reduce((s: any, a: any) => s + (a.quantidade || 0), 0)
                return { ...prof, pAlocs, pAtivs, chAula, chAdm, total: chAula + chAdm }
            }).filter(p => p.total > 0).sort((a, b) => a.nome.localeCompare(b.nome))

            // Stats Cards
            const stats = [
                { label: 'Aulas Atribuídas', value: grade.length.toString(), color: [21, 101, 192] },
                { label: 'Docentes Ativos', value: profsWithData.length.toString(), color: [56, 142, 60] },
                { label: 'Carga Horária Total', value: `${profsWithData.reduce((s, p) => s + p.total, 0)}h`, color: [245, 124, 0] }
            ]

            let cardX = 14
            const cardWidth = (pageWidth - 28 - 10) / 3
            stats.forEach(s => {
                doc.setDrawColor(200, 200, 200)
                doc.setFillColor(245, 245, 245)
                doc.roundedRect(cardX, 32, cardWidth, 18, 2, 2, 'FD')
                doc.setFontSize(7)
                doc.setTextColor(117, 117, 117)
                doc.text(s.label.toUpperCase(), cardX + cardWidth / 2, 38, { align: 'center' })
                doc.setFontSize(12)
                doc.setFont('helvetica', 'bold')
                doc.setTextColor(s.color[0], s.color[1], s.color[2] as any)
                doc.text(s.value, cardX + cardWidth / 2, 45, { align: 'center' })
                cardX += cardWidth + 5
            })

            autoTable(doc, {
                startY: 55,
                head: [['Docente', 'CH Aula', 'CH Outras', 'Total', 'Disciplinas']],
                body: profsWithData.map(p => [
                    p.apelido || p.nome,
                    `${p.chAula}h`,
                    `${p.chAdm}h`,
                    `${p.total}h`,
                    p.pAlocs.map((a: any) => a.disciplina?.nome).join(', ')
                ]),
                theme: 'grid',
                headStyles: { fillColor: [21, 101, 192] },
                styles: { fontSize: 8 }
            })

            // --- PAGE 2: GRADE GERAL ---
            doc.addPage()
            addProfessionalHeader('Grade de Aulas', pageWidth)

            const tableHead = [['Horário', ...DIAS]]
            const tableBody: any[] = []

            TURNOS.forEach(turno => {
                HORARIOS[turno as keyof typeof HORARIOS].forEach(horario => {
                    const row: any[] = [horario]
                    DIAS.forEach(dia => {
                        const aula = grade.find(g => g.dia === dia && g.turno === turno && HORARIOS[turno as keyof typeof HORARIOS][g.indice] === horario)
                        if (aula) {
                            const profs = Array.isArray(aula.professores) ? aula.professores : []
                            const nicknames = profs.map((pid: string) => professores.find(p => p.id === pid)?.apelido || 'Prof.').join(', ')
                            row.push(`${aula.disciplina_nome || '?'}\n${nicknames}`)
                        } else {
                            row.push('')
                        }
                    })
                    tableBody.push({
                        content: row,
                        styles: {
                            fillColor: turno === 'Manhã' ? COLORS.MANHA : turno === 'Tarde' ? COLORS.TARDE : COLORS.NOITE
                        }
                    })
                })
            })

            autoTable(doc, {
                head: tableHead,
                body: tableBody,
                startY: 32,
                styles: { fontSize: 7, cellPadding: 2, minCellHeight: 15, valign: 'middle', halign: 'center' },
                columnStyles: { 0: { fontStyle: 'bold', fillColor: '#F5F5F5', cellWidth: 25 } },
                headStyles: { fillColor: [21, 101, 192], textColor: '#FFFFFF' },
                theme: 'grid'
            })

            // --- PAGE 3+: DETALHES DOS DOCENTES ---
            doc.addPage()
            addProfessionalHeader('Detalhamento por Docente', pageWidth)

            let currentY = 32
            const boxWidth = pageWidth - 28

            profsWithData.forEach((prof) => {
                const rowCount = Math.max(prof.pAlocs.length, prof.pAtivs.length, 1)
                const boxHeight = 15 + (rowCount * 6)

                if (currentY + boxHeight > 190) {
                    doc.addPage()
                    addProfessionalHeader('Detalhamento por Docente (cont.)', pageWidth)
                    currentY = 32
                }

                doc.setDrawColor(220, 220, 220)
                doc.roundedRect(14, currentY, boxWidth, boxHeight, 2, 2, 'D')
                doc.setFillColor(248, 249, 250)
                doc.rect(14.5, currentY + 0.5, boxWidth - 1, 8, 'F')

                doc.setFont('helvetica', 'bold')
                doc.setFontSize(9)
                doc.setTextColor(33, 33, 33)
                doc.text(prof.nome.toUpperCase(), 18, currentY + 6)
                doc.text(`TOTAL: ${prof.total}h`, pageWidth - 20, currentY + 6, { align: 'right' })

                doc.setFont('helvetica', 'normal')
                doc.setFontSize(8)
                let itemY = currentY + 13

                prof.pAlocs.forEach((aloc: any) => {
                    doc.text(`• ${aloc.disciplina?.nome || 'Disciplina'} (${aloc.ch_alocada}h)`, 20, itemY)
                    itemY += 5
                })

                prof.pAtivs.forEach((ativ: any) => {
                    doc.text(`• ${ativ.descricao || ativ.tipos_atividade?.nome || 'Atividade'} (${ativ.quantidade}h)`, 20, itemY)
                    itemY += 5
                })

                currentY += boxHeight + 5
            })

            // Save
            doc.save(`Relatorio_Semestre_${semestreId}.pdf`)

        } catch (error) {
            console.error(error)
            alert('Erro ao gerar PDF')
        } finally {
            setGenerating(false)
        }
    }

    return (
        <div className="min-h-screen bg-gray-50 flex flex-col font-sans">
            <header className="bg-white border-b border-gray-200 sticky top-0 z-20">
                <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-4">
                        <Link href="/semestre" className="p-2 hover:bg-gray-100 rounded-full text-gray-500">
                            <ArrowLeft size={20} />
                        </Link>
                        <div>
                            <h1 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                                <FileText size={20} className="text-indigo-600" />
                                Relatórios
                            </h1>
                            <p className="text-xs text-gray-500 font-medium">Semestre {semestreId}</p>
                        </div>
                    </div>
                </div>
            </header>

            <main className="flex-1 p-8 max-w-7xl mx-auto w-full flex flex-col items-center justify-center">

                <div className="bg-white p-10 rounded-2xl shadow-lg border border-gray-200 text-center max-w-lg w-full">
                    <div className="w-20 h-20 bg-indigo-100 rounded-full flex items-center justify-center text-indigo-600 mx-auto mb-6">
                        <FileText size={40} />
                    </div>

                    <h2 className="text-2xl font-bold text-gray-900 mb-2">Gerar Relatório Completo</h2>
                    <p className="text-gray-500 mb-8">
                        Este relatório inclui a grade completa de horários, detalhes de alocação por professor e resumo de carga horária.
                    </p>

                    <button
                        onClick={generatePDF}
                        disabled={generating}
                        className="w-full bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-4 rounded-xl font-bold text-lg flex items-center justify-center shadow-lg hover:shadow-indigo-200 transition-all active:scale-95 disabled:opacity-70 disabled:cursor-not-allowed"
                    >
                        {generating ? (
                            <>
                                <Loader2 className="mr-3 animate-spin" />
                                Gerando PDF...
                            </>
                        ) : (
                            <>
                                <Download className="mr-3" />
                                Baixar PDF
                            </>
                        )}
                    </button>

                    {generating && (
                        <p className="mt-4 text-xs text-gray-400 animate-pulse">
                            Isso pode levar alguns segundos...
                        </p>
                    )}
                </div>

            </main>
        </div>
    )
}

export default function RelatoriosPage() {
    return (
        <Suspense fallback={<div>Carregando...</div>}>
            <RelatoriosContent />
        </Suspense>
    )
}
