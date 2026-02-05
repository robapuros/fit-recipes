<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, type Recipe, type Ingredient } from '$lib/supabase';

  let recipes: (Recipe & { ingredient_names?: string[] })[] = [];
  let loading = true;
  let searchQuery = '';
  let ingredientSearch = '';

  onMount(async () => {
    await loadRecipes();
  });

  async function loadRecipes() {
    // Use the recipe_search view for ingredient data
    const { data, error } = await supabase
      .from('recipe_search')
      .select('*');
    
    if (!error && data) {
      recipes = data;
    }
    loading = false;
  }

  async function deleteRecipe(id: string) {
    if (!confirm('¿Eliminar esta receta?')) return;
    
    const { error } = await supabase.from('recipes').delete().eq('id', id);
    if (!error) {
      recipes = recipes.filter(r => r.id !== id);
    }
  }

  $: filteredRecipes = recipes.filter(recipe => {
    // Search by title
    const matchesTitle = !searchQuery || 
      recipe.title.toLowerCase().includes(searchQuery.toLowerCase());
    
    // Search by ingredients (comma-separated)
    let matchesIngredients = true;
    if (ingredientSearch) {
      const searchTerms = ingredientSearch.toLowerCase().split(',').map(s => s.trim()).filter(Boolean);
      const recipeIngredients = (recipe.ingredient_names || []).map(i => i.toLowerCase());
      matchesIngredients = searchTerms.every(term => 
        recipeIngredients.some(ing => ing.includes(term))
      );
    }
    
    return matchesTitle && matchesIngredients;
  });
</script>

<div class="page">
  <header class="page-header">
    <h1>Recetas</h1>
    <a href="/recipes/new" class="btn btn-primary btn-sm">+ Nueva</a>
  </header>

  <div class="search-box">
    <span class="search-icon">🔍</span>
    <input 
      type="text" 
      class="search-input" 
      placeholder="Buscar receta..."
      bind:value={searchQuery}
    />
  </div>

  <div class="search-box">
    <span class="search-icon">🥕</span>
    <input 
      type="text" 
      class="search-input" 
      placeholder="Buscar por ingredientes (ej: pollo, arroz)"
      bind:value={ingredientSearch}
    />
  </div>

  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else if filteredRecipes.length === 0}
    <div class="empty-state">
      <div class="empty-state-icon">📖</div>
      <p>No hay recetas{ingredientSearch ? ' con esos ingredientes' : ''}.</p>
      <a href="/recipes/new" class="btn btn-primary">Crear receta</a>
    </div>
  {:else}
    <div class="recipe-grid">
      {#each filteredRecipes as recipe}
        <a href="/recipes/{recipe.id}" class="recipe-card">
          <div class="recipe-title">{recipe.title}</div>
          <div class="recipe-meta">
            {#if recipe.prep_time_min}
              <span>⏱️ {recipe.prep_time_min + (recipe.cook_time_min || 0)} min</span>
            {/if}
            {#if recipe.servings}
              <span>👥 {recipe.servings}</span>
            {/if}
          </div>
          {#if recipe.ingredient_names && recipe.ingredient_names.length > 0}
            <div class="recipe-ingredients">
              {recipe.ingredient_names.slice(0, 4).join(', ')}
              {#if recipe.ingredient_names.length > 4}
                <span>+{recipe.ingredient_names.length - 4}</span>
              {/if}
            </div>
          {/if}
        </a>
      {/each}
    </div>
  {/if}
</div>

<style>
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .recipe-grid {
    display: grid;
    gap: 1rem;
  }

  .recipe-card {
    display: block;
    background: var(--color-bg-card);
    border-radius: var(--radius);
    padding: 1rem;
    text-decoration: none;
    color: var(--color-text);
    transition: transform 0.2s;
  }

  .recipe-card:hover {
    transform: translateY(-2px);
  }

  .recipe-title {
    font-weight: 600;
    font-size: 1.1rem;
    margin-bottom: 0.5rem;
  }

  .recipe-meta {
    display: flex;
    gap: 1rem;
    color: var(--color-text-muted);
    font-size: 0.875rem;
    margin-bottom: 0.5rem;
  }

  .recipe-ingredients {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }
</style>
