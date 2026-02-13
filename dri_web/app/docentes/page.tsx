'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import {
    ArrowLeft,
    LogOut,
    ArrowUpRight,
    User,
    Users,
    List,
    FileText
} from 'lucide-react'
import clsx from 'clsx'

export default function DocentesHubPage() {
    const router = useRouter()
    const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)
    const [loading, setLoading] = useState(true)
    const [user, setUser] = useState<any>(null)

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

            const level = accessData?.access_level || 0

            if (level < 2) {
                router.push('/') // Redirect unauthorized to home
                return
            }

            setUserAccessLevel(level)
            setLoading(false)
        }
        checkSession()
    }, [router])

    const handleLogout = async () => {
        await supabase.auth.signOut()
        router.push('/login')
    }

    const firstName = user?.user_metadata?.full_name?.split(' ')[0] || 'Usuário'

    // --- Components ---

    const BentoCard = ({ href, title, subtitle, icon: Icon, color, size = 'normal' }: any) => {
        const isLarge = size === 'large'
        const colorStyles = {
            blue: 'from-blue-500 to-blue-600 shadow-blue-200',
            purple: 'from-purple-500 to-purple-600 shadow-purple-200',
            emerald: 'from-emerald-500 to-emerald-600 shadow-emerald-200',
            orange: 'from-orange-500 to-orange-600 shadow-orange-200',
            indigo: 'from-indigo-500 to-indigo-600 shadow-indigo-200',
            red: 'from-red-500 to-red-600 shadow-red-200',
            lime: 'from-lime-500 to-lime-600 shadow-lime-200',
            dark: 'from-gray-800 to-gray-900 shadow-gray-200'
        }

        return (
            <Link
                href={href}
                className={clsx(
                    "group relative overflow-hidden rounded-[1.25rem] p-3.5 transition-all duration-300 hover:scale-[1.01] hover:shadow-lg shadow-sm flex flex-col justify-between",
                    isLarge ? "md:col-span-2 md:row-span-2 min-h-[190px]" : "min-h-[85px]",
                    "bg-white border border-gray-100"
                )}
            >
                {/* Background Gradient Blob */}
                <div className={clsx(
                    "absolute -right-6 -top-6 w-24 h-24 rounded-full opacity-10 bg-gradient-to-br transition-transform group-hover:scale-125",
                    colorStyles[color as keyof typeof colorStyles]
                )} />

                <div className="relative z-10 flex justify-between items-start">
                    <div className={clsx(
                        "w-8 h-8 rounded-xl flex items-center justify-center text-white bg-gradient-to-br shadow-sm",
                        colorStyles[color as keyof typeof colorStyles]
                    )}>
                        <Icon size={isLarge ? 20 : 16} />
                    </div>
                    <div className={clsx(
                        "w-6 h-6 rounded-full flex items-center justify-center transition-colors",
                        "bg-gray-50 text-gray-400 group-hover:bg-gray-100 group-hover:text-gray-900"
                    )}>
                        <ArrowUpRight size={14} />
                    </div>
                </div>

                <div className="relative z-10 mt-2">
                    <h3 className={clsx("font-extrabold text-slate-900 leading-tight tracking-tight", isLarge ? "text-2xl mb-0.5" : "text-sm mb-0")}>
                        {title}
                    </h3>
                    <p className={clsx("text-slate-600 font-bold leading-tight", isLarge ? "text-base max-w-xs" : "text-[11px]")}>
                        {subtitle}
                    </p>
                </div>
            </Link>
        )
    }

    if (loading) return null

    return (
        <div className="min-h-screen bg-[#F5F5F7] text-gray-900 font-sans antialiased selection:bg-indigo-100 selection:text-indigo-900">

            {/* Dynamic Background */}
            <div className="fixed inset-0 z-0 pointer-events-none opacity-40">
                <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-100 blur-[120px]" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-100 blur-[120px]" />
            </div>

            {/* Navbar (Minimal) */}
            <nav className="relative z-20 px-4 py-4 md:px-12 flex justify-between items-center max-w-7xl mx-auto">
                <div className="flex items-center space-x-3">
                    <Link href="/" className="group flex items-center gap-4">
                        <div className="w-10 h-10 md:w-12 md:h-12 bg-white rounded-xl md:rounded-2xl flex items-center justify-center shadow-sm border border-slate-200 text-slate-600 group-hover:text-indigo-600 group-hover:border-indigo-100 group-hover:scale-105 transition-all">
                            <ArrowLeft size={22} />
                        </div>
                        <span className="font-extrabold text-lg md:text-2xl text-slate-900 tracking-tight">
                            Gestão de <span className="text-indigo-600">Docentes</span>
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
                {/* Bento Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2.5">

                    {/* Lista de Docentes */}
                    <BentoCard
                        href="/docentes/lista"
                        title="Lista de Docentes"
                        subtitle="Gerenciar professores cadastrados."
                        icon={Users}
                        color="indigo"
                    />

                    {/* Lançar Atividades */}
                    <BentoCard
                        href="/docentes/atividades"
                        title="Lançar Atividades"
                        subtitle="Registrar atividades e encargos."
                        icon={FileText}
                        color="blue"
                    />

                    {/* Tipos de Atividade */}
                    <BentoCard
                        href="/docentes/tipos"
                        title="Tipos de Atividade"
                        subtitle="Catálogo de atividades."
                        icon={List}
                        color="purple"
                    />

                </div>
            </main>

        </div>
    )
}
