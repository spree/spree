import type { DeliveryMethod } from '@spree/admin-sdk'
import { Subject, usePermissions, useStore } from '@spree/dashboard-core'
import {
  Badge,
  RowActions,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import { TruckIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import {
  useDeleteDeliveryMethod,
  useDeliveryRateProviders,
} from '../../../hooks/use-delivery-methods'
import { formatListedPrice, summarizeRules } from '../../../lib/delivery-method-summary'
import { useMethodSheetNavigation } from './use-method-sheet-navigation'

export function DeliveryMethodList({
  methods,
  icon: Icon = TruckIcon,
}: {
  methods: DeliveryMethod[]
  icon?: typeof TruckIcon
}) {
  const { t, i18n } = useTranslation()
  const { store, defaultCurrency } = useStore()
  const { openMethod } = useMethodSheetNavigation()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryMethod()
  const { permissions } = usePermissions()
  const { data: rateProviders } = useDeliveryRateProviders()
  const defaultRateProvider = rateProviders?.default ?? ''

  async function handleDelete(method: DeliveryMethod) {
    const ok = await confirm({
      title: t('admin.delivery_methods.delete_confirm.title'),
      message: t('admin.delivery_methods.delete_confirm.message', { name: method.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(method.id).catch(() => undefined)
  }

  if (methods.length === 0) {
    return (
      <p className="text-muted-foreground text-sm">
        {t('admin.delivery_profiles.detail.no_methods')}
      </p>
    )
  }

  return (
    <div className="flex flex-col divide-y">
      {methods.map((method) => {
        const rateProvider = (rateProviders?.data ?? []).find(
          (provider) => provider.type === method.rate_provider,
        )
        // A carrier quotes each shipment live, so this column answers what the
        // price IS rather than naming the provider — which the method is
        // usually named after anyway. Everything else is priced up front: an
        // amount, or free when there is none.
        //
        // A method carrying a rate provider absent from the registry (an
        // uninstalled gem, a disconnected integration) is still not
        // calculator-priced, and calling it free would be a lie about money.
        const carrierPriced = rateProvider
          ? rateProvider.uses_calculator === false
          : !!method.rate_provider && method.rate_provider !== defaultRateProvider
        const price = carrierPriced
          ? t('admin.delivery_methods.carrier_rates')
          : formatListedPrice(
              method.calculator_preferences,
              defaultCurrency,
              i18n.language,
              t('admin.delivery_methods.free'),
              t('admin.delivery_methods.rule_summary.separator'),
            )

        const ruleSummary = summarizeRules(method.rules, {
          t,
          currency: defaultCurrency,
          weightUnit: store?.preferred_weight_unit ?? 'lb',
          locale: i18n.language,
        })

        return (
          <div key={method.id} className="flex items-center justify-between gap-2 py-2">
            <button
              type="button"
              className="flex flex-1 items-center gap-2 text-left"
              onClick={() => openMethod(method.id)}
            >
              <Icon className="size-4 shrink-0 text-muted-foreground" />
              <span className="flex flex-col">
                <span className="text-sm">{method.name}</span>
                {ruleSummary && (
                  <span className="text-muted-foreground text-xs">{ruleSummary}</span>
                )}
              </span>
            </button>
            {!method.storefront_visible && (
              <Badge variant="outline">{t('admin.delivery_profiles.detail.hidden_badge')}</Badge>
            )}
            {carrierPriced ? (
              <Tooltip>
                <TooltipTrigger
                  render={
                    <span className="shrink-0 cursor-default text-sm underline decoration-dotted underline-offset-2">
                      {price}
                    </span>
                  }
                />
                <TooltipContent className="max-w-xs">
                  {t('admin.delivery_methods.carrier_rates_hint', {
                    name: rateProvider?.name ?? method.name,
                  })}
                </TooltipContent>
              </Tooltip>
            ) : (
              <span className="shrink-0 text-sm tabular-nums">{price}</span>
            )}
            <RowActions
              actions={[
                {
                  key: 'edit',
                  onSelect: () => openMethod(method.id),
                },
                {
                  key: 'delete',
                  destructive: true,
                  visible: permissions.can('destroy', Subject.DeliveryMethod),
                  disabled: deleteMutation.isPending,
                  onSelect: () => handleDelete(method),
                },
              ]}
            />
          </div>
        )
      })}
    </div>
  )
}
