'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Search,
    PlusCircle,
    Calendar,
    User,
    FileText,
    Clock,
    Filter,
    X,
    Check
} from 'lucide-react'
import clsx from 'clsx'

type Atividade = {
    id: string
    docente_id: string
    semestre_id: string
    tipo_atividade_id: string
    descricao: string
    quantidade: number
    data_inicio: string | null
    data_fim: string | null
    observacoes: string | null
    created_at: string

    // Joined tables
    docentes: { nome: string }
    semestres: { ano: number, semestre: number }
    tipos_atividade: { nome: string, categoria: string, unidade_medida: string }
}

export default function LancarAtividadesPage() {
    const router = useRouter()
    const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)
    const [loading, setLoading] = useState(true)

    // Data lists
    const [atividades, setAtividades] = useState<Atividade[]>([])
    const [filteredAtividades, setFilteredAtividades] = useState<Atividade[]>([])
    const [docentes, setDocentes] = useState<any[]>([])
    const [semestres, setSemestres] = useState<any[]>([])
    const [tiposAtividade, setTiposAtividade] = useState<any[]>([])

    // Filters
    const [search, setSearch] = useState('')
    const [selectedSemestre, setSelectedSemestre] = useState<string>('')

    // Form State
    const [isCreating, setIsCreating] = useState(false)
    const [formDocente, setFormDocente] = useState('')
    const [formSemestre, setFormSemestre] = useState('')
    const [formTipo, setFormTipo] = useState('')
    const [formQtd, setFormQtd] = useState('')
    const [formInicio, setFormInicio] = useState('')
    const [formFim, setFormFim] = useState('')
    const [formObs, setFormObs] = useState('')

    useEffect(() => {
        const checkAccess = async () => {
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) {
                router.push('/login')
                return
            }

            // Check Access Level
            const { data: accessData } = await supabase
                .from('users_access')
                .select('access_level')
                .eq('id', session.user.id)
                .single()

            const level = accessData?.access_level || 0

            if (level < 2) {
                router.push('/')
                return
            }

            setUserAccessLevel(level)
            fetchData()
        }
        checkAccess()
    }, [router])

    const fetchData = async () => {
        setLoading(true)
        try {
            // Fetch dropdown data
            const [docentesRes, semestresRes, tiposRes] = await Promise.all([
                supabase.from('docentes').select('id, nome').order('nome'),
                supabase.from('semestres').select('id, ano, semestre').order('ano', { ascending: false }).order('semestre', { ascending: false }),
                supabase.from('tipos_atividade').select('*').order('nome')
            ])

            if (docentesRes.data) setDocentes(docentesRes.data)
            if (semestresRes.data) {
                setSemestres(semestresRes.data)
                // Default to latest semester
                if (semestresRes.data.length > 0) {
                    setSelectedSemestre(semestresRes.data[0].id)
                    setFormSemestre(semestresRes.data[0].id)
                }
            }
            if (tiposRes.data) setTiposAtividade(tiposRes.data)

            // Fetch Atividades
            fetchAtividades()

        } catch (error) {
            console.error('Erro ao carregar dados:', error)
        } finally {
            setLoading(false)
        }
    }

    const fetchAtividades = async () => {
        try {
            const { data, error } = await supabase
                .from('atividades_docentes')
                .select(`
                    *,
                    docentes (nome),
                    semestres (ano, semestre),
                    tipos_atividade (nome, categoria, unidade_medida)
                `)
                .order('created_at', { ascending: false })

            if (error) throw error
            if (data) {
                setAtividades(data as any)
                setFilteredAtividades(data as any)
            }
        } catch (error) {
            console.error('Erro ao buscar atividades:', error)
        }
    }

    // Filters Effect
    useEffect(() => {
        let filtered = atividades

        if (selectedSemestre) {
            filtered = filtered.filter(a => a.semestre_id.toString() === selectedSemestre.toString())
        }

        if (search.trim()) {
            const lowerSearch = search.toLowerCase()
            filtered = filtered.filter(a =>
                a.docentes?.nome.toLowerCase().includes(lowerSearch) ||
                a.tipos_atividade?.nome.toLowerCase().includes(lowerSearch) ||
                (a.observacoes && a.observacoes.toLowerCase().includes(lowerSearch))
            )
        }

        setFilteredAtividades(filtered)
    }, [search, selectedSemestre, atividades])


    const handleCreate = async () => {
        if (!formDocente || !formSemestre || !formTipo || !formQtd) {
            alert('Preencha os campos obrigatórios: Docente, Semestre, Tipo e Quantidade.')
            return
        }

        try {
            const tipo = tiposAtividade.find(t => t.id.toString() === formTipo)

            const payload = {
                docente_id: formDocente,
                semestre_id: formSemestre,
                tipo_atividade_id: formTipo,
                descricao: tipo?.nome, // Store historical name
                quantidade: parseFloat(formQtd),
                data_inicio: formInicio || null,
                data_fim: formFim || null,
                observacoes: formObs || null,
                status: 'aprovado'
            }

            const { error } = await supabase
                .from('atividades_docentes')
                .insert(payload)

            if (error) throw error

            setIsCreating(false)
            fetchAtividades()

            // Reset crucial form fields but keep context (semester)
            setFormDocente('')
            setFormTipo('')
            setFormQtd('')
            setFormInicio('')
            setFormFim('')
            setFormObs('')

        } catch (error) {
            console.error('Erro ao salvar atividade:', error)
            alert('Erro ao salvar atividade.')
        }
    }

    const handleDelete = async (id: string) => {
        if (!confirm('Excluir este lançamento de atividade?')) return

        try {
            const { error } = await supabase
                .from('atividades_docentes')
                .delete()
                .eq('id', id)

            if (error) throw error

            setAtividades(prev => prev.filter(a => a.id !== id))
        } catch (error) {
            console.error('Erro ao excluir:', error)
            alert('Erro ao excluir.')
        }
    }

    const getSemestreLabel = (id: string) => {
        const s = semestres.find(s => s.id.toString() === id.toString())
        return s ? `${s.ano}.${s.semestre}` : '?'
    }

    if (loading) return null

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-slate-800 font-sans">
            <header className="bg-white border-b border-slate-200 py-3 px-4 sticky top-0 z-10 shadow-sm">
                <div className="max-w-6xl mx-auto flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <Link href="/docentes" className="p-1.5 hover:bg-slate-100 rounded-full transition-colors text-slate-500">
                            <ArrowLeft size={20} />
                        </Link>
                        <div>
                            <h1 className="text-xl font-bold text-slate-800 flex items-center gap-2 leading-none">
                                <FileText className="text-indigo-600" size={24} />
                                Lançar Atividades
                            </h1>
                            <p className="text-xs text-slate-500 font-medium mt-0.5 ml-0.5">Registro de atividades de docentes</p>
                        </div>
                    </div>
                </div>
            </header>

            <main className="max-w-6xl mx-auto px-4 py-8">

                {/* Filters */}
                <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm mb-6 flex flex-col md:flex-row gap-4 items-end">
                    <div className="w-full md:w-64">
                        <label className="text-xs font-bold text-slate-500 mb-1 block">Semestre</label>
                        <div className="relative">
                            <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                            <select
                                value={selectedSemestre}
                                onChange={e => setSelectedSemestre(e.target.value)}
                                className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-1 focus:ring-indigo-500 outline-none appearance-none font-medium text-slate-700"
                            >
                                {semestres.map(s => (
                                    <option key={s.id} value={s.id}>{s.ano}.{s.semestre}</option>
                                ))}
                                <option value="">Todos</option>
                            </select>
                        </div>
                    </div>

                    <div className="flex-1 w-full">
                        <label className="text-xs font-bold text-slate-500 mb-1 block">Pesquisar</label>
                        <div className="relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                            <input
                                type="text"
                                placeholder="Nome do docente, tipo de atividade..."
                                value={search}
                                onChange={e => setSearch(e.target.value)}
                                className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-1 focus:ring-indigo-500 outline-none"
                            />
                        </div>
                    </div>

                    {(userAccessLevel || 0) >= 3 && (
                        <button
                            onClick={() => setIsCreating(true)}
                            className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-bold hover:bg-indigo-700 transition-colors shadow-sm flex items-center gap-2 h-[38px]"
                        >
                            <PlusCircle size={16} />
                            Lançar Atividade
                        </button>
                    )}
                </div>

                {/* Create Form */}
                {isCreating && (
                    <div className="bg-white border border-indigo-200 rounded-xl p-5 shadow-sm animate-in slide-in-from-top-2 mb-6">
                        <div className="flex justify-between items-center mb-4">
                            <h3 className="text-sm font-bold text-slate-700 flex items-center gap-2">
                                <PlusCircle size={16} className="text-indigo-500" />
                                Novo Lançamento
                            </h3>
                            <button onClick={() => setIsCreating(false)} className="text-slate-400 hover:text-slate-600"><X size={18} /></button>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
                            <div className="lg:col-span-2">
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Docente *</label>
                                <select
                                    value={formDocente}
                                    onChange={e => setFormDocente(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                >
                                    <option value="">Selecione...</option>
                                    {docentes.map(d => (
                                        <option key={d.id} value={d.id}>{d.nome}</option>
                                    ))}
                                </select>
                            </div>

                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Semestre *</label>
                                <select
                                    value={formSemestre}
                                    onChange={e => setFormSemestre(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                >
                                    {semestres.map(s => (
                                        <option key={s.id} value={s.id}>{s.ano}.{s.semestre}</option>
                                    ))}
                                </select>
                            </div>

                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Quantidade / CH *</label>
                                <input
                                    type="number"
                                    value={formQtd}
                                    onChange={e => setFormQtd(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                    placeholder="0"
                                />
                            </div>

                            <div className="lg:col-span-2">
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Tipo de Atividade *</label>
                                <select
                                    value={formTipo}
                                    onChange={e => setFormTipo(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                >
                                    <option value="">Selecione...</option>
                                    {tiposAtividade.map(t => (
                                        <option key={t.id} value={t.id}>{t.nome} ({t.unidade_medida})</option>
                                    ))}
                                </select>
                            </div>

                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Data Início</label>
                                <input
                                    type="date"
                                    value={formInicio}
                                    onChange={e => setFormInicio(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Data Fim</label>
                                <input
                                    type="date"
                                    value={formFim}
                                    onChange={e => setFormFim(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                />
                            </div>

                            <div className="lg:col-span-4">
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Observações (Opcional)</label>
                                <input
                                    type="text"
                                    value={formObs}
                                    onChange={e => setFormObs(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                    placeholder="Detalhes adicionais..."
                                />
                            </div>
                        </div>

                        <div className="flex justify-end gap-2">
                            <button
                                onClick={() => setIsCreating(false)}
                                className="px-4 py-2 text-slate-600 text-sm font-bold hover:bg-slate-100 rounded-lg transition-colors"
                            >
                                Cancelar
                            </button>
                            <button
                                onClick={handleCreate}
                                className="px-4 py-2 bg-indigo-600 text-white text-sm font-bold hover:bg-indigo-700 rounded-lg transition-colors shadow-sm flex items-center gap-2"
                            >
                                <Check size={16} />
                                Salvar Lançamento
                            </button>
                        </div>
                    </div>
                )}

                {/* List */}
                <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                    <div className="overflow-x-auto">
                        <table className="w-full text-left text-sm whitespace-nowrap">
                            <thead className="bg-slate-50 border-b border-slate-200">
                                <tr>
                                    <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px]">Docente</th>
                                    <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px]">Atividade</th>
                                    <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px]">Qtd.</th>
                                    <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px]">Período</th>
                                    <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px]">Semestre</th>
                                    {(userAccessLevel || 0) >= 3 && (
                                        <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px] text-right">Ações</th>
                                    )}
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                                {filteredAtividades.map((atividade) => (
                                    <tr key={atividade.id} className="hover:bg-slate-50 transition-colors">
                                        <td className="px-6 py-4">
                                            <div className="font-bold text-slate-800 flex items-center gap-2">
                                                <User size={14} className="text-indigo-400" />
                                                {atividade.docentes?.nome || 'Desconhecido'}
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="text-slate-700 font-medium">{atividade.tipos_atividade?.nome}</div>
                                            <div className="text-xs text-slate-400">{atividade.observacoes || atividade.tipos_atividade?.categoria}</div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className="bg-slate-100 text-slate-600 px-2 py-1 rounded text-xs font-mono font-bold">
                                                {atividade.quantidade} {atividade.tipos_atividade?.unidade_medida}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-xs text-slate-500">
                                            {(atividade.data_inicio || atividade.data_fim) ? (
                                                <div className="flex flex-col gap-0.5">
                                                    {atividade.data_inicio && <span>Início: {new Date(atividade.data_inicio).toLocaleDateString('pt-BR')}</span>}
                                                    {atividade.data_fim && <span>Fim: {new Date(atividade.data_fim).toLocaleDateString('pt-BR')}</span>}
                                                </div>
                                            ) : (
                                                <span className="text-slate-300">-</span>
                                            )}
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className="bg-indigo-50 text-indigo-700 px-2 py-1 rounded text-xs font-bold border border-indigo-100">
                                                {atividade.semestres ? `${atividade.semestres.ano}.${atividade.semestres.semestre}` : getSemestreLabel(atividade.semestre_id)}
                                            </span>
                                        </td>
                                        {(userAccessLevel || 0) >= 3 && (
                                            <td className="px-6 py-4 text-right">
                                                <button
                                                    onClick={() => handleDelete(atividade.id)}
                                                    className="text-red-400 hover:text-red-600 hover:bg-red-50 p-1.5 rounded transition-all"
                                                    title="Excluir"
                                                >
                                                    <X size={16} />
                                                </button>
                                            </td>
                                        )}
                                    </tr>
                                ))}
                                {filteredAtividades.length === 0 && (
                                    <tr>
                                        <td colSpan={6} className="px-6 py-12 text-center text-slate-400">
                                            Nenhuma atividade encontrada neste semestre.
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            </main>
        </div>
    )
}
