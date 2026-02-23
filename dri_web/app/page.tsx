'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { supabase } from '@/lib/supabaseClient'
import {
  ArrowUpRight,
  Users,
  LogOut,
  AlertCircle,
  LayoutDashboard,
  GraduationCap,
  BookOpen,
  ShieldCheck
} from 'lucide-react'
import clsx from 'clsx'
import { useRouter } from 'next/navigation'

export default function Dashboard() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [alertInfo, setAlertInfo] = useState<any>(null)

  useEffect(() => {
    const checkSessionAndData = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        window.location.href = '/login'
        return
      }
      setUser(session.user)

      const { data: accessData } = await supabase
        .from('users_access')
        .select('access_level')
        .eq('id', session.user.id)
        .single()

      if (accessData) {
        const { data: boards } = await supabase
          .from('tcc_defesas')
          .select('id')
          .or(`orientador_id.eq.${session.user.id},coorientador_id.eq.${session.user.id},membro1_id.eq.${session.user.id},membro2_id.eq.${session.user.id},membro3_id.eq.${session.user.id}`)
          .is('data_finalizada', null)

        if (boards && boards.length > 0) {
          setAlertInfo({ count: boards.length })
        }
        setLoading(false)
      }
    }
    checkSessionAndData()
  }, [])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    window.location.href = '/login'
  }

  const navigateTo = (href: string) => () => {
    window.location.href = href
  }

  if (loading) return null

  const firstName = user?.user_metadata?.full_name?.split(' ')[0] || 'Usuário'

  const HomeButton = ({ href, title, subtitle, icon: Icon, color }: any) => {
    const colorStyles = {
      blue: 'bg-blue-600',
      purple: 'bg-purple-600',
      emerald: 'bg-emerald-600',
      orange: 'bg-orange-600',
      indigo: 'bg-indigo-600',
      dark: 'bg-slate-900'
    }

    return (
      <button
        onClick={navigateTo(href)}
        className={clsx(
          "group relative overflow-hidden rounded-[1.25rem] p-6 flex flex-col justify-between text-left transition-all",
          "bg-white border border-slate-200 shadow-sm active:scale-[0.98] active:bg-slate-50 min-h-[140px]"
        )}
      >
        <div className={clsx(
          "w-10 h-10 rounded-xl flex items-center justify-center text-white shadow-md",
          colorStyles[color as keyof typeof colorStyles] || 'bg-slate-600'
        )}>
          <Icon size={24} />
        </div>

        <div className="mt-4">
          <h3 className="font-black text-slate-800 leading-tight uppercase italic text-base">
            {title}
          </h3>
          <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
            {subtitle}
          </p>
        </div>

        <div className="absolute right-4 top-4 text-slate-200 group-hover:text-indigo-600 transition-colors">
          <ArrowUpRight size={22} />
        </div>
      </button>
    )
  }

  return (
    <div className="min-h-screen bg-[#F5F5F7] text-gray-900 font-sans antialiased font-medium">
      <div className="fixed inset-0 z-0 pointer-events-none opacity-30">
        <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-100 blur-[120px]" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-blue-100 blur-[120px]" />
      </div>

      <nav className="relative z-20 px-6 py-4 flex justify-between items-center max-w-7xl mx-auto">
        <div className="flex items-center gap-3">
          <img src="/logo-dri.png" alt="DRI UFPB" className="w-12 h-12 object-contain" />
          <div className="flex flex-col text-left">
            <span className="font-black text-xl tracking-tighter text-slate-900 uppercase italic leading-none">
              DRI <span className="text-indigo-600">Digital</span>
            </span>
            <span className="text-[8px] font-black uppercase tracking-[2px] text-slate-400">Portal de Gestão</span>
          </div>
        </div>

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
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">

          {alertInfo && (
            <button
              onClick={navigateTo('/tcc/minhas-bancas')}
              className="md:col-span-2 lg:col-span-3 flex items-center gap-4 p-5 bg-orange-50 border-2 border-orange-100 rounded-2xl shadow-sm hover:bg-orange-100 active:scale-[0.99] transition-all text-left group"
            >
              <div className="w-12 h-12 rounded-xl bg-orange-500 flex items-center justify-center text-white shrink-0 shadow-lg">
                <AlertCircle size={26} />
              </div>
              <div className="flex-1">
                <h3 className="font-black text-orange-900 uppercase text-sm italic leading-tight">Bancas em Aberto</h3>
                <p className="text-[10px] font-bold text-orange-700 uppercase">Você possui {alertInfo.count} defesa(s) pendente(s).</p>
              </div>
              <ArrowUpRight size={24} className="text-orange-300 group-hover:text-orange-600" />
            </button>
          )}

          <HomeButton
            href="/semestre"
            title="Semestres"
            subtitle="Grade, CH e Planejamento"
            icon={BookOpen}
            color="blue"
          />

          <HomeButton
            href="/tcc"
            title="TCC"
            subtitle="Bancas, Docs e Editais"
            icon={GraduationCap}
            color="emerald"
          />

          <HomeButton
            href="/docentes"
            title="Docentes"
            subtitle="Encargos e Atividades"
            icon={Users}
            color="purple"
          />

          <HomeButton
            href="/secretaria"
            title="Secretaria"
            subtitle="Seu Espaço e Perfil"
            icon={LayoutDashboard}
            color="orange"
          />

          <HomeButton
            href="/usuarios"
            title="Usuários"
            subtitle="Gestão de Acessos"
            icon={ShieldCheck}
            color="indigo"
          />
        </div>
      </main>

      <footer className="relative z-20 px-6 max-w-7xl mx-auto py-12 border-t border-slate-200 text-center flex flex-col items-center gap-4">
        <div className="text-[10px] font-black text-slate-300 uppercase tracking-[4px]">
          UFPB • DRI • v2.3
        </div>
        <div className="text-[10px] font-black text-slate-200 uppercase tracking-[2px]">Secretaria Digital</div>
      </footer>
    </div>
  )
}
