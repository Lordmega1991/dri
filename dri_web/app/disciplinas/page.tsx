'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import Link from 'next/link'
import {
    Plus,
    Search,
    Edit,
    Trash2,
    BookOpen,
    ArrowLeft,
    Filter,
    X,
    Check,
    ChevronUp,
    ChevronDown
} from 'lucide-react'
import clsx from 'clsx'

type Disciplina = {
    id: string
    nome: string
    ch_aula: number
    nome_extenso: string | null
    periodo: string | null
    ppc: string | null
    turno: string | null
    codigo: string | null
}

const DisciplinaModal = ({ isOpen, onClose, onSave, editingDisciplina }: any) => {
    const [nome, setNome] = useState('')
    const [nomeExtenso, setNomeExtenso] = useState('')
    const [chAula, setChAula] = useState(60)
    const [periodo, setPeriodo] = useState('')
    const [ppc, setPpc] = useState('Novo')
    const [turno, setTurno] = useState('Manhã')
    const [codigo, setCodigo] = useState('')
    const [saving, setSaving] = useState(false)

    useEffect(() => {
        if (editingDisciplina) {
            setNome(editingDisciplina.nome)
            setNomeExtenso(editingDisciplina.nome_extenso || '')
            setChAula(editingDisciplina.ch_aula)
            setPeriodo(editingDisciplina.periodo || '')
            setPpc(editingDisciplina.ppc || '')
            setTurno(editingDisciplina.turno || 'Manhã')
            setCodigo(editingDisciplina.codigo || '')
        } else {
            setNome('')
            setNomeExtenso('')
            setChAula(60)
            setPeriodo('')
            setPpc('Novo')
            setTurno('Manhã')
            setCodigo('')
        }
    }, [editingDisciplina, isOpen])

    if (!isOpen) return null

    const handleSubmit = async (e: any) => {
        e.preventDefault()
        setSaving(true)
        await onSave({
            id: editingDisciplina?.id,
            nome,
            nome_extenso: nomeExtenso || null,
            ch_aula: chAula,
            periodo: periodo || null,
            ppc: ppc || null,
            turno: turno || null,
            codigo: codigo || null
        })
        setSaving(false)
        onClose()
    }

    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden animate-in fade-in zoom-in duration-200">
                <div className="bg-gradient-to-r from-indigo-600 to-indigo-800 p-6">
                    <h3 className="text-white font-bold text-lg flex items-center">
                        <BookOpen className="mr-2" size={20} />
                        {editingDisciplina ? 'Editar Disciplina' : 'Nova Disciplina'}
                    </h3>
                </div>

                <form onSubmit={handleSubmit} className="p-6 space-y-4">
                    <div className="grid grid-cols-1 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Nome Abreviado (Ex: RI I)</label>
                            <input
                                type="text"
                                value={nome}
                                onChange={e => setNome(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none uppercase"
                                required
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Código (Opcional)</label>
                            <input
                                type="text"
                                value={codigo}
                                onChange={e => setCodigo(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none uppercase"
                                placeholder="Ex: DIS001"
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Nome Extenso</label>
                            <input
                                type="text"
                                value={nomeExtenso}
                                onChange={e => setNomeExtenso(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
                            />
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Carga Horária (CH)</label>
                            <input
                                type="number"
                                value={chAula}
                                onChange={e => setChAula(parseInt(e.target.value))}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
                                required
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">PPC (Ano)</label>
                            <input
                                type="text"
                                value={ppc}
                                onChange={e => setPpc(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
                                placeholder="Ex: 2023"
                            />
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Período</label>
                            <input
                                type="text"
                                value={periodo}
                                onChange={e => setPeriodo(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
                                placeholder="1-9 ou Optativas"
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Turno</label>
                            <select
                                value={turno}
                                onChange={e => setTurno(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none bg-white"
                            >
                                <option value="Manhã">Manhã</option>
                                <option value="Tarde">Tarde</option>
                                <option value="Noite">Noite</option>
                                <option value="Integral">Integral</option>
                            </select>
                        </div>
                    </div>

                    <div className="flex justify-end space-x-3 mt-6">
                        <button
                            type="button"
                            onClick={onClose}
                            className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
                        >
                            Cancelar
                        </button>
                        <button
                            type="submit"
                            disabled={saving}
                            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium shadow-sm transition-all"
                        >
                            {saving ? 'Salvando...' : editingDisciplina ? 'Salvar Alterações' : 'Criar Disciplina'}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    )
}

export default function DisciplinasPage() {
    const router = useRouter()
    const [disciplinas, setDisciplinas] = useState<Disciplina[]>([])
    const [loading, setLoading] = useState(true)
    const [search, setSearch] = useState('')
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [editingDisciplina, setEditingDisciplina] = useState<any>(null)

    // Filters
    const [filterPeriodo, setFilterPeriodo] = useState('Todos')
    const [filterTurno, setFilterTurno] = useState('Todos')

    // Sorting State
    const [sortColumn, setSortColumn] = useState<keyof Disciplina>('periodo')
    const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc')

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

            if (!accessData || accessData.access_level < 3) {
                router.push('/')
                return
            }

            fetchDisciplinas()
        }
        checkAccess()
    }, [])

    const fetchDisciplinas = async () => {
        try {
            setLoading(true)
            const { data, error } = await supabase
                .from('disciplinas')
                .select('*')
                .order('periodo', { ascending: true })
                .order('nome', { ascending: true })

            if (error) throw error
            if (data) setDisciplinas(data)
        } catch (error) {
            console.error('Erro ao buscar disciplinas', error)
        } finally {
            setLoading(false)
        }
    }

    const handleSaveDisciplina = async (data: any) => {
        try {
            if (data.id) {
                const { error } = await supabase
                    .from('disciplinas')
                    .update(data)
                    .eq('id', data.id)
                if (error) throw error
            } else {
                const { error } = await supabase
                    .from('disciplinas')
                    .insert(data)
                if (error) throw error
            }
            fetchDisciplinas()
        } catch (err: any) {
            alert('Erro: ' + err.message)
        }
    }

    const handleDelete = async (id: string, nome: string) => {
        if (!confirm(`Tem certeza que deseja excluir a disciplina "${nome}"?`)) return
        try {
            const { error } = await supabase
                .from('disciplinas')
                .delete()
                .eq('id', id)

            if (error) throw error
            fetchDisciplinas()
        } catch (err: any) {
            alert('Erro ao excluir: ' + err.message)
        }
    }

    const openModal = (disc: any = null) => {
        setEditingDisciplina(disc)
        setIsModalOpen(true)
    }

    const filteredDisciplinas = disciplinas.filter(d => {
        const matchesSearch = d.nome.toLowerCase().includes(search.toLowerCase()) ||
            (d.nome_extenso?.toLowerCase() || '').includes(search.toLowerCase()) ||
            (d.ppc?.toLowerCase() || '').includes(search.toLowerCase())

        const matchesPeriodo = filterPeriodo === 'Todos' || d.periodo === filterPeriodo
        const matchesTurno = filterTurno === 'Todos' || d.turno === filterTurno

        return matchesSearch && matchesPeriodo && matchesTurno
    })

    const sortedDisciplinas = [...filteredDisciplinas].sort((a, b) => {
        const valA = a[sortColumn] || ''
        const valB = b[sortColumn] || ''

        if (typeof valA === 'number' && typeof valB === 'number') {
            return sortDirection === 'asc' ? valA - valB : valB - valA
        }

        // Natural sort for strings (especially periods)
        const strA = String(valA)
        const strB = String(valB)

        return sortDirection === 'asc'
            ? strA.localeCompare(strB, undefined, { numeric: true, sensitivity: 'base' })
            : strB.localeCompare(strA, undefined, { numeric: true, sensitivity: 'base' })
    })

    const handleSort = (column: keyof Disciplina) => {
        if (sortColumn === column) {
            setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
        } else {
            setSortColumn(column)
            setSortDirection('asc')
        }
    }

    const SortIcon = ({ column }: { column: keyof Disciplina }) => {
        if (sortColumn !== column) return null
        return sortDirection === 'asc' ? <ChevronUp size={14} className="ml-1" /> : <ChevronDown size={14} className="ml-1" />
    }

    const periodos = Array.from(new Set(disciplinas.map(d => d.periodo).filter(Boolean))).sort()
    const turnos = Array.from(new Set(disciplinas.map(d => d.turno).filter(Boolean))).sort()

    return (
        <div className="min-h-screen bg-gray-50 font-sans">
            <DisciplinaModal
                isOpen={isModalOpen}
                onClose={() => setIsModalOpen(false)}
                onSave={handleSaveDisciplina}
                editingDisciplina={editingDisciplina}
            />

            <header className="bg-white border-b border-gray-200 sticky top-0 z-10 shadow-sm">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
                    <div className="flex items-center">
                        <Link href="/semestre" className="mr-4 text-gray-400 hover:text-gray-600 transition-colors">
                            <ArrowLeft size={24} />
                        </Link>
                        <h1 className="text-xl font-bold text-gray-900 flex items-center">
                            <BookOpen className="mr-2 text-indigo-600" size={24} />
                            Catálogo de Disciplinas
                        </h1>
                    </div>
                </div>
            </header>

            <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

                <div className="flex flex-col md:flex-row md:justify-between md:items-center mb-8 gap-4">
                    <div className="flex-1 max-w-xl relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
                        <input
                            type="text"
                            placeholder="Buscar por nome, ementa ou PPC..."
                            value={search}
                            onChange={e => setSearch(e.target.value)}
                            className="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl shadow-sm focus:ring-2 focus:ring-indigo-500 outline-none transition-all"
                        />
                    </div>

                    <div className="flex gap-2">
                        <div className="flex items-center bg-white border border-gray-200 rounded-xl px-3 shadow-sm">
                            <Filter size={16} className="text-gray-400 mr-2" />
                            <select
                                value={filterPeriodo}
                                onChange={e => setFilterPeriodo(e.target.value)}
                                className="bg-transparent py-2 text-sm outline-none text-gray-600"
                            >
                                <option value="Todos">Todos Períodos</option>
                                {periodos.map(p => <option key={p} value={p || ''}>{p}</option>)}
                            </select>
                        </div>

                        <button
                            onClick={() => openModal(null)}
                            className="bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl font-medium flex items-center shadow-lg hover:shadow-indigo-200 transition-all active:scale-95 whitespace-nowrap"
                        >
                            <Plus size={20} className="mr-2" />
                            Cadastrar Disciplina
                        </button>
                    </div>
                </div>

                {loading ? (
                    <div className="flex flex-col items-center justify-center py-20">
                        <div className="w-12 h-12 border-4 border-indigo-600/20 border-t-indigo-600 rounded-full animate-spin"></div>
                        <p className="text-gray-500 mt-4 font-medium">Carregando catálogo...</p>
                    </div>
                ) : (
                    <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden overflow-x-auto">
                        <table className="w-full text-left border-collapse">
                            <thead>
                                <tr className="bg-gray-50 border-b border-gray-200 text-xs font-bold text-gray-500 uppercase tracking-wider">
                                    <th className="px-6 py-4 cursor-pointer hover:bg-gray-100 transition-colors" onClick={() => handleSort('nome')}>
                                        <div className="flex items-center">Disciplina <SortIcon column="nome" /></div>
                                    </th>
                                    <th className="px-6 py-4 cursor-pointer hover:bg-gray-100 transition-colors" onClick={() => handleSort('codigo')}>
                                        <div className="flex items-center">Código <SortIcon column="codigo" /></div>
                                    </th>
                                    <th className="px-6 py-4 cursor-pointer hover:bg-gray-100 transition-colors" onClick={() => handleSort('periodo')}>
                                        <div className="flex items-center">Período <SortIcon column="periodo" /></div>
                                    </th>
                                    <th className="px-6 py-4 cursor-pointer hover:bg-gray-100 transition-colors" onClick={() => handleSort('ch_aula')}>
                                        <div className="flex items-center">CH <SortIcon column="ch_aula" /></div>
                                    </th>
                                    <th className="px-6 py-4 cursor-pointer hover:bg-gray-100 transition-colors" onClick={() => handleSort('turno')}>
                                        <div className="flex items-center">Turno <SortIcon column="turno" /></div>
                                    </th>
                                    <th className="px-6 py-4 cursor-pointer hover:bg-gray-100 transition-colors" onClick={() => handleSort('ppc')}>
                                        <div className="flex items-center">PPC <SortIcon column="ppc" /></div>
                                    </th>
                                    <th className="px-6 py-4 text-right">Ações</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {sortedDisciplinas.length > 0 ? sortedDisciplinas.map((disc) => (
                                    <tr key={disc.id} className="hover:bg-gray-50/50 transition-colors group">
                                        <td className="px-6 py-4">
                                            <div className="font-bold text-gray-900">{disc.nome}</div>
                                            <div className="text-xs text-gray-400 truncate max-w-[200px]">{disc.nome_extenso || '-'}</div>
                                        </td>
                                        <td className="px-6 py-4 text-sm font-medium text-gray-500">
                                            {disc.codigo || '-'}
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className={clsx(
                                                "px-2 py-1 rounded-md text-[10px] font-bold uppercase",
                                                isNaN(parseInt(disc.periodo || '')) ? "bg-purple-100 text-purple-700" : "bg-indigo-100 text-indigo-700"
                                            )}>
                                                {disc.periodo || 'N/A'}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-sm font-medium text-gray-600">{disc.ch_aula}h</td>
                                        <td className="px-6 py-4">
                                            <span className={clsx(
                                                "text-[10px] font-bold px-2 py-1 rounded-full",
                                                disc.turno === 'Noite' ? 'bg-indigo-50 text-indigo-700' : 'bg-orange-50 text-orange-700'
                                            )}>
                                                {disc.turno || 'M'}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-sm text-gray-500 font-medium">{disc.ppc || '-'}</td>
                                        <td className="px-6 py-4 text-right">
                                            <div className="flex justify-end space-x-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                                <button
                                                    onClick={() => openModal(disc)}
                                                    className="p-2 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
                                                    title="Editar"
                                                >
                                                    <Edit size={16} />
                                                </button>
                                                <button
                                                    onClick={() => handleDelete(disc.id, disc.nome)}
                                                    className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                                    title="Excluir"
                                                >
                                                    <Trash2 size={16} />
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                )) : (
                                    <tr>
                                        <td colSpan={6} className="px-6 py-12 text-center text-gray-400 italic">
                                            Nenhuma disciplina encontrada com os filtros atuais.
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </div>
                )}

                <div className="mt-6 flex justify-between items-center text-sm text-gray-500">
                    <p>Total de disciplinas: <span className="font-bold text-gray-900">{sortedDisciplinas.length}</span></p>
                    <p className="hidden md:block">DRI - Departamento de Relações Internacionais</p>
                </div>

            </main>
        </div>
    )
}
