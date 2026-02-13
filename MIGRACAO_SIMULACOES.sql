-- 1. Cria a tabela de Simulações (Cenários)
CREATE TABLE IF NOT EXISTS public.simulacoes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    semestre TEXT NOT NULL,
    nome TEXT NOT NULL DEFAULT 'Simulação Padrão',
    disciplinas_ignoradas JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Adiciona coluna simulacao_id em alocacoes_docentes
ALTER TABLE public.alocacoes_docentes
ADD COLUMN IF NOT EXISTS simulacao_id UUID REFERENCES public.simulacoes(id) ON DELETE CASCADE;

-- 3. Migração de dados existentes (IMPORTANTE)
DO $$
DECLARE
    v_sim_id UUID;
    v_semestre TEXT;
BEGIN
    -- Para cada semestre que tem alocações mas não tem simulação vinculada
    FOR v_semestre IN SELECT DISTINCT semestre FROM public.alocacoes_docentes WHERE simulacao_id IS NULL LOOP
        -- Cria uma Simulação Padrão
        INSERT INTO public.simulacoes (semestre, nome) VALUES (v_semestre, 'Simulação Padrão') RETURNING id INTO v_sim_id;
        
        -- Vincula as alocações órfãs a esta nova simulação
        UPDATE public.alocacoes_docentes 
        SET simulacao_id = v_sim_id 
        WHERE semestre = v_semestre AND simulacao_id IS NULL;
    END LOOP;
END $$;

-- 4. Ajustar Constraints (Unique)
-- Remove a constraint antiga que impedia múltiplas simulações
ALTER TABLE public.alocacoes_docentes DROP CONSTRAINT IF EXISTS alocacoes_docentes_unique;

-- Cria nova constraint considerando a Simulação
-- Um professor não pode ser alocado na mesma disciplina DENTRO DA MESMA SIMULAÇÃO
ALTER TABLE public.alocacoes_docentes 
ADD CONSTRAINT alocacoes_docentes_simulacao_unique UNIQUE (simulacao_id, docente_id, disciplina_id, turma); 
-- Nota: incluí 'turma' para permitir que o mesmo prof pegue turmas diferentes da mesma matéria
