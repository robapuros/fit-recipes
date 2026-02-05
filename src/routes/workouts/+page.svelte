<script lang="ts">
  import { onMount } from 'svelte';
  import { auth } from '$lib/stores/auth';
  import { supabase, type WorkoutLog, type Exercise, muscleGroups } from '$lib/supabase';

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
      .order('order', { ascending: true })
      .order('created_at', { ascending: true });
    
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
      // Handle unilateral exercises
      if (set.reps_left !== undefined) {
        return total + 
          ((set.reps_left || 0) * (set.weight_left || 0)) +
          ((set.reps_right || 0) * (set.weight_right || 0));
      }
      return total + (set.reps || 0) * (set.weight || 0);
    }, 0);
  }

  function formatSet(set: any): string {
    if (set.reps_left !== undefined) {
      return `I:${set.reps_left}×${set.weight_left || 0}kg D:${set.reps_right}×${set.weight_right || 0}kg`;
    }
    if (set.duration_seconds && !set.reps) {
      return `${set.duration_seconds}s`;
    }
    if (set.duration_seconds && set.reps) {
      return `${set.reps}reps + ${set.duration_seconds}s`;
    }
    return `${set.reps || 0}×${set.weight || 0}${set.unit || 'kg'}`;
  }

  $: if (selectedDate) {
    loadWorkouts();
  }

  // Get unique methodology from today's workouts
  $: todayMethodology = workouts.find(w => w.methodology)?.methodology;
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

  {#if todayMethodology}
    <div class="methodology-banner">
      📋 {todayMethodology}
    </div>
  {/if}

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
      {#each workouts as workout, index}
        <div class="card workout-card">
          <div class="card-header">
            <div class="exercise-order">{index + 1}</div>
            <div class="exercise-details">
              <div class="card-title">{workout.exercise?.name || 'Ejercicio'}</div>
              {#if workout.exercise?.description}
                <div class="card-description">{workout.exercise.description}</div>
              {/if}
              <div class="card-tags">
                {#if workout.exercise?.muscle_group}
                  <span class="tag-small">{muscleGroups.find(m => m.value === workout.exercise?.muscle_group)?.label}</span>
                {/if}
                {#if workout.exercise?.is_unilateral}
                  <span class="tag-small">↔️ Unilateral</span>
                {/if}
                {#if workout.intensity}
                  <span class="tag-small intensity">{workout.intensity}</span>
                {/if}
              </div>
            </div>
            <button class="btn btn-sm btn-danger" on:click={() => deleteWorkout(workout.id)}>🗑️</button>
          </div>
          
          <div class="sets-summary">
            {#each workout.sets as set, i}
              <span class="set-badge">
                {formatSet(set)}
              </span>
            {/each}
          </div>

          {#if workout.rest_seconds}
            <div class="rest-info">⏱️ Descanso: {workout.rest_seconds}s</div>
          {/if}

          {#if workout.notes}
            <div class="workout-notes">💬 {workout.notes}</div>
          {/if}

          <div class="workout-stats">
            <span>{workout.sets.length} series</span>
            <span>•</span>
            <span>{calculateVolume(workout.sets).toLocaleString()} kg vol.</span>
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
        <div class="stat-label">Series</div>
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

  .methodology-banner {
    background: var(--color-primary);
    color: white;
    padding: 0.5rem 1rem;
    border-radius: var(--radius-sm);
    margin-bottom: 1rem;
    font-weight: 500;
  }

  .workout-card {
    margin-bottom: 0.75rem;
  }

  .card-header {
    display: flex;
    gap: 0.75rem;
    align-items: flex-start;
  }

  .exercise-order {
    background: var(--color-primary);
    color: white;
    width: 1.75rem;
    height: 1.75rem;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    font-size: 0.9rem;
    flex-shrink: 0;
  }

  .exercise-details {
    flex: 1;
  }

  .card-title {
    font-weight: 600;
    font-size: 1.05rem;
  }

  .card-description {
    color: var(--color-text-muted);
    font-size: 0.85rem;
    margin-top: 0.25rem;
    line-height: 1.3;
  }

  .card-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
    margin-top: 0.4rem;
  }

  .tag-small {
    font-size: 0.7rem;
    padding: 0.15rem 0.4rem;
    background: var(--color-bg-input);
    border-radius: 4px;
  }

  .tag-small.intensity {
    background: var(--color-secondary);
    color: white;
  }

  .sets-summary {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
    margin: 0.75rem 0;
  }

  .set-badge {
    background: var(--color-bg-input);
    color: var(--color-text);
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-size: 0.8rem;
    font-weight: 500;
  }

  .rest-info {
    color: var(--color-text-muted);
    font-size: 0.8rem;
    margin-bottom: 0.5rem;
  }

  .workout-notes {
    color: var(--color-text-muted);
    font-size: 0.85rem;
    margin-bottom: 0.5rem;
    padding: 0.5rem;
    background: var(--color-bg-input);
    border-radius: 4px;
  }

  .workout-stats {
    display: flex;
    gap: 0.5rem;
    color: var(--color-text-muted);
    font-size: 0.8rem;
    padding-top: 0.5rem;
    border-top: 1px solid var(--color-border);
  }

  .day-summary {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    background: var(--color-bg-card);
    border-radius: var(--radius);
    padding: 1rem;
    margin-top: 1rem;
  }

  .stat {
    text-align: center;
  }

  .stat-value {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--color-primary);
  }

  .stat-label {
    font-size: 0.75rem;
    color: var(--color-text-muted);
  }
</style>
