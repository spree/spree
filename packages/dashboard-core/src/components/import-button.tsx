import {
  Button,
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
  toastManager,
} from '@spree/dashboard-ui'
import { DownloadIcon, FileSpreadsheetIcon, UploadIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { PanelImport } from '../api-client'
import {
  useCreateImport,
  useDownloadImportExample,
  useDownloadImportTemplate,
} from '../hooks/use-import'
import type { SubjectName } from '../lib/permissions'
import { hasSampleCsv } from '../lib/sample-csv'
import { Can } from './can'
import { EMPTY_FILE_UPLOAD_VALUE, FileUploadField, type FileUploadValue } from './file-upload-field'

const DELIMITERS = [
  { value: ',', labelKey: 'comma' },
  { value: ';', labelKey: 'semicolon' },
  { value: '|', labelKey: 'pipe' },
  { value: '\t', labelKey: 'tab' },
] as const

type Delimiter = (typeof DELIMITERS)[number]['value']

interface ImportButtonProps {
  /** Which dataset to import. Server validates against `Spree::Import.available_types`. */
  type: string
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
  onCreated: (imp: PanelImport) => void
  /** Label shown on the button. Defaults to the translated "Import" action. */
  label?: string
  /** Optional variant for the button. Defaults to "outline". */
  variant?: 'default' | 'outline' | 'ghost'
  /** Optional size for the button. Defaults to "sm". */
  size?: 'sm' | 'default' | 'lg'
  /**
   * Path the import-done email links back to, relative to this panel's origin.
   * Defaults to the operator dashboard's imports view under the current
   * tenant; a panel filing that page elsewhere passes its own.
   */
  resultsPath?: string
}

/**
 * Toolbar entry point for CSV imports: opens a Sheet with the upload form
 * (file, delimiter, template download). The CSV direct-uploads on pick via
 * `FileUploadField`; submitting creates the import from the signed blob id
 * and hands it to `onCreated`.
 */
export function ImportButton({
  type,
  subject,
  onCreated,
  label,
  variant,
  size,
  resultsPath,
}: ImportButtonProps) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [file, setFile] = useState<FileUploadValue>(EMPTY_FILE_UPLOAD_VALUE)
  const [delimiter, setDelimiter] = useState<Delimiter>(',')
  const createImport = useCreateImport()
  const downloadTemplate = useDownloadImportTemplate()
  const downloadExample = useDownloadImportExample()
  const hasExample = hasSampleCsv(type)

  const delimiterOptions = DELIMITERS.map(({ value, labelKey }) => ({
    value,
    label: t(`admin.components.import_button.delimiters.${labelKey}`),
  }))

  function handleOpenChange(next: boolean) {
    setOpen(next)
    if (!next) setFile(EMPTY_FILE_UPLOAD_VALUE)
  }

  function handleSubmit() {
    if (!file.signedId || createImport.isPending) return

    createImport.mutate(
      { type, signedId: file.signedId, preferredDelimiter: delimiter, resultsPath },
      {
        onSuccess: (imp) => {
          handleOpenChange(false)
          onCreated(imp)
        },
        onError: (err) => {
          toastManager.add({
            type: 'error',
            title: t('admin.components.import_button.failed', {
              message: err instanceof Error ? err.message : String(err),
            }),
          })
        },
      },
    )
  }

  function handleTemplateDownload() {
    downloadTemplate.mutate(type, {
      onError: (err) => {
        toastManager.add({
          type: 'error',
          title: t('admin.components.import_button.template_failed', {
            message: err instanceof Error ? err.message : String(err),
          }),
        })
      },
    })
  }

  function handleExampleDownload() {
    downloadExample.mutate(type, {
      onError: (err) => {
        toastManager.add({
          type: 'error',
          title: t('admin.components.import_button.example_failed', {
            message: err instanceof Error ? err.message : String(err),
          }),
        })
      },
    })
  }

  return (
    <Can I="create" a={subject}>
      {/* Desktop only: the wizard needs a file from disk and column
          mapping across a wide grid, neither of which works on a phone. */}
      <Button
        size={size ?? 'sm'}
        variant={variant ?? 'outline'}
        className="hidden h-[2.125rem] lg:inline-flex"
        onClick={() => setOpen(true)}
        disabled={createImport.isPending}
      >
        <UploadIcon />
        {label ?? t('admin.actions.import')}
      </Button>

      <Sheet open={open} onOpenChange={handleOpenChange}>
        <SheetContent className="sm:max-w-xl">
          <SheetHeader>
            <SheetTitle>{t('admin.components.import_button.title')}</SheetTitle>
            <SheetDescription>{t('admin.components.import_button.description')}</SheetDescription>
          </SheetHeader>

          <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FileUploadField
              value={file}
              onChange={setFile}
              accept=".csv,text/csv"
              variant="file"
              icon={<FileSpreadsheetIcon />}
              dropLabel={t('admin.components.import_button.drop_label')}
              // Windows browsers report `.csv` as `application/vnd.ms-excel`,
              // which the server's content-type validation rejects.
              transformFile={(picked) => new File([picked], picked.name, { type: 'text/csv' })}
            />

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

            <div className="flex flex-col items-start gap-1">
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={handleTemplateDownload}
                disabled={downloadTemplate.isPending}
              >
                <DownloadIcon className="size-4" />
                {t('admin.components.import_button.download_template')}
              </Button>

              {/* The populated counterpart to the headers-only template above.
                  Fetched through the API so the file matches the installed
                  Spree version's schema. */}
              {hasExample && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={handleExampleDownload}
                  disabled={downloadExample.isPending}
                >
                  <FileSpreadsheetIcon className="size-4" />
                  {t('admin.components.import_button.download_example')}
                </Button>
              )}
            </div>
          </div>

          <SheetFooter>
            <Button type="button" variant="outline" onClick={() => handleOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button
              type="button"
              onClick={handleSubmit}
              disabled={!file.signedId || createImport.isPending}
            >
              {createImport.isPending
                ? t('admin.actions.creating')
                : t('admin.components.import_button.submit')}
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>
    </Can>
  )
}
