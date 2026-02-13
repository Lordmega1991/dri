# 🚨 MIGRACAO URGENTE: Nova Tabela de Alocações

Para corrigir definitivamente o problema da carga horária e permitir que ela seja independente dos slots (ex: 59h mesmo com 1 slot), implementamos uma nova estrutura.

**Você PRECISA criar esta tabela no Supabase para o sistema voltar a funcionar, pois o código já foi atualizado para usá-la.**

## 1. Execute no SQL Editor do Supabase

```sql
-- Tabela para armazenar a Carga Horária total (separada da grade)
CREATE TABLE public.alocacoes_docentes (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    semestre TEXT NOT NULL,
    docente_id UUID NOT NULL,
    disciplina_id UUID NOT NULL,
    ch_alocada NUMERIC NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT alocacoes_docentes_pkey PRIMARY KEY (id),
    CONSTRAINT alocacoes_docentes_unique UNIQUE (semestre, docente_id, disciplina_id)
);

-- Índices para performance
CREATE INDEX idx_alocacoes_docentes_semestre ON public.alocacoes_docentes(semestre);
```

**Nota:** Não precisa adicionar nenhuma coluna na tabela `grade_aulas`! A coluna `ch_alocada` NÃO será usada na grade_aulas.

## 2. Como Funciona Agora

1. **Simulação**: Salva os horários na `grade_aulas` E a carga horária na `alocacoes_docentes`.
2. **Grade**: 
   - Lê os horários de `grade_aulas` para montar o visual.
   - Lê a carga horária de `alocacoes_docentes` para calcular o total do professor.

Isso garante que se o professor tiver 59h definidas na simulação, ele terá 59h na grade, independente de quantos slots (quadradinhos) ele ocupar.

## 3. Teste

Após criar a tabela:
1. Vá na Simulação.
2. Clique em "Aplicar na Grade".
3. Vá na Grade de Aulas e verifique se a CH está correta.

---
**Atualizado:** 2026-02-09
