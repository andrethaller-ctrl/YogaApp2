/*
  # Vereinheitlichung der Teilnehmerzaehlung

  1. Problem
    - Die Funktion get_course_participant_counts verwendete cancellation_timestamp IS NULL
    - Andere Stellen im Code verwendeten status != 'cancelled'
    - Dies fuehrte zu inkonsistenten Zahlungen

  2. Loesung
    - Funktion aktualisiert, um konsistent status != 'cancelled' zu verwenden
    - Beide Bedingungen (status und is_waitlist) werden jetzt korrekt geprueft
*/

CREATE OR REPLACE FUNCTION get_course_participant_counts(p_course_ids uuid[])
RETURNS TABLE(course_id uuid, registered_count bigint, waitlist_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id as course_id,
    COUNT(r.id) FILTER (
      WHERE r.status = 'registered' 
      AND r.is_waitlist = false
    ) as registered_count,
    COUNT(r.id) FILTER (
      WHERE r.status = 'waitlist'
      AND r.is_waitlist = true
    ) as waitlist_count
  FROM courses c
  LEFT JOIN registrations r ON c.id = r.course_id
  WHERE c.id = ANY(p_course_ids)
  GROUP BY c.id;
END;
$$;