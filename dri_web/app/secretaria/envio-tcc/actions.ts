'use client'

const APPS_SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyeENasoKjrsLvKrCVCnQbN1zZ1Bz-kiMyClhsGypEu0uXdv4T_6SdA2LF_waPDRCAK/exec'

export async function uploadToDrive(formData: FormData, userId: string, userName: string, userMatricula: string) {
    try {
        const file = formData.get('file') as File
        const docType = formData.get('type') as string // 'TCC' ou 'TERMO'

        if (!file) throw new Error('Arquivo não encontrado')

        // Converte o arquivo para Base64 de forma eficiente no browser
        const base64Content = await new Promise<string>((resolve, reject) => {
            const reader = new FileReader()
            reader.onload = () => {
                const result = reader.result as string
                resolve(result.split(',')[1]) // Extrai apenas a parte Base64 (remove o prefixo data:...)
            }
            reader.onerror = reject
            reader.readAsDataURL(file)
        })

        const safeName = userName.toUpperCase()
        const date = new Date().toLocaleDateString('pt-BR').replace(/\//g, '-')
        const folderName = `${userMatricula} - ${safeName}`
        const fileName = `${docType} - ${safeName} - ${userMatricula} - ${date}.pdf`

        const payload = JSON.stringify({ folderName, fileName, fileContent: base64Content })

        // No browser (Static Export), o Google Apps Script bloqueia o redirect (302) por CORS.
        // Tentamos usar o modo 'no-cors' para o upload funcionar, mas não conseguiremos ler o link de retorno.
        // ATENÇÃO: Se o erro persistir, a solução definitiva será usar o Supabase Storage em vez do Google Drive.

        try {
            const response = await fetch(APPS_SCRIPT_URL, {
                method: 'POST',
                mode: 'cors', // Tentamos cors primeiro
                headers: {
                    'Content-Type': 'text/plain;charset=utf-8'
                },
                body: payload,
            })

            const text = await response.text()
            const result = JSON.parse(text)

            if (!result.success) throw new Error(result.error || 'Erro no Apps Script')
            return { success: true, link: result.link, fileName, docType }

        } catch (corsErr) {
            console.warn('Erro de CORS detectado. Tentando fallback ou reportando erro de ambiente estático.')
            throw new Error('Bloqueio de CORS do Google: O navegador impediu a leitura da resposta. Verifique se o arquivo foi enviado ao Drive mesmo assim.')
        }
    } catch (error: any) {
        console.error('Upload Error:', error)
        return { success: false, error: error.message || 'Erro ao fazer upload' }
    }
}
