'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Search,
    PlusCircle,
    User,
    Edit2,
    Trash2,
    Save,
    X,
    CheckCircle,
    XCircle,
    ChevronLeft,
    ChevronRight,
    Shield,
    AlertCircle,
    Calendar,
    ArrowUpDown,
    ArrowUp,
    ArrowDown
} from 'lucide-react'
import clsx from 'clsx'

type Docente = {
    id: string | number
    nome: string
    apelido: string | null
    matricula: string | null
    email: string | null
    afastado_ate: string | null
    ativo: boolean
}

type SortField = 'nome' | 'email' | 'matricula' | 'status' | 'afastado'
type SortOrder = 'asc' | 'desc'

export default function GestaoDocentesListaPage() {
    const router = useRouter()

    // Access & User State
    const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)
    const [loading, setLoading] = useState(true)

    // Data State
    const [docentes, setDocentes] = useState<Docente[]>([])
    const [filteredDocentes, setFilteredDocentes] = useState<Docente[]>([])
    const [search, setSearch] = useState('')

    // Sorting
    const [sortField, setSortField] = useState<SortField>('nome')
    const [sortOrder, setSortOrder] = useState<SortOrder>('asc')

    // Pagination
    const [currentPage, setCurrentPage] = useState(1)
    const itemsPerPage = 20

    // Editing State (Modal)
    const [isEditing, setIsEditing] = useState(false)
    const [editingId, setEditingId] = useState<string | number | null>(null)

    // Form State
    const [formNome, setFormNome] = useState('')
    const [formEmail, setFormEmail] = useState('')
    const [formMatricula, setFormMatricula] = useState('')
    const [formApelido, setFormApelido] = useState('')
    const [formAfastadoAte, setFormAfastadoAte] = useState('')

    const [isCreating, setIsCreating] = useState(false)

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
            fetchDocentes()
        }
        checkAccess()
    }, [router])

    const fetchDocentes = async () => {
        setLoading(true)
        try {
            const { data, error } = await supabase
                .from('docentes')
                .select('*')

            if (error) throw error
            if (data) {
                setDocentes(data)
                setFilteredDocentes(data)
            }
        } catch (error) {
            console.error('Erro ao buscar docentes:', error)
        } finally {
            setLoading(false)
        }
    }

    // Filter & Sort Effect
    useEffect(() => {
        let result = [...docentes]

        // 1. Search
        if (search.trim() !== '') {
            const lowerSearch = search.toLowerCase()
            result = result.filter(d =>
                d.nome.toLowerCase().includes(lowerSearch) ||
                (d.email && d.email.toLowerCase().includes(lowerSearch)) ||
                (d.matricula && d.matricula.toLowerCase().includes(lowerSearch)) ||
                (d.apelido && d.apelido.toLowerCase().includes(lowerSearch))
            )
        }

        // 2. Sort
        result.sort((a, b) => {
            let valA: any = ''
            let valB: any = ''

            switch (sortField) {
                case 'nome':
                    // Remove titles for sorting (simple version)
                    valA = a.nome.replace(/^(Prof\.|Dr\.|Me\.|Dra\.|Ma\.)\s*/i, '').trim().toLowerCase()
                    valB = b.nome.replace(/^(Prof\.|Dr\.|Me\.|Dra\.|Ma\.)\s*/i, '').trim().toLowerCase()
                    break
                case 'email':
                    valA = a.email?.toLowerCase() || ''
                    valB = b.email?.toLowerCase() || ''
                    break
                case 'matricula':
                    valA = a.matricula || ''
                    valB = b.matricula || ''
                    break
                case 'status':
                    // Active first or Inactive first
                    valA = a.ativo ? 1 : 0
                    valB = b.ativo ? 1 : 0
                    break
                case 'afastado':
                    valA = a.afastado_ate || ''
                    valB = b.afastado_ate || ''
                    break
                default:
                    valA = a.nome
                    valB = b.nome
            }

            if (valA < valB) return sortOrder === 'asc' ? -1 : 1
            if (valA > valB) return sortOrder === 'asc' ? 1 : -1
            return 0
        })

        setFilteredDocentes(result)
        setCurrentPage(1)
    }, [search, docentes, sortField, sortOrder])

    // Pagination Logic
    const totalPages = Math.ceil(filteredDocentes.length / itemsPerPage)
    const paginatedDocentes = filteredDocentes.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage)

    // Handlers
    const handleSort = (field: SortField) => {
        if (sortField === field) {
            setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')
        } else {
            setSortField(field)
            setSortOrder('asc')
        }
    }

    const clearForm = () => {
        setFormNome('')
        setFormEmail('')
        setFormMatricula('')
        setFormApelido('')
        setFormAfastadoAte('')
        setEditingId(null)
        setIsEditing(false)
        setIsCreating(false)
    }

    const openCreate = () => {
        clearForm()
        setIsCreating(true)
    }

    const openEdit = (docente: Docente) => {
        setEditingId(docente.id)
        setFormNome(docente.nome)
        setFormEmail(docente.email || '')
        setFormMatricula(docente.matricula || '')
        setFormApelido(docente.apelido || '')
        setFormAfastadoAte(docente.afastado_ate ? docente.afastado_ate.split('T')[0] : '')
        setIsEditing(true)
    }

    const handleSave = async () => {
        if (!formNome.trim() || !formEmail.trim()) {
            alert('Nome e Email são obrigatórios')
            return
        }

        // Logic for active status based on afastado_ate
        const isAfastado = !!formAfastadoAte
        const ativo = !isAfastado

        const payload = {
            nome: formNome,
            email: formEmail,
            matricula: formMatricula.trim() || null,
            apelido: formApelido.trim() || null,
            afastado_ate: formAfastadoAte || null,
            ativo: ativo
        }

        try {
            if (isEditing && editingId) {
                const { error } = await supabase
                    .from('docentes')
                    .update(payload)
                    .eq('id', editingId)
                if (error) throw error

                setDocentes(prev => prev.map(d => d.id === editingId ? { ...d, ...payload, id: editingId } : d))
                alert('Docente atualizado com sucesso!')
            } else {
                const { data, error } = await supabase
                    .from('docentes')
                    .insert(payload)
                    .select()
                    .single()
                if (error) throw error
                if (data) setDocentes(prev => [data, ...prev])
                alert('Docente cadastrado com sucesso!')
            }
            clearForm()
        } catch (error: any) {
            console.error('Erro detalhado ao salvar:', JSON.stringify(error, null, 2))
            const msg = error.message || error.details || 'Erro desconhecido.'
            const code = error.code
            if (code === '23505') {
                alert('Erro: Já existe um docente com este Email ou Matrícula.')
            } else {
                alert(`Erro ao salvar: ${msg}`)
            }
        }
    }

    const handleDelete = async (id: string | number) => {
        if (!confirm('Tem certeza que deseja excluir este docente permanentemente?')) return

        try {
            const { error } = await supabase
                .from('docentes')
                .delete()
                .eq('id', id)

            if (error) throw error
            setDocentes(prev => prev.filter(d => d.id !== id))
        } catch (error: any) {
            console.error('Erro ao excluir:', error)
            alert(`Erro ao excluir docente: ${error.message || 'Pode haver dependências.'}`)
        }
    }

    const toggleAtivoDirect = async (docente: Docente) => {
        if ((userAccessLevel || 0) < 3) return

        const newValue = !docente.ativo
        try {
            const { error } = await supabase
                .from('docentes')
                .update({ ativo: newValue })
                .eq('id', docente.id)

            if (error) throw error
            setDocentes(prev => prev.map(d => d.id === docente.id ? { ...d, ativo: newValue } : d))
        } catch (error) {
            console.error('Erro ao alterar status:', error)
        }
    }

    const SortIcon = ({ field }: { field: SortField }) => {
        if (sortField !== field) return <ArrowUpDown size={12} className="text-slate-400 ml-1 inline" />
        return sortOrder === 'asc'
            ? <ArrowUp size={12} className="text-indigo-600 ml-1 inline" />
            : <ArrowDown size={12} className="text-indigo-600 ml-1 inline" />
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
                                <User className="text-indigo-600" size={24} />
                                Lista de Docentes
                            </h1>
                            <p className="text-xs text-slate-500 font-medium mt-0.5 ml-0.5">Catálogo completo</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-3">
                        <div className="relative hidden sm:block">
                            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                            <input
                                type="text"
                                placeholder="Pesquisar por nome, email..."
                                value={search}
                                onChange={e => setSearch(e.target.value)}
                                className="pl-8 pr-3 py-1.5 bg-slate-100 border-none rounded-lg text-sm focus:ring-1 focus:ring-indigo-500 outline-none w-48 transition-all focus:w-64"
                            />
                        </div>

                        {userAccessLevel !== null && (
                            <span className={clsx(
                                "px-2 py-1 rounded-md text-[10px] font-bold border flex items-center gap-1 uppercase tracking-wider",
                                userAccessLevel >= 3 ? "bg-indigo-50 text-indigo-700 border-indigo-200" : "bg-slate-100 text-slate-500 border-slate-200"
                            )}>
                                <Shield size={10} />
                                Nível {userAccessLevel}
                            </span>
                        )}
                    </div>
                </div>
            </header>

            <main className="max-w-6xl mx-auto px-4 py-8 pb-32">

                <div className="flex justify-between items-center mb-4">
                    <div className="text-xs font-medium text-slate-500">
                        {filteredDocentes.length} docentes encontrados
                    </div>

                    <div className="flex items-center gap-3">
                        {userAccessLevel !== null && userAccessLevel >= 3 && (
                            <button
                                onClick={openCreate}
                                className="flex items-center gap-1 px-3 py-1.5 bg-indigo-600 text-white rounded-lg text-xs font-bold hover:bg-indigo-700 transition-colors shadow-sm"
                            >
                                <PlusCircle size={14} />
                                Novo Docente
                            </button>
                        )}

                        {totalPages > 1 && (
                            <div className="flex items-center gap-1 bg-white border border-slate-200 rounded-lg p-1">
                                <button
                                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                                    disabled={currentPage === 1}
                                    className="p-1 rounded hover:bg-slate-100 disabled:opacity-50"
                                >
                                    <ChevronLeft size={16} />
                                </button>
                                <span className="text-xs font-medium px-2 text-slate-600">{currentPage} / {totalPages}</span>
                                <button
                                    onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                                    disabled={currentPage === totalPages}
                                    className="p-1 rounded hover:bg-slate-100 disabled:opacity-50"
                                >
                                    <ChevronRight size={16} />
                                </button>
                            </div>
                        )}
                    </div>
                </div>

                {/* Create/Edit Form (Modal-like Inline) */}
                {(isCreating || isEditing) && (
                    <div className="mb-6 bg-white border border-indigo-200 rounded-xl p-5 shadow-sm animate-in slide-in-from-top-2">
                        <h3 className="text-sm font-bold text-slate-700 mb-4 flex items-center gap-2">
                            {isEditing ? <Edit2 size={16} className="text-indigo-500" /> : <PlusCircle size={16} className="text-indigo-500" />}
                            {isEditing ? 'Editar Registro' : 'Novo Cadastro'}
                        </h3>

                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-4">
                            <div className="lg:col-span-2">
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Nome Completo *</label>
                                <input
                                    type="text"
                                    value={formNome}
                                    onChange={e => setFormNome(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                    placeholder="Ex: Prof. Dr. João Silva"
                                />
                            </div>
                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">E-mail Institucional *</label>
                                <input
                                    type="email"
                                    value={formEmail}
                                    onChange={e => setFormEmail(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                    placeholder="email@ufpb.br"
                                />
                            </div>
                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Siape / Matrícula</label>
                                <input
                                    type="text"
                                    value={formMatricula}
                                    onChange={e => setFormMatricula(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                    placeholder="Apenas números"
                                />
                            </div>
                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Apelido (Opcional)</label>
                                <input
                                    type="text"
                                    value={formApelido}
                                    onChange={e => setFormApelido(e.target.value)}
                                    className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                                    placeholder="Como é conhecido"
                                />
                            </div>
                            <div>
                                <label className="text-xs font-bold text-slate-500 mb-1 block">Afastado Até</label>
                                <div className="relative">
                                    <input
                                        type="date"
                                        value={formAfastadoAte}
                                        onChange={e => setFormAfastadoAte(e.target.value)}
                                        className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none pl-9"
                                    />
                                    <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                                </div>
                            </div>
                        </div>

                        <div className="flex justify-end gap-2">
                            <button
                                onClick={clearForm}
                                className="px-4 py-2 text-slate-600 text-xs font-bold hover:bg-slate-100 rounded-lg transition-colors"
                            >
                                Cancelar
                            </button>
                            <button
                                onClick={handleSave}
                                className="px-4 py-2 bg-indigo-600 text-white text-xs font-bold hover:bg-indigo-700 rounded-lg transition-colors shadow-sm flex items-center gap-2"
                            >
                                <Save size={16} />
                                {isEditing ? 'Atualizar Doncente' : 'Cadastrar Docente'}
                            </button>
                        </div>
                    </div>
                )}

                <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                    <div className="overflow-x-auto w-full">
                        <table className="w-full text-left text-sm whitespace-nowrap">
                            <thead className="bg-slate-50 border-b border-slate-200">
                                <tr>
                                    <th
                                        className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[10px] cursor-pointer hover:bg-slate-100 transition-colors select-none text-center"
                                        onClick={() => handleSort('status')}
                                    >
                                        Status <SortIcon field="status" />
                                    </th>
                                    <th
                                        className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[10px] cursor-pointer hover:bg-slate-100 transition-colors select-none"
                                        onClick={() => handleSort('nome')}
                                    >
                                        Docente <SortIcon field="nome" />
                                    </th>
                                    <th
                                        className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[10px] cursor-pointer hover:bg-slate-100 transition-colors select-none"
                                        onClick={() => handleSort('email')}
                                    >
                                        Email <SortIcon field="email" />
                                    </th>
                                    <th
                                        className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[10px] cursor-pointer hover:bg-slate-100 transition-colors select-none"
                                        onClick={() => handleSort('matricula')}
                                    >
                                        Matrícula <SortIcon field="matricula" />
                                    </th>
                                    <th
                                        className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[10px] cursor-pointer hover:bg-slate-100 transition-colors select-none"
                                        onClick={() => handleSort('afastado')}
                                    >
                                        Afastado Até <SortIcon field="afastado" />
                                    </th>
                                    {(userAccessLevel || 0) >= 3 && (
                                        <th className="px-6 py-4 font-bold text-slate-500 uppercase tracking-wider text-[10px] text-right">Ações</th>
                                    )}
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                                {paginatedDocentes.map((docente) => (
                                    <tr key={docente.id} className="hover:bg-slate-50 transition-colors group">
                                        <td className="px-6 py-4 text-center">
                                            <div
                                                onClick={() => toggleAtivoDirect(docente)}
                                                className={clsx(
                                                    "inline-flex items-center justify-center px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wide border cursor-pointer select-none",
                                                    docente.ativo ? "bg-green-50 text-green-700 border-green-200" : "bg-red-50 text-red-700 border-red-200"
                                                )}
                                            >
                                                {docente.ativo ? "ATIVO" : "INATIVO"}
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="flex flex-col">
                                                <span className={clsx("font-extrabold text-slate-800 text-[13px]", !docente.ativo && "line-through decoration-slate-400 text-slate-400")}>
                                                    {docente.nome.toUpperCase()}
                                                </span>
                                                {docente.apelido && <span className="text-[10px] text-slate-500">{docente.apelido}</span>}
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-xs text-slate-500">
                                            {docente.email || '-'}
                                        </td>
                                        <td className="px-6 py-4 text-xs text-slate-500">
                                            {docente.matricula || '-'}
                                        </td>
                                        <td className="px-6 py-4 text-xs text-slate-500">
                                            {docente.afastado_ate ? new Date(docente.afastado_ate).toLocaleDateString('pt-BR') : '-'}
                                        </td>
                                        {(userAccessLevel || 0) >= 3 && (
                                            <td className="px-6 py-4 text-right">
                                                <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                                    <button
                                                        onClick={() => openEdit(docente)}
                                                        className="p-1.5 text-indigo-600 hover:bg-indigo-50 rounded transition-colors"
                                                        title="Editar"
                                                    >
                                                        <Edit2 size={16} />
                                                    </button>
                                                    <button
                                                        onClick={() => toggleAtivoDirect(docente)}
                                                        className={clsx(
                                                            "p-1.5 rounded transition-colors",
                                                            docente.ativo ? "text-red-500 hover:bg-red-50" : "text-green-500 hover:bg-green-50"
                                                        )}
                                                        title={docente.ativo ? "Desativar" : "Ativar"}
                                                    >
                                                        {docente.ativo ? <XCircle size={16} /> : <CheckCircle size={16} />}
                                                    </button>
                                                    <button
                                                        onClick={() => handleDelete(docente.id)}
                                                        className="p-1.5 text-red-500 hover:bg-red-50 rounded transition-colors"
                                                        title="Excluir"
                                                    >
                                                        <Trash2 size={16} />
                                                    </button>
                                                </div>
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
