<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Exercise, type Methodology, muscleGroups } from '$lib/supabase';

  let exercises: Exercise[] = [];
  let recentExercises: Exercise[] = [];
  let methodologies: Methodology[] = [];
  let filteredExercises: Exercise[] = [];
  let selectedExercise: Exercise | null = null;
  let searchQuery = '';
  let selectedMuscle = '';
  let loading = true;
  let saving = false;
  let showRecent = true;

  // Workout data
  let sets: any[] = [];
  let methodology = '';
  let methodologySearch = '';
  let showMethodologySuggestions = false;
  let notes = '';
  let performedAt = new Date().toISOString().split('T')[0];

  onMount(async () => {
    // Load exercises
    const { data: exerciseData } = await supabase
      .from('exercises')
      .select('*')
      .order('name');
    
    exercises = exerciseData || [];
    filteredExercises = exercises;

    // Load recent exercises (from user's workout logs)
    const { data: recentData } = await supabase
      .from('workout_logs')
      .select('exercise_id, exercises(*)')
      .eq('user_id', $auth.user?.id)
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (recentData) {
      const seen = new Set();
      recentExercises = recentData
        .map(w => w.exercises as Exercise)
        .filter(e => e && !seen.has(e.id) && seen.add(e.id))
        .slice(0, 5);
    }

    // Load methodologies
    const { data: methData } = await supabase
      .from('methodologies')
      .select('*')
      .order('name');
    
    methodologies = methData || [];
    
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
    // Initialize sets based on exercise type
    sets = [createEmptySet(exercise)];
  }

  function createEmptySet(exercise: Exercise) {
    const set: any = { unit: 'kg' };
    
    if (exercise.tracking_type === 'time' || exercise.tracking_type === 'reps_and_time') {
      set.duration_seconds = 0;
    }
    
    if (exercise.tracking_type === 'reps' || exercise.tracking_type === 'reps_and_time') {
      if (exercise.is_unilateral) {
        set.reps_left = 0;
        set.reps_right = 0;
        set.weight_left = 0;
        set.weight_right = 0;
      } else {
        set.reps = 0;
        set.weight = 0;
      }
    }
    
    return set;
  }

  function addSet() {
    if (!selectedExercise) return;
    const lastSet = sets[sets.length - 1];
    sets = [...sets, { ...lastSet }];
  }

  function removeSet(index: number) {
    if (sets.length > 1) {
      sets = sets.filter((_, i) => i !== index);
    }
  }

  function filterMethodologies() {
    if (!methodologySearch) {
      showMethodologySuggestions = false;
      return [];
    }
    return methodologies.filter(m => 
      m.name.toLowerCase().includes(methodologySearch.toLowerCase())
    ).slice(0, 5);
  }

  function selectMethodology(name: string) {
    methodology = name;
    methodologySearch = name;
    showMethodologySuggestions = false;
  }

  async function saveWorkout() {
    if (!selectedExercise || !$auth.user) return;

    saving = true;

    const { error } = await supabase.from('workout_logs').insert({
      user_id: $auth.user.id,
      exercise_id: selectedExercise.id,
      performed_at: performedAt,
      sets: sets.filter(s => {
        // Filter out empty sets
        if (selectedExercise?.is_unilateral) {
          return (s.reps_left > 0 || s.reps_right > 0 || s.duration_seconds > 0);
        }
        return (s.reps > 0 || s.duration_seconds > 0);
      }),
      methodology: methodology || null,
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

  $: filteredMethodologies = filterMethodologies();
</script>

<div class="page">
  {#if !selectedExercise}
    <header class="page-header">
      <h1>Registrar entreno</h1>
      <a href="/workouts" class="btn btn-sm btn-secondary">Cancelar</a>
    </header>

    <!-- Recent exercises -->
    {#if recentExercises.length > 0 && showRecent}
      <div class="recent-section">
        <div class="section-header">
          <h3>⏱️ Recientes</h3>
          <button class="btn-link" on:click={() => showRecent = false}>Ocultar</button>
        </div>
        <div class="recent-grid">
          {#each recentExercises as exercise}
            <button class="recent-item" on:click={() => selectExercise(exercise)}>
              {exercise.name}
            </button>
          {/each}
        </div>
      </div>
    {/if}

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
        <p>No hay ejercicios. <a href="/exercises?new=true">Crea uno</a></p>
      </div>
    {:else}
      <ul class="list">
        {#each filteredExercises as exercise}
          <button class="list-item" on:click={() => selectExercise(exercise)}>
            <div>
              <div class="exercise-name">{exercise.name}</div>
              <div class="exercise-muscle">
                {muscleGroups.find(m => m.value === exercise.muscle_group)?.label || ''}
                {#if exercise.is_unilateral}
                  <span class="tag-small">↔️ Unilateral</span>
                {/if}
              </div>
            </div>
            <span>→</span>
          </button>
        {/each}
      </ul>
    {/if}

  {:else}
    <header class="page-header">
      <button class="btn btn-sm btn-secondary" on:click={() => selectedExercise = null}>← Atrás</button>
      <h1>{selectedExercise.name}</h1>
    </header>

    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Fecha</label>
        <input type="date" class="form-input" bind:value={performedAt} />
      </div>
      <div class="form-group methodology-container">
        <label class="form-label">Metodología</label>
        <input 
          type="text" 
          class="form-input" 
          placeholder="Ej: Fuerza, Tabata..."
          bind:value={methodologySearch}
          on:input={() => { methodology = methodologySearch; showMethodologySuggestions = true; }}
          on:focus={() => showMethodologySuggestions = true}
          on:blur={() => setTimeout(() => showMethodologySuggestions = false, 200)}
        />
        {#if showMethodologySuggestions && filteredMethodologies.length > 0}
          <div class="suggestions-dropdown">
            {#each filteredMethodologies as meth}
              <button class="suggestion-item" on:mousedown={() => selectMethodology(meth.name)}>
                {meth.name}
              </button>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <div class="form-group">
      <label class="form-label">Series</label>
      {#each sets as set, i}
        <div class="set-card">
          <div class="set-header">
            <span class="set-number">Serie {i + 1}</span>
            <button class="btn btn-sm btn-danger" on:click={() => removeSet(i)}>✕</button>
          </div>
          
          {#if selectedExercise.is_unilateral}
            <!-- Unilateral: Left/Right -->
            <div class="set-row-unilateral">
              <div class="side-group">
                <span class="side-label">🦵 Izq</span>
                {#if selectedExercise.tracking_type !== 'time'}
                  <input type="number" class="set-input" placeholder="Reps" bind:value={set.reps_left} />
                  <input type="number" class="set-input" placeholder="Peso" bind:value={set.weight_left} step="0.5" />
                {/if}
              </div>
              <div class="side-group">
                <span class="side-label">🦵 Der</span>
                {#if selectedExercise.tracking_type !== 'time'}
                  <input type="number" class="set-input" placeholder="Reps" bind:value={set.reps_right} />
                  <input type="number" class="set-input" placeholder="Peso" bind:value={set.weight_right} step="0.5" />
                {/if}
              </div>
            </div>
          {:else}
            <!-- Bilateral: Normal -->
            {#if selectedExercise.tracking_type !== 'time'}
              <div class="set-row">
                <input type="number" class="set-input" placeholder="Reps" bind:value={set.reps} />
                <input type="number" class="set-input" placeholder="Peso (kg)" bind:value={set.weight} step="0.5" />
                <input type="number" class="set-input small" placeholder="Discos" bind:value={set.plates} />
              </div>
            {/if}
          {/if}

          {#if selectedExercise.tracking_type === 'time' || selectedExercise.tracking_type === 'reps_and_time'}
            <div class="set-row">
              <label class="inline-label">⏱️ Segundos:</label>
              <input type="number" class="set-input" placeholder="Segundos" bind:value={set.duration_seconds} />
            </div>
          {/if}
        </div>
      {/each}
      <button class="btn btn-secondary btn-block" on:click={addSet}>+ Añadir serie</button>
    </div>

    <div class="form-group">
      <label class="form-label">Notas (opcional)</label>
      <textarea class="form-textarea" bind:value={notes} placeholder="RPE, sensaciones, observaciones..."></textarea>
    </div>

    <button 
      class="btn btn-primary btn-block" 
      on:click={saveWorkout}
      disabled={saving}
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

  .list-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    gap: 1rem;
    padding: 1rem;
    background: var(--color-bg-card);
    border: none;
    border-radius: var(--radius-sm);
    margin-bottom: 0.5rem;
    cursor: pointer;
    text-align: left;
    color: var(--color-text);
    transition: background 0.2s;
  }

  .list-item:hover {
    background: var(--color-bg-input);
  }

  .exercise-name {
    font-weight: 500;
  }

  .exercise-muscle {
    color: var(--color-text-muted);
    font-size: 0.875rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .tag-small {
    font-size: 0.7rem;
    padding: 0.1rem 0.3rem;
    background: var(--color-bg-input);
    border-radius: 4px;
  }

  .recent-section {
    margin-bottom: 1.5rem;
  }

  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
  }

  .section-header h3 {
    margin: 0;
    font-size: 1rem;
    color: var(--color-text-muted);
  }

  .btn-link {
    background: none;
    border: none;
    color: var(--color-primary);
    cursor: pointer;
    font-size: 0.875rem;
  }

  .recent-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .recent-item {
    padding: 0.5rem 1rem;
    background: var(--color-bg-card);
    border: 1px solid var(--color-border);
    border-radius: var(--radius);
    color: var(--color-text);
    cursor: pointer;
    font-size: 0.9rem;
    transition: all 0.2s;
  }

  .recent-item:hover {
    background: var(--color-primary);
    border-color: var(--color-primary);
  }

  .methodology-container {
    position: relative;
  }

  .suggestions-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: var(--color-bg-card);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-sm);
    z-index: 10;
    max-height: 200px;
    overflow-y: auto;
  }

  .suggestion-item {
    display: block;
    width: 100%;
    padding: 0.75rem 1rem;
    text-align: left;
    background: none;
    border: none;
    color: var(--color-text);
    cursor: pointer;
  }

  .suggestion-item:hover {
    background: var(--color-bg-input);
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
    align-items: center;
  }

  .set-row-unilateral {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }

  .side-group {
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
    font-size: 1rem;
    text-align: center;
  }

  .set-input.small {
    max-width: 4rem;
  }

  .inline-label {
    font-size: 0.9rem;
    color: var(--color-text-muted);
    white-space: nowrap;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }
</style>
