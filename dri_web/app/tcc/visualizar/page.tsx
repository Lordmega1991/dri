'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Search,
    ChevronDown,
    RefreshCw,
    GraduationCap,
    Clock,
    PlusCircle,
    X,
    ChevronRight,
    Info,
    Loader2,
    Calendar,
    ChevronUp,
    User,
    CheckCircle,
    Grid,
    FileText,
    MapPin,
    XCircle,
    Edit,
    Trash2,
    Share2,
    Award,
    Mic
} from 'lucide-react'
import clsx from 'clsx'
import {
    generateAta, generateCertificado, generateFichaIndividual,
    generateFolhaAprovacao, generateFichaFinal
} from '@/lib/tcc-pdf';
import Head from 'next/head'

type Defesa = {
    id: number
    semestre: string
    dia: string | null
    hora: string | null
    discente: string
    titulo: string | null
    orientador: string | null
    coorientador: string | null
    avaliador1: string | null
    avaliador2: string | null
    avaliador3: string | null
    local: string | null
    doc_tcc_devolvido: boolean
    doc_termo_devolvido: boolean
    doc_outros_devolvido: boolean
}

const SEARCH_FIELDS = [
    { label: 'SEMESTRE', key: 'semestre', icon: Grid },
    { label: 'DIA', key: 'dia', icon: Calendar },
    { label: 'DISCENTE', key: 'discente', icon: User },
    { label: 'ORIENTADOR', key: 'orientador', icon: User },
    { label: 'COORIENTADOR', key: 'coorientador', icon: User },
    { label: 'AVALIADOR1', key: 'avaliador1', icon: User },
    { label: 'AVALIADOR2', key: 'avaliador2', icon: User },
    { label: 'AVALIADOR3', key: 'avaliador3', icon: User },
    { label: 'TITULO', key: 'titulo', icon: FileText },
    { label: 'LOCAL', key: 'local', icon: MapPin },
]

export default function VisualizarDefesasPage() {
    const router = useRouter()
    const [defesas, setDefesas] = useState<Defesa[]>([])
    const [loading, setLoading] = useState(true)
    const [semestres, setSemestres] = useState<string[]>([])

    // Filters
    const [filter1, setFilter1] = useState({ field: 'semestre', value: '' })
    const [filter2, setFilter2] = useState({ field: 'discente', value: '' })
    const [showMoreFilters, setShowMoreFilters] = useState(false)

    // Sort
    const [sortBy, setSortBy] = useState<'discente' | 'dia'>('discente')
    const [sortAsc, setSortAsc] = useState(true)

    const [selectedDefesa, setSelectedDefesa] = useState<Defesa | null>(null);
    const [generatingPdf, setGeneratingPdf] = useState(false);
    const [expandFichas, setExpandFichas] = useState(false);

    const fetchDefesas = async () => {
        setLoading(true)
        try {
            // 1. Fetch Defesas
            const { data: defesasData, error: defesasError } = await supabase.from('dados_defesas').select('*')
            if (defesasError) throw defesasError

            // 2. Fetch Semestres to find the official "Current"
            const { data: semestresData, error: semestresError } = await supabase
                .from('semestres')
                .select('*')
                .order('ano', { ascending: false })
                .order('semestre', { ascending: false })

            if (semestresError) throw semestresError

            if (defesasData) {
                setDefesas(defesasData)

                let currentLabel = ''
                const now = new Date()

                if (semestresData && semestresData.length > 0) {
                    const formatted = semestresData.map(s => {
                        const label = `${s.ano}.${s.semestre}`
                        const start = s.data_inicio ? new Date(s.data_inicio) : null
                        const end = s.data_fim ? new Date(s.data_fim) : null
                        const isCurrent = start && end ? (now >= start && now <= end) : false
                        if (isCurrent) currentLabel = label
                        return label
                    })

                    // If no semester is technically current by date, use the first one (most recent)
                    if (!currentLabel) currentLabel = formatted[0]

                    setSemestres(formatted)
                } else {
                    // Fallback calculation if table is empty
                    const year = now.getFullYear()
                    const month = now.getMonth() + 1
                    currentLabel = `${year}.${month <= 6 ? 1 : 2}`
                    setSemestres([currentLabel])
                }

                // Auto-select current semester ONLY on first load
                if (filter1.value === '') {
                    setFilter1(prev => ({ ...prev, value: currentLabel }))
                }
            }
        } catch (err) {
            console.error('Erro ao buscar dados:', err)
        } finally {
            setLoading(false)
        }
    }

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

            fetchDefesas()
        }
        checkAccess()
    }, [])

    const toggleDoc = async (id: number, campo: string, valorAtual: boolean) => {
        try {
            const { error } = await supabase
                .from('dados_defesas')
                .update({ [campo]: !valorAtual })
                .eq('id', id)

            if (error) throw error
            setDefesas(prev => prev.map(d => d.id === id ? { ...d, [campo]: !valorAtual } : d))
            if (selectedDefesa?.id === id) {
                setSelectedDefesa(prev => prev ? ({ ...prev, [campo]: !valorAtual }) : null)
            }
        } catch (err) {
            alert('Erro ao atualizar documento')
        }
    }

    const handleDelete = async (id: number, nome: string) => {
        if (!confirm(`Deseja realmente excluir a banca de ${nome}?`)) return
        setLoading(true)
        try {
            // Deletar notas relacionadas primeiro para evitar erro de chave estrangeira
            await supabase.from('notas').delete().eq('defesa_id', id)

            // Deletar dados finais se existirem
            await supabase.from('dados_defesa_final').delete().eq('defesa_id', id)

            // Por fim, deletar a defesa
            const { error } = await supabase.from('dados_defesas').delete().eq('id', id)

            if (error) throw error
            setDefesas(prev => prev.filter(d => d.id !== id))
            setSelectedDefesa(null)
            alert('Banca excluída com sucesso!')
        } catch (err) {
            console.error('Erro ao excluir banca:', err)
            alert('Erro ao excluir banca. Verifique se existem registros vinculados.')
        } finally {
            setLoading(false)
        }
    }

    const applyFilter = (defesa: Defesa, filter: { field: string, value: string }) => {
        if (!filter.value) return true
        const fieldVal = (defesa[filter.field as keyof Defesa] || '').toString().toLowerCase()
        const searchVal = filter.value.toLowerCase()

        // Exact match for semester to avoid partial matches like "2025.1" matching "2025.10"
        if (filter.field === 'semestre') return fieldVal === searchVal

        return fieldVal.includes(searchVal)
    }

    const filteredDefesas = defesas.filter(d => {
        const matches1 = applyFilter(d, filter1)
        const matches2 = showMoreFilters ? applyFilter(d, filter2) : true
        return matches1 && matches2
    }).sort((a, b) => {
        if (sortBy === 'discente') {
            return sortAsc ? a.discente.localeCompare(b.discente) : b.discente.localeCompare(a.discente)
        } else {
            const dateA = a.dia ? new Date(a.dia).getTime() : 0
            const dateB = b.dia ? new Date(b.dia).getTime() : 0
            return sortAsc ? dateA - dateB : dateB - dateA
        }
    })

    const toggleSort = (field: 'discente' | 'dia') => {
        if (sortBy === field) {
            setSortAsc(!sortAsc)
        } else {
            setSortBy(field)
            setSortAsc(true)
        }
    }

    const limparFiltros = () => {
        setFilter1({ ...filter1, value: '' })
        setFilter2({ ...filter2, value: '' })
        setShowMoreFilters(false)
    }

    const FilterInput = ({
        filter,
        onChange,
        semestres
    }: {
        filter: { field: string, value: string },
        onChange: (f: { field: string, value: string }) => void,
        semestres: string[]
    }) => {
        const activeField = SEARCH_FIELDS.find(f => f.key === filter.field) || SEARCH_FIELDS[0]
        const Icon = activeField.icon

        return (
            <div className="bg-white rounded-lg border border-blue-100 flex items-center h-10 shadow-sm relative overflow-hidden transition-all focus-within:border-blue-300">
                {/* Selector de Campo */}
                <div className="h-full px-3 flex items-center gap-2 border-r border-slate-100 bg-slate-50/50 min-w-[130px] relative hover:bg-slate-100 transition-colors">
                    <Icon size={14} className="text-[#0284C7]" />
                    <span className="text-[9px] font-black text-[#0C4A6E] uppercase tracking-wider">{activeField.label}</span>
                    <ChevronDown size={12} className="text-[#0C4A6E] ml-auto" />
                    <select
                        className="absolute inset-x-0 h-full opacity-0 cursor-pointer"
                        value={filter.field}
                        onChange={e => onChange({ field: e.target.value, value: '' })}
                    >
                        {SEARCH_FIELDS.map(f => <option key={f.key} value={f.key}>{f.label}</option>)}
                    </select>
                </div>

                {/* Área de Input/Seleção de Valor */}
                <div className="flex-1 h-full relative flex items-center">
                    {filter.field === 'dia' ? (
                        <input
                            type="date"
                            className="w-full h-full px-3 outline-none text-xs font-bold text-slate-700 uppercase cursor-pointer"
                            value={filter.value}
                            onChange={e => onChange({ ...filter, value: e.target.value })}
                        />
                    ) : filter.field === 'semestre' ? (
                        <div className="relative w-full h-full flex items-center">
                            <select
                                className="w-full h-full pl-3 pr-10 outline-none text-xs font-bold text-slate-700 uppercase appearance-none cursor-pointer bg-white"
                                value={filter.value}
                                onChange={e => onChange({ ...filter, value: e.target.value })}
                            >
                                <option value="">TODOS OS SEMESTRES</option>
                                {semestres.map(s => (
                                    <option key={s} value={s}>{s}</option>
                                ))}
                            </select>
                            <div className="absolute right-3 pointer-events-none text-[#0284C7]">
                                <ChevronDown size={14} />
                            </div>
                        </div>
                    ) : (
                        <input
                            type="text"
                            placeholder={`Buscar por ${activeField.label.toLowerCase()}...`}
                            className="w-full h-full px-3 outline-none text-xs font-bold text-slate-700 placeholder:text-slate-300 uppercase"
                            value={filter.value}
                            onChange={e => onChange({ ...filter, value: e.target.value })}
                        />
                    )}

                    {/* Botão de Limpar Valor */}
                    {filter.value && (
                        <button
                            onClick={() => onChange({ ...filter, value: '' })}
                            className={clsx(
                                "absolute p-1 hover:bg-slate-100 rounded-full text-slate-400 transition-all",
                                filter.field === 'semestre' || filter.field === 'dia' ? "right-10" : "right-3"
                            )}
                        >
                            <X size={14} />
                        </button>
                    )}
                </div>

                <div className="px-3 text-blue-300 pointer-events-none">
                    <Search size={16} />
                </div>
            </div>
        )
    }

    const handleGenerateAta = async () => {
        if (!selectedDefesa) return;
        setGeneratingPdf(true);
        try {
            await generateAta(selectedDefesa as any);
        } catch (error) {
            console.error(error);
            alert('Erro ao gerar Ata');
        } finally {
            setGeneratingPdf(false);
        }
    };

    const handleGenerateCertificados = async () => {
        if (!selectedDefesa) return;
        setGeneratingPdf(true);
        try {
            // Gera para o orientador
            await generateCertificado(selectedDefesa as any, selectedDefesa.orientador || '', 'orientador');
            // Gera para os avaliadores que existem
            if (selectedDefesa.avaliador1) await generateCertificado(selectedDefesa as any, selectedDefesa.avaliador1 || '', 'avaliador');
            if (selectedDefesa.avaliador2) await generateCertificado(selectedDefesa as any, selectedDefesa.avaliador2 || '', 'avaliador');
            if (selectedDefesa.avaliador3) await generateCertificado(selectedDefesa as any, selectedDefesa.avaliador3 || '', 'avaliador');
        } catch (error) {
            console.error(error);
            alert('Erro ao gerar Certificados');
        } finally {
            setGeneratingPdf(false);
        }
    };

    const handleGenerateApresentacao = async () => {
        if (!selectedDefesa) return;
        setGeneratingPdf(true);
        try {
            if (selectedDefesa.avaliador1) await generateFichaIndividual(selectedDefesa as any, 1);
            if (selectedDefesa.avaliador2) await generateFichaIndividual(selectedDefesa as any, 2);
            if (selectedDefesa.avaliador3) await generateFichaIndividual(selectedDefesa as any, 3);
        } catch (error) {
            console.error(error);
            alert('Erro ao gerar Fichas');
        } finally {
            setGeneratingPdf(false);
        }
    };

    const handleGenerateFolhaAprovacao = async () => {
        if (!selectedDefesa) return;
        setGeneratingPdf(true);
        try {
            await generateFolhaAprovacao(selectedDefesa as any);
        } catch (error) {
            console.error(error);
            alert('Erro ao gerar Folha de Aprovação');
        } finally {
            setGeneratingPdf(false);
        }
    };

    const handleGenerateFichaFinal = async () => {
        if (!selectedDefesa) return;
        setGeneratingPdf(true);
        try {
            await generateFichaFinal(selectedDefesa as any);
        } catch (error) {
            console.error(error);
            alert('Erro ao gerar Ficha Final');
        } finally {
            setGeneratingPdf(false);
        }
    };

    return (
        <div className="min-h-screen bg-[#FAFAFA] text-slate-700 antialiased" style={{ fontFamily: '"Plus Jakarta Sans", sans-serif' }}>
            <style jsx global>{`
                @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:ital,wght@0,200..800;1,200..800&display=swap');
            `}</style>
            {/* Header Área Azul (como no anexo) - REDUCED PADDING */}
            <div className="bg-[#E0F2FE] rounded-b-[2rem] shadow-sm pb-4">
                <div className="max-w-7xl mx-auto px-4 pt-4 flex items-center justify-between mb-4">
                    <div className="flex items-center gap-3">
                        <Link href="/tcc" className="w-8 h-8 bg-white rounded-lg shadow-sm flex items-center justify-center text-[#0C4A6E] hover:bg-slate-50 transition-colors">
                            <ArrowLeft size={16} />
                        </Link>
                        <div>
                            <h1 className="text-[#0C4A6E] text-base font-black italic">Defesas de TCC Cadastradas</h1>
                        </div>
                    </div>
                    <button onClick={fetchDefesas} className="w-8 h-8 bg-white rounded-lg shadow-sm flex items-center justify-center text-[#0C4A6E] hover:bg-slate-50 transition-colors">
                        <RefreshCw size={16} className={loading ? "animate-spin" : ""} />
                    </button>
                </div>

                {/* Filtros de Busca - COMPACT HEIGHT */}
                <div className="max-w-7xl mx-auto px-4 space-y-2">
                    {/* Filtro 01 */}
                    <FilterInput filter={filter1} onChange={setFilter1} semestres={semestres} />

                    {/* Filtro 02 (Condicional) */}
                    {showMoreFilters && (
                        <div className="animate-in fade-in slide-in-from-top-1 duration-200">
                            <FilterInput filter={filter2} onChange={setFilter2} semestres={semestres} />
                        </div>
                    )}

                    <div className="flex items-center justify-center gap-4 pt-1">
                        <button
                            onClick={() => setShowMoreFilters(!showMoreFilters)}
                            className="flex items-center gap-1.5 text-[10px] font-black text-[#0369A1] uppercase tracking-tight hover:underline"
                        >
                            {showMoreFilters ? <X size={12} /> : <PlusCircle size={12} />}
                            {showMoreFilters ? "Menos" : "Mais Filtros"}
                        </button>
                        <button
                            onClick={limparFiltros}
                            className="flex items-center gap-1.5 text-[10px] font-black text-red-600 uppercase tracking-tight hover:underline"
                        >
                            <X size={12} />
                            Limpar
                        </button>
                    </div>

                    {/* Barra de Status e Ordenação INSIDE - COMPACT */}
                    <div className="flex flex-wrap items-center justify-between gap-2 pt-3 border-t border-blue-200/50">
                        <div className="bg-[#0C4A6E]/10 border border-[#0C4A6E]/5 px-3 py-1 rounded-full flex items-center gap-1.5">
                            <Info size={12} className="text-[#0C4A6E]" />
                            <span className="text-[9px] font-black text-[#0C4A6E] uppercase tracking-tighter">TOTAL: {filteredDefesas.length}</span>
                        </div>

                        <div className="flex items-center gap-2">
                            <span className="text-[8px] font-black text-[#0369A1] uppercase tracking-widest opacity-60 hidden xs:block">ORDEM:</span>
                            <div className="flex bg-white rounded-lg p-0.5 border border-blue-100 shadow-sm">
                                <button
                                    onClick={() => toggleSort('discente')}
                                    className={clsx(
                                        "px-3 py-1 rounded-md text-[8px] font-black transition-all uppercase tracking-tighter",
                                        sortBy === 'discente' ? "bg-[#0C4A6E] text-white" : "text-slate-400"
                                    )}
                                >
                                    NOME {sortBy === 'discente' && (sortAsc ? "↑" : "↓")}
                                </button>
                                <button
                                    onClick={() => toggleSort('dia')}
                                    className={clsx(
                                        "px-3 py-1 rounded-md text-[8px] font-black transition-all uppercase tracking-tighter",
                                        sortBy === 'dia' ? "bg-[#0C4A6E] text-white" : "text-slate-400"
                                    )}
                                >
                                    DATA {sortBy === 'dia' && (sortAsc ? "↑" : "↓")}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <main className="max-w-7xl mx-auto px-4 py-4">
                {/* Lista de Defesas - COMPACT CARDS */}
                {loading ? (
                    <div className="flex flex-col items-center justify-center py-10 text-slate-300">
                        <Loader2 className="animate-spin mb-2" size={24} />
                        <p className="text-[10px] font-black uppercase tracking-[2px]">Carregando...</p>
                    </div>
                ) : filteredDefesas.length === 0 ? (
                    <div className="text-center py-16 bg-white rounded-2xl border border-dashed border-slate-200">
                        <Search className="mx-auto mb-2 text-slate-200" size={32} />
                        <h3 className="text-sm font-bold text-slate-900">Nenhum resultado</h3>
                    </div>
                ) : (
                    <div className="space-y-1.5">
                        {filteredDefesas.map((defesa) => (
                            <button
                                key={defesa.id}
                                onClick={() => setSelectedDefesa(defesa)}
                                className="w-full flex items-center bg-white rounded-xl p-2.5 border border-slate-50 shadow-sm hover:shadow-md hover:border-blue-100 transition-all group text-left"
                            >
                                <div className="w-9 h-9 rounded-full bg-[#E0F2FE] flex items-center justify-center text-[#0284C7] shrink-0 mr-3 group-hover:bg-[#0284C7] group-hover:text-white transition-all">
                                    <GraduationCap size={16} />
                                </div>

                                <div className="flex-1 min-w-0">
                                    <h3 className="text-[13px] font-black text-[#0C4A6E] uppercase leading-tight group-hover:text-blue-600 transition-colors truncate">
                                        {defesa.discente}
                                    </h3>
                                    <div className="flex items-center text-[9px] font-bold mt-0.5 truncate">
                                        <div className="flex items-center text-[#0284C7] bg-[#E0F2FE]/50 px-1.5 py-0.5 rounded">
                                            <Calendar size={10} className="mr-1" />
                                            {defesa.dia ? new Intl.DateTimeFormat('pt-BR').format(new Date(defesa.dia + 'T12:00:00')) : 'A DEFINIR'}
                                        </div>
                                        <div className="mx-1.5 w-0.5 h-0.5 bg-slate-200 rounded-full" />
                                        <div className="flex items-center text-slate-400 uppercase tracking-tight truncate">
                                            <User size={10} className="mr-1 text-slate-300" />
                                            {defesa.orientador || 'N/A'}
                                        </div>
                                    </div>
                                </div>

                                <div className="flex items-center gap-2 shrink-0">
                                    <div className="hidden sm:flex items-center gap-1 text-[9px] font-black text-slate-400 bg-slate-50 px-1.5 py-0.5 rounded border border-slate-100 uppercase">
                                        {defesa.semestre}
                                    </div>
                                    <ChevronRight size={16} className="text-slate-300 group-hover:text-blue-500 group-hover:translate-x-0.5 transition-all" />
                                </div>
                            </button>
                        ))}
                    </div>
                )}
            </main>

            {/* MODAL DE DETALHES (POP-UP) */}
            {selectedDefesa && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-in fade-in duration-200">
                    <div className="bg-white w-full max-w-lg rounded-[2.5rem] shadow-2xl overflow-hidden border border-slate-100 flex flex-col max-h-[90vh] animate-in zoom-in-95 duration-200">
                        {/* Modal Header */}
                        <div className="bg-[#E0F2FE] p-6 pb-12 relative">
                            <button
                                onClick={() => setSelectedDefesa(null)}
                                className="absolute right-6 top-6 w-8 h-8 rounded-full bg-white/50 flex items-center justify-center text-[#0C4A6E] hover:bg-white transition-all"
                            >
                                <X size={16} />
                            </button>
                            <div className="flex items-center gap-3 mb-2">
                                <span className="bg-[#0C4A6E] text-white px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-widest">
                                    {selectedDefesa.semestre}
                                </span>
                                <span className="text-[#0284C7] text-[10px] font-bold flex items-center gap-1">
                                    <Clock size={12} />
                                    {selectedDefesa.hora ? (selectedDefesa.hora.length > 5 ? selectedDefesa.hora.substring(0, 5) : selectedDefesa.hora) : '--:--'}
                                </span>
                            </div>
                            <h2 className="text-[#0C4A6E] text-xl font-black uppercase leading-tight italic">
                                {selectedDefesa.discente}
                            </h2>
                        </div>

                        {/* Modal Body */}
                        <div className="flex-1 overflow-y-auto p-6 -mt-6 bg-white rounded-t-[2rem]">
                            <div className="space-y-6">
                                {/* Título e Info Principal */}
                                <section className="space-y-4">
                                    <div className="bg-slate-50 rounded-2xl p-4 border border-slate-100">
                                        <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-1.5">Título do Trabalho</p>
                                        <p className="text-xs font-bold text-slate-700 leading-relaxed italic">
                                            &quot;{selectedDefesa.titulo || 'TÍTULO NÃO INFORMADO'}&quot;
                                        </p>
                                    </div>

                                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                                        <div className="flex items-center gap-3 bg-slate-50 p-3 rounded-xl border border-slate-100">
                                            <MapPin size={16} className="text-blue-400" />
                                            <div>
                                                <p className="text-[8px] font-black text-slate-400 uppercase">Local</p>
                                                <p className="text-xs font-bold text-slate-700">{selectedDefesa.local || 'A DEFINIR'}</p>
                                            </div>
                                        </div>
                                        <div className="flex items-center gap-3 bg-slate-50 p-3 rounded-xl border border-slate-100">
                                            <Calendar size={16} className="text-blue-400" />
                                            <div>
                                                <p className="text-[8px] font-black text-slate-400 uppercase">Data</p>
                                                <p className="text-xs font-bold text-slate-700">
                                                    {selectedDefesa.dia ? new Intl.DateTimeFormat('pt-BR').format(new Date(selectedDefesa.dia + 'T12:00:00')) : 'A DEFINIR'}
                                                </p>
                                            </div>
                                        </div>
                                    </div>
                                </section>

                                {/* Banca Examinadora */}
                                <section className="space-y-3">
                                    <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-2">
                                        <div className="h-px flex-1 bg-slate-100" />
                                        Banca Examinadora
                                        <div className="h-px flex-1 bg-slate-100" />
                                    </h4>
                                    <div className="space-y-2">
                                        {[
                                            { label: 'Orientador', value: selectedDefesa.orientador },
                                            { label: 'Coorientador', value: selectedDefesa.coorientador },
                                            { label: 'Avaliador 1', value: selectedDefesa.avaliador1 },
                                            { label: 'Avaliador 2', value: selectedDefesa.avaliador2 },
                                            { label: 'Avaliador 3', value: selectedDefesa.avaliador3 },
                                        ].filter(b => b.value).map((mem, idx) => (
                                            <div key={idx} className="flex items-center justify-between p-2.5 bg-white border border-slate-100 rounded-xl hover:bg-blue-50/30 transition-colors">
                                                <span className="text-[9px] font-black text-[#0284C7] uppercase">{mem.label}</span>
                                                <span className="text-[11px] font-bold text-slate-700">{mem.value}</span>
                                            </div>
                                        ))}
                                    </div>
                                </section>



                                {/* Documentos Acadêmicos (Estilo Flutter) */}
                                <section className="space-y-3">
                                    <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-2">
                                        <div className="h-px flex-1 bg-slate-100" />
                                        Documentos Acadêmicos
                                        <div className="h-px flex-1 bg-slate-100" />
                                    </h4>

                                    <div className="space-y-2">
                                        {/* Ata de Defesa */}
                                        <button
                                            onClick={handleGenerateAta}
                                            disabled={generatingPdf}
                                            className="w-full flex items-center gap-4 bg-blue-50/50 p-4 rounded-2xl border border-blue-100/50 hover:bg-blue-50 transition-all group"
                                        >
                                            <div className="w-10 h-10 bg-blue-100 rounded-xl flex items-center justify-center text-blue-600 group-hover:scale-110 transition-transform">
                                                {generatingPdf ? <Loader2 size={20} className="animate-spin" /> : <FileText size={20} />}
                                            </div>
                                            <span className="text-[11px] font-black text-blue-700 uppercase tracking-wider">Ata Defesa</span>
                                        </button>

                                        {/* Folha de Aprovação */}
                                        <button
                                            onClick={handleGenerateFolhaAprovacao}
                                            disabled={generatingPdf}
                                            className="w-full flex items-center gap-4 bg-indigo-50/50 p-4 rounded-2xl border border-indigo-100/50 hover:bg-indigo-50 transition-all group"
                                        >
                                            <div className="w-10 h-10 bg-indigo-100 rounded-xl flex items-center justify-center text-indigo-600 group-hover:scale-110 transition-transform">
                                                {generatingPdf ? <Loader2 size={20} className="animate-spin" /> : <CheckCircle size={20} />}
                                            </div>
                                            <span className="text-[11px] font-black text-indigo-700 uppercase tracking-wider">Aprovação</span>
                                        </button>

                                        {/* Ficha Final */}
                                        <button
                                            onClick={handleGenerateFichaFinal}
                                            disabled={generatingPdf}
                                            className="w-full flex items-center gap-4 bg-orange-50/50 p-4 rounded-2xl border border-orange-100/50 hover:bg-orange-50 transition-all group"
                                        >
                                            <div className="w-10 h-10 bg-orange-100 rounded-xl flex items-center justify-center text-orange-600 group-hover:scale-110 transition-transform">
                                                {generatingPdf ? <Loader2 size={20} className="animate-spin" /> : <Grid size={20} />}
                                            </div>
                                            <span className="text-[11px] font-black text-orange-700 uppercase tracking-wider">Ficha Final</span>
                                        </button>

                                        {/* Fichas Individuais - Expandable */}
                                        <div className="space-y-2">
                                            <button
                                                onClick={() => setExpandFichas(!expandFichas)}
                                                className={clsx(
                                                    "w-full flex items-center justify-between bg-emerald-50/50 p-4 rounded-2xl border transition-all group",
                                                    expandFichas ? "border-emerald-300 bg-emerald-50" : "border-emerald-100/50 hover:bg-emerald-50"
                                                )}
                                            >
                                                <div className="flex items-center gap-4">
                                                    <div className="w-10 h-10 bg-emerald-100 rounded-xl flex items-center justify-center text-emerald-600 group-hover:scale-110 transition-transform">
                                                        <Mic size={20} />
                                                    </div>
                                                    <span className="text-[11px] font-black text-emerald-700 uppercase tracking-wider">Fichas Indiv.</span>
                                                </div>
                                                <div className={clsx("transition-transform duration-200 text-emerald-400", expandFichas ? "rotate-180" : "")}>
                                                    <ChevronDown size={18} />
                                                </div>
                                            </button>

                                            {expandFichas && (
                                                <div className="grid grid-cols-1 gap-1.5 pl-4 pr-1 py-1 animate-in slide-in-from-top-2 duration-200">
                                                    {[
                                                        { label: 'Orientador', index: 1, name: selectedDefesa.orientador },
                                                        { label: 'Membro 1', index: 2, name: selectedDefesa.avaliador2 },
                                                        { label: 'Membro 2', index: 3, name: selectedDefesa.avaliador3 },
                                                    ].filter(m => m.name).map((m) => (
                                                        <button
                                                            key={m.index}
                                                            disabled={generatingPdf}
                                                            onClick={async () => {
                                                                setGeneratingPdf(true);
                                                                try {
                                                                    await generateFichaIndividual(selectedDefesa as any, m.index);
                                                                } finally {
                                                                    setGeneratingPdf(false);
                                                                }
                                                            }}
                                                            className="w-full flex items-center justify-between p-3 bg-white border border-emerald-100 rounded-xl hover:bg-emerald-50 transition-colors group/sub"
                                                        >
                                                            <div className="flex flex-col items-start">
                                                                <span className="text-[8px] font-black text-emerald-400 uppercase tracking-[1px]">{m.label}</span>
                                                                <span className="text-[10px] font-bold text-slate-600 truncate max-w-[180px]">{m.name}</span>
                                                                {generatingPdf && <Loader2 size={12} className="animate-spin text-emerald-500 mt-1" />}
                                                            </div>
                                                            <FileText size={16} className="text-emerald-300 group-hover/sub:text-emerald-500 transition-colors" />
                                                        </button>
                                                    ))}
                                                </div>
                                            )}
                                        </div>

                                        {/* Dados Finais (Navegação) */}
                                        <Link
                                            href={`/defesas/dados-finais?id=${selectedDefesa.id}`}
                                            className="w-full flex items-center gap-4 bg-purple-50/50 p-4 rounded-2xl border border-purple-100/50 hover:bg-purple-50 transition-all group"
                                        >
                                            <div className="w-10 h-10 bg-purple-100 rounded-xl flex items-center justify-center text-purple-600 group-hover:scale-110 transition-transform">
                                                <Edit size={20} />
                                            </div>
                                            <span className="text-[11px] font-black text-purple-700 uppercase tracking-wider">Dados Finais</span>
                                        </Link>

                                        {/* Certificados (Extra) */}
                                        <button
                                            onClick={handleGenerateCertificados}
                                            disabled={generatingPdf}
                                            className="w-full flex items-center gap-4 bg-amber-50/50 p-4 rounded-2xl border border-amber-100/50 hover:bg-amber-50 transition-all group"
                                        >
                                            <div className="w-10 h-10 bg-amber-100 rounded-xl flex items-center justify-center text-amber-600 group-hover:scale-110 transition-transform">
                                                {generatingPdf ? <Loader2 size={20} className="animate-spin" /> : <Award size={20} />}
                                            </div>
                                            <span className="text-[11px] font-black text-amber-700 uppercase tracking-wider">Certificados</span>
                                        </button>
                                    </div>
                                </section>

                                {/* Outras Ações */}
                                <section className="space-y-3">
                                    <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-2">
                                        <div className="h-px flex-1 bg-slate-100" />
                                        Outras Ações
                                        <div className="h-px flex-1 bg-slate-100" />
                                    </h4>
                                    <div className="grid grid-cols-1 gap-3">
                                        <button
                                            onClick={() => {
                                                const link = `${window.location.origin}/defesas/avaliar?id=${selectedDefesa.id}`
                                                navigator.clipboard.writeText(link)
                                                alert('Link de avaliação copiado!')
                                            }}
                                            className="flex items-center justify-center gap-2 bg-slate-50 text-slate-600 px-4 py-3 rounded-xl border border-slate-100 text-[10px] font-black uppercase hover:bg-slate-100 transition-all"
                                        >
                                            <Share2 size={16} />
                                            Copiar Link de Avaliação
                                        </button>
                                    </div>
                                </section>
                            </div>
                        </div>

                        {/* Modal Footer (Actions) */}
                        <div className="p-6 bg-slate-50 border-t border-slate-100 flex items-center gap-3">
                            <Link
                                href={`/defesas/avaliar?id=${selectedDefesa.id}`}
                                className="flex-1 bg-[#0C4A6E] text-white py-3 rounded-2xl text-[10px] font-black uppercase tracking-widest flex items-center justify-center gap-2 shadow-lg shadow-blue-100 hover:bg-[#0284C7] transition-all"
                            >
                                <Edit size={14} />
                                Lançar Notas
                            </Link>
                            <Link
                                href={`/tcc/editar?id=${selectedDefesa.id}`}
                                className="w-12 h-12 flex items-center justify-center bg-white border border-slate-200 rounded-2xl text-slate-400 hover:text-blue-600 hover:border-blue-200 transition-all shadow-sm"
                                title="Editar Cadastro"
                            >
                                <FileText size={20} />
                            </Link>
                            <button
                                onClick={() => handleDelete(selectedDefesa.id, selectedDefesa.discente)}
                                className="w-12 h-12 flex items-center justify-center bg-white border border-red-100 rounded-2xl text-red-300 hover:text-red-500 hover:bg-red-50 transition-all shadow-sm"
                                title="Excluir Banca"
                            >
                                <Trash2 size={20} />
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}
