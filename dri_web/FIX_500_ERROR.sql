-- 1. Create a secure function to read access level without triggering RLS loops
-- This function runs as the database owner (SECURITY DEFINER), bypassing RLS
CREATE OR REPLACE FUNCTION public.get_user_access_level(user_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER 
SET search_path = public 
AS $$
  SELECT access_level FROM public.users_access WHERE id = user_id;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_access_level(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_access_level(uuid) TO service_role;

-- 2. Drop the problematic policies that are causing recursion/500 errors
DROP POLICY IF EXISTS "Admins can view all data" ON public.users_access;
DROP POLICY IF EXISTS "Admins can update all data" ON public.users_access;
DROP POLICY IF EXISTS "Users can view their own data" ON public.users_access;
DROP POLICY IF EXISTS "Users can view own data" ON public.users_access;

-- 3. Re-create policies using the secure function

-- Policy: Everyone can see their own data
CREATE POLICY "Users can view own data" ON public.users_access
FOR SELECT
USING (auth.uid() = id);

-- Policy: Admins (Level >= 4) can view ALL data
CREATE POLICY "Admins can view all data" ON public.users_access
FOR SELECT
USING (
  public.get_user_access_level(auth.uid()) >= 4
);

-- Policy: Admins (Level >= 4) can update ALL data
CREATE POLICY "Admins can update all data" ON public.users_access
FOR UPDATE
USING (
  public.get_user_access_level(auth.uid()) >= 4
);

-- Ensure RLS is enabled
ALTER TABLE public.users_access ENABLE ROW LEVEL SECURITY;
