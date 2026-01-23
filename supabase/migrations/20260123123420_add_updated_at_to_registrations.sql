/*
  # Add updated_at column to registrations

  1. Problem
    - Trigger update_registrations_updated_at erwartet updated_at Spalte
    - Spalte existiert nicht in registrations Tabelle

  2. Loesung
    - updated_at Spalte hinzufuegen
*/

ALTER TABLE registrations 
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
