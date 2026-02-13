'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Search,
    PlusCircle,
    Edit2,
    Trash2,
    Save,
    X,
    Tag,
    List,
    Shield,
    AlertCircle
} from 'lucide-react'
import clsx from 'clsx'

type TipoAtividade = {
    id: string | number
    nome: string
    categoria: string
    descricao: string | null
    unidade_medida: string
    created_at?: string
}

const CATEGORIAS = ['Ensino', 'Pesquisa', 'Extensão', 'Administrativa', 'Outra']
const UNIDADES = ['horas', 'quantidade', 'pontos', 'outro']

export default function TiposAtividadePage() {
    const router = useRouter()

    // Access & User State
    const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)
    const [loading, setLoading] = useState(true)

    // Data State
    const [tipos, setTipos] = useState<TipoAtividade[]>([])
    const [filteredTipos, setFilteredTipos] = useState<TipoAtividade[]>([])
    const [search, setSearch] = useState('')

    // Pagination
    const [currentPage, setCurrentPage] = useState(1)
    const itemsPerPage = 20

    // Editing State
    const [editingId, setEditingId] = useState<string | number | null>(null)
    const [tempNome, setTempNome] = useState('')
    const [tempCategoria, setTempCategoria] = useState('')
    const [tempUnidade, setTempUnidade] = useState('')
    const [tempDescricao, setTempDescricao] = useState('')

    // Creating State
    const [isCreating, setIsCreating] = useState(false)
    const [newNome, setNewNome] = useState('')
    const [newCategoria, setNewCategoria] = useState(CATEGORIAS[0])
    const [newUnidade, setNewUnidade] = useState(UNIDADES[0])
    const [newDescricao, setNewDescricao] = useState('')

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
            fetchTipos()
        }
        checkAccess()
    }, [router])

    const fetchTipos = async () => {
        setLoading(true)
        try {
            const { data, error } = await supabase
                .from('tipos_atividade')
                .select('*')
                .order('categoria')
                .order('nome')

            if (error) throw error
            if (data) {
                setTipos(data)
                setFilteredTipos(data)
            }
        } catch (error) {
            console.error('Erro ao buscar tipos:', error)
        } finally {
            setLoading(false)
        }
    }

    // Filter Effect
    useEffect(() => {
        if (search.trim() === '') {
            setFilteredTipos(tipos)
        } else {
            const lowerSearch = search.toLowerCase()
            const filtered = tipos.filter(t =>
                t.nome.toLowerCase().includes(lowerSearch) ||
                t.categoria.toLowerCase().includes(lowerSearch) ||
                (t.descricao && t.descricao.toLowerCase().includes(lowerSearch))
            )
            setFilteredTipos(filtered)
        }
        setCurrentPage(1)
    }, [search, tipos])

    // Pagination Logic
    const totalPages = Math.ceil(filteredTipos.length / itemsPerPage)
    const paginatedTipos = filteredTipos.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage)

    // Actions
    const handleEditClick = (tipo: TipoAtividade) => {
        setEditingId(tipo.id)
        setTempNome(tipo.nome)
        setTempCategoria(tipo.categoria)
        setTempUnidade(tipo.unidade_medida || 'horas')
        setTempDescricao(tipo.descricao || '')
    }

    const handleCancelEdit = () => {
        setEditingId(null)
    }

    const handleSaveEdit = async (id: string | number) => {
        if (!tempNome.trim()) {
            alert('Nome é obrigatório')
            return
        }

        try {
            const { error } = await supabase
                .from('tipos_atividade')
                .update({
                    nome: tempNome,
                    categoria: tempCategoria,
                    unidade_medida: tempUnidade,
                    descricao: tempDescricao
                })
                .eq('id', id)

            if (error) throw error

            setTipos(prev => prev.map(t => t.id === id ? {
                ...t,
                nome: tempNome,
                categoria: tempCategoria,
                unidade_medida: tempUnidade,
                descricao: tempDescricao
            } : t))
            setEditingId(null)
        } catch (error) {
            console.error('Erro ao atualizar:', error)
            alert('Erro ao atualizar tipo de atividade.')
        }
    }

    const handleDelete = async (id: string | number) => {
        if (!confirm('Tem certeza que deseja excluir este tipo de atividade?')) return

        try {
            const { error } = await supabase
                .from('tipos_atividade')
                .delete()
                .eq('id', id)

            if (error) throw error

            setTipos(prev => prev.filter(t => t.id !== id))
        } catch (error) {
            console.error('Erro ao excluir:', error)
            alert('Erro ao excluir. Pode haver atividades vinculadas a este tipo.')
        }
    }

    const handleCreate = async () => {
        if (!newNome.trim()) {
            alert('Nome é obrigatório')
            return
        }

        try {
            const { data, error } = await supabase
                .from('tipos_atividade')
                .insert({
                    nome: newNome,
                    categoria: newCategoria,
                    unidade_medida: newUnidade,
                    descricao: newDescricao
                })
                .select()
                .single()

            if (error) throw error

            if (data) {
                setTipos(prev => [data, ...prev])
                setIsCreating(false)
                setNewNome('')
                setNewDescricao('')
                setNewCategoria(CATEGORIAS[0])
                setNewUnidade(UNIDADES[0])
            }
        } catch (error) {
            console.error('Erro ao criar:', error)
            alert('Erro ao criar tipo de atividade.')
        }
    }

    const getCategoryColor = (cat: string) => {
        switch (cat.toLowerCase()) {
            case 'ensino': return 'bg-blue-50 text-blue-700 border-blue-200'
            case 'pesquisa': return 'bg-purple-50 text-purple-700 border-purple-200'
            case 'extensão': return 'bg-orange-50 text-orange-700 border-orange-200'
            case 'administrativa': return 'bg-slate-50 text-slate-700 border-slate-200'
            default: return 'bg-gray-50 text-gray-700 border-gray-200'
        }
    }

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-[#F5F5F7]">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            </div>
        )
    }

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
                                <Tag className="text-indigo-600" size={24} />
                                Tipos de Atividade
                            </h1>
                            <p className="text-xs text-slate-500 font-medium mt-0.5 ml-0.5">Catálogo de atividades</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-3">
                        <div className="relative hidden sm:block">
                            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                            <input
                                type="text"
                                placeholder="Pesquisar..."
                                value={search}
                                onChange={e => setSearch(e.target.value)}
                                className="pl-8 pr-3 py-1.5 bg-slate-100 border-none rounded-lg text-sm focus:ring-1 focus:ring-indigo-500 outline-none w-48 transition-all focus:w-64"
                            />
                        </div>
                    </div>
                </div>
            </header>

            <main className="max-w-6xl mx-auto px-4 py-8">

                <div className="flex justify-between items-center mb-4">
                    <div className="text-xs font-medium text-slate-500">
                        {filteredTipos.length} tipos cadastrados
                    </div>

                    <div className="flex items-center gap-3">
                        {userAccessLevel !== null && userAccessLevel >= 3 && (
                            <button
                                onClick={() => setIsCreating(true)}
                                disabled={isCreating}
                                className="flex items-center gap-1 px-3 py-1.5 bg-indigo-600 text-white rounded-lg text-xs font-bold hover:bg-indigo-700 transition-colors shadow-sm disabled:opacity-50"
                            >
                                <PlusCircle size={14} />
                                Novo Tipo
                            </button>
                        )}
                    </div>
                </div>

                {isCreating && (
                    <div className="mb-4 bg-white border border-indigo-200 rounded-xl p-4 shadow-sm animate-in slide-in-from-top-2">
                        <h3 className="text-sm font-bold text-slate-700 mb-3 flex items-center gap-2">
                            <PlusCircle size={16} className="text-indigo-500" />
                            Novo Tipo de Atividade
                        </h3>
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3 mb-3">
                            <div className="lg:col-span-2">
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Nome</label>
                                <input
                                    type="text"
                                    value={newNome}
                                    onChange={e => setNewNome(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-1.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                    placeholder="Ex: Orientação de TCC"
                                />
                            </div>
                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Categoria</label>
                                <select
                                    value={newCategoria}
                                    onChange={e => setNewCategoria(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-1.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white"
                                >
                                    {CATEGORIAS.map(c => <option key={c} value={c}>{c}</option>)}
                                </select>
                            </div>
                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Unidade</label>
                                <select
                                    value={newUnidade}
                                    onChange={e => setNewUnidade(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-1.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white"
                                >
                                    {UNIDADES.map(u => <option key={u} value={u}>{u}</option>)}
                                </select>
                            </div>
                            <div className="lg:col-span-4">
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Descrição (Opcional)</label>
                                <input
                                    type="text"
                                    value={newDescricao}
                                    onChange={e => setNewDescricao(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-1.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                    placeholder="Breve descrição..."
                                />
                            </div>
                        </div>
                        <div className="flex justify-end gap-2">
                            <button
                                onClick={() => setIsCreating(false)}
                                className="px-3 py-1.5 text-slate-600 text-xs font-bold hover:bg-slate-100 rounded-lg transition-colors"
                            >
                                Cancelar
                            </button>
                            <button
                                onClick={handleCreate}
                                className="px-3 py-1.5 bg-indigo-600 text-white text-xs font-bold hover:bg-indigo-700 rounded-lg transition-colors shadow-sm"
                            >
                                Salvar
                            </button>
                        </div>
                    </div>
                )}

                <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                    <div className="overflow-x-auto">
                        <table className="w-full text-left text-sm whitespace-nowrap">
                            <thead className="bg-slate-50 border-b border-slate-200">
                                <tr>
                                    <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px]">Nome / Descrição</th>
                                    <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px]">Categoria</th>
                                    <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px]">Unidade</th>
                                    {(userAccessLevel || 0) >= 3 && (
                                        <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[11px] text-right">Ações</th>
                                    )}
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                                {paginatedTipos.map((tipo) => (
                                    <tr key={tipo.id} className="hover:bg-slate-50 transition-colors group">
                                        <td className="px-6 py-4">
                                            {editingId === tipo.id ? (
                                                <div className="space-y-2">
                                                    <input
                                                        type="text"
                                                        value={tempNome}
                                                        onChange={e => setTempNome(e.target.value)}
                                                        className="w-full border border-indigo-300 rounded px-2 py-1 text-sm focus:ring-1 focus:ring-indigo-500 outline-none"
                                                        placeholder="Nome"
                                                    />
                                                    <input
                                                        type="text"
                                                        value={tempDescricao}
                                                        onChange={e => setTempDescricao(e.target.value)}
                                                        className="w-full border border-indigo-300 rounded px-2 py-1 text-xs focus:ring-1 focus:ring-indigo-500 outline-none"
                                                        placeholder="Descrição"
                                                    />
                                                </div>
                                            ) : (
                                                <div>
                                                    <div className="font-bold text-slate-800">{tipo.nome}</div>
                                                    {tipo.descricao && <div className="text-xs text-slate-400 mt-0.5">{tipo.descricao}</div>}
                                                </div>
                                            )}
                                        </td>
                                        <td className="px-6 py-4">
                                            {editingId === tipo.id ? (
                                                <select
                                                    value={tempCategoria}
                                                    onChange={e => setTempCategoria(e.target.value)}
                                                    className="border border-indigo-300 rounded px-2 py-1 text-sm focus:ring-1 focus:ring-indigo-500 outline-none bg-white"
                                                >
                                                    {CATEGORIAS.map(c => <option key={c} value={c}>{c}</option>)}
                                                </select>
                                            ) : (
                                                <span className={clsx(
                                                    "px-2 py-0.5 rounded text-[10px] font-bold uppercase border",
                                                    getCategoryColor(tipo.categoria)
                                                )}>
                                                    {tipo.categoria}
                                                </span>
                                            )}
                                        </td>
                                        <td className="px-6 py-4">
                                            {editingId === tipo.id ? (
                                                <select
                                                    value={tempUnidade}
                                                    onChange={e => setTempUnidade(e.target.value)}
                                                    className="border border-indigo-300 rounded px-2 py-1 text-sm focus:ring-1 focus:ring-indigo-500 outline-none bg-white"
                                                >
                                                    {UNIDADES.map(u => <option key={u} value={u}>{u}</option>)}
                                                </select>
                                            ) : (
                                                <span className="text-slate-500 text-xs font-mono">
                                                    {tipo.unidade_medida || 'horas'}
                                                </span>
                                            )}
                                        </td>
                                        {(userAccessLevel || 0) >= 3 && (
                                            <td className="px-6 py-4 text-right">
                                                {editingId === tipo.id ? (
                                                    <div className="flex items-center justify-end gap-2">
                                                        <button
                                                            onClick={() => handleSaveEdit(tipo.id)}
                                                            className="p-1.5 bg-green-100 text-green-700 rounded hover:bg-green-200 transition-colors"
                                                            title="Salvar"
                                                        >
                                                            <Save size={16} />
                                                        </button>
                                                        <button
                                                            onClick={handleCancelEdit}
                                                            className="p-1.5 bg-red-100 text-red-700 rounded hover:bg-red-200 transition-colors"
                                                            title="Cancelar"
                                                        >
                                                            <X size={16} />
                                                        </button>
                                                    </div>
                                                ) : (
                                                    <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                                        <button
                                                            onClick={() => handleEditClick(tipo)}
                                                            className="p-1.5 text-indigo-600 hover:bg-indigo-50 rounded transition-colors"
                                                            title="Editar"
                                                        >
                                                            <Edit2 size={16} />
                                                        </button>
                                                        <button
                                                            onClick={() => handleDelete(tipo.id)}
                                                            className="p-1.5 text-red-500 hover:bg-red-50 rounded transition-colors"
                                                            title="Excluir"
                                                        >
                                                            <Trash2 size={16} />
                                                        </button>
                                                    </div>
                                                )}
                                            </td>
                                        )}
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </main>
        </div>
    )
}
