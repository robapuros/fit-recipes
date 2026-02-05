# FitRecipes 💪📖

A private web app for couples to track workouts and share recipes.

## Features

- **Workout Logging**: Track exercises, sets, reps, and weights
- **Shared Exercise Library**: Both users can add and use exercises
- **Personal Training Records**: View your partner's workouts (read-only)
- **Recipe Book**: Create and search recipes by ingredients
- **Mobile-First PWA**: Install on your phone for quick access

## Tech Stack

- **Frontend**: SvelteKit + TypeScript
- **Backend**: Supabase (Auth + PostgreSQL + RLS)
- **Styling**: Custom CSS (dark theme, mobile-first)

## Setup

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Go to **SQL Editor** and run the migration in `supabase/migrations/001_initial_schema.sql`

### 2. Create Users

In Supabase Dashboard → Authentication → Users:

1. Click "Add user" → "Create new user"
2. Create user with email starting with "alba" (e.g., alba@example.com)
3. Create user with email starting with "angel" (e.g., angel@example.com)
4. Users will receive magic links or you can set passwords

### 3. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your Supabase credentials (Settings → API):
- `PUBLIC_SUPABASE_URL`: Your project URL
- `PUBLIC_SUPABASE_ANON_KEY`: Your anon/public key

### 4. Install & Run

```bash
npm install
npm run dev
```

Open http://localhost:5173

## Deployment

### Vercel (Recommended)

```bash
npm install -g vercel
vercel
```

Set environment variables in Vercel dashboard.

### Docker

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
CMD ["node", "build"]
```

## Data Model

```
profiles (extends auth.users)
├── id, username (Alba|angel), display_name

exercises (shared)
├── name, muscle_group, description, created_by

workout_logs (personal, viewable by partner)
├── user_id, exercise_id, performed_at, sets[], notes

recipes (shared)
├── title, instructions, prep_time, cook_time, servings

ingredients (shared reference)
├── name, category

recipe_ingredients (junction)
├── recipe_id, ingredient_id, quantity, unit
```

## Row Level Security

- **Exercises**: Both can read all, each can edit their own
- **Workout Logs**: Both can read all, each can edit their own
- **Recipes**: Both can read and edit all
- **Ingredients**: Both can read and edit all

## License

Private project for personal use.
