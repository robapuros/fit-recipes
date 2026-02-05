<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Exercise, type Methodology, type Intensity, muscleGroups } from '$lib/supabase';

  // Data
  let exercises: Exercise[] = [];
  let recentExercises: Exercise[] = [];
  let methodologies: Methodology[] = [];
  let intensities: Intensity[] = [];
  let loading = true;
  let saving = false;

  // Workout session data
  let performedAt = new Date().toISOString().split('T')[0];
  let methodology = '';
  let methodologySearch = '';
  let sessionNotes = '';

  // Current workout items (multiple exercises)
  interface WorkoutItem {
    exercise: Exercise;
    sets: any[];
    intensity: string;
    restSeconds: number;
    notes: string;
  }
  let workoutItems: WorkoutItem[] = [];

  // UI state
  let showExerciseSelector = false;
  let searchQuery = '';
  let selectedMuscle = '';
  let editingItemIndex: number | null = null;
  let showMethodologySuggestions = false;

  onMount(async () => {
    // Load exercises
    const { data: exerciseData } = await supabase
      .from('exercises')
      .select('*')
      .order('name');
    exercises = exerciseData || [];

    // Load recent exercises
    const { data: recentData } = await supabase
      .from('workout_logs')
      .select('exercise_id, exercises(*)')
      .eq('user_id', $auth.user?.id)
      .order('created_at', { ascending: false })
      .limit(20);
    
    if (recentData) {
      const seen = new Set();
      recentExercises = recentData
        .map(w => w.exercises as Exercise)
        .filter(e => e && !seen.has(e.id) && seen.add(e.id))
        .slice(0, 8);
    }

    // Load methodologies
    const { data: methData } = await supabase
      .from('methodologies')
      .select('*')
      .order('name');
    methodologies = methData || [];

    // Load intensities
    const { data: intData } = await supabase
      .from('intensities')
      .select('*')
      .order('name');
    intensities = intData || [];

    loading = false;
  });

  function addExercise(exercise: Exercise) {
    const newItem: WorkoutItem = {
      exercise,
      sets: [createEmptySet(exercise)],
      intensity: '',
      restSeconds: 60,
      notes: ''
    };
    workoutItems = [...workoutItems, newItem];
    showExerciseSelector = false;
    searchQuery = '';
  }

  function createEmptySet(exercise: Exercise) {
    const set: any = { unit: 'kg' };
    
    if (exercise.tracking_type === 'time' || exercise.tracking_type === 'reps_and_time') {
      set.duration_seconds = 0;
    }
    
    if (exercise.tracking_type !== 'time') {
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

  function removeItem(index: number) {
    workoutItems = workoutItems.filter((_, i) => i !== index);
  }

  function moveItem(index: number, direction: 'up' | 'down') {
    const newIndex = direction === 'up' ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= workoutItems.length) return;
    
    const items = [...workoutItems];
    [items[index], items[newIndex]] = [items[newIndex], items[index]];
    workoutItems = items;
  }

  function addSet(itemIndex: number) {
    const item = workoutItems[itemIndex];
    const lastSet = item.sets[item.sets.length - 1];
    item.sets = [...item.sets, { ...lastSet }];
    workoutItems = [...workoutItems];
  }

  function removeSet(itemIndex: number, setIndex: number) {
    const item = workoutItems[itemIndex];
    if (item.sets.length > 1) {
      item.sets = item.sets.filter((_, i) => i !== setIndex);
      workoutItems = [...workoutItems];
    }
  }

  $: filteredExercises = exercises.filter(ex => {
    const matchesSearch = !searchQuery || 
      ex.name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesMuscle = !selectedMuscle || 
      ex.muscle_group === selectedMuscle;
    return matchesSearch && matchesMuscle;
  });

  $: filteredMethodologies = methodologySearch 
    ? methodologies.filter(m => m.name.toLowerCase().includes(methodologySearch.toLowerCase())).slice(0, 5)
    : [];

  async function saveWorkout() {
    if (workoutItems.length === 0 || !$auth.user) return;

    saving = true;

    // Create workout logs for each exercise
    const logs = workoutItems.map((item, index) => ({
      user_id: $auth.user!.id,
      exercise_id: item.exercise.id,
      performed_at: performedAt,
      sets: item.sets.filter(s => {
        if (item.exercise.is_unilateral) {
          return (s.reps_left > 0 || s.reps_right > 0 || s.duration_seconds > 0);
        }
        return (s.reps > 0 || s.duration_seconds > 0);
      }),
      methodology: methodology || null,
      intensity: item.intensity || null,
      rest_seconds: item.restSeconds || null,
      order: index,
      notes: item.notes || null
    }));

    const { error } = await supabase.from('workout_logs').insert(logs);

    if (!error) {
      goto('/workouts');
    } else {
      alert('Error al guardar: ' + error.message);
    }

    saving = false;
  }
</script>

<div class="page">
  <header class="page-header">
    <h1>Nuevo Entreno</h1>
    <a href="/workouts" class="btn btn-sm btn-secondary">Cancelar</a>
  </header>

  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else}
    <!-- Session info -->
    <div class="session-info card">
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
                <button class="suggestion-item" on:mousedown={() => { methodology = meth.name; methodologySearch = meth.name; showMethodologySuggestions = false; }}>
                  {meth.name}
                </button>
              {/each}
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Workout items list -->
    {#if workoutItems.length > 0}
      <div class="workout-items">
        {#each workoutItems as item, itemIndex}
          <div class="workout-item card">
            <div class="item-header">
              <div class="item-order">
                <button class="order-btn" on:click={() => moveItem(itemIndex, 'up')} disabled={itemIndex === 0}>↑</button>
                <span class="order-number">{itemIndex + 1}</span>
                <button class="order-btn" on:click={() => moveItem(itemIndex, 'down')} disabled={itemIndex === workoutItems.length - 1}>↓</button>
              </div>
              <div class="item-info">
                <div class="item-name">{item.exercise.name}</div>
                {#if item.exercise.description}
                  <div class="item-description">{item.exercise.description}</div>
                {/if}
                <div class="item-tags">
                  {#if item.exercise.is_unilateral}
                    <span class="tag-small">↔️ Unilateral</span>
                  {/if}
                  {#if item.exercise.muscle_group}
                    <span class="tag-small">{muscleGroups.find(m => m.value === item.exercise.muscle_group)?.label}</span>
                  {/if}
                </div>
              </div>
              <button class="btn btn-sm btn-danger" on:click={() => removeItem(itemIndex)}>🗑️</button>
            </div>

            <!-- Sets -->
            <div class="sets-section">
              {#each item.sets as set, setIndex}
                <div class="set-row-container">
                  <span class="set-label">S{setIndex + 1}</span>
                  
                  {#if item.exercise.is_unilateral}
                    <div class="set-inputs unilateral">
                      <div class="side">
                        <span class="side-label">Izq</span>
                        <input type="number" class="set-input" placeholder="R" bind:value={set.reps_left} />
                        <input type="number" class="set-input" placeholder="kg" bind:value={set.weight_left} step="0.5" />
                      </div>
                      <div class="side">
                        <span class="side-label">Der</span>
                        <input type="number" class="set-input" placeholder="R" bind:value={set.reps_right} />
                        <input type="number" class="set-input" placeholder="kg" bind:value={set.weight_right} step="0.5" />
                      </div>
                    </div>
                  {:else if item.exercise.tracking_type === 'time'}
                    <div class="set-inputs">
                      <input type="number" class="set-input" placeholder="Segundos" bind:value={set.duration_seconds} />
                    </div>
                  {:else}
                    <div class="set-inputs">
                      <input type="number" class="set-input" placeholder="Reps" bind:value={set.reps} />
                      <input type="number" class="set-input" placeholder="kg" bind:value={set.weight} step="0.5" />
                      {#if item.exercise.tracking_type === 'reps_and_time'}
                        <input type="number" class="set-input" placeholder="seg" bind:value={set.duration_seconds} />
                      {/if}
                    </div>
                  {/if}

                  <button class="btn-icon" on:click={() => removeSet(itemIndex, setIndex)} disabled={item.sets.length <= 1}>✕</button>
                </div>
              {/each}
              <button class="btn btn-sm btn-secondary" on:click={() => addSet(itemIndex)}>+ Serie</button>
            </div>

            <!-- Intensity and Rest -->
            <div class="item-footer">
              <div class="form-group compact">
                <label class="form-label-small">Intensidad</label>
                <select class="form-select-small" bind:value={item.intensity}>
                  <option value="">-</option>
                  {#each intensities as int}
                    <option value={int.name}>{int.name}</option>
                  {/each}
                </select>
              </div>
              <div class="form-group compact">
                <label class="form-label-small">Descanso</label>
                <div class="rest-input">
                  <input type="number" class="form-input-small" bind:value={item.restSeconds} />
                  <span>seg</span>
                </div>
              </div>
              <div class="form-group compact notes-group">
                <input type="text" class="form-input-small" placeholder="Notas..." bind:value={item.notes} />
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}

    <!-- Add exercise button -->
    {#if !showExerciseSelector}
      <button class="btn btn-primary btn-block add-exercise-btn" on:click={() => showExerciseSelector = true}>
        + Añadir ejercicio
      </button>
    {:else}
      <!-- Exercise selector -->
      <div class="exercise-selector card">
        <div class="selector-header">
          <h3>Seleccionar ejercicio</h3>
          <button class="btn btn-sm btn-secondary" on:click={() => showExerciseSelector = false}>✕</button>
        </div>

        {#if recentExercises.length > 0}
          <div class="recent-section">
            <span class="section-label">Recientes:</span>
            <div class="recent-chips">
              {#each recentExercises as ex}
                <button class="recent-chip" on:click={() => addExercise(ex)}>{ex.name}</button>
              {/each}
            </div>
          </div>
        {/if}

        <div class="search-box">
          <input type="text" class="search-input" placeholder="Buscar ejercicio..." bind:value={searchQuery} />
        </div>

        <div class="tags compact">
          <button class="tag" class:active={selectedMuscle === ''} on:click={() => selectedMuscle = ''}>Todos</button>
          {#each muscleGroups as group}
            <button class="tag" class:active={selectedMuscle === group.value} on:click={() => selectedMuscle = group.value}>
              {group.label}
            </button>
          {/each}
        </div>

        <div class="exercise-list">
          {#each filteredExercises.slice(0, 10) as exercise}
            <button class="exercise-option" on:click={() => addExercise(exercise)}>
              <div class="exercise-option-name">{exercise.name}</div>
              {#if exercise.description}
                <div class="exercise-option-desc">{exercise.description}</div>
              {/if}
            </button>
          {/each}
          {#if filteredExercises.length === 0}
            <div class="empty-message">No hay ejercicios. <a href="/exercises?new=true">Crear uno</a></div>
          {/if}
        </div>
      </div>
    {/if}

    <!-- Save button -->
    {#if workoutItems.length > 0}
      <button 
        class="btn btn-success btn-block save-btn" 
        on:click={saveWorkout}
        disabled={saving}
      >
        {saving ? 'Guardando...' : `✓ Guardar entreno (${workoutItems.length} ejercicios)`}
      </button>
    {/if}
  {/if}
</div>

<style>
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .session-info {
    margin-bottom: 1rem;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
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
  }

  .suggestion-item {
    display: block;
    width: 100%;
    padding: 0.5rem;
    text-align: left;
    background: none;
    border: none;
    color: var(--color-text);
    cursor: pointer;
  }

  .suggestion-item:hover {
    background: var(--color-bg-input);
  }

  .workout-items {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .workout-item {
    padding: 0.75rem;
  }

  .item-header {
    display: flex;
    gap: 0.75rem;
    align-items: flex-start;
    margin-bottom: 0.75rem;
  }

  .item-order {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
  }

  .order-btn {
    background: var(--color-bg-input);
    border: none;
    color: var(--color-text-muted);
    width: 1.5rem;
    height: 1.5rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.8rem;
  }

  .order-btn:disabled {
    opacity: 0.3;
  }

  .order-number {
    font-weight: bold;
    color: var(--color-primary);
  }

  .item-info {
    flex: 1;
  }

  .item-name {
    font-weight: 600;
    font-size: 1.1rem;
  }

  .item-description {
    color: var(--color-text-muted);
    font-size: 0.85rem;
    margin-top: 0.25rem;
  }

  .item-tags {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.25rem;
  }

  .tag-small {
    font-size: 0.7rem;
    padding: 0.1rem 0.4rem;
    background: var(--color-bg-input);
    border-radius: 4px;
  }

  .sets-section {
    margin-bottom: 0.75rem;
  }

  .set-row-container {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.5rem;
  }

  .set-label {
    font-size: 0.8rem;
    color: var(--color-text-muted);
    min-width: 1.5rem;
  }

  .set-inputs {
    display: flex;
    gap: 0.5rem;
    flex: 1;
  }

  .set-inputs.unilateral {
    flex-direction: column;
    gap: 0.25rem;
  }

  .side {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .side-label {
    font-size: 0.75rem;
    color: var(--color-text-muted);
    min-width: 2rem;
  }

  .set-input {
    width: 4rem;
    padding: 0.4rem;
    background: var(--color-bg);
    border: 1px solid var(--color-border);
    border-radius: 4px;
    color: var(--color-text);
    text-align: center;
    font-size: 0.9rem;
  }

  .btn-icon {
    background: none;
    border: none;
    color: var(--color-text-muted);
    cursor: pointer;
    padding: 0.25rem;
  }

  .btn-icon:disabled {
    opacity: 0.3;
  }

  .item-footer {
    display: flex;
    gap: 0.75rem;
    align-items: flex-end;
    flex-wrap: wrap;
    padding-top: 0.5rem;
    border-top: 1px solid var(--color-border);
  }

  .form-group.compact {
    margin: 0;
  }

  .form-label-small {
    font-size: 0.7rem;
    color: var(--color-text-muted);
    margin-bottom: 0.25rem;
    display: block;
  }

  .form-select-small, .form-input-small {
    padding: 0.4rem;
    background: var(--color-bg);
    border: 1px solid var(--color-border);
    border-radius: 4px;
    color: var(--color-text);
    font-size: 0.85rem;
  }

  .rest-input {
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  .rest-input input {
    width: 3.5rem;
  }

  .rest-input span {
    font-size: 0.8rem;
    color: var(--color-text-muted);
  }

  .notes-group {
    flex: 1;
  }

  .notes-group input {
    width: 100%;
  }

  .add-exercise-btn {
    margin-bottom: 1rem;
  }

  .exercise-selector {
    margin-bottom: 1rem;
  }

  .selector-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.75rem;
  }

  .selector-header h3 {
    margin: 0;
    font-size: 1rem;
  }

  .recent-section {
    margin-bottom: 0.75rem;
  }

  .section-label {
    font-size: 0.8rem;
    color: var(--color-text-muted);
  }

  .recent-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }

  .recent-chip {
    padding: 0.4rem 0.75rem;
    background: var(--color-bg-input);
    border: 1px solid var(--color-border);
    border-radius: 999px;
    color: var(--color-text);
    font-size: 0.85rem;
    cursor: pointer;
  }

  .recent-chip:hover {
    background: var(--color-primary);
    border-color: var(--color-primary);
  }

  .search-box {
    margin-bottom: 0.5rem;
  }

  .search-input {
    width: 100%;
    padding: 0.5rem;
    background: var(--color-bg);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-sm);
    color: var(--color-text);
  }

  .tags.compact {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
    margin-bottom: 0.75rem;
  }

  .tags.compact .tag {
    padding: 0.25rem 0.5rem;
    font-size: 0.8rem;
  }

  .exercise-list {
    max-height: 300px;
    overflow-y: auto;
  }

  .exercise-option {
    display: block;
    width: 100%;
    padding: 0.75rem;
    text-align: left;
    background: none;
    border: none;
    border-bottom: 1px solid var(--color-border);
    color: var(--color-text);
    cursor: pointer;
  }

  .exercise-option:hover {
    background: var(--color-bg-input);
  }

  .exercise-option-name {
    font-weight: 500;
  }

  .exercise-option-desc {
    font-size: 0.8rem;
    color: var(--color-text-muted);
    margin-top: 0.25rem;
  }

  .empty-message {
    padding: 1rem;
    text-align: center;
    color: var(--color-text-muted);
  }

  .save-btn {
    position: sticky;
    bottom: 5rem;
  }

  .tag {
    padding: 0.4rem 0.75rem;
    background: var(--color-bg-input);
    border: none;
    border-radius: 999px;
    color: var(--color-text);
    font-size: 0.85rem;
    cursor: pointer;
  }

  .tag.active {
    background: var(--color-primary);
  }
</style>
