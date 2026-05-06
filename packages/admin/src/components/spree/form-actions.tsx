import { Loader2Icon } from 'lucide-react'
import { useEffect } from 'react'
import { type FieldValues, type UseFormReturn, useFormState } from 'react-hook-form'
import { Button } from '@/components/ui/button'

/**
 * Submit button wired to a `react-hook-form` instance. Always rendered,
 * disabled until the form is dirty. Replaces the legacy "footer pops up
 * when something changes" pattern with the always-visible header pattern
 * Linear and modern Shopify use.
 *
 * Reads `isDirty` and `isSubmitting` from the RHF form state via
 * `useFormState`, so the button re-renders independently of the parent page
 * and won't churn on every keystroke.
 *
 * Uses `<button type="submit">` and relies on the surrounding `<form>` to
 * dispatch submission — same flow as the legacy sticky footer. ⌘S keyboard
 * submission is handled separately by `useFormSubmitShortcut`.
 */
export function FormSaveButton<TFieldValues extends FieldValues>({
  form,
  label = 'Save',
  savingLabel = 'Saving…',
}: {
  form: UseFormReturn<TFieldValues, any, any>
  label?: string
  savingLabel?: string
}) {
  const { isDirty, isSubmitting } = useFormState({ control: form.control })

  return (
    <Button type="submit" size="sm" disabled={!isDirty || isSubmitting}>
      {isSubmitting && <Loader2Icon className="animate-spin" />}
      {isSubmitting ? savingLabel : label}
    </Button>
  )
}

/**
 * Discard button wired to a `react-hook-form` instance. Renders only when
 * the form is dirty (so the header stays uncluttered for read-only pages).
 *
 * Calls `form.reset()` by default — pass `onDiscard` to override (e.g., to
 * reset to a freshly-fetched server value rather than the original mount
 * defaults).
 */
export function FormDiscardButton<TFieldValues extends FieldValues>({
  form,
  label = 'Discard',
  onDiscard,
}: {
  form: UseFormReturn<TFieldValues, any, any>
  label?: string
  onDiscard?: () => void
}) {
  const { isDirty, isSubmitting } = useFormState({ control: form.control })

  if (!isDirty) return null

  return (
    <Button
      type="button"
      size="sm"
      variant="outline"
      disabled={isSubmitting}
      onClick={onDiscard ?? (() => form.reset())}
    >
      {label}
    </Button>
  )
}

/**
 * Convenience: render Discard + Save side-by-side. Most pages just want both.
 */
export function FormActions<TFieldValues extends FieldValues>({
  form,
  saveLabel,
  savingLabel,
  discardLabel,
  onDiscard,
}: {
  form: UseFormReturn<TFieldValues, any, any>
  saveLabel?: string
  savingLabel?: string
  discardLabel?: string
  onDiscard?: () => void
}) {
  return (
    <>
      <FormDiscardButton form={form} label={discardLabel} onDiscard={onDiscard} />
      <FormSaveButton form={form} label={saveLabel} savingLabel={savingLabel} />
    </>
  )
}

/**
 * Bind ⌘S / Ctrl+S to submit a `react-hook-form` instance. Mount once per
 * form. Skips when the form is pristine or already submitting — same gate
 * as the visual Save button. Schema validation still runs inside
 * `form.handleSubmit`, so invalid input rejects on its own without us
 * needing to read `isValid` (which is unreliable under the default
 * `onSubmit` validation mode).
 *
 * Also wires `beforeunload` to warn if the user closes the tab or navigates
 * away while the form is dirty. (TanStack Router internal navigation is not
 * intercepted — the SPA's own dirty-route guard would belong elsewhere.)
 */
export function useFormSubmitShortcut<TFieldValues extends FieldValues>(
  form: UseFormReturn<TFieldValues, any, any>,
  onSubmit: (values: TFieldValues) => void | Promise<void>,
) {
  const { isDirty, isSubmitting } = useFormState({ control: form.control })

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (event.key !== 's' && event.key !== 'S') return
      if (!(event.metaKey || event.ctrlKey)) return
      event.preventDefault()
      if (!isDirty || isSubmitting) return
      void form.handleSubmit(onSubmit)()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [form, onSubmit, isDirty, isSubmitting])

  useEffect(() => {
    if (!isDirty) return
    const handler = (event: BeforeUnloadEvent) => {
      event.preventDefault()
    }
    window.addEventListener('beforeunload', handler)
    return () => window.removeEventListener('beforeunload', handler)
  }, [isDirty])
}
