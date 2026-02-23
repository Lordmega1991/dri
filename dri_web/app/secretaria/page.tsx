'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    User,
    Search,
    X,
    Loader2,
    IdCard,
    Edit3,
    School,
    LogOut,
    FilePlus,
    ArrowUpRight
} from 'lucide-react'
import clsx from 'clsx'
import { fetchSigaaStudents } from '../tcc/cadastrar/actions'

export default function SecretariaPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [saving, setSaving] = useState(false)
    const [userAuth, setUserAuth] = useState<any>(null)
    const [accessData, setAccessData] = useState<any>(null)
    const [isEditing, setIsEditing] = useState(false)

    const [nome, setNome] = useState('')
    const [matricula, setMatricula] = useState('')

    // SIGAA Modal
    const [studentModalOpen, setStudentModalOpen] = useState(false)
    const [sigaaStudents, setSigaaStudents] = useState<{ nome: string, matricula: string }[]>([])
    const [fetchingStudents, setFetchingStudents] = useState(false)
    const [studentSearch, setStudentSearch] = useState('')

    useEffect(() => {
        const loadUserData = async () => {
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) {
                window.location.href = '/login'
                return
            }
            setUserAuth(session.user)

            const { data: access } = await supabase
                .from('users_access')
                .select('*')
                .eq('id', session.user.id)
                .single()

            if (access) {
                setAccessData(access)
                setNome(access.nomecompleto || '')
                setMatricula(access.matricula?.toString() || '')
                setIsEditing(!(access.nomecompleto && access.matricula))
            }
            setLoading(false)
        }
        loadUserData()
    }, [])

    const openSigaaSearch = async () => {
        setStudentModalOpen(true)
        if (sigaaStudents.length === 0) {
            setFetchingStudents(true)
            const result = await fetchSigaaStudents()
            if (result.data) {
                setSigaaStudents(result.data)
            } else if (result.fallback) {
                setSigaaStudents(result.fallback)
            }
            setFetchingStudents(false)
        }
    }

    const selectStudent = (student: { nome: string, matricula: string }) => {
        setNome(student.nome)
        setMatricula(student.matricula)
        setStudentModalOpen(false)
    }

    const handleSave = async (e: React.FormEvent) => {
        e.preventDefault()
        if (!userAuth) return
        setSaving(true)
        try {
            const { error } = await supabase
                .from('users_access')
                .update({ nomecompleto: nome, matricula: matricula ? parseFloat(matricula) : null })
                .eq('id', userAuth.id)
            if (error) throw error
            setAccessData({ ...accessData, nomecompleto: nome, matricula: matricula })
            setIsEditing(false)
        } catch (err) {
            console.error(err)
            alert('Erro ao salvar.')
        } finally {
            setSaving(false)
        }
    }

    const filteredStudents = sigaaStudents.filter(s =>
        s.nome.toLowerCase().includes(studentSearch.toLowerCase()) ||
        s.matricula.includes(studentSearch)
    )

    const handleLogout = async () => {
        await supabase.auth.signOut()
        window.location.href = '/login'
    }

    const navigateTo = (href: string) => () => {
        window.location.href = href
    }

    if (loading) return (
        <div className="min-h-screen flex items-center justify-center bg-[#F5F5F7]">
            <Loader2 className="animate-spin text-indigo-600" size={32} />
        </div>
    )

    const firstName = userAuth?.user_metadata?.full_name?.split(' ')[0] || 'Aluno'

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-slate-800 font-sans antialiased">
            <div className="fixed inset-0 z-0 pointer-events-none opacity-30">
                <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-100 blur-[120px]" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-blue-100 blur-[120px]" />
            </div>

            {/* Modal SIGAA */}
            {studentModalOpen && (
                <div className="fixed inset-0 z-[60] flex items-center justify-center p-6 bg-slate-900/30 backdrop-blur-[2px]">
                    <div className="bg-white w-full max-w-lg rounded-3xl shadow-2xl border border-slate-100 overflow-hidden flex flex-col max-h-[80vh] animate-in zoom-in-95 duration-200">
                        <div className="px-8 py-6 border-b border-slate-50 flex items-center justify-between bg-indigo-50/30 font-black uppercase text-sm italic">
                            BUSCA SIGAA
                            <button onClick={() => setStudentModalOpen(false)} className="p-2 hover:bg-white rounded-full transition-colors text-slate-400">
                                <X size={20} />
                            </button>
                        </div>
                        <div className="p-6">
                            <input
                                autoFocus
                                type="text"
                                placeholder="Nome ou matrícula..."
                                className="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl text-xs font-bold text-slate-700 outline-none focus:ring-4 focus:ring-indigo-50 uppercase"
                                value={studentSearch}
                                onChange={e => setStudentSearch(e.target.value)}
                            />
                        </div>
                        <div className="flex-1 overflow-y-auto px-4 pb-6">
                            {fetchingStudents ? (
                                <div className="py-20 flex flex-col items-center text-slate-300">
                                    <Loader2 className="animate-spin mb-4 text-indigo-500" size={32} />
                                    <p className="text-[10px] font-black uppercase tracking-[3px]">Buscando...</p>
                                </div>
                            ) : (
                                <div className="grid gap-2">
                                    {filteredStudents.map((student, i) => (
                                        <button
                                            key={i}
                                            onClick={() => selectStudent(student)}
                                            className="w-full text-left p-4 rounded-3xl hover:bg-indigo-50 group flex justify-between items-center transition-all bg-white border border-slate-100 shadow-sm active:scale-95"
                                        >
                                            <div>
                                                <p className="font-black text-slate-800 text-xs uppercase">{student.nome}</p>
                                                <p className="text-[10px] text-indigo-500 font-bold">{student.matricula}</p>
                                            </div>
                                        </button>
                                    ))}
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}

            <nav className="relative z-20 px-6 py-4 flex justify-between items-center max-w-7xl mx-auto">
                <button onClick={navigateTo('/')} className="flex items-center gap-4 group text-left">
                    <div className="w-10 h-10 bg-white border border-slate-200 rounded-xl flex items-center justify-center text-slate-400 group-hover:text-indigo-600 group-hover:border-indigo-100 transition-all shadow-sm">
                        <ArrowLeft size={20} />
                    </div>
                    <div className="flex flex-col">
                        <span className="font-black text-lg tracking-tight text-slate-900 uppercase italic leading-none">
                            Minha <span className="text-indigo-600">Secretaria</span>
                        </span>
                        <span className="text-[8px] font-black uppercase tracking-[2px] text-slate-400">Portal do Aluno</span>
                    </div>
                </button>

                <div className="flex items-center bg-white shadow-sm border border-slate-200 rounded-full px-4 py-2">
                    <div className="text-xs mr-4 text-right">
                        <span className="text-slate-400 font-bold uppercase tracking-widest text-[10px]">Olá, </span>
                        <span className="font-black text-slate-800 block md:inline">{firstName}</span>
                    </div>
                    <button onClick={handleLogout} className="text-slate-400 hover:text-red-500 transition-colors">
                        <LogOut size={18} />
                    </button>
                </div>
            </nav>

            <main className="relative z-20 px-6 max-w-7xl mx-auto py-8 space-y-8">
                {/* Perfil Header */}
                <div className="bg-white rounded-[2rem] p-8 border border-slate-200 shadow-xl shadow-slate-200/40 flex flex-col md:flex-row items-center justify-between gap-6">
                    <div className="flex flex-col md:flex-row items-center gap-6 text-center md:text-left">
                        <div className="w-20 h-20 bg-indigo-600 text-white rounded-3xl flex items-center justify-center shadow-lg">
                            <User size={40} />
                        </div>
                        <div>
                            {isEditing ? (
                                <h2 className="text-2xl font-black text-slate-900 uppercase italic">Identificação</h2>
                            ) : (
                                <>
                                    <h2 className="text-2xl font-black text-slate-900 uppercase">{accessData?.nomecompleto || 'Sem Nome'}</h2>
                                    <div className="flex items-center justify-center md:justify-start gap-4 text-[11px] font-bold text-slate-400 uppercase tracking-widest mt-2">
                                        <span className="flex items-center gap-1.5"><IdCard size={14} className="text-indigo-500" /> {accessData?.matricula || '---'}</span>
                                        <span className="flex items-center gap-1.5"><School size={14} className="text-indigo-500" /> DRI UFPB</span>
                                    </div>
                                </>
                            )}
                        </div>
                    </div>

                    {!isEditing && (
                        <button
                            onClick={() => setIsEditing(true)}
                            className="bg-slate-50 border border-slate-200 text-slate-600 px-6 py-3 rounded-2xl font-black text-[12px] uppercase tracking-widest hover:bg-white hover:text-indigo-600 transition-all active:scale-95"
                        >
                            <Edit3 size={16} className="inline mr-2" /> Editar Perfil
                        </button>
                    )}
                </div>

                {isEditing ? (
                    <div className="bg-white rounded-3xl p-8 border border-slate-200 shadow-sm max-w-2xl mx-auto transition-all animate-in slide-in-from-bottom-4">
                        <form onSubmit={handleSave} className="space-y-6">
                            <div className="space-y-4">
                                <div className="relative">
                                    <input
                                        required
                                        type="text"
                                        placeholder="Nome Completo *"
                                        className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-5 px-6 pr-24 text-sm font-black text-slate-700 outline-none focus:border-indigo-400 transition-all uppercase"
                                        value={nome}
                                        onChange={e => setNome(e.target.value)}
                                    />
                                    <button
                                        type="button"
                                        onClick={openSigaaSearch}
                                        className="absolute right-3 top-1/2 -translate-y-1/2 bg-indigo-600 text-white px-4 py-2 rounded-xl text-[10px] font-black uppercase hover:bg-indigo-700 active:scale-95"
                                    >
                                        SIGAA
                                    </button>
                                </div>
                                <input
                                    required
                                    type="text"
                                    placeholder="Matrícula *"
                                    className="w-full bg-slate-50 border border-slate-100 rounded-2xl py-5 px-6 text-sm font-black text-slate-700 outline-none focus:border-indigo-400 transition-all"
                                    value={matricula}
                                    onChange={e => setMatricula(e.target.value)}
                                />
                            </div>
                            <div className="flex gap-3">
                                <button type="submit" disabled={saving} className="flex-1 bg-slate-900 text-white py-5 rounded-2xl font-black text-xs uppercase tracking-widest hover:bg-black transition-all active:scale-95 disabled:opacity-50">
                                    {saving ? <Loader2 className="animate-spin mx-auto" size={20} /> : 'Salvar Alterações'}
                                </button>
                                <button type="button" onClick={() => setIsEditing(false)} className="px-8 py-5 bg-white border border-slate-200 rounded-2xl font-black text-xs uppercase tracking-widest active:scale-95">
                                    Cancelar
                                </button>
                            </div>
                        </form>
                    </div>
                ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        <button
                            onClick={navigateTo('/secretaria/envio-tcc')}
                            className="group relative overflow-hidden rounded-[1.25rem] p-6 flex flex-col justify-between text-left transition-all bg-white border border-slate-200 shadow-sm active:scale-[0.98] active:bg-slate-50 min-h-[130px]"
                        >
                            <div className="w-10 h-10 bg-blue-600 text-white rounded-xl flex items-center justify-center shadow-md">
                                <FilePlus size={24} />
                            </div>
                            <div className="mt-4">
                                <h3 className="font-black text-slate-800 uppercase italic text-sm leading-tight">Envio de TCC</h3>
                                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mt-0.5">PDF Final e Termos</p>
                            </div>
                            <div className="absolute right-4 top-4 text-slate-200 group-hover:text-indigo-600">
                                <ArrowUpRight size={22} />
                            </div>
                        </button>
                    </div>
                )}
            </main>
        </div>
    )
}
