import type { FieldValues, UseFormReturn } from 'react-hook-form'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

interface StickyFormFooterProps<TFieldValues extends FieldValues = FieldValues> {
  /** RHF form instance. Reads `formState.isDirty` / `isSubmitting`. */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<TFieldValues, any, any>
  /** Save button label. Default "Save". */
  saveLabel?: string
  /** Cancel button label. Default "Discard". */
  cancelLabel?: string
  /** Called when Discard is clicked. Default: `form.reset()`. */
  onCancel?: () => void
  /** Always render the footer (don't gate on isDirty). Useful for "create" forms. */
  alwaysVisible?: boolean
  className?: string
}

/**
 * Sticky save bar that appears at the bottom of the viewport while the form
 * has unsaved changes. Sits inside the form so its submit button triggers RHF.
 *
 * Replaces the legacy `data-controller="sticky"` save bar. Use in addition to
 * `<PageHeader actions={...}>` when forms are long enough that the top Save
 * button scrolls out of view.
 */
export function StickyFormFooter<TFieldValues extends FieldValues>({
  form,
  saveLabel = 'Save',
  cancelLabel = 'Discard',
  onCancel,
  alwaysVisible = false,
  className,
}: StickyFormFooterProps<TFieldValues>) {
  const { isDirty, isSubmitting } = form.formState

  if (!alwaysVisible && !isDirty) return null

  return (
    <div
      className={cn(
        'sticky bottom-0 -mx-4 mt-4 flex items-center justify-end gap-2 border-t border-border bg-background/90 px-4 py-3 backdrop-blur supports-[backdrop-filter]:bg-background/75',
        className,
      )}
    >
      <Button
        type="button"
        size="sm"
        variant="outline"
        onClick={onCancel ?? (() => form.reset())}
        disabled={isSubmitting}
      >
        {cancelLabel}
      </Button>
      <Button type="submit" size="sm" disabled={isSubmitting}>
        {isSubmitting ? 'Saving…' : saveLabel}
      </Button>
    </div>
  )
}
