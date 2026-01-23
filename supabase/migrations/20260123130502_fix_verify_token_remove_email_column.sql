/*
  # Fix verify_token function
  
  The function was incorrectly trying to select an 'email' column 
  that doesn't exist in the auth_tokens table.
  
  ## Changes
  - Remove email from SELECT statement
  - Update return type to not include email
*/

DROP FUNCTION IF EXISTS verify_token(text, text);

CREATE OR REPLACE FUNCTION verify_token(p_token text, p_type text)
RETURNS TABLE(user_id uuid, valid boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token_record RECORD;
BEGIN
  SELECT t.user_id, t.expires_at, t.used
  INTO v_token_record
  FROM auth_tokens t
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