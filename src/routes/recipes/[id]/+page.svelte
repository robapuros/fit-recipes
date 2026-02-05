<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase, type Recipe, type RecipeIngredient, type Ingredient } from '$lib/supabase';

  type FullRecipe = Recipe & { 
    recipe_ingredients: (RecipeIngredient & { ingredient: Ingredient })[] 
  };

  let recipe: FullRecipe | null = null;
  let loading = true;

  onMount(async () => {
    const { data, error } = await supabase
      .from('recipes')
      .select(`
        *,
        recipe_ingredients (
          *,
          ingredient:ingredients(*)
        )
      `)
      .eq('id', $page.params.id)
      .single();

    if (error || !data) {
      goto('/recipes');
    } else {
      recipe = data;
    }
    loading = false;
  });

  async function deleteRecipe() {
    if (!recipe || !confirm('¿Eliminar esta receta?')) return;
    
    await supabase.from('recipes').delete().eq('id', recipe.id);
    goto('/recipes');
  }
</script>

<div class="page">
  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else if recipe}
    <header class="page-header">
      <a href="/recipes" class="btn btn-sm btn-secondary">← Recetas</a>
      <div class="header-actions">
        <a href="/recipes/{recipe.id}/edit" class="btn btn-sm btn-secondary">✏️ Editar</a>
        <button class="btn btn-sm btn-danger" on:click={deleteRecipe}>🗑️</button>
      </div>
    </header>

    <h1>{recipe.title}</h1>

    <div class="recipe-meta">
      {#if recipe.prep_time_min}
        <div class="meta-item">
          <span class="meta-icon">⏱️</span>
          <span>Prep: {recipe.prep_time_min} min</span>
        </div>
      {/if}
      {#if recipe.cook_time_min}
        <div class="meta-item">
          <span class="meta-icon">🔥</span>
          <span>Cocción: {recipe.cook_time_min} min</span>
        </div>
      {/if}
      {#if recipe.servings}
        <div class="meta-item">
          <span class="meta-icon">👥</span>
          <span>{recipe.servings} raciones</span>
        </div>
      {/if}
    </div>

    {#if recipe.recipe_ingredients && recipe.recipe_ingredients.length > 0}
      <section class="recipe-section">
        <h2>Ingredientes</h2>
        <ul class="ingredients-list">
          {#each recipe.recipe_ingredients as ri}
            <li>
              {#if ri.quantity}
                <span class="ingredient-qty">{ri.quantity} {ri.unit || ''}</span>
              {/if}
              <span class="ingredient-name">{ri.ingredient?.name}</span>
              {#if ri.notes}
                <span class="ingredient-note">({ri.notes})</span>
              {/if}
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if recipe.instructions}
      <section class="recipe-section">
        <h2>Instrucciones</h2>
        <div class="instructions">
          {#each recipe.instructions.split('\n') as step, i}
            {#if step.trim()}
              <p>{step}</p>
            {/if}
          {/each}
        </div>
      </section>
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

  .header-actions {
    display: flex;
    gap: 0.5rem;
  }

  h1 {
    font-size: 1.75rem;
    margin-bottom: 1rem;
  }

  .recipe-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    margin-bottom: 1.5rem;
    padding: 1rem;
    background: var(--color-bg-card);
    border-radius: var(--radius);
  }

  .meta-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .meta-icon {
    font-size: 1.25rem;
  }

  .recipe-section {
    margin-bottom: 1.5rem;
  }

  .recipe-section h2 {
    font-size: 1.25rem;
    margin-bottom: 0.75rem;
    color: var(--color-primary);
  }

  .ingredients-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .ingredients-list li {
    display: flex;
    align-items: baseline;
    gap: 0.5rem;
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--color-border);
  }

  .ingredients-list li:last-child {
    border-bottom: none;
  }

  .ingredient-qty {
    font-weight: 600;
    min-width: 5rem;
  }

  .ingredient-name {
    flex: 1;
  }

  .ingredient-note {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }

  .instructions {
    line-height: 1.6;
  }

  .instructions p {
    margin-bottom: 0.75rem;
  }
</style>
