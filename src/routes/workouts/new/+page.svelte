<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Exercise, muscleGroups } from '$lib/supabase';

  let exercises: Exercise[] = [];
  let filteredExercises: Exercise[] = [];
  let selectedExercise: Exercise | null = null;
  let searchQuery = '';
  let selectedMuscle = '';
  let loading = true;
  let saving = false;

  let sets: { reps: number; weight: number; unit: string }[] = [
    { reps: 10, weight: 0, unit: 'kg' }
  ];
  let notes = '';
  let performedAt = new Date().toISOString().split('T')[0];

  onMount(async () => {
    const { data } = await supabase
      .from('exercises')
      .select('*')
      .order('name');
    
    exercises = data || [];
    filteredExercises = exercises;
    loading = false;
  });

  function filterExercises() {
    filteredExercises = exercises.filter(ex => {
      const matchesSearch = !searchQuery || 
        ex.name.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesMuscle = !selectedMuscle || 
        ex.muscle_group === selectedMuscle;
      return matchesSearch && matchesMuscle;
    });
  }

  function selectExercise(exercise: Exercise) {
    selectedExercise = exercise;
  }

  function addSet() {
    const lastSet = sets[sets.length - 1];
    sets = [...sets, { ...lastSet }];
  }

  function removeSet(index: number) {
    if (sets.length > 1) {
      sets = sets.filter((_, i) => i !== index);
    }
  }

  async function saveWorkout() {
    if (!selectedExercise || !$auth.user) return;

    saving = true;

    const { error } = await supabase.from('workout_logs').insert({
      user_id: $auth.user.id,
      exercise_id: selectedExercise.id,
      performed_at: performedAt,
      sets: sets.filter(s => s.reps > 0),
      notes: notes || null
    });

    if (!error) {
      goto('/workouts');
    } else {
      alert('Error al guardar: ' + error.message);
    }

    saving = false;
  }

  $: {
    searchQuery;
    selectedMuscle;
    filterExercises();
  }
</script>

<div class="page">
  {#if !selectedExercise}
    <header class="page-header">
      <h1>Selecciona ejercicio</h1>
      <a href="/workouts" class="btn btn-sm btn-secondary">Cancelar</a>
    </header>

    <div class="search-box">
      <span class="search-icon">🔍</span>
      <input 
        type="text" 
        class="search-input" 
        placeholder="Buscar ejercicio..."
        bind:value={searchQuery}
      />
    </div>

    <div class="tags">
      <button 
        class="tag" 
        class:active={selectedMuscle === ''}
        on:click={() => selectedMuscle = ''}
      >
        Todos
      </button>
      {#each muscleGroups as group}
        <button 
          class="tag" 
          class:active={selectedMuscle === group.value}
          on:click={() => selectedMuscle = group.value}
        >
          {group.label}
        </button>
      {/each}
    </div>

    {#if loading}
      <div class="loading"><div class="spinner"></div></div>
    {:else if filteredExercises.length === 0}
      <div class="empty-state">
        <p>No hay ejercicios. <a href="/exercises/new">Crea uno</a></p>
      </div>
    {:else}
      <ul class="list">
        {#each filteredExercises as exercise}
          <li class="list-item" on:click={() => selectExercise(exercise)}>
            <div>
              <div class="exercise-name">{exercise.name}</div>
              <div class="exercise-muscle">{muscleGroups.find(m => m.value === exercise.muscle_group)?.label || ''}</div>
            </div>
            <span>→</span>
          </li>
        {/each}
      </ul>
    {/if}

  {:else}
    <header class="page-header">
      <button class="btn btn-sm btn-secondary" on:click={() => selectedExercise = null}>← Atrás</button>
      <h1>{selectedExercise.name}</h1>
    </header>

    <div class="form-group">
      <label class="form-label">Fecha</label>
      <input type="date" class="form-input" bind:value={performedAt} />
    </div>

    <div class="form-group">
      <label class="form-label">Series</label>
      {#each sets as set, i}
        <div class="set-row">
          <span class="set-number">{i + 1}</span>
          <input 
            type="number" 
            class="set-input" 
            placeholder="Reps"
            bind:value={set.reps}
          />
          <input 
            type="number" 
            class="set-input" 
            placeholder="Peso"
            bind:value={set.weight}
            step="0.5"
          />
          <button class="btn btn-sm btn-danger" on:click={() => removeSet(i)}>✕</button>
        </div>
      {/each}
      <button class="btn btn-secondary btn-block" on:click={addSet}>+ Añadir serie</button>
    </div>

    <div class="form-group">
      <label class="form-label">Notas (opcional)</label>
      <textarea class="form-textarea" bind:value={notes} placeholder="RPE, sensaciones..."></textarea>
    </div>

    <button 
      class="btn btn-primary btn-block" 
      on:click={saveWorkout}
      disabled={saving || sets.every(s => s.reps === 0)}
    >
      {saving ? 'Guardando...' : '✓ Guardar entreno'}
    </button>
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

  .tags {
    margin: 1rem 0;
  }

  .exercise-name {
    font-weight: 500;
  }

  .exercise-muscle {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }
</style>
