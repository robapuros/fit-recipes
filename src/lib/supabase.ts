import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

export const supabase = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY);

// Types for our database
export interface Profile {
  id: string;
  username: 'Alba' | 'angel';
  display_name: string | null;
  created_at: string;
  updated_at: string;
}

export interface Exercise {
  id: string;
  name: string;
  muscle_group: 'chest' | 'back' | 'shoulders' | 'arms' | 'legs' | 'core' | 'cardio' | 'full_body' | null;
  description: string | null;
  is_unilateral: boolean;
  tracking_type: 'reps' | 'time' | 'distance' | 'reps_and_time';
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface WorkoutSet {
  reps?: number;
  reps_left?: number;
  reps_right?: number;
  weight?: number;
  weight_left?: number;
  weight_right?: number;
  plates?: number;
  duration_seconds?: number;
  unit: 'kg' | 'lb';
}

export interface Methodology {
  id: string;
  name: string;
  description: string | null;
  created_at: string;
}

export interface WorkoutLog {
  id: string;
  user_id: string;
  exercise_id: string;
  performed_at: string;
  sets: WorkoutSet[];
  methodology: string | null;
  intensity: string | null;
  rest_seconds: number | null;
  order: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
  // Joined fields
  exercise?: Exercise;
  profile?: Profile;
}

export interface Intensity {
  id: string;
  name: string;
  description: string | null;
  percentage_range: string | null;
}

// Tracking types for exercises
export const trackingTypes = [
  { value: 'reps', label: 'Repeticiones' },
  { value: 'time', label: 'Tiempo (segundos)' },
  { value: 'distance', label: 'Distancia' },
  { value: 'reps_and_time', label: 'Reps + Tiempo' }
] as const;

export interface Recipe {
  id: string;
  title: string;
  instructions: string | null;
  prep_time_min: number | null;
  cook_time_min: number | null;
  servings: number | null;
  image_url: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  // Joined fields
  ingredients?: RecipeIngredient[];
}

export interface Ingredient {
  id: string;
  name: string;
  category: 'protein' | 'vegetable' | 'fruit' | 'dairy' | 'grain' | 'spice' | 'sauce' | 'other' | null;
  created_at: string;
}

export interface RecipeIngredient {
  id: string;
  recipe_id: string;
  ingredient_id: string;
  quantity: number | null;
  unit: string | null;
  notes: string | null;
  // Joined
  ingredient?: Ingredient;
}

// Muscle group labels
export const muscleGroups = [
  { value: 'chest', label: 'Pecho' },
  { value: 'back', label: 'Espalda' },
  { value: 'shoulders', label: 'Hombros' },
  { value: 'arms', label: 'Brazos' },
  { value: 'legs', label: 'Piernas' },
  { value: 'core', label: 'Core' },
  { value: 'cardio', label: 'Cardio' },
  { value: 'full_body', label: 'Cuerpo Completo' }
] as const;

// Ingredient categories
export const ingredientCategories = [
  { value: 'protein', label: 'Proteína' },
  { value: 'vegetable', label: 'Verdura' },
  { value: 'fruit', label: 'Fruta' },
  { value: 'dairy', label: 'Lácteos' },
  { value: 'grain', label: 'Cereales' },
  { value: 'spice', label: 'Especias' },
  { value: 'sauce', label: 'Salsas' },
  { value: 'other', label: 'Otros' }
] as const;
