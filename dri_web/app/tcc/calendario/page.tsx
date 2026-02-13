'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    X,
    Grid,
    Search,
    RefreshCw,
    GraduationCap,
    ChevronDown,
    Loader2,
    Info,
    ChevronRight,
    Edit,
    Trash2,
    Share2,
    Award,
    Mic,
    CheckCircle,
    FileText,
    ChevronLeft,
    ArrowLeft,
    Clock,
    MapPin,
    Calendar,
    User
} from 'lucide-react'
import clsx from 'clsx'
import {
    generateAta, generateCertificado, generateFichaIndividual,
    generateFolhaAprovacao, generateFichaFinal
} from '@/lib/tcc-pdf';

const MONTHS = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
]

const DAYS_OF_WEEK = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']

export default function CalendarioPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [defesas, setDefesas] = useState<any[]>([])
    const [currentDate, setCurrentDate] = useState(new Date())
    const [selectedDate, setSelectedDate] = useState<Date | null>(null)
    const [selectedDefesas, setSelectedDefesas] = useState<any[]>([])
    const [selectedDefesaInfo, setSelectedDefesaInfo] = useState<any | null>(null)
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [isDetailModalOpen, setIsDetailModalOpen] = useState(false)
    const [generatingPdf, setGeneratingPdf] = useState(false)
    const [expandFichas, setExpandFichas] = useState(false)

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

    const fetchDefesas = async () => {
        setLoading(true)
        const { data, error } = await supabase
            .from('dados_defesas')
            .select('*')

        if (data) setDefesas(data)
        setLoading(false)
    }

    const getDaysInMonth = (year: number, month: number) => {
        return new Date(year, month + 1, 0).getDate()
    }

    const getFirstDayOfMonth = (year: number, month: number) => {
        return new Date(year, month, 1).getDay()
    }

    const handlePrevMonth = () => {
        setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1))
    }

    const handleNextMonth = () => {
        setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1))
    }

    const getDateString = (year: number, month: number, day: number) => {
        const y = year
        const m = String(month + 1).padStart(2, '0')
        const d = String(day).padStart(2, '0')
        return `${y}-${m}-${d}`
    }

    const handleDayClick = (day: number) => {
        const year = currentDate.getFullYear()
        const month = currentDate.getMonth()
        const dateString = getDateString(year, month, day)

        const defensesOnDay = defesas.filter(d => d.dia === dateString)

        if (defensesOnDay.length > 0) {
            setSelectedDate(new Date(year, month, day))
            setSelectedDefesas(defensesOnDay)
            setIsModalOpen(true)
        }
    }

    const handleDefesaClick = (defesa: any) => {
        setSelectedDefesaInfo(defesa)
        setIsDetailModalOpen(true)
    }

    const handleDelete = async (id: number, nome: string) => {
        if (!confirm(`Deseja realmente excluir a banca de ${nome}?`)) return
        setLoading(true)
        try {
            await supabase.from('notas').delete().eq('defesa_id', id)
            await supabase.from('dados_defesa_final').delete().eq('defesa_id', id)
            const { error } = await supabase.from('dados_defesas').delete().eq('id', id)
            if (error) throw error
            setDefesas(prev => prev.filter(d => d.id !== id))
            setIsDetailModalOpen(false)
            setSelectedDefesaInfo(null)
            alert('Banca excluída com sucesso!')
        } catch (err) {
            console.error('Erro ao excluir banca:', err)
            alert('Erro ao excluir banca.')
        } finally {
            setLoading(false)
        }
    }

    const handleGenerateAta = async () => {
        if (!selectedDefesaInfo) return;
        setGeneratingPdf(true);
        try { await generateAta(selectedDefesaInfo); }
        catch (error) { alert('Erro ao gerar Ata'); }
        finally { setGeneratingPdf(false); }
    };

    const handleGenerateCertificados = async () => {
        if (!selectedDefesaInfo) return;
        setGeneratingPdf(true);
        try {
            await generateCertificado(selectedDefesaInfo, selectedDefesaInfo.orientador, 'orientador');
            if (selectedDefesaInfo.avaliador1) await generateCertificado(selectedDefesaInfo, selectedDefesaInfo.avaliador1, 'avaliador');
            if (selectedDefesaInfo.avaliador2) await generateCertificado(selectedDefesaInfo, selectedDefesaInfo.avaliador2, 'avaliador');
            if (selectedDefesaInfo.avaliador3) await generateCertificado(selectedDefesaInfo, selectedDefesaInfo.avaliador3, 'avaliador');
        } catch (error) { alert('Erro ao gerar Certificados'); }
        finally { setGeneratingPdf(false); }
    };

    const handleGenerateFolhaAprovacao = async () => {
        if (!selectedDefesaInfo) return;
        setGeneratingPdf(true);
        try { await generateFolhaAprovacao(selectedDefesaInfo); }
        catch (error) { alert('Erro ao gerar Folha de Aprovação'); }
        finally { setGeneratingPdf(false); }
    };

    const handleGenerateFichaFinal = async () => {
        if (!selectedDefesaInfo) return;
        setGeneratingPdf(true);
        try { await generateFichaFinal(selectedDefesaInfo); }
        catch (error) { alert('Erro ao gerar Ficha Final'); }
        finally { setGeneratingPdf(false); }
    };

    const renderCalendar = () => {
        const year = currentDate.getFullYear()
        const month = currentDate.getMonth()
        const daysInMonth = getDaysInMonth(year, month)
        const firstDay = getFirstDayOfMonth(year, month)

        const days = []

        // Empty slots for previous month
        for (let i = 0; i < firstDay; i++) {
            days.push(<div key={`empty-${i}`} className="h-24 md:h-32 bg-gray-50/30 border border-gray-100 rounded-xl m-1 opacity-50"></div>)
        }

        // Days of current month
        for (let day = 1; day <= daysInMonth; day++) {
            const dateString = getDateString(year, month, day)
            const defensesOnDay = defesas.filter(d => d.dia === dateString)
            const isToday = new Date().toDateString() === new Date(year, month, day).toDateString()

            days.push(
                <div
                    key={day}
                    onClick={() => handleDayClick(day)}
                    className={clsx(
                        "h-24 md:h-32 m-1 p-2 border rounded-xl flex flex-col justify-between transition-all cursor-pointer relative overflow-hidden group",
                        isToday ? "bg-indigo-50 border-indigo-200" : "bg-white border-gray-100 hover:border-indigo-200 hover:shadow-md"
                    )}
                >
                    <span className={clsx(
                        "text-sm font-bold w-7 h-7 flex items-center justify-center rounded-full",
                        isToday ? "bg-indigo-600 text-white" : "text-gray-700 bg-gray-100 group-hover:bg-indigo-100 group-hover:text-indigo-700"
                    )}>
                        {day}
                    </span>

                    <div className="flex flex-col gap-1 mt-1 overflow-y-auto max-h-[70%] scrollbar-hide">
                        {defensesOnDay.map((defesa, idx) => (
                            <div key={idx} className="bg-indigo-50 border border-indigo-100 rounded px-1.5 py-1 text-[9px] md:text-[10px] text-indigo-800 font-medium truncate w-full" title={defesa.discente}>
                                {defesa.hora?.slice(0, 5)} - {defesa.discente.split(' ')[0]}
                            </div>
                        ))}
                    </div>

                    {defensesOnDay.length > 3 && (
                        <div className="absolute bottom-1 right-2 text-[9px] font-bold text-gray-400 bg-white/80 px-1 rounded-full">
                            +{defensesOnDay.length - 3} mais
                        </div>
                    )}
                </div>
            )
        }

        return days
    }

    const unscheduledDefesas = defesas.filter(d => !d.dia)

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-gray-900 font-sans antialiased selection:bg-indigo-100 selection:text-indigo-900 flex flex-col">
            {/* Dynamic Background */}
            <div className="fixed inset-0 z-0 pointer-events-none opacity-40">
                <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-100 blur-[120px]" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-100 blur-[120px]" />
            </div>

            {/* Navbar */}
            <nav className="relative z-20 px-4 py-3 md:px-8 flex justify-between items-center w-full border-b border-white/50 bg-white/30 backdrop-blur-md sticky top-0">
                <div className="flex items-center space-x-3">
                    <Link href="/tcc" className="group flex items-center gap-3">
                        <div className="w-8 h-8 bg-white rounded-lg flex items-center justify-center shadow-sm border border-slate-200 text-slate-600 group-hover:text-indigo-600 group-hover:border-indigo-100 group-hover:scale-105 transition-all">
                            <ArrowLeft size={18} />
                        </div>
                        <span className="font-extrabold text-base md:text-xl text-slate-900 tracking-tight">
                            Calendário <span className="text-indigo-600">Defesas</span>
                        </span>
                    </Link>
                </div>
            </nav>

            <main className="relative z-20 flex-1 flex flex-col md:flex-row overflow-hidden h-[calc(100vh-60px)]">

                {/* Main Calendar Area - 75% width on desktop */}
                <div className="flex-1 flex flex-col p-4 md:p-6 overflow-y-auto">
                    {/* Controls */}
                    <div className="flex items-center justify-between mb-4 bg-white p-3 rounded-xl shadow-sm border border-gray-100">
                        <div className="flex items-center gap-3">
                            <button onClick={handlePrevMonth} className="p-1.5 hover:bg-gray-100 rounded-full transition-colors text-gray-500 hover:text-indigo-600">
                                <ChevronLeft size={20} />
                            </button>
                            <h2 className="text-lg md:text-xl font-black text-gray-800 capitalize min-w-[150px] text-center">
                                {MONTHS[currentDate.getMonth()]} <span className="text-indigo-600">{currentDate.getFullYear()}</span>
                            </h2>
                            <button onClick={handleNextMonth} className="p-1.5 hover:bg-gray-100 rounded-full transition-colors text-gray-500 hover:text-indigo-600">
                                <ChevronRight size={20} />
                            </button>
                        </div>

                        <div className="text-xs font-medium text-gray-500 hidden md:block">
                            <span className="bg-indigo-50 text-indigo-700 px-2.5 py-1 rounded-full font-bold border border-indigo-100">
                                {defesas.filter(d => {
                                    if (!d.dia) return false
                                    const date = new Date(d.dia + 'T12:00:00')
                                    return date.getMonth() === currentDate.getMonth() && date.getFullYear() === currentDate.getFullYear()
                                }).length} agendadas
                            </span>
                        </div>
                    </div>

                    {/* Calendar Grid - Compact */}
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col min-h-0 overflow-hidden">
                        {/* Weekday Headers */}
                        <div className="grid grid-cols-7 border-b border-gray-100">
                            {DAYS_OF_WEEK.map(day => (
                                <div key={day} className="text-center text-[10px] font-black text-gray-400 uppercase tracking-wider py-2 bg-gray-50/50">
                                    {day}
                                </div>
                            ))}
                        </div>

                        {/* Days Grid - Scrollable if needed, but intended to fit */}
                        <div className="grid grid-cols-7 flex-1 auto-rows-fr overflow-y-auto p-1 gap-1">
                            {renderCalendar()}
                        </div>
                    </div>
                </div>

                {/* Sidebar - Unscheduled Defenses - 25% width on desktop */}
                <div className="w-full md:w-80 lg:w-96 bg-white border-l border-gray-100 md:shadow-xl shadow-gray-200 flex flex-col z-30">
                    <div className="p-4 border-b border-gray-100 bg-gray-50/50">
                        <h3 className="text-sm font-black text-gray-800 uppercase tracking-wide flex items-center gap-2">
                            <span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse"></span>
                            A Agendar ({unscheduledDefesas.length})
                        </h3>
                    </div>

                    <div className="flex-1 overflow-y-auto p-2 space-y-1.5">
                        {unscheduledDefesas.length === 0 ? (
                            <div className="text-center py-10 text-gray-400 text-xs italic">
                                Nenhuma defesa pendente de agendamento.
                            </div>
                        ) : (
                            unscheduledDefesas.map(defesa => (
                                <Link
                                    key={defesa.id}
                                    href={`/tcc/editar?id=${defesa.id}`}
                                    className="bg-white border border-gray-100 rounded-lg p-2.5 shadow-sm hover:shadow-md hover:border-indigo-200 transition-all group cursor-pointer relative overflow-hidden block"
                                >
                                    <div className="absolute left-0 top-0 bottom-0 w-1 bg-amber-300 rounded-l-lg"></div>
                                    <div className="pl-2">
                                        <h4 className="font-bold text-gray-900 group-hover:text-indigo-700 transition-colors uppercase leading-tight text-[11px] truncate mb-0.5" title={defesa.discente}>
                                            {defesa.discente}
                                        </h4>
                                        <div className="flex items-center gap-1.5 text-[10px] text-gray-500">
                                            <User size={10} className="text-gray-400 shrink-0" />
                                            <span className="truncate italic">{defesa.orientador || 'Docente N/A'}</span>
                                        </div>
                                    </div>
                                </Link>
                            ))
                        )}
                    </div>
                </div>

            </main>

            {/* Daily Summary Modal */}
            {isModalOpen && selectedDate && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm animate-in fade-in duration-200">
                    <div className="bg-white rounded-3xl shadow-2xl w-full max-w-lg max-h-[80vh] flex flex-col animate-in zoom-in-95 duration-200 border border-gray-100">
                        <div className="bg-indigo-50 p-6 rounded-t-3xl border-b border-indigo-100 flex justify-between items-start">
                            <div>
                                <h3 className="text-2xl font-black text-indigo-900">
                                    {selectedDate.getDate()} de {MONTHS[selectedDate.getMonth()]}
                                </h3>
                                <p className="text-indigo-500 font-medium text-sm">{DAYS_OF_WEEK[selectedDate.getDay()]}</p>
                            </div>
                            <button onClick={() => setIsModalOpen(false)} className="p-2 bg-white/50 hover:bg-white rounded-full text-indigo-700 transition-colors">
                                <X size={20} />
                            </button>
                        </div>

                        <div className="p-6 overflow-y-auto flex-1 space-y-4">
                            {selectedDefesas.map((defesa, idx) => (
                                <div
                                    key={idx}
                                    onClick={() => handleDefesaClick(defesa)}
                                    className="bg-white border border-gray-100 rounded-xl p-4 shadow-sm hover:shadow-md hover:border-indigo-100 transition-all group cursor-pointer"
                                >
                                    <div className="flex justify-between items-start mb-2">
                                        <h4 className="font-bold text-gray-900 group-hover:text-indigo-700 transition-colors uppercase leading-tight text-sm">
                                            {defesa.discente}
                                        </h4>
                                        <span className="bg-indigo-100 text-indigo-700 text-[10px] font-black px-2 py-0.5 rounded-full flex items-center gap-1">
                                            <Clock size={10} /> {defesa.hora ? defesa.hora.slice(0, 5) : '--:--'}
                                        </span>
                                    </div>

                                    <div className="flex items-center gap-2 text-xs text-gray-600">
                                        <User size={12} className="text-gray-400" />
                                        <span className="truncate flex-1 font-bold">{defesa.orientador}</span>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            )}

            {/* FULL DETAIL MODAL (MATCHING VISUALIZAR PAGE) */}
            {isDetailModalOpen && selectedDefesaInfo && (
                <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-in fade-in duration-200">
                    <div className="bg-white w-full max-w-lg rounded-[2.5rem] shadow-2xl overflow-hidden border border-slate-100 flex flex-col max-h-[90vh] animate-in zoom-in-95 duration-200">
                        {/* Modal Header */}
                        <div className="bg-[#E0F2FE] p-6 pb-12 relative">
                            <button
                                onClick={() => setIsDetailModalOpen(false)}
                                className="absolute right-6 top-6 w-8 h-8 rounded-full bg-white/50 flex items-center justify-center text-[#0C4A6E] hover:bg-white transition-all"
                            >
                                <X size={16} />
                            </button>
                            <div className="flex items-center gap-3 mb-2">
                                <span className="bg-[#0C4A6E] text-white px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-widest">
                                    {selectedDefesaInfo.semestre}
                                </span>
                                <span className="text-[#0284C7] text-[10px] font-bold flex items-center gap-1">
                                    <Clock size={12} />
                                    {selectedDefesaInfo.hora ? (selectedDefesaInfo.hora.length > 5 ? selectedDefesaInfo.hora.substring(0, 5) : selectedDefesaInfo.hora) : '--:--'}
                                </span>
                            </div>
                            <h2 className="text-[#0C4A6E] text-xl font-black uppercase leading-tight italic">
                                {selectedDefesaInfo.discente}
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
                                            &quot;{selectedDefesaInfo.titulo || 'TÍTULO NÃO INFORMADO'}&quot;
                                        </p>
                                    </div>

                                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                                        <div className="flex items-center gap-3 bg-slate-50 p-3 rounded-xl border border-slate-100">
                                            <MapPin size={16} className="text-blue-400" />
                                            <div>
                                                <p className="text-[8px] font-black text-slate-400 uppercase">Local</p>
                                                <p className="text-xs font-bold text-slate-700">{selectedDefesaInfo.local || 'A DEFINIR'}</p>
                                            </div>
                                        </div>
                                        <div className="flex items-center gap-3 bg-slate-50 p-3 rounded-xl border border-slate-100">
                                            <Calendar size={16} className="text-blue-400" />
                                            <div>
                                                <p className="text-[8px] font-black text-slate-400 uppercase">Data</p>
                                                <p className="text-xs font-bold text-slate-700">
                                                    {selectedDefesaInfo.dia ? new Intl.DateTimeFormat('pt-BR').format(new Date(selectedDefesaInfo.dia + 'T12:00:00')) : 'A DEFINIR'}
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
                                            { label: 'Orientador', value: selectedDefesaInfo.orientador },
                                            { label: 'Coorientador', value: selectedDefesaInfo.coorientador },
                                            { label: 'Avaliador 1', value: selectedDefesaInfo.avaliador1 },
                                            { label: 'Avaliador 2', value: selectedDefesaInfo.avaliador2 },
                                            { label: 'Avaliador 3', value: selectedDefesaInfo.avaliador3 },
                                        ].filter(b => b.value).map((mem, idx) => (
                                            <div key={idx} className="flex items-center justify-between p-2.5 bg-white border border-slate-100 rounded-xl hover:bg-blue-50/30 transition-colors">
                                                <span className="text-[9px] font-black text-[#0284C7] uppercase">{mem.label}</span>
                                                <span className="text-[11px] font-bold text-slate-700">{mem.value}</span>
                                            </div>
                                        ))}
                                    </div>
                                </section>

                                {/* Documentos Acadêmicos */}
                                <section className="space-y-3">
                                    <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-2">
                                        <div className="h-px flex-1 bg-slate-100" />
                                        Documentos Acadêmicos
                                        <div className="h-px flex-1 bg-slate-100" />
                                    </h4>

                                    <div className="space-y-2">
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
                                                        { label: 'Orientador', index: 1, name: selectedDefesaInfo.orientador },
                                                        { label: 'Membro 1', index: 2, name: selectedDefesaInfo.avaliador2 },
                                                        { label: 'Membro 2', index: 3, name: selectedDefesaInfo.avaliador3 },
                                                    ].filter(m => m.name).map((m) => (
                                                        <button
                                                            key={m.index}
                                                            disabled={generatingPdf}
                                                            onClick={async () => {
                                                                setGeneratingPdf(true);
                                                                try {
                                                                    await generateFichaIndividual(selectedDefesaInfo, m.index);
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
                                    <button
                                        onClick={() => {
                                            const link = `${window.location.origin}/defesas/avaliar?id=${selectedDefesaInfo.id}`
                                            navigator.clipboard.writeText(link)
                                            alert('Link de avaliação copiado!')
                                        }}
                                        className="w-full flex items-center justify-center gap-2 bg-slate-50 text-slate-600 px-4 py-3 rounded-xl border border-slate-100 text-[10px] font-black uppercase hover:bg-slate-100 transition-all"
                                    >
                                        <Share2 size={16} />
                                        Copiar Link de Avaliação
                                    </button>
                                </section>
                            </div>
                        </div>

                        {/* Modal Footer (Actions) */}
                        <div className="p-6 bg-slate-50 border-t border-slate-100 flex items-center gap-3">
                            <Link
                                href={`/defesas/avaliar?id=${selectedDefesaInfo.id}`}
                                className="flex-1 bg-[#0C4A6E] text-white py-3 rounded-2xl text-[10px] font-black uppercase tracking-widest flex items-center justify-center gap-2 shadow-lg shadow-blue-100 hover:bg-[#0284C7] transition-all"
                            >
                                <Edit size={14} />
                                Lançar Notas
                            </Link>
                            <Link
                                href={`/tcc/editar?id=${selectedDefesaInfo.id}`}
                                className="w-12 h-12 flex items-center justify-center bg-white border border-slate-200 rounded-2xl text-slate-400 hover:text-blue-600 hover:border-blue-200 transition-all shadow-sm"
                                title="Editar Cadastro"
                            >
                                <FileText size={20} />
                            </Link>
                            <button
                                onClick={() => handleDelete(selectedDefesaInfo.id, selectedDefesaInfo.discente)}
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
