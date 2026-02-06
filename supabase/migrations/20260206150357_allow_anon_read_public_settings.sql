/*
  # Allow anonymous users to read public-facing settings

  1. Security Changes
    - Add SELECT policy on `global_settings` for `anon` role
    - Only allows reading specific keys needed on the login page:
      - `forgot_password_enabled`
      - `registration_email_enabled`
    - All other settings remain restricted to authenticated users

  2. Notes
    - This is needed because the login page checks whether the 
      "forgot password" feature is enabled before the user is authenticated
    - The policy is restrictive: only specific non-sensitive keys are exposed
*/

CREATE POLICY "Anonymous users can read public settings"
  ON global_settings
  FOR SELECT
  TO anon
  USING (key IN ('forgot_password_enabled', 'registration_email_enabled'));
