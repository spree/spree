import { zodResolver } from '@hookform/resolvers/zod'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Textarea,
} from '@spree/dashboard-ui'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'

const saveReportSchema = z.object({
  name: z.string().trim().min(1),
  description: z.string().trim().optional(),
})

export type SaveReportValues = z.infer<typeof saveReportSchema>

interface SaveReportDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description?: string
  submitLabel: string
  defaultValues?: Partial<SaveReportValues>
  onSubmit: (values: SaveReportValues) => Promise<unknown>
}

/**
 * Name + description prompt shared by "save", "save a copy" and "rename".
 * Mount it only while open — the form's defaults are read once.
 */
export function SaveReportDialog({
  open,
  onOpenChange,
  title,
  description,
  submitLabel,
  defaultValues,
  onSubmit,
}: SaveReportDialogProps) {
  const { t } = useTranslation()
  const form = useForm<SaveReportValues>({
    resolver: zodResolver(saveReportSchema),
    defaultValues: { name: '', description: '', ...defaultValues },
  })

  async function handleSubmit(values: SaveReportValues) {
    try {
      await onSubmit(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form onSubmit={form.handleSubmit(handleSubmit)}>
          <DialogHeader>
            <DialogTitle>{title}</DialogTitle>
            {description && <DialogDescription>{description}</DialogDescription>}
          </DialogHeader>
          <DialogBody>
            <FieldGroup>
              {form.formState.errors.root?.message && (
                <p className="text-sm text-destructive" role="alert">
                  {form.formState.errors.root.message}
                </p>
              )}
              <Field>
                <FieldLabel htmlFor="report-name">
                  {t('admin.reports.save_dialog.name_label')}
                </FieldLabel>
                <Input
                  id="report-name"
                  autoFocus
                  aria-invalid={!!form.formState.errors.name}
                  {...form.register('name')}
                />
                <FieldError errors={[form.formState.errors.name]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="report-description">
                  {t('admin.reports.save_dialog.description_label')}
                </FieldLabel>
                <Textarea id="report-description" rows={3} {...form.register('description')} />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {submitLabel}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
