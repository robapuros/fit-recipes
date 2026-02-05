<script lang="ts">
  import { onMount } from 'svelte';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Profile, type WorkoutLog, type Exercise } from '$lib/supabase';

  type WorkoutWithExercise = WorkoutLog & { exercise: Exercise };

  let partner: Profile | null = null;
  let workouts: WorkoutWithExercise[] = [];
  let loading = true;
  let selectedDate = new Date().toISOString().split('T')[0];

  onMount(async () => {
    await loadPartner();
  });

  async function loadPartner() {
    if (!$auth.user) return;

    // Get partner profile
    const { data: profileData } = await supabase
      .from('profiles')
      .select('*')
      .neq('id', $auth.user.id)
      .single();

    partner = profileData;

    if (partner) {
      await loadWorkouts();
    }
    loading = false;
  }

  async function loadWorkouts() {
    if (!partner) return;

    const { data } = await supabase
      .from('workout_logs')
      .select('*, exercise:exercises(*)')
      .eq('user_id', partner.id)
      .eq('performed_at', selectedDate)
      .order('created_at', { ascending: false });

    workouts = data || [];
  }

  function calculateVolume(sets: any[]): number {
    return sets.reduce((total, set) => {
      return total + (set.reps || 0) * (set.weight || 0);
    }, 0);
  }

  $: if (selectedDate && partner) {
    loadWorkouts();
  }
</script>

<div class="page">
  <h1>👀 Entrenos de {partner?.display_name || partner?.username || 'tu pareja'}</h1>

  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else if !partner}
    <div class="empty-state">
      <div class="empty-state-icon">👤</div>
      <p>No hay otro usuario registrado todavía.</p>
    </div>
  {:else}
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

    <div class="notice">
      <span>👁️</span>
      <span>Solo lectura — no puedes modificar los datos de {partner.username}</span>
    </div>

    {#if workouts.length === 0}
      <div class="empty-state">
        <div class="empty-state-icon">🏖️</div>
        <p>{partner.username} no entrenó este día.</p>
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
            </div>
            
            <div class="sets-summary">
              {#each workout.sets as set}
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
              <span>{calculateVolume(workout.sets).toLocaleString()} kg</span>
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
          <div class="stat-label">Volumen</div>
        </div>
      </div>
    {/if}
  {/if}
</div>

<style>
  h1 {
    font-size: 1.5rem;
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

  .notice {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: rgba(99, 102, 241, 0.2);
    border-radius: var(--radius-sm);
    margin-bottom: 1rem;
    font-size: 0.875rem;
    color: var(--color-text-muted);
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
    background: var(--color-secondary);
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
