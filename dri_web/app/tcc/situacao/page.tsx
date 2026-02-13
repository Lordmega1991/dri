'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Printer,
    RefreshCw,
    Search,
    CheckCircle2,
    XCircle,
    ChevronDown,
    FileText,
    TrendingUp,
    Users,
    AlertCircle
} from 'lucide-react'
import clsx from 'clsx'
import { generateSituacaoDefesasReport } from '@/lib/tcc-pdf'

type Nota = {
    defesa_id: number
    avaliador_numero: number
    nota_total: number | null
    modo_nota_total: boolean
    [key: string]: any
}

type Defesa = {
    id: number
    semestre: string
    dia: string | null
    discente: string
    orientador: string | null
    doc_tcc_devolvido: boolean
    doc_termo_devolvido: boolean
    doc_outros_devolvido: boolean
}

export default function SituacaoDefesasPage() {
    const router = useRouter()
    const [defesas, setDefesas] = useState<Defesa[]>([])
    const [notas, setNotas] = useState<Nota[]>([])
    const [loading, setLoading] = useState(true)
    const [semestreFiltro, setSemestreFiltro] = useState('')
    const [semestres, setSemestres] = useState<string[]>([])
    const [search, setSearch] = useState('')
    const [sortBy, setSortBy] = useState<string>('dia')
    const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)

    const [sortAsc, setSortAsc] = useState(true)

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

            setUserAccessLevel(accessData.access_level)
            fetchData()
        }
        checkAccess()
    }, [])

    const fetchData = async () => {
        setLoading(true)
        try {
            const { data: defs } = await supabase.from('dados_defesas').select('*')
            const { data: nts } = await supabase.from('notas').select('*')

            if (defs) {
                setDefesas(defs)
                const uniqueSemestres = Array.from(new Set(defs.map(d => d.semestre))).sort((a, b) => {
                    const [anoA, semA] = a.split('.').map(Number)
                    const [anoB, semB] = b.split('.').map(Number)
                    if (anoA !== anoB) return anoB - anoA
                    return semB - semA
                })
                setSemestres(uniqueSemestres)

                if (semestreFiltro === '') {
                    const now = new Date()
                    const year = now.getFullYear()
                    const month = now.getMonth() + 1
                    const currentLabel = `${year}.${month <= 6 ? 1 : 2}`

                    if (uniqueSemestres.includes(currentLabel)) {
                        setSemestreFiltro(currentLabel)
                    } else if (uniqueSemestres.length > 0) {
                        setSemestreFiltro(uniqueSemestres[0])
                    }
                }
            }
            if (nts) setNotas(nts)
        } catch (err) {
            console.error(err)
        } finally {
            setLoading(false)
        }
    }

    useEffect(() => {
        fetchData()
    }, [])

    const getNotaFinal = (defesaId: number, avaliadorNumero: number) => {
        const nota = notas.find(n => n.defesa_id === defesaId && n.avaliador_numero === avaliadorNumero)
        if (!nota) return null
        if (nota.modo_nota_total) return nota.nota_total
        const fields = ['introducao', 'problematizacao', 'referencial', 'desenvolvimento', 'conclusoes', 'forma', 'estruturacao', 'clareza', 'dominio']
        return fields.reduce((acc, field) => acc + (nota[field] || 0), 0)
    }

    const toggleDoc = async (id: number, campo: string, valorAtual: boolean) => {
        if (userAccessLevel !== null && userAccessLevel < 3) return

        try {
            const novoValor = !valorAtual;
            let updates: any = { [campo]: novoValor };

            const defesa = defesas.find(d => d.id === id);
            if (defesa) {
                let tccDev = campo === 'doc_tcc_devolvido' ? novoValor : defesa.doc_tcc_devolvido;
                let termoDev = campo === 'doc_termo_devolvido' ? novoValor : defesa.doc_termo_devolvido;

                if (campo !== 'doc_outros_devolvido') {
                    updates.doc_outros_devolvido = (tccDev && termoDev);
                }
            }

            const { error } = await supabase.from('dados_defesas').update(updates).eq('id', id)
            if (error) throw error
            setDefesas(prev => prev.map(d => d.id === id ? { ...d, ...updates } : d))
        } catch (err) {
            alert('Erro ao atualizar')
        }
    }

    const filteredDefesas = defesas.filter(d => {
        const matchesSearch = d.discente.toLowerCase().includes(search.toLowerCase()) || (d.orientador?.toLowerCase().includes(search.toLowerCase()))
        const matchesSemestre = semestreFiltro === 'Todos' || d.semestre === semestreFiltro
        return matchesSearch && matchesSemestre
    }).sort((a, b) => {
        let valA: any = a[sortBy as keyof Defesa];
        let valB: any = b[sortBy as keyof Defesa];

        if (sortBy === 'dia') {
            valA = valA ? new Date(valA).getTime() : 0;
            valB = valB ? new Date(valB).getTime() : 0;
        }

        if (valA < valB) return sortAsc ? -1 : 1;
        if (valA > valB) return sortAsc ? 1 : -1;
        return 0;
    })

    const handleSort = (column: string) => {
        if (sortBy === column) {
            setSortAsc(!sortAsc)
        } else {
            setSortBy(column)
            setSortAsc(true)
        }
    }

    const totalMedia = () => {
        let sum = 0;
        let count = 0;
        filteredDefesas.forEach(d => {
            const v = [getNotaFinal(d.id, 1), getNotaFinal(d.id, 2), getNotaFinal(d.id, 3)].filter(n => n !== null) as number[]
            if (v.length > 0) {
                sum += v.reduce((a, b) => a + b, 0) / v.length;
                count++;
            }
        });
        return count > 0 ? (sum / count).toFixed(1) : '0.0';
    }

    const pendingDocs = filteredDefesas.filter(d => !d.doc_outros_devolvido || !d.doc_tcc_devolvido || !d.doc_termo_devolvido).length;

    return (
        <div className="min-h-screen bg-[#F8FAFC] font-sans">
            <header className="bg-[#0C4A6E] text-white py-3 px-4 sticky top-0 z-30 shadow-md">
                <div className="max-w-7xl mx-auto flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <Link href="/tcc" className="w-7 h-7 bg-white/10 rounded-lg flex items-center justify-center hover:bg-white/20 transition-all">
                            <ArrowLeft size={16} />
                        </Link>
                        <h1 className="text-base font-black italic uppercase tracking-tight">Situação da Documentação das Bancas de Defesas</h1>
                    </div>
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => generateSituacaoDefesasReport(filteredDefesas, notas, semestreFiltro)}
                            className="w-7 h-7 bg-white/10 rounded-lg flex items-center justify-center hover:bg-white/20 transition-all text-white"
                            title="Gerar Relatório PDF"
                        >
                            <Printer size={16} />
                        </button>
                        <button onClick={fetchData} className="w-7 h-7 bg-white/10 rounded-lg flex items-center justify-center hover:bg-white/20 transition-all">
                            <RefreshCw size={16} className={loading ? "animate-spin" : ""} />
                        </button>
                    </div>
                </div>
            </header>

            <main className="max-w-7xl mx-auto px-4 py-4">
                {/* Dashboard Summary - Super Compact */}
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-2 mb-4">
                    <div className="bg-white px-3 py-2 rounded-xl border border-gray-100 shadow-sm flex items-center gap-3">
                        <div className="w-8 h-8 bg-blue-50 rounded-lg flex items-center justify-center text-blue-600 shrink-0">
                            <Users size={16} />
                        </div>
                        <div>
                            <p className="text-slate-500 text-[10px] font-bold uppercase tracking-wider">Total</p>
                            <p className="text-lg font-bold text-slate-900 leading-none">{filteredDefesas.length}</p>
                        </div>
                    </div>
                    <div className="bg-white px-3 py-2 rounded-xl border border-gray-100 shadow-sm flex items-center gap-3">
                        <div className="w-8 h-8 bg-emerald-50 rounded-lg flex items-center justify-center text-emerald-600 shrink-0">
                            <TrendingUp size={16} />
                        </div>
                        <div>
                            <p className="text-slate-500 text-[10px] font-bold uppercase tracking-wider">Média</p>
                            <p className="text-lg font-bold text-slate-900 leading-none">{totalMedia()}</p>
                        </div>
                    </div>
                    <div className="bg-white px-3 py-2 rounded-xl border border-gray-100 shadow-sm flex items-center gap-3">
                        <div className="w-8 h-8 bg-orange-50 rounded-lg flex items-center justify-center text-orange-600 shrink-0">
                            <AlertCircle size={16} />
                        </div>
                        <div>
                            <p className="text-slate-500 text-[10px] font-bold uppercase tracking-wider">Pendentes</p>
                            <p className="text-lg font-bold text-slate-900 leading-none">{pendingDocs}</p>
                        </div>
                    </div>
                    <div className="bg-white px-3 py-2 rounded-xl border border-gray-100 shadow-sm flex items-center gap-3 border-l-2 border-l-indigo-500">
                        <div className="w-8 h-8 bg-indigo-50 rounded-lg flex items-center justify-center text-indigo-600 shrink-0">
                            <FileText size={16} />
                        </div>
                        <div>
                            <p className="text-slate-500 text-[10px] font-bold uppercase tracking-wider">Semestre</p>
                            <p className="text-[11px] font-bold text-slate-700 leading-none">{semestreFiltro}</p>
                        </div>
                    </div>
                </div>

                {/* Filters - Super Compact */}
                <div className="flex flex-col md:flex-row gap-2 mb-4 bg-white p-2 rounded-xl border border-gray-100 shadow-sm items-center">
                    <div className="relative flex-1 w-full">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                        <input
                            type="text"
                            placeholder="Pesquisar discente..."
                            className="w-full pl-9 pr-4 py-2 bg-slate-50 border-none rounded-lg focus:ring-1 focus:ring-[#0C4A6E] outline-none font-bold text-xs transition-all uppercase placeholder:normal-case text-slate-900"
                            value={search}
                            onChange={e => setSearch(e.target.value)}
                        />
                    </div>
                    <div className="relative w-full md:w-auto min-w-[150px]">
                        <select
                            className="w-full pl-3 pr-8 py-2 bg-slate-50 border-none rounded-lg focus:ring-1 focus:ring-[#0C4A6E] outline-none font-bold text-xs appearance-none cursor-pointer text-[#0C4A6E]"
                            value={semestreFiltro}
                            onChange={e => setSemestreFiltro(e.target.value)}
                        >
                            <option value="Todos">Todos</option>
                            {semestres.map(s => <option key={s} value={s}>{s}</option>)}
                        </select>
                        <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 text-[#0C4A6E] pointer-events-none" size={12} />
                    </div>
                </div>

                {/* Table - Optimized for Legibility */}
                <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden hidden lg:block">
                    <div className="overflow-x-auto">
                        <table className="w-full text-left border-collapse">
                            <thead>
                                <tr className="bg-slate-50 border-b border-slate-200">
                                    <th onClick={() => handleSort('dia')} className="px-4 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest cursor-pointer hover:text-[#0C4A6E] transition-colors border-r border-slate-200/60">
                                        Data {sortBy === 'dia' && (sortAsc ? "↑" : "↓")}
                                    </th>
                                    <th onClick={() => handleSort('discente')} className="px-4 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest cursor-pointer hover:text-[#0C4A6E] transition-colors border-r border-slate-200/60">
                                        Discente / Orientador {sortBy === 'discente' && (sortAsc ? "↑" : "↓")}
                                    </th>
                                    <th className="px-2 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center border-r border-slate-200/60">Docs</th>
                                    <th className="px-2 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center border-r border-slate-200/60">N.Ori</th>
                                    <th className="px-2 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center border-r border-slate-200/60">N.Av1</th>
                                    <th className="px-2 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center border-r border-slate-200/60">N.Av2</th>
                                    <th className="px-2 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center border-r border-slate-200/60">Média</th>
                                    <th className="px-2 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center border-r border-slate-200/60">TCC</th>
                                    <th className="px-2 py-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center">Termo</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-200">
                                {filteredDefesas.map((defesa) => {
                                    const n1 = getNotaFinal(defesa.id, 1)
                                    const n2 = getNotaFinal(defesa.id, 2)
                                    const n3 = getNotaFinal(defesa.id, 3)

                                    const valids = [n1, n2, n3].filter(n => n !== null) as number[]
                                    const media = valids.length > 0 ? valids.reduce((a, b) => a + b, 0) / valids.length : null

                                    return (
                                        <tr key={defesa.id} className="hover:bg-blue-50/50 transition-colors group even:bg-blue-50/50">
                                            <td className="px-4 py-2 whitespace-nowrap text-[11px] font-bold text-slate-600 border-r border-slate-200/60">
                                                {defesa.dia ? new Intl.DateTimeFormat('pt-BR').format(new Date(defesa.dia + 'T12:00:00')) : '--/--/--'}
                                            </td>
                                            <td className="px-4 py-2 border-r border-slate-200/60">
                                                <p className="text-[12px] font-bold text-slate-900 uppercase leading-tight group-hover:text-indigo-600 transition-colors">{defesa.discente}</p>
                                                <p className="text-[10px] font-medium text-slate-500 uppercase mt-0.5">{defesa.orientador || 'Sem orientador'}</p>
                                            </td>
                                            <td className="px-2 py-2 text-center border-r border-slate-200/60">
                                                <button
                                                    onClick={() => toggleDoc(defesa.id, 'doc_outros_devolvido', defesa.doc_outros_devolvido)}
                                                    disabled={userAccessLevel !== null && userAccessLevel < 3}
                                                    className={clsx(
                                                        "w-7 h-7 rounded-lg flex items-center justify-center mx-auto transition-all border",
                                                        defesa.doc_outros_devolvido ? "bg-emerald-50 text-emerald-600 border-emerald-100 shadow-sm" : "bg-white text-slate-200 border-slate-100 hover:text-emerald-300",
                                                        (userAccessLevel !== null && userAccessLevel < 3) && "cursor-not-allowed opacity-60"
                                                    )}
                                                >
                                                    <CheckCircle2 size={14} />
                                                </button>
                                            </td>
                                            <td className="px-2 py-2 text-center border-r border-slate-200/60">
                                                <span className={clsx("text-[11px] font-bold font-mono", n1 !== null ? "text-slate-900" : "text-slate-200")}>
                                                    {n1 !== null ? n1.toFixed(1) : '-'}
                                                </span>
                                            </td>
                                            <td className="px-2 py-2 text-center border-r border-slate-200/60">
                                                <span className={clsx("text-[11px] font-bold font-mono", n2 !== null ? "text-slate-900" : "text-slate-200")}>
                                                    {n2 !== null ? n2.toFixed(1) : '-'}
                                                </span>
                                            </td>
                                            <td className="px-2 py-2 text-center border-r border-slate-200/60">
                                                <span className={clsx("text-[11px] font-bold font-mono", n3 !== null ? "text-slate-900" : "text-slate-200")}>
                                                    {n3 !== null ? n3.toFixed(1) : '-'}
                                                </span>
                                            </td>
                                            <td className="px-2 py-2 text-center border-r border-slate-200/60">
                                                <div className={clsx(
                                                    "inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold shadow-sm border",
                                                    media === null ? "bg-slate-50 text-slate-300 border-slate-100" : (media >= 7 ? "bg-blue-50 text-blue-700 border-blue-100" : "bg-red-50 text-red-700 border-red-100")
                                                )}>
                                                    {media !== null ? media.toFixed(1) : '--'}
                                                </div>
                                            </td>
                                            <td className="px-2 py-2 text-center border-r border-slate-200/60">
                                                <button
                                                    onClick={() => toggleDoc(defesa.id, 'doc_tcc_devolvido', defesa.doc_tcc_devolvido)}
                                                    disabled={userAccessLevel !== null && userAccessLevel < 3}
                                                    className={clsx(
                                                        "w-7 h-7 rounded-lg flex items-center justify-center mx-auto transition-all border",
                                                        defesa.doc_tcc_devolvido ? "bg-indigo-50 text-indigo-600 border-indigo-100 shadow-sm" : "bg-white text-slate-200 border-slate-100 hover:text-indigo-300",
                                                        (userAccessLevel !== null && userAccessLevel < 3) && "cursor-not-allowed opacity-60"
                                                    )}
                                                >
                                                    <CheckCircle2 size={14} />
                                                </button>
                                            </td>
                                            <td className="px-2 py-2 text-center">
                                                <button
                                                    onClick={() => toggleDoc(defesa.id, 'doc_termo_devolvido', defesa.doc_termo_devolvido)}
                                                    disabled={userAccessLevel !== null && userAccessLevel < 3}
                                                    className={clsx(
                                                        "w-7 h-7 rounded-lg flex items-center justify-center mx-auto transition-all border",
                                                        defesa.doc_termo_devolvido ? "bg-violet-50 text-violet-600 border-violet-100 shadow-sm" : "bg-white text-slate-200 border-slate-100 hover:text-violet-300",
                                                        (userAccessLevel !== null && userAccessLevel < 3) && "cursor-not-allowed opacity-60"
                                                    )}
                                                >
                                                    <CheckCircle2 size={14} />
                                                </button>
                                            </td>
                                        </tr>
                                    )
                                })}
                            </tbody>
                        </table>
                    </div>
                </div>

                {/* Mobile Cards View */}
                <div className="lg:hidden space-y-3">
                    {filteredDefesas.map((defesa) => {
                        const n1 = getNotaFinal(defesa.id, 1)
                        const n2 = getNotaFinal(defesa.id, 2)
                        const n3 = getNotaFinal(defesa.id, 3)
                        const valids = [n1, n2, n3].filter(n => n !== null) as number[]
                        const media = valids.length > 0 ? valids.reduce((a, b) => a + b, 0) / valids.length : null

                        return (
                            <div key={defesa.id} className="bg-white p-4 rounded-3xl border border-gray-100 shadow-sm space-y-3">
                                <div className="flex justify-between items-start">
                                    <div className="flex-1 min-w-0">
                                        <h3 className="text-[11px] font-black text-slate-900 uppercase">{defesa.discente}</h3>
                                        <p className="text-[9px] font-bold text-gray-400 uppercase mt-0.5">{defesa.orientador}</p>
                                    </div>
                                    <div className={clsx(
                                        "px-2 py-0.5 rounded-md text-[10px] font-black italic",
                                        media === null ? "bg-gray-100 text-gray-300" : (media >= 7 ? "bg-[#E0F2FE] text-[#0369A1]" : "bg-red-50 text-red-700")
                                    )}>
                                        {media !== null ? media.toFixed(1) : '--'}
                                    </div>
                                </div>
                                <div className="grid grid-cols-3 gap-1.5">
                                    <div className="text-center bg-gray-50 p-1.5 rounded-lg">
                                        <p className="text-[7px] font-black text-gray-400 uppercase">N.Ori</p>
                                        <p className="text-[10px] font-black text-slate-600">{n1 !== null ? n1.toFixed(1) : '-'}</p>
                                    </div>
                                    <div className="text-center bg-gray-50 p-1.5 rounded-lg">
                                        <p className="text-[7px] font-black text-gray-400 uppercase">N.Av1</p>
                                        <p className="text-[10px] font-black text-slate-600">{n2 !== null ? n2.toFixed(1) : '-'}</p>
                                    </div>
                                    <div className="text-center bg-gray-50 p-1.5 rounded-lg">
                                        <p className="text-[7px] font-black text-gray-400 uppercase">N.Av2</p>
                                        <p className="text-[10px] font-black text-slate-600">{n3 !== null ? n3.toFixed(1) : '-'}</p>
                                    </div>
                                </div>
                                <div className="flex items-center justify-between pt-2 border-t border-gray-50">
                                    <div className="flex gap-3">
                                        <div className="flex flex-col items-center gap-0.5">
                                            <button
                                                onClick={() => toggleDoc(defesa.id, 'doc_outros_devolvido', defesa.doc_outros_devolvido)}
                                                disabled={userAccessLevel !== null && userAccessLevel < 3}
                                                className={clsx(
                                                    "w-7 h-7 rounded-lg flex items-center justify-center transition-all border",
                                                    defesa.doc_outros_devolvido ? "bg-emerald-50 text-emerald-600 border-emerald-100" : "bg-white text-gray-200",
                                                    (userAccessLevel !== null && userAccessLevel < 3) && "cursor-not-allowed opacity-60"
                                                )}
                                            >
                                                <CheckCircle2 size={12} />
                                            </button>
                                            <span className="text-[7px] font-black text-gray-400 uppercase">Docs</span>
                                        </div>
                                        <div className="flex flex-col items-center gap-0.5">
                                            <button
                                                onClick={() => toggleDoc(defesa.id, 'doc_tcc_devolvido', defesa.doc_tcc_devolvido)}
                                                disabled={userAccessLevel !== null && userAccessLevel < 3}
                                                className={clsx(
                                                    "w-7 h-7 rounded-lg flex items-center justify-center transition-all border",
                                                    defesa.doc_tcc_devolvido ? "bg-blue-50 text-blue-600 border-blue-100" : "bg-white text-gray-200",
                                                    (userAccessLevel !== null && userAccessLevel < 3) && "cursor-not-allowed opacity-60"
                                                )}
                                            >
                                                <CheckCircle2 size={12} />
                                            </button>
                                            <span className="text-[7px] font-black text-gray-400 uppercase">TCC</span>
                                        </div>
                                        <div className="flex flex-col items-center gap-0.5">
                                            <button
                                                onClick={() => toggleDoc(defesa.id, 'doc_termo_devolvido', defesa.doc_termo_devolvido)}
                                                disabled={userAccessLevel !== null && userAccessLevel < 3}
                                                className={clsx(
                                                    "w-7 h-7 rounded-lg flex items-center justify-center transition-all border",
                                                    defesa.doc_termo_devolvido ? "bg-purple-50 text-purple-600 border-purple-100" : "bg-white text-gray-200",
                                                    (userAccessLevel !== null && userAccessLevel < 3) && "cursor-not-allowed opacity-60"
                                                )}
                                            >
                                                <CheckCircle2 size={12} />
                                            </button>
                                            <span className="text-[7px] font-black text-gray-400 uppercase">Termo</span>
                                        </div>
                                    </div>
                                    <div className="text-right">
                                        <p className="text-[8px] font-black text-gray-300 uppercase italic">
                                            {defesa.dia ? new Intl.DateTimeFormat('pt-BR').format(new Date(defesa.dia + 'T12:00:00')) : '--/--/--'}
                                        </p>
                                    </div>
                                </div>
                            </div>
                        )
                    })}
                </div>

                {filteredDefesas.length === 0 && !loading && (
                    <div className="text-center py-10 bg-white rounded-3xl mt-4 border border-dashed border-gray-200">
                        <Search className="mx-auto text-gray-200 mb-2" size={32} />
                        <p className="text-gray-400 font-bold uppercase tracking-widest text-[10px]">Nenhuma banca encontrada</p>
                    </div>
                )}
            </main>
        </div>
    )
}
