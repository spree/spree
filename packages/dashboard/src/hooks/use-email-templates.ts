import {
  type EmailTemplate,
  type EmailTemplateDraftParams,
  type EmailTemplatePreview,
  type EmailTemplatePreviewParams,
  type EmailTemplateVersionParams,
  SpreeError,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useMutation, useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

const RESOURCE = 'email-templates'

export interface EmailTemplateProblem {
  email: string
  message: string
  line?: number | null
}

/** The problems a 422 lists when a template does not render, else none. */
export function templateProblems(error: unknown): EmailTemplateProblem[] {
  if (!(error instanceof SpreeError) || error.code !== 'email_template_invalid') return []
  const problems = (error.details as unknown as { problems?: EmailTemplateProblem[] } | undefined)
    ?.problems
  return problems ?? [{ email: '', message: error.message }]
}

export function useEmailTemplates(language: string) {
  return useQuery({
    queryKey: useResourceKey(RESOURCE, 'list', language),
    queryFn: () => adminClient.emailTemplates.list({ language }),
  })
}

export function useEmailTemplate(id: string, language: string, enabled = true) {
  return useQuery({
    queryKey: useResourceKey(RESOURCE, id, language),
    queryFn: () => adminClient.emailTemplates.get(id, { language, expand: ['draft.updated_by'] }),
    enabled,
  })
}

export function useEmailTemplateRevisions(id: string, language: string, enabled: boolean) {
  return useQuery({
    queryKey: useResourceKey(RESOURCE, id, language, 'revisions'),
    queryFn: () =>
      adminClient.emailTemplates.revisions.list(id, {
        language,
        expand: ['published_by'],
        limit: 50,
      }),
    enabled,
  })
}

/** Saves the draft; conflicts and render problems are left to the editor. */
export function useSaveEmailTemplateDraft(id: string) {
  return useResourceMutation<EmailTemplate, Error, EmailTemplateDraftParams>({
    mutationFn: (params) => adminClient.emailTemplates.draft.update(id, params),
    invalidate: [[RESOURCE]],
    successMessage: i18n.t('admin.email_templates.messages.draft_saved'),
    errorMessage: false,
  })
}

export function useDiscardEmailTemplateDraft(id: string) {
  return useResourceMutation<EmailTemplate, Error, EmailTemplateVersionParams>({
    mutationFn: (params) => adminClient.emailTemplates.draft.delete(id, params),
    invalidate: [[RESOURCE]],
    errorMessage: false,
    successMessage: i18n.t('admin.email_templates.messages.draft_discarded'),
  })
}

export function usePublishEmailTemplate(id: string) {
  return useResourceMutation<EmailTemplate, Error, EmailTemplateVersionParams>({
    mutationFn: (params) => adminClient.emailTemplates.publish(id, params),
    invalidate: [[RESOURCE]],
    successMessage: i18n.t('admin.email_templates.messages.published'),
    errorMessage: false,
  })
}

export function useRevertEmailTemplate(id: string) {
  return useResourceMutation<EmailTemplate, Error, EmailTemplateVersionParams>({
    mutationFn: (params) => adminClient.emailTemplates.revert(id, params),
    invalidate: [[RESOURCE]],
    errorMessage: false,
    successMessage: i18n.t('admin.email_templates.messages.reverted'),
  })
}

export function useRestoreEmailTemplateRevision(id: string) {
  return useResourceMutation<
    EmailTemplate,
    Error,
    { revisionId: string; language: string; lock_version?: number }
  >({
    mutationFn: ({ revisionId, ...params }) =>
      adminClient.emailTemplates.revisions.restore(id, revisionId, params),
    invalidate: [[RESOURCE]],
    successMessage: i18n.t('admin.email_templates.messages.restored'),
    errorMessage: false,
  })
}

export function useSendTestEmail(id: string) {
  return useResourceMutation<{ sent_to: string }, Error, EmailTemplatePreviewParams>({
    mutationFn: (params) => adminClient.emailTemplates.sendTest(id, params),
    successMessage: false,
    errorMessage: i18n.t('admin.email_templates.errors.test_email_failed'),
  })
}

/**
 * The store's latest records a template can be previewed with. Empty for an
 * email that needs none; a caller who may not read them gets none either.
 */
export function useEmailTemplateSampleRecords(id: string, emailKey: string, enabled: boolean) {
  return useQuery({
    queryKey: useResourceKey(RESOURCE, id, 'sample-records', emailKey),
    queryFn: async () => {
      try {
        return (
          await adminClient.emailTemplates.sampleRecords.list(id, {
            email_key: emailKey || undefined,
          })
        ).data
      } catch (error) {
        if (error instanceof SpreeError && error.status === 403) return []
        throw error
      }
    },
    enabled,
  })
}

/** Renders a template, or unsaved changes to it, with sample data. Never cached. */
export function useEmailTemplatePreview(id: string) {
  return useMutation<EmailTemplatePreview, Error, EmailTemplatePreviewParams>({
    mutationFn: (params) => adminClient.emailTemplates.preview(id, params),
  })
}
