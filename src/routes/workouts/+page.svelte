<script lang="ts">
  import { onMount } from 'svelte';
  import { auth } from '$lib/stores/auth';
  import { supabase, type WorkoutLog, type Exercise } from '$lib/supabase';

  type WorkoutWithExercise = WorkoutLog & { exercise: Exercise };

  let workouts: WorkoutWithExercise[] = [];
  let loading = true;
  let selectedDate = new Date().toISOString().split('T')[0];

  onMount(() => {
    loadWorkouts();
  });

  async function loadWorkouts() {
    if (!$auth.user) return;
    
    loading = true;
    
    const { data, error } = await supabase
      .from('workout_logs')
      .select('*, exercise:exercises(*)')
      .eq('user_id', $auth.user.id)
      .eq('performed_at', selectedDate)
      .order('created_at', { ascending: false });
    
    if (!error) {
      workouts = data || [];
    }
    
    loading = false;
  }

  async function deleteWorkout(id: string) {
    if (!confirm('¿Eliminar este registro?')) return;
    
    await supabase.from('workout_logs').delete().eq('id', id);
    workouts = workouts.filter(w => w.id !== id);
  }

  function calculateVolume(sets: any[]): number {
    return sets.reduce((total, set) => {
      return total + (set.reps || 0) * (set.weight || 0);
    }, 0);
  }

  $: if (selectedDate) {
    loadWorkouts();
  }
</script>

<div class="page">
  <header class="page-header">
    <h1>Mis Entrenos</h1>
    <a href="/workouts/new" class="btn btn-primary btn-sm">+ Nuevo</a>
  </header>

  <div class="date-picker">
    <button class="btn btn-sm btn-secondary" on:click={() => {
      const d = new Date(selectedDate);
      d.setDate(d.getDate() - 1);
      selectedDate = d.toISOString().split('T')[0];
    }}>←</button>
    <input type="date" bind:value={selectedDate} class="form-input date-input" />
    <button class="btn btn-sm btn-secondary" on:click={() => {
      const d = new Date(selectedDate);
      d.setDate(d.getDate() + 1);
      selectedDate = d.toISOString().split('T')[0];
    }}>→</button>
  </div>

  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else if workouts.length === 0}
    <div class="empty-state">
      <div class="empty-state-icon">📝</div>
      <p>No hay entrenos este día</p>
      <a href="/workouts/new" class="btn btn-primary">Registrar entreno</a>
    </div>
  {:else}
    <div class="workout-list">
      {#each workouts as workout}
        <div class="card workout-card">
          <div class="card-header">
            <div>
              <div class="card-title">{workout.exercise?.name || 'Ejercicio'}</div>
              <div class="card-subtitle">{workout.exercise?.muscle_group || ''}</div>
            </div>
            <button class="btn btn-sm btn-danger" on:click={() => deleteWorkout(workout.id)}>🗑️</button>
          </div>
          
          <div class="sets-summary">
            {#each workout.sets as set, i}
              <span class="set-badge">
                {set.reps}×{set.weight}{set.unit || 'kg'}
              </span>
            {/each}
          </div>

          {#if workout.notes}
            <div class="workout-notes">{workout.notes}</div>
          {/if}

          <div class="workout-stats">
            <span>{workout.sets.length} series</span>
            <span>•</span>
            <span>{calculateVolume(workout.sets).toLocaleString()} kg volumen</span>
          </div>
        </div>
      {/each}
    </div>

    <div class="day-summary">
      <div class="stat">
        <div class="stat-value">{workouts.length}</div>
        <div class="stat-label">Ejercicios</div>
      </div>
      <div class="stat">
        <div class="stat-value">{workouts.reduce((t, w) => t + w.sets.length, 0)}</div>
        <div class="stat-label">Series totales</div>
      </div>
      <div class="stat">
        <div class="stat-value">{workouts.reduce((t, w) => t + calculateVolume(w.sets), 0).toLocaleString()}</div>
        <div class="stat-label">Volumen (kg)</div>
      </div>
    </div>
  {/if}
</div>

<style>
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .date-picker {
    display: flex;
    gap: 0.5rem;
    align-items: center;
    margin-bottom: 1rem;
  }

  .date-input {
    flex: 1;
    text-align: center;
  }

  .workout-card {
    margin-bottom: 1rem;
  }

  .sets-summary {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin: 0.75rem 0;
  }

  .set-badge {
    background: var(--color-primary);
    color: white;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .workout-notes {
    color: var(--color-text-muted);
    font-size: 0.875rem;
    font-style: italic;
    margin-bottom: 0.5rem;
  }

  .workout-stats {
    display: flex;
    gap: 0.5rem;
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }

  .day-summary {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    background: var(--color-bg-card);
    border-radius: var(--radius);
    padding: 1rem;
    margin-top: 1rem;
  }
</style>
