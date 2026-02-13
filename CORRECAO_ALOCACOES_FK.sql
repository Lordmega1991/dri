-- 🚨 SCRIPT DE CORREÇÃO DE RELACIONAMENTO 🚨

-- O erro "Could not find a relationship" ocorre porque faltam as Chaves Estrangeiras (Foreign Keys).
-- Execute este script no SQL Editor do Supabase para corrigir.

-- 1. Tentar adicionar as constraints na tabela existente
DO $$
BEGIN
    -- FK Docentes
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'alocacoes_docentes_docente_fkey') THEN
        ALTER TABLE public.alocacoes_docentes 
        ADD CONSTRAINT alocacoes_docentes_docente_fkey 
        FOREIGN KEY (docente_id) REFERENCES public.docentes(id);
    END IF;

    -- FK Disciplinas
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'alocacoes_docentes_disciplina_fkey') THEN
        ALTER TABLE public.alocacoes_docentes 
        ADD CONSTRAINT alocacoes_docentes_disciplina_fkey 
        FOREIGN KEY (disciplina_id) REFERENCES public.disciplinas(id);
    END IF;
END $$;

-- 2. Atualizar o cache do schema
NOTIFY pgrst, 'reload schema';

-- SE O ERRO PERSISTIR:
-- Pode ser necessário deletar e recriar a tabela com as referências corretas explícitas:
/*
DROP TABLE IF EXISTS public.alocacoes_docentes;

CREATE TABLE public.alocacoes_docentes (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    semestre TEXT NOT NULL,
    docente_id UUID NOT NULL REFERENCES public.professores(id),
    disciplina_id UUID NOT NULL REFERENCES public.disciplinas(id),
    ch_alocada NUMERIC NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT alocacoes_docentes_pkey PRIMARY KEY (id),
    CONSTRAINT alocacoes_docentes_unique UNIQUE (semestre, docente_id, disciplina_id)
);
*/
