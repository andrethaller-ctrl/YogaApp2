/*
  # Erlaubt Administratoren und Kursleitern, Teilnehmer anzumelden

  1. Neue Policies
    - "Admins can create registrations for any user"
      - Administratoren koennen beliebige Benutzer zu beliebigen Kursen anmelden
    - "Course leaders can create registrations for own courses"
      - Kursleiter koennen Benutzer zu ihren eigenen Kursen anmelden (wo sie teacher_id sind)

  2. Sicherheit
    - Nur authentifizierte Benutzer mit entsprechenden Rollen koennen diese Aktionen ausfuehren
    - Der zu registrierende Benutzer muss die Rolle 'participant' haben
*/

CREATE POLICY "Admins can create registrations for any user"
  ON registrations FOR INSERT
  TO authenticated
  WITH CHECK (
    is_admin()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = user_id
      AND 'participant' = ANY(roles)
    )
  );

CREATE POLICY "Course leaders can create registrations for own courses"
  ON registrations FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = (SELECT auth.uid())
      AND 'course_leader' = ANY(roles)
    )
    AND EXISTS (
      SELECT 1 FROM courses
      WHERE id = course_id
      AND teacher_id = (SELECT auth.uid())
    )
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = user_id
      AND 'participant' = ANY(roles)
    )
  );
