'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabaseClient'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import {
  GraduationCap,
  Calendar,
  FileText,
  Users,
  LogOut,
  ChevronRight,
  ArrowUpRight,
  Clock,
  BookOpen,
  AlertCircle,
  School
} from 'lucide-react'
import clsx from 'clsx'

// Force reload trigger
export default function DashboardAppleStyle() {
  const router = useRouter()
  const [loading, setLoading] = useState(true)
  const [user, setUser] = useState<any>(null)
  const [date, setDate] = useState('')
  const [alertInfo, setAlertInfo] = useState<{ count: number, unscheduled: number } | null>(null)
  const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)

  useEffect(() => {
    const checkSessionAndData = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        router.push('/login')
        return
      }
      setUser(session.user)

      try {
        // 1. Get Current Semester
        const now = new Date()
        const { data: semData } = await supabase
          .from('semestres')
          .select('*')
          .lte('data_inicio', now.toISOString())
          .gte('data_fim', now.toISOString())
          .single()

        let currentLabel = ''
        if (semData) {
          currentLabel = `${semData.ano}.${semData.semestre}`
        } else {
          // Fallback
          const year = now.getFullYear()
          const month = now.getMonth() + 1
          currentLabel = `${year}.${month <= 6 ? 1 : 2}`
        }

        // 2. Check Defenses for this semester where user participates
        const { data: defesas, error } = await supabase
          .from('dados_defesas')
          .select('id, dia, orientador, coorientador, avaliador1, avaliador2, avaliador3')
          .eq('semestre', currentLabel)

        if (defesas && defesas.length > 0) {
          const userName = session.user?.user_metadata?.full_name?.toLowerCase()?.trim() || ''
          const today = new Date()
          today.setHours(0, 0, 0, 0)

          const myDefesas = defesas.filter(d => {
            const roles = [
              d.orientador,
              d.coorientador,
              d.avaliador1,
              d.avaliador2,
              d.avaliador3
            ].map(r => r?.toLowerCase()?.trim())
            return roles.includes(userName)
          })

          // Filtra apenas as bancas "ativas": sem data definida OU com data hoje/futura
          const activeDefesas = myDefesas.filter(d => {
            if (!d.dia) return true
            const defenseDate = new Date(d.dia + 'T12:00:00')
            defenseDate.setHours(0, 0, 0, 0)
            return defenseDate >= today
          })

          if (activeDefesas.length > 0) {
            const unscheduled = activeDefesas.filter(d => !d.dia).length
            setAlertInfo({ count: activeDefesas.length, unscheduled })
          } else {
            setAlertInfo(null)
          }
        } else {
          setAlertInfo(null)
        }
      } catch (err) {
        console.error('Error fetching alert data:', err)
      }
      try {
        // 3. Get User Access Level
        const { data: accessData, error: accessError } = await supabase
          .from('users_access')
          .select('access_level')
          .eq('id', session.user.id)
          .single()

        if (accessData) {
          setUserAccessLevel(accessData.access_level)
        } else {
          setUserAccessLevel(0)
        }

      } catch (err) {
        console.error('Error fetching access level:', err)
        setUserAccessLevel(0)
      } finally {
        setLoading(false)
      }
    }

    checkSessionAndData()
    setDate(new Date().toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' }))
  }, [router])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push('/login')
  }

  if (loading) return null

  const firstName = user?.user_metadata?.full_name?.split(' ')[0] || 'Usuário'

  // --- Components ---

  const BentoCard = ({ href, title, subtitle, icon: Icon, color, size = 'normal', delay }: any) => {
    const isLarge = size === 'large'
    const colorStyles = {
      blue: 'from-blue-500 to-blue-600 shadow-blue-200',
      purple: 'from-purple-500 to-purple-600 shadow-purple-200',
      emerald: 'from-emerald-500 to-emerald-600 shadow-emerald-200',
      orange: 'from-orange-500 to-orange-600 shadow-orange-200',
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

  return (
    <div className="min-h-screen bg-[#F5F5F7] text-gray-900 font-sans antialiased selection:bg-indigo-100 selection:text-indigo-900">

      {/* Dynamic Background */}
      <div className="fixed inset-0 z-0 pointer-events-none opacity-40">
        <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-blue-100 blur-[120px]" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-100 blur-[120px]" />
      </div>

      {/* Navbar (Minimal) */}
      <nav className="relative z-20 px-4 py-4 md:px-12 flex justify-between items-center max-w-7xl mx-auto">
        <div className="flex items-center space-x-3">
          {/* Logo DRI UFPB */}
          <img
            src="/logo-dri.png"
            alt="DRI UFPB"
            className="w-14 h-14 md:w-16 md:h-16 object-contain"
          />
          <span className="font-bold text-lg md:text-xl tracking-tight text-gray-900 leading-tight ml-2">
            Secretaria Digital <span className="text-indigo-600">DRI UFPB</span>
          </span>
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
        <style jsx global>{`
          @keyframes slow-pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.6; transform: scale(1.05); }
          }
          .animate-slow-pulse {
            animation: slow-pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite;
          }
        `}</style>

        {/* Bento Grid - Extra Compact */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2.5">
          {/* Alerta de Bancas (Dynamic) */}
          {alertInfo && (
            <Link
              href="/tcc/minhas-bancas"
              className="group relative overflow-hidden rounded-[1.25rem] p-3.5 transition-all duration-300 hover:scale-[1.01] hover:shadow-lg shadow-sm flex flex-col justify-between min-h-[85px] bg-white border-2 border-orange-100 md:col-span-2 lg:col-span-3"
            >
              <div className="absolute -right-6 -top-6 w-32 h-32 rounded-full opacity-5 bg-orange-500" />
              <div className="relative z-10 flex items-center gap-4">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center text-white bg-gradient-to-br from-orange-400 to-red-500 shadow-md animate-slow-pulse">
                  <AlertCircle size={24} />
                </div>
                <div>
                  <h3 className="font-extrabold text-slate-900 leading-tight tracking-tight text-base">
                    Atenção: Bancas em Aberto
                  </h3>
                  <p className="text-slate-600 font-bold leading-tight text-xs mt-0.5">
                    Você está cadastrado em {alertInfo.count} {alertInfo.count === 1 ? 'banca' : 'bancas'} no semestre atual. {alertInfo.unscheduled > 0 ? (
                      <span className="text-red-500">{alertInfo.unscheduled} ainda não {alertInfo.unscheduled === 1 ? 'possui' : 'possuem'} data definida.</span>
                    ) : (
                      <span className="text-emerald-500">Todas já possuem data marcada.</span>
                    )}
                  </p>
                </div>
                <div className="ml-auto w-8 h-8 rounded-full bg-orange-50 text-orange-500 flex items-center justify-center group-hover:bg-orange-500 group-hover:text-white transition-all">
                  <ChevronRight size={18} />
                </div>
              </div>
            </Link>
          )}

          {/* Semestres - Level 2, 3, 4 */}
          {(userAccessLevel || 0) >= 2 && (
            <BentoCard
              href="/semestre"
              title="Gestão de Semestres"
              subtitle="Grades horárias e alocações."
              icon={Calendar}
              color="blue"
            />
          )}

          {/* TCC - Level 0 or 2+ (Hidden for Level 1) */}
          {((userAccessLevel || 0) === 0 || (userAccessLevel || 0) >= 2) && (
            <BentoCard
              href="/tcc"
              title="Bancas de TCC"
              subtitle="Agendamentos e atas."
              icon={GraduationCap}
              color="purple"
            />
          )}

          {/* Secretaria - Level 1, 2, 3, 4 */}
          {(userAccessLevel || 0) >= 1 && (
            <BentoCard
              href="/secretaria"
              title="Secretaria"
              subtitle="Documentos e processos."
              icon={FileText}
              color="emerald"
            />
          )}

          {/* Docentes - Level 2, 3, 4 */}
          {(userAccessLevel || 0) >= 2 && (
            <BentoCard
              href="/docentes"
              title="Docentes"
              subtitle="Gestão do corpo docente."
              icon={BookOpen}
              color="indigo"
            />
          )}

          {/* Usuários - Level 4 only */}
          {(userAccessLevel || 0) >= 4 && (
            <BentoCard
              href="/usuarios"
              title="Usuários"
              subtitle="Controle de acesso."
              icon={Users}
              color="orange"
            />
          )}

          {/* Relatórios - Level 2, 3, 4 */}
          {(userAccessLevel || 0) >= 2 && (
            <BentoCard
              href="/relatorios"
              title="Relatórios"
              subtitle="Dados consolidados."
              icon={BookOpen}
              color="dark"
            />
          )}



        </div>
      </main>

    </div>
  )
}
