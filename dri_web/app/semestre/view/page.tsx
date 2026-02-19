'use client'

import { useEffect, useState, Suspense } from 'react'
import { supabase } from '@/lib/supabaseClient'
import { useSearchParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import {
    ArrowLeft,
    Calendar,
    FileText,
    BarChart2,
    Clock,
    CheckCircle,
    XCircle,
    LayoutDashboard
} from 'lucide-react'
import clsx from 'clsx'

function SemestreViewContent() {
    const searchParams = useSearchParams()
    const id = searchParams.get('id')
    const router = useRouter()

    const [semestre, setSemestre] = useState<any>(null)
    const [disciplinasSummary, setDisciplinasSummary] = useState<any[]>([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        if (!id) {
            router.push('/semestre')
            return
        }

        const fetchSemestre = async () => {
            try {
                // Fetch Semester Info
                const { data, error } = await supabase
                    .from('semestres')
                    .select('*')
                    .eq('id', id)
                    .single()

                if (error) throw error
                setSemestre(data)

                // Fetch Allocations for Summary
                const semesterLabel = `${data.ano}.${data.semestre}`
                const { data: alocs, error: alocError } = await supabase
                    .from('alocacoes_docentes')
                    .select('*, docentes(id, nome, apelido), disciplinas(id, nome, periodo)')
                    .eq('semestre', semesterLabel)
                    .is('simulacao_id', null)

                if (alocs) {
                    // Group and format
                    const grouped = new Map<string, any>()
                    alocs.forEach((a: any) => {
                        if (!a.disciplinas) return
                        const discId = a.disciplinas.id
                        if (!grouped.has(discId)) {
                            grouped.set(discId, {
                                nome: a.disciplinas.nome,
                                periodo: a.disciplinas.periodo,
                                professores: []
                            })
                        }
                        const profName = a.docentes?.apelido || a.docentes?.nome || '?'
                        grouped.get(discId).professores.push(profName)
                    })

                    setDisciplinasSummary(
                        Array.from(grouped.values()).sort((a, b) => {
                            if (a.periodo !== b.periodo) return a.periodo - b.periodo
                            return a.nome.localeCompare(b.nome)
                        })
                    )
                }
            } catch (error) {
                console.error('Erro ao buscar semestre:', error)
                router.push('/semestre')
            } finally {
                setLoading(false)
            }
        }
        fetchSemestre()
    }, [id, router])

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-[#F5F5F7]">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            </div>
        )
    }

    if (!semestre) return null

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-slate-800 font-sans">
            <header className="bg-white border-b border-slate-200 py-3 px-4 sticky top-0 z-10 shadow-sm">
                <div className="max-w-6xl mx-auto flex items-center gap-3">
                    <Link href="/semestre" className="p-1.5 hover:bg-slate-100 rounded-full transition-colors text-slate-500">
                        <ArrowLeft size={20} />
                    </Link>
                    <div>
                        <h1 className="text-xl font-bold text-slate-800 flex items-center gap-2 leading-none">
                            <Calendar className="text-indigo-600" size={24} />
                            Semestre {semestre.ano}.{semestre.semestre}
                        </h1>
                        <p className="text-xs text-slate-500 font-medium mt-0.5 ml-0.5">Painel de Controle</p>
                    </div>
                </div>
            </header>

            <main className="max-w-6xl mx-auto px-4 py-8 pb-32">
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {/* Info Card */}
                    <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm flex flex-col justify-between">
                        <div>
                            <h3 className="text-sm font-bold text-slate-500 uppercase tracking-wide mb-4">Informações</h3>
                            <div className="space-y-3">
                                <div className="flex justify-between border-b pb-2">
                                    <span className="text-sm text-slate-600">Início</span>
                                    <span className="text-sm font-medium">{semestre.data_inicio ? new Date(semestre.data_inicio).toLocaleDateString('pt-BR') : '-'}</span>
                                </div>
                                <div className="flex justify-between border-b pb-2">
                                    <span className="text-sm text-slate-600">Término</span>
                                    <span className="text-sm font-medium">{semestre.data_fim ? new Date(semestre.data_fim).toLocaleDateString('pt-BR') : '-'}</span>
                                </div>
                                <div className="flex justify-between items-center pt-1">
                                    <span className="text-sm text-slate-600">Status</span>
                                    {(() => {
                                        let status = 'Finalizado';
                                        const now = new Date();
                                        if (semestre.data_inicio && semestre.data_fim) {
                                            const start = new Date(semestre.data_inicio);
                                            const end = new Date(semestre.data_fim);
                                            if (now >= start && now <= end) status = 'Ativo';
                                            else if (now < start) status = 'Planejamento';
                                            else status = 'Finalizado';
                                        }
                                        return (
                                            <span className={clsx(
                                                "px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wide border",
                                                status === 'Ativo' ? "bg-green-50 text-green-700 border-green-200" :
                                                    status === 'Planejamento' ? "bg-amber-50 text-amber-700 border-amber-100" :
                                                        "bg-slate-100 text-slate-500 border-slate-200"
                                            )}>
                                                {status}
                                            </span>
                                        );
                                    })()}
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Navigation Cards */}
                    <Link href={`/semestre/grade?id=${id}`} className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm hover:border-indigo-300 hover:shadow-md transition-all group">
                        <div className="w-10 h-10 bg-indigo-50 rounded-lg flex items-center justify-center text-indigo-600 mb-4 group-hover:scale-110 transition-transform">
                            <LayoutDashboard size={20} />
                        </div>
                        <h3 className="text-lg font-bold text-slate-800 mb-1 group-hover:text-indigo-600 transition-colors">Grade de Horários</h3>
                        <p className="text-sm text-slate-500 leading-relaxed">Gerenciar alocação de disciplinas e horários.</p>
                    </Link>

                    <Link href={`/semestre/relatorios?id=${id}`} className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm hover:border-indigo-300 hover:shadow-md transition-all group">
                        <div className="w-10 h-10 bg-indigo-50 rounded-lg flex items-center justify-center text-indigo-600 mb-4 group-hover:scale-110 transition-transform">
                            <FileText size={20} />
                        </div>
                        <h3 className="text-lg font-bold text-slate-800 mb-1 group-hover:text-indigo-600 transition-colors">Relatórios</h3>
                        <p className="text-sm text-slate-500 leading-relaxed">Visualizar e baixar PDFs da grade.</p>
                    </Link>

                    <Link href={`/semestre/simulacao?id=${id}`} className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm hover:border-indigo-300 hover:shadow-md transition-all group">
                        <div className="w-10 h-10 bg-teal-50 rounded-lg flex items-center justify-center text-teal-600 mb-4 group-hover:scale-110 transition-transform">
                            <BarChart2 size={20} />
                        </div>
                        <h3 className="text-lg font-bold text-slate-800 mb-1 group-hover:text-teal-600 transition-colors">Simulação de CH</h3>
                        <p className="text-sm text-slate-500 leading-relaxed">Planejamento de carga horária docente.</p>
                    </Link>
                </div>

                {/* Disciplines Summary Section */}
                <div className="mt-8 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                    <div className="p-6 border-b border-slate-100 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <BookOpen className="text-indigo-600" size={20} />
                            <h3 className="text-lg font-bold text-slate-800">Quadro de Alocações</h3>
                        </div>
                        <span className="text-xs font-bold text-slate-400 uppercase tracking-widest">{disciplinasSummary.length} Disciplinas Ativas</span>
                    </div>

                    {disciplinasSummary.length > 0 ? (
                        <div className="divide-y divide-slate-50">
                            {disciplinasSummary.map((item, idx) => (
                                <div key={idx} className="p-4 hover:bg-slate-50/50 transition-colors flex items-center justify-between group">
                                    <div className="flex items-center gap-4">
                                        <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-500 font-bold text-xs">
                                            {item.periodo}º
                                        </div>
                                        <div className="text-sm font-bold text-slate-800">
                                            {item.nome}
                                            <span className="text-indigo-600 font-semibold ml-1">
                                                - {item.professores.join(', ')}
                                            </span>
                                        </div>
                                    </div>
                                    <div className="opacity-0 group-hover:opacity-100 transition-opacity">
                                        <div className="w-2 h-2 rounded-full bg-indigo-400" />
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="p-12 text-center">
                            <div className="w-12 h-12 bg-slate-50 rounded-full flex items-center justify-center text-slate-300 mx-auto mb-4">
                                <BookOpen size={24} />
                            </div>
                            <p className="text-slate-500 font-medium">Nenhuma alocação confirmada para este semestre.</p>
                            <Link href={`/semestre/grade?id=${id}`} className="text-indigo-600 font-bold text-sm mt-2 inline-block hover:underline">Ir para Grade Horária</Link>
                        </div>
                    )}
                </div>
            </main>
        </div>
    )
}

export default function SemestreViewPage() {
    return (
        <Suspense fallback={<div>Carregando...</div>}>
            <SemestreViewContent />
        </Suspense>
    )
}
