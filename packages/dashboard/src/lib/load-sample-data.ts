import { adminClient, queryClient } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import type { TFunction } from 'i18next'

/**
 * Loads the demo store through the Admin API while the merchant gets on with
 * the dashboard: the imports take a few minutes. Progress and the outcome
 * are a toast. A load that stops halfway (a closed tab, a failed step) is
 * finished by `spree sample-data`, which only adds what is missing.
 */
export function loadSampleDataInBackground(t: TFunction): void {
  const toast = toastManager.add({
    type: 'loading',
    title: t('admin.setup.sample_data.loading'),
    timeout: 0,
  })
  void (async () => {
    try {
      // The recipe carries the demo catalog's CSVs, so it is loaded only here.
      const { runRecipe, sampleData } = await import('@spree/config/sample-data')
      await runRecipe(adminClient, sampleData(), {
        onStep: ({ number, total }) =>
          toastManager.update(toast, {
            description: t('admin.setup.sample_data.step', { number, total }),
          }),
      })
      toastManager.update(toast, {
        type: 'success',
        title: t('admin.setup.sample_data.loaded'),
        description: undefined,
        timeout: 5000,
      })
      // Whatever the merchant is looking at may now have rows to show.
      await queryClient.invalidateQueries()
    } catch (error) {
      toastManager.update(toast, {
        type: 'error',
        title: t('admin.setup.sample_data.failed'),
        description: error instanceof Error ? error.message : String(error),
        timeout: 0,
      })
    }
  })()
}
