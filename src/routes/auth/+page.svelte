<script lang="ts">
  import { auth } from '$lib/stores/auth';

  let email = '';
  let password = '';
  let error = '';
  let success = '';
  let loading = false;
  let mode: 'magic' | 'password' = 'magic';

  async function handleMagicLink() {
    if (!email) return;
    
    loading = true;
    error = '';
    
    const { error: authError } = await auth.signIn(email);
    
    if (authError) {
      error = authError.message;
    } else {
      success = '¡Revisa tu email! Te hemos enviado un enlace mágico.';
    }
    
    loading = false;
  }

  async function handlePassword() {
    if (!email || !password) return;
    
    loading = true;
    error = '';
    
    const { error: authError } = await auth.signInWithPassword(email, password);
    
    if (authError) {
      error = authError.message;
    }
    
    loading = false;
  }

  function handleSubmit() {
    if (mode === 'magic') {
      handleMagicLink();
    } else {
      handlePassword();
    }
  }
</script>

<div class="auth-container">
  <div class="auth-card">
    <div class="auth-header">
      <h1>💪 FitRecipes</h1>
      <p>Tu app de entreno y recetas</p>
    </div>

    {#if error}
      <div class="message message-error">{error}</div>
    {/if}

    {#if success}
      <div class="message message-success">{success}</div>
    {:else}
      <form on:submit|preventDefault={handleSubmit}>
        <div class="form-group">
          <label class="form-label" for="email">Email</label>
          <input
            id="email"
            type="email"
            class="form-input"
            bind:value={email}
            placeholder="alba@ejemplo.com"
            required
          />
        </div>

        {#if mode === 'password'}
          <div class="form-group">
            <label class="form-label" for="password">Contraseña</label>
            <input
              id="password"
              type="password"
              class="form-input"
              bind:value={password}
              placeholder="••••••••"
              required
            />
          </div>
        {/if}

        <button type="submit" class="btn btn-primary btn-block" disabled={loading}>
          {#if loading}
            Cargando...
          {:else if mode === 'magic'}
            Enviar enlace mágico ✨
          {:else}
            Entrar
          {/if}
        </button>
      </form>

      <div class="auth-toggle">
        {#if mode === 'magic'}
          <button class="btn-link" on:click={() => mode = 'password'}>
            Usar contraseña
          </button>
        {:else}
          <button class="btn-link" on:click={() => mode = 'magic'}>
            Usar enlace mágico
          </button>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .auth-container {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
  }

  .auth-card {
    background: var(--color-bg-card);
    border-radius: var(--radius);
    padding: 2rem;
    width: 100%;
    max-width: 400px;
  }

  .auth-header {
    text-align: center;
    margin-bottom: 2rem;
  }

  .auth-header h1 {
    font-size: 2rem;
    margin-bottom: 0.5rem;
  }

  .auth-header p {
    color: var(--color-text-muted);
    margin: 0;
  }

  .auth-toggle {
    text-align: center;
    margin-top: 1.5rem;
  }

  .btn-link {
    background: none;
    border: none;
    color: var(--color-primary);
    cursor: pointer;
    font-size: 0.875rem;
  }

  .btn-link:hover {
    text-decoration: underline;
  }
</style>
