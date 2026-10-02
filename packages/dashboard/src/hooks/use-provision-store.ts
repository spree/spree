import { adminClient } from '@spree/dashboard-core'
import { useMutation } from '@tanstack/react-query'

/**
 * Deploys the defaults every new store starts with — tax categories,
 * channels, the warehouse, delivery zones and rates, reasons — through the
 * Admin API, right after first-run setup has placed the store in its
 * country. Only what is missing is created, so retrying is safe.
 */
export function useProvisionStore() {
  return useMutation({
    mutationFn: async (storeId: string | null) => {
      // The engine (YAML parser, schemas, templates) is only needed here, so
      // it stays out of the bundle every other admin page loads.
      const { provisionStore, renderReport, reportHasFailures } = await import('@spree/config')
      if (storeId) adminClient.setStore(storeId)
      const report = await provisionStore(adminClient)
      if (reportHasFailures(report)) throw new Error(renderReport(report))
      return report
    },
  })
}
