/*
  # Fix Security Issues - Unused Indexes, Multiple Permissive Policies, and Function Search Paths

  1. Removed Indexes (unused)
    - `idx_users_admin_role` on users table
    - `idx_courses_teacher_id` on courses table
    - `idx_users_roles` on users table
    - `idx_courses_series_id` on courses table
    - `idx_courses_status` on courses table
    - `idx_registrations_is_waitlist` on registrations table
    - `idx_messages_course_id` on messages table
    - `idx_messages_recipient_id` on messages table
    - `idx_messages_sender_id` on messages table
    - `idx_auth_tokens_token` on auth_tokens table
    - `idx_auth_tokens_user_type` on auth_tokens table
    - `idx_auth_tokens_expires` on auth_tokens table
    - `idx_auth_tokens_used` on auth_tokens table

  2. Consolidated RLS Policies
    - email_templates: Merged admin SELECT ALL and general SELECT policies
    - global_settings: Merged admin SELECT ALL and general SELECT policies
    - messages: Merged INSERT policies for course leaders and participants
    - registrations: Consolidated SELECT, INSERT, UPDATE, DELETE policies
    - users: Consolidated SELECT and UPDATE policies

  3. Fixed Function Search Paths
    - verify_token: Set explicit search_path
    - ensure_registration_status_consistency: Set explicit search_path
    - register_for_course: Set explicit search_path
    - create_password_reset_token: Set explicit search_path

  4. Notes
    - Auth DB Connection Strategy and Leaked Password Protection must be configured in Supabase Dashboard
*/

-- ============================================
-- PART 1: DROP UNUSED INDEXES
-- ============================================

DROP INDEX IF EXISTS idx_users_admin_role;
DROP INDEX IF EXISTS idx_courses_teacher_id;
DROP INDEX IF EXISTS idx_users_roles;
DROP INDEX IF EXISTS idx_courses_series_id;
DROP INDEX IF EXISTS idx_courses_status;
DROP INDEX IF EXISTS idx_registrations_is_waitlist;
DROP INDEX IF EXISTS idx_messages_course_id;
DROP INDEX IF EXISTS idx_messages_recipient_id;
DROP INDEX IF EXISTS idx_messages_sender_id;
DROP INDEX IF EXISTS idx_auth_tokens_token;
DROP INDEX IF EXISTS idx_auth_tokens_user_type;
DROP INDEX IF EXISTS idx_auth_tokens_expires;
DROP INDEX IF EXISTS idx_auth_tokens_used;

-- ============================================
-- PART 2: CONSOLIDATE MULTIPLE PERMISSIVE POLICIES
-- ============================================

-- 2.1 email_templates: Consolidate SELECT policies (merge ALL + SELECT)
DROP POLICY IF EXISTS "Admins can manage email templates" ON email_templates;
DROP POLICY IF EXISTS "Anyone can read email templates" ON email_templates;

CREATE POLICY "Authenticated users can read email templates"
  ON email_templates
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert email templates"
  ON email_templates
  FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

CREATE POLICY "Admins can update email templates"
  ON email_templates
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admins can delete email templates"
  ON email_templates
  FOR DELETE
  TO authenticated
  USING (is_admin());

-- 2.2 global_settings: Consolidate SELECT policies (merge ALL + SELECT)
DROP POLICY IF EXISTS "Admins can manage settings" ON global_settings;
DROP POLICY IF EXISTS "Anyone authenticated can view settings" ON global_settings;

CREATE POLICY "Authenticated users can read settings"
  ON global_settings
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert settings"
  ON global_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

CREATE POLICY "Admins can update settings"
  ON global_settings
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admins can delete settings"
  ON global_settings
  FOR DELETE
  TO authenticated
  USING (is_admin());

-- 2.3 messages: Consolidate INSERT policies
DROP POLICY IF EXISTS "Course leaders can send messages" ON messages;
DROP POLICY IF EXISTS "Participants can send messages to course leaders" ON messages;

CREATE POLICY "Users can send messages based on role"
  ON messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND (
      -- Course leaders can send to anyone (they have the role)
      EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND 'course_leader' = ANY(users.roles)
      )
      OR
      -- Participants can send to course leaders of courses they are registered in
      EXISTS (
        SELECT 1 FROM registrations r
        JOIN courses c ON r.course_id = c.id
        WHERE r.user_id = auth.uid()
        AND c.teacher_id = messages.recipient_id
      )
    )
  );

-- 2.4 registrations: Consolidate all policies
DROP POLICY IF EXISTS "Admins can manage all registrations" ON registrations;
DROP POLICY IF EXISTS "Users can delete own registrations" ON registrations;
DROP POLICY IF EXISTS "Admins can create registrations for any user" ON registrations;
DROP POLICY IF EXISTS "Course leaders can create registrations for own courses" ON registrations;
DROP POLICY IF EXISTS "Participants can create registrations" ON registrations;
DROP POLICY IF EXISTS "Admins can read all registrations" ON registrations;
DROP POLICY IF EXISTS "Course leaders can read course registrations" ON registrations;
DROP POLICY IF EXISTS "Users can read own registrations" ON registrations;
DROP POLICY IF EXISTS "Course leaders can update course registrations" ON registrations;

-- Registrations SELECT: Users see own, course leaders see their courses, admins see all
CREATE POLICY "Registrations select policy"
  ON registrations
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM courses c
      WHERE c.id = registrations.course_id
      AND c.teacher_id = auth.uid()
    )
    OR is_admin()
  );

-- Registrations INSERT: Users can register themselves, course leaders for their courses, admins for any
CREATE POLICY "Registrations insert policy"
  ON registrations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Users can register themselves if they have participant role
    (
      user_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND 'participant' = ANY(users.roles)
      )
    )
    -- Course leaders can register users in their own courses
    OR (
      EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND 'course_leader' = ANY(users.roles)
      )
      AND EXISTS (
        SELECT 1 FROM courses
        WHERE courses.id = registrations.course_id
        AND courses.teacher_id = auth.uid()
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = registrations.user_id
        AND 'participant' = ANY(users.roles)
      )
    )
    -- Admins can register any participant in any course
    OR (
      is_admin()
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = registrations.user_id
        AND 'participant' = ANY(users.roles)
      )
    )
  );

-- Registrations UPDATE: Course leaders for their courses, admins for all
CREATE POLICY "Registrations update policy"
  ON registrations
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM courses c
      WHERE c.id = registrations.course_id
      AND c.teacher_id = auth.uid()
    )
    OR is_admin()
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM courses c
      WHERE c.id = registrations.course_id
      AND c.teacher_id = auth.uid()
    )
    OR is_admin()
  );

-- Registrations DELETE: Users can delete own, course leaders can delete from their courses, admins can delete any
CREATE POLICY "Registrations delete policy"
  ON registrations
  FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM courses c
      WHERE c.id = registrations.course_id
      AND c.teacher_id = auth.uid()
    )
    OR is_admin()
  );

-- 2.5 users: Consolidate SELECT and UPDATE policies
DROP POLICY IF EXISTS "Admins can read all users" ON users;
DROP POLICY IF EXISTS "Users can read own profile" ON users;
DROP POLICY IF EXISTS "Admins can update all users" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;

-- Users SELECT: Users can read own, admins can read all
CREATE POLICY "Users select policy"
  ON users
  FOR SELECT
  TO authenticated
  USING (
    id = auth.uid()
    OR is_admin()
  );

-- Users UPDATE: Users can update own (with role restriction), admins can update all
CREATE POLICY "Users update policy"
  ON users
  FOR UPDATE
  TO authenticated
  USING (
    id = auth.uid()
    OR is_admin()
  )
  WITH CHECK (
    -- Users can update own profile but cannot change their roles
    (
      id = auth.uid()
      AND roles = (SELECT u.roles FROM users u WHERE u.id = auth.uid())
    )
    -- Admins can update anything
    OR is_admin()
  );

-- ============================================
-- PART 3: FIX FUNCTION SEARCH PATHS
-- ============================================

-- 3.1 Fix verify_token function with explicit search_path
-- Drop first to change return type
DROP FUNCTION IF EXISTS public.verify_token(text, text);

CREATE FUNCTION public.verify_token(
  p_token text,
  p_type text
)
RETURNS TABLE (
  user_id uuid,
  is_valid boolean,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token_record RECORD;
BEGIN
  SELECT t.user_id, t.expires_at, t.used
  INTO v_token_record
  FROM public.auth_tokens t
  WHERE t.token = p_token
  AND t.type = p_type;

  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, false, 'Token nicht gefunden'::text;
    RETURN;
  END IF;

  IF v_token_record.used THEN
    RETURN QUERY SELECT NULL::uuid, false, 'Token wurde bereits verwendet'::text;
    RETURN;
  END IF;

  IF v_token_record.expires_at <= now() THEN
    RETURN QUERY SELECT NULL::uuid, false, 'Token ist abgelaufen'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT v_token_record.user_id, true, 'Token gültig'::text;
END;
$$;

-- 3.2 Fix ensure_registration_status_consistency function with explicit search_path
CREATE OR REPLACE FUNCTION public.ensure_registration_status_consistency()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.cancellation_timestamp IS NOT NULL AND NEW.status != 'cancelled' THEN
    NEW.status := 'cancelled';
  END IF;

  IF NEW.status = 'cancelled' AND NEW.cancellation_timestamp IS NULL THEN
    NEW.cancellation_timestamp := now();
  END IF;

  RETURN NEW;
END;
$$;

-- 3.3 Fix register_for_course function with explicit search_path
CREATE OR REPLACE FUNCTION public.register_for_course(
  p_course_id uuid,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_course record;
  v_current_count int;
  v_is_waitlist boolean;
  v_registration_id uuid;
  v_waitlist_position int;
  v_existing_registration record;
BEGIN
  v_user_id := COALESCE(p_user_id, auth.uid());

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Benutzer nicht authentifiziert');
  END IF;

  SELECT * INTO v_course FROM public.courses WHERE id = p_course_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kurs nicht gefunden');
  END IF;

  IF v_course.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kurs ist nicht fuer Anmeldungen geoeffnet');
  END IF;

  SELECT * INTO v_existing_registration
  FROM public.registrations 
  WHERE course_id = p_course_id 
  AND user_id = v_user_id;

  IF FOUND THEN
    IF v_existing_registration.status IN ('registered', 'waitlist') THEN
      RETURN jsonb_build_object('success', false, 'message', 'Sie sind bereits fuer diesen Kurs angemeldet');
    END IF;

    SELECT COUNT(*) INTO v_current_count
    FROM public.registrations
    WHERE course_id = p_course_id
    AND status = 'registered'
    AND (is_waitlist = false OR is_waitlist IS NULL);

    v_is_waitlist := v_current_count >= v_course.max_participants;

    IF v_is_waitlist THEN
      SELECT COALESCE(MAX(waitlist_position), 0) + 1 INTO v_waitlist_position
      FROM public.registrations
      WHERE course_id = p_course_id AND is_waitlist = true AND status = 'waitlist';

      UPDATE public.registrations
      SET status = 'waitlist',
          is_waitlist = true,
          waitlist_position = v_waitlist_position,
          registered_at = now(),
          signup_timestamp = now(),
          cancellation_timestamp = NULL
      WHERE id = v_existing_registration.id
      RETURNING id INTO v_registration_id;

      RETURN jsonb_build_object(
        'success', true,
        'message', 'Sie wurden auf die Warteliste gesetzt',
        'registration_id', v_registration_id,
        'is_waitlist', true,
        'waitlist_position', v_waitlist_position
      );
    ELSE
      UPDATE public.registrations
      SET status = 'registered',
          is_waitlist = false,
          waitlist_position = NULL,
          registered_at = now(),
          signup_timestamp = now(),
          cancellation_timestamp = NULL
      WHERE id = v_existing_registration.id
      RETURNING id INTO v_registration_id;

      RETURN jsonb_build_object(
        'success', true,
        'message', 'Erfolgreich angemeldet!',
        'registration_id', v_registration_id,
        'is_waitlist', false
      );
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_current_count
  FROM public.registrations
  WHERE course_id = p_course_id
  AND status = 'registered'
  AND (is_waitlist = false OR is_waitlist IS NULL);

  v_is_waitlist := v_current_count >= v_course.max_participants;

  IF v_is_waitlist THEN
    SELECT COALESCE(MAX(waitlist_position), 0) + 1 INTO v_waitlist_position
    FROM public.registrations
    WHERE course_id = p_course_id AND is_waitlist = true AND status = 'waitlist';

    INSERT INTO public.registrations (course_id, user_id, status, is_waitlist, waitlist_position)
    VALUES (p_course_id, v_user_id, 'waitlist', true, v_waitlist_position)
    RETURNING id INTO v_registration_id;

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Sie wurden auf die Warteliste gesetzt',
      'registration_id', v_registration_id,
      'is_waitlist', true,
      'waitlist_position', v_waitlist_position
    );
  ELSE
    INSERT INTO public.registrations (course_id, user_id, status, is_waitlist)
    VALUES (p_course_id, v_user_id, 'registered', false)
    RETURNING id INTO v_registration_id;

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Erfolgreich angemeldet!',
      'registration_id', v_registration_id,
      'is_waitlist', false
    );
  END IF;
END;
$$;

-- 3.4 Fix create_password_reset_token function with explicit search_path
-- First drop the existing functions to avoid signature conflicts
DROP FUNCTION IF EXISTS public.create_password_reset_token(uuid);
DROP FUNCTION IF EXISTS public.create_password_reset_token(uuid, text);

CREATE FUNCTION public.create_password_reset_token(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token text;
BEGIN
  UPDATE public.auth_tokens
  SET used = true
  WHERE user_id = p_user_id
  AND type = 'password_reset'
  AND NOT used;

  v_token := encode(gen_random_bytes(32), 'hex');

  INSERT INTO public.auth_tokens (user_id, token, type, expires_at)
  VALUES (p_user_id, v_token, 'password_reset', now() + INTERVAL '1 hour');

  RETURN v_token;
END;
$$;