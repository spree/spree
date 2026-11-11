import { zodResolver } from '@hookform/resolvers/zod'
import type { Seller, SellerUpdateParams } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  FieldGroup,
  useConfirm,
} from '@spree/dashboard-ui'
import type { ReactNode } from 'react'
import { type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useUpdateSeller } from '../../../hooks/use-sellers'
import { type SellerFormValues, sellerFormSchema, sellerFormValues } from '../../../schemas/seller'

/**
 * One part of a seller edited on its own, in its card or in a dialog.
 *
 * `toParams` picks only this part's own fields: every part shares one schema,
 * and sending the whole form would post its untouched values over another
 * part's edits.
 *
 * `dialog` opens it in a dialog of that title instead, with the buttons in
 * the footer. Either way Save waits for a change, and leaving with one asks
 * first.
 */
export function SellerInlineForm({
  seller,
  label,
  toParams,
  onDone,
  dialog,
  children,
}: {
  seller: Seller
  label: string
  toParams: (values: SellerFormValues) => SellerUpdateParams
  onDone: () => void
  dialog?: { title: string }
  children: (form: UseFormReturn<SellerFormValues>) => ReactNode
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const updateMutation = useUpdateSeller(seller.id)

  const defaultValues = sellerFormValues(seller)
  const form = useForm<SellerFormValues>({
    // Every part shares one schema, but only what the operator changed here
    // may block Save: an untouched value came from the server, which already
    // accepted it, and its field may not even be on screen.
    resolver: async (values, context, options) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const result = await (zodResolver(sellerFormSchema) as any)(values, context, options)
      const errors = Object.fromEntries(
        Object.entries(result.errors).filter(
          ([field]) =>
            values[field as keyof SellerFormValues] !==
            defaultValues[field as keyof SellerFormValues],
        ),
      )
      if (Object.keys(errors).length > 0) return { values: {}, errors }
      return Object.keys(result.errors).length > 0 ? { values, errors: {} } : result
    },
    defaultValues,
  })

  async function onSubmit(values: SellerFormValues) {
    try {
      await updateMutation.mutateAsync(toParams(values))
      onDone()
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors, isDirty, isSubmitting } = form.formState

  async function cancel() {
    if (isSubmitting) return
    if (isDirty) {
      const ok = await confirm({
        title: t('admin.actions.discard_changes'),
        message: t('admin.common.unsaved_changes'),
        variant: 'destructive',
        confirmLabel: t('admin.actions.discard'),
      })
      if (!ok) return
    }
    onDone()
  }

  const fields = (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-destructive text-base" role="alert">
          {errors.root.message}
        </p>
      )}
      {children(form)}
    </FieldGroup>
  )
  const size = dialog ? 'default' : 'sm'
  const buttons = (
    <>
      <Button type="button" variant="outline" size={size} disabled={isSubmitting} onClick={cancel}>
        {t('admin.actions.cancel')}
      </Button>
      <Button type="submit" size={size} disabled={!isDirty || isSubmitting}>
        {isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
      </Button>
    </>
  )

  if (dialog) {
    return (
      <Dialog open onOpenChange={(open) => !open && cancel()}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{dialog.title}</DialogTitle>
          </DialogHeader>
          <form
            aria-label={label}
            onSubmit={form.handleSubmit(onSubmit)}
            className="flex min-h-0 flex-1 flex-col"
          >
            <DialogBody>{fields}</DialogBody>
            <DialogFooter>{buttons}</DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    )
  }

  return (
    <form aria-label={label} onSubmit={form.handleSubmit(onSubmit)} className="flex flex-col gap-4">
      {fields}
      <div className="flex justify-end gap-2">{buttons}</div>
    </form>
  )
}
