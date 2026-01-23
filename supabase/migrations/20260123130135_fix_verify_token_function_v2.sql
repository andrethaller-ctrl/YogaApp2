/*
  # Fix verify_token function

  1. Bug Fixes
    - Column name: was using `token_type` but column is named `type`
    - Return column: was returning `is_valid` but Edge Function expects `valid`
    - Added `message` column for error messages as expected by Edge Function

  2. Changes
    - Drop existing function first (return type changed)
    - Recreate with correct column references and return type
*/

DROP FUNCTION IF EXISTS public.verify_token(text, text);

CREATE FUNCTION public.verify_token(p_token text, p_type text)
RETURNS TABLE(user_id uuid, email text, valid boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_token_record RECORD;
BEGIN
  SELECT t.user_id, t.email, t.expires_at, t.used
  INTO v_token_record
  FROM auth_tokens t
  WHERE t.token = p_token
  AND t.type = p_type;

  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, false, 'Token nicht gefunden'::text;
    RETURN;
  END IF;

  IF v_token_record.used THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, false, 'Token wurde bereits verwendet'::text;
    RETURN;
  END IF;

  IF v_token_record.expires_at <= now() THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, false, 'Token ist abgelaufen'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT v_token_record.user_id, v_token_record.email, true, 'Token gültig'::text;
END;
$function$;