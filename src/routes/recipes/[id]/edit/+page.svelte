<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Recipe, type Ingredient, ingredientCategories } from '$lib/supabase';

  let recipe: Recipe | null = null;
  let loading = true;
  let saving = false;
  let error = '';

  let form = {
    title: '',
    instructions: '',
    prep_time_min: null as number | null,
    cook_time_min: null as number | null,
    servings: null as number | null
  };

  // Ingredients
  let allIngredients: Ingredient[] = [];
  let selectedIngredients: { ingredient: Ingredient; quantity: string; unit: string }[] = [];
  let ingredientSearch = '';
  let newIngredientName = '';
  let newIngredientCategory = '';
  let showIngredientForm = false;

  onMount(async () => {
    // Load recipe with ingredients
    const { data: recipeData, error: fetchError } = await supabase
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

    if (fetchError || !recipeData) {
      goto('/recipes');
      return;
    }

    recipe = recipeData;
    form = {
      title: recipeData.title,
      instructions: recipeData.instructions || '',
      prep_time_min: recipeData.prep_time_min,
      cook_time_min: recipeData.cook_time_min,
      servings: recipeData.servings
    };

    // Load existing ingredients
    if (recipeData.recipe_ingredients) {
      selectedIngredients = recipeData.recipe_ingredients.map((ri: any) => ({
        ingredient: ri.ingredient,
        quantity: ri.quantity?.toString() || '',
        unit: ri.unit || ''
      }));
    }

    // Load all ingredients
    const { data: ingredientData } = await supabase
      .from('ingredients')
      .select('*')
      .order('name');
    allIngredients = ingredientData || [];

    loading = false;
  });

  function addIngredient(ingredient: Ingredient) {
    if (!selectedIngredients.find(si => si.ingredient.id === ingredient.id)) {
      selectedIngredients = [...selectedIngredients, { ingredient, quantity: '', unit: '' }];
    }
    ingredientSearch = '';
  }

  function removeIngredient(id: string) {
    selectedIngredients = selectedIngredients.filter(si => si.ingredient.id !== id);
  }

  async function createIngredient() {
    if (!newIngredientName) return;

    const { data, error: createError } = await supabase
      .from('ingredients')
      .insert({
        name: newIngredientName.toLowerCase(),
        category: newIngredientCategory || null
      })
      .select()
      .single();

    if (!createError && data) {
      allIngredients = [...allIngredients, data].sort((a, b) => a.name.localeCompare(b.name));
      addIngredient(data);
      newIngredientName = '';
      newIngredientCategory = '';
      showIngredientForm = false;
    }
  }

  async function saveRecipe() {
    if (!form.title || !recipe) return;

    saving = true;
    error = '';

    // Update recipe
    const { error: updateError } = await supabase
      .from('recipes')
      .update({
        title: form.title,
        instructions: form.instructions || null,
        prep_time_min: form.prep_time_min,
        cook_time_min: form.cook_time_min,
        servings: form.servings
      })
      .eq('id', recipe.id);

    if (updateError) {
      error = updateError.message;
      saving = false;
      return;
    }

    // Delete existing ingredients and re-add
    await supabase
      .from('recipe_ingredients')
      .delete()
      .eq('recipe_id', recipe.id);

    if (selectedIngredients.length > 0) {
      const ingredientRows = selectedIngredients.map(si => ({
        recipe_id: recipe!.id,
        ingredient_id: si.ingredient.id,
        quantity: si.quantity ? parseFloat(si.quantity) : null,
        unit: si.unit || null
      }));

      await supabase.from('recipe_ingredients').insert(ingredientRows);
    }

    goto(`/recipes/${recipe.id}`);
    saving = false;
  }

  async function deleteRecipe() {
    if (!recipe || !confirm('¿Eliminar esta receta?')) return;

    await supabase.from('recipes').delete().eq('id', recipe.id);
    goto('/recipes');
  }

  $: filteredIngredients = ingredientSearch
    ? allIngredients.filter(i => 
        i.name.toLowerCase().includes(ingredientSearch.toLowerCase()) &&
        !selectedIngredients.find(si => si.ingredient.id === i.id)
      ).slice(0, 5)
    : [];
</script>

<div class="page">
  {#if loading}
    <div class="loading"><div class="spinner"></div></div>
  {:else if recipe}
    <header class="page-header">
      <a href="/recipes/{recipe.id}" class="btn btn-sm btn-secondary">← Volver</a>
      <h1>Editar Receta</h1>
    </header>

    {#if error}
      <div class="message message-error">{error}</div>
    {/if}

    <div class="card">
      <div class="form-group">
        <label class="form-label">Título</label>
        <input type="text" class="form-input" bind:value={form.title} />
      </div>

      <div class="form-row">
        <div class="form-group">
          <label class="form-label">Prep (min)</label>
          <input type="number" class="form-input" bind:value={form.prep_time_min} />
        </div>
        <div class="form-group">
          <label class="form-label">Cocción (min)</label>
          <input type="number" class="form-input" bind:value={form.cook_time_min} />
        </div>
        <div class="form-group">
          <label class="form-label">Raciones</label>
          <input type="number" class="form-input" bind:value={form.servings} />
        </div>
      </div>

      <div class="form-group">
        <label class="form-label">Ingredientes</label>
        
        {#if selectedIngredients.length > 0}
          <div class="selected-ingredients">
            {#each selectedIngredients as si}
              <div class="ingredient-row">
                <span class="ingredient-name">{si.ingredient.name}</span>
                <input type="text" class="ingredient-input" bind:value={si.quantity} placeholder="Cant." />
                <input type="text" class="ingredient-input" bind:value={si.unit} placeholder="ud." />
                <button class="btn btn-sm btn-danger" on:click={() => removeIngredient(si.ingredient.id)}>✕</button>
              </div>
            {/each}
          </div>
        {/if}

        <div class="ingredient-search">
          <input 
            type="text" 
            class="form-input" 
            bind:value={ingredientSearch}
            placeholder="Buscar ingrediente..."
          />
          {#if filteredIngredients.length > 0}
            <div class="suggestions-dropdown">
              {#each filteredIngredients as ingredient}
                <button class="suggestion-item" on:mousedown={() => addIngredient(ingredient)}>
                  {ingredient.name}
                </button>
              {/each}
            </div>
          {:else if ingredientSearch && !allIngredients.find(i => i.name.toLowerCase() === ingredientSearch.toLowerCase())}
            <div class="suggestions-dropdown">
              <button class="suggestion-item new" on:mousedown={() => { showIngredientForm = true; newIngredientName = ingredientSearch; }}>
                + Crear "{ingredientSearch}"
              </button>
            </div>
          {/if}
        </div>

        {#if showIngredientForm}
          <div class="new-ingredient-form">
            <input type="text" class="form-input" bind:value={newIngredientName} placeholder="Nombre" />
            <select class="form-select" bind:value={newIngredientCategory}>
              <option value="">Categoría...</option>
              {#each ingredientCategories as cat}
                <option value={cat.value}>{cat.label}</option>
              {/each}
            </select>
            <button class="btn btn-sm btn-primary" on:click={createIngredient}>Crear</button>
            <button class="btn btn-sm btn-secondary" on:click={() => showIngredientForm = false}>✕</button>
          </div>
        {/if}
      </div>

      <div class="form-group">
        <label class="form-label">Instrucciones</label>
        <textarea class="form-textarea" bind:value={form.instructions} rows="8"></textarea>
      </div>

      <div class="button-row">
        <button class="btn btn-danger" on:click={deleteRecipe}>🗑️ Eliminar</button>
        <button class="btn btn-primary" on:click={saveRecipe} disabled={saving || !form.title}>
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

  .form-row {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
  }

  .selected-ingredients {
    margin-bottom: 0.5rem;
  }

  .ingredient-row {
    display: flex;
    gap: 0.5rem;
    align-items: center;
    margin-bottom: 0.5rem;
    padding: 0.5rem;
    background: var(--color-bg-input);
    border-radius: var(--radius-sm);
  }

  .ingredient-name {
    flex: 1;
    font-weight: 500;
  }

  .ingredient-input {
    width: 4rem;
    padding: 0.4rem;
    background: var(--color-bg);
    border: 1px solid var(--color-border);
    border-radius: 4px;
    color: var(--color-text);
    font-size: 0.85rem;
  }

  .ingredient-search {
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
  }

  .suggestion-item {
    display: block;
    width: 100%;
    padding: 0.75rem;
    text-align: left;
    background: none;
    border: none;
    color: var(--color-text);
    cursor: pointer;
  }

  .suggestion-item:hover {
    background: var(--color-bg-input);
  }

  .suggestion-item.new {
    color: var(--color-primary);
  }

  .new-ingredient-form {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.5rem;
    flex-wrap: wrap;
  }

  .new-ingredient-form input,
  .new-ingredient-form select {
    flex: 1;
    min-width: 100px;
  }

  .button-row {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
    margin-top: 1rem;
  }
</style>
