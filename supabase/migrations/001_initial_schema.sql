-- ============================================
-- FIT-RECIPES INITIAL SCHEMA
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- PROFILES (extends Supabase Auth)
-- ============================================
create table public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  username text unique not null check (username in ('Alba', 'angel')),
  display_name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- EXERCISES (shared library)
-- ============================================
create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  muscle_group text check (muscle_group in ('chest', 'back', 'shoulders', 'arms', 'legs', 'core', 'cardio', 'full_body')),
  description text,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- WORKOUT LOGS (personal training records)
-- ============================================
create table public.workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  exercise_id uuid references public.exercises(id) on delete cascade not null,
  performed_at date not null default current_date,
  sets jsonb not null default '[]',
  -- sets format: [{"reps": 10, "weight": 50, "unit": "kg"}, ...]
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- RECIPES (shared cookbook)
-- ============================================
create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  instructions text,
  prep_time_min int,
  cook_time_min int,
  servings int,
  image_url text,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- INGREDIENTS (normalized reference)
-- ============================================
create table public.ingredients (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  category text check (category in ('protein', 'vegetable', 'fruit', 'dairy', 'grain', 'spice', 'sauce', 'other')),
  created_at timestamptz default now()
);

-- ============================================
-- RECIPE_INGREDIENTS (junction table)
-- ============================================
create table public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid references public.recipes(id) on delete cascade not null,
  ingredient_id uuid references public.ingredients(id) on delete cascade not null,
  quantity decimal,
  unit text,
  notes text,
  unique(recipe_id, ingredient_id)
);

-- ============================================
-- INDEXES
-- ============================================
create index idx_workout_logs_user on public.workout_logs(user_id);
create index idx_workout_logs_date on public.workout_logs(performed_at desc);
create index idx_workout_logs_exercise on public.workout_logs(exercise_id);
create index idx_exercises_muscle_group on public.exercises(muscle_group);
create index idx_recipe_ingredients_recipe on public.recipe_ingredients(recipe_id);
create index idx_recipe_ingredients_ingredient on public.recipe_ingredients(ingredient_id);

-- Full-text search on ingredients
create index idx_ingredients_name_search on public.ingredients 
  using gin(to_tsvector('spanish', name));

-- Full-text search on recipes
create index idx_recipes_title_search on public.recipes 
  using gin(to_tsvector('spanish', title));

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.workout_logs enable row level security;
alter table public.recipes enable row level security;
alter table public.ingredients enable row level security;
alter table public.recipe_ingredients enable row level security;

-- PROFILES: Read all, update own
create policy "Profiles viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Users can update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- EXERCISES: Full read, write own
create policy "Exercises viewable by authenticated"
  on public.exercises for select
  to authenticated
  using (true);

create policy "Exercises insertable by authenticated"
  on public.exercises for insert
  to authenticated
  with check (auth.uid() = created_by);

create policy "Exercises updatable by creator"
  on public.exercises for update
  to authenticated
  using (auth.uid() = created_by);

create policy "Exercises deletable by creator"
  on public.exercises for delete
  to authenticated
  using (auth.uid() = created_by);

-- WORKOUT LOGS: Write own, read all (partner visibility)
create policy "Workout logs viewable by authenticated"
  on public.workout_logs for select
  to authenticated
  using (true);

create policy "Users can insert own workout logs"
  on public.workout_logs for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update own workout logs"
  on public.workout_logs for update
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can delete own workout logs"
  on public.workout_logs for delete
  to authenticated
  using (auth.uid() = user_id);

-- RECIPES: Full access for authenticated
create policy "Recipes viewable by authenticated"
  on public.recipes for select
  to authenticated
  using (true);

create policy "Recipes insertable by authenticated"
  on public.recipes for insert
  to authenticated
  with check (auth.uid() = created_by);

create policy "Recipes updatable by authenticated"
  on public.recipes for update
  to authenticated
  using (true);

create policy "Recipes deletable by creator"
  on public.recipes for delete
  to authenticated
  using (auth.uid() = created_by);

-- INGREDIENTS: Full access (shared reference data)
create policy "Ingredients viewable by authenticated"
  on public.ingredients for select
  to authenticated
  using (true);

create policy "Ingredients insertable by authenticated"
  on public.ingredients for insert
  to authenticated
  with check (true);

create policy "Ingredients updatable by authenticated"
  on public.ingredients for update
  to authenticated
  using (true);

-- RECIPE_INGREDIENTS: Full access
create policy "Recipe ingredients viewable by authenticated"
  on public.recipe_ingredients for select
  to authenticated
  using (true);

create policy "Recipe ingredients insertable by authenticated"
  on public.recipe_ingredients for insert
  to authenticated
  with check (true);

create policy "Recipe ingredients updatable by authenticated"
  on public.recipe_ingredients for update
  to authenticated
  using (true);

create policy "Recipe ingredients deletable by authenticated"
  on public.recipe_ingredients for delete
  to authenticated
  using (true);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto-update updated_at timestamp
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

create trigger exercises_updated_at
  before update on public.exercises
  for each row execute function public.handle_updated_at();

create trigger workout_logs_updated_at
  before update on public.workout_logs
  for each row execute function public.handle_updated_at();

create trigger recipes_updated_at
  before update on public.recipes
  for each row execute function public.handle_updated_at();

-- Auto-create profile on user signup
create or replace function public.handle_new_user()
returns trigger as $$
declare
  username_val text;
begin
  -- Map email to username (customize these emails)
  username_val := case 
    when lower(new.email) like 'alba%' then 'Alba'
    when lower(new.email) like 'angel%' then 'angel'
    else null
  end;
  
  if username_val is not null then
    insert into public.profiles (id, username, display_name)
    values (new.id, username_val, username_val);
  end if;
  
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================
-- HELPER VIEWS
-- ============================================

-- View for searching recipes by ingredients
create or replace view public.recipe_search as
select 
  r.id,
  r.title,
  r.prep_time_min,
  r.cook_time_min,
  r.servings,
  r.created_by,
  array_agg(distinct i.name) as ingredient_names,
  string_agg(distinct i.name, ' ') as ingredient_text
from public.recipes r
left join public.recipe_ingredients ri on r.id = ri.recipe_id
left join public.ingredients i on ri.ingredient_id = i.id
group by r.id;

-- ============================================
-- SEED DATA (sample exercises)
-- ============================================
-- Note: Run this after creating your first user

-- insert into public.exercises (name, muscle_group, description, created_by) values
-- ('Bench Press', 'chest', 'Barbell bench press on flat bench', YOUR_USER_ID),
-- ('Squats', 'legs', 'Barbell back squats', YOUR_USER_ID),
-- ('Deadlift', 'back', 'Conventional deadlift', YOUR_USER_ID),
-- ('Pull-ups', 'back', 'Bodyweight pull-ups', YOUR_USER_ID),
-- ('Overhead Press', 'shoulders', 'Standing barbell press', YOUR_USER_ID),
-- ('Barbell Rows', 'back', 'Bent over barbell rows', YOUR_USER_ID),
-- ('Lunges', 'legs', 'Walking or stationary lunges', YOUR_USER_ID),
-- ('Plank', 'core', 'Forearm plank hold', YOUR_USER_ID);
