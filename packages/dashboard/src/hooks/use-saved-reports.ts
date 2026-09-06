import type {
  SavedReport,
  SavedReportCreateParams,
  SavedReportUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useSavedReport(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('saved-reports', id ?? 'noop'),
    queryFn: () => adminClient.reporting.savedReports.get(id as string),
    enabled: !!id,
  })
}

export function useCreateSavedReport() {
  return useResourceMutation<SavedReport, Error, SavedReportCreateParams>({
    mutationFn: (params) => adminClient.reporting.savedReports.create(params),
    invalidate: [['saved-reports']],
    successMessage: i18n.t('admin.reports.messages.created'),
    errorMessage: i18n.t('admin.reports.messages.create_failed'),
  })
}

export function useUpdateSavedReport(id: string) {
  return useResourceMutation<SavedReport, Error, SavedReportUpdateParams>({
    mutationFn: (params) => adminClient.reporting.savedReports.update(id, params),
    invalidate: [['saved-reports'], ['saved-reports', id]],
    successMessage: i18n.t('admin.reports.messages.updated'),
    errorMessage: i18n.t('admin.reports.messages.update_failed'),
  })
}

export function useDeleteSavedReport() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.reporting.savedReports.delete(id),
    invalidate: [['saved-reports']],
    successMessage: i18n.t('admin.reports.messages.deleted'),
    errorMessage: i18n.t('admin.reports.messages.delete_failed'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('saved-reports', id) })
    },
  })
}
