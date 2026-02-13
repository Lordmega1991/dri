'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabaseClient'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import {
    Plus,
    Calendar,
    Edit,
    Trash2,
    BarChart2,
    FileText,
    Clock,
    ArrowLeft,
    X,
    Check,
    BookOpen,
    LogOut
} from 'lucide-react'
import clsx from 'clsx'

type Semestre = {
    id: number
    ano: number
    semestre: number
    data_inicio: string | null
    data_fim: string | null
    status?: string // Vamos computar isso no front
}

// Modal Component
const SemesterModal = ({ isOpen, onClose, onSave, editingSemester }: any) => {
    const [ano, setAno] = useState(new Date().getFullYear())
    const [semestre, setSemestre] = useState(1)
    const [inicio, setInicio] = useState('')
    const [fim, setFim] = useState('')
    const [saving, setSaving] = useState(false)

    useEffect(() => {
        if (editingSemester) {
            setAno(editingSemester.ano)
            setSemestre(editingSemester.semestre)
            setInicio(editingSemester.data_inicio || '')
            setFim(editingSemester.data_fim || '')
        } else {
            setAno(new Date().getFullYear())
            setSemestre(1)
            setInicio('')
            setFim('')
        }
    }, [editingSemester, isOpen])

    if (!isOpen) return null

    const handleSubmit = async (e: any) => {
        e.preventDefault()
        setSaving(true)
        await onSave({
            id: editingSemester?.id,
            ano,
            semestre,
            data_inicio: inicio || null,
            data_fim: fim || null
        })
        setSaving(false)
        onClose()
    }

    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl overflow-hidden animate-in fade-in zoom-in duration-200">
                <div className="bg-gradient-to-r from-indigo-600 to-indigo-800 p-6">
                    <h3 className="text-white font-bold text-lg flex items-center">
                        <Calendar className="mr-2" size={20} />
                        {editingSemester ? 'Editar Semestre' : 'Novo Semestre'}
                    </h3>
                </div>

                <form onSubmit={handleSubmit} className="p-6 space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Ano</label>
                            <input
                                type="number"
                                value={ano}
                                onChange={e => setAno(parseInt(e.target.value))}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Semestre</label>
                            <select
                                value={semestre}
                                onChange={e => setSemestre(parseInt(e.target.value))}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none bg-white"
                            >
                                <option value={1}>1</option>
                                <option value={2}>2</option>
                            </select>
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Início</label>
                            <input
                                type="date"
                                value={inicio}
                                onChange={e => setInicio(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Fim</label>
                            <input
                                type="date"
                                value={fim}
                                onChange={e => setFim(e.target.value)}
                                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
                            />
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
                            {saving ? 'Salvando...' : editingSemester ? 'Salvar Alterações' : 'Criar Semestre'}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    )
}

export default function SemestresPage() {
    const router = useRouter()
    const [user, setUser] = useState<any>(null)
    const [semestres, setSemestres] = useState<Semestre[]>([])
    const [visibleSemestres, setVisibleSemestres] = useState<Semestre[]>([])
    const [finalizados, setFinalizados] = useState<Semestre[]>([])
    const [pinnedIds, setPinnedIds] = useState<number[]>([])
    const [selectedHistoryId, setSelectedHistoryId] = useState<string>('')
    const [hiddenIds, setHiddenIds] = useState<number[]>([])
    const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)
    const [isLoaded, setIsLoaded] = useState(false)

    useEffect(() => {
        const checkSession = async () => {
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) {
                router.push('/login')
                return
            }
            setUser(session.user)

            // Check Access Level (Needs 2+)
            const { data: accessData } = await supabase
                .from('users_access')
                .select('access_level')
                .eq('id', session.user.id)
                .single()

            if (!accessData || accessData.access_level < 2) {
                router.push('/') // Redirect unauthorized to home
                return
            }
            setUserAccessLevel(accessData.access_level)
        }
        checkSession()
    }, [router])

    const handleLogout = async () => {
        await supabase.auth.signOut()
        router.push('/login')
    }

    const firstName = user?.user_metadata?.full_name?.split(' ')[0] || 'Usuário'

    // Load persisted state from localStorage ONCE on mount
    useEffect(() => {
        const savedPinned = localStorage.getItem('pinned_semestres')
        const savedHidden = localStorage.getItem('hidden_semestres')
        if (savedPinned) setPinnedIds(JSON.parse(savedPinned))
        if (savedHidden) setHiddenIds(JSON.parse(savedHidden))
        setIsLoaded(true)
    }, [])

    // Save state to localStorage ONLY AFTER initial load and when state changes
    useEffect(() => {
        if (isLoaded) {
            localStorage.setItem('pinned_semestres', JSON.stringify(pinnedIds))
        }
    }, [pinnedIds, isLoaded])

    useEffect(() => {
        if (isLoaded) {
            localStorage.setItem('hidden_semestres', JSON.stringify(hiddenIds))
        }
    }, [hiddenIds, isLoaded])

    const [loading, setLoading] = useState(true)
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [editingSemester, setEditingSemester] = useState<any>(null)

    useEffect(() => {
        fetchSemestres()
    }, [pinnedIds, hiddenIds])

    const fetchSemestres = async () => {
        try {
            const { data, error } = await supabase
                .from('semestres')
                .select('*')
                .order('ano', { ascending: false })
                .order('semestre', { ascending: false })

            if (error) throw error

            if (data) {
                const now = new Date()
                const processed = data.map((s: any) => {
                    let status = 'Finalizado'
                    if (s.data_inicio && s.data_fim) {
                        const start = new Date(s.data_inicio)
                        const end = new Date(s.data_fim)
                        if (now >= start && now <= end) status = 'Ativo'
                        else if (now < start) status = 'Planejamento'
                        else status = 'Finalizado'
                    } else {
                        // Lógica de fallback se não tiver datas:
                        // Se for o primeiro da lista (mais recente), assume Planejamento ou Ativo
                        if (s === data[0]) status = 'Planejamento'
                    }
                    return { ...s, status }
                })

                setSemestres(processed)

                // Separa os que devem aparecer por padrão ou estão fixados, DESDE QUE não estejam ocultos
                const activeOrPlanned = processed.filter((s: any) =>
                    !hiddenIds.includes(s.id) &&
                    (s.status !== 'Finalizado' || pinnedIds.includes(s.id))
                )

                // O "Histórico" (Dropdown) contém tudo o que NÃO está na tela
                const activeOrPlannedIds = activeOrPlanned.map((s: any) => s.id)
                const done = processed.filter((s: any) => !activeOrPlannedIds.includes(s.id))

                setVisibleSemestres(activeOrPlanned)
                setFinalizados(done)
            }
        } catch (error) {
            console.error('Erro ao buscar semestres', error)
        } finally {
            setLoading(false)
        }
    }

    const handleHistorySelect = (id: string) => {
        if (!id) return
        const semester = finalizados.find(s => s.id.toString() === id)
        if (semester) {
            setPinnedIds(prev => [...new Set([...prev, semester.id])])
            setHiddenIds(prev => prev.filter(hid => hid !== semester.id))
        }
        setSelectedHistoryId('') // Reseta o seletor imediatamente
    }

    const handleSaveSemester = async (data: any) => {
        try {
            if (data.id) {
                const { error } = await supabase
                    .from('semestres')
                    .update({
                        ano: data.ano,
                        semestre: data.semestre,
                        data_inicio: data.data_inicio,
                        data_fim: data.data_fim
                    })
                    .eq('id', data.id)
                if (error) throw error
            } else {
                const { error } = await supabase
                    .from('semestres')
                    .insert({
                        ano: data.ano,
                        semestre: data.semestre,
                        data_inicio: data.data_inicio,
                        data_fim: data.data_fim
                    })
                if (error) throw error
            }
            fetchSemestres()
        } catch (err: any) {
            alert('Erro: ' + err.message)
        }
    }

    const handlePinSemester = (id: number) => {
        setPinnedIds(prev => [...prev, id])
        setHiddenIds(prev => prev.filter(hid => hid !== id)) // Se estava oculto, remove dos ocultos
        setSelectedHistoryId('') // Limpa a seleção após fixar
    }

    const handleHide = (id: number) => {
        // Se estiver nos fixados, apenas remove dos fixados (volta para o histórico)
        if (pinnedIds.includes(id)) {
            setPinnedIds(prev => prev.filter(pid => pid !== id))
        } else {
            // Se for um ativo/planejamento, move para a lista de ocultos
            setHiddenIds(prev => [...prev, id])
        }
    }

    const openModal = (sem: any = null) => {
        setEditingSemester(sem)
        setIsModalOpen(true)
    }

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-gray-900 font-sans antialiased selection:bg-indigo-100 selection:text-indigo-900">
            <SemesterModal
                isOpen={isModalOpen}
                onClose={() => setIsModalOpen(false)}
                onSave={handleSaveSemester}
                editingSemester={editingSemester}
            />

            {/* Dynamic Background */}
            <div className="fixed inset-0 z-0 pointer-events-none opacity-40">
                <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-blue-100 blur-[120px]" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-100 blur-[120px]" />
            </div>

            <nav className="relative z-20 px-4 py-4 md:px-12 flex justify-between items-center max-w-7xl mx-auto">
                <div className="flex items-center space-x-3">
                    <Link href="/" className="group flex items-center gap-4">
                        <div className="w-10 h-10 md:w-12 md:h-12 bg-white rounded-xl md:rounded-2xl flex items-center justify-center shadow-sm border border-slate-200 text-slate-600 group-hover:text-indigo-600 group-hover:border-indigo-100 group-hover:scale-105 transition-all">
                            <ArrowLeft size={22} />
                        </div>
                        <span className="font-extrabold text-lg md:text-2xl text-slate-900 tracking-tight">
                            Gerenciamento de <span className="text-indigo-600">Semestres</span>
                        </span>
                    </Link>
                </div>

                <div className="flex items-center bg-white/60 backdrop-blur-md rounded-full px-3 py-1.5 md:px-4 md:py-2 shadow-sm border border-white/50">
                    <div className="text-xs md:text-sm mr-2 md:mr-4 text-right leading-tight">
                        <span className="text-gray-500 block md:inline md:mr-1">Olá,</span>
                        <span className="font-bold text-gray-800">{firstName}</span>
                    </div>
                    <button
                        onClick={handleLogout}
                        className="w-7 h-7 md:w-8 md:h-8 bg-gray-100 text-gray-500 rounded-full flex items-center justify-center hover:bg-red-50 hover:text-red-600 transition-all border border-gray-200 hover:border-red-200"
                        title="Sair"
                    >
                        <LogOut size={14} />
                    </button>
                </div>
            </nav>

            <main className="relative z-20 px-4 md:px-12 max-w-7xl mx-auto pb-20 pt-8">

                <div className="flex flex-col md:flex-row md:justify-between md:items-center mb-6 gap-4 border-b border-gray-200/60 pb-6">
                    <div>
                        <h2 className="text-xl font-bold text-slate-900">Períodos Letivos</h2>
                        <p className="text-slate-500 text-sm mt-0.5">Gerencie a oferta corrente e histórico.</p>
                    </div>
                    <div className="flex gap-2 items-center">
                        {userAccessLevel !== 2 && (
                            <Link
                                href="/disciplinas"
                                className="bg-white border border-gray-200 text-slate-600 hover:bg-gray-50 px-4 py-2 rounded-xl text-sm font-bold flex items-center shadow-sm transition-all active:scale-95"
                            >
                                <BookOpen size={16} className="mr-2 text-indigo-600" />
                                Catálogo de Disciplinas
                            </Link>
                        )}
                        {userAccessLevel !== 2 && (
                            <button
                                onClick={() => openModal(null)}
                                className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-xl text-sm font-bold flex items-center shadow-lg hover:shadow-indigo-200 transition-all active:scale-95"
                            >
                                <Plus size={16} className="mr-2" />
                                Novo
                            </button>
                        )}
                    </div>
                </div>

                {loading ? (
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2.5">
                        {[1, 2].map(i => (
                            <div key={i} className="h-48 bg-white/50 rounded-[1.25rem] animate-pulse border border-gray-100"></div>
                        ))}
                    </div>
                ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2.5">

                        {/* Render Active/Planned/Selected Semesters */}
                        {visibleSemestres.map((sem) => (
                            <div key={sem.id} className={clsx(
                                "bg-white rounded-[1.25rem] border shadow-sm hover:shadow-md transition-all overflow-hidden group hover:-translate-y-0.5 relative",
                                sem.status === 'Finalizado' ? "border-gray-200 bg-gray-50/50" : "border-gray-100"
                            )}>
                                {sem.status === 'Finalizado' && (
                                    <div className="absolute top-0 right-0 bg-gray-100 text-gray-500 text-[10px] font-bold px-3 py-1 rounded-bl-xl z-10 border-b border-l border-gray-200">
                                        HISTÓRICO
                                    </div>
                                )}

                                <div className="p-4">
                                    <div className="flex justify-between items-start mb-3">
                                        <div>
                                            <h3 className="text-2xl font-extrabold text-slate-900 tracking-tight">{sem.ano}.{sem.semestre}</h3>
                                            <div className={clsx(
                                                "mt-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide w-fit border",
                                                sem.status === 'Ativo'
                                                    ? "bg-emerald-50 text-emerald-700 border-emerald-100"
                                                    : sem.status === 'Planejamento'
                                                        ? "bg-amber-50 text-amber-700 border-amber-100"
                                                        : "bg-gray-100 text-gray-600 border-gray-200"
                                            )}>
                                                {sem.status}
                                            </div>
                                        </div>
                                        <div className={clsx("p-2 rounded-xl", sem.status === 'Finalizado' ? "bg-gray-100 text-gray-400" : "bg-indigo-50 text-indigo-600")}>
                                            <Calendar size={20} />
                                        </div>
                                    </div>

                                    {/* Dates Info */}
                                    <div className="mb-4 text-xs text-slate-500 space-y-1">
                                        <div className="flex items-center">
                                            <span className="w-12 font-semibold">Início:</span>
                                            <span className="font-medium text-slate-700">
                                                {sem.data_inicio ? new Date(sem.data_inicio).toLocaleDateString() : '-'}
                                            </span>
                                        </div>
                                        <div className="flex items-center">
                                            <span className="w-12 font-semibold">Fim:</span>
                                            <span className="font-medium text-slate-700">
                                                {sem.data_fim ? new Date(sem.data_fim).toLocaleDateString() : '-'}
                                            </span>
                                        </div>
                                    </div>

                                    {/* Actions */}
                                    <div className="space-y-1.5 border-t border-gray-50 pt-3">
                                        <Link href={`/semestre/${sem.ano}.${sem.semestre}/grade`} className="flex items-center justify-between p-2 rounded-lg hover:bg-indigo-50 group-hover:bg-indigo-50/50 transition-colors">
                                            <div className="flex items-center text-slate-700 text-xs font-bold">
                                                <div className="w-6 h-6 rounded-md bg-indigo-100 text-indigo-600 flex items-center justify-center mr-2">
                                                    <Clock size={14} />
                                                </div>
                                                Grade Horária
                                            </div>
                                            <ArrowLeft size={14} className="rotate-180 text-slate-300 group-hover:text-indigo-400" />
                                        </Link>

                                        <Link href={`/semestre/${sem.ano}.${sem.semestre}/simulacao`} className="flex items-center justify-between p-2 rounded-lg hover:bg-green-50 transition-colors">
                                            <div className="flex items-center text-slate-700 text-xs font-bold hover:text-green-800">
                                                <div className="w-6 h-6 rounded-md bg-green-100 text-green-600 flex items-center justify-center mr-2">
                                                    <BarChart2 size={14} />
                                                </div>
                                                Simulação CH
                                            </div>
                                            <ArrowLeft size={14} className="rotate-180 text-slate-300" />
                                        </Link>

                                        <Link href={`/semestre/${sem.ano}.${sem.semestre}/relatorios`} className="flex items-center justify-between p-2 rounded-lg hover:bg-orange-50 transition-colors">
                                            <div className="flex items-center text-slate-700 text-xs font-bold hover:text-orange-800">
                                                <div className="w-6 h-6 rounded-md bg-orange-100 text-orange-600 flex items-center justify-center mr-2">
                                                    <FileText size={14} />
                                                </div>
                                                Relatórios
                                            </div>
                                            <ArrowLeft size={14} className="rotate-180 text-slate-300" />
                                        </Link>
                                    </div>
                                </div>

                                <div className="bg-gray-50/80 px-4 py-2 border-t border-gray-100 flex justify-between items-center text-[10px] text-gray-400 font-bold uppercase tracking-wider">
                                    <span>ID: {sem.id}</span>
                                    {userAccessLevel !== 2 && (
                                        <div className="flex space-x-1 opacity-100 transition-opacity">
                                            <button
                                                onClick={() => openModal(sem)}
                                                className="p-1.5 hover:bg-gray-200 rounded text-gray-500" title="Editar Datas"
                                            >
                                                <Edit size={12} />
                                            </button>
                                            <button
                                                onClick={() => handleHide(sem.id)}
                                                className="p-1.5 hover:bg-gray-200 rounded text-gray-400 hover:text-gray-600"
                                                title="Remover da visualização"
                                            >
                                                <X size={12} />
                                            </button>
                                        </div>
                                    )}
                                </div>
                            </div>
                        ))}

                        {/* History Card Selector */}
                        {finalizados.length > 0 && (
                            <div className="bg-white/40 rounded-[1.25rem] border-2 border-dashed border-gray-200 flex flex-col justify-center items-center p-4 text-center hover:bg-white/60 transition-colors">
                                <div className="w-10 h-10 bg-gray-100 rounded-full flex items-center justify-center text-gray-400 mb-2">
                                    <Clock size={20} />
                                </div>
                                <h3 className="text-sm font-bold text-slate-600">Acessar Histórico</h3>
                                <p className="text-xs text-slate-400 mb-3 max-w-[150px]">
                                    Visualize semestres anteriores.
                                </p>

                                <select
                                    value={selectedHistoryId}
                                    onChange={(e) => handleHistorySelect(e.target.value)}
                                    className="w-full max-w-[180px] p-1.5 bg-white border border-gray-200 rounded-lg text-xs font-medium focus:ring-2 focus:ring-indigo-500 outline-none text-slate-600"
                                >
                                    <option value="">Selecione...</option>
                                    {finalizados.map(f => (
                                        <option key={f.id} value={f.id}>{f.ano}.{f.semestre}</option>
                                    ))}
                                </select>
                            </div>
                        )}
                    </div>
                )}
            </main>
        </div>
    )
}
