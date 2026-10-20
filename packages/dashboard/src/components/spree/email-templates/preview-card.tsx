import type { EmailTemplate, EmailTemplatePreview } from '@spree/admin-sdk'
import { formatStoreDate, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Field,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Tabs,
  TabsList,
  TabsTrigger,
  useDebouncedValue,
} from '@spree/dashboard-ui'
import { MonitorIcon, SmartphoneIcon } from '@spree/dashboard-ui/icons'
import type { CodeEditorCompletion } from '@spree/dashboard-ui/ui/code-editor'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  type EmailTemplateProblem,
  templateProblems,
  useEmailTemplatePreview,
  useEmailTemplateSampleRecords,
  useEmailTemplates,
} from '../../../hooks/use-email-templates'
import { emailTemplateName } from '../../../lib/email-template-name'
import {
  documentedPaths,
  flattenVariables,
  templateVariables,
} from '../../../lib/email-template-variables'
import { EmailPreviewFrame, type EmailPreviewWidth } from './email-preview-frame'

/** How long typing pauses before a preview is rendered again. */
export const PREVIEW_DELAY_MS = 600

const WIDTHS = [
  { value: 'desktop', icon: MonitorIcon },
  { value: 'mobile', icon: SmartphoneIcon },
] as const

export interface LivePreview {
  data?: EmailTemplatePreview
  problems: EmailTemplateProblem[]
  unavailable?: string
  completions: CodeEditorCompletion[]
  recordId: string
  setRecordId: (value: string) => void
  emailKey: string
  setEmailKey: (value: string) => void
  /** Whether previews are rendered for this caller. */
  enabled: boolean
}

/**
 * Re-renders the template on the server once typing pauses. Only the latest
 * request's answer is kept, so a slow render never overwrites a newer one.
 */
export function useLivePreview(
  templateId: string,
  unsaved: { language: string; subject?: string; body: string },
  enabled: boolean,
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
    if (!enabled) return
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
  }, [request, mutateAsync, enabled])

  const completions = useMemo(() => {
    const documented = templateVariables(templateId)
    const descriptions = new Map(
      documented.map((variable) => [variable.name, t(variable.descriptionKey)]),
    )
    const fromPreview = flattenVariables(data?.variables ?? {}).map(({ path, sample }) => ({
      label: path,
      detail: sample.length > 40 ? `${sample.slice(0, 40)}…` : sample,
      info: descriptions.get(path),
    }))
    const known = new Set(fromPreview.map((completion) => completion.label))
    const documentedOnly = documentedPaths(templateId)
      .filter((path) => !known.has(path))
      .map((path) => ({ label: path, info: descriptions.get(path) }))
    return [...fromPreview, ...documentedOnly]
  }, [data, templateId, t])

  return {
    data,
    problems,
    unavailable: enabled ? unavailable : t('admin.email_templates.preview.needs_permission'),
    completions,
    recordId,
    setRecordId,
    emailKey,
    setEmailKey,
    enabled,
  }
}

export function EmailTemplatePreviewCard({
  template,
  preview,
}: {
  template: EmailTemplate
  preview: LivePreview
}) {
  const { t } = useTranslation()
  const [view, setView] = useState<'html' | 'text'>('html')
  const [width, setWidth] = useState<EmailPreviewWidth>('desktop')

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
          {WIDTHS.map(({ value, icon: Icon }) => (
            <Button
              key={value}
              size="icon-sm"
              variant={width === value ? 'outline' : 'ghost'}
              aria-pressed={width === value}
              aria-label={t(`admin.email_templates.preview.${value}`)}
              onClick={() => setWidth(value)}
            >
              <Icon className="size-4" />
            </Button>
          ))}
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="grid gap-3 sm:grid-cols-2">
          {template.kind !== 'email' && <ShownInField preview={preview} />}
          <RecordField template={template} preview={preview} />
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

/** Which email a layout or partial is previewed inside. */
function ShownInField({ preview }: { preview: LivePreview }) {
  const { t } = useTranslation()
  const { defaultLocale } = useStore()
  const { data: templates } = useEmailTemplates(defaultLocale)
  const emailOptions = (templates?.data ?? [])
    .filter((entry) => entry.kind === 'email')
    .map((entry) => ({ value: entry.id, label: emailTemplateName(t, entry.key) }))

  return (
    <Field>
      <FieldLabel htmlFor="email-template-preview-email">
        {t('admin.email_templates.preview.shown_in')}
      </FieldLabel>
      <Select
        items={emailOptions}
        value={preview.emailKey || preview.data?.email_key || ''}
        onValueChange={(value) => {
          preview.setEmailKey((value as string) ?? '')
          preview.setRecordId('')
        }}
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
  )
}

const LATEST = ''

/** Which of the store's latest records the preview is built from. */
function RecordField({ template, preview }: { template: EmailTemplate; preview: LivePreview }) {
  const { t } = useTranslation()
  const { timezone } = useStore()
  const { data: records } = useEmailTemplateSampleRecords(
    template.id,
    preview.emailKey,
    preview.enabled,
  )

  if (!records?.length) return null

  const options = [
    { value: LATEST, label: t('admin.email_templates.preview.latest_record') },
    ...records.map((record) => ({
      value: record.id,
      label: `${record.label} · ${formatStoreDate(record.created_at, timezone)}`,
    })),
  ]

  return (
    <Field>
      <FieldLabel htmlFor="email-template-preview-record">
        {t('admin.email_templates.preview.record')}
      </FieldLabel>
      <Select
        items={options}
        value={preview.recordId}
        onValueChange={(value) => preview.setRecordId((value as string) ?? LATEST)}
      >
        <SelectTrigger id="email-template-preview-record">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {options.map((option) => (
            <SelectItem key={option.value || 'latest'} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </Field>
  )
}
