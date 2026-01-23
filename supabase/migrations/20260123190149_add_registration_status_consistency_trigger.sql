/*
  # Add trigger to ensure registration status consistency

  1. Problem
    - Registrations can have cancellation_timestamp set but status != 'cancelled'
    - This causes inconsistent data across different views

  2. Solution
    - Create a trigger that automatically sets status='cancelled' when cancellation_timestamp is set
    - This ensures data consistency at the database level
*/

CREATE OR REPLACE FUNCTION public.ensure_registration_status_consistency()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.cancellation_timestamp IS NOT NULL AND NEW.status != 'cancelled' THEN
    NEW.status := 'cancelled';
  END IF;
  
  IF NEW.status = 'cancelled' AND NEW.cancellation_timestamp IS NULL THEN
    NEW.cancellation_timestamp := now();
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ensure_registration_status_consistency_trigger ON registrations;

CREATE TRIGGER ensure_registration_status_consistency_trigger
  BEFORE INSERT OR UPDATE ON registrations
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_registration_status_consistency();