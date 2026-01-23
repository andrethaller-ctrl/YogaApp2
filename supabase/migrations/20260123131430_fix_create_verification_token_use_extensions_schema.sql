/*
  # Fix Token Creation Function - Use Extensions Schema

  1. Changes
    - Fix create_verification_token to use extensions.gen_random_bytes
    - Update search_path to include extensions schema
    - Fix column names to match auth_tokens table

  2. Security
    - No changes to RLS policies
*/

-- Fix create_verification_token function with correct schema reference
DROP FUNCTION IF EXISTS create_verification_token(uuid, text);

CREATE OR REPLACE FUNCTION create_verification_token(
  p_user_id uuid,
  p_email text
)
RETURNS TABLE(token text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_token text;
BEGIN
  -- Generate a random token using extensions.gen_random_bytes
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  
  -- Insert the token into auth_tokens table
  INSERT INTO auth_tokens (user_id, token, type, expires_at)
  VALUES (p_user_id, v_token, 'email_verification', now() + interval '24 hours');
  
  -- Return the token
  RETURN QUERY SELECT v_token;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION create_verification_token(uuid, text) TO service_role;
