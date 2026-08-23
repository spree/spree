import type { Integration, IntegrationTypeDefinition } from '@spree/admin-sdk'
import { Can, defaultPreferences, PreferencesForm, Subject } from '@spree/dashboard-core'
import {
  Button,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
  useConfirm,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCreateIntegration,
  useDeleteIntegration,
  useTestIntegration,
  useUpdateIntegration,
} from '../../../hooks/use-integrations'

/**
 * Connect/configure sheet for one integration type. Shared between the
 * integrations gallery and inline-connect flows (a delivery method picking a
 * carrier rate provider can connect its integration without leaving the
 * form).
 */
export function ConfigureIntegrationSheet({
  type,
  integration,
  open,
  onOpenChange,
}: {
  type: IntegrationTypeDefinition
  integration?: Integration
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const createMutation = useCreateIntegration()
  const updateMutation = useUpdateIntegration(integration?.id ?? '')
  const deleteMutation = useDeleteIntegration()
  const testMutation = useTestIntegration()

  // Seeded once per mount — the parent keys this sheet by type + record, so
  // switching integrations remounts with fresh state.
  const [preferences, setPreferences] = useState<Record<string, unknown>>(() =>
    integration
      ? ((integration.preferences as Record<string, unknown>) ?? {})
      : defaultPreferences(type.preference_schema),
  )
  const [active, setActive] = useState(integration?.active ?? false)
  const [submitError, setSubmitError] = useState<string | null>(null)

  const saving = createMutation.isPending || updateMutation.isPending

  async function handleSave() {
    setSubmitError(null)
    try {
      if (integration) {
        await updateMutation.mutateAsync({ active, preferences })
      } else {
        await createMutation.mutateAsync({ type: type.type, active, preferences })
      }
      onOpenChange(false)
    } catch (err) {
      // Activation failures come back as a 422 on `active` with the seller's
      // message — surface it inline, where the admin can act on it.
      setSubmitError(err instanceof Error ? err.message : String(err))
    }
  }

  async function handleDisconnect() {
    if (!integration) return
    const ok = await confirm({
      title: t('admin.integrations.disconnect_confirm.title'),
      message: t('admin.integrations.disconnect_confirm.message', { name: type.name }),
      variant: 'destructive',
      confirmLabel: t('admin.integrations.disconnect'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(integration.id).catch(() => undefined)
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{type.name}</SheetTitle>
          <SheetDescription>
            {integration
              ? t('admin.integrations.edit_description')
              : t('admin.integrations.connect_description')}
          </SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {submitError && (
              <p className="text-destructive text-sm" role="alert">
                {submitError}
              </p>
            )}

            <PreferencesForm
              schema={type.preference_schema}
              values={preferences}
              onChange={setPreferences}
            />

            <div className="flex items-center justify-between gap-3">
              <div className="flex flex-col">
                <span className="font-medium text-sm">
                  {t('admin.integrations.active_toggle.label')}
                </span>
                <span className="text-muted-foreground text-xs">
                  {t('admin.integrations.active_toggle.help')}
                </span>
              </div>
              <Switch checked={active} onCheckedChange={setActive} />
            </div>

            {integration && (
              <TestConnectionRow
                onTest={() => testMutation.mutateAsync(integration.id)}
                testing={testMutation.isPending}
                result={testMutation.data}
              />
            )}
          </div>
          <SheetFooter>
            {integration && (
              <Can I="destroy" a={Subject.Integration}>
                <Button
                  type="button"
                  variant="destructive"
                  onClick={handleDisconnect}
                  disabled={deleteMutation.isPending || saving}
                  className="mr-auto"
                >
                  {t('admin.integrations.disconnect')}
                </Button>
              </Can>
            )}
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={saving}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Can I={integration ? 'update' : 'create'} a={Subject.Integration}>
              <Button type="button" onClick={handleSave} disabled={saving}>
                {saving
                  ? t('admin.actions.saving')
                  : integration
                    ? t('admin.actions.save')
                    : t('admin.integrations.connect_cta')}
              </Button>
            </Can>
          </SheetFooter>
        </div>
      </SheetContent>
    </Sheet>
  )
}

function TestConnectionRow({
  onTest,
  testing,
  result,
}: {
  onTest: () => Promise<unknown>
  testing: boolean
  result?: { connected: boolean; error_message: string | null }
}) {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-2 rounded-md border p-3">
      <div className="flex items-center justify-between gap-3">
        <span className="font-medium text-sm">{t('admin.integrations.test.label')}</span>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => onTest().catch(() => undefined)}
          disabled={testing}
        >
          {testing ? t('admin.integrations.test.testing') : t('admin.integrations.test.run')}
        </Button>
      </div>
      {result &&
        (result.connected ? (
          <p className="text-sm text-success">{t('admin.integrations.test.success')}</p>
        ) : (
          <p className="text-destructive text-sm" role="alert">
            {result.error_message ?? t('admin.integrations.test.failure')}
          </p>
        ))}
    </div>
  )
}
