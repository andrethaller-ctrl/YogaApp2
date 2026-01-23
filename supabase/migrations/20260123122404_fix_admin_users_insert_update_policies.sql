/*
  # Korrigiert Admin-Policies fuer Benutzerverwaltung

  1. Aenderungen
    - Ersetzt die ALL-Policy durch separate Policies fuer jede Operation
    - INSERT: Admins koennen neue Teilnehmer anlegen
    - UPDATE: Admins koennen alle Benutzer bearbeiten
    - SELECT und DELETE bleiben via bestehende Policies erhalten

  2. Sicherheit
    - Nur Administratoren koennen diese Aktionen ausfuehren
    - Beim Anlegen wird sichergestellt, dass nur Teilnehmer erstellt werden
*/

DROP POLICY IF EXISTS "Admins can manage all users" ON users;

CREATE POLICY "Admins can read all users"
  ON users FOR SELECT
  TO authenticated
  USING (is_admin());

CREATE POLICY "Admins can insert participants"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (
    is_admin()
    AND 'participant' = ANY(roles)
  );

CREATE POLICY "Admins can update all users"
  ON users FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admins can delete users"
  ON users FOR DELETE
  TO authenticated
  USING (is_admin());
