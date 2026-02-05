-- ============================================
-- WORKOUT SESSIONS MIGRATION
-- Run this in Supabase SQL Editor
-- ============================================

-- Add rest time and intensity to workout logs
ALTER TABLE public.workout_logs
ADD COLUMN IF NOT EXISTS rest_seconds int,
ADD COLUMN IF NOT EXISTS intensity text,
ADD COLUMN IF NOT EXISTS "order" int DEFAULT 0;

-- Create intensity options reference
CREATE TABLE IF NOT EXISTS public.intensities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  percentage_range text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.intensities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Intensities viewable by authenticated"
  ON public.intensities FOR SELECT TO authenticated USING (true);

-- Seed intensity levels
INSERT INTO public.intensities (name, description, percentage_range) VALUES
  ('Muy baja', 'Calentamiento, recuperación activa', '30-40%'),
  ('Baja', 'Trabajo técnico, activación', '40-50%'),
  ('Moderada', 'Resistencia, volumen', '50-65%'),
  ('Media-Alta', 'Hipertrofia, fuerza-resistencia', '65-75%'),
  ('Alta', 'Fuerza, potencia', '75-85%'),
  ('Muy alta', 'Fuerza máxima', '85-95%'),
  ('Máxima', 'PR, test de máximos', '95-100%'),
  ('RPE 6', 'Podría hacer 4+ reps más', NULL),
  ('RPE 7', 'Podría hacer 3 reps más', NULL),
  ('RPE 8', 'Podría hacer 2 reps más', NULL),
  ('RPE 9', 'Podría hacer 1 rep más', NULL),
  ('RPE 10', 'Fallo muscular', NULL)
ON CONFLICT (name) DO NOTHING;
