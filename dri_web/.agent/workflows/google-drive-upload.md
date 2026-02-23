---
description: Como implementar upload de arquivos para o Google Drive via Google Apps Script
---

# Upload de Documentos para Google Drive via Google Apps Script

## Contexto
Este padrão foi criado para permitir que usuários façam upload de documentos PDF diretamente para uma pasta do Google Drive pessoal (@gmail.com). A solução usa o **Google Apps Script como intermediário**, pois contas de serviço do Google não têm cota de armazenamento em Drives pessoais.

---

## Arquitetura da Solução

```
[Usuário (Browser)] → [Next.js Server Action] → [Google Apps Script Web App] → [Google Drive]
                   ↘ [Supabase document_uploads] (client-side insert, com sessão autenticada)
```

1. O arquivo PDF é convertido em **Base64** no servidor Next.js.
2. O Next.js envia os dados para o **Apps Script via POST**.
3. O Apps Script (rodando com as credenciais do dono da pasta) salva o arquivo.
4. A pasta do aluno é criada automaticamente se não existir.
5. Após sucesso, o **client-side** registra o upload no Supabase com a sessão autenticada.

---

## Passo 1: Criar o Google Apps Script

1. Acesse: https://script.google.com → **Novo projeto**
2. Cole o código abaixo substituindo `FOLDER_ID`:

```javascript
const FOLDER_ID = 'ID_DA_PASTA_DO_DRIVE_AQUI'

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents)
    const fileName = data.fileName
    const base64Content = data.fileContent
    const folderName = data.folderName

    // Encontra ou cria a pasta do usuário
    const mainFolder = DriveApp.getFolderById(FOLDER_ID)
    let studentFolder
    const folders = mainFolder.getFoldersByName(folderName)
    if (folders.hasNext()) {
      studentFolder = folders.next()
    } else {
      studentFolder = mainFolder.createFolder(folderName)
    }

    // Decodifica e salva o arquivo
    const bytes = Utilities.base64Decode(base64Content)
    const blob = Utilities.newBlob(bytes, 'application/pdf', fileName)
    const file = studentFolder.createFile(blob)

    return ContentService
      .createTextOutput(JSON.stringify({ success: true, link: file.getUrl() }))
      .setMimeType(ContentService.MimeType.JSON)
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ success: false, error: err.message }))
      .setMimeType(ContentService.MimeType.JSON)
  }
}
```

## Passo 2: Publicar o Apps Script como Web App

1. **Implementar** → **Nova implementação**
2. Tipo: **Web App**
3. **Executar como**: `Eu mesmo` ← OBRIGATÓRIO
4. **Quem tem acesso**: `Qualquer pessoa`
5. Copiar a **URL gerada** (`https://script.google.com/macros/s/.../exec`)

> ⚠️ Sempre que modificar o script, republique com **"Nova implementação"**. A URL muda a cada nova versão — atualize no `actions.ts`.

---

## Passo 3: Tabela no Supabase

Execute no **SQL Editor** do Supabase:

```sql
CREATE TABLE document_uploads (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid REFERENCES users_access(id) ON DELETE CASCADE,
  doc_type    text NOT NULL,      -- ex: 'TCC', 'TERMO', 'HISTORICO'
  category    text NOT NULL,      -- ex: 'tcc', 'intercambio', 'monitoria'
  file_name   text,
  drive_link  text,
  uploaded_at timestamptz DEFAULT now()
);

CREATE INDEX idx_document_uploads_user_id ON document_uploads(user_id);

ALTER TABLE document_uploads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own uploads"
  ON document_uploads FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own uploads"
  ON document_uploads FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

> 💡 Use o campo `category` para agrupar documentos por módulo. Assim a tabela serve para qualquer tipo de documento sem criar novas tabelas.

---

## Passo 4: Server Action (`actions.ts`)

> ⚠️ **IMPORTANTE**: O insert no Supabase NÃO deve ser feito aqui. O server action usa a chave anon sem sessão de usuário, o que viola o RLS. O insert deve ser feito no client-side. O server action só faz o upload para o Drive e retorna os dados.

```typescript
'use server'

const APPS_SCRIPT_URL = 'https://script.google.com/macros/s/.../exec'

export async function uploadToDrive(
  formData: FormData,
  userId: string,
  userName: string,
  userMatricula: string
) {
    try {
        const file = formData.get('file') as File
        const docType = formData.get('type') as string

        if (!file) throw new Error('Arquivo não encontrado')

        const bytes = await file.arrayBuffer()
        const base64Content = Buffer.from(bytes).toString('base64')

        const safeName = userName.toUpperCase()
        const date = new Date().toLocaleDateString('pt-BR').replace(/\//g, '-')
        const folderName = `${userMatricula} - ${safeName}`
        const fileName = `${docType} - ${safeName} - ${userMatricula} - ${date}.pdf`

        const payload = JSON.stringify({ folderName, fileName, fileContent: base64Content })

        // Passo 1: Resolver redirect do Google Apps Script
        const redirectResponse = await fetch(APPS_SCRIPT_URL, {
            method: 'GET',
            redirect: 'manual'
        })
        const finalUrl = redirectResponse.headers.get('location') || APPS_SCRIPT_URL

        // Passo 2: POST direto na URL final
        const response = await fetch(finalUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: payload,
            redirect: 'follow'
        })

        const text = await response.text()
        let result: any
        try {
            result = JSON.parse(text)
        } catch {
            throw new Error('Resposta inválida do servidor. Verifique publicação do Apps Script.')
        }

        if (!result.success) throw new Error(result.error || 'Erro no Apps Script')

        // Retorna fileName e docType para o cliente salvar no Supabase
        return { success: true, link: result.link, fileName, docType }
    } catch (error: any) {
        console.error('Upload Error:', error)
        return { success: false, error: error.message || 'Erro ao fazer upload' }
    }
}
```

---

## Passo 5: Client Component — Upload + Registro no Supabase

```typescript
const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>, type: string) => {
    const file = e.target.files?.[0]
    if (!file || !accessData) return

    const formData = new FormData()
    formData.append('file', file)
    formData.append('type', type)

    const result = await uploadToDrive(
        formData,
        userAuth.id,
        accessData.nomecompleto,
        accessData.matricula.toString()
    )

    if (result.success) {
        // Insert feito no cliente — sessão autenticada respeita o RLS ✅
        await supabase.from('document_uploads').insert({
            user_id: userAuth.id,
            doc_type: result.docType,
            category: 'tcc',          // ← mude para o módulo correspondente
            file_name: result.fileName,
            drive_link: result.link,
            uploaded_at: new Date().toISOString()
        })
    }
}
```

## Passo 6: Buscar histórico ao carregar a página

```typescript
const { data: uploads } = await supabase
    .from('document_uploads')
    .select('doc_type, file_name, drive_link, uploaded_at')
    .eq('user_id', session.user.id)
    .eq('category', 'tcc')           // ← filtra pelo módulo
    .order('uploaded_at', { ascending: false })
```

---

## Estrutura de Pastas no Drive

```
📁 Pasta Principal (FOLDER_ID)
  📁 117210001 - LEANDRO SILVA
    📄 TCC - LEANDRO SILVA - 117210001 - 19-02-2026.pdf
    📄 TERMO - LEANDRO SILVA - 117210001 - 19-02-2026.pdf
```

---

## Projeto de Referência (TCC)

| Item | Valor |
|------|-------|
| **Módulo** | Secretaria → Envio de TCC |
| **Apps Script URL** | `https://script.google.com/macros/s/AKfycbyeENasoKjrsLvKrCVCnQbN1zZ1Bz-kiMyClhsGypEu0uXdv4T_6SdA2LF_waPDRCAK/exec` |
| **Pasta Drive** | `https://drive.google.com/drive/folders/1Fcgk8FIT8a5P5CoLjFPIZS1hMPvL0hlq` |
| **Category no Supabase** | `'tcc'` |
| **Server Action** | `app/secretaria/envio-tcc/actions.ts` |
| **Client Page** | `app/secretaria/envio-tcc/page.tsx` |

---

## Erros Comuns e Soluções

| Erro | Causa | Solução |
|------|-------|---------|
| `Unexpected token '<'` | Apps Script retornou HTML de login | Republique com "Qualquer pessoa" |
| `Service Accounts do not have storage quota` | API Drive direto em Gmail pessoal | Use o Apps Script como intermediário |
| `ERR_OSSL_UNSUPPORTED` | Chave privada com `\n` literal | `.replace(/\\n/g, '\n')` na chave |
| `client_email field missing` | `.env.local` em UTF-16 | Recriar com `[System.IO.File]::WriteAllText(..., Encoding::UTF8)` |
| Upload salvo sempre no Supabase mas some ao relogar | Insert feito no server action sem sessão (viola RLS) | Mover o insert para o client-side |
| `SyntaxError: Unexpected token '<'` | Redirect do Apps Script perde o body do POST | Fazer GET para obter redirect URL, depois POST direto |
