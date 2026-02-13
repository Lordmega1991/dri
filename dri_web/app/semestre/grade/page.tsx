'use client'
// app/semestre/[id]/grade/page.tsx

import { useEffect, useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import Link from 'next/link'
import { ArrowLeft, Filter, Plus, Clock, Save, Loader2, Calendar, X, Download, Users, Trash2, Trash, FileText, Search } from 'lucide-react'
import clsx from 'clsx'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'

const DIAS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
const TURNOS = ['Manhã', 'Tarde', 'Noite']

const HORARIOS = {
    'Manhã': ['07h-08h', '08h-09h', '09h-10h', '10h-11h', '11h-12h', '12h-13h'],
    'Tarde': ['13h-14h', '14h-15h', '15h-16h', '16h-17h', '17h-18h', '18h-19h'],
    'Noite': ['19h-19h50', '19h50-20h40', '20h40-21h30', '21h30-22h20']
}

const SearchableSelect = ({ options, value, onChange, placeholder, searchPlaceholder, themeColor = 'blue' }: any) => {
    const [isOpen, setIsOpen] = useState(false)
    const [search, setSearch] = useState('')

    const selectedOption = options.find((o: any) => o.id === value)

    const filteredOptions = options.filter((o: any) =>
        o.label.toLowerCase().includes(search.toLowerCase()) ||
        (o.sublabel && o.sublabel.toLowerCase().includes(search.toLowerCase()))
    )

    const colors = {
        blue: { bg: 'bg-blue-50', border: 'border-blue-200', text: 'text-blue-800', ring: 'ring-blue-500', hover: 'hover:bg-blue-100' },
        emerald: { bg: 'bg-emerald-50', border: 'border-emerald-200', text: 'text-emerald-800', ring: 'ring-emerald-500', hover: 'hover:bg-emerald-100' }
    }[themeColor as 'blue' | 'emerald'] || { bg: 'bg-gray-50', border: 'border-gray-200', text: 'text-gray-800', ring: 'ring-gray-500', hover: 'hover:bg-gray-100' }

    return (
        <div className="relative">
            <div
                onClick={() => setIsOpen(true)}
                className={clsx(
                    "w-full p-3 border rounded-xl flex items-center justify-between cursor-pointer bg-white transition-all shadow-sm group hover:border-gray-300",
                    colors.border,
                    isOpen && `ring-2 ${colors.ring}`
                )}
            >
                <div className="flex flex-col truncate pr-4">
                    {selectedOption ? (
                        <>
                            <span className="font-bold text-gray-900 text-sm truncate">{selectedOption.label}</span>
                            {selectedOption.sublabel && <span className="text-[10px] text-gray-500 truncate">{selectedOption.sublabel}</span>}
                        </>
                    ) : (
                        <span className="text-gray-400 font-medium text-sm">{placeholder}</span>
                    )}
                </div>
                <Search size={16} className={clsx("shrink-0 transition-colors", isOpen ? colors.text : "text-gray-400")} />
            </div>

            {isOpen && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
                    <div
                        className="fixed inset-0 bg-black/40 backdrop-blur-sm animate-in fade-in duration-200"
                        onClick={() => setIsOpen(false)}
                    />

                    <div className="relative bg-white w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[80vh] border border-gray-100 animate-in zoom-in-95 fade-in duration-200">
                        {/* Popup Header */}
                        <div className={clsx("p-4 border-b flex items-center justify-between bg-gray-50", colors.bg)}>
                            <div className="flex items-center gap-2">
                                <Search size={18} className={colors.text} />
                                <span className={clsx("font-bold text-sm uppercase tracking-wider", colors.text)}>
                                    {placeholder}
                                </span>
                            </div>
                            <button
                                onClick={() => setIsOpen(false)}
                                className="p-2 hover:bg-black/5 rounded-full transition-colors"
                            >
                                <X size={20} className="text-gray-500" />
                            </button>
                        </div>

                        {/* Search Input */}
                        <div className="p-4 border-b">
                            <div className="relative">
                                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                                <input
                                    autoFocus
                                    type="text"
                                    placeholder={searchPlaceholder}
                                    value={search}
                                    onChange={(e) => setSearch(e.target.value)}
                                    className={clsx(
                                        "w-full pl-10 pr-4 py-3 text-sm border rounded-xl outline-none transition-all",
                                        colors.border,
                                        `focus:ring-2 ${colors.ring}`
                                    )}
                                    onClick={(e) => e.stopPropagation()}
                                />
                            </div>
                        </div>

                        {/* Options List */}
                        <div className="overflow-y-auto custom-scrollbar flex-1 py-1">
                            {filteredOptions.length > 0 ? (
                                filteredOptions.map((opt: any) => (
                                    <div
                                        key={opt.id}
                                        onClick={() => {
                                            onChange(opt.id)
                                            setIsOpen(false)
                                            setSearch('')
                                        }}
                                        className={clsx(
                                            "px-6 py-4 cursor-pointer transition-colors flex flex-col border-b last:border-0 border-gray-50",
                                            value === opt.id ? colors.bg : "hover:bg-gray-50"
                                        )}
                                    >
                                        <span className={clsx("font-bold text-base", value === opt.id ? colors.text : "text-gray-900")}>
                                            {opt.label}
                                        </span>
                                        {opt.sublabel && (
                                            <span className="text-xs text-gray-500 mt-1">
                                                {opt.sublabel}
                                            </span>
                                        )}
                                    </div>
                                ))
                            ) : (
                                <div className="p-12 text-center">
                                    <Search size={48} className="mx-auto text-gray-100 mb-4" />
                                    <p className="text-gray-400 font-medium italic">Nenhum resultado encontrado para "{search}"</p>
                                </div>
                            )}
                        </div>

                        <div className="p-4 bg-gray-50 border-t flex justify-end">
                            <button
                                onClick={() => setIsOpen(false)}
                                className="px-4 py-2 text-sm font-bold text-gray-500 hover:text-gray-700 transition-colors"
                            >
                                Cancelar
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}

const AddClassModal = ({ isOpen, onClose, onSave, disciplinas, professores, initialSlot }: any) => {
    const [disciplinaId, setDisciplinaId] = useState('')
    const [docentesAlocados, setDocentesAlocados] = useState<any[]>([{ docente_id: '', ch: '' }])
    const [selectedSlots, setSelectedSlots] = useState<Set<string>>(new Set())
    const [saving, setSaving] = useState(false)

    // Reset/Initialize state when modal opens
    useEffect(() => {
        if (isOpen) {
            setDisciplinaId('')
            setDocentesAlocados([{ docente_id: '', ch: '' }])

            const initialSet = new Set<string>()
            if (initialSlot) {
                const turnoCode = initialSlot.turno === 'Manhã' ? 'M' : initialSlot.turno === 'Tarde' ? 'T' : 'N'
                initialSet.add(`${initialSlot.dia}-${turnoCode}${initialSlot.indice + 1}`)
            }
            setSelectedSlots(initialSet)
        }
    }, [isOpen, initialSlot])

    if (!isOpen) return null

    const toggleSlot = (slot: string) => {
        const newSet = new Set(selectedSlots)
        if (newSet.has(slot)) newSet.delete(slot)
        else newSet.add(slot)
        setSelectedSlots(newSet)
    }

    const addDocente = () => {
        setDocentesAlocados([...docentesAlocados, { docente_id: '', ch: '' }])
    }

    const removeDocente = (idx: number) => {
        if (docentesAlocados.length > 1) {
            setDocentesAlocados(docentesAlocados.filter((_, i) => i !== idx))
        }
    }

    const updateDocente = (idx: number, field: string, value: string) => {
        const newDocentes = [...docentesAlocados]
        newDocentes[idx][field] = value
        setDocentesAlocados(newDocentes)
    }


    const handleSubmit = async (e: any) => {
        e.preventDefault()
        if (!disciplinaId) return alert('Selecione uma disciplina')
        if (selectedSlots.size === 0) return alert('Selecione pelo menos um horário')
        if (docentesAlocados.some(d => !d.docente_id)) return alert('Selecione os docentes para todas as linhas')

        setSaving(true)
        await onSave({
            disciplina_id: disciplinaId,
            professores: docentesAlocados.map(d => ({
                docente_id: d.docente_id,
                ch_alocada: parseFloat(d.ch) || 0
            })),
            slots: Array.from(selectedSlots)
        })
        setSaving(false)
        onClose()
    }

    const getTurnoColor = (turno: string) => {
        if (turno === 'Manhã') return 'bg-amber-500'
        if (turno === 'Tarde') return 'bg-orange-500'
        if (turno === 'Noite') return 'bg-indigo-600'
        return 'bg-gray-500'
    }

    return (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-md z-50 flex items-center justify-center p-4 overflow-y-auto">
            <div className="bg-white rounded-2xl w-full max-w-4xl shadow-2xl my-auto animate-in fade-in zoom-in duration-300 flex flex-col max-h-[90vh]">
                {/* Header */}
                <div className="bg-indigo-700 p-6 rounded-t-2xl flex justify-between items-center shrink-0">
                    <div className="flex items-center gap-3">
                        <div className="p-2 bg-white/20 rounded-lg">
                            <Plus className="text-white" size={24} />
                        </div>
                        <div>
                            <h3 className="text-white font-bold text-xl">Lançamento de Aula</h3>
                            <p className="text-indigo-100 text-xs">
                                {initialSlot ? `${initialSlot.dia} • ${initialSlot.turno} • Horário #${initialSlot.indice + 1}` : 'Preencha os detalhes para lançamento em lote'}
                            </p>
                        </div>
                    </div>
                    <button onClick={onClose} className="text-white/60 hover:text-white transition-colors p-2 hover:bg-white/10 rounded-full">
                        <X size={24} />
                    </button>
                </div>

                {/* Content */}
                <form onSubmit={handleSubmit} className="p-8 space-y-8 overflow-y-auto flex-1 custom-scrollbar">
                    {/* Disciplina Section */}
                    <div className="bg-blue-50/50 border border-blue-100 p-5 rounded-2xl space-y-4">
                        <div className="flex items-center gap-2 text-blue-800 mb-2">
                            <Calendar size={18} className="font-bold" />
                            <span className="font-bold text-sm uppercase tracking-wider">Disciplina</span>
                        </div>
                        <SearchableSelect
                            options={disciplinas.map((d: any) => ({
                                id: d.id,
                                label: d.nome,
                                sublabel: d.nome_extenso
                            }))}
                            value={disciplinaId}
                            onChange={setDisciplinaId}
                            placeholder="Selecione a disciplina..."
                            searchPlaceholder="Buscar por sigla ou nome..."
                            themeColor="blue"
                        />
                    </div>

                    {/* Docentes Section */}
                    <div className="bg-emerald-50/50 border border-emerald-100 p-5 rounded-2xl space-y-4">
                        <div className="flex items-center justify-between mb-2">
                            <div className="flex items-center gap-2 text-emerald-800">
                                <Users size={18} />
                                <span className="font-bold text-sm uppercase tracking-wider">Docentes e Carga Horária</span>
                            </div>
                            <button
                                type="button"
                                onClick={addDocente}
                                className="text-[10px] bg-emerald-600 text-white px-3 py-1.5 rounded-full hover:bg-emerald-700 transition-colors font-bold uppercase"
                            >
                                + Co-docência
                            </button>
                        </div>

                        <div className="space-y-3">
                            {docentesAlocados.map((d, idx) => (
                                <div key={idx} className="flex gap-3 items-start animate-in slide-in-from-left-2 duration-200">
                                    <div className="flex-1">
                                        <SearchableSelect
                                            options={professores.map((p: any) => ({
                                                id: p.id,
                                                label: p.apelido || p.nome,
                                                sublabel: p.apelido ? p.nome : null
                                            }))}
                                            value={d.docente_id}
                                            onChange={(val: string) => updateDocente(idx, 'docente_id', val)}
                                            placeholder="Selecione o docente..."
                                            searchPlaceholder="Buscar docente..."
                                            themeColor="emerald"
                                        />
                                    </div>
                                    <div className="w-24">
                                        <div className="relative">
                                            <input
                                                type="number"
                                                value={d.ch}
                                                onChange={e => updateDocente(idx, 'ch', e.target.value)}
                                                placeholder="CH"
                                                className="w-full p-3 border border-emerald-200 rounded-xl focus:ring-2 focus:ring-emerald-500 bg-white pr-8"
                                            />
                                            <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] text-gray-400 font-bold">h</span>
                                        </div>
                                        <div className="text-[9px] text-emerald-600 font-bold mt-1 ml-1">
                                            {((parseFloat(d.ch) || 0) / 15).toFixed(1)} h.a.
                                        </div>
                                    </div>
                                    {docentesAlocados.length > 1 && (
                                        <button
                                            type="button"
                                            onClick={() => removeDocente(idx)}
                                            className="p-3 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-xl transition-all"
                                        >
                                            <X size={20} />
                                        </button>
                                    )}
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Horários Section */}
                    <div className="bg-purple-50/50 border border-purple-100 p-5 rounded-2xl space-y-4">
                        <div className="flex items-center gap-2 text-purple-800 mb-2">
                            <Clock size={18} />
                            <span className="font-bold text-sm uppercase tracking-wider">Horários Específicos</span>
                        </div>

                        <div className="space-y-6">
                            {['Manhã', 'Tarde', 'Noite'].map(turno => {
                                const turnoCode = turno === 'Manhã' ? 'M' : turno === 'Tarde' ? 'T' : 'N'
                                const count = turno === 'Noite' ? 4 : 6

                                return (
                                    <div key={turno} className="space-y-3">
                                        <div className="flex items-center gap-2 px-1">
                                            <div className={clsx("w-2 h-2 rounded-full", getTurnoColor(turno))} />
                                            <span className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">{turno}</span>
                                        </div>
                                        <div className="grid grid-cols-6 gap-2">
                                            {DIAS.map(dia => (
                                                <div key={dia} className="space-y-1">
                                                    <div className="text-[8px] text-gray-400 text-center font-bold uppercase">{dia}</div>
                                                    <div className="flex flex-col gap-1">
                                                        {Array.from({ length: count }).map((_, i) => {
                                                            const slotCode = `${dia}-${turnoCode}${i + 1}`
                                                            const isSelected = selectedSlots.has(slotCode)
                                                            return (
                                                                <button
                                                                    key={slotCode}
                                                                    type="button"
                                                                    onClick={() => toggleSlot(slotCode)}
                                                                    className={clsx(
                                                                        "h-8 rounded-lg text-[9px] font-bold transition-all border flex items-center justify-center",
                                                                        isSelected
                                                                            ? `${getTurnoColor(turno)} text-white border-transparent shadow-md scale-105 z-10`
                                                                            : "bg-white text-gray-400 border-gray-100 hover:border-gray-300"
                                                                    )}
                                                                >
                                                                    {turnoCode}{i + 1}
                                                                </button>
                                                            )
                                                        })}
                                                    </div>
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )
                            })}
                        </div>
                    </div>
                </form>

                {/* Footer */}
                <div className="p-6 bg-gray-50 rounded-b-2xl border-t border-gray-200 flex justify-between items-center shrink-0">
                    <p className="text-xs text-gray-400 font-medium italic">
                        * {selectedSlots.size} horário(s) selecionado(s)
                    </p>
                    <div className="flex gap-4">
                        <button
                            type="button"
                            onClick={onClose}
                            className="px-6 py-3 text-gray-600 hover:bg-gray-200 font-bold rounded-xl transition-colors text-sm"
                        >
                            Cancelar
                        </button>
                        <button
                            type="submit"
                            onClick={handleSubmit}
                            disabled={saving}
                            className="px-8 py-3 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-xl transition-all shadow-lg shadow-indigo-200 disabled:opacity-50 text-sm flex items-center gap-2"
                        >
                            {saving ? <Loader2 size={18} className="animate-spin" /> : <Save size={18} />}
                            {saving ? 'Processando...' : initialSlot ? 'Confirmar Lançamento' : 'Lançar em Lote'}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    )
}

const ViewClassesModal = ({ isOpen, onClose, aulas, onAdd, onDelete, dia, turno, indice, userAccessLevel }: any) => {
    if (!isOpen) return null

    return (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl w-full max-w-2xl shadow-2xl animate-in fade-in zoom-in duration-200 overflow-hidden">
                <div className="bg-gray-800 p-6 flex justify-between items-center">
                    <div>
                        <h3 className="text-white font-bold text-lg">Aulas Registradas</h3>
                        <p className="text-gray-400 text-xs mt-0.5">{dia} • {turno} • Horário #{indice + 1}</p>
                    </div>
                    <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
                        <X size={20} />
                    </button>
                </div>

                <div className="p-6 max-h-[60vh] overflow-y-auto space-y-3">
                    {aulas.map((aula: any, idx: number) => (
                        <div key={idx} className="flex items-center justify-between p-4 bg-gray-50 rounded-xl border border-gray-100 group">
                            <div className="flex-1 min-w-0">
                                <div className="font-bold text-gray-900 truncate">
                                    {aula.disciplina_nome}
                                </div>
                                <div className="text-xs text-indigo-600 font-medium mt-1">
                                    Prof: {aula.professor}
                                </div>
                                <div className="text-[10px] text-gray-400 mt-0.5">
                                    Semestre: {aula.semestre}
                                </div>
                            </div>
                            {userAccessLevel !== 2 && (
                                <button
                                    onClick={() => onDelete(aula.id)}
                                    className="p-2 text-gray-300 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all opacity-0 group-hover:opacity-100"
                                    title="Excluir aula"
                                >
                                    <Trash2 size={18} />
                                </button>
                            )}
                        </div>
                    ))}
                </div>

                <div className="p-6 border-t bg-gray-50 flex justify-end gap-3">
                    <button onClick={onClose} className="px-4 py-2 text-gray-600 font-bold text-sm hover:bg-gray-200 rounded-xl transition-colors">
                        Fechar
                    </button>
                    {userAccessLevel !== 2 && (
                        <button
                            onClick={() => { onClose(); onAdd(); }}
                            className="px-6 py-2 bg-indigo-600 text-white font-bold text-sm rounded-xl shadow-lg shadow-indigo-100 hover:bg-indigo-700 transition-all flex items-center gap-2"
                        >
                            <Plus size={16} />
                            Adicionar Aula
                        </button>
                    )}
                </div>
            </div>
        </div>
    )
}

function GradeContent() {
    const searchParams = useSearchParams()
    const semestreId = searchParams.get('id') || ''

    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [grade, setGrade] = useState<any[]>([])
    const [disciplinas, setDisciplinas] = useState<any[]>([])
    const [professores, setProfessores] = useState<any[]>([])
    const [selectedTurno, setSelectedTurno] = useState('Manhã')
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [initialSlot, setInitialSlot] = useState<any>(null)
    const [viewingAulas, setViewingAulas] = useState<any[] | null>(null)
    const [viewingSlotInfo, setViewingSlotInfo] = useState<any>(null)

    // New states for simulation import
    const [simulacoes, setSimulacoes] = useState<any[]>([])
    const [selectedSimulacao, setSelectedSimulacao] = useState<string>('grade_oficial')
    const [showSidebar, setShowSidebar] = useState(false)
    const [professorSummary, setProfessorSummary] = useState<any[]>([])
    const [sidebarSortBy, setSidebarSortBy] = useState<'apelido' | 'ch'>('apelido')
    const [importing, setImporting] = useState(false)
    const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)

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
            fetchAllData()
        }
        checkAccess()
    }, [semestreId])

    useEffect(() => {
        if (selectedSimulacao) {
            loadSimulationData(selectedSimulacao)
        }
    }, [selectedSimulacao])

    // Reactive sorting for professor summary
    useEffect(() => {
        if (professorSummary.length > 0) {
            setProfessorSummary(prev => {
                const sorted = [...prev].sort((a: any, b: any) => {
                    if (sidebarSortBy === 'ch') return (b.totalCH || 0) - (a.totalCH || 0)
                    return (a.apelido || '').localeCompare(b.apelido || '')
                })
                // Only update if order actually changed to prevent loops
                const isSameOrder = sorted.every((val, index) => val.id === prev[index].id)
                return isSameOrder ? prev : sorted
            })
        }
    }, [sidebarSortBy])

    const fetchAllData = async () => {
        setLoading(true)
        try {
            // Load basic data
            const [gradeRes, discRes, profRes, simRes, alocRes] = await Promise.all([
                supabase
                    .from('grade_aulas')
                    .select('id, dia, turno, indice, disciplina_id, professores, semestre, disciplinas!inner(id, nome, nome_extenso, periodo, turno, ppc)')
                    .eq('semestre', semestreId),
                supabase.from('disciplinas').select('*').order('nome'),
                supabase.from('docentes').select('*').order('nome'),
                supabase.from('simulacoes').select('*').eq('semestre', semestreId).order('created_at', { ascending: false }),
                supabase
                    .from('alocacoes_docentes')
                    .select('*, docentes(id, nome, apelido), disciplinas(id, nome, nome_extenso, ch_aula)')
                    .eq('semestre', semestreId)
                    .is('simulacao_id', null)
            ])

            // Build current professor summary
            const summaryMap = new Map<string, any>()
            alocRes.data?.forEach((aloc: any) => {
                const prof = aloc.docentes
                const disc = aloc.disciplinas
                const profId = aloc.docente_id

                if (!prof) return

                if (!summaryMap.has(profId)) {
                    summaryMap.set(profId, {
                        id: profId,
                        nome: prof.nome,
                        apelido: prof.apelido || prof.nome,
                        totalCH: 0,
                        atividades: []
                    })
                }

                const profSum = summaryMap.get(profId)
                const ch = aloc.ch_alocada || 0
                profSum.totalCH += ch

                profSum.atividades.push({
                    tipo: 'disciplina',
                    nome: disc?.nome || '?',
                    nomeExtenso: disc?.nome_extenso || disc?.nome || '?',
                    ch: ch,
                    turno: aloc.turno || '-',
                    dias: aloc.dias || []
                })
            })

            const summaryArray = Array.from(summaryMap.values())

            // Only update summary from fetchAllData if we are NOT viewing a specific simulation
            if (selectedSimulacao === 'grade_oficial' || !selectedSimulacao) {
                // Apply current sort before setting
                summaryArray.sort((a: any, b: any) => {
                    if (sidebarSortBy === 'ch') return (b.totalCH || 0) - (a.totalCH || 0)
                    return (a.apelido || '').localeCompare(b.apelido || '')
                })
                setProfessorSummary(summaryArray)
            }

            // Process grade data to match display format
            const processedGrade = gradeRes.data?.map((item: any) => {
                const disc = item.disciplinas
                const horario = HORARIOS[item.turno as keyof typeof HORARIOS]?.[item.indice] || ''

                // Get professor apelidos (nicknames)
                const professoresApelidos = (item.professores || []).map((profId: string) => {
                    const prof = profRes.data?.find((p: any) => p.id === profId)
                    return prof?.apelido || prof?.nome || 'Prof. não encontrado'
                })

                // Get CH from allocations
                let ch = null
                if (item.professores && item.professores.length > 0) {
                    const profId = item.professores[0]
                    const alocacao = alocRes.data?.find((a: any) =>
                        a.docente_id === profId && a.disciplina_id === item.disciplina_id
                    )
                    if (alocacao) {
                        ch = alocacao.ch_alocada
                    }
                }

                return {
                    ...item,
                    dia: item.dia,
                    horario: horario,
                    turno: item.turno,
                    indice: item.indice,
                    disciplina_nome: disc?.nome || 'Disciplina não especificada',
                    disciplina_nome_extenso: disc?.nome_extenso || disc?.nome,
                    professor: professoresApelidos.join(', '),
                    professores_apelidos: professoresApelidos,
                    professores_ids: item.professores || [],
                    ch: ch
                }
            }) || []

            setGrade(processedGrade)
            if (discRes.data) setDisciplinas(discRes.data)
            if (profRes.data) setProfessores(profRes.data)
            if (simRes.data) {
                setSimulacoes(simRes.data)
                if (simRes.data.length > 0 && !selectedSimulacao) {
                    setSelectedSimulacao(simRes.data[0].id)
                }
            }
        } catch (error) {
            console.error('Erro ao carregar dados:', error)
        } finally {
            setLoading(false)
        }
    }

    const loadSimulationData = async (simulacaoId: string) => {
        if (!simulacaoId) return

        if (simulacaoId === 'grade_oficial') {
            fetchAllData()
            return
        }

        try {
            // Fetch allocations with discipline details
            const { data: alocacoes, error: alocError } = await supabase
                .from('alocacoes_docentes')
                .select('*, docentes(id, nome, apelido), disciplinas(id, nome, nome_extenso, ch_aula)')
                .eq('simulacao_id', simulacaoId)

            if (alocError) throw alocError

            if (!alocacoes || alocacoes.length === 0) {
                setProfessorSummary([])
                setShowSidebar(true)
                return
            }

            // Build professor summary
            const summaryMap = new Map<string, any>()

            alocacoes.forEach((aloc: any) => {
                const prof = aloc.docentes
                const disc = aloc.disciplinas
                const profId = aloc.docente_id

                if (!prof) return

                if (!summaryMap.has(profId)) {
                    summaryMap.set(profId, {
                        id: profId,
                        nome: prof.nome,
                        apelido: prof.apelido || prof.nome,
                        totalCH: 0,
                        atividades: []
                    })
                }

                const profSum = summaryMap.get(profId)
                const ch = aloc.ch_alocada || 0
                profSum.totalCH += ch

                profSum.atividades.push({
                    tipo: 'disciplina',
                    nome: disc?.nome || '?',
                    nomeExtenso: disc?.nome_extenso || disc?.nome || '?',
                    ch: ch,
                    turno: aloc.turno,
                    dias: aloc.dias || []
                })
            })

            const summaryArray = Array.from(summaryMap.values())

            // Apply current sort
            summaryArray.sort((a: any, b: any) => {
                if (sidebarSortBy === 'ch') return (b.totalCH || 0) - (a.totalCH || 0)
                return (a.apelido || '').localeCompare(b.apelido || '')
            })

            setProfessorSummary(summaryArray)
            setShowSidebar(true)
        } catch (err) {
            console.error('Erro ao carregar simulação:', err)
            alert('Erro ao carregar dados da simulação')
        }
    }

    const importSimulationToGrade = async () => {
        if (!selectedSimulacao) {
            alert('Selecione uma simulação primeiro')
            return
        }

        if (!confirm('Isso irá importar todas as alocações da simulação para a grade. Continuar?')) {
            return
        }

        setImporting(true)
        try {
            console.log('Iniciando importação da simulação:', selectedSimulacao)

            // 1. Fetch simulation allocations
            const { data: alocacoes, error: fetchError } = await supabase
                .from('alocacoes_docentes')
                .select('*')
                .eq('simulacao_id', selectedSimulacao)

            if (fetchError) {
                console.error('Erro ao buscar alocações:', fetchError)
                throw new Error(`Erro ao buscar alocações: ${fetchError.message}`)
            }

            console.log('Alocações encontradas:', alocacoes?.length || 0)

            if (!alocacoes || alocacoes.length === 0) {
                alert('Nenhuma alocação encontrada nesta simulação')
                setImporting(false)
                return
            }

            // Get unique professor and discipline IDs
            const profIds = [...new Set(alocacoes.map((a: any) => a.docente_id).filter(Boolean))]
            const discIds = [...new Set(alocacoes.map((a: any) => a.disciplina_id).filter(Boolean))]

            console.log('Buscando professores:', profIds.length, 'e disciplinas:', discIds.length)

            // Fetch professors and disciplines separately
            const profsRes = profIds.length > 0
                ? await supabase.from('docentes').select('id, nome, apelido').in('id', profIds)
                : { data: [], error: null }

            const discsRes = discIds.length > 0
                ? await supabase.from('disciplinas').select('id, nome').in('id', discIds)
                : { data: [], error: null }

            if (profsRes.error) {
                console.error('Erro ao buscar professores:', profsRes.error)
                throw new Error(`Erro ao buscar professores: ${profsRes.error.message}`)
            }

            if (discsRes.error) {
                console.error('Erro ao buscar disciplinas:', discsRes.error)
                throw new Error(`Erro ao buscar disciplinas: ${discsRes.error.message}`)
            }

            const profsMap = new Map(profsRes.data?.map(p => [p.id, p]) || [])
            const discsMap = new Map(discsRes.data?.map(d => [d.id, d]) || [])

            console.log('Professores carregados:', profsMap.size, 'Disciplinas carregadas:', discsMap.size)

            // Build a map of allocations by professor-discipline for deduplication
            const alocacoesMap = new Map<string, any>()

            alocacoes.forEach((aloc: any) => {
                const key = `${aloc.docente_id}-${aloc.disciplina_id}`
                if (!alocacoesMap.has(key)) {
                    alocacoesMap.set(key, {
                        docente_id: aloc.docente_id,
                        disciplina_id: aloc.disciplina_id,
                        ch_alocada: aloc.ch_alocada,
                        semestre: semestreId,
                        simulacao_id: selectedSimulacao,
                        dias: aloc.dias || [],
                        slots: aloc.slots || [],
                        turno: aloc.turno
                    })
                }
            })

            console.log('Alocações únicas:', alocacoesMap.size)

            // Insert or update alocacoes_docentes for this semester
            const alocacoesArray = Array.from(alocacoesMap.values())

            // First, delete existing allocations for this semester to avoid duplicates
            const { error: deleteError } = await supabase
                .from('alocacoes_docentes')
                .delete()
                .eq('semestre', semestreId)

            if (deleteError) {
                console.warn('Aviso ao limpar alocações antigas:', deleteError)
            }

            // Insert new allocations
            const { error: alocError } = await supabase
                .from('alocacoes_docentes')
                .insert(alocacoesArray)

            if (alocError) {
                console.error('Erro ao inserir alocações:', alocError)
                throw new Error(`Erro ao inserir alocações: ${alocError.message}`)
            }

            console.log('Alocações inseridas com sucesso')

            // Convert allocations to grade entries
            const gradeEntries: any[] = []
            alocacoes.forEach((aloc: any) => {
                const prof = profsMap.get(aloc.docente_id)
                const disc = discsMap.get(aloc.disciplina_id)
                const dias = aloc.dias || []
                const slots = aloc.slots || []

                // Map each day-slot combination to a grade entry
                dias.forEach((dia: string, index: number) => {
                    const slot = slots[index]
                    if (!slot) return

                    // Extract time from slot (e.g., "Seg-M1" -> "M1")
                    const slotCode = slot.split('-')[1]
                    const horario = mapSlotToHorario(slotCode)
                    const turno = slotCode.startsWith('M') ? 'Manhã' : slotCode.startsWith('T') ? 'Tarde' : 'Noite'
                    const indice = parseInt(slotCode.substring(1)) - 1

                    if (horario) {
                        gradeEntries.push({
                            semestre: semestreId,
                            dia: dia,
                            turno: turno,
                            indice: indice,
                            disciplina_id: aloc.disciplina_id,
                            professores: [aloc.docente_id]
                        })
                    }
                })
            })

            console.log('Entradas de grade geradas:', gradeEntries.length)

            if (gradeEntries.length === 0) {
                alert('Nenhuma entrada válida para importar')
                setImporting(false)
                return
            }

            // Insert into grade_aulas
            const { error: insertError } = await supabase
                .from('grade_aulas')
                .insert(gradeEntries)

            if (insertError) {
                console.error('Erro ao inserir na grade:', insertError)
                throw new Error(`Erro ao inserir na grade: ${insertError.message}`)
            }

            console.log('Importação concluída com sucesso!')
            alert(`${gradeEntries.length} aulas importadas com sucesso!`)
            fetchAllData()
        } catch (err: any) {
            console.error('Erro ao importar:', err)
            alert('Erro ao importar simulação: ' + (err.message || 'Erro desconhecido'))
        } finally {
            setImporting(false)
        }
    }

    // Helper to map slot codes to time ranges
    const mapSlotToHorario = (slotCode: string): string => {
        const slotMap: any = {
            'M1': '07h-08h', 'M2': '08h-09h', 'M3': '09h-10h',
            'M4': '10h-11h', 'M5': '11h-12h', 'M6': '12h-13h',
            'T1': '13h-14h', 'T2': '14h-15h', 'T3': '15h-16h',
            'T4': '16h-17h', 'T5': '17h-18h', 'T6': '18h-19h',
            'N1': '19h-19h50', 'N2': '19h50-20h40', 'N3': '20h40-21h30', 'N4': '21h30-22h20'
        }
        return slotMap[slotCode] || ''
    }

    const handleAddClass = async (data: any) => {
        try {
            const { disciplina_id, professores: profsAlloc, slots } = data

            // 1. Create allocations for each professor
            const alocacoes = profsAlloc.map((p: any) => {
                const dias = [...new Set(slots.map((s: string) => s.split('-')[0]))]

                return {
                    semestre: semestreId,
                    docente_id: p.docente_id,
                    disciplina_id: disciplina_id,
                    ch_alocada: p.ch_alocada,
                    dias: dias,
                    slots: slots,
                    turno: selectedTurno,
                    turma: 'A',
                    simulacao_id: null // Explicitly null for official grade
                }
            })

            // Clear previous official allocations for this discipline before inserting new ones
            // This maintains co-teaching consistency for the semester
            const { error: deleteAlocError } = await supabase
                .from('alocacoes_docentes')
                .delete()
                .eq('semestre', semestreId)
                .eq('disciplina_id', disciplina_id)
                .is('simulacao_id', null)

            if (deleteAlocError) throw deleteAlocError

            // Save new allocations
            const { error: alocError } = await supabase
                .from('alocacoes_docentes')
                .insert(alocacoes)

            if (alocError) throw alocError

            // 2. Create grade entries for each slot
            const gradeEntries = slots.map((slot: string) => {
                const [dia, slotCode] = slot.split('-')
                const turno = slotCode.startsWith('M') ? 'Manhã' : slotCode.startsWith('T') ? 'Tarde' : 'Noite'
                const indice = parseInt(slotCode.substring(1)) - 1

                return {
                    semestre: semestreId,
                    dia: dia,
                    turno: turno,
                    indice: indice,
                    disciplina_id: disciplina_id,
                    professores: profsAlloc.map((p: any) => p.docente_id)
                }
            })

            // Save to grade_aulas
            const { error: gradeError } = await supabase
                .from('grade_aulas')
                .insert(gradeEntries)

            if (gradeError) throw gradeError

            fetchAllData()
        } catch (err: any) {
            console.error('Erro detalhado ao salvar:', JSON.stringify(err, null, 2))
            alert('Erro ao salvar lançamento: ' + (err.message || err.details || 'Erro desconhecido no servidor'))
        }
    }

    const handleClearGrade = async () => {
        if (!confirm('🚨 ATENÇÃO: Isso irá excluir TODAS as aulas e alocações oficiais deste semestre. Esta ação não pode ser desfeita. Deseja continuar?')) return

        setLoading(true)
        try {
            // Delete all grade entries
            const { error: gradeError } = await supabase
                .from('grade_aulas')
                .delete()
                .eq('semestre', semestreId)

            if (gradeError) throw gradeError

            // Delete all official allocations (simulacao_id is null)
            const { error: alocError } = await supabase
                .from('alocacoes_docentes')
                .delete()
                .eq('semestre', semestreId)
                .is('simulacao_id', null)

            if (alocError) throw alocError

            alert('Grade limpa com sucesso!')
            fetchAllData()
        } catch (err: any) {
            console.error('Erro ao limpar grade:', err)
            alert('Erro ao limpar grade: ' + err.message)
        } finally {
            setLoading(false)
        }
    }

    const generatePDF = () => {
        const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' })
        const pageWidth = doc.internal.pageSize.getWidth()

        // --- Helper: Professional Header ---
        const addProfessionalHeader = (title: string) => {
            // Top border
            doc.setDrawColor(21, 101, 192) // Primary Blue
            doc.setLineWidth(0.5)
            doc.line(14, 25, pageWidth - 14, 25)

            doc.setFont('helvetica', 'bold')
            doc.setFontSize(9)
            doc.setTextColor(33, 33, 33)
            doc.text('UNIVERSIDADE FEDERAL DA PARAÍBA', 14, 12)
            doc.text('CENTRO DE CIÊNCIAS SOCIAIS APLICADAS', 14, 16)
            doc.text('DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS', 14, 20)

            doc.setFontSize(14)
            doc.setTextColor(21, 101, 192)
            doc.text(title.toUpperCase(), pageWidth - 14, 20, { align: 'right' })

            doc.setFontSize(8)
            doc.setTextColor(117, 117, 117)
            doc.setFont('helvetica', 'italic')
            doc.text(`Semestre: ${semestreId} | DRI-SISTEMA`, pageWidth - 14, 12, { align: 'right' })

            doc.setTextColor(0, 0, 0)
            doc.setFont('helvetica', 'normal')
        }

        // --- Page 1: Summary and Stats ---
        addProfessionalHeader('Resumo Geral de Alocações')

        // Stats Cards Layout
        const totalAulas = grade.length
        const totalProfessores = professorSummary.length
        const totalDisciplinas = new Set(grade.map(g => g.disciplina_id)).size

        const stats = [
            { label: 'Aulas Atribuídas', value: totalAulas.toString(), color: [21, 101, 192] },
            { label: 'Docentes Ativos', value: totalProfessores.toString(), color: [56, 142, 60] },
            { label: 'Disciplinas', value: totalDisciplinas.toString(), color: [245, 124, 0] },
            { label: 'Ocupação Grade', value: `${totalAulas} slots`, color: [123, 31, 162] }
        ]

        let cardX = 14
        const cardWidth = (pageWidth - 28 - 15) / 4
        stats.forEach(s => {
            doc.setDrawColor(200, 200, 200)
            doc.setFillColor(245, 245, 245)
            doc.roundedRect(cardX, 32, cardWidth, 18, 2, 2, 'FD')

            doc.setFontSize(7)
            doc.setTextColor(117, 117, 117)
            doc.text(s.label.toUpperCase(), cardX + cardWidth / 2, 38, { align: 'center' })

            doc.setFontSize(12)
            doc.setFont('helvetica', 'bold')
            doc.setTextColor(s.color[0], s.color[1], s.color[2])
            doc.text(s.value, cardX + cardWidth / 2, 45, { align: 'center' })

            cardX += cardWidth + 5
        })

        const summaryData = professorSummary.map(ps => [
            ps.apelido,
            (ps.totalCH / 15).toFixed(1) + ' h.a.',
            ps.totalCH + 'h',
            ps.atividades.map((a: any) => `${a.nome} (${(a.ch / 15).toFixed(1)} h.a.)`).join(', ')
        ])

        autoTable(doc, {
            startY: 55,
            head: [['Docente', 'CH (h.a.)', 'CH (hrs)', 'Detalhamento das Disciplinas']],
            body: summaryData,
            theme: 'grid',
            headStyles: { fillColor: [21, 101, 192], fontSize: 9 },
            styles: { fontSize: 8, cellPadding: 3 },
            columnStyles: {
                0: { fontStyle: 'bold', cellWidth: 40 },
                1: { halign: 'center', cellWidth: 25 },
                2: { halign: 'center', cellWidth: 25 },
                3: { fontSize: 7 }
            }
        })

        // --- Pages per Shift: Manhã, Tarde, Noite ---
        const shifts = [
            { label: 'Manhã', prefix: 'M', count: 6, color: [255, 248, 225] as [number, number, number] },
            { label: 'Tarde', prefix: 'T', count: 6, color: [251, 233, 231] as [number, number, number] },
            { label: 'Noite', prefix: 'N', count: 4, color: [232, 234, 246] as [number, number, number] }
        ]

        shifts.forEach(turno => {
            doc.addPage()
            addProfessionalHeader(`Mapa de Horários - Turno ${turno.label}`)

            const tableBody: any[] = []
            for (let i = 0; i < turno.count; i++) {
                const horarioDesc = HORARIOS[turno.label as keyof typeof HORARIOS][i]
                const row: any[] = [`${i + 1}º (${turno.prefix})\n${horarioDesc}`]

                DIAS.forEach(dia => {
                    const aulas = grade.filter(g =>
                        g.dia === dia &&
                        g.turno === turno.label &&
                        g.indice === i
                    )

                    if (aulas.length > 0) {
                        row.push(aulas.map(a =>
                            `${a.disciplinas?.nome || '?'} - ${(a.professores_apelidos || []).join(', ')}`
                        ).join('\n'))
                    } else {
                        row.push('')
                    }
                })
                tableBody.push(row)
            }

            autoTable(doc, {
                startY: 32,
                head: [['Horário / Dia', ...DIAS.map(d => d.toUpperCase())]],
                body: tableBody,
                theme: 'grid',
                styles: { fontSize: 7, cellPadding: 2, minCellHeight: 20, valign: 'middle' },
                headStyles: { fillColor: [21, 101, 192], halign: 'center' },
                columnStyles: {
                    0: { fontStyle: 'bold', fillColor: [245, 245, 245], cellWidth: 22, halign: 'center' },
                    1: { cellWidth: 41, fillColor: turno.color },
                    2: { cellWidth: 41, fillColor: turno.color },
                    3: { cellWidth: 41, fillColor: turno.color },
                    4: { cellWidth: 41, fillColor: turno.color },
                    5: { cellWidth: 41, fillColor: turno.color },
                    6: { cellWidth: 41, fillColor: turno.color }
                }
            })
        })

        // --- Page: Resumo de Disciplinas ---
        doc.addPage()
        addProfessionalHeader('Resumo de Disciplinas')

        const discSummaryMap = new Map<string, any>()
        grade.forEach(item => {
            const discId = item.disciplina_id
            const discName = item.disciplinas?.nome || '?'
            const discNameExt = item.disciplinas?.nome_extenso || discName

            if (!discSummaryMap.has(discId)) {
                discSummaryMap.set(discId, {
                    nome: discName,
                    nomeExt: discNameExt,
                    totalAulas: 0,
                    professores: new Set(),
                    turnos: new Set()
                })
            }

            const ds = discSummaryMap.get(discId)
            ds.totalAulas += 1
            if (item.turno) ds.turnos.add(item.turno)
            if (item.professores_apelidos) {
                item.professores_apelidos.forEach((p: string) => ds.professores.add(p))
            }
        })

        const discSummaryData = Array.from(discSummaryMap.values())
            .sort((a, b) => a.nome.localeCompare(b.nome))
            .map(ds => [
                ds.nome,
                ds.nomeExt,
                Array.from(ds.turnos).join(', '),
                ds.totalAulas,
                Array.from(ds.professores).join(', ')
            ])

        autoTable(doc, {
            startY: 32,
            head: [['Sigla', 'Nome Disciplina', 'Turno', 'Aulas', 'Professores']],
            body: discSummaryData,
            theme: 'grid',
            headStyles: { fillColor: [21, 101, 192], fontSize: 9 },
            styles: { fontSize: 8, cellPadding: 3 },
            columnStyles: {
                0: { fontStyle: 'bold', cellWidth: 30 },
                1: { cellWidth: 65 },
                2: { cellWidth: 20 },
                3: { halign: 'center', cellWidth: 15 },
                4: { fontSize: 7 }
            }
        })

        // --- Page(s): Detalhes dos Docentes (Visual Layout) ---
        doc.addPage()
        addProfessionalHeader('Detalhes dos Docentes')

        let currentY = 32
        const boxWidth = pageWidth - 28
        const leftColWidth = (boxWidth * 0.6) - 5
        const rightColWidth = (boxWidth * 0.4) - 5

        professorSummary.forEach((prof, pIdx) => {
            // Estimate height needed for this professor
            const atvCount = prof.atividades.length
            const atvHeight = atvCount * 5 + 10
            // Aggregate unique availability for this prof from grade data
            const availability = new Set<string>()
            grade.forEach(g => {
                if (g.professores_ids?.includes(prof.id)) {
                    availability.add(`${g.dia} (${g.turno})`)
                }
            })
            const availCount = availability.size
            const availRows = Math.ceil(availCount / 3)
            const availHeight = availRows * 8 + 10

            const boxHeight = Math.max(atvHeight, availHeight) + 15

            // Check if needs new page
            if (currentY + boxHeight > doc.internal.pageSize.getHeight() - 15) {
                doc.addPage()
                addProfessionalHeader('Detalhes dos Docentes (cont.)')
                currentY = 32
            }

            // Draw Box
            doc.setDrawColor(220, 220, 220)
            doc.setFillColor(255, 255, 255)
            doc.roundedRect(14, currentY, boxWidth, boxHeight, 3, 3, 'FD')

            // Professor Title Bar
            doc.setFillColor(248, 249, 250)
            doc.roundedRect(14.5, currentY + 0.5, boxWidth - 1, 10, 2, 2, 'F')

            doc.setFont('helvetica', 'bold')
            doc.setFontSize(10)
            doc.setTextColor(33, 33, 33)
            doc.text(prof.nome.toUpperCase(), 20, currentY + 7)

            // Total Pill
            const totalText = `TOTAL: ${(prof.totalCH / 15).toFixed(1)} h.a. (${prof.totalCH}h)`
            const textWidth = doc.getTextWidth(totalText)
            doc.setFillColor(21, 101, 192)
            doc.roundedRect(pageWidth - 20 - textWidth - 6, currentY + 2, textWidth + 6, 6, 3, 3, 'F')
            doc.setTextColor(255, 255, 255)
            doc.setFontSize(8)
            doc.text(totalText, pageWidth - 20 - textWidth - 3, currentY + 6.2)

            // Content Left: Atividades
            doc.setTextColor(117, 117, 117)
            doc.setFontSize(7)
            doc.setFont('helvetica', 'bold')
            doc.text('ATIVIDADES ATRIBUÍDAS', 20, currentY + 16)

            doc.setTextColor(33, 33, 33)
            doc.setFont('helvetica', 'normal')
            prof.atividades.forEach((atv: any, aIdx: number) => {
                const y = currentY + 22 + (aIdx * 5)
                // Dot
                doc.setFillColor(76, 175, 80)
                doc.circle(21, y - 1, 0.8, 'F')
                // Text
                doc.setFontSize(7.5)
                doc.text(`${atv.nome} - ${atv.nomeExtenso || ''} (${atv.turno}) (${(atv.ch / 15).toFixed(1)} h.a. | ${atv.ch}h)`, 24, y)
            })

            // Content Right: Disponibilidade
            const availX = 14 + (boxWidth * 0.6)
            doc.setTextColor(117, 117, 117)
            doc.setFontSize(7)
            doc.setFont('helvetica', 'bold')
            doc.text('DISPONIBILIDADE NA GRADE', availX, currentY + 16)

            let ax = availX
            let ay = currentY + 20
            Array.from(availability).sort().forEach((slot, sIdx) => {
                if (sIdx > 0 && sIdx % 3 === 0) {
                    ax = availX
                    ay += 8
                }

                const sText = slot
                const sWidth = doc.getTextWidth(sText) + 4
                doc.setDrawColor(21, 101, 192, 0.5)
                doc.setFillColor(232, 240, 254)
                doc.roundedRect(ax, ay, sWidth, 5, 1.5, 1.5, 'FD')
                doc.setTextColor(21, 101, 192)
                doc.setFontSize(6.5)
                doc.text(sText, ax + 2, ay + 3.5)
                ax += sWidth + 2
            })

            currentY += boxHeight + 5
        })

        doc.save(`Relatorio_Grade_${semestreId}.pdf`)
    }

    const handleDeleteAula = async (id: string | number) => {
        if (!confirm('Tem certeza que deseja excluir esta aula?')) return

        try {
            const { error } = await supabase.from('grade_aulas').delete().eq('id', id)
            if (error) throw error

            setViewingAulas(prev => prev ? prev.filter(a => a.id !== id) : null)
            fetchAllData()
        } catch (err: any) {
            alert('Erro ao excluir aula: ' + err.message)
        }
    }

    const openModalForSlot = (dia: string, turno: string, indice: number) => {
        const horario = HORARIOS[turno as keyof typeof HORARIOS]?.[indice] || ''
        const aulas = grade.filter(g => g.dia === dia && g.horario === horario)

        if (aulas.length > 0) {
            setViewingAulas(aulas)
            setViewingSlotInfo({ dia, turno, indice })
        } else {
            if (userAccessLevel === 2) return // Read-only can't add classes
            setInitialSlot({ dia, turno, indice })
            setIsModalOpen(true)
        }
    }

    const openLoteModal = () => {
        setInitialSlot(null)
        setIsModalOpen(true)
    }

    // Helper para encontrar aula num slot especifico
    const getAula = (dia: string, horario: string) => {
        return grade.find(g => g.dia === dia && (g.horario || '').includes(horario.split('-')[0].trim()))
        // Nota: a comparacao de horario precisa ser exata ou robusta. 
        // No banco antigo o horario pode estar salvo como '07h - 08h' ou diferente.
        // Vou assumir por enquanto que precisamos normalizar ou a string bate exato.
    }

    return (
        <div className="min-h-screen bg-gray-50 flex flex-col">
            <AddClassModal
                isOpen={isModalOpen}
                onClose={() => setIsModalOpen(false)}
                onSave={handleAddClass}
                turnos={TURNOS}
                dias={DIAS}
                horarios={HORARIOS}
                disciplinas={disciplinas}
                professores={professores}
                initialSlot={initialSlot}
            />

            <ViewClassesModal
                isOpen={!!viewingAulas}
                onClose={() => setViewingAulas(null)}
                aulas={viewingAulas || []}
                dia={viewingSlotInfo?.dia}
                turno={viewingSlotInfo?.turno}
                indice={viewingSlotInfo?.indice}
                onAdd={() => {
                    setInitialSlot(viewingSlotInfo)
                    setIsModalOpen(true)
                }}
                onDelete={handleDeleteAula}
                userAccessLevel={userAccessLevel}
            />

            {/* Header */}
            <header className="bg-white border-b border-gray-200 sticky top-0 z-20">
                <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-4">
                        <Link href="/semestre" className="p-2 hover:bg-gray-100 rounded-full transition-colors text-gray-500">
                            <ArrowLeft size={20} />
                        </Link>
                        <div>
                            <h1 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                                <Calendar size={20} className="text-indigo-600" />
                                Grade de Horários
                            </h1>
                            <p className="text-xs text-gray-500 font-medium">Semestre {semestreId}</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-3">
                        {/* Simulation Selector */}
                        {simulacoes.length > 0 && (
                            <div className="flex items-center gap-2 bg-white border rounded-lg px-3 py-1.5">
                                <select
                                    value={selectedSimulacao}
                                    onChange={(e) => setSelectedSimulacao(e.target.value)}
                                    className="text-sm font-medium text-gray-700 outline-none bg-transparent"
                                >
                                    <option value="grade_oficial">Grade Atual</option>
                                    <optgroup label="Simulações">
                                        {simulacoes.map(sim => (
                                            <option key={sim.id} value={sim.id}>{sim.nome}</option>
                                        ))}
                                    </optgroup>
                                </select>
                                {userAccessLevel !== 2 && (
                                    <button
                                        onClick={importSimulationToGrade}
                                        disabled={importing}
                                        className="bg-emerald-600 hover:bg-emerald-700 text-white px-3 py-1.5 rounded-md text-sm font-medium flex items-center disabled:opacity-50"
                                        title="Importar simulação para a grade"
                                    >
                                        <Download size={14} className="mr-1.5" />
                                        {importing ? 'Importando...' : 'Importar'}
                                    </button>
                                )}
                                <button
                                    onClick={() => setShowSidebar(!showSidebar)}
                                    className="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-1.5 rounded-md text-sm font-medium flex items-center"
                                    title="Ver resumo de docentes"
                                >
                                    <Users size={14} className="mr-1.5" />
                                    Resumo
                                </button>
                            </div>
                        )}

                        <div className="flex bg-gray-100 p-1 rounded-lg">
                            {TURNOS.map(turno => (
                                <button
                                    key={turno}
                                    onClick={() => setSelectedTurno(turno)}
                                    className={clsx(
                                        "px-4 py-1.5 text-sm font-medium rounded-md transition-all",
                                        selectedTurno === turno
                                            ? "bg-white text-indigo-600 shadow-sm"
                                            : "text-gray-500 hover:text-gray-700"
                                    )}
                                >
                                    {turno}
                                </button>
                            ))}
                        </div>

                        <div className="flex gap-2">
                            {userAccessLevel !== 2 && (
                                <button
                                    onClick={handleClearGrade}
                                    className="bg-white text-red-600 px-4 py-2 rounded-lg text-sm font-medium flex items-center hover:bg-red-50 transition-colors border border-red-100"
                                    title="Limpar toda a grade"
                                >
                                    <Trash2 size={16} className="mr-2" />
                                    Limpar
                                </button>
                            )}
                            <button
                                onClick={generatePDF}
                                className="bg-white text-gray-700 px-4 py-2 rounded-lg text-sm font-medium flex items-center hover:bg-gray-50 transition-colors border border-gray-200"
                                title="Salvar em PDF"
                            >
                                <FileText size={16} className="mr-2" />
                                PDF
                            </button>
                            {userAccessLevel !== 2 && (
                                <button
                                    onClick={openLoteModal}
                                    className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm font-medium flex items-center shadow-sm transition-all hover:shadow-md active:scale-95"
                                >
                                    <Plus size={16} className="mr-2" />
                                    Lançar Aulas
                                </button>
                            )}
                        </div>
                    </div>
                </div>
            </header>

            {/* Sidebar - Professor Summary */}
            {showSidebar && (
                <div className="fixed right-0 top-16 bottom-0 w-96 bg-gray-50 border-l border-gray-200 shadow-xl z-30 flex flex-col">
                    <div className="p-4 border-b bg-white sticky top-0 z-10">
                        <div className="flex items-center justify-between">
                            <h3 className="font-bold text-gray-800 flex items-center gap-2 text-sm uppercase tracking-wider">
                                <Users size={18} className="text-gray-500" />
                                Docentes - Detalhes
                            </h3>
                            <button
                                onClick={() => setShowSidebar(false)}
                                className="p-1.5 hover:bg-gray-100 rounded-full transition-colors"
                            >
                                <X size={18} className="text-gray-400" />
                            </button>
                        </div>

                        <div className="mt-4 flex bg-gray-100 p-1 rounded-lg">
                            <button
                                onClick={() => setSidebarSortBy('apelido')}
                                className={clsx(
                                    "flex-1 px-3 py-1.5 text-[10px] font-bold rounded-md transition-all uppercase tracking-wider",
                                    sidebarSortBy === 'apelido' ? "bg-white text-indigo-600 shadow-sm" : "text-gray-500"
                                )}
                            >
                                Nome
                            </button>
                            <button
                                onClick={() => setSidebarSortBy('ch')}
                                className={clsx(
                                    "flex-1 px-3 py-1.5 text-[10px] font-bold rounded-md transition-all uppercase tracking-wider",
                                    sidebarSortBy === 'ch' ? "bg-white text-indigo-600 shadow-sm" : "text-gray-500"
                                )}
                            >
                                CH total
                            </button>
                        </div>
                    </div>

                    <div className="flex-1 overflow-y-auto p-3 space-y-3">
                        {professorSummary.length === 0 ? (
                            <div className="flex flex-col items-center justify-center h-64 text-gray-400 text-sm">
                                <Users size={48} className="mb-4 opacity-20" />
                                <p>Nenhum docente com aulas atribuídas</p>
                            </div>
                        ) : (
                            professorSummary.map((prof: any, idx: number) => {
                                const totalHa = prof.totalCH / 15

                                return (
                                    <div key={idx} className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                                        <div className="p-4">
                                            <div className="flex items-start justify-between gap-3 mb-3">
                                                <h4 className="font-bold text-slate-900 text-sm leading-tight flex-1">
                                                    {prof.apelido}
                                                </h4>
                                                <div className="bg-slate-100 border border-slate-200 px-2 py-1 rounded-lg flex items-center gap-1.5 shrink-0">
                                                    <span className="text-slate-700 font-bold text-[11px]">
                                                        {totalHa.toFixed(1)} h.a.
                                                    </span>
                                                    <span className="text-slate-500 text-[10px] font-medium">
                                                        ({prof.totalCH}hrs)
                                                    </span>
                                                </div>
                                            </div>

                                            {prof.atividades.length > 0 ? (
                                                <div className="space-y-2 border-t pt-2 mt-1">
                                                    {prof.atividades.map((atv: any, atvIdx: number) => (
                                                        <div key={atvIdx} className="flex items-start gap-2 text-[11px]">
                                                            <div className="mt-1.5 w-1.5 h-1.5 rounded-full bg-slate-400 shrink-0" />
                                                            <div className="flex-1 min-w-0">
                                                                <div className="font-bold text-slate-700 leading-snug">
                                                                    {atv.nomeExtenso}
                                                                </div>
                                                            </div>
                                                            <div className="bg-slate-50 text-slate-600 px-1.5 py-0.5 rounded font-bold text-[9px] whitespace-nowrap lg:flex gap-1 hidden">
                                                                <span>{atv.turno}</span>
                                                            </div>
                                                            <div className="bg-slate-50 text-slate-600 px-1.5 py-0.5 rounded font-bold text-[9px] whitespace-nowrap self-start border border-slate-100 flex items-center gap-1">
                                                                <span>{(atv.ch / 15).toFixed(1)} h.a.</span>
                                                                <span className="opacity-70 text-[8px]">({atv.ch}hrs)</span>
                                                            </div>
                                                        </div>
                                                    ))}
                                                </div>
                                            ) : (
                                                <p className="text-[11px] text-slate-400 italic mt-2">
                                                    Sem atividades atribuídas
                                                </p>
                                            )}
                                        </div>
                                    </div>
                                )
                            })
                        )}
                    </div>
                </div>
            )}

            {/* Main Grid */}
            <main className="flex-1 overflow-auto p-4 md:p-8">
                {loading ? (
                    <div className="flex justify-center items-center h-64">
                        <Loader2 className="animate-spin text-indigo-600" size={32} />
                    </div>
                ) : (
                    <div className="max-w-7xl mx-auto">
                        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
                            <div className="grid grid-cols-[100px_repeat(6,1fr)] divide-x divide-gray-200 border-b border-gray-200 bg-gray-50">
                                <div className="p-4 text-xs font-bold text-gray-400 uppercase tracking-wider text-center flex items-center justify-center">
                                    Horário
                                </div>
                                {DIAS.map(dia => (
                                    <div key={dia} className="p-4 text-sm font-bold text-gray-700 text-center uppercase tracking-wide">
                                        {dia}
                                    </div>
                                ))}
                            </div>

                            <div className="divide-y divide-gray-200">
                                {HORARIOS[selectedTurno as keyof typeof HORARIOS].map((horario, idx) => (
                                    <div key={horario} className="grid grid-cols-[100px_repeat(6,1fr)] divide-x divide-gray-200 hover:bg-gray-50/50 transition-colors">
                                        {/* Coluna de Horario */}
                                        <div className="p-2 text-[10px] font-medium text-gray-500 flex items-center justify-center border-r bg-gray-50/30 h-24">
                                            {horario}
                                        </div>

                                        {/* Colunas de Dias */}
                                        {DIAS.map(dia => {
                                            // Find all classes for this day and time slot
                                            const aulas = grade.filter(g =>
                                                g.dia === dia && g.horario === horario
                                            )

                                            const colorClass = selectedTurno === 'Manhã' ? 'bg-amber-50 border-amber-200 text-amber-900' :
                                                selectedTurno === 'Tarde' ? 'bg-orange-50 border-orange-200 text-orange-900' :
                                                    'bg-indigo-50 border-indigo-200 text-indigo-900'

                                            const subTextColor = selectedTurno === 'Manhã' ? 'text-amber-700' :
                                                selectedTurno === 'Tarde' ? 'text-orange-700' :
                                                    'text-indigo-700'

                                            return (
                                                <div
                                                    key={`${dia}-${horario}`}
                                                    className="h-32 p-1.5 relative group cursor-pointer hover:bg-gray-50/50 transition-colors overflow-hidden"
                                                    onClick={() => openModalForSlot(dia, selectedTurno, idx)}
                                                >
                                                    {aulas.length > 0 ? (
                                                        <div className="space-y-1 h-full overflow-y-auto">
                                                            {aulas.map((aula, aulaIdx) => (
                                                                <div key={aulaIdx} className={clsx("border rounded-md p-1.5 shadow-sm hover:shadow transition-shadow", colorClass)}>
                                                                    <div className="font-semibold text-[9px] leading-snug" style={{ fontFamily: 'Inter, sans-serif' }} title={`${aula.disciplina_nome} - ${aula.professor}`}>
                                                                        <span className="text-gray-900">{aula.disciplina_nome || aula.disciplina}</span>
                                                                        <span className={clsx("ml-1", subTextColor)}>- {aula.professor}</span>
                                                                    </div>
                                                                </div>
                                                            ))}
                                                        </div>
                                                    ) : (
                                                        <div className="h-full w-full flex items-center justify-center opacity-0 group-hover:opacity-100">
                                                            {userAccessLevel !== 2 && <Plus size={16} className="text-gray-300" />}
                                                        </div>
                                                    )}
                                                </div>
                                            )
                                        })}
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                )}
            </main>

        </div>
    )
}

export default function GradePage() {
    return (
        <Suspense fallback={<div>Carregando...</div>}>
            <GradeContent />
        </Suspense>
    )
}
