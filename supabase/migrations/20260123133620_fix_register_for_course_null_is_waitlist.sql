/*
  # Fix register_for_course function NULL handling

  1. Changes
    - Fix the COUNT query to handle NULL values in is_waitlist column
    - Use `is_waitlist = false` instead of `NOT is_waitlist` to avoid NULL issues
    - Ensure consistent counting of registered participants
*/

CREATE OR REPLACE FUNCTION register_for_course(p_course_id uuid, p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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

  SELECT * INTO v_course FROM courses WHERE id = p_course_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kurs nicht gefunden');
  END IF;

  IF v_course.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kurs ist nicht fuer Anmeldungen geoeffnet');
  END IF;

  SELECT * INTO v_existing_registration
  FROM registrations 
  WHERE course_id = p_course_id 
  AND user_id = v_user_id;

  IF FOUND THEN
    IF v_existing_registration.status IN ('registered', 'waitlist') THEN
      RETURN jsonb_build_object('success', false, 'message', 'Sie sind bereits fuer diesen Kurs angemeldet');
    END IF;

    SELECT COUNT(*) INTO v_current_count
    FROM registrations
    WHERE course_id = p_course_id
    AND status = 'registered'
    AND (is_waitlist = false OR is_waitlist IS NULL);

    v_is_waitlist := v_current_count >= v_course.max_participants;

    IF v_is_waitlist THEN
      SELECT COALESCE(MAX(waitlist_position), 0) + 1 INTO v_waitlist_position
      FROM registrations
      WHERE course_id = p_course_id AND is_waitlist = true AND status = 'waitlist';

      UPDATE registrations
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
      UPDATE registrations
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
  FROM registrations
  WHERE course_id = p_course_id
  AND status = 'registered'
  AND (is_waitlist = false OR is_waitlist IS NULL);

  v_is_waitlist := v_current_count >= v_course.max_participants;

  IF v_is_waitlist THEN
    SELECT COALESCE(MAX(waitlist_position), 0) + 1 INTO v_waitlist_position
    FROM registrations
    WHERE course_id = p_course_id AND is_waitlist = true AND status = 'waitlist';

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