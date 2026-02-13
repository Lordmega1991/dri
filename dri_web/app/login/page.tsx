'use client'

import { useState } from 'react'
import { supabase } from '@/lib/supabaseClient'
import { useRouter } from 'next/navigation'
import { Lock, User, GraduationCap, Users } from 'lucide-react'

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
            // Call the secure RPC function to bypass RLS
            const { data, error } = await supabase
                .rpc('login_avaliador', {
                    p_login: email,
                    p_senha: password
                })

            if (error) throw error

            if (data) {
                // Success! Redirect to grading page
                sessionStorage.setItem('guest_defense_id', data.id)
                router.push(`/defesas/avaliar?id=${data.id}`)
                return
            }

            // If not found in guest table, show simple error (Guests handle only via this table)
            setError('Credenciais de acesso inválidas. Verifique com a secretaria.')

        } catch (err: any) {
            console.error('Login error:', err)
            setError('Erro ao validar credenciais. Tente novamente.')
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
        <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-600 via-purple-700 to-blue-800 p-4">
            <div className="w-full max-w-md bg-white/10 backdrop-blur-lg rounded-2xl shadow-2xl overflow-hidden border border-white/20">
                <div className="p-8 space-y-8">
                    <div className="text-center space-y-2">
                        <h1 className="text-3xl font-bold text-white tracking-tight">Secretaria Digital</h1>
                        <p className="text-blue-100 font-medium">Departamento de Relações Internacionais</p>
                    </div>

                    <div className="space-y-4">
                        {/* Avaliador Login Form */}
                        <div className="bg-white rounded-xl p-6 shadow-lg space-y-4">
                            <div className="border-b pb-2 mb-4">
                                <div className="flex items-center space-x-2 text-indigo-700 font-semibold">
                                    <Users size={20} />
                                    <span>Acesso aos Avaliadores Convidados às Defesas de Bancas</span>
                                </div>
                                <p className="text-xs text-gray-500 mt-1 pl-7">
                                    Informações de acesso fornecidas pela secretaria
                                </p>
                            </div>

                            <form onSubmit={handleLogin} className="space-y-4">
                                <div className="relative">
                                    <User className="absolute left-3 top-3 text-gray-400" size={18} />
                                    <input
                                        type="text"
                                        placeholder="Login"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        className="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all"
                                        required
                                    />
                                </div>
                                <div className="relative">
                                    <Lock className="absolute left-3 top-3 text-gray-400" size={18} />
                                    <input
                                        type="password"
                                        placeholder="Senha"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        className="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all"
                                        required
                                    />
                                </div>

                                {error && (
                                    <div className="text-red-500 text-sm text-center bg-red-50 p-2 rounded-lg">
                                        {error}
                                    </div>
                                )}

                                <button
                                    type="submit"
                                    disabled={loading}
                                    className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 px-4 rounded-lg transition-colors flex items-center justify-center space-x-2 disabled:opacity-50"
                                >
                                    {loading ? (
                                        <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                                    ) : (
                                        <span>Entrar</span>
                                    )}
                                </button>
                            </form>
                        </div>

                        {/* Google Login Options */}
                        <div className="space-y-3">
                            <button
                                onClick={handleGoogleLogin}
                                className="w-full bg-white hover:bg-gray-50 text-gray-800 font-semibold py-3 px-4 rounded-xl shadow-md transition-all flex items-center justify-center space-x-3 group"
                            >
                                <div className="bg-blue-100 p-2 rounded-full group-hover:bg-blue-200 transition-colors">
                                    <GraduationCap size={20} className="text-blue-700" />
                                </div>
                                <span>Entrar como Docente/Discente</span>
                            </button>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    )
}
