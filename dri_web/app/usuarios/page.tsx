'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import Link from 'next/link'
import { ArrowLeft, User, Shield, AlertCircle, Search, ChevronLeft, ChevronRight, Save, X } from 'lucide-react'

type UserAccess = {
    id: string
    email: string
    full_name: string | null
    access_level: number
    allowed_pages?: string[]
    created_at: string
    nomecompleto: string | null
    matricula: number | null
}

export default function UsuariosPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [users, setUsers] = useState<UserAccess[]>([])
    const [filteredUsers, setFilteredUsers] = useState<UserAccess[]>([])
    const [currentUserLevel, setCurrentUserLevel] = useState<number | null>(null)
    const [search, setSearch] = useState('')
    const [currentPage, setCurrentPage] = useState(1)
    const itemsPerPage = 20
    const [editingUser, setEditingUser] = useState<string | null>(null)

    // Temp states for editing
    const [tempLevel, setTempLevel] = useState<number>(0)
    const [tempFullName, setTempFullName] = useState<string>('')
    const [tempNomeCompleto, setTempNomeCompleto] = useState<string>('')

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

            if (!accessData || accessData.access_level < 4) {
                router.push('/')
                return
            }

            setCurrentUserLevel(accessData.access_level)
            fetchUsers()
        }
        checkAccess()
    }, [])

    const fetchUsers = async () => {
        try {
            setLoading(true)
            const { data, error } = await supabase
                .from('users_access')
                .select('*')
                .order('created_at', { ascending: false })

            if (error) throw error
            if (data) {
                setUsers(data)
                setFilteredUsers(data)
            }
        } catch (error) {
            console.error('Erro ao buscar usuários', error)
        } finally {
            setLoading(false)
        }
    }

    useEffect(() => {
        if (search.trim() === '') {
            setFilteredUsers(users)
        } else {
            const lowerSearch = search.toLowerCase()
            const filtered = users.filter(user =>
                (user.full_name?.toLowerCase().includes(lowerSearch)) ||
                (user.nomecompleto?.toLowerCase().includes(lowerSearch)) ||
                (user.email?.toLowerCase().includes(lowerSearch)) ||
                (user.id.toLowerCase().includes(lowerSearch))
            )
            setFilteredUsers(filtered)
        }
        setCurrentPage(1)
    }, [search, users])

    const totalPages = Math.ceil(filteredUsers.length / itemsPerPage)
    const paginatedUsers = filteredUsers.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage)

    const handleEditClick = (user: UserAccess) => {
        setEditingUser(user.id)
        setTempLevel(user.access_level)
        setTempFullName(user.full_name || '')
        setTempNomeCompleto(user.nomecompleto || '')
    }

    const handleCancelEdit = () => {
        setEditingUser(null)
    }

    const handleSave = async (userId: string) => {
        try {
            const updates = {
                access_level: tempLevel,
                full_name: tempFullName,
                nomecompleto: tempNomeCompleto
            }

            const { error } = await supabase
                .from('users_access')
                .update(updates)
                .eq('id', userId)

            if (error) throw error

            setUsers(prev => prev.map(u => u.id === userId ? { ...u, ...updates } : u))
            setEditingUser(null)
        } catch (error) {
            console.error('Erro ao atualizar usuário', error)
            alert('Erro ao atualizar usuário.')
        }
    }

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-slate-50">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-500"></div>
            </div>
        )
    }

    return (
        <div className="min-h-screen bg-slate-50 font-sans text-slate-800">
            <header className="bg-white border-b border-slate-200 py-3 px-4 sticky top-0 z-10 shadow-sm">
                <div className="max-w-7xl mx-auto flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <Link href="/" className="p-1.5 hover:bg-slate-100 rounded-full transition-colors text-slate-500">
                            <ArrowLeft size={18} />
                        </Link>
                        <div>
                            <h1 className="text-lg font-bold text-slate-800 flex items-center gap-2 leading-none">
                                <User className="text-orange-500" size={20} />
                                Gestão de Usuários
                            </h1>
                        </div>
                    </div>
                    <div className="flex items-center gap-2">
                        {/* Search Bar - Compact */}
                        <div className="relative hidden sm:block">
                            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                            <input
                                type="text"
                                placeholder="Pesquisar..."
                                value={search}
                                onChange={e => setSearch(e.target.value)}
                                className="pl-8 pr-3 py-1.5 bg-slate-100 border-none rounded-lg text-sm focus:ring-1 focus:ring-orange-500 outline-none w-48 transition-all focus:w-64"
                            />
                        </div>
                        <span className="px-2 py-1 bg-orange-100 text-orange-700 rounded-md text-[10px] font-bold border border-orange-200 flex items-center gap-1 uppercase tracking-wider">
                            <Shield size={10} />
                            Admin
                        </span>
                    </div>
                </div>
                {/* Mobile Search */}
                <div className="mt-3 sm:hidden px-1">
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                        <input
                            type="text"
                            placeholder="Pesquisar usuário..."
                            value={search}
                            onChange={e => setSearch(e.target.value)}
                            className="w-full pl-9 pr-3 py-2 bg-slate-100 border-none rounded-lg text-sm focus:ring-1 focus:ring-orange-500 outline-none"
                        />
                    </div>
                </div>
            </header>

            <main className="max-w-7xl mx-auto px-4 py-6">

                {/* Pagination Controls Top */}
                {totalPages > 1 && (
                    <div className="flex justify-between items-center mb-4 text-xs font-medium text-slate-500">
                        <span>Mostrando {paginatedUsers.length} de {filteredUsers.length} usuários</span>
                        <div className="flex items-center gap-1">
                            <button
                                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                                disabled={currentPage === 1}
                                className="p-1 rounded hover:bg-slate-200 disabled:opacity-50 disabled:hover:bg-transparent"
                            >
                                <ChevronLeft size={16} />
                            </button>
                            <span>Pág {currentPage} / {totalPages}</span>
                            <button
                                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                                disabled={currentPage === totalPages}
                                className="p-1 rounded hover:bg-slate-200 disabled:opacity-50 disabled:hover:bg-transparent"
                            >
                                <ChevronRight size={16} />
                            </button>
                        </div>
                    </div>
                )}

                <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                    <div className="overflow-x-auto">
                        <table className="w-full text-left text-sm whitespace-nowrap">
                            <thead className="bg-slate-50 border-b border-slate-200">
                                <tr>
                                    <th className="px-4 py-3 font-bold text-slate-500 uppercase tracking-wider text-[10px]">Nome Completo (Sistema)</th>
                                    <th className="px-4 py-3 font-bold text-slate-500 uppercase tracking-wider text-[10px]">Full Name (Auth)</th>
                                    <th className="px-4 py-3 font-bold text-slate-500 uppercase tracking-wider text-[10px]">ID / Email</th>
                                    <th className="px-4 py-3 font-bold text-slate-500 uppercase tracking-wider text-[10px]">Nível</th>
                                    <th className="px-4 py-3 font-bold text-slate-500 uppercase tracking-wider text-[10px] text-right">Ações</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                                {paginatedUsers.map((user) => (
                                    <tr key={user.id} className="hover:bg-slate-50 transition-colors group">
                                        <td className="px-4 py-3">
                                            {editingUser === user.id ? (
                                                <input
                                                    type="text"
                                                    value={tempNomeCompleto}
                                                    onChange={e => setTempNomeCompleto(e.target.value)}
                                                    className="w-full border border-indigo-300 rounded px-2 py-1 text-xs focus:ring-1 focus:ring-indigo-500 outline-none"
                                                    placeholder="Nome completo..."
                                                />
                                            ) : (
                                                <span className="font-bold text-slate-800 text-xs block">
                                                    {user.nomecompleto || '-'}
                                                </span>
                                            )}
                                        </td>
                                        <td className="px-4 py-3">
                                            {editingUser === user.id ? (
                                                <input
                                                    type="text"
                                                    value={tempFullName}
                                                    onChange={e => setTempFullName(e.target.value)}
                                                    className="w-full border border-indigo-300 rounded px-2 py-1 text-xs focus:ring-1 focus:ring-indigo-500 outline-none"
                                                    placeholder="Full name..."
                                                />
                                            ) : (
                                                <span className="text-slate-600 text-xs block">
                                                    {user.full_name || '-'}
                                                </span>
                                            )}
                                        </td>
                                        <td className="px-4 py-3">
                                            <div className="flex flex-col">
                                                {user.email && <span className="text-slate-600 text-xs">{user.email}</span>}
                                                <span className="font-mono text-[10px] text-slate-400 truncate w-24" title={user.id}>
                                                    {user.id}
                                                </span>
                                            </div>
                                        </td>
                                        <td className="px-4 py-3">
                                            {editingUser === user.id ? (
                                                <select
                                                    value={tempLevel}
                                                    onChange={(e) => setTempLevel(Number(e.target.value))}
                                                    className="border border-indigo-300 rounded px-2 py-1 text-xs bg-indigo-50 focus:ring-1 focus:ring-indigo-500 outline-none w-24"
                                                >
                                                    <option value={0}>0 - Visitante</option>
                                                    <option value={1}>1 - Secretaria</option>
                                                    <option value={2}>2 - Coordenação</option>
                                                    <option value={3}>3 - Coord. Especial</option>
                                                    <option value={4}>4 - Admin</option>
                                                </select>
                                            ) : (
                                                <span className={`inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold uppercase border ${user.access_level === 4 ? 'bg-orange-50 text-orange-700 border-orange-100' :
                                                    user.access_level === 3 ? 'bg-purple-50 text-purple-700 border-purple-100' :
                                                        user.access_level === 2 ? 'bg-blue-50 text-blue-700 border-blue-100' :
                                                            user.access_level === 1 ? 'bg-emerald-50 text-emerald-700 border-emerald-100' :
                                                                'bg-slate-100 text-slate-500 border-slate-200'
                                                    }`}>
                                                    Nível {user.access_level}
                                                </span>
                                            )}
                                        </td>
                                        <td className="px-4 py-3 text-right">
                                            {editingUser === user.id ? (
                                                <div className="flex items-center justify-end gap-2">
                                                    <button
                                                        onClick={() => handleSave(user.id)}
                                                        className="p-1.5 bg-green-100 text-green-700 rounded hover:bg-green-200 transition-colors"
                                                        title="Salvar"
                                                    >
                                                        <Save size={14} />
                                                    </button>
                                                    <button
                                                        onClick={handleCancelEdit}
                                                        className="p-1.5 bg-red-100 text-red-700 rounded hover:bg-red-200 transition-colors"
                                                        title="Cancelar"
                                                    >
                                                        <X size={14} />
                                                    </button>
                                                </div>
                                            ) : (
                                                <button
                                                    onClick={() => handleEditClick(user)}
                                                    className="text-indigo-600 hover:text-indigo-800 text-xs font-bold hover:bg-indigo-50 px-2 py-1 rounded transition-colors"
                                                >
                                                    Editar
                                                </button>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>

                    {users.length === 0 && (
                        <div className="p-12 text-center text-slate-400 font-medium flex flex-col items-center">
                            <AlertCircle size={32} className="mb-2 opacity-50" />
                            Nenhum usuário encontrado.
                        </div>
                    )}
                    {users.length > 0 && filteredUsers.length === 0 && (
                        <div className="p-12 text-center text-slate-400 font-medium">
                            Nenhum usuário corresponde à pesquisa.
                        </div>
                    )}
                </div>
            </main>
        </div>
    )
}
