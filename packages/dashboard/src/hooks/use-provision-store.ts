import { provisionStore, renderReport, reportHasFailures } from '@spree/config'
import { adminClient } from '@spree/dashboard-core'
import { useMutation } from '@tanstack/react-query'

/**
 * Deploys the defaults every new store starts with — tax categories,
 * channels, the warehouse, delivery zones and rates, reasons — through the
 * Admin API, right after first-run setup has placed the store in its
 * country. Safe to run again: only what is missing is created.
 */
export function useProvisionStore() {
  return useMutation({
    mutationFn: async () => {
      const report = await provisionStore(adminClient)
      if (reportHasFailures(report)) throw new Error(renderReport(report))
      return report
    },
  })
}
