'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Save,
    User,
    Users,
    Calendar,
    MapPin,
    BookOpen,
    Key,
    Copy,
    RefreshCw,
    Search,
    List,
    X,
    ExternalLink,
    Loader2,
    CheckCircle2,
    GraduationCap,
    Clock,
    Info,
    Contact,
    School,
    IdCard
} from 'lucide-react'
import clsx from 'clsx'
import { fetchSigaaStudents } from './actions'

export default function CadastrarDefesaPage() {
    const router = useRouter()

    const [loading, setLoading] = useState(false)
    const [fetchingStudents, setFetchingStudents] = useState(false)
    const [studentModalOpen, setStudentModalOpen] = useState(false)
    const [sigaaStudents, setSigaaStudents] = useState<{ nome: string, matricula: string }[]>([])
    const [studentSearch, setStudentSearch] = useState('')
    const [semestresDb, setSemestresDb] = useState<{ label: string, isCurrent: boolean }[]>([])

    const [formData, setFormData] = useState({
        semestre: '',
        dia: '',
        hora: '',
        discente: '',
        matricula: '',
        orientador: '',
        coorientador: '',
        avaliador1: '',
        instituto_av1: '',
        avaliador2: '',
        instituto_av2: '',
        avaliador3: '',
        instituto_av3: '',
        titulo: '',
        local: '',
        login: '',
        senha: ''
    })

    const [docentes, setDocentes] = useState<string[]>([])
    const [instituicoes, setInstituicoes] = useState<string[]>([])

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

            generateCredentials()
            fetchAuxiliaryData()
            fetchSemestres()
        }
        checkAccess()
    }, [])

    const fetchSemestres = async () => {
        try {
            const { data, error } = await supabase
                .from('semestres')
                .select('*')
                .order('ano', { ascending: false })
                .order('semestre', { ascending: false })

            if (error) throw error

            if (data && data.length > 0) {
                const now = new Date()
                const formatted = data.map(s => {
                    const label = `${s.ano}.${s.semestre}`
                    const start = s.data_inicio ? new Date(s.data_inicio) : null
                    const end = s.data_fim ? new Date(s.data_fim) : null
                    const isCurrent = start && end ? (now >= start && now <= end) : false
                    return { label, isCurrent }
                })

                // Find current index
                let currentIndex = formatted.findIndex(s => s.isCurrent)
                if (currentIndex === -1) currentIndex = 0

                // Filter to show Current, Previous (index + 1), and Next (index - 1)
                // Note: data is ordered DESC, so index - 1 is the most recent (next)
                const restricted = formatted.filter((_, idx) =>
                    idx === currentIndex || idx === currentIndex - 1 || idx === currentIndex + 1
                )

                setSemestresDb(restricted)

                // Auto-select current
                const current = restricted.find(s => s.isCurrent)
                if (current) {
                    setFormData(prev => ({ ...prev, semestre: current.label }))
                } else if (restricted.length > 0) {
                    setFormData(prev => ({ ...prev, semestre: restricted[0].label }))
                }
            } else {
                // Fallback hardcoded if table is empty
                const now = new Date()
                const year = now.getFullYear()
                const month = now.getMonth() + 1
                const s1 = month <= 6 ? 1 : 2
                const s2 = s1 === 1 ? 2 : 1
                const y2 = s1 === 2 ? year + 1 : year
                const fallback = [
                    { label: `${year}.${s1}`, isCurrent: true },
                    { label: `${y2}.${s2}`, isCurrent: false }
                ]
                setSemestresDb(fallback)
                setFormData(prev => ({ ...prev, semestre: fallback[0].label }))
            }
        } catch (err) {
            console.error('Error fetching semestres:', err)
        }
    }

    const fetchAuxiliaryData = async () => {
        try {
            const { data: docs } = await supabase.from('diversos').select('item').eq('descricao', 'docente')
            const { data: insts } = await supabase.from('diversos').select('item').eq('descricao', 'instituicao')
            if (docs) setDocentes(docs.map(d => d.item).sort())
            if (insts) setInstituicoes(insts.map(i => i.item).sort())
        } catch (err) {
            console.error('Error fetching auxiliary data:', err)
        }
    }

    const generateCredentials = () => {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
        const gen = (len: number) => Array.from({ length: len }, () => chars.charAt(Math.floor(Math.random() * chars.length))).join('')
        setFormData(prev => ({ ...prev, login: gen(6), senha: gen(6) }))
    }

    const handleOrientadorChange = (val: string) => {
        setFormData(prev => ({ ...prev, orientador: val, avaliador1: val }))
    }

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
        setFormData(prev => ({
            ...prev,
            discente: student.nome,
            matricula: student.matricula
        }))
        setStudentModalOpen(false)
    }

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        try {
            const { error } = await supabase.from('dados_defesas').insert({
                ...formData,
                dia: formData.dia || null,
                hora: formData.hora || null,
                matricula: formData.matricula ? parseInt(formData.matricula) : null,
                coorientador: formData.coorientador || null,
                local: formData.local || null,
                instituto_av1: formData.instituto_av1 || null,
                instituto_av2: formData.instituto_av2 || null,
                instituto_av3: formData.instituto_av3 || null,
            })
            if (error) throw error
            alert('Defesa cadastrada com sucesso!')
            router.push('/tcc/visualizar')
        } catch (err) {
            console.error(err)
            alert('Erro ao salvar defesa')
        } finally {
            setLoading(false)
        }
    }

    const copyCreds = () => {
        const text = `Acesso à Banca de TCC:\nLogin: ${formData.login}\nSenha: ${formData.senha}`
        navigator.clipboard.writeText(text)
        alert('Copiado!')
    }

    const filteredStudents = sigaaStudents.filter(s =>
        s.nome.toLowerCase().includes(studentSearch.toLowerCase()) ||
        s.matricula.includes(studentSearch)
    )

    return (
        <div className="min-h-screen bg-white text-slate-700 font-sans">
            {/* Modal de busca de alunos */}
            {studentModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-6 bg-slate-900/30 backdrop-blur-[1px]">
                    <div className="bg-white w-full max-w-lg rounded-[2rem] shadow-2xl border border-slate-100 overflow-hidden flex flex-col max-h-[80vh]">
                        <div className="px-6 py-4 border-b border-slate-50 flex items-center justify-between">
                            <h3 className="font-bold text-slate-800 flex items-center gap-2">
                                <Search size={18} className="text-indigo-500" />
                                Alunos SIGAA
                            </h3>
                            <button onClick={() => setStudentModalOpen(false)} className="p-1.5 hover:bg-slate-100 rounded-full transition-colors text-slate-400">
                                <X size={18} />
                            </button>
                        </div>
                        <div className="p-4">
                            <input
                                autoFocus
                                type="text"
                                placeholder="Filtrar por nome ou matrícula..."
                                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-sm font-bold text-slate-700 outline-none focus:ring-2 focus:ring-indigo-100"
                                value={studentSearch}
                                onChange={e => setStudentSearch(e.target.value)}
                            />
                        </div>
                        <div className="flex-1 overflow-y-auto px-2 pb-4">
                            {fetchingStudents ? (
                                <div className="flex flex-col items-center justify-center py-20 text-slate-400">
                                    <Loader2 className="animate-spin mb-3 text-indigo-500" size={24} />
                                    <p className="text-xs font-bold uppercase tracking-widest">Buscando...</p>
                                </div>
                            ) : (
                                <div className="grid gap-1 px-2">
                                    {filteredStudents.map((student, i) => (
                                        <button
                                            key={i}
                                            onClick={() => selectStudent(student)}
                                            className="w-full text-left p-3.5 rounded-2xl hover:bg-indigo-50 group flex justify-between items-center transition-colors"
                                        >
                                            <div>
                                                <p className="font-bold text-slate-800 text-xs uppercase">{student.nome}</p>
                                                <p className="text-[10px] text-slate-400 font-bold font-mono">{student.matricula}</p>
                                            </div>
                                            <CheckCircle2 size={16} className="text-indigo-200 group-hover:text-indigo-500" />
                                        </button>
                                    ))}
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}

            <header className="bg-white border-b border-slate-100 sticky top-0 z-40">
                <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-4">
                        <Link href="/tcc" className="p-2 hover:bg-slate-50 rounded-full transition-colors text-slate-400">
                            <ArrowLeft size={18} />
                        </Link>
                        <h1 className="text-lg font-bold text-slate-800 tracking-tight italic">Cadastrar Defesa</h1>
                    </div>
                    <button
                        form="defense-form"
                        disabled={loading}
                        className="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2 rounded-full font-bold text-sm transition-all shadow-lg shadow-indigo-100 disabled:opacity-50 flex items-center gap-2"
                    >
                        {loading ? <RefreshCw size={14} className="animate-spin" /> : <Save size={14} />}
                        Salvar
                    </button>
                </div>
            </header>

            <main className="max-w-5xl mx-auto px-6 py-10">
                <form id="defense-form" onSubmit={handleSubmit} className="space-y-10">

                    {/* CREDENCIAIS DE ACESSO */}
                    <div className="bg-emerald-50 border border-emerald-100 rounded-[2rem] p-6 text-emerald-800 relative group">
                        <button type="button" onClick={copyCreds} className="absolute right-6 top-6 text-emerald-600 hover:text-emerald-800" title="Copiar">
                            <Copy size={18} />
                        </button>
                        <div className="mb-2">
                            <h3 className="text-[10px] font-black uppercase tracking-[2px] text-emerald-600">Credenciais de Acesso</h3>
                            <p className="text-[11px] font-medium italic text-emerald-500 mt-1">
                                Importante: Estes dados devem ser enviados aos avaliadores externos para acesso ao sistema.
                            </p>
                        </div>
                        <div className="flex gap-16 mt-4">
                            <div>
                                <span className="text-[9px] font-black uppercase tracking-wider text-emerald-400 block mb-1">Login</span>
                                <span className="text-2xl font-black tracking-tight">{formData.login}</span>
                            </div>
                            <div>
                                <span className="text-[9px] font-black uppercase tracking-wider text-emerald-400 block mb-1">Senha</span>
                                <span className="text-2xl font-black tracking-tight">{formData.senha}</span>
                            </div>
                        </div>
                    </div>

                    {/* INFORMAÇÕES BÁSICAS */}
                    <div className="space-y-6">
                        <div className="flex items-center gap-2 text-indigo-600">
                            <Info size={16} />
                            <h2 className="text-[10px] font-black uppercase tracking-[2px]">Informações Básicas</h2>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div className="md:col-span-2 relative">
                                <GraduationCap className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
                                <select
                                    required
                                    className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-12 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all appearance-none"
                                    value={formData.semestre}
                                    onChange={e => setFormData({ ...formData, semestre: e.target.value })}
                                >
                                    <option value="">Semestre Letivo *</option>
                                    {semestresDb.map(s => (
                                        <option key={s.label} value={s.label}>
                                            {s.label} {s.isCurrent ? '(Atual)' : ''}
                                        </option>
                                    ))}
                                </select>
                                <Search className="absolute right-5 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                            </div>

                            <div className="relative bg-white border border-slate-200 rounded-[2rem] px-5 py-3 group focus-within:border-indigo-500 transition-all">
                                <div className="flex items-center gap-4">
                                    <Calendar className="text-slate-400" size={20} />
                                    <div>
                                        <label className="text-[9px] font-black uppercase tracking-wider text-slate-400 block">Data da Defesa</label>
                                        <input
                                            type="date"
                                            className="w-full text-sm font-bold text-slate-700 outline-none bg-transparent"
                                            value={formData.dia}
                                            onChange={e => setFormData({ ...formData, dia: e.target.value })}
                                        />
                                    </div>
                                </div>
                            </div>

                            <div className="relative bg-white border border-slate-200 rounded-[2rem] px-5 py-3 group focus-within:border-indigo-500 transition-all">
                                <div className="flex items-center gap-4">
                                    <Clock className="text-slate-400" size={20} />
                                    <div>
                                        <label className="text-[9px] font-black uppercase tracking-wider text-slate-400 block">Hora Início</label>
                                        <input
                                            type="time"
                                            className="w-full text-sm font-bold text-slate-700 outline-none bg-transparent"
                                            value={formData.hora}
                                            onChange={e => setFormData({ ...formData, hora: e.target.value })}
                                        />
                                    </div>
                                </div>
                            </div>

                            <div className="md:col-span-2 relative">
                                <MapPin className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
                                <input
                                    type="text"
                                    placeholder="Local ou Link da Defesa"
                                    className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-5 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all"
                                    value={formData.local}
                                    onChange={e => setFormData({ ...formData, local: e.target.value })}
                                />
                            </div>
                        </div>
                    </div>

                    {/* DADOS DO DISCENTE */}
                    <div className="space-y-6">
                        <div className="flex items-center gap-2 text-indigo-600">
                            <User size={16} />
                            <h2 className="text-[10px] font-black uppercase tracking-[2px]">Dados do Discente</h2>
                        </div>

                        <div className="grid grid-cols-1 gap-4">
                            <div className="relative flex items-center">
                                <User className="absolute left-5 text-slate-400 z-10" size={20} />
                                <input
                                    required
                                    type="text"
                                    placeholder="Nome do Aluno *"
                                    className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-32 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all uppercase"
                                    value={formData.discente}
                                    onChange={e => setFormData({ ...formData, discente: e.target.value })}
                                />
                                <button
                                    type="button"
                                    onClick={openSigaaSearch}
                                    className="absolute right-4 bg-indigo-50 text-indigo-600 px-4 py-1.5 rounded-full text-[10px] font-black uppercase hover:bg-indigo-100 transition-all"
                                >
                                    Consultar SIGAA
                                </button>
                            </div>

                            <div className="relative">
                                <IdCard className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
                                <input
                                    type="text"
                                    placeholder="Matrícula"
                                    className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-5 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all"
                                    value={formData.matricula}
                                    onChange={e => setFormData({ ...formData, matricula: e.target.value })}
                                />
                            </div>

                            <div className="relative">
                                <BookOpen className="absolute left-5 top-5 text-slate-400" size={20} />
                                <textarea
                                    required
                                    rows={2}
                                    placeholder="Título do Trabalho *"
                                    className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-5 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all uppercase resize-none"
                                    value={formData.titulo}
                                    onChange={e => setFormData({ ...formData, titulo: e.target.value })}
                                />
                            </div>
                        </div>
                    </div>

                    {/* ORIENTAÇÃO E BANCA */}
                    <div className="space-y-6">
                        <div className="flex items-center gap-2 text-indigo-600">
                            <Contact size={16} />
                            <h2 className="text-[10px] font-black uppercase tracking-[2px]">Orientação e Banca</h2>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div className="relative">
                                <User className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                <input
                                    required
                                    list="docentes-list"
                                    placeholder="Orientador(a) *"
                                    className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-5 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all uppercase"
                                    value={formData.orientador}
                                    onChange={e => handleOrientadorChange(e.target.value)}
                                />
                            </div>
                            <div className="relative">
                                <User className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                <input
                                    list="docentes-list"
                                    placeholder="Coorientador(a)"
                                    className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-5 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all uppercase"
                                    value={formData.coorientador}
                                    onChange={e => setFormData({ ...formData, coorientador: e.target.value })}
                                />
                            </div>

                            {[1, 2, 3].map(num => (
                                <div key={num} className="md:col-span-2 grid grid-cols-1 md:grid-cols-2 gap-4">
                                    <div className="relative">
                                        <Users className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                        <input
                                            list="docentes-list"
                                            placeholder={`Avaliador ${num}`}
                                            className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-5 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all uppercase"
                                            value={formData[`avaliador${num}` as keyof typeof formData] as string}
                                            onChange={e => setFormData({ ...formData, [`avaliador${num}`]: e.target.value })}
                                        />
                                    </div>
                                    <div className="relative">
                                        <School className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                        <input
                                            list="instituicoes-list"
                                            placeholder="Instituição"
                                            className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-5 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all uppercase"
                                            value={formData[`instituto_av${num}` as keyof typeof formData] as string}
                                            onChange={e => setFormData({ ...formData, [`instituto_av${num}`]: e.target.value })}
                                        />
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="pb-20">
                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-slate-900 hover:bg-black text-white py-5 rounded-[2rem] font-black text-sm tracking-[2px] transition-all shadow-xl active:scale-[0.98] disabled:opacity-50 uppercase"
                        >
                            {loading ? <Loader2 size={18} className="animate-spin inline mr-2" /> : null}
                            Finalizar Registro de Banca
                        </button>
                    </div>
                </form>

                <datalist id="docentes-list">
                    {docentes.map(d => <option key={d} value={d} />)}
                </datalist>
                <datalist id="instituicoes-list">
                    {instituicoes.map(i => <option key={i} value={i} />)}
                </datalist>
            </main>
        </div>
    )
}
