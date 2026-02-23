'use client'

// Remote fetch (CORS might block this on client-side)

export async function fetchSigaaStudents() {
    try {
        const targetUrl = 'https://sigaa.ufpb.br/sigaa/public/curso/alunos.jsf?lc=pt_br&id=1626850'
        const proxyUrl = `https://api.allorigins.win/raw?url=${encodeURIComponent(targetUrl)}`

        const response = await fetch(proxyUrl)
        const html = await response.text()

        // Simple regex to extract names and matriculas from SIGAA table
        // This is a simplified version as SIGAA structure can be complex
        // Typically students are in a table with rows like:
        // <td>MATRICULA</td><td>NOME</td>...

        const students: { nome: string; matricula: string }[] = []

        // Example Regex (Note: SIGAA HTML is usually messy)
        // We look for patterns like <td>2023000123</td><td>JOAO SILVA</td>
        const rowRegex = /<td[^>]*>(\d{7,12})<\/td>\s*<td[^>]*>([^<]+)<\/td>/gi
        let match;

        while ((match = rowRegex.exec(html)) !== null) {
            students.push({
                matricula: match[1].trim(),
                nome: match[2].trim()
            })
        }

        // Fallback for demo if scraping fails (SIGAA often blocks or has different structure)
        if (students.length === 0) {
            return {
                error: "Não foi possível extrair os dados automaticamente do SIGAA. Verifique a conexão ou tente novamente mais tarde.",
                fallback: [
                    { nome: "ALEXANDRE SILVA DOS SANTOS", matricula: "20210045678" },
                    { nome: "BEATRIZ OLIVEIRA LIMA", matricula: "20220123456" },
                    { nome: "CARLOS EDUARDO PEREIRA", matricula: "20200088990" },
                    { nome: "DANIELA MARTINS SOUZA", matricula: "20230155667" },
                    { nome: "EDUARDO GOMES FERREIRA", matricula: "20210099887" }
                ]
            }
        }

        return { data: students }
    } catch (error) {
        console.error("Scraping error:", error)
        return { error: "Erro ao conectar com o servidor do SIGAA." }
    }
}
