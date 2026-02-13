-- Adicionar colunas faltantes na tabela alocacoes_docentes para suportar a nova simulação
ALTER TABLE public.alocacoes_docentes
ADD COLUMN IF NOT EXISTS dias JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS turno TEXT DEFAULT 'Manhã',
ADD COLUMN IF NOT EXISTS slots JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS turma TEXT DEFAULT 'A',
ADD COLUMN IF NOT EXISTS sala TEXT DEFAULT '';

-- Comentários para documentação
COMMENT ON COLUMN public.alocacoes_docentes.dias IS 'Lista de dias da semana (ex: ["Seg", "Qua"])';
COMMENT ON COLUMN public.alocacoes_docentes.turno IS 'Turno predominante (Manhã, Tarde, Noite)';
COMMENT ON COLUMN public.alocacoes_docentes.slots IS 'Lista de slots específicos (ex: ["Seg-M1", "Qua-M2"])';
COMMENT ON COLUMN public.alocacoes_docentes.turma IS 'Identificador da turma (A, B, C...)';
COMMENT ON COLUMN public.alocacoes_docentes.sala IS 'Sala de aula (ex: 101, Lab 2)';
