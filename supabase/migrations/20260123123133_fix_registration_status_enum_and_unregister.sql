/*
  # Fix registration status enum and unregister function

  1. Problem
    - ENUM hat nur 'registered' und 'waitlist'
    - unregister_from_course verwendet 'cancelled' und 'confirmed'

  2. Loesung
    - ENUM um 'cancelled' erweitern
    - unregister_from_course korrigieren
*/

ALTER TYPE registration_status ADD VALUE IF NOT EXISTS 'cancelled';

CREATE OR REPLACE FUNCTION unregister_from_course(p_course_id uuid, p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_registration record;
  v_next_waitlist record;
BEGIN
  v_user_id := COALESCE(p_user_id, auth.uid());

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Benutzer nicht authentifiziert');
  END IF;

  SELECT * INTO v_registration
  FROM registrations
  WHERE course_id = p_course_id
  AND user_id = v_user_id
  AND status IN ('registered', 'waitlist');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Anmeldung nicht gefunden');
  END IF;

  UPDATE registrations
  SET status = 'cancelled',
      cancellation_timestamp = now()
  WHERE id = v_registration.id;

  IF NOT v_registration.is_waitlist THEN
    SELECT * INTO v_next_waitlist
    FROM registrations
    WHERE course_id = p_course_id
    AND is_waitlist = true
    AND status = 'waitlist'
    ORDER BY waitlist_position ASC
    LIMIT 1;

    IF FOUND THEN
      UPDATE registrations
      SET is_waitlist = false,
          status = 'registered',
          waitlist_position = NULL
      WHERE id = v_next_waitlist.id;
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Erfolgreich abgemeldet');
END;
$$;
