/*
  # Fix mark_token_used function - remove reference to non-existent used_at column

  1. Changes
    - `mark_token_used` function: Removed `used_at = now()` from UPDATE statement
      because the `auth_tokens` table does not have a `used_at` column.
      The function now only sets `used = true`.

  2. Notes
    - This fixes a runtime error when marking password reset or email verification tokens as used.
*/

DROP FUNCTION IF EXISTS mark_token_used(text);

CREATE FUNCTION mark_token_used(p_token text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE auth_tokens
  SET used = true
  WHERE token = p_token AND NOT used;

  RETURN FOUND;
END;
$$;
