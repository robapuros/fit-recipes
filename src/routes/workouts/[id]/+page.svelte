<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth';
  import { supabase, type WorkoutLog, type Exercise, type Intensity, muscleGroups } from '$lib/supabase';

  let workout: (WorkoutLog & { exercise: Exercise }) | null = null;
  let intensities: Intensity[] = [];
  let loading = true;
  let saving = false;
  let error = '';

  let form = {
    sets: [] as any[],
    intensity: '',
    rest_seconds: 60,
    notes: '',
    performed_at: ''
  };

  onMount(async () => {
    // Load workout
    const { data: workoutData, error: fetchError } = await supabase
      .from('workout_logs')
      .select('*, exercise:exercises(*)')
      .eq('id', $page.params.id)
      .single();

    if (fetchError || !workoutData) {
      goto('/workouts');
      return;
    }

    workout = workoutData;
    form = {
      sets: workoutData.sets || [],
      intensity: workoutData.intensity || '',
      rest_seconds: workoutData.rest_seconds || 60,
      notes: workoutData.notes || '',
      performed_at: workoutData.performed_at
    };

    // Ensure at least one set
    if (form.sets.length === 0) {
      form.sets = [createEmptySet(workoutData.exercise)];
    }

    // Load intensities
    const { data: intData } = await supabase
      .from('intensities')
      .select('*')
      .order('name');
    intensities = intData || [];

    loading = false;
  });

  function createEmptySet(exercise: Exercise) {
    const set: any = { unit: 'kg' };
    if (exercise.is_unilateral) {
      set.reps_left = 0;
      set.reps_right = 0;
      set.weight_left = 0;
      set.weight_right = 0;
    } else {
      set.reps = 0;
      set.weight = 0;
    }
    if (exercise.tracking_type === 'time' || exercise.tracking_type === 'reps_and_time') {
      set.duration_seconds = 0;
    }
    return set;
  }

  function addSet() {
    if (!workout) return;
    const lastSet = form.sets[form.sets.length - 1] || createEmptySet(workout.exercise);
    form.sets = [...form.sets, { ...lastSet }];
  }

  function removeSet(index: number) {
    if (form.sets.length > 1) {
      form.sets = form.sets.filter((_, i) => i !== index);
    }
  }

  async function saveWorkout() {
    if (!workout) return;

    saving = true;
    error = '';

    const { error: updateError } = await supabase
      .from('workout_logs')
      .update({
        sets: form.sets,
        intensity: form.intensity || null,
        rest_seconds: form.rest_seconds || null,
        notes: form.notes || null,
        performed_at: form.performed_at
      })
      .eq('id', workout.id);

    if (updateError) {
      error = updateError.message;
    } else {
      goto('/workouts');
    }

    saving = false;
  }

  async function deleteWorkout() {
    if (!workout || !confirm('¿Eliminar este registro?')) return;

    await supabase.from('workout_logs').delete().eq('id', workout.id);
    goto('/workouts');
  }
</script>

<div class="page">
  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else if workout}
    <header class="page-header">
      <a href="/workouts" class="btn btn-sm btn-secondary">← Volver</a>
      <h1>Editar Registro</h1>
    </header>

    <div class="exercise-info card">
      <div class="exercise-name">{workout.exercise.name}</div>
      {#if workout.exercise.description}
        <div class="exercise-description">{workout.exercise.description}</div>
      {/if}
      <div class="exercise-tags">
        {#if workout.exercise.muscle_group}
          <span class="tag-small">{muscleGroups.find(m => m.value === workout.exercise.muscle_group)?.label}</span>
        {/if}
        {#if workout.exercise.is_unilateral}
          <span class="tag-small">↔️ Unilateral</span>
        {/if}
      </div>
    </div>

    {#if error}
      <div class="message message-error">{error}</div>
    {/if}

    <div class="card">
      <div class="form-row">
        <div class="form-group">
          <label class="form-label">Fecha</label>
          <input type="date" class="form-input" bind:value={form.performed_at} />
        </div>
        <div class="form-group">
          <label class="form-label">Intensidad</label>
          <select class="form-select" bind:value={form.intensity}>
            <option value="">-</option>
            {#each intensities as int}
              <option value={int.name}>{int.name}</option>
            {/each}
          </select>
        </div>
      </div>

      <div class="form-group">
        <label class="form-label">Series</label>
        {#each form.sets as set, i}
          <div class="set-card">
            <div class="set-header">
              <span class="set-number">Serie {i + 1}</span>
              <button class="btn btn-sm btn-danger" on:click={() => removeSet(i)} disabled={form.sets.length <= 1}>✕</button>
            </div>
            
            {#if workout.exercise.is_unilateral}
              <div class="set-row-unilateral">
                <div class="side">
                  <span class="side-label">Izq</span>
                  <input type="number" class="set-input" placeholder="Reps" bind:value={set.reps_left} />
                  <input type="number" class="set-input" placeholder="kg" bind:value={set.weight_left} step="0.5" />
                </div>
                <div class="side">
                  <span class="side-label">Der</span>
                  <input type="number" class="set-input" placeholder="Reps" bind:value={set.reps_right} />
                  <input type="number" class="set-input" placeholder="kg" bind:value={set.weight_right} step="0.5" />
                </div>
              </div>
            {:else if workout.exercise.tracking_type === 'time'}
              <div class="set-row">
                <input type="number" class="set-input" placeholder="Segundos" bind:value={set.duration_seconds} />
              </div>
            {:else}
              <div class="set-row">
                <input type="number" class="set-input" placeholder="Reps" bind:value={set.reps} />
                <input type="number" class="set-input" placeholder="kg" bind:value={set.weight} step="0.5" />
                {#if workout.exercise.tracking_type === 'reps_and_time'}
                  <input type="number" class="set-input" placeholder="seg" bind:value={set.duration_seconds} />
                {/if}
              </div>
            {/if}
          </div>
        {/each}
        <button class="btn btn-secondary btn-block" on:click={addSet}>+ Añadir serie</button>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label class="form-label">Descanso (seg)</label>
          <input type="number" class="form-input" bind:value={form.rest_seconds} />
        </div>
      </div>

      <div class="form-group">
        <label class="form-label">Notas</label>
        <textarea class="form-textarea" bind:value={form.notes} rows="3"></textarea>
      </div>

      <div class="button-row">
        <button class="btn btn-danger" on:click={deleteWorkout}>🗑️ Eliminar</button>
        <button class="btn btn-primary" on:click={saveWorkout} disabled={saving}>
          {saving ? 'Guardando...' : '✓ Guardar cambios'}
        </button>
      </div>
    </div>
  {/if}
</div>

<style>
  .page-header {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .page-header h1 {
    margin: 0;
    font-size: 1.25rem;
  }

  .exercise-info {
    margin-bottom: 1rem;
  }

  .exercise-name {
    font-weight: 600;
    font-size: 1.1rem;
  }

  .exercise-description {
    color: var(--color-text-muted);
    font-size: 0.9rem;
    margin-top: 0.25rem;
  }

  .exercise-tags {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }

  .tag-small {
    font-size: 0.75rem;
    padding: 0.2rem 0.5rem;
    background: var(--color-bg-input);
    border-radius: 4px;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }

  .set-card {
    background: var(--color-bg-input);
    border-radius: var(--radius-sm);
    padding: 0.75rem;
    margin-bottom: 0.5rem;
  }

  .set-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
  }

  .set-number {
    font-weight: 600;
    color: var(--color-text-muted);
  }

  .set-row {
    display: flex;
    gap: 0.5rem;
  }

  .set-row-unilateral {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }

  .side {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .side-label {
    font-size: 0.8rem;
    color: var(--color-text-muted);
  }

  .set-input {
    flex: 1;
    padding: 0.5rem;
    background: var(--color-bg);
    border: 1px solid var(--color-border);
    border-radius: 4px;
    color: var(--color-text);
    text-align: center;
  }

  .button-row {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
    margin-top: 1rem;
  }
</style>
