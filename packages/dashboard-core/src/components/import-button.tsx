import type { Import, ImportType } from '@spree/admin-sdk'
import {
  Button,
  cn,
  Field,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { DownloadIcon, FileSpreadsheetIcon, UploadIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useCreateImport, useDownloadImportTemplate } from '../hooks/use-import'
import type { SubjectName } from '../lib/permissions'
import { Can } from './can'

const DELIMITERS = [
  { value: ',', labelKey: 'comma' },
  { value: ';', labelKey: 'semicolon' },
  { value: '|', labelKey: 'pipe' },
  { value: '\t', labelKey: 'tab' },
] as const

type Delimiter = (typeof DELIMITERS)[number]['value']

interface ImportButtonProps {
  /** Which dataset to import. Server validates against `Spree::Import.available_types`. */
  type: ImportType
  /**
   * CanCanCan subject gating the button — the *imported resource*
   * (e.g. `Subject.Product`), mirroring the server's `write_<resource>`
   * scope model. Purely UX; the backend authorizes every request.
   */
  subject: SubjectName
  /**
   * Receives the created import (in `mapping` state). The consumer opens the
   * wizard — typically a full-window dialog driven by an `?import=` search
   * param.
   */
  onCreated: (imp: Import) => void
  /** Label shown on the button. Defaults to the translated "Import" action. */
  label?: string
}

/**
 * Toolbar entry point for CSV imports: opens a Sheet with the upload form
 * (file, delimiter, template download). On success the sheet closes and the
 * created import is handed to `onCreated`.
 */
export function ImportButton({ type, subject, onCreated, label }: ImportButtonProps) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [file, setFile] = useState<File | null>(null)
  const [delimiter, setDelimiter] = useState<Delimiter>(',')
  const createImport = useCreateImport()
  const downloadTemplate = useDownloadImportTemplate()

  const delimiterOptions = DELIMITERS.map(({ value, labelKey }) => ({
    value,
    label: t(`admin.components.import_button.delimiters.${labelKey}`),
  }))

  function handleOpenChange(next: boolean) {
    setOpen(next)
    if (!next) setFile(null)
  }

  function handleSubmit() {
    if (!file || createImport.isPending) return

    createImport.mutate(
      { type, file, preferredDelimiter: delimiter },
      {
        onSuccess: (imp) => {
          handleOpenChange(false)
          onCreated(imp)
        },
        onError: (err) => {
          toast.error(
            t('admin.components.import_button.failed', {
              message: err instanceof Error ? err.message : String(err),
            }),
          )
        },
      },
    )
  }

  function handleTemplateDownload() {
    downloadTemplate.mutate(type, {
      onError: (err) => {
        toast.error(
          t('admin.components.import_button.template_failed', {
            message: err instanceof Error ? err.message : String(err),
          }),
        )
      },
    })
  }

  return (
    <Can I="create" a={subject}>
      <Button
        size="sm"
        variant="outline"
        className="h-[2.125rem]"
        onClick={() => setOpen(true)}
        disabled={createImport.isPending}
      >
        <UploadIcon className="size-4" />
        {label ?? t('admin.actions.import')}
      </Button>

      <Sheet open={open} onOpenChange={handleOpenChange}>
        <SheetContent className="sm:max-w-xl">
          <SheetHeader>
            <SheetTitle>{t('admin.components.import_button.title')}</SheetTitle>
            <SheetDescription>{t('admin.components.import_button.description')}</SheetDescription>
          </SheetHeader>

          <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
            {/* A <label> wrapping the file input: clicking anywhere opens the
                picker natively, no JS forwarding needed. */}
            <label
              className={cn(
                'flex cursor-pointer flex-col items-center justify-center gap-2 rounded-md border border-border border-dashed bg-muted/40 px-4 py-10 text-center transition-colors hover:bg-muted',
                file && 'border-solid',
              )}
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => {
                e.preventDefault()
                const dropped = e.dataTransfer.files?.[0]
                if (dropped) setFile(dropped)
              }}
            >
              <FileSpreadsheetIcon className="size-6 text-muted-foreground" />
              {file ? (
                <span className="font-medium text-sm">{file.name}</span>
              ) : (
                <span className="text-muted-foreground text-sm">
                  {t('admin.components.import_button.drop_label')}
                </span>
              )}
              <span className="mt-1 inline-flex h-8 items-center rounded-md border border-border bg-background px-3 font-medium text-sm shadow-xs">
                {t('admin.components.import_button.browse')}
              </span>
              <input
                type="file"
                accept=".csv,text/csv"
                className="hidden"
                onChange={(e) => {
                  const picked = e.target.files?.[0]
                  if (picked) setFile(picked)
                  e.target.value = ''
                }}
              />
            </label>

            <Field>
              <FieldLabel>{t('admin.components.import_button.delimiter_label')}</FieldLabel>
              <Select
                items={delimiterOptions}
                value={delimiter}
                onValueChange={(value) => setDelimiter(value as Delimiter)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {delimiterOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="self-start"
              onClick={handleTemplateDownload}
              disabled={downloadTemplate.isPending}
            >
              <DownloadIcon className="size-4" />
              {t('admin.components.import_button.download_template')}
            </Button>
          </div>

          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => handleOpenChange(false)}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button
              type="button"
              size="sm"
              onClick={handleSubmit}
              disabled={!file || createImport.isPending}
            >
              {createImport.isPending
                ? t('admin.components.import_button.uploading')
                : t('admin.components.import_button.submit')}
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>
    </Can>
  )
}
