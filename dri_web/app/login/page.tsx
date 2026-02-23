'use client'

import { useState } from 'react'
import { supabase } from '@/lib/supabaseClient'
import { useRouter } from 'next/navigation'
import { Lock, User, GraduationCap, Users, ArrowRight, ShieldCheck } from 'lucide-react'

export default function LoginPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(false)
    const [email, setEmail] = useState('')
    const [password, setPassword] = useState('')
    const [error, setError] = useState<string | null>(null)

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        setError(null)

        try {
            const { data, error } = await supabase
                .rpc('login_avaliador', {
                    p_login: email,
                    p_senha: password
                })

            if (error) throw error

            if (data) {
                sessionStorage.setItem('guest_defense_id', data.id)
                router.push(`/defesas/avaliar?id=${data.id}`)
                return
            }

            setError('Credenciais inválidas. Verifique com a secretaria.')
        } catch (err: any) {
            console.error('Login error:', err)
            setError('Erro ao validar acesso. Tente novamente.')
        } finally {
            setLoading(false)
        }
    }

    const handleGoogleLogin = async () => {
        try {
            const { error } = await supabase.auth.signInWithOAuth({
                provider: 'google',
                options: {
                    redirectTo: `${window.location.origin}/auth/callback`,
                },
            })
            if (error) throw error
        } catch (err: any) {
            setError(err.message)
        }
    }

    return (
        <div className="relative min-h-screen flex items-center justify-center p-4 overflow-hidden font-sans">
            {/* Animated Mesh Background */}
            <div className="fixed inset-0 z-0 bg-[#0a0a0f]">
                <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-900/30 blur-[120px] animate-pulse" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-blue-900/20 blur-[120px] animate-pulse [animation-delay:2s]" />
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[60%] h-[60%] rounded-full bg-purple-900/10 blur-[150px]" />

                {/* Subtle Grid Pattern */}
                <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-20 brightness-100 contrast-150" />
                <div className="absolute inset-0 bg-[linear-gradient(to_right,#80808012_1px,transparent_1px),linear-gradient(to_bottom,#80808012_1px,transparent_1px)] bg-[size:40px_40px]" />
            </div>

            <div className="relative z-10 w-full max-w-xl animate-in fade-in zoom-in duration-700">
                <div className="grid grid-cols-1 md:grid-cols-1 gap-6">
                    {/* Header Section */}
                    <div className="text-center space-y-4 mb-2">
                        <div className="inline-flex items-center justify-center w-24 h-24 bg-white/5 backdrop-blur-xl rounded-full border border-white/10 shadow-2xl mb-2 overflow-hidden">
                            <img src="/logo-dri.png" alt="Logo" className="w-full h-full object-cover" />
                        </div>
                        <div className="space-y-1">
                            <h1 className="text-4xl font-extrabold text-white tracking-tight sm:text-5xl">
                                Secretaria <span className="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-blue-400">Digital</span>
                            </h1>
                            <p className="text-gray-400 font-medium text-lg">Departamento de Relações Internacionais • UFPB</p>
                        </div>
                    </div>

                    {/* Main Login Card */}
                    <div className="bg-white/5 backdrop-blur-2xl rounded-3xl shadow-[0_32px_64px_-16px_rgba(0,0,0,0.5)] border border-white/10 overflow-hidden flex flex-col md:flex-row">
                        {/* Left Side - External Access Form */}
                        <div className="flex-1 p-8 sm:p-10 border-b md:border-b-0 md:border-r border-white/10">
                            <div className="flex items-center space-x-3 mb-8">
                                <div className="p-2 bg-indigo-500/20 rounded-lg">
                                    <ShieldCheck className="text-indigo-400" size={24} />
                                </div>
                                <div>
                                    <h2 className="text-xl font-bold text-white leading-none">Acesso Externo</h2>
                                    <p className="text-gray-400 text-sm mt-1">Avaliadores e Convidados</p>
                                </div>
                            </div>

                            <form onSubmit={handleLogin} className="space-y-5">
                                <div className="space-y-2">
                                    <label className="text-sm font-semibold text-gray-300 ml-1">Login</label>
                                    <div className="relative group">
                                        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none transition-colors group-focus-within:text-indigo-400 text-gray-500">
                                            <User size={18} />
                                        </div>
                                        <input
                                            type="text"
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                            className="w-full bg-black/40 border border-white/10 rounded-2xl pl-11 pr-4 py-3.5 text-white placeholder-gray-500 focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500 outline-none transition-all"
                                            placeholder="Nome de login"
                                            required
                                        />
                                    </div>
                                </div>

                                <div className="space-y-2">
                                    <label className="text-sm font-semibold text-gray-300 ml-1">Senha de Acesso</label>
                                    <div className="relative group">
                                        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none transition-colors group-focus-within:text-indigo-400 text-gray-500">
                                            <Lock size={18} />
                                        </div>
                                        <input
                                            type="password"
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                            className="w-full bg-black/40 border border-white/10 rounded-2xl pl-11 pr-4 py-3.5 text-white placeholder-gray-500 focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500 outline-none transition-all"
                                            placeholder="••••••••"
                                            required
                                        />
                                    </div>
                                </div>

                                {error && (
                                    <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-400 text-sm text-center animate-shake">
                                        {error}
                                    </div>
                                )}

                                <button
                                    type="submit"
                                    disabled={loading}
                                    className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-4 px-6 rounded-2xl transition-all flex items-center justify-center space-x-2 shadow-lg shadow-indigo-600/20 hover:shadow-indigo-600/40 active:scale-[0.98] disabled:opacity-50"
                                >
                                    {loading ? (
                                        <div className="animate-spin rounded-full h-5 w-5 border-2 border-white/30 border-t-white"></div>
                                    ) : (
                                        <>
                                            <span>Entrar no Sistema</span>
                                            <ArrowRight size={18} />
                                        </>
                                    )}
                                </button>
                            </form>
                        </div>

                        {/* Middle Divider (Visible only on desktop) */}
                        <div className="hidden md:flex flex-col items-center justify-center -mx-4 z-20">
                            <div className="h-full w-px bg-gradient-to-b from-transparent via-white/10 to-transparent" />
                            <div className="w-10 h-10 rounded-full bg-[#12121a] border border-white/10 flex items-center justify-center shadow-xl">
                                <span className="text-[10px] font-black text-gray-500 uppercase tracking-widest">OU</span>
                            </div>
                            <div className="h-full w-px bg-gradient-to-b from-transparent via-white/10 to-transparent" />
                        </div>

                        {/* Right Side - SIGAA / Institutional Access */}
                        <div className="flex-1 p-8 sm:p-10 flex flex-col justify-center bg-white/[0.02]">
                            <div className="text-center space-y-6">
                                <div className="inline-flex p-4 bg-blue-500/10 rounded-3xl border border-blue-500/20 mb-2">
                                    <GraduationCap className="text-blue-400" size={40} />
                                </div>
                                <div className="space-y-2">
                                    <h3 className="text-xl font-bold text-white">Docentes e Discentes</h3>
                                    <p className="text-gray-400 text-sm px-4">Utilize sua conta institucional da UFPB para acessar todas as funcionalidades.</p>
                                </div>

                                <button
                                    onClick={handleGoogleLogin}
                                    className="w-full group relative flex items-center justify-center px-6 py-4 bg-white text-black font-bold rounded-2xl transition-all hover:bg-blue-50 hover:ring-4 hover:ring-blue-500/20 active:scale-95 shadow-xl"
                                >
                                    <img src="https://www.google.com/favicon.ico" alt="Google" className="w-5 h-5 mr-3" />
                                    <span>Fazer Login com o Google ou Google Acadêmico</span>
                                </button>

                                <p className="text-[10px] text-gray-500 uppercase tracking-widest font-bold">
                                    Autenticação via Google Workspace
                                </p>
                            </div>
                        </div>
                    </div>

                    {/* Footer Info */}
                    <p className="text-center text-gray-500 text-xs font-medium">
                        &copy; {new Date().getFullYear()} Departamento de Relações Internacionais — UFPB
                    </p>
                </div>
            </div>

            <style jsx global>{`
                @keyframes shake {
                    0%, 100% { transform: translateX(0); }
                    25% { transform: translateX(-4px); }
                    75% { transform: translateX(4px); }
                }
                .animate-shake {
                    animation: shake 0.4s ease-in-out;
                }
            `}</style>
        </div>
    )
}

