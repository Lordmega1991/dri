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
            const [gradeRes, profRes, alocRes, semRes] = await Promise.all([
                supabase.from('grade_aulas').select('*').eq('semestre', semestreId),
                supabase.from('docentes').select('*').eq('ativo', true).order('nome'),
                supabase.from('alocacoes_docentes').select('*, disciplina(nome, periodo, turno)').eq('semestre', semestreId),
                supabase.from('semestres').select('id').eq('ano', semestreId.split('.')[0]).eq('semestre', semestreId.split('.')[1]).single()
            ])

            let atividades = []
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

            // --- PAGE 1: GRADE GERAL ---
            doc.setFontSize(16)
            doc.setTextColor(COLORS.PRIMARY)
            doc.text(`GRADE DE AULAS COMPLETA - ${semestreId}`, 14, 15)

            // Prepare Table Data
            const tableHead = [['Horário', ...DIAS]]
            const tableBody: any[] = []

            TURNOS.forEach(turno => {
                // Shift Header Row (Optional or merged)
                // tableBody.push([{ content: turno.toUpperCase(), colSpan: 7, styles: { fillColor: COLORS.HEADER, fontStyle: 'bold', halign: 'center' } }])

                HORARIOS[turno as keyof typeof HORARIOS].forEach(horario => {
                    const row: any[] = [horario]
                    DIAS.forEach(dia => {
                        // Find Class
                        const aula = grade.find(g => g.dia === dia && (g.horario || '').includes(horario.split('-')[0].trim()))
                        if (aula) {
                            row.push(`${aula.disciplina_nome || aula.disciplina}\n(${aula.professor})\n${aula.sala || ''}`)
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
                startY: 20,
                styles: { fontSize: 8, cellPadding: 2, overflow: 'linebreak' },
                headStyles: { fillColor: COLORS.PRIMARY, textColor: '#FFFFFF' },
                theme: 'grid'
            })

            // --- PAGE 2+: DETALHES DOS DOCENTES ---
            doc.addPage() // Portrait for details
            // doc.setPageOrientation('portrait') // jsPDF handling of orientation switch is tricky, usually new doc or kept landscape. 
            // Let's keep landscape or switch. Ideally switch.
            // But jsPDF addPage(format, orientation) works in recent versions.

            // Calculate Totals per Prof
            const profsWithData = professores.map(prof => {
                const pAlocs = alocacoes.filter(a => a.docente_id === prof.id)
                const pAtivs = atividades.filter((a: any) => a.docente_id === prof.id)
                const chAula = pAlocs.reduce((s, a) => s + (a.ch_alocada || 0), 0)
                const chAdm = pAtivs.reduce((s: any, a: any) => s + (a.quantidade || 0), 0)
                return { ...prof, pAlocs, pAtivs, total: chAula + chAdm }
            }).sort((a, b) => b.total - a.total)

            let y = 20
            doc.setFontSize(14)
            doc.text('DETALHES DOS DOCENTES', 14, 15)

            profsWithData.forEach((prof, i) => {
                if (y > 180) { doc.addPage(); y = 20; }

                // Card Header
                doc.setFillColor(COLORS.HEADER)
                doc.rect(14, y, 270, 8, 'F') // Landscape width ~297mm
                doc.setFontSize(10)
                doc.setTextColor(COLORS.TEXT_MAIN)
                doc.text(prof.nome.toUpperCase(), 16, y + 6)

                // Badge Total
                doc.setFillColor(COLORS.PRIMARY)
                doc.roundedRect(250, y + 1, 30, 6, 2, 2, 'F')
                doc.setTextColor('#FFFFFF')
                doc.setFontSize(8)
                doc.text(`TOTAL: ${prof.total}h`, 255, y + 5)

                y += 10

                // Content
                doc.setTextColor(COLORS.TEXT_SEC)
                doc.text('ATIVIDADES:', 16, y)
                y += 5

                prof.pAlocs.forEach((aloc: any) => {
                    doc.setTextColor(COLORS.TEXT_MAIN)
                    doc.text(`• ${aloc.disciplina?.nome || 'Disciplina'} (${aloc.ch_alocada}h)`, 20, y)
                    y += 5
                })

                prof.pAtivs.forEach((ativ: any) => {
                    doc.setTextColor(COLORS.TEXT_SEC)
                    doc.text(`• ${ativ.descricao || ativ.tipos_atividade?.nome} (${ativ.quantidade}h)`, 20, y)
                    y += 5
                })

                y += 5 // Spacing
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
