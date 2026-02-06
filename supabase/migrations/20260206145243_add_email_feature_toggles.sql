/*
  # E-Mail-Funktions-Schalter

  1. Neue Einstellungen
    - `forgot_password_enabled` - Aktiviert/deaktiviert die "Passwort vergessen" Funktion
    - `registration_email_enabled` - Aktiviert/deaktiviert den Emailversand bei Registrierung
  
  2. Standardwerte
    - Beide Funktionen sind standardmäßig aktiviert (true)
  
  3. Sicherheit
    - Einstellungen können nur von Administratoren geändert werden (durch bestehende RLS-Policies)
*/

-- Add forgot password enabled setting
INSERT INTO global_settings (key, value, updated_at)
VALUES ('forgot_password_enabled', 'true', now())
ON CONFLICT (key) DO NOTHING;

-- Add registration email enabled setting
INSERT INTO global_settings (key, value, updated_at)
VALUES ('registration_email_enabled', 'true', now())
ON CONFLICT (key) DO NOTHING;