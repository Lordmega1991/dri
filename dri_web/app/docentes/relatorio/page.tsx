'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Download,
    Filter,
    Users,
    Clock,
    Briefcase,
    GraduationCap,
    PieChart,
    Search,
    ChevronDown,
    MoreHorizontal,
    FileText,
    TrendingUp,
    Shield
} from 'lucide-react'
import clsx from 'clsx'

export default function RelatorioConsolidadoPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [semestres, setSemestres] = useState<any[]>([])
    const [selectedSemestre, setSelectedSemestre] = useState<string>('')
    const [selectedSemestreLabel, setSelectedSemestreLabel] = useState<string>('')

    const [data, setData] = useState<any[]>([])
    const [searchTerm, setSearchTerm] = useState('')

    useEffect(() => {
        const fetchInitial = async () => {
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) { router.push('/login'); return }

            const { data: sems } = await supabase
                .from('semestres')
                .select('*')
                .order('ano', { ascending: false })
                .order('semestre', { ascending: false })

            if (sems && sems.length > 0) {
                setSemestres(sems)
                setSelectedSemestre(sems[0].id)
                setSelectedSemestreLabel(`${sems[0].ano}.${sems[0].semestre}`)
                loadReportData(sems[0].id, `${sems[0].ano}.${sems[0].semestre}`)
            } else {
                setLoading(false)
            }
        }
        fetchInitial()
    }, [router])

    const loadReportData = async (semId: string, semLabel: string) => {
        setLoading(true)

        // Fetch everything needed
        const [
            { data: docs },
            { data: activities },
            { data: types },
            { data: defenses }
        ] = await Promise.all([
            supabase.from('docentes').select('*').order('nome'),
            supabase.from('atividades_docentes').select('*').eq('semestre_id', semId),
            supabase.from('tipos_atividade').select('*'),
            supabase.from('dados_defesas').select('*').eq('semestre', semLabel)
        ])

        if (!docs) { setLoading(false); return }

        // Process data per Docente
        const processed = docs.map(doc => {
            const docActivities = activities?.filter(a => a.docente_id === doc.id) || []

            // Calc CH components
            let chEnsino = 0
            let chGestao = 0
            let chOutros = 0

            docActivities.forEach(a => {
                const type = types?.find(t => t.id === a.tipo_atividade_id)
                const cat = type?.categoria?.toLowerCase() || ''

                if (cat.includes('ensino') || cat.includes('aula')) chEnsino += (a.ch_semanal || 0)
                else if (cat.includes('gestão') || cat.includes('adm') || cat.includes('administrativa')) chGestao += (a.ch_semanal || 0)
                else chOutros += (a.ch_semanal || 0)
            })

            // Calc Bancas (fuzzy match name)
            const docName = doc.nome.toLowerCase().trim()
            const docBancas = defenses?.filter(d => {
                const orientador = d.orientador?.toLowerCase().trim()
                const coorientador = d.coorientador?.toLowerCase().trim()
                const a1 = d.avaliador1?.toLowerCase().trim()
                const a2 = d.avaliador2?.toLowerCase().trim()
                const a3 = d.avaliador3?.toLowerCase().trim()
                return [orientador, coorientador, a1, a2, a3].includes(docName)
            }) || []

            return {
                id: doc.id,
                nome: doc.nome,
                matricula: doc.matricula,
                chTotal: chEnsino + chGestao + chOutros,
                chEnsino,
                chGestao,
                chOutros,
                bancasCount: docBancas.length
            }
        })

        setData(processed)
        setLoading(false)
    }

    const handleSemestreChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
        const sem = semestres.find(s => s.id === e.target.value)
        if (sem) {
            setSelectedSemestre(sem.id)
            setSelectedSemestreLabel(`${sem.ano}.${sem.semestre}`)
            loadReportData(sem.id, `${sem.ano}.${sem.semestre}`)
        }
    }

    const filteredData = data.filter(d =>
        d.nome.toLowerCase().includes(searchTerm.toLowerCase()) ||
        d.matricula?.toString().includes(searchTerm)
    ).sort((a, b) => b.chTotal - a.chTotal)

    const stats = {
        totalDocentes: data.length,
        avgCH: data.length > 0 ? (data.reduce((acc, curr) => acc + curr.chTotal, 0) / data.length).toFixed(1) : 0,
        totalBancas: data.reduce((acc, curr) => acc + curr.bancasCount, 0)
    }

    if (loading && semestres.length === 0) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-[#F5F5F7]">
                <div className="flex flex-col items-center gap-4">
                    <div className="w-12 h-12 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
                    <p className="font-bold text-slate-500 uppercase tracking-widest text-[10px]">Gerando Relatório Consolidado...</p>
                </div>
            </div>
        )
    }

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-slate-900 font-sans antialiased selection:bg-indigo-100 selection:text-indigo-900">
            {/* Header / Sticky Top */}
            <header className="bg-white/90 backdrop-blur-xl border-b border-slate-200 sticky top-0 z-50">
                <div className="max-w-[1600px] mx-auto px-6 h-20 md:h-24 flex flex-col justify-center">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-6">
                            <Link href="/docentes" className="w-10 h-10 md:w-12 md:h-12 bg-white border border-slate-200 flex items-center justify-center rounded-2xl text-slate-400 hover:text-indigo-600 hover:border-indigo-100 hover:shadow-md transition-all">
                                <ArrowLeft size={22} />
                            </Link>
                            <div className="flex flex-col">
                                <h1 className="text-xl md:text-3xl font-black text-slate-900 tracking-tighter uppercase leading-none">Status do Departamento</h1>
                                <div className="flex items-center gap-2 mt-2">
                                    <span className="px-2 py-0.5 bg-indigo-600 text-white text-[9px] font-black rounded uppercase tracking-wider">{selectedSemestreLabel}</span>
                                    <span className="text-[10px] md:text-xs font-bold uppercase tracking-wider text-slate-400">Visão Geral de Encargos e Atividades</span>
                                </div>
                            </div>
                        </div>

                        <div className="flex items-center gap-4">
                            {/* Stats in Header for Desktop */}
                            <div className="hidden lg:flex items-center gap-8 mr-8 border-r border-slate-100 pr-8">
                                <div className="text-right">
                                    <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Docentes</p>
                                    <p className="text-xl font-black text-slate-900">{stats.totalDocentes}</p>
                                </div>
                                <div className="text-right">
                                    <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Média CH</p>
                                    <p className="text-xl font-black text-indigo-600">{stats.avgCH}h</p>
                                </div>
                                <div className="text-right">
                                    <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Bancas</p>
                                    <p className="text-xl font-black text-emerald-600">{stats.totalBancas}</p>
                                </div>
                            </div>

                            <div className="flex items-center bg-slate-100 rounded-2xl px-3 py-2 border border-slate-200 gap-2">
                                <Filter size={14} className="text-slate-400" />
                                <select
                                    className="bg-transparent text-xs font-black text-slate-700 outline-none pr-4 cursor-pointer"
                                    value={selectedSemestre}
                                    onChange={handleSemestreChange}
                                >
                                    {semestres.map(s => (
                                        <option key={s.id} value={s.id}>{s.ano}.{s.semestre}</option>
                                    ))}
                                </select>
                            </div>

                            <button className="h-10 md:h-12 px-6 bg-slate-900 text-white text-xs font-black uppercase tracking-widest rounded-2xl hover:bg-black transition-all shadow-lg flex items-center gap-2">
                                <Download size={16} />
                                <span className="hidden md:inline">Exportar Planilha</span>
                            </button>
                        </div>
                    </div>
                </div>
            </header>

            <main className="max-w-[1600px] mx-auto px-6 py-10">
                {/* Search & Tool Bar */}
                <div className="mb-8 flex flex-col md:flex-row gap-4 items-center justify-between">
                    <div className="relative w-full md:w-96">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                        <input
                            type="text"
                            placeholder="Buscar por nome ou matrícula..."
                            className="w-full pl-12 pr-4 py-3 bg-white border border-slate-200 rounded-2xl text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-100 transition-all shadow-sm"
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                        />
                    </div>

                    <div className="flex items-center gap-4 text-xs font-bold text-slate-500 uppercase tracking-widest">
                        <span>Total de <b>{filteredData.length}</b> docentes encontrados</span>
                    </div>
                </div>

                {/* Main Table */}
                <div className="bg-white rounded-3xl border border-slate-200 shadow-xl overflow-hidden relative">
                    {loading && (
                        <div className="absolute inset-0 bg-white/60 backdrop-blur-[2px] z-10 flex items-center justify-center">
                            <Clock className="animate-spin text-indigo-600" size={32} />
                        </div>
                    )}

                    <div className="overflow-x-auto">
                        <table className="w-full text-left border-collapse">
                            <thead>
                                <tr className="bg-slate-50/80 border-b border-slate-200">
                                    <th className="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[2px]">Docente</th>
                                    <th className="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[2px] text-center">CH Total</th>
                                    <th className="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[2px] text-center">Ensino / Aulas</th>
                                    <th className="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[2px] text-center">Ativ. Administrativas</th>
                                    <th className="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[2px] text-center">Bancas (TCC)</th>
                                    <th className="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[2px] text-center">Status</th>
                                    <th className="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[2px] text-right">Ações</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                                {filteredData.map((d, i) => (
                                    <tr key={d.id} className="hover:bg-slate-50/50 transition-colors group">
                                        <td className="px-8 py-5">
                                            <div className="flex items-center gap-4">
                                                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-slate-100 to-slate-200 flex items-center justify-center font-black text-slate-500 text-sm border border-white shrink-0 group-hover:scale-110 transition-transform">
                                                    {d.nome.charAt(0)}
                                                </div>
                                                <div className="flex flex-col min-w-0">
                                                    <span className="text-sm font-black text-slate-800 uppercase tracking-tight truncate">{d.nome}</span>
                                                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{d.matricula || 'SEM MATRÍCULA'}</span>
                                                </div>
                                            </div>
                                        </td>

                                        <td className="px-8 py-5 text-center">
                                            <div className="inline-flex items-baseline gap-1 bg-indigo-50 px-4 py-1.5 rounded-full border border-indigo-100">
                                                <span className="text-base font-black text-indigo-700">{d.chTotal}</span>
                                                <span className="text-[10px] font-bold text-indigo-400 uppercase">hrs</span>
                                            </div>
                                        </td>

                                        <td className="px-8 py-5 text-center">
                                            <span className={clsx(
                                                "text-xs font-bold",
                                                d.chEnsino > 0 ? "text-slate-700" : "text-slate-300"
                                            )}>{d.chEnsino}h</span>
                                        </td>

                                        <td className="px-8 py-5 text-center">
                                            <span className={clsx(
                                                "text-xs font-bold",
                                                d.chGestao > 0 ? "text-slate-700" : "text-slate-300"
                                            )}>{d.chGestao}h</span>
                                        </td>

                                        <td className="px-8 py-5 text-center">
                                            <div className={clsx(
                                                "inline-flex items-center gap-2 px-3 py-1 rounded-lg font-black text-xs",
                                                d.bancasCount > 0 ? "bg-emerald-50 text-emerald-700 border border-emerald-100" : "text-slate-300"
                                            )}>
                                                <GraduationCap size={14} />
                                                <span>{d.bancasCount}</span>
                                            </div>
                                        </td>

                                        <td className="px-8 py-5 text-center">
                                            <div className="flex justify-center">
                                                {d.chTotal >= 8 ? (
                                                    <div className="w-6 h-6 rounded-full bg-emerald-500 flex items-center justify-center text-white shadow-sm border-2 border-white" title="Carga horária regular">
                                                        <Shield size={12} fill="currentColor" />
                                                    </div>
                                                ) : d.chTotal > 0 ? (
                                                    <div className="w-6 h-6 rounded-full bg-orange-400 flex items-center justify-center text-white shadow-sm border-2 border-white" title="Carga horária reduzida">
                                                        <Shield size={12} fill="currentColor" />
                                                    </div>
                                                ) : (
                                                    <div className="w-6 h-6 rounded-full bg-slate-200 flex items-center justify-center text-white shadow-sm border-2 border-white" title="Sem atividades">
                                                        <Shield size={12} fill="currentColor" />
                                                    </div>
                                                )}
                                            </div>
                                        </td>

                                        <td className="px-8 py-5 text-right">
                                            <button className="p-2 hover:bg-white hover:shadow-md rounded-xl transition-all text-slate-400 hover:text-indigo-600">
                                                <MoreHorizontal size={20} />
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>

                    {filteredData.length === 0 && (
                        <div className="py-24 flex flex-col items-center justify-center text-slate-300">
                            <Search size={48} className="opacity-20 mb-4" />
                            <p className="text-xs font-black uppercase tracking-widest">Nenhum docente corresponde à sua busca</p>
                        </div>
                    )}
                </div>

                {/* Visual Analytics Summary */}
                <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6">
                    <div className="bg-white p-6 rounded-[2rem] border border-slate-200 shadow-sm">
                        <div className="flex items-center gap-3 mb-4">
                            <PieChart size={18} className="text-indigo-600" />
                            <h3 className="font-black text-slate-800 uppercase text-xs tracking-wider">Carga por Categoria</h3>
                        </div>
                        <div className="space-y-4">
                            {[
                                { label: 'Ensino', val: data.reduce((a, b) => a + b.chEnsino, 0), color: 'bg-indigo-600' },
                                { label: 'Gestão / Adm', val: data.reduce((a, b) => a + b.chGestao, 0), color: 'bg-emerald-500' },
                                { label: 'Outros', val: data.reduce((a, b) => a + b.chOutros, 0), color: 'bg-orange-400' }
                            ].map(item => {
                                const total = data.reduce((a, b) => a + b.chTotal, 0)
                                const pct = total > 0 ? (item.val / total) * 100 : 0
                                return (
                                    <div key={item.label} className="space-y-1">
                                        <div className="flex justify-between text-[10px] font-black uppercase tracking-wider">
                                            <span>{item.label}</span>
                                            <span>{item.val}h ({pct.toFixed(0)}%)</span>
                                        </div>
                                        <div className="h-2 bg-slate-50 rounded-full overflow-hidden">
                                            <div className={clsx("h-full rounded-full transition-all", item.color)} style={{ width: `${pct}%` }} />
                                        </div>
                                    </div>
                                )
                            })}
                        </div>
                    </div>

                    <div className="bg-white p-6 rounded-[2rem] border border-slate-200 shadow-sm flex flex-col justify-center text-center">
                        <TrendingUp size={32} className="mx-auto text-emerald-500 mb-3" />
                        <h4 className="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-1">Carga Horária Total Depto</h4>
                        <p className="text-4xl font-black text-slate-900 tracking-tighter">{data.reduce((a, b) => a + b.chTotal, 0)}h</p>
                        <p className="text-[10px] font-bold text-emerald-600 uppercase mt-2">Ativo no Semestre {selectedSemestreLabel}</p>
                    </div>

                    <div className="bg-white p-6 rounded-[2rem] border border-slate-200 shadow-sm flex flex-col justify-center text-center">
                        <Users size={32} className="mx-auto text-orange-500 mb-3" />
                        <h4 className="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-1">Média de Bancas/Docente</h4>
                        <p className="text-4xl font-black text-slate-900 tracking-tighter">{(stats.totalBancas / (stats.totalDocentes || 1)).toFixed(1)}</p>
                        <p className="text-[10px] font-bold text-orange-600 uppercase mt-2">Participações totais: {stats.totalBancas}</p>
                    </div>
                </div>
            </main>
        </div>
    )
}
