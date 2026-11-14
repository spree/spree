import { type RecipeClient, type RecipeStep, runRecipe } from '@spree/config/sample-data'

/**
 * Runs the sample data recipe, naming each step as it starts. The imports
 * take a few minutes: every product image is downloaded by the server.
 */
export function loadSampleData(
  client: RecipeClient,
  steps: RecipeStep[],
  report: (message: string) => void,
): Promise<void> {
  return runRecipe(client, steps, {
    onStep: ({ step, number, total }) => report(`${step.title} (${number}/${total})...`),
  })
}
