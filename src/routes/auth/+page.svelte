<script lang="ts">
  import { auth } from '$lib/stores/auth';

  let email = '';
  let password = '';
  let error = '';
  let loading = false;

  async function handleSubmit() {
    if (!email || !password) return;
    
    loading = true;
    error = '';
    
    const { error: authError } = await auth.signInWithPassword(email, password);
    
    if (authError) {
      error = authError.message;
    }
    
    loading = false;
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

      <button type="submit" class="btn btn-primary btn-block" disabled={loading}>
        {loading ? 'Cargando...' : 'Entrar'}
      </button>
    </form>
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

</style>
