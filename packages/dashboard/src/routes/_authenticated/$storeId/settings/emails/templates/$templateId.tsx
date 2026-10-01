import { type EmailTemplate, type EmailTemplatePreview, SpreeError } from '@spree/admin-sdk'
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
  CardDescription,
  CardHeader,
  CardTitle,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DropdownMenuItem,
  ErrorState,
  Field,
  FieldLabel,
  Input,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  Tabs,
  TabsList,
  TabsTrigger,
  toastManager,
  useConfirm,
  useDebouncedValue,
} from '@spree/dashboard-ui'
import {
  HistoryIcon,
  MonitorIcon,
  RotateCcwIcon,
  SendIcon,
  SmartphoneIcon,
  Trash2Icon,
} from '@spree/dashboard-ui/icons'
import { CodeEditor, type CodeEditorCompletion } from '@spree/dashboard-ui/ui/code-editor'
import { createFileRoute } from '@tanstack/react-router'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { DefaultDiffDialog } from '../../../../../../components/spree/email-templates/default-diff-dialog'
import {
  EmailPreviewFrame,
  type EmailPreviewWidth,
} from '../../../../../../components/spree/email-templates/email-preview-frame'
import { EmailTemplateHistorySheet } from '../../../../../../components/spree/email-templates/history-sheet'
import {
  type EmailTemplateProblem,
  templateProblems,
  useDiscardEmailTemplateDraft,
  useEmailTemplate,
  useEmailTemplatePreview,
  useEmailTemplateRevisions,
  useEmailTemplates,
  usePublishEmailTemplate,
  useRestoreEmailTemplateRevision,
  useRevertEmailTemplate,
  useSaveEmailTemplateDraft,
  useSendTestEmail,
} from '../../../../../../hooks/use-email-templates'
import { emailTemplateName } from '../../../../../../lib/email-template-name'
import {
  EMAIL_TEMPLATE_FILTERS,
  EMAIL_TEMPLATE_VARIABLES,
  type EmailTemplateVariable,
  flattenVariables,
  SHARED_EMAIL_VARIABLES,
} from '../../../../../../lib/email-template-variables'

export const Route = createFileRoute(
  '/_authenticated/$storeId/settings/emails/templates/$templateId',
)({
  component: EmailTemplateEditorPage,
})

const ANY_LANGUAGE = 'any'
const PREVIEW_DELAY_MS = 600

function EmailTemplateEditorPage() {
  const { t } = useTranslation()
  const { templateId } = Route.useParams()
  const [language, setLanguage] = useState(ANY_LANGUAGE)
  const [reloads, setReloads] = useState(0)
  const { data: template, isLoading, error, refetch } = useEmailTemplate(templateId, language)

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
}: {
  template: EmailTemplate
  language: string
  onLanguageChange: (language: string) => void
  onReload: () => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { permissions } = usePermissions()
  const canEdit = permissions.can('update', Subject.EmailTemplate)
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

  const save = useSaveEmailTemplateDraft(template.id)
  const discard = useDiscardEmailTemplateDraft(template.id)
  const publish = usePublishEmailTemplate(template.id)
  const revert = useRevertEmailTemplate(template.id)
  const restore = useRestoreEmailTemplateRevision(template.id)
  const sendTest = useSendTestEmail(template.id)
  const revisions = useEmailTemplateRevisions(template.id, language, historyOpen)

  const applyResponse = useCallback((next: EmailTemplate) => {
    const version = startingVersion(next)
    setSaved(version)
    setSubject(version.subject)
    setBody(version.body)
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

  const saveDraft = async (extra: { rebase?: boolean; version?: Version } = {}) => {
    const version = extra.version ?? { subject, body }
    try {
      const next = await save.mutateAsync({
        language,
        body: version.body,
        ...(isEmail ? { subject: version.subject } : {}),
        lock_version: lockVersion,
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
    if ((dirty || !hasDraft) && !(await saveDraft())) return
    try {
      applyResponse(await publish.mutateAsync(language))
    } catch (error) {
      handleError(error)
    }
  }

  const handleDiscard = async () => {
    const confirmed = await confirm({
      title: t('admin.email_templates.confirm.discard_title'),
      message: t('admin.email_templates.confirm.discard_message'),
      confirmLabel: t('admin.email_templates.actions.discard_draft'),
      variant: 'destructive',
    })
    if (!confirmed) return
    try {
      applyResponse(await discard.mutateAsync(language))
    } catch {
      // The mutation already reported the failure.
    }
  }

  const handleRevert = async () => {
    const confirmed = await confirm({
      title: t('admin.email_templates.confirm.revert_title'),
      message: t('admin.email_templates.confirm.revert_message'),
      confirmLabel: t('admin.email_templates.actions.revert'),
      variant: 'destructive',
    })
    if (!confirmed) return
    try {
      applyResponse(await revert.mutateAsync(language))
    } catch {
      // The mutation already reported the failure.
    }
  }

  const handleRestore = async (revisionId: string) => {
    const confirmed = await confirm({
      title: t('admin.email_templates.confirm.restore_title'),
      message: t('admin.email_templates.confirm.restore_message'),
      confirmLabel: t('admin.email_templates.history.restore'),
      variant: dirty ? 'destructive' : 'default',
    })
    if (!confirmed) return
    try {
      applyResponse(await restore.mutateAsync({ revisionId, language, lock_version: lockVersion }))
      setHistoryOpen(false)
    } catch (error) {
      handleError(error)
    }
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

  const preview = useLivePreview(template.id, {
    language,
    subject: isEmail ? subject : undefined,
    body,
  })

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
  const diagnostics = shownProblems
    .filter((problem) => !problem.email || problem.email === template.id)
    .map((problem) => ({ line: problem.line, message: problem.message }))

  const busy = save.isPending || publish.isPending || discard.isPending || revert.isPending

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

          {shownProblems.length > 0 && <ProblemsAlert problems={shownProblems} />}

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
                    <Input
                      id="email-template-subject"
                      value={subject}
                      readOnly={!canEdit}
                      onChange={(event) => setSubject(event.target.value)}
                    />
                  </Field>
                )}
                <CodeEditor
                  aria-label={t('admin.email_templates.editor.body')}
                  value={body}
                  onChange={setBody}
                  readOnly={!canEdit}
                  completions={preview.completions}
                  filters={FILTER_COMPLETIONS}
                  diagnostics={diagnostics}
                  onSave={() => canEdit && dirty && saveDraft()}
                  className="h-[36rem]"
                />
              </CardContent>
            </Card>

            <PreviewCard template={template} preview={preview} />
          </div>

          <VariablesCard templateId={template.id} />

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
          <ConflictDialog
            message={conflict}
            onClose={() => setConflict(null)}
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
  const options = [
    { value: ANY_LANGUAGE, label: t('admin.email_templates.languages.any') },
    ...locales.map((code) => ({ value: code, label: languageName(code) ?? code })),
  ]

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

function ProblemsAlert({ problems }: { problems: EmailTemplateProblem[] }) {
  const { t } = useTranslation()

  return (
    <Alert variant="destructive">
      <AlertTitle>{t('admin.email_templates.problems.title')}</AlertTitle>
      <AlertDescription>
        <ul className="list-disc pl-4">
          {problems.map((problem) => (
            <li key={`${problem.email}:${problem.line}:${problem.message}`}>
              {problem.email && `${emailTemplateName(t, problem.email.replace(/\./g, '/'))}: `}
              {problem.line
                ? t('admin.email_templates.problems.on_line', {
                    line: problem.line,
                    message: problem.message,
                  })
                : problem.message}
            </li>
          ))}
        </ul>
      </AlertDescription>
    </Alert>
  )
}

interface LivePreview {
  data?: EmailTemplatePreview
  problems: EmailTemplateProblem[]
  unavailable?: string
  completions: CodeEditorCompletion[]
  recordId: string
  setRecordId: (value: string) => void
  emailKey: string
  setEmailKey: (value: string) => void
}

/**
 * Re-renders the template on the server once typing pauses. Only the latest
 * request's answer is kept, so a slow render never overwrites a newer one.
 */
function useLivePreview(
  templateId: string,
  unsaved: { language: string; subject?: string; body: string },
): LivePreview {
  const { t } = useTranslation()
  const [recordId, setRecordId] = useState('')
  const [emailKey, setEmailKey] = useState('')
  const [data, setData] = useState<EmailTemplatePreview>()
  const [problems, setProblems] = useState<EmailTemplateProblem[]>([])
  const [unavailable, setUnavailable] = useState<string>()
  const { mutateAsync } = useEmailTemplatePreview(templateId)
  const latest = useRef(0)

  const request = useDebouncedValue(
    JSON.stringify({
      ...unsaved,
      record_id: recordId || undefined,
      email_key: emailKey || undefined,
    }),
    PREVIEW_DELAY_MS,
  )

  useEffect(() => {
    const id = ++latest.current
    mutateAsync(JSON.parse(request))
      .then((result) => {
        if (id !== latest.current) return
        setData(result)
        setProblems([])
        setUnavailable(undefined)
      })
      .catch((error: unknown) => {
        if (id !== latest.current) return
        const listed = templateProblems(error)
        setProblems(listed)
        setUnavailable(listed.length > 0 ? undefined : (error as Error).message)
      })
  }, [request, mutateAsync])

  const completions = useMemo(() => {
    const documented = [...(EMAIL_TEMPLATE_VARIABLES[templateId] ?? []), ...SHARED_EMAIL_VARIABLES]
    const descriptions = new Map(
      documented.map((variable) => [variable.name, t(variable.descriptionKey)]),
    )
    const fromPreview = flattenVariables(data?.variables ?? {}).map(({ path, sample }) => ({
      label: path,
      detail: sample.length > 40 ? `${sample.slice(0, 40)}…` : sample,
      info: descriptions.get(path),
    }))
    const known = new Set(fromPreview.map((completion) => completion.label))
    const documentedOnly = documented
      .filter((variable) => !known.has(variable.name))
      .map((variable) => ({ label: variable.name, info: descriptions.get(variable.name) }))
    return [...fromPreview, ...documentedOnly]
  }, [data, templateId, t])

  return { data, problems, unavailable, completions, recordId, setRecordId, emailKey, setEmailKey }
}

function PreviewCard({ template, preview }: { template: EmailTemplate; preview: LivePreview }) {
  const { t } = useTranslation()
  const [view, setView] = useState<'html' | 'text'>('html')
  const [width, setWidth] = useState<EmailPreviewWidth>('desktop')
  const { data: templates } = useEmailTemplates()
  const emailOptions = (templates?.data ?? [])
    .filter((entry) => entry.kind === 'email')
    .map((entry) => ({ value: entry.id, label: emailTemplateName(t, entry.key) }))

  return (
    <Card>
      <CardHeader className="flex flex-row flex-wrap items-center justify-between gap-2">
        <div className="flex flex-col gap-1">
          <CardTitle>{t('admin.email_templates.preview.title')}</CardTitle>
          {preview.data && (
            <CardDescription className="truncate">
              {t('admin.email_templates.preview.subject', { subject: preview.data.subject })}
            </CardDescription>
          )}
        </div>
        <div className="flex items-center gap-2">
          <Tabs value={view} onValueChange={(value) => setView(value as 'html' | 'text')}>
            <TabsList>
              <TabsTrigger value="html">{t('admin.email_templates.preview.html')}</TabsTrigger>
              <TabsTrigger value="text">{t('admin.email_templates.preview.text')}</TabsTrigger>
            </TabsList>
          </Tabs>
          <Button
            size="icon-sm"
            variant={width === 'desktop' ? 'outline' : 'ghost'}
            aria-pressed={width === 'desktop'}
            aria-label={t('admin.email_templates.preview.desktop')}
            onClick={() => setWidth('desktop')}
          >
            <MonitorIcon className="size-4" />
          </Button>
          <Button
            size="icon-sm"
            variant={width === 'mobile' ? 'outline' : 'ghost'}
            aria-pressed={width === 'mobile'}
            aria-label={t('admin.email_templates.preview.mobile')}
            onClick={() => setWidth('mobile')}
          >
            <SmartphoneIcon className="size-4" />
          </Button>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="grid gap-3 sm:grid-cols-2">
          {template.kind !== 'email' && (
            <Field>
              <FieldLabel htmlFor="email-template-preview-email">
                {t('admin.email_templates.preview.shown_in')}
              </FieldLabel>
              <Select
                items={emailOptions}
                value={preview.emailKey || preview.data?.email_key || ''}
                onValueChange={(value) => preview.setEmailKey((value as string) ?? '')}
              >
                <SelectTrigger id="email-template-preview-email">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {emailOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
          )}
          <Field>
            <FieldLabel htmlFor="email-template-preview-record">
              {t('admin.email_templates.preview.record')}
            </FieldLabel>
            <Input
              id="email-template-preview-record"
              placeholder={t('admin.email_templates.preview.record_placeholder')}
              value={preview.recordId}
              onChange={(event) => preview.setRecordId(event.target.value.trim())}
            />
          </Field>
        </div>
        {preview.unavailable ? (
          <p className="rounded-md border border-border p-4 text-sm text-muted-foreground">
            {preview.unavailable}
          </p>
        ) : (
          <EmailPreviewFrame
            html={preview.data?.html}
            text={preview.data?.text}
            view={view}
            width={width}
            className="h-[36rem]"
          />
        )}
      </CardContent>
    </Card>
  )
}

function VariablesCard({ templateId }: { templateId: string }) {
  const { t } = useTranslation()
  const variables: EmailTemplateVariable[] = [
    ...(EMAIL_TEMPLATE_VARIABLES[templateId] ?? []),
    ...SHARED_EMAIL_VARIABLES,
  ]

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.email_templates.variables.title')}</CardTitle>
        <CardDescription>{t('admin.email_templates.variables.description')}</CardDescription>
      </CardHeader>
      <CardContent>
        <dl className="grid gap-3 sm:grid-cols-2">
          {variables.map((variable) => (
            <div key={variable.name} className="flex flex-col gap-1">
              <dt className="font-mono text-sm">{`{{ ${variable.name} }}`}</dt>
              <dd className="text-sm text-muted-foreground">{t(variable.descriptionKey)}</dd>
              {variable.fields && (
                <dd className="flex flex-wrap gap-1">
                  {variable.fields.map((field) => (
                    <code key={field} className="rounded bg-muted px-1.5 py-0.5 text-xs">
                      {`${variable.name}.${field}`}
                    </code>
                  ))}
                </dd>
              )}
            </div>
          ))}
        </dl>
      </CardContent>
    </Card>
  )
}

function ConflictDialog({
  message,
  onReload,
  onClose,
}: {
  message: string | null
  onReload: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()

  return (
    <Dialog open={!!message} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.email_templates.conflict.title')}</DialogTitle>
          <DialogDescription>{message}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('admin.email_templates.conflict.keep_editing')}
          </Button>
          <Button variant="destructive" onClick={onReload}>
            {t('admin.email_templates.conflict.reload')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
