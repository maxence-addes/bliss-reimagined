CREATE TABLE public.profiles (
  id uuid PRIMARY KEY,
  display_name text,
  role text,
  profession text,
  referral_source text,
  avatar_url text,
  invite_code text,
  invite_codes text[] NOT NULL DEFAULT '{}',
  used_invite_codes text[] NOT NULL DEFAULT '{}',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  onboarded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.parent_child_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_user_id uuid NOT NULL,
  child_user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (parent_user_id, child_user_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.parent_child_links TO authenticated;
GRANT ALL ON public.parent_child_links TO service_role;
ALTER TABLE public.parent_child_links ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.habits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  created_by uuid,
  name text NOT NULL,
  detail text NOT NULL DEFAULT '',
  schedule jsonb NOT NULL DEFAULT '{}'::jsonb,
  completions text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.habits TO authenticated;
GRANT ALL ON public.habits TO service_role;
ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.habit_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id uuid NOT NULL,
  child_user_id uuid NOT NULL,
  parent_user_id uuid NOT NULL,
  date date NOT NULL,
  image_path text NOT NULL,
  image_paths text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending',
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.habit_approvals TO authenticated;
GRANT ALL ON public.habit_approvals TO service_role;
ALTER TABLE public.habit_approvals ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_parent_of(_child uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.parent_child_links
    WHERE parent_user_id = auth.uid() AND child_user_id = _child
  );
$$;

CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.is_parent_of(id));
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY "links_select" ON public.parent_child_links FOR SELECT TO authenticated
  USING (parent_user_id = auth.uid() OR child_user_id = auth.uid());
CREATE POLICY "links_insert" ON public.parent_child_links FOR INSERT TO authenticated
  WITH CHECK (parent_user_id = auth.uid() OR child_user_id = auth.uid());
CREATE POLICY "links_delete" ON public.parent_child_links FOR DELETE TO authenticated
  USING (parent_user_id = auth.uid() OR child_user_id = auth.uid());

CREATE POLICY "habits_select" ON public.habits FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_parent_of(user_id));
CREATE POLICY "habits_insert" ON public.habits FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.is_parent_of(user_id));
CREATE POLICY "habits_update" ON public.habits FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.is_parent_of(user_id))
  WITH CHECK (user_id = auth.uid() OR public.is_parent_of(user_id));
CREATE POLICY "habits_delete" ON public.habits FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR public.is_parent_of(user_id));

CREATE POLICY "approvals_select" ON public.habit_approvals FOR SELECT TO authenticated
  USING (child_user_id = auth.uid() OR parent_user_id = auth.uid());
CREATE POLICY "approvals_insert" ON public.habit_approvals FOR INSERT TO authenticated
  WITH CHECK (child_user_id = auth.uid());
CREATE POLICY "approvals_update" ON public.habit_approvals FOR UPDATE TO authenticated
  USING (parent_user_id = auth.uid()) WITH CHECK (parent_user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
CREATE TRIGGER habits_updated_at BEFORE UPDATE ON public.habits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.ensure_profile()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (auth.uid()) ON CONFLICT (id) DO NOTHING;
END; $$;

CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _code text; _exists boolean;
BEGIN
  LOOP
    _code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    SELECT EXISTS (
      SELECT 1 FROM public.profiles WHERE invite_code = _code OR _code = ANY(invite_codes)
    ) INTO _exists;
    EXIT WHEN NOT _exists;
  END LOOP;
  RETURN _code;
END; $$;

CREATE OR REPLACE FUNCTION public.find_profile_by_invite_code(_code text)
RETURNS TABLE (id uuid, display_name text, profession text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.id, p.display_name, p.profession
  FROM public.profiles p
  WHERE (p.invite_code = upper(_code) OR upper(_code) = ANY(p.invite_codes))
    AND NOT (upper(_code) = ANY(p.used_invite_codes))
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.consume_invite_code(_code text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.profiles
  SET used_invite_codes = array_append(used_invite_codes, upper(_code))
  WHERE (invite_code = upper(_code) OR upper(_code) = ANY(invite_codes))
    AND NOT (upper(_code) = ANY(used_invite_codes));
$$;

CREATE OR REPLACE FUNCTION public.get_my_children()
RETURNS TABLE (id uuid, display_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.id, p.display_name
  FROM public.parent_child_links l
  JOIN public.profiles p ON p.id = l.child_user_id
  WHERE l.parent_user_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.ensure_profile(), public.generate_invite_code(),
  public.find_profile_by_invite_code(text), public.consume_invite_code(text),
  public.get_my_children(), public.is_parent_of(uuid) TO authenticated;

CREATE POLICY "proofs_insert_own" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'habit-proofs' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "proofs_select_own_or_parent" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'habit-proofs' AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR public.is_parent_of(((storage.foldername(name))[1])::uuid)
  ));
CREATE POLICY "proofs_delete_own" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'habit-proofs' AND (storage.foldername(name))[1] = auth.uid()::text);