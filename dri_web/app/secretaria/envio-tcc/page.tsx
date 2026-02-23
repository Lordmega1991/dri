'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Upload,
    CheckCircle2,
    Clock,
    Loader2,
    FileText,
    Info,
    Check,
    ExternalLink,
    CalendarDays
} from 'lucide-react'
import clsx from 'clsx'
import { uploadToDrive } from './actions'

type UploadRecord = {
    doc_type: string
    file_name: string
    drive_link: string
    uploaded_at: string
}

export default function EnvioTccPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [userAuth, setUserAuth] = useState<any>(null)
    const [accessData, setAccessData] = useState<any>(null)
    const [uploadRecords, setUploadRecords] = useState<UploadRecord[]>([])

    const [uploading, setUploading] = useState<{ tcc: boolean, termo: boolean }>({ tcc: false, termo: false })
    const [completed, setCompleted] = useState<{ tcc: boolean, termo: boolean }>({ tcc: false, termo: false })

    useEffect(() => {
        const loadUserData = async () => {
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) { router.push('/login'); return }
            setUserAuth(session.user)

            const { data: access } = await supabase
                .from('users_access')
                .select('*')
                .eq('id', session.user.id)
                .single()

            if (access) {
                setAccessData(access)
                if (!access.nomecompleto || !access.matricula) {
                    alert('Por favor, complete seu cadastro na secretaria antes de enviar documentos.')
                    router.push('/secretaria')
                    return
                }
            } else {
                router.push('/secretaria')
                return
            }

            // Busca histórico de uploads desta categoria
            const { data: uploads } = await supabase
                .from('document_uploads')
                .select('doc_type, file_name, drive_link, uploaded_at')
                .eq('user_id', session.user.id)
                .eq('category', 'tcc')
                .order('uploaded_at', { ascending: false })

            if (uploads) {
                setUploadRecords(uploads)
                // Marca como já enviado se existir registro
                const hasTcc = uploads.some(u => u.doc_type === 'TCC')
                const hasTermo = uploads.some(u => u.doc_type === 'TERMO')
                setCompleted({ tcc: hasTcc, termo: hasTermo })
            }

            setLoading(false)
        }
        loadUserData()
    }, [router])

    const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>, type: 'TCC' | 'TERMO') => {
        const file = e.target.files?.[0]
        if (!file || !accessData) return

        if (file.type !== 'application/pdf') {
            alert('Por favor, selecione apenas arquivos PDF.')
            return
        }

        const typeKey = type.toLowerCase() as 'tcc' | 'termo'
        setUploading(prev => ({ ...prev, [typeKey]: true }))

        try {
            const formData = new FormData()
            formData.append('file', file)
            formData.append('type', type)

            const result = await uploadToDrive(
                formData,
                userAuth.id,
                accessData.nomecompleto,
                accessData.matricula.toString()
            )

            if (result.success) {
                setCompleted(prev => ({ ...prev, [typeKey]: true }))

                // Salva no Supabase com a sessão autenticada do usuário (respeita o RLS)
                const { error: dbError } = await supabase
                    .from('document_uploads')
                    .insert({
                        user_id: userAuth.id,
                        doc_type: result.docType,
                        category: 'tcc',
                        file_name: result.fileName,
                        drive_link: result.link,
                        uploaded_at: new Date().toISOString()
                    })

                if (dbError) console.error('Erro ao salvar registro:', dbError)

                // Atualiza a lista local
                const newRecord: UploadRecord = {
                    doc_type: type,
                    file_name: result.fileName || '',
                    drive_link: result.link || '',
                    uploaded_at: new Date().toISOString()
                }
                setUploadRecords(prev => [newRecord, ...prev])
            } else {
                alert(`Erro no upload: ${result.error}`)
            }
        } catch (error) {
            console.error(error)
            alert('Erro crítico ao processar o upload.')
        } finally {
            setUploading(prev => ({ ...prev, [typeKey]: false }))
        }
    }

    const formatDate = (iso: string) => {
        const d = new Date(iso)
        return d.toLocaleDateString('pt-BR') + ' às ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
    }

    const lastTcc = uploadRecords.find(u => u.doc_type === 'TCC')
    const lastTermo = uploadRecords.find(u => u.doc_type === 'TERMO')

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-[#F5F5F7]">
                <Loader2 className="animate-spin text-indigo-600" size={32} />
            </div>
        )
    }

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-slate-800 font-sans antialiased selection:bg-indigo-100 selection:text-indigo-900">
            <div className="fixed inset-0 z-0 pointer-events-none opacity-40">
                <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-blue-100 blur-[120px]" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-100 blur-[120px]" />
            </div>

            <header className="bg-white/80 backdrop-blur-md border-b border-slate-200 sticky top-0 z-40">
                <div className="max-w-6xl mx-auto px-6 h-16 md:h-20 flex items-center">
                    <div className="flex items-center gap-4 md:gap-5">
                        <Link href="/secretaria" className="w-8 h-8 md:w-10 md:h-10 bg-slate-50 border border-slate-100 flex items-center justify-center rounded-xl md:rounded-2xl text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition-all shadow-sm">
                            <ArrowLeft size={18} />
                        </Link>
                        <div className="flex flex-col">
                            <h1 className="text-lg md:text-2xl font-black text-slate-900 tracking-tight leading-tight uppercase">Envio de TCC</h1>
                            <span className="text-[10px] md:text-xs font-bold uppercase tracking-wider text-indigo-600">Repositório Institucional</span>
                        </div>
                    </div>
                </div>
            </header>

            <main className="relative z-20 px-4 md:px-12 max-w-4xl mx-auto pb-10 pt-4">
                <div className="space-y-4">
                    {/* Banner de Instruções */}
                    <div className="bg-gradient-to-r from-indigo-600 to-indigo-700 rounded-[1.25rem] p-4 md:p-6 text-white relative overflow-hidden shadow-lg shadow-indigo-100">
                        <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full -mr-10 -mt-10 blur-2xl" />
                        <div className="relative z-10 flex gap-4 items-center">
                            <div className="w-10 h-10 bg-white/20 backdrop-blur-md rounded-xl flex items-center justify-center shrink-0">
                                <Info size={20} className="text-white" />
                            </div>
                            <div className="min-w-0">
                                <h2 className="text-base md:text-xl font-black tracking-tight uppercase leading-none mb-1.5">Instruções de Envio</h2>
                                <p className="text-indigo-50 font-medium text-xs md:text-sm uppercase tracking-wide leading-tight">
                                    Envie o PDF Final e o Termo de Depósito assinado pelo orientador.
                                </p>
                            </div>
                        </div>
                    </div>

                    {/* Cards de Upload */}
                    <div className="grid grid-cols-2 gap-4">
                        {/* Card TCC */}
                        <div className={clsx(
                            "bg-white/80 backdrop-blur-sm rounded-[1.25rem] p-4 md:p-6 border transition-all flex flex-col",
                            completed.tcc ? "border-emerald-200" : "border-white/50 shadow-sm"
                        )}>
                            <div className="flex items-center gap-3 mb-3">
                                <div className={clsx(
                                    "w-9 h-9 rounded-xl flex items-center justify-center transition-all shadow-sm shrink-0",
                                    completed.tcc ? "bg-emerald-500 text-white" : "bg-red-50 text-red-500"
                                )}>
                                    {completed.tcc ? <Check size={18} /> : <FileText size={18} />}
                                </div>
                                <div className="min-w-0">
                                    <h3 className="text-xs md:text-base font-black text-slate-900 uppercase tracking-tight leading-none">TCC PDF</h3>
                                    <p className="text-[9px] md:text-[11px] text-slate-500 font-bold uppercase tracking-wide mt-1">ABNT Final</p>
                                </div>
                            </div>

                            {/* Último envio */}
                            {lastTcc && (
                                <div className="mb-3 px-2.5 py-2 bg-emerald-50 rounded-lg border border-emerald-100 flex items-start gap-2">
                                    <CalendarDays size={10} className="text-emerald-500 mt-0.5 shrink-0" />
                                    <div className="min-w-0">
                                        <p className="text-[9px] font-black text-slate-900 uppercase tracking-wide leading-none">Último envio</p>
                                        <p className="text-[10px] text-slate-900 font-bold mt-1">{formatDate(lastTcc.uploaded_at)}</p>
                                    </div>
                                    {lastTcc.drive_link && (
                                        <a href={lastTcc.drive_link} target="_blank" rel="noopener noreferrer" className="ml-auto">
                                            <ExternalLink size={10} className="text-emerald-500 hover:text-emerald-700" />
                                        </a>
                                    )}
                                </div>
                            )}

                            <label className={clsx(
                                "mt-auto w-full py-3 rounded-xl font-black text-[10px] md:text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all cursor-pointer",
                                uploading.tcc ? "bg-slate-200 text-slate-500 cursor-not-allowed" :
                                    completed.tcc ? "bg-emerald-100 text-emerald-800 hover:bg-emerald-200" :
                                        "bg-slate-900 text-white hover:bg-black active:scale-[0.98]"
                            )}>
                                {uploading.tcc ? <Loader2 size={12} className="animate-spin" /> : <Upload size={12} />}
                                {completed.tcc ? "Reenviar" : "Selecionar"}
                                <input type="file" className="hidden" accept="application/pdf"
                                    onChange={(e) => handleFileUpload(e, 'TCC')}
                                    disabled={uploading.tcc} />
                            </label>
                        </div>

                        {/* Card Termo */}
                        <div className={clsx(
                            "bg-white/80 backdrop-blur-sm rounded-[1.25rem] p-4 md:p-6 border transition-all flex flex-col",
                            completed.termo ? "border-emerald-200" : "border-white/50 shadow-sm"
                        )}>
                            <div className="flex items-center gap-3 mb-3">
                                <div className={clsx(
                                    "w-9 h-9 rounded-xl flex items-center justify-center transition-all shadow-sm shrink-0",
                                    completed.termo ? "bg-emerald-500 text-white" : "bg-emerald-50 text-emerald-500"
                                )}>
                                    {completed.termo ? <Check size={18} /> : <CheckCircle2 size={18} />}
                                </div>
                                <div className="min-w-0">
                                    <h3 className="text-xs md:text-base font-black text-slate-900 uppercase tracking-tight leading-none">Termo Depósito</h3>
                                    <p className="text-[9px] md:text-[11px] text-slate-500 font-bold uppercase tracking-wide mt-1">Assinado</p>
                                </div>
                            </div>

                            {/* Último envio */}
                            {lastTermo && (
                                <div className="mb-3 px-2.5 py-2 bg-emerald-50 rounded-lg border border-emerald-100 flex items-start gap-2">
                                    <CalendarDays size={10} className="text-emerald-500 mt-0.5 shrink-0" />
                                    <div className="min-w-0">
                                        <p className="text-[9px] font-black text-slate-900 uppercase tracking-wide leading-none">Último envio</p>
                                        <p className="text-[10px] text-slate-900 font-bold mt-1">{formatDate(lastTermo.uploaded_at)}</p>
                                    </div>
                                    {lastTermo.drive_link && (
                                        <a href={lastTermo.drive_link} target="_blank" rel="noopener noreferrer" className="ml-auto">
                                            <ExternalLink size={10} className="text-emerald-500 hover:text-emerald-700" />
                                        </a>
                                    )}
                                </div>
                            )}

                            <label className={clsx(
                                "mt-auto w-full py-3 rounded-xl font-black text-[10px] md:text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all cursor-pointer",
                                uploading.termo ? "bg-slate-200 text-slate-500 cursor-not-allowed" :
                                    completed.termo ? "bg-emerald-100 text-emerald-800 hover:bg-emerald-200" :
                                        "bg-slate-900 text-white hover:bg-black active:scale-[0.98]"
                            )}>
                                {uploading.termo ? <Loader2 size={12} className="animate-spin" /> : <Upload size={12} />}
                                {completed.termo ? "Reenviar" : "Selecionar"}
                                <input type="file" className="hidden" accept="application/pdf"
                                    onChange={(e) => handleFileUpload(e, 'TERMO')}
                                    disabled={uploading.termo} />
                            </label>
                        </div>
                    </div>

                    {/* Status Geral */}
                    <div className="bg-white/40 backdrop-blur-md rounded-[1.25rem] p-5 border border-slate-200 border-dashed flex items-center gap-4">
                        <div className={clsx(
                            "w-10 h-10 shadow-sm border rounded-full flex items-center justify-center shrink-0 transition-all",
                            (completed.tcc && completed.termo) ? "bg-emerald-500 border-emerald-400 text-white" : "bg-white border-slate-100 text-slate-300"
                        )}>
                            {(completed.tcc && completed.termo) ? <Check size={18} /> : <Clock size={16} />}
                        </div>
                        <div>
                            <h4 className="font-black text-slate-700 text-xs uppercase tracking-wider leading-none">
                                {(completed.tcc && completed.termo) ? "Documentação Completa" : "Aguardando Documentação"}
                            </h4>
                            <p className="text-[10px] md:text-xs text-slate-500 font-bold uppercase mt-1.5 tracking-wide">
                                {(completed.tcc && completed.termo)
                                    ? "Tudo pronto para homologação!"
                                    : `Pendente: ${!completed.tcc ? 'PDF do TCC' : ''}${!completed.tcc && !completed.termo ? ' e ' : ''}${!completed.termo ? 'Termo de Depósito' : ''}`}
                            </p>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    )
}
