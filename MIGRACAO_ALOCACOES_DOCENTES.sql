-- Tabela para armazenar a Carga Horária total de cada docente em cada disciplina num semestre
-- Isso desacopla a CH dos slots de horário (grade_aulas), permitindo que um professor tenha
-- uma CH específica (ex: 59h) independente de quantos slots ele ocupa na grade.

CREATE TABLE public.alocacoes_docentes (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    semestre TEXT NOT NULL,
    docente_id UUID NOT NULL,
    disciplina_id UUID NOT NULL,
    ch_alocada NUMERIC NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT alocacoes_docentes_pkey PRIMARY KEY (id),
    -- Garante que só existe um registro por professor/disciplina/semestre
    CONSTRAINT alocacoes_docentes_unique UNIQUE (semestre, docente_id, disciplina_id),
    
    CONSTRAINT alocacoes_docentes_docente_fkey FOREIGN KEY (docente_id) REFERENCES professores (id),
    CONSTRAINT alocacoes_docentes_disciplina_fkey FOREIGN KEY (disciplina_id) REFERENCES disciplinas (id)
) TABLESPACE pg_default;

-- Índices para performance
CREATE INDEX idx_alocacoes_docentes_semestre ON public.alocacoes_docentes(semestre);
CREATE INDEX idx_alocacoes_docentes_docente ON public.alocacoes_docentes(docente_id);
