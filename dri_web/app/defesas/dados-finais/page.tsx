'use client'

import { useEffect, useState, Suspense } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import { ArrowLeft, Save, Loader2, Calendar, ClipboardCheck } from 'lucide-react'

function DadosFinaisContent() {
    const searchParams = useSearchParams()
    const id = searchParams.get('id')
    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [saving, setSaving] = useState(false)
    const [defesa, setDefesa] = useState<any>(null)
    const [formData, setFormData] = useState({
        data_aprovacao: '',
        resultado: '',
        observacoes_finais: ''
    })

    useEffect(() => {
        const fetchDados = async () => {
            if (!id) return;
            setLoading(true)
            try {
                // Fetch Defesa
                const { data: defData } = await supabase
                    .from('dados_defesas')
                    .select('*')
                    .eq('id', id)
                    .single()
                setDefesa(defData)

                // Fetch Dados Finais
                const { data: finData } = await supabase
                    .from('dados_defesa_final')
                    .select('*')
                    .eq('defesa_id', id)
                    .maybeSingle()

                if (finData) {
                    setFormData({
                        data_aprovacao: finData.data_aprovacao || '',
                        resultado: finData.resultado || '',
                        observacoes_finais: finData.observacoes_finais || ''
                    })
                }
            } catch (error) {
                console.error(error)
            } finally {
                setLoading(false)
            }
        }
        fetchDados()
    }, [id])

    const handleSave = async () => {
        if (!id) return;
        setSaving(true)
        try {
            const { error } = await supabase
                .from('dados_defesa_final')
                .upsert({
                    defesa_id: parseInt(id),
                    ...formData
                }, { onConflict: 'defesa_id' })

            if (error) throw error
            alert('Dados salvos com sucesso!')
            router.back()
        } catch (error) {
            console.error(error)
            alert('Erro ao salvar dados')
        } finally {
            setSaving(false)
        }
    }

    if (loading) return (
        <div className="min-h-screen flex items-center justify-center bg-slate-50">
            <Loader2 className="animate-spin text-blue-600" size={32} />
        </div>
    )

    return (
        <div className="min-h-screen bg-[#FAFAFA] pb-20">
            {/* Header */}
            <div className="bg-[#0C4A6E] text-white p-6 shadow-lg rounded-b-[2rem] mb-6">
                <div className="max-w-3xl mx-auto flex items-center gap-4">
                    <button onClick={() => router.back()} className="p-2 hover:bg-white/10 rounded-full transition-colors">
                        <ArrowLeft size={20} />
                    </button>
                    <div>
                        <h1 className="text-lg font-bold">Dados Finais da Defesa</h1>
                        <p className="text-xs text-blue-200 uppercase font-black tracking-widest">{defesa?.discente}</p>
                    </div>
                </div>
            </div>

            <main className="max-w-3xl mx-auto px-4 space-y-6">
                {/* Info Card */}
                <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm space-y-4">
                    <div className="flex items-center gap-3 text-[#0C4A6E] mb-2">
                        <ClipboardCheck size={20} />
                        <h2 className="font-black text-sm uppercase tracking-wider">Informações da Defesa</h2>
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
                        <div>
                            <span className="block text-slate-400 font-bold uppercase mb-1">Título</span>
                            <span className="font-bold text-slate-700">{defesa?.titulo}</span>
                        </div>
                        <div>
                            <span className="block text-slate-400 font-bold uppercase mb-1">Orientador</span>
                            <span className="font-bold text-slate-700">{defesa?.orientador}</span>
                        </div>
                    </div>
                </div>

                {/* Form */}
                <div className="bg-white p-8 rounded-3xl border border-slate-100 shadow-sm space-y-6">
                    <div className="space-y-2">
                        <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-2">
                            <Calendar size={14} className="text-blue-500" />
                            Data de Aprovação
                        </label>
                        <input
                            type="date"
                            value={formData.data_aprovacao}
                            onChange={(e) => setFormData({ ...formData, data_aprovacao: e.target.value })}
                            className="w-full bg-slate-50 border border-slate-100 rounded-2xl px-4 py-3 text-sm font-bold text-slate-700 outline-none focus:border-blue-300 transition-all"
                        />
                    </div>

                    <div className="space-y-2">
                        <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">
                            Resultado Final
                        </label>
                        <textarea
                            value={formData.resultado}
                            onChange={(e) => setFormData({ ...formData, resultado: e.target.value })}
                            placeholder="Ex: Aprovado com Louvor, Aprovado..."
                            className="w-full bg-slate-50 border border-slate-100 rounded-2xl px-4 py-3 text-sm font-bold text-slate-700 outline-none focus:border-blue-300 transition-all min-h-[80px]"
                        />
                    </div>

                    <div className="space-y-2">
                        <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">
                            Observações Finais
                        </label>
                        <textarea
                            value={formData.observacoes_finais}
                            onChange={(e) => setFormData({ ...formData, observacoes_finais: e.target.value })}
                            placeholder="Observações que constarão na Ata..."
                            className="w-full bg-slate-50 border border-slate-100 rounded-2xl px-4 py-3 text-sm font-bold text-slate-700 outline-none focus:border-blue-300 transition-all min-h-[120px]"
                        />
                    </div>

                    <button
                        onClick={handleSave}
                        disabled={saving}
                        className="w-full bg-[#0C4A6E] text-white py-4 rounded-2xl font-black uppercase tracking-[0.2em] text-xs flex items-center justify-center gap-3 shadow-xl shadow-blue-100 hover:bg-blue-700 transition-all disabled:opacity-50"
                    >
                        {saving ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
                        Salvar Dados Finais
                    </button>
                </div>
            </main>
        </div>
    )
}

export default function DadosFinaisPage() {
    return (
        <Suspense fallback={<div>Carregando...</div>}>
            <DadosFinaisContent />
        </Suspense>
    )
}
