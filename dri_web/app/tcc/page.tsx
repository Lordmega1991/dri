'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    Calendar,
    FileText,
    Users,
    LogOut,
    ArrowUpRight,
    ClipboardCheck,
    User,
    PlusCircle,
    Search
} from 'lucide-react'
import clsx from 'clsx'
import { useRouter } from 'next/navigation'

export default function TCCPage() {
    const [user, setUser] = useState<any>(null)
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        const checkSession = async () => {
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) {
                window.location.href = '/login'
                return
            }
            setUser(session.user)
            setLoading(false)
        }
        checkSession()
    }, [])

    const handleLogout = async () => {
        await supabase.auth.signOut()
        window.location.href = '/login'
    }

    const navigateTo = (href: string) => () => {
        window.location.href = href
    }

    const TCCButton = ({ href, title, subtitle, icon: Icon, color }: any) => {
        const colorStyles = {
            blue: 'bg-blue-600',
            purple: 'bg-purple-600',
            emerald: 'bg-emerald-600',
            orange: 'bg-orange-600',
            indigo: 'bg-indigo-600',
            red: 'bg-red-600',
            lime: 'bg-lime-600',
            dark: 'bg-gray-800'
        }

        return (
            <button
                onClick={navigateTo(href)}
                className="group relative overflow-hidden rounded-[1.25rem] p-5 flex flex-col justify-between text-left transition-all bg-white border border-slate-200 shadow-sm active:scale-[0.98] active:bg-slate-50 min-h-[120px]"
            >
                <div className={clsx(
                    "w-10 h-10 rounded-xl flex items-center justify-center text-white shadow-md",
                    colorStyles[color as keyof typeof colorStyles] || 'bg-slate-600'
                )}>
                    <Icon size={24} />
                </div>
                <div className="mt-4">
                    <h3 className="font-black text-slate-800 uppercase italic text-sm leading-tight">
                        {title}
                    </h3>
                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mt-0.5">
                        {subtitle}
                    </p>
                </div>
                <div className="absolute right-4 top-4 text-slate-200 group-hover:text-indigo-600">
                    <ArrowUpRight size={20} />
                </div>
            </button>
        )
    }

    if (loading) return null

    const firstName = user?.user_metadata?.full_name?.split(' ')[0] || 'Usuário'

    const tccItems = [
        {
            title: "Minhas Bancas",
            subtitle: "Bancas em que atuo",
            icon: User,
            color: "lime",
            href: "/tcc/minhas-bancas"
        },
        {
            title: "Cadastrar Defesa",
            subtitle: "Novo TCC no sistema",
            icon: PlusCircle,
            color: "blue",
            href: "/tcc/cadastrar"
        },
        {
            title: "Ver Defesas",
            subtitle: "Lista e busca geral",
            icon: Search,
            color: "orange",
            href: "/tcc/visualizar"
        },
        {
            title: "Calendário TCC",
            subtitle: "Agenda completa",
            icon: Calendar,
            color: "red",
            href: "/tcc/calendario"
        },
        {
            title: "Documentação",
            subtitle: "Atas e Situação",
            icon: ClipboardCheck,
            color: "emerald",
            href: "/tcc/situacao"
        },
        {
            title: "Relatórios",
            subtitle: "Estatísticas da Área",
            icon: FileText,
            color: "purple",
            href: "/tcc/relatorios"
        }
    ]

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-gray-900 font-sans antialiased">
            <div className="fixed inset-0 z-0 pointer-events-none opacity-30">
                <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-100 blur-[120px]" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-blue-100 blur-[120px]" />
            </div>

            <nav className="relative z-20 px-6 py-4 flex justify-between items-center max-w-7xl mx-auto">
                <button onClick={navigateTo('/')} className="flex items-center gap-4 group text-left">
                    <div className="w-10 h-10 bg-white border border-slate-200 rounded-xl flex items-center justify-center text-slate-400 group-hover:text-indigo-600 group-hover:border-indigo-100 transition-all shadow-sm">
                        <ArrowLeft size={20} />
                    </div>
                    <div className="flex flex-col">
                        <span className="font-black text-lg tracking-tight text-slate-900 uppercase italic leading-none">
                            Defesas <span className="text-indigo-600">de TCC</span>
                        </span>
                        <span className="text-[8px] font-black uppercase tracking-[2px] text-slate-400">Voltar para Início</span>
                    </div>
                </button>

                <div className="flex items-center bg-white shadow-sm border border-slate-200 rounded-full px-4 py-2">
                    <div className="text-xs mr-4 text-right">
                        <span className="text-slate-400 font-bold uppercase tracking-widest text-[10px]">Olá, </span>
                        <span className="font-black text-slate-800 block md:inline">{firstName}</span>
                    </div>
                    <button onClick={handleLogout} className="text-slate-400 hover:text-red-500 transition-colors shrink-0">
                        <LogOut size={18} />
                    </button>
                </div>
            </nav>

            <main className="relative z-20 px-6 max-w-7xl mx-auto py-8">
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {tccItems.map((item, index) => (
                        <TCCButton key={index} {...item} />
                    ))}
                </div>
            </main>
        </div>
    )
}
