<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Exercise, muscleGroups, trackingTypes } from '$lib/supabase';

  let exercises: Exercise[] = [];
  let loading = true;
  let showForm = false;
  let searchQuery = '';
  let selectedMuscle = '';
  let formError = '';

  // Autocomplete state
  let showSuggestions = false;
  let suggestions: string[] = [];

  // Auto-open form if ?new=true in URL
  $: if ($page.url.searchParams.get('new') === 'true') {
    showForm = true;
  }

  let newExercise = {
    name: '',
    muscle_group: '',
    description: '',
    is_unilateral: false,
    tracking_type: 'reps'
  };

  onMount(async () => {
    await loadExercises();
  });

  async function loadExercises() {
    const { data, error } = await supabase
      .from('exercises')
      .select('*')
      .order('name');
    
    if (error) {
      console.error('Load error:', error);
    }
    
    exercises = data || [];
    loading = false;
  }

  // Autocomplete for exercise name
  function updateSuggestions() {
    if (newExercise.name.length < 2) {
      suggestions = [];
      showSuggestions = false;
      return;
    }

    const query = newExercise.name.toLowerCase();
    suggestions = exercises
      .map(e => e.name)
      .filter(name => name.toLowerCase().includes(query))
      .slice(0, 5);
    
    showSuggestions = suggestions.length > 0;
  }

  function selectSuggestion(name: string) {
    newExercise.name = name;
    showSuggestions = false;
  }

  async function createExercise() {
    formError = '';
    
    if (!$auth.user) {
      formError = 'Error: No has iniciado sesión';
      return;
    }
    
    if (!newExercise.name) {
      formError = 'Error: El nombre es obligatorio';
      return;
    }

    const payload = {
      name: newExercise.name,
      muscle_group: newExercise.muscle_group || null,
      description: newExercise.description || null,
      is_unilateral: newExercise.is_unilateral,
      tracking_type: newExercise.tracking_type,
      created_by: $auth.user.id
    };

    const { error } = await supabase
      .from('exercises')
      .insert(payload)
      .select();

    if (error) {
      formError = `Error: ${error.message}`;
      console.error('Supabase error:', error);
    } else {
      newExercise = { name: '', muscle_group: '', description: '', is_unilateral: false, tracking_type: 'reps' };
      showForm = false;
      await loadExercises();
    }
  }

  async function deleteExercise(id: string) {
    if (!confirm('¿Eliminar este ejercicio?')) return;
    
    const { error } = await supabase.from('exercises').delete().eq('id', id);
    if (!error) {
      exercises = exercises.filter(e => e.id !== id);
    } else {
      alert('No se puede eliminar: tiene registros asociados');
    }
  }

  $: filteredExercises = exercises.filter(ex => {
    const matchesSearch = !searchQuery || 
      ex.name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesMuscle = !selectedMuscle || 
      ex.muscle_group === selectedMuscle;
    return matchesSearch && matchesMuscle;
  });
</script>

<div class="page">
  <header class="page-header">
    <h1>Ejercicios</h1>
    <button class="btn btn-primary btn-sm" on:click={() => showForm = !showForm}>
      {showForm ? '✕' : '+ Nuevo'}
    </button>
  </header>

  {#if showForm}
    <div class="card form-card">
      {#if formError}
        <div class="message message-error">{formError}</div>
      {/if}
      
      <div class="form-group autocomplete-container">
        <label class="form-label">Nombre</label>
        <input 
          type="text" 
          class="form-input" 
          bind:value={newExercise.name} 
          on:input={updateSuggestions}
          on:focus={updateSuggestions}
          on:blur={() => setTimeout(() => showSuggestions = false, 200)}
          placeholder="Ej: Arnold press, Sentadilla búlgara..." 
        />
        {#if showSuggestions}
          <div class="suggestions-dropdown">
            {#each suggestions as suggestion}
              <button class="suggestion-item" on:mousedown={() => selectSuggestion(suggestion)}>
                {suggestion}
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div class="form-group">
        <label class="form-label">Grupo muscular</label>
        <select class="form-select" bind:value={newExercise.muscle_group}>
          <option value="">Seleccionar...</option>
          {#each muscleGroups as group}
            <option value={group.value}>{group.label}</option>
          {/each}
        </select>
      </div>

      <div class="form-group">
        <label class="form-label">Tipo de registro</label>
        <select class="form-select" bind:value={newExercise.tracking_type}>
          {#each trackingTypes as type}
            <option value={type.value}>{type.label}</option>
          {/each}
        </select>
      </div>

      <div class="form-group checkbox-group">
        <label class="checkbox-label">
          <input type="checkbox" bind:checked={newExercise.is_unilateral} />
          <span>Ejercicio unilateral</span>
        </label>
        <span class="checkbox-hint">Registrar izquierda/derecha por separado</span>
      </div>

      <div class="form-group">
        <label class="form-label">Descripción (opcional)</label>
        <textarea class="form-textarea" bind:value={newExercise.description} placeholder="Notas sobre la técnica..."></textarea>
      </div>

      <button class="btn btn-primary btn-block" on:click={createExercise} disabled={!newExercise.name}>
        Crear ejercicio
      </button>
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
    <button class="tag" class:active={selectedMuscle === ''} on:click={() => selectedMuscle = ''}>
      Todos
    </button>
    {#each muscleGroups as group}
      <button class="tag" class:active={selectedMuscle === group.value} on:click={() => selectedMuscle = group.value}>
        {group.label}
      </button>
    {/each}
  </div>

  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else if filteredExercises.length === 0}
    <div class="empty-state">
      <div class="empty-state-icon">🏋️</div>
      <p>No hay ejercicios. ¡Crea el primero!</p>
    </div>
  {:else}
    <ul class="list">
      {#each filteredExercises as exercise}
        <li class="list-item exercise-item">
          <div class="exercise-info">
            <div class="exercise-name">
              {exercise.name}
              {#if exercise.is_unilateral}
                <span class="badge badge-small">↔️ Unilateral</span>
              {/if}
            </div>
            <div class="exercise-meta">
              {#if exercise.muscle_group}
                <span class="badge badge-secondary">
                  {muscleGroups.find(m => m.value === exercise.muscle_group)?.label}
                </span>
              {/if}
              {#if exercise.tracking_type && exercise.tracking_type !== 'reps'}
                <span class="badge badge-secondary">
                  {trackingTypes.find(t => t.value === exercise.tracking_type)?.label}
                </span>
              {/if}
            </div>
          </div>
          <div class="exercise-actions">
            <a href="/exercises/{exercise.id}" class="btn btn-sm btn-secondary">✏️</a>
            {#if exercise.created_by === $auth.user?.id}
              <button class="btn btn-sm btn-danger" on:click={() => deleteExercise(exercise.id)}>🗑️</button>
            {/if}
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .form-card {
    margin-bottom: 1rem;
  }

  .tags {
    margin: 1rem 0;
  }

  .exercise-item {
    flex-direction: row;
    justify-content: space-between;
  }

  .exercise-info {
    flex: 1;
  }

  .exercise-name {
    font-weight: 500;
    margin-bottom: 0.25rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .exercise-meta {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .exercise-desc {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }

  .autocomplete-container {
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

  .checkbox-group {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
  }

  .checkbox-label input {
    width: 1.25rem;
    height: 1.25rem;
    accent-color: var(--color-primary);
  }

  .checkbox-hint {
    color: var(--color-text-muted);
    font-size: 0.8rem;
    margin-left: 1.75rem;
  }

  .badge-small {
    font-size: 0.7rem;
    padding: 0.15rem 0.4rem;
    background: var(--color-bg-input);
  }

  .exercise-actions {
    display: flex;
    gap: 0.25rem;
  }
</style>
