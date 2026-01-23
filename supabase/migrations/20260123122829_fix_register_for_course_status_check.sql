/*
  # Fix register_for_course status check

  1. Problem
    - Die Funktion prueft auf status = 'published'
    - Kurse haben aber status = 'active'
    - Dadurch schlaegt die Kursanmeldung immer fehl

  2. Loesung
    - Status-Pruefung auf 'active' aendern
*/

CREATE OR REPLACE FUNCTION register_for_course(p_course_id uuid, p_user_id uuid DEFAULT NULL)
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
BEGIN
  v_user_id := COALESCE(p_user_id, auth.uid());

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Benutzer nicht authentifiziert');
  END IF;

  SELECT * INTO v_course FROM courses WHERE id = p_course_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kurs nicht gefunden');
  END IF;

  IF v_course.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kurs ist nicht fuer Anmeldungen geoeffnet');
  END IF;

  IF EXISTS (
    SELECT 1 FROM registrations 
    WHERE course_id = p_course_id 
    AND user_id = v_user_id 
    AND status != 'cancelled'
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sie sind bereits fuer diesen Kurs angemeldet');
  END IF;

  SELECT COUNT(*) INTO v_current_count
  FROM registrations
  WHERE course_id = p_course_id
  AND status IN ('confirmed', 'pending', 'registered')
  AND NOT is_waitlist;

  v_is_waitlist := v_current_count >= v_course.max_participants;

  IF v_is_waitlist THEN
    SELECT COALESCE(MAX(waitlist_position), 0) + 1 INTO v_waitlist_position
    FROM registrations
    WHERE course_id = p_course_id AND is_waitlist = true;

    INSERT INTO registrations (course_id, user_id, status, is_waitlist, waitlist_position)
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
    INSERT INTO registrations (course_id, user_id, status, is_waitlist)
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
