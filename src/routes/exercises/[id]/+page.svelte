<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Exercise, muscleGroups, trackingTypes } from '$lib/supabase';

  let exercise: Exercise | null = null;
  let loading = true;
  let saving = false;
  let error = '';

  let form = {
    name: '',
    muscle_group: '',
    description: '',
    is_unilateral: false,
    tracking_type: 'reps'
  };

  onMount(async () => {
    const { data, error: fetchError } = await supabase
      .from('exercises')
      .select('*')
      .eq('id', $page.params.id)
      .single();

    if (fetchError || !data) {
      goto('/exercises');
      return;
    }

    exercise = data;
    form = {
      name: data.name,
      muscle_group: data.muscle_group || '',
      description: data.description || '',
      is_unilateral: data.is_unilateral || false,
      tracking_type: data.tracking_type || 'reps'
    };
    loading = false;
  });

  async function saveExercise() {
    if (!form.name || !exercise) return;

    saving = true;
    error = '';

    const { error: updateError } = await supabase
      .from('exercises')
      .update({
        name: form.name,
        muscle_group: form.muscle_group || null,
        description: form.description || null,
        is_unilateral: form.is_unilateral,
        tracking_type: form.tracking_type
      })
      .eq('id', exercise.id);

    if (updateError) {
      error = updateError.message;
    } else {
      goto('/exercises');
    }

    saving = false;
  }

  async function deleteExercise() {
    if (!exercise || !confirm('¿Eliminar este ejercicio? Se perderán todos los registros asociados.')) return;

    const { error: deleteError } = await supabase
      .from('exercises')
      .delete()
      .eq('id', exercise.id);

    if (deleteError) {
      error = 'No se puede eliminar: ' + deleteError.message;
    } else {
      goto('/exercises');
    }
  }
</script>

<div class="page">
  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else if exercise}
    <header class="page-header">
      <a href="/exercises" class="btn btn-sm btn-secondary">← Volver</a>
      <h1>Editar Ejercicio</h1>
    </header>

    {#if error}
      <div class="message message-error">{error}</div>
    {/if}

    <div class="card">
      <div class="form-group">
        <label class="form-label">Nombre</label>
        <input type="text" class="form-input" bind:value={form.name} />
      </div>

      <div class="form-group">
        <label class="form-label">Grupo muscular</label>
        <select class="form-select" bind:value={form.muscle_group}>
          <option value="">Seleccionar...</option>
          {#each muscleGroups as group}
            <option value={group.value}>{group.label}</option>
          {/each}
        </select>
      </div>

      <div class="form-group">
        <label class="form-label">Tipo de registro</label>
        <select class="form-select" bind:value={form.tracking_type}>
          {#each trackingTypes as type}
            <option value={type.value}>{type.label}</option>
          {/each}
        </select>
      </div>

      <div class="form-group checkbox-group">
        <label class="checkbox-label">
          <input type="checkbox" bind:checked={form.is_unilateral} />
          <span>Ejercicio unilateral</span>
        </label>
        <span class="checkbox-hint">Registrar izquierda/derecha por separado</span>
      </div>

      <div class="form-group">
        <label class="form-label">Descripción</label>
        <textarea class="form-textarea" bind:value={form.description} rows="4"></textarea>
      </div>

      <div class="button-row">
        <button class="btn btn-danger" on:click={deleteExercise}>🗑️ Eliminar</button>
        <button class="btn btn-primary" on:click={saveExercise} disabled={saving || !form.name}>
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
  }

  .checkbox-hint {
    color: var(--color-text-muted);
    font-size: 0.8rem;
    margin-left: 1.75rem;
  }

  .button-row {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
    margin-top: 1rem;
  }
</style>
