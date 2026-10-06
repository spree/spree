import type { OauthApplication } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  Input,
  Label,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'

interface FormValues {
  name: string
  redirect_uri: string
}

/**
 * Registers an OAuth client, or edits one already registered.
 *
 * The callback comes from the client's own documentation — it is where
 * authorization codes are delivered, so a wrong one sends them to whoever
 * controls that host. The field says as much rather than leaving a merchant
 * to guess, and the server refuses anything that is not https.
 */
export function OauthApplicationSheet({
  application,
  open,
  onOpenChange,
}: {
  application?: OauthApplication
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const form = useForm<FormValues>({ defaultValues: { name: '', redirect_uri: '' } })

  useEffect(() => {
    if (!open) return
    form.reset({
      name: application?.name ?? '',
      redirect_uri: application?.redirect_uri ?? '',
    })
  }, [open, application, form])

  const save = useMutation({
    mutationFn: (values: FormValues) =>
      application
        ? adminClient.oauth.applications.update(application.id, values)
        : adminClient.oauth.applications.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['oauth-applications'] })
      onOpenChange(false)
    },
  })

  async function onSubmit(values: FormValues) {
    try {
      await save.mutateAsync(values)
    } catch (error) {
      if (!mapSpreeErrorsToForm(error, form.setError)) throw error
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {application
              ? t('admin.pages.settings.oauth_clients.form.edit_title')
              : t('admin.pages.settings.oauth_clients.form.create_title')}
          </SheetTitle>
          <SheetDescription>
            {t('admin.pages.settings.oauth_clients.form.description')}
          </SheetDescription>
        </SheetHeader>

        <form
          className="flex flex-1 flex-col gap-4 overflow-y-auto px-4"
          onSubmit={form.handleSubmit(onSubmit)}
        >
          {form.formState.errors.root && (
            <p className="text-destructive text-sm">{form.formState.errors.root.message}</p>
          )}

          <Field>
            <Label htmlFor="oauth-application-name">
              {t('admin.fields.oauth_application.name.label')}
            </Label>
            <Input
              id="oauth-application-name"
              {...form.register('name', { required: true })}
              aria-invalid={Boolean(form.formState.errors.name)}
              placeholder={t('admin.fields.oauth_application.name.placeholder')}
            />
            <FieldError>{form.formState.errors.name?.message}</FieldError>
          </Field>

          <Field>
            <Label htmlFor="oauth-application-redirect-uri">
              {t('admin.fields.oauth_application.redirect_uri.label')}
            </Label>
            <Input
              id="oauth-application-redirect-uri"
              {...form.register('redirect_uri', { required: true })}
              aria-invalid={Boolean(form.formState.errors.redirect_uri)}
              placeholder="https://example.com/oauth/callback"
            />
            <p className="text-muted-foreground text-xs">
              {t('admin.fields.oauth_application.redirect_uri.help')}
            </p>
            <FieldError>{form.formState.errors.redirect_uri?.message}</FieldError>
          </Field>

          <SheetFooter className="px-0">
            <Button type="submit" disabled={save.isPending}>
              {t('admin.common.save')}
            </Button>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.common.cancel')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
