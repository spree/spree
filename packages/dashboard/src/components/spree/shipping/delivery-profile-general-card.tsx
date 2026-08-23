import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryProfile } from '@spree/admin-sdk'
import { Can, mapSpreeErrorsToForm, Subject } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
  useConfirm,
} from '@spree/dashboard-ui'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useUpdateDeliveryProfile } from '../../../hooks/use-delivery-profiles'
import {
  type DeliveryProfileGeneralValues,
  deliveryProfileGeneralSchema,
} from '../../../schemas/delivery-profile'

/** Name, kind, and promotion to store default. */
export function DeliveryProfileGeneralCard({ profile }: { profile: DeliveryProfile }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const updateMutation = useUpdateDeliveryProfile(profile.id)

  const form = useForm<DeliveryProfileGeneralValues>({
    resolver: zodResolver(deliveryProfileGeneralSchema),
    defaultValues: { name: profile.name },
    values: { name: profile.name },
    resetOptions: { keepDirtyValues: true },
  })

  async function onSubmit(values: DeliveryProfileGeneralValues) {
    try {
      await updateMutation.mutateAsync({ name: values.name })
      form.reset(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  async function handleMakeDefault() {
    const ok = await confirm({
      title: t('admin.delivery_profiles.default_confirm.title'),
      message: t('admin.delivery_profiles.default_confirm.message', { name: profile.name }),
      confirmLabel: t('admin.delivery_profiles.make_default'),
    })
    if (!ok) return
    await updateMutation.mutateAsync({ default: true }).catch(() => undefined)
  }

  const { errors } = form.formState

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.delivery_profiles.detail.general_title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {errors.root?.message && (
          <p className="text-sm text-destructive" role="alert">
            {errors.root.message}
          </p>
        )}
        <Field>
          <FieldLabel htmlFor="profile-name">{t('admin.fields.name.label')}</FieldLabel>
          <Input
            id="profile-name"
            aria-invalid={!!errors.name || undefined}
            {...form.register('name')}
          />
          <FieldError errors={[errors.name]} />
        </Field>

        <Field>
          <FieldLabel>{t('admin.fields.delivery_profile.kind.label')}</FieldLabel>
          <div>
            <Badge variant="outline">
              {t(`admin.delivery_profiles.kinds.${profile.kind}`, {
                defaultValue: profile.kind,
              })}
            </Badge>
          </div>
          <span className="text-muted-foreground text-xs">
            {t('admin.delivery_profiles.kind_immutable_hint')}
          </span>
        </Field>

        <Field>
          <FieldLabel>{t('admin.delivery_profiles.default_badge')}</FieldLabel>
          {profile.default ? (
            <span className="text-muted-foreground text-xs">
              {t('admin.delivery_profiles.is_default_hint')}
            </span>
          ) : (
            <Can I="update" a={Subject.DeliveryProfile}>
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="self-start"
                onClick={handleMakeDefault}
                disabled={updateMutation.isPending}
              >
                {t('admin.delivery_profiles.make_default')}
              </Button>
            </Can>
          )}
        </Field>

        <Can I="update" a={Subject.DeliveryProfile}>
          <Button
            type="button"
            size="sm"
            className="self-start"
            onClick={form.handleSubmit(onSubmit)}
            disabled={form.formState.isSubmitting || !form.formState.isDirty}
          >
            {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </Can>
      </CardContent>
    </Card>
  )
}
