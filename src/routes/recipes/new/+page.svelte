<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth';
  import { supabase, type Ingredient, ingredientCategories } from '$lib/supabase';

  let recipe = {
    title: '',
    instructions: '',
    prep_time_min: null as number | null,
    cook_time_min: null as number | null,
    servings: null as number | null
  };

  let ingredients: Ingredient[] = [];
  let selectedIngredients: { ingredient: Ingredient; quantity: string; unit: string }[] = [];
  let newIngredientName = '';
  let newIngredientCategory = '';
  let showIngredientForm = false;
  let saving = false;
  let ingredientSearch = '';

  onMount(async () => {
    const { data } = await supabase.from('ingredients').select('*').order('name');
    ingredients = data || [];
  });

  async function createIngredient() {
    if (!newIngredientName) return;

    const { data, error } = await supabase
      .from('ingredients')
      .insert({
        name: newIngredientName.toLowerCase(),
        category: newIngredientCategory || null
      })
      .select()
      .single();

    if (!error && data) {
      ingredients = [...ingredients, data].sort((a, b) => a.name.localeCompare(b.name));
      addIngredient(data);
      newIngredientName = '';
      newIngredientCategory = '';
      showIngredientForm = false;
    }
  }

  function addIngredient(ingredient: Ingredient) {
    if (!selectedIngredients.find(si => si.ingredient.id === ingredient.id)) {
      selectedIngredients = [...selectedIngredients, { ingredient, quantity: '', unit: '' }];
    }
    ingredientSearch = '';
  }

  function removeIngredient(id: string) {
    selectedIngredients = selectedIngredients.filter(si => si.ingredient.id !== id);
  }

  async function saveRecipe() {
    if (!recipe.title || !$auth.user) return;

    saving = true;

    // Create recipe
    const { data: recipeData, error: recipeError } = await supabase
      .from('recipes')
      .insert({
        title: recipe.title,
        instructions: recipe.instructions || null,
        prep_time_min: recipe.prep_time_min,
        cook_time_min: recipe.cook_time_min,
        servings: recipe.servings,
        created_by: $auth.user.id
      })
      .select()
      .single();

    if (recipeError || !recipeData) {
      alert('Error al crear receta');
      saving = false;
      return;
    }

    // Add ingredients
    if (selectedIngredients.length > 0) {
      const ingredientRows = selectedIngredients.map(si => ({
        recipe_id: recipeData.id,
        ingredient_id: si.ingredient.id,
        quantity: si.quantity ? parseFloat(si.quantity) : null,
        unit: si.unit || null
      }));

      await supabase.from('recipe_ingredients').insert(ingredientRows);
    }

    goto('/recipes');
  }

  $: filteredIngredients = ingredientSearch
    ? ingredients.filter(i => 
        i.name.toLowerCase().includes(ingredientSearch.toLowerCase()) &&
        !selectedIngredients.find(si => si.ingredient.id === i.id)
      )
    : [];
</script>

<div class="page">
  <header class="page-header">
    <a href="/recipes" class="btn btn-sm btn-secondary">← Atrás</a>
    <h1>Nueva Receta</h1>
  </header>

  <div class="form-group">
    <label class="form-label">Título *</label>
    <input type="text" class="form-input" bind:value={recipe.title} placeholder="Ej: Arroz con pollo" />
  </div>

  <div class="form-row">
    <div class="form-group">
      <label class="form-label">Prep (min)</label>
      <input type="number" class="form-input" bind:value={recipe.prep_time_min} placeholder="15" />
    </div>
    <div class="form-group">
      <label class="form-label">Cocción (min)</label>
      <input type="number" class="form-input" bind:value={recipe.cook_time_min} placeholder="30" />
    </div>
  </div>

  <div class="form-group">
    <label class="form-label">Raciones</label>
    <input type="number" class="form-input" bind:value={recipe.servings} placeholder="4" />
  </div>

  <div class="form-group">
    <label class="form-label">Ingredientes</label>
    
    {#if selectedIngredients.length > 0}
      <div class="selected-ingredients">
        {#each selectedIngredients as si}
          <div class="ingredient-row">
            <span class="ingredient-name">{si.ingredient.name}</span>
            <input type="text" class="ingredient-qty" bind:value={si.quantity} placeholder="Cant." />
            <input type="text" class="ingredient-unit" bind:value={si.unit} placeholder="ud." />
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
        placeholder="Buscar o añadir ingrediente..."
      />
      {#if filteredIngredients.length > 0}
        <div class="ingredient-dropdown">
          {#each filteredIngredients.slice(0, 5) as ingredient}
            <button class="ingredient-option" on:click={() => addIngredient(ingredient)}>
              {ingredient.name}
            </button>
          {/each}
        </div>
      {:else if ingredientSearch && !ingredients.find(i => i.name.toLowerCase() === ingredientSearch.toLowerCase())}
        <div class="ingredient-dropdown">
          <button class="ingredient-option new" on:click={() => { showIngredientForm = true; newIngredientName = ingredientSearch; }}>
            + Crear "{ingredientSearch}"
          </button>
        </div>
      {/if}
    </div>

    {#if showIngredientForm}
      <div class="card new-ingredient-form">
        <div class="form-group">
          <label class="form-label">Nombre del ingrediente</label>
          <input type="text" class="form-input" bind:value={newIngredientName} />
        </div>
        <div class="form-group">
          <label class="form-label">Categoría</label>
          <select class="form-select" bind:value={newIngredientCategory}>
            <option value="">Sin categoría</option>
            {#each ingredientCategories as cat}
              <option value={cat.value}>{cat.label}</option>
            {/each}
          </select>
        </div>
        <div class="form-row">
          <button class="btn btn-secondary" on:click={() => showIngredientForm = false}>Cancelar</button>
          <button class="btn btn-primary" on:click={createIngredient}>Crear</button>
        </div>
      </div>
    {/if}
  </div>

  <div class="form-group">
    <label class="form-label">Instrucciones</label>
    <textarea 
      class="form-textarea" 
      bind:value={recipe.instructions}
      placeholder="1. Cortar la cebolla...&#10;2. Calentar el aceite..."
      rows="6"
    ></textarea>
  </div>

  <button 
    class="btn btn-primary btn-block" 
    on:click={saveRecipe}
    disabled={saving || !recipe.title}
  >
    {saving ? 'Guardando...' : '✓ Guardar receta'}
  </button>
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
  }

  .selected-ingredients {
    margin-bottom: 0.5rem;
  }

  .ingredient-row {
    display: grid;
    grid-template-columns: 1fr 4rem 4rem auto;
    gap: 0.5rem;
    align-items: center;
    padding: 0.5rem;
    background: var(--color-bg-input);
    border-radius: var(--radius-sm);
    margin-bottom: 0.5rem;
  }

  .ingredient-name {
    font-weight: 500;
  }

  .ingredient-qty, .ingredient-unit {
    padding: 0.5rem;
    background: var(--color-bg);
    border: 1px solid var(--color-border);
    border-radius: 4px;
    color: var(--color-text);
    font-size: 0.875rem;
  }

  .ingredient-search {
    position: relative;
  }

  .ingredient-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: var(--color-bg-card);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-sm);
    z-index: 10;
    max-height: 200px;
    overflow-y: auto;
  }

  .ingredient-option {
    display: block;
    width: 100%;
    padding: 0.75rem 1rem;
    text-align: left;
    background: none;
    border: none;
    color: var(--color-text);
    cursor: pointer;
  }

  .ingredient-option:hover {
    background: var(--color-bg-input);
  }

  .ingredient-option.new {
    color: var(--color-primary);
    font-weight: 500;
  }

  .new-ingredient-form {
    margin-top: 0.5rem;
  }
</style>
