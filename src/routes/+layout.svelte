<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth';
  import '../app.css';

  let loading = true;

  onMount(() => {
    auth.initialize().then(() => {
      loading = false;
    });
  });

  // Auth check - redirect to login if not authenticated
  $: if (!loading && !$auth.user && !$page.url.pathname.startsWith('/auth')) {
    goto('/auth');
  }

  // Redirect to home if authenticated and on auth page
  $: if (!loading && $auth.user && $page.url.pathname.startsWith('/auth')) {
    goto('/');
  }

  $: currentPath = $page.url.pathname;
</script>

{#if loading}
  <div class="loading" style="min-height: 100vh;">
    <div class="spinner"></div>
  </div>
{:else if !$auth.user}
  <slot />
{:else}
  <slot />
  
  <nav class="nav-bottom">
    <a href="/" class="nav-item" class:active={currentPath === '/'}>
      <span class="nav-icon">🏠</span>
      <span>Inicio</span>
    </a>
    <a href="/workouts" class="nav-item" class:active={currentPath.startsWith('/workouts')}>
      <span class="nav-icon">💪</span>
      <span>Entrenos</span>
    </a>
    <a href="/exercises" class="nav-item" class:active={currentPath.startsWith('/exercises')}>
      <span class="nav-icon">🏋️</span>
      <span>Ejercicios</span>
    </a>
    <a href="/recipes" class="nav-item" class:active={currentPath.startsWith('/recipes')}>
      <span class="nav-icon">📖</span>
      <span>Recetas</span>
    </a>
    <a href="/partner" class="nav-item" class:active={currentPath.startsWith('/partner')}>
      <span class="nav-icon">👀</span>
      <span>Pareja</span>
    </a>
  </nav>
{/if}
