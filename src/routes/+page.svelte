<script lang="ts">
  import { onMount } from 'svelte';
  import { auth } from '$lib/stores/auth';
  import { supabase, type WorkoutLog, type Exercise } from '$lib/supabase';

  let todayWorkouts: (WorkoutLog & { exercise: Exercise })[] = [];
  let partnerWorkouts: (WorkoutLog & { exercise: Exercise, profile: { username: string } })[] = [];
  let loading = true;

  onMount(async () => {
    await loadTodayData();
  });

  async function loadTodayData() {
    if (!$auth.user) return;
    
    const today = new Date().toISOString().split('T')[0];
    
    // My workouts today
    const { data: myData } = await supabase
      .from('workout_logs')
      .select('*, exercise:exercises(*)')
      .eq('user_id', $auth.user.id)
      .eq('performed_at', today)
      .order('created_at', { ascending: false });
    
    todayWorkouts = myData || [];

    // Partner's workouts today
    const { data: partnerData } = await supabase
      .from('workout_logs')
      .select('*, exercise:exercises(*), profile:profiles(username)')
      .neq('user_id', $auth.user.id)
      .eq('performed_at', today)
      .order('created_at', { ascending: false });
    
    partnerWorkouts = partnerData || [];
    
    loading = false;
  }

  function getGreeting() {
    const hour = new Date().getHours();
    if (hour < 12) return '¡Buenos días';
    if (hour < 20) return '¡Buenas tardes';
    return '¡Buenas noches';
  }

  async function handleSignOut() {
    await auth.signOut();
  }
</script>

<div class="page">
  <header class="home-header">
    <div>
      <h1>{getGreeting()}, {$auth.profile?.display_name || $auth.profile?.username}! 💪</h1>
      <p class="date">{new Date().toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long' })}</p>
    </div>
    <button class="btn btn-sm btn-secondary" on:click={handleSignOut}>Salir</button>
  </header>

  <div class="quick-actions">
    <a href="/workouts/new" class="quick-action">
      <span class="quick-action-icon">🏋️</span>
      <span class="quick-action-label">Log Entreno</span>
    </a>
    <a href="/recipes" class="quick-action">
      <span class="quick-action-icon">📖</span>
      <span class="quick-action-label">Recetas</span>
    </a>
  </div>

  <section>
    <h2>Hoy</h2>
    
    {#if loading}
      <div class="loading"><div class="spinner"></div></div>
    {:else if todayWorkouts.length === 0}
      <div class="card">
        <div class="empty-state">
          <div class="empty-state-icon">🎯</div>
          <p>No has entrenado hoy. ¡Es un buen día para empezar!</p>
          <a href="/workouts/new" class="btn btn-primary">Registrar entreno</a>
        </div>
      </div>
    {:else}
      <div class="card">
        <div class="card-header">
          <span class="card-title">Mis ejercicios hoy</span>
          <span class="badge badge-primary">{todayWorkouts.length}</span>
        </div>
        {#each todayWorkouts as workout}
          <div class="workout-item">
            <span class="workout-name">{workout.exercise?.name}</span>
            <span class="workout-sets">{workout.sets.length} series</span>
          </div>
        {/each}
      </div>
    {/if}
  </section>

  {#if partnerWorkouts.length > 0}
    <section>
      <h2>Tu pareja hoy</h2>
      <div class="card">
        <div class="card-header">
          <span class="card-title">{partnerWorkouts[0].profile?.username}</span>
          <span class="badge badge-secondary">{partnerWorkouts.length} ejercicios</span>
        </div>
        {#each partnerWorkouts as workout}
          <div class="workout-item">
            <span class="workout-name">{workout.exercise?.name}</span>
            <span class="workout-sets">{workout.sets.length} series</span>
          </div>
        {/each}
      </div>
    </section>
  {/if}
</div>

<style>
  .home-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 1.5rem;
  }

  .home-header h1 {
    font-size: 1.5rem;
    margin-bottom: 0.25rem;
  }

  .date {
    color: var(--color-text-muted);
    margin: 0;
    text-transform: capitalize;
  }

  section {
    margin-bottom: 1.5rem;
  }

  section h2 {
    font-size: 1.1rem;
    color: var(--color-text-muted);
    margin-bottom: 0.75rem;
  }

  .workout-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 0;
    border-bottom: 1px solid var(--color-border);
  }

  .workout-item:last-child {
    border-bottom: none;
  }

  .workout-name {
    font-weight: 500;
  }

  .workout-sets {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }
</style>
