'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    FileText,
    Calendar,
    ChevronDown,
    Download,
    Loader2,
    PieChart,
    Users,
    CheckCircle2,
    TrendingUp,
    Search,
    Info,
    ArrowUpRight
} from 'lucide-react'
import clsx from 'clsx'
import { generateSituacaoDefesasReport, generateParticipacoesDocentesReport } from '@/lib/tcc-pdf'

export default function TccRelatoriosPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [generatingPdf, setGeneratingPdf] = useState(false)
    const [defesas, setDefesas] = useState<any[]>([])
    const [notas, setNotas] = useState<any[]>([])
    const [semestres, setSemestres] = useState<string[]>([])
    const [filterSemester, setFilterSemester] = useState('')
    const [viewMode, setViewMode] = useState<'top' | 'full'>('top')
    const [sortConfig, setSortConfig] = useState<{ key: string, direction: 'asc' | 'desc' } | null>({ key: 'total', direction: 'desc' })

    useEffect(() => {
        const checkAccess = async () => {
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) {
                router.push('/login')
                return
            }

            const { data: accessData } = await supabase
                .from('users_access')
                .select('access_level')
                .eq('id', session.user.id)
                .single()

            if (!accessData || accessData.access_level < 2) {
                router.push('/')
                return
            }

            fetchInitialData()
        }
        checkAccess()
    }, [])

    const fetchInitialData = async () => {
        setLoading(true)
        try {
            // 1. Fetch Semestres
            const { data: semData } = await supabase
                .from('semestres')
                .select('*')
                .order('ano', { ascending: false })
                .order('semestre', { ascending: false })

            if (semData) {
                const formatted = semData.map(s => `${s.ano}.${s.semestre}`)
                setSemestres(formatted)

                // Define current semester
                const now = new Date()
                let current = ''
                const activeSem = semData.find(s => {
                    const start = s.data_inicio ? new Date(s.data_inicio) : null
                    const end = s.data_fim ? new Date(s.data_fim) : null
                    return start && end && now >= start && now <= end
                })
                current = activeSem ? `${activeSem.ano}.${activeSem.semestre}` : formatted[0]
                setFilterSemester(current)
                fetchStats(current)
            }
        } catch (err) {
            console.error(err)
        } finally {
            setLoading(false)
        }
    }

    const fetchStats = async (semester: string) => {
        setLoading(true)
        try {
            const [defRes, notasRes] = await Promise.all([
                supabase.from('dados_defesas').select('*').eq('semestre', semester),
                supabase.from('notas').select('*')
            ])

            setDefesas(defRes.data || [])
            setNotas(notasRes.data || [])
        } catch (err) {
            console.error(err)
        } finally {
            setLoading(false)
        }
    }

    useEffect(() => {
        if (filterSemester) fetchStats(filterSemester)
    }, [filterSemester])

    // Calculations
    const totalDefesas = defesas.length
    const defesasComData = defesas.filter(d => d.dia).length
    const defesasPendentesData = totalDefesas - defesasComData

    const getNotaFinal = (defesaId: number, avaliadorNumero: number) => {
        const nota = notas.find(n => n.defesa_id === defesaId && n.avaliador_numero === avaliadorNumero)
        if (!nota) return null
        if (nota.modo_nota_total) return nota.nota_total || 0
        const fields = ['introducao', 'problematizacao', 'referencial', 'desenvolvimento', 'conclusoes', 'forma', 'estruturacao', 'clareza', 'dominio']
        return fields.reduce((acc, field) => acc + (nota[field] || 0), 0)
    }

    const getAllMedias = () => {
        return defesas.map(d => {
            const n1 = getNotaFinal(d.id, 1)
            const n2 = getNotaFinal(d.id, 2)
            const n3 = getNotaFinal(d.id, 3)
            const valids = [n1, n2, n3].filter(n => n !== null) as number[]
            return valids.length > 0 ? valids.reduce((a, b) => a + b, 0) / valids.length : null
        }).filter(m => m !== null) as number[]
    }

    const medias = getAllMedias()
    const mediaGeral = medias.length > 0 ? medias.reduce((a, b) => a + b, 0) / medias.length : 0

    const docsCompletos = defesas.filter(d => d.doc_tcc_devolvido && d.doc_termo_devolvido && d.doc_outros_devolvido).length
    const docsPendentes = totalDefesas - docsCompletos

    // Group by month
    const monthStats = defesas.reduce((acc: any, d) => {
        if (!d.dia) return acc
        const month = new Date(d.dia + 'T12:00:00').toLocaleString('pt-BR', { month: 'long' })
        acc[month] = (acc[month] || 0) + 1
        return acc
    }, {})

    const generatePDF = async () => {
        setGeneratingPdf(true)
        try {
            await generateSituacaoDefesasReport(defesas, notas, filterSemester)
        } catch (err) {
            alert('Erro ao gerar relatório')
        } finally {
            setGeneratingPdf(false)
        }
    }

    // Detailed Participation Data
    const participationMap = defesas.reduce((acc: any, d) => {
        const rolesMap: { [key: string]: string[] } = {
            orientador: [d.orientador],
            coorientador: [d.coorientador],
            avaliador: [d.avaliador1, d.avaliador2, d.avaliador3]
        };

        const seenInThisDefense = new Set<string>();

        // We iterate through roles but check for duplication
        Object.entries(rolesMap).forEach(([role, names]) => {
            names.forEach(name => {
                if (!name || name === 'null' || name === '' || name.toLowerCase().includes('a definir')) return;

                // Normalizing name for comparison
                const normalizedName = name.trim();

                if (!acc[normalizedName]) {
                    acc[normalizedName] = { nome: normalizedName, orientador: 0, coorientador: 0, avaliador: 0, total: 0 };
                }

                // Business Rule: If advisor is also in evaluator slot, count only as advisor and don't duplicate total
                if (role === 'orientador') {
                    acc[normalizedName].orientador++;
                } else if (role === 'coorientador') {
                    acc[normalizedName].coorientador++;
                } else if (role === 'avaliador') {
                    // Only count as evaluator if not already counted as advisor in this defense
                    if (normalizedName === d.orientador?.trim()) return;
                    acc[normalizedName].avaliador++;
                }

                // Increment total only once per defense per teacher
                if (!seenInThisDefense.has(normalizedName)) {
                    acc[normalizedName].total++;
                    seenInThisDefense.add(normalizedName);
                }
            });
        });
        return acc;
    }, {});

    const participationList = Object.values(participationMap).sort((a: any, b: any) => {
        if (!sortConfig) return 0;
        const { key, direction } = sortConfig;
        if (a[key] < b[key]) return direction === 'asc' ? -1 : 1;
        if (a[key] > b[key]) return direction === 'asc' ? 1 : -1;
        return 0;
    });

    const requestSort = (key: string) => {
        let direction: 'asc' | 'desc' = 'desc';
        if (sortConfig && sortConfig.key === key && sortConfig.direction === 'desc') {
            direction = 'asc';
        }
        setSortConfig({ key, direction });
    };

    const sortedAdvisors = Object.values(participationMap)
        .sort((a: any, b: any) => b.total - a.total)
        .slice(0, 5);

    const totalParticipacoes = participationList.reduce((acc: number, p: any) => acc + p.total, 0)
    const totalDocentesDiferentes = participationList.length

    const handleExportParticipacoes = async () => {
        setGeneratingPdf(true)
        try {
            const totalParticipations = participationList.reduce((acc: number, p: any) => acc + p.total, 0)
            await generateParticipacoesDocentesReport(participationList, totalDefesas, totalParticipations, filterSemester)
        } catch (err) {
            alert('Erro ao gerar relatório')
        } finally {
            setGeneratingPdf(false)
        }
    }

    const handleExportGeral = async () => {
        setGeneratingPdf(true)
        try {
            await generateSituacaoDefesasReport(defesas, notas, filterSemester)
        } catch (err) {
            alert('Erro ao gerar relatório')
        } finally {
            setGeneratingPdf(false)
        }
    }

    return (
        <div className="min-h-screen bg-[#F8FAFC] text-slate-700 antialiased font-sans">
            {/* Header Redesign - Compact & Premium */}
            <header className="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-sm">
                <div className="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <Link href="/tcc" className="w-8 h-8 rounded-lg bg-slate-50 flex items-center justify-center text-slate-500 hover:bg-slate-100 transition-all border border-slate-200">
                            <ArrowLeft size={16} />
                        </Link>
                        <div>
                            <h1 className="text-sm font-black text-slate-900 uppercase tracking-tight flex items-center gap-2">
                                <FileText size={16} className="text-indigo-600" />
                                Relatórios de TCC
                            </h1>
                            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest leading-none">Visão Analítica do Semestre</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-2">
                        <div className="relative group">
                            <div className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-hover:text-indigo-600 transition-colors">
                                <Calendar size={14} />
                            </div>
                            <select
                                className="pl-9 pr-8 h-9 rounded-xl border border-slate-200 bg-slate-50 text-[11px] font-black text-slate-700 uppercase appearance-none focus:ring-2 focus:ring-indigo-100 focus:border-indigo-300 outline-none transition-all cursor-pointer hover:bg-white"
                                value={filterSemester}
                                onChange={(e) => setFilterSemester(e.target.value)}
                            >
                                {semestres.map(s => <option key={s} value={s}>{s}</option>)}
                            </select>
                            <div className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none">
                                <ChevronDown size={14} />
                            </div>
                        </div>

                        <button
                            onClick={handleExportParticipacoes}
                            disabled={generatingPdf || totalDefesas === 0}
                            className="h-8 px-3 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white flex items-center gap-1.5 text-[10px] font-black uppercase tracking-wider shadow-md shadow-indigo-100 transition-all active:scale-95 disabled:opacity-50"
                        >
                            {generatingPdf ? <Loader2 size={12} className="animate-spin" /> : <Download size={12} />}
                            <span className="hidden sm:inline">Baixar Participações</span>
                        </button>
                    </div>
                </div>
            </header>

            <main className="max-w-7xl mx-auto px-4 py-6">
                {/* Stats Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                    {/* Total Bancas */}
                    <div className="bg-white p-4 rounded-2xl border border-slate-100 shadow-sm relative overflow-hidden group">
                        <div className="absolute -right-4 -top-4 w-16 h-16 rounded-full bg-blue-50/50 group-hover:scale-110 transition-transform" />
                        <div className="relative z-10">
                            <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center mb-2">
                                <TrendingUp size={16} />
                            </div>
                            <h3 className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-0.5">Total de Bancas</h3>
                            <div className="flex items-baseline gap-1.5">
                                <span className="text-2xl font-black text-slate-900">{totalDefesas}</span>
                                <span className="text-[9px] font-bold text-slate-400 uppercase">Bancas</span>
                            </div>
                        </div>
                    </div>

                    {/* Média Geral */}
                    <div className="bg-white p-4 rounded-2xl border border-slate-100 shadow-sm relative overflow-hidden group">
                        <div className="absolute -right-4 -top-4 w-16 h-16 rounded-full bg-emerald-50/50 group-hover:scale-110 transition-transform" />
                        <div className="relative z-10">
                            <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center mb-2">
                                <TrendingUp size={16} />
                            </div>
                            <h3 className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-0.5">Média Geral</h3>
                            <div className="flex items-baseline gap-1.5">
                                <span className="text-2xl font-black text-slate-900">{mediaGeral.toFixed(1)}</span>
                                <span className="text-[9px] font-bold text-slate-400 uppercase">pontos</span>
                            </div>
                        </div>
                    </div>

                    {/* Documentação */}
                    <div className="bg-white p-4 rounded-2xl border border-slate-100 shadow-sm relative overflow-hidden group">
                        <div className="absolute -right-4 -top-4 w-16 h-16 rounded-full bg-indigo-50/50 group-hover:scale-110 transition-transform" />
                        <div className="relative z-10">
                            <div className="w-8 h-8 rounded-xl bg-indigo-50 text-indigo-600 flex items-center justify-center mb-2">
                                <CheckCircle2 size={16} />
                            </div>
                            <h3 className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-0.5">Doc. Concluída</h3>
                            <div className="flex items-baseline gap-1.5">
                                <span className="text-2xl font-black text-slate-900">{docsCompletos}</span>
                                <span className="text-[9px] font-bold text-slate-400 uppercase">de {totalDefesas}</span>
                            </div>
                        </div>
                    </div>

                    {/* Resumo do Semestre */}
                    <div className="bg-indigo-50/50 p-4 rounded-2xl border border-indigo-100 shadow-sm relative overflow-hidden group">
                        <div className="absolute -right-4 -top-4 w-16 h-16 rounded-full bg-indigo-100/50 group-hover:scale-110 transition-transform" />
                        <div className="relative z-10">
                            <h3 className="text-[10px] font-black text-indigo-900 uppercase tracking-widest mb-3 flex items-center gap-2">
                                <PieChart size={14} className="text-indigo-600" />
                                Resumo do Semestre
                            </h3>
                            <div className="space-y-2">
                                <div className="flex justify-between items-center border-b border-indigo-100/50 pb-1">
                                    <span className="text-[9px] font-bold text-slate-500 uppercase">Bancas Realizadas</span>
                                    <span className="text-[11px] font-black text-slate-900">{totalDefesas}</span>
                                </div>
                                <div className="flex justify-between items-center border-b border-indigo-100/50 pb-1">
                                    <span className="text-[9px] font-bold text-slate-500 uppercase">Participações em Bancas</span>
                                    <span className="text-[11px] font-black text-slate-900">{totalParticipacoes}</span>
                                </div>
                                <div className="flex justify-between items-center">
                                    <span className="text-[9px] font-bold text-slate-500 uppercase">Docentes Diferentes</span>
                                    <span className="text-[11px] font-black text-slate-900">{totalDocentesDiferentes}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Analytical Sections */}
                <div className="grid grid-cols-1 gap-6">
                    {/* Top Advisors & Participation */}
                    <div className="space-y-6">
                        {/* Top Advisors & Participation Card */}
                        <div className="bg-white rounded-3xl border-2 border-indigo-50 shadow-sm overflow-hidden flex flex-col transition-all hover:shadow-md">
                            <div className="p-6 border-b border-indigo-50 flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-indigo-50/30">
                                <h3 className="text-xs font-black text-slate-900 uppercase tracking-widest flex items-center gap-2">
                                    <Users size={16} className="text-indigo-600" />
                                    Participação dos Docentes
                                </h3>

                                <div className="flex bg-white/50 p-1 rounded-xl border border-indigo-100 self-start sm:self-auto shadow-sm">
                                    <button
                                        onClick={() => setViewMode('top')}
                                        className={clsx(
                                            "px-3 py-1.5 rounded-lg text-[9px] font-black uppercase tracking-wider transition-all",
                                            viewMode === 'top' ? "bg-white text-indigo-600 shadow-sm" : "text-slate-400 hover:text-slate-600"
                                        )}
                                    >
                                        Top 5
                                    </button>
                                    <button
                                        onClick={() => setViewMode('full')}
                                        className={clsx(
                                            "px-3 py-1.5 rounded-lg text-[9px] font-black uppercase tracking-wider transition-all",
                                            viewMode === 'full' ? "bg-white text-indigo-600 shadow-sm" : "text-slate-400 hover:text-slate-600"
                                        )}
                                    >
                                        Lista Completa
                                    </button>
                                </div>
                            </div>

                            <div className="p-6 flex-1">
                                {viewMode === 'top' ? (
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                        {sortedAdvisors.length > 0 ? (
                                            sortedAdvisors.map((p: any, idx) => (
                                                <div key={idx} className="flex items-center gap-4 bg-slate-50/50 p-4 rounded-2xl border border-slate-100 hover:bg-white hover:border-indigo-200 transition-all shadow-sm hover:shadow-md group">
                                                    <div className="w-8 h-8 rounded-full bg-white flex items-center justify-center text-[11px] font-black text-indigo-600 shadow-sm border border-indigo-50 group-hover:scale-110 transition-transform">
                                                        #{idx + 1}
                                                    </div>
                                                    <div className="flex-1 min-w-0">
                                                        <p className="text-[11px] font-bold text-slate-800 uppercase truncate">{p.nome}</p>
                                                        <p className="text-[9px] font-bold text-slate-400 uppercase">{p.total} participações totais</p>
                                                    </div>
                                                    <div className="text-indigo-400 group-hover:text-indigo-600 transition-colors">
                                                        <ArrowUpRight size={14} />
                                                    </div>
                                                </div>
                                            ))
                                        ) : (
                                            <div className="col-span-full py-12 text-center">
                                                <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Sem dados de participação</p>
                                            </div>
                                        )}
                                    </div>
                                ) : (
                                    <div className="overflow-x-auto -mx-6 sm:mx-0">
                                        <div className="inline-block min-w-full align-middle sm:px-0">
                                            <table className="min-w-full border-separate border-spacing-0">
                                                <thead>
                                                    <tr className="bg-indigo-50/50">
                                                        <th
                                                            onClick={() => requestSort('nome')}
                                                            className="sticky left-0 bg-indigo-50/80 backdrop-blur-md text-left text-[9px] font-black text-indigo-900 uppercase tracking-tighter p-3 border-b border-indigo-100 rounded-tl-xl whitespace-nowrap cursor-pointer hover:bg-indigo-100 transition-colors"
                                                        >
                                                            Docente {sortConfig?.key === 'nome' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                        </th>
                                                        <th
                                                            onClick={() => requestSort('orientador')}
                                                            className="text-center text-[9px] font-black text-indigo-900 uppercase tracking-tighter p-3 border-b border-indigo-100 whitespace-nowrap cursor-pointer hover:bg-indigo-100 transition-colors"
                                                        >
                                                            OR {sortConfig?.key === 'orientador' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                        </th>
                                                        <th
                                                            onClick={() => requestSort('coorientador')}
                                                            className="text-center text-[9px] font-black text-indigo-900 uppercase tracking-tighter p-3 border-b border-indigo-100 whitespace-nowrap cursor-pointer hover:bg-indigo-100 transition-colors"
                                                        >
                                                            CO {sortConfig?.key === 'coorientador' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                        </th>
                                                        <th
                                                            onClick={() => requestSort('avaliador')}
                                                            className="text-center text-[9px] font-black text-indigo-900 uppercase tracking-tighter p-3 border-b border-indigo-100 whitespace-nowrap cursor-pointer hover:bg-indigo-100 transition-colors"
                                                        >
                                                            AV {sortConfig?.key === 'avaliador' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                        </th>
                                                        <th
                                                            onClick={() => requestSort('total')}
                                                            className="text-center text-[9px] font-black text-indigo-900 uppercase tracking-tighter p-3 border-b border-indigo-100 rounded-tr-xl whitespace-nowrap cursor-pointer hover:bg-indigo-100 transition-colors"
                                                        >
                                                            Total {sortConfig?.key === 'total' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                        </th>
                                                    </tr>
                                                </thead>
                                                <tbody className="divide-y divide-slate-100">
                                                    {participationList.map((p: any, idx) => (
                                                        <tr key={idx} className="hover:bg-indigo-50/30 transition-colors even:bg-blue-50/20">
                                                            <td className="sticky left-0 bg-transparent backdrop-blur-sm p-3 text-[10px] font-bold text-slate-700 uppercase whitespace-nowrap truncate max-w-[180px] border-b border-slate-100">
                                                                <div className="bg-white/40 backdrop-blur-sm -m-3 p-3 group-hover:bg-transparent">
                                                                    {p.nome}
                                                                </div>
                                                            </td>
                                                            <td className="p-3 text-center text-[10px] font-medium text-slate-600 border-b border-slate-100">{p.orientador}</td>
                                                            <td className="p-3 text-center text-[10px] font-medium text-slate-600 border-b border-slate-100">{p.coorientador}</td>
                                                            <td className="p-3 text-center text-[10px] font-medium text-slate-600 border-b border-slate-100">{p.avaliador}</td>
                                                            <td className="p-3 text-center text-[10px] font-black text-indigo-600 border-b border-slate-100">{p.total}</td>
                                                        </tr>
                                                    ))}
                                                </tbody>
                                            </table>
                                        </div>
                                    </div>
                                )}

                                {viewMode === 'full' && (
                                    <div className="mt-4 flex justify-end">
                                        <button
                                            onClick={handleExportParticipacoes}
                                            disabled={generatingPdf}
                                            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-[10px] font-black uppercase tracking-widest shadow-lg shadow-indigo-100 transition-all active:scale-95"
                                        >
                                            <Download size={14} />
                                            Baixar Relatório de Participações
                                        </button>
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    )
}
