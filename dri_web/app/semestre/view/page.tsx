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
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        if (!id) {
            router.push('/semestre')
            return
        }

        const fetchSemestre = async () => {
            try {
                const { data, error } = await supabase
                    .from('semestres')
                    .select('*')
                    .eq('id', id)
                    .single()

                if (error) throw error
                setSemestre(data)
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
                            Semestre {semestre.ano_letivo}.{semestre.periodo_letivo}
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
                                    <span className="text-sm font-medium">{new Date(semestre.data_inicio).toLocaleDateString('pt-BR')}</span>
                                </div>
                                <div className="flex justify-between border-b pb-2">
                                    <span className="text-sm text-slate-600">Terimno</span>
                                    <span className="text-sm font-medium">{new Date(semestre.data_fim).toLocaleDateString('pt-BR')}</span>
                                </div>
                                <div className="flex justify-between items-center pt-1">
                                    <span className="text-sm text-slate-600">Status</span>
                                    <span className={clsx(
                                        "px-2 py-0.5 rounded textxs font-bold uppercase tracking-wide border",
                                        semestre.status === 'ativo' ? "bg-green-50 text-green-700 border-green-200" : "bg-slate-100 text-slate-500 border-slate-200"
                                    )}>
                                        {semestre.status}
                                    </span>
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
