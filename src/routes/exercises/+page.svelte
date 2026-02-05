<script lang="ts">
  import { onMount } from 'svelte';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Exercise, muscleGroups } from '$lib/supabase';

  let exercises: Exercise[] = [];
  let loading = true;
  let showForm = false;
  let searchQuery = '';
  let selectedMuscle = '';

  let newExercise = {
    name: '',
    muscle_group: '',
    description: ''
  };

  onMount(async () => {
    await loadExercises();
  });

  async function loadExercises() {
    const { data } = await supabase
      .from('exercises')
      .select('*')
      .order('name');
    
    exercises = data || [];
    loading = false;
  }

  let formError = '';

  async function createExercise() {
    if (!newExercise.name || !$auth.user) return;
    
    formError = '';

    const { error } = await supabase.from('exercises').insert({
      name: newExercise.name,
      muscle_group: newExercise.muscle_group || null,
      description: newExercise.description || null,
      created_by: $auth.user.id
    });

    if (error) {
      formError = `Error: ${error.message} (${error.code})`;
      console.error('Supabase error:', error);
    } else {
      newExercise = { name: '', muscle_group: '', description: '' };
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
      <div class="form-group">
        <label class="form-label">Nombre</label>
        <input type="text" class="form-input" bind:value={newExercise.name} placeholder="Ej: Press banca" />
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
            <div class="exercise-name">{exercise.name}</div>
            <div class="exercise-meta">
              {#if exercise.muscle_group}
                <span class="badge badge-secondary">
                  {muscleGroups.find(m => m.value === exercise.muscle_group)?.label}
                </span>
              {/if}
              {#if exercise.description}
                <span class="exercise-desc">{exercise.description}</span>
              {/if}
            </div>
          </div>
          {#if exercise.created_by === $auth.user?.id}
            <button class="btn btn-sm btn-danger" on:click={() => deleteExercise(exercise.id)}>🗑️</button>
          {/if}
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
</style>
