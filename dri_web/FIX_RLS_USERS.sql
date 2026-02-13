-- Habilita RLS na tabela users_access (caso não esteja habilitado)
ALTER TABLE public.users_access ENABLE ROW LEVEL SECURITY;

-- 1. Política para o próprio usuário ver seus dados
-- (Isso geralmente já existe, mas garantimos aqui)
CREATE POLICY "Users can view their own data" 
ON public.users_access
FOR SELECT 
USING (auth.uid() = id);

-- 2. Política para Administradores (Nível >= 4) verem TODOS os dados
-- Esta política permite que admins vejam todas as linhas
CREATE POLICY "Admins can view all data" 
ON public.users_access
FOR SELECT 
USING (
  (SELECT access_level FROM public.users_access WHERE id = auth.uid()) >= 4
);

-- 3. Política para Administradores (Nível >= 4) ATUALIZAREM dados
-- Necessário para o admin poder editar o nível de acesso dos outros
CREATE POLICY "Admins can update all data" 
ON public.users_access
FOR UPDATE 
USING (
  (SELECT access_level FROM public.users_access WHERE id = auth.uid()) >= 4
);
