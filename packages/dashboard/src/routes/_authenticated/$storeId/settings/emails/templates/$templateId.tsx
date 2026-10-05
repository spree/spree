import { type EmailTemplate, SpreeError } from '@spree/admin-sdk'
import {
  PageHeader,
  Subject,
  useDisplayName,
  usePermissions,
  useStore,
} from '@spree/dashboard-core'
import {
  Alert,
  AlertAction,
  AlertDescription,
  AlertTitle,
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenuItem,
  ErrorState,
  Field,
  FieldLabel,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  Textarea,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import { HistoryIcon, RotateCcwIcon, SendIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import {
  CodeEditor,
  type CodeEditorCompletion,
  type CodeEditorHandle,
} from '@spree/dashboard-ui/ui/code-editor'
import { createFileRoute, useBlocker } from '@tanstack/react-router'
import { useCallback, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { EmailTemplateConflictDialog } from '../../../../../../components/spree/email-templates/conflict-dialog'
import { DefaultDiffDialog } from '../../../../../../components/spree/email-templates/default-diff-dialog'
import { EmailTemplateHistorySheet } from '../../../../../../components/spree/email-templates/history-sheet'
import {
  EmailTemplatePreviewCard,
  useLivePreview,
} from '../../../../../../components/spree/email-templates/preview-card'
import { EmailTemplateProblemsAlert } from '../../../../../../components/spree/email-templates/problems-alert'
import { EmailTemplateVariablesCard } from '../../../../../../components/spree/email-templates/variables-card'
import {
  type EmailTemplateProblem,
  templateProblems,
  useDiscardEmailTemplateDraft,
  useEmailTemplate,
  useEmailTemplateRevisions,
  usePublishEmailTemplate,
  useRestoreEmailTemplateRevision,
  useRevertEmailTemplate,
  useSaveEmailTemplateDraft,
  useSendTestEmail,
} from '../../../../../../hooks/use-email-templates'
import { emailTemplateName } from '../../../../../../lib/email-template-name'
import { EMAIL_TEMPLATE_FILTERS } from '../../../../../../lib/email-template-variables'

export const Route = createFileRoute(
  '/_authenticated/$storeId/settings/emails/templates/$templateId',
)({
  component: EmailTemplateEditorPage,
})

/** A version an earlier store published for every language at once. */
const EVERY_LANGUAGE = 'any'

function EmailTemplateEditorPage() {
  const { t } = useTranslation()
  const { templateId } = Route.useParams()
  const { permissions } = usePermissions()
  const canRead = permissions.can('read', Subject.EmailTemplate)
  const { defaultLocale } = useStore()
  const [language, setLanguage] = useState(defaultLocale)
  const [reloads, setReloads] = useState(0)
  const {
    data: template,
    isLoading,
    error,
    refetch,
  } = useEmailTemplate(templateId, language, canRead)

  if (!canRead) {
    return <ErrorState title={t('admin.email_templates.errors.not_allowed')} />
  }

  if (error) {
    return (
      <ErrorState
        title={t('admin.email_templates.errors.load_failed')}
        description={error.message}
        onRetry={() => refetch()}
      />
    )
  }

  if (isLoading || !template) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-[32rem] w-full" />
      </div>
    )
  }

  return (
    <EmailTemplateEditor
      key={`${template.id}:${language}:${reloads}`}
      template={template}
      language={language}
      onLanguageChange={setLanguage}
      onReload={async () => {
        await refetch()
        setReloads((count) => count + 1)
      }}
      onFetchLatest={async () => (await refetch()).data}
    />
  )
}

interface Version {
  subject: string
  body: string
}

/** What the editor opens on: the draft, else what customers receive now. */
function startingVersion(template: EmailTemplate): Version {
  const source = template.draft ?? template
  return { subject: source.subject ?? '', body: source.body }
}

function EmailTemplateEditor({
  template,
  language,
  onLanguageChange,
  onReload,
  onFetchLatest,
}: {
  template: EmailTemplate
  language: string
  onLanguageChange: (language: string) => void
  onReload: () => void
  onFetchLatest: () => Promise<EmailTemplate | undefined>
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { permissions } = usePermissions()
  const canEdit = permissions.can('update', Subject.EmailTemplate)
  const editorRef = useRef<CodeEditorHandle>(null)
  const isEmail = template.kind === 'email'

  const [saved, setSaved] = useState<Version>(() => startingVersion(template))
  const [subject, setSubject] = useState(saved.subject)
  const [body, setBody] = useState(saved.body)
  const [lockVersion, setLockVersion] = useState(template.draft?.lock_version)
  const [hasDraft, setHasDraft] = useState(!!template.draft)
  const [problems, setProblems] = useState<EmailTemplateProblem[]>([])
  const [conflict, setConflict] = useState<string | null>(null)
  const [historyOpen, setHistoryOpen] = useState(false)
  const [diffOpen, setDiffOpen] = useState(false)
  const dirty = subject !== saved.subject || body !== saved.body

  // Problems from a save or publish describe the text as it was sent.
  const editSubject = (value: string) => {
    setSubject(value)
    setProblems([])
  }
  const editBody = (value: string) => {
    setBody(value)
    setProblems([])
  }

  // Leaving the page, or the tab, would lose unsaved changes.
  useBlocker({
    shouldBlockFn: async () =>
      dirty &&
      !(await confirm({
        title: t('admin.email_templates.confirm.leave_title'),
        message: t('admin.email_templates.confirm.leave_message'),
        confirmLabel: t('admin.email_templates.confirm.leave'),
        variant: 'destructive',
      })),
    enableBeforeUnload: () => dirty,
  })

  const save = useSaveEmailTemplateDraft(template.id)
  const discard = useDiscardEmailTemplateDraft(template.id)
  const publish = usePublishEmailTemplate(template.id)
  const revert = useRevertEmailTemplate(template.id)
  const restore = useRestoreEmailTemplateRevision(template.id)
  const sendTest = useSendTestEmail(template.id)
  // Until this language has its own version, revert and history act on the
  // one published for every language, which is what customers receive.
  const forEveryLanguage = template.published_language === EVERY_LANGUAGE
  const versionLanguage = forEveryLanguage ? EVERY_LANGUAGE : language
  const revisions = useEmailTemplateRevisions(template.id, versionLanguage, historyOpen)

  /**
   * Takes the server's version after a write. With `sent`, text typed while
   * the request was out is kept rather than replaced.
   */
  const applyResponse = useCallback((next: EmailTemplate, sent?: Version) => {
    const version = startingVersion(next)
    setSaved(version)
    setSubject((current) => (!sent || current === sent.subject ? version.subject : current))
    setBody((current) => (!sent || current === sent.body ? version.body : current))
    setLockVersion(next.draft?.lock_version)
    setHasDraft(!!next.draft)
    setProblems([])
  }, [])

  const handleError = (error: unknown) => {
    if (error instanceof SpreeError && error.status === 409) {
      setConflict(error.message)
      return
    }
    const listed = templateProblems(error)
    if (listed.length > 0) setProblems(listed)
    else if (error instanceof Error) toastManager.add({ type: 'error', title: error.message })
  }

  const saveDraft = async (
    extra: { rebase?: boolean; version?: Version; lockVersion?: number } = {},
  ) => {
    const version = extra.version ?? { subject, body }
    try {
      const next = await save.mutateAsync({
        language,
        body: version.body,
        ...(isEmail ? { subject: version.subject } : {}),
        // null says this editor saw no draft, so one someone saved since is not overwritten.
        lock_version: ('lockVersion' in extra ? extra.lockVersion : lockVersion) ?? null,
        rebase: extra.rebase,
      })
      // Keep what is being typed: only the saved copy moves on.
      setSaved(version)
      setLockVersion(next.draft?.lock_version)
      setHasDraft(true)
      setProblems([])
      return next
    } catch (error) {
      handleError(error)
      return null
    }
  }

  const handlePublish = async () => {
    const sent = { subject, body }
    const draft = dirty || !hasDraft ? await saveDraft() : undefined
    if (draft === null) return
    try {
      const lock_version = draft ? draft.draft?.lock_version : lockVersion
      applyResponse(await publish.mutateAsync({ language, lock_version }), sent)
    } catch (error) {
      handleError(error)
    }
  }

  /** Asks first, then replaces the editor's text with what the write returns. */
  const confirmAndApply = async (
    question: Parameters<typeof confirm>[0],
    write: () => Promise<EmailTemplate>,
  ) => {
    if (!(await confirm(question))) return false
    try {
      applyResponse(await write())
      return true
    } catch (error) {
      handleError(error)
      return false
    }
  }

  const handleDiscard = () =>
    confirmAndApply(
      {
        title: t('admin.email_templates.confirm.discard_title'),
        message: t('admin.email_templates.confirm.discard_message'),
        confirmLabel: t('admin.email_templates.actions.discard_draft'),
        variant: 'destructive',
      },
      () => discard.mutateAsync({ language, lock_version: lockVersion }),
    )

  const handleRevert = () =>
    confirmAndApply(
      {
        title: t('admin.email_templates.confirm.revert_title'),
        message: forEveryLanguage
          ? t('admin.email_templates.confirm.revert_every_language_message')
          : t('admin.email_templates.confirm.revert_message'),
        confirmLabel: t('admin.email_templates.actions.revert'),
        variant: 'destructive',
      },
      async () => {
        if (!forEveryLanguage) return revert.mutateAsync({ language, lock_version: lockVersion })

        // The shared version has no draft anyone edits here, so there is no
        // copy to check; its answer is for every language, so this language's
        // own state (and its draft) is read again instead.
        await revert.mutateAsync({ language: versionLanguage })
        const latest = await onFetchLatest()
        if (!latest) throw new Error(t('admin.errors.failed_to_load'))
        return latest
      },
    )

  const handleRestore = async (revisionId: string) => {
    const restored = await confirmAndApply(
      {
        title: t('admin.email_templates.confirm.restore_title'),
        message: t('admin.email_templates.confirm.restore_message'),
        confirmLabel: t('admin.email_templates.history.restore'),
        variant: dirty ? 'destructive' : 'default',
      },
      () =>
        // Restored into this language's draft, even from the shared version's history.
        restore.mutateAsync({ revisionId, language, lock_version: lockVersion ?? null }),
    )
    if (restored) setHistoryOpen(false)
  }

  const handleOverwrite = async () => {
    setConflict(null)
    const latest = await onFetchLatest()
    if (!latest) return
    const latestLockVersion = latest.draft?.lock_version
    setLockVersion(latestLockVersion)
    await saveDraft({ lockVersion: latestLockVersion })
  }

  const handleKeepMine = async () => {
    if (await saveDraft({ rebase: true })) setDiffOpen(false)
  }

  const handleStartOver = async () => {
    const version = { subject: template.default_subject ?? '', body: template.default_body }
    if (await saveDraft({ rebase: true, version })) {
      setSubject(version.subject)
      setBody(version.body)
      setDiffOpen(false)
    }
  }

  const preview = useLivePreview(
    template.id,
    { language, subject: isEmail ? subject : undefined, body },
    canEdit,
  )

  const handleSendTest = async () => {
    try {
      const { sent_to } = await sendTest.mutateAsync({
        language,
        body,
        ...(isEmail ? { subject } : {}),
        record_id: preview.recordId || undefined,
        email_key: preview.emailKey || undefined,
      })
      toastManager.add({
        type: 'success',
        title: t('admin.email_templates.messages.test_sent', { email: sent_to }),
      })
    } catch (error) {
      handleError(error)
    }
  }

  const shownProblems = problems.length > 0 ? problems : preview.problems
  const diagnostics = useMemo(
    () =>
      shownProblems
        .filter((problem) => !problem.email || problem.email === template.id)
        .map((problem) => ({ line: problem.line, message: problem.message })),
    [shownProblems, template.id],
  )

  const busy =
    save.isPending ||
    publish.isPending ||
    discard.isPending ||
    revert.isPending ||
    restore.isPending

  return (
    <ResourceLayout
      header={
        <PageHeader
          backTo="settings/emails/templates"
          title={emailTemplateName(t, template.key)}
          badges={<VersionBadge template={template} dirty={dirty} hasDraft={hasDraft} />}
          actions={
            canEdit && (
              <>
                <Button variant="outline" disabled={busy || !dirty} onClick={() => saveDraft()}>
                  {t('admin.email_templates.actions.save_draft')}
                </Button>
                <Button disabled={busy || (!dirty && !hasDraft)} onClick={handlePublish}>
                  {t('admin.email_templates.actions.publish')}
                </Button>
              </>
            )
          }
          dropdownItems={
            <>
              {canEdit && (
                <DropdownMenuItem disabled={sendTest.isPending} onClick={handleSendTest}>
                  <SendIcon className="size-4" />
                  {t('admin.email_templates.actions.send_test')}
                </DropdownMenuItem>
              )}
              <DropdownMenuItem onClick={() => setHistoryOpen(true)}>
                <HistoryIcon className="size-4" />
                {t('admin.email_templates.actions.history')}
              </DropdownMenuItem>
            </>
          }
          destructiveItems={
            canEdit && (
              <>
                {hasDraft && (
                  <DropdownMenuItem variant="destructive" disabled={busy} onClick={handleDiscard}>
                    <Trash2Icon className="size-4" />
                    {t('admin.email_templates.actions.discard_draft')}
                  </DropdownMenuItem>
                )}
                {(template.customized || hasDraft) && (
                  <DropdownMenuItem variant="destructive" disabled={busy} onClick={handleRevert}>
                    <RotateCcwIcon className="size-4" />
                    {t('admin.email_templates.actions.revert')}
                  </DropdownMenuItem>
                )}
              </>
            )
          }
        />
      }
      main={
        <div className="flex flex-col gap-4">
          {template.default_changed && template.base_body !== null && (
            <Alert variant="warning">
              <AlertTitle>{t('admin.email_templates.default_update.title')}</AlertTitle>
              <AlertDescription>
                {t('admin.email_templates.default_update.description')}
              </AlertDescription>
              <AlertAction>
                <Button size="sm" variant="outline" onClick={() => setDiffOpen(true)}>
                  {t('admin.email_templates.default_update.compare')}
                </Button>
              </AlertAction>
            </Alert>
          )}

          {forEveryLanguage && <EveryLanguageNotice language={language} />}

          {shownProblems.length > 0 && <EmailTemplateProblemsAlert problems={shownProblems} />}

          <div className="grid gap-4 xl:grid-cols-2">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between gap-4">
                <CardTitle>{t('admin.email_templates.editor.title')}</CardTitle>
                <LanguageSelect value={language} onChange={onLanguageChange} disabled={dirty} />
              </CardHeader>
              <CardContent className="flex flex-col gap-4">
                {isEmail && (
                  <Field>
                    <FieldLabel htmlFor="email-template-subject">
                      {t('admin.email_templates.editor.subject')}
                    </FieldLabel>
                    <Textarea
                      id="email-template-subject"
                      rows={2}
                      className="min-h-0 resize-y font-mono text-sm"
                      value={subject}
                      readOnly={!canEdit}
                      onChange={(event) => editSubject(event.target.value)}
                    />
                  </Field>
                )}
                <CodeEditor
                  ref={editorRef}
                  aria-label={t('admin.email_templates.editor.body')}
                  value={body}
                  onChange={editBody}
                  readOnly={!canEdit}
                  completions={preview.completions}
                  filters={FILTER_COMPLETIONS}
                  diagnostics={diagnostics}
                  onSave={() => canEdit && dirty && !busy && saveDraft()}
                  className="h-[36rem]"
                />
              </CardContent>
            </Card>

            <EmailTemplatePreviewCard template={template} preview={preview} />
          </div>

          <EmailTemplateVariablesCard
            templateId={template.id}
            onInsert={canEdit ? (text) => editorRef.current?.insert(text) : undefined}
          />

          <EmailTemplateHistorySheet
            open={historyOpen}
            onOpenChange={setHistoryOpen}
            revisions={revisions.data?.data}
            isLoading={revisions.isLoading}
            canRestore={canEdit}
            restoring={restore.isPending}
            onRestore={(revision) => handleRestore(revision.id)}
          />
          <DefaultDiffDialog
            open={diffOpen}
            onOpenChange={setDiffOpen}
            before={template.base_body ?? ''}
            after={template.default_body}
            pending={save.isPending}
            onKeepMine={handleKeepMine}
            onStartOver={handleStartOver}
          />
          <EmailTemplateConflictDialog
            message={conflict}
            onClose={() => setConflict(null)}
            onOverwrite={handleOverwrite}
            onReload={() => {
              setConflict(null)
              onReload()
            }}
          />
        </div>
      }
    />
  )
}

const FILTER_COMPLETIONS: CodeEditorCompletion[] = EMAIL_TEMPLATE_FILTERS.map((filter) => ({
  label: filter,
}))

function VersionBadge({
  template,
  dirty,
  hasDraft,
}: {
  template: EmailTemplate
  dirty: boolean
  hasDraft: boolean
}) {
  const { t } = useTranslation()

  if (dirty) return <Badge variant="warning">{t('admin.email_templates.badges.unsaved')}</Badge>
  if (hasDraft)
    return <Badge variant="info">{t('admin.email_templates.badges.showing_draft')}</Badge>
  if (template.customized) {
    return <Badge variant="success">{t('admin.email_templates.badges.showing_published')}</Badge>
  }
  return <Badge variant="outline">{t('admin.email_templates.badges.showing_default')}</Badge>
}

function LanguageSelect({
  value,
  onChange,
  disabled,
}: {
  value: string
  onChange: (value: string) => void
  disabled: boolean
}) {
  const { t } = useTranslation()
  const { locales } = useStore()
  const languageName = useDisplayName('language')
  const options = locales.map((code) => ({ value: code, label: languageName(code) ?? code }))

  return (
    <Select
      items={options}
      value={value}
      disabled={disabled}
      onValueChange={(next) => next && onChange(next as string)}
    >
      <SelectTrigger className="w-48" aria-label={t('admin.email_templates.editor.language')}>
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {options.map((option) => (
          <SelectItem key={option.value} value={option.value}>
            {option.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function EveryLanguageNotice({ language }: { language: string }) {
  const { t } = useTranslation()
  const languageName = useDisplayName('language')

  return (
    <Alert variant="info">
      <AlertDescription>
        {t('admin.email_templates.every_language.notice', {
          language: languageName(language) ?? language,
        })}
      </AlertDescription>
    </Alert>
  )
}
