'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'

export default function AuthCallbackPage() {
    const router = useRouter()

    useEffect(() => {
        // The supabase client automatically handles the hash fragment (#access_token=...)
        // when initialized on a page that has it.
        // We just need to give it a moment to process and then verify the session.

        const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
            if (event === 'SIGNED_IN' || session) {
                router.push('/')
            }
        })

        return () => {
            subscription.unsubscribe()
        }
    }, [router])

    return (
        <div className="flex items-center justify-center min-h-screen bg-gray-50">
            <div className="text-center">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
                <h2 className="text-xl font-semibold text-gray-800">Finalizando autenticação...</h2>
                <p className="text-gray-500">Você será redirecionado em instantes.</p>
            </div>
        </div>
    )
}
