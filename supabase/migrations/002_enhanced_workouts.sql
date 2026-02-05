-- ============================================
-- ENHANCED WORKOUTS MIGRATION
-- Run this in Supabase SQL Editor
-- ============================================

-- Add tracking type to exercises (what fields to show when logging)
ALTER TABLE public.exercises 
ADD COLUMN IF NOT EXISTS is_unilateral boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS tracking_type text DEFAULT 'reps' 
  CHECK (tracking_type IN ('reps', 'time', 'distance', 'reps_and_time'));

-- Add methodology to workout logs
ALTER TABLE public.workout_logs
ADD COLUMN IF NOT EXISTS methodology text;

-- Create a table for common training methodologies (optional, for autocomplete)
CREATE TABLE IF NOT EXISTS public.methodologies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.methodologies ENABLE ROW LEVEL SECURITY;

-- Full access for authenticated users
CREATE POLICY "Methodologies viewable by authenticated"
  ON public.methodologies FOR SELECT TO authenticated USING (true);

CREATE POLICY "Methodologies insertable by authenticated"
  ON public.methodologies FOR INSERT TO authenticated WITH CHECK (true);

-- Seed common methodologies
INSERT INTO public.methodologies (name, description) VALUES
  ('Fuerza', 'Entrenamiento de fuerza máxima'),
  ('Hipertrofia', 'Entrenamiento para ganancia muscular'),
  ('Resistencia', 'Entrenamiento de resistencia muscular'),
  ('Potencia', 'Entrenamiento de potencia explosiva'),
  ('Evaluación Fuerza', 'Test de fuerza máxima'),
  ('Evaluación Potencia', 'Test de potencia'),
  ('Tabata', '20s trabajo / 10s descanso x 8 rondas'),
  ('EMOM', 'Every Minute On the Minute'),
  ('AMRAP', 'As Many Rounds As Possible'),
  ('Death By', 'Incremento progresivo cada minuto'),
  ('Isométrico', 'Mantener posición por tiempo'),
  ('Superserie', 'Dos ejercicios sin descanso'),
  ('Drop Set', 'Series descendentes de peso'),
  ('Pirámide', 'Incremento y decremento de peso'),
  ('Cluster', 'Series con micro-pausas'),
  ('Rest-Pause', 'Pausa corta para más reps')
ON CONFLICT (name) DO NOTHING;

-- Index for faster methodology search
CREATE INDEX IF NOT EXISTS idx_methodologies_name ON public.methodologies USING gin(to_tsvector('spanish', name));

-- Update exercises index for autocomplete
CREATE INDEX IF NOT EXISTS idx_exercises_name_trgm ON public.exercises USING gin(name gin_trgm_ops);

-- Note: If gin_trgm_ops doesn't exist, run this first:
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
