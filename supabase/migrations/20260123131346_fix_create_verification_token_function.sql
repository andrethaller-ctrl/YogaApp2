/*
  # Fix Token Creation Function

  1. Changes
    - Enable pgcrypto extension for gen_random_bytes
    - Fix create_verification_token function to use correct column names
    - Remove email column reference (not in auth_tokens table)
    - Fix token_type to type

  2. Security
    - No changes to RLS policies
*/

-- Enable pgcrypto extension for gen_random_bytes
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Fix create_verification_token function
DROP FUNCTION IF EXISTS create_verification_token(uuid, text);

CREATE OR REPLACE FUNCTION create_verification_token(
  p_user_id uuid,
  p_email text
)
RETURNS TABLE(token text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token text;
BEGIN
  -- Generate a random token
  v_token := encode(gen_random_bytes(32), 'hex');
  
  -- Insert the token into auth_tokens table
  INSERT INTO auth_tokens (user_id, token, type, expires_at)
  VALUES (p_user_id, v_token, 'email_verification', now() + interval '24 hours');
  
  -- Return the token
  RETURN QUERY SELECT v_token;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION create_verification_token(uuid, text) TO service_role;
