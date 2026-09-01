import {
  defaultPreferences,
  PageHeader,
  PreferencesForm,
  type ResourceSearch,
  ResourceTable,
  useResourceKey,
  useResourceKeyBuilder,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
  RowActions,
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
  Switch,
  toastManager,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PlusIcon, TrashIcon } from '@spree/dashboard-ui/icons'
import type { DeliveryMethod, DeliveryPreferenceField } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import '../tables/delivery-methods'

/**
 * How this seller ships.
 *
 * The list carries the marketplace's shared methods alongside the seller's
 * own, because the question a seller has is "can my goods be shipped", not
 * "what have I made" — and on a marketplace where the operator ships for
 * everyone the honest answer is a list the seller did not create
 * (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
 *
 * A shared row is read-only: the API refuses every write against it, so the
 * page offers no actions on one rather than letting a seller discover that
 * from a 404.
 */
export function DeliveryMethodsPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const confirm = useConfirm()
  const queryClient = useQueryClient()

  const [editingId, setEditingId] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)

  const buildKey = useResourceKeyBuilder()

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: buildKey('seller-delivery-methods') })
    // Having a way to ship can be an onboarding requirement, so the checklist
    // is no longer what it was.
    queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
  }

  const deleteMutation = useMutation({
    mutationFn: (id: string) => sellerClient().deliveryMethods.delete(id),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('delivery_methods.messages.deleted') })
      invalidate()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  // Only the seller's own rows open the editor — a shared marketplace method
  // has nothing here to change.
  useRowClickBridge('data-delivery-method-id', setEditingId)

  async function handleDelete(method: DeliveryMethod) {
    const ok = await confirm({
      title: t('delivery_methods.delete_confirm.title'),
      message: t('delivery_methods.delete_confirm.message', { name: method.name }),
      variant: 'destructive',
      confirmLabel: t('common.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(method.id).catch(() => undefined)
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('delivery_methods.title')}
        subtitle={t('delivery_methods.description')}
      />

      <ResourceTable<DeliveryMethod>
        tableKey="seller-delivery-methods"
        queryKey="seller-delivery-methods"
        queryFn={(params) => sellerClient().deliveryMethods.list(params)}
        searchParams={search}
        rowActions={(method) =>
          method.editable ? (
            <RowActions
              actions={[
                { key: 'edit', onSelect: () => setEditingId(method.id) },
                {
                  key: 'delete',
                  destructive: true,
                  disabled: deleteMutation.isPending,
                  onSelect: () => handleDelete(method),
                },
              ]}
            />
          ) : null
        }
        actions={
          <Button size="sm" onClick={() => setCreating(true)}>
            <PlusIcon className="size-4" />
            {t('delivery_methods.add')}
          </Button>
        }
      />

      {creating && <DeliveryMethodSheet onSaved={invalidate} onClose={() => setCreating(false)} />}
      {editingId && (
        <DeliveryMethodSheet
          methodId={editingId}
          onSaved={invalidate}
          onClose={() => setEditingId(null)}
        />
      )}
    </div>
  )
}

interface RuleDraft {
  id?: string
  type: string
  preferences: Record<string, unknown>
}

interface DeliveryMethodFormValues {
  name: string
  admin_name: string
  storefront_visible: boolean
  delivery_profile_id: string
  delivery_zone_id: string
  calculator_type: string
  calculator_preferences: Record<string, unknown>
  rules: RuleDraft[]
}

const DEFAULTS: DeliveryMethodFormValues = {
  name: '',
  admin_name: '',
  storefront_visible: true,
  delivery_profile_id: '',
  delivery_zone_id: '',
  calculator_type: '',
  calculator_preferences: {},
  rules: [],
}

function DeliveryMethodSheet({
  methodId,
  onSaved,
  onClose,
}: {
  methodId?: string
  onSaved: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()

  const { data: method } = useQuery({
    queryKey: useResourceKey('seller-delivery-methods', methodId ?? 'new'),
    queryFn: () => sellerClient().deliveryMethods.get(methodId as string),
    enabled: !!methodId,
  })

  // The currencies this marketplace trades in. A calculator set to anything
  // else saves fine and then quotes no rate at checkout, so the picker is
  // narrowed to what the store actually supports.
  const { data: sellerProfile } = useQuery({
    queryKey: useResourceKey('seller-profile', 'currencies'),
    queryFn: () => sellerClient().profile.get(),
  })
  const currencyOptions = sellerProfile?.supported_currencies ?? []

  // The marketplace's vocabulary this form picks from.
  const { data: allProfiles } = useQuery({
    queryKey: useResourceKey('seller-delivery-profiles', 'all'),
    queryFn: () => sellerClient().deliveryProfiles.list({ limit: 100 }),
  })

  // A seller's method ships by hand, which a digital profile refuses. Offering
  // one would only produce a save that fails on the fulfillment provider — a
  // field this form does not have.
  const profiles = allProfiles?.data.filter((profile) => !profile.digital) ?? []

  const { data: calculators } = useQuery({
    queryKey: useResourceKey('seller-delivery-calculators', 'all'),
    queryFn: () => sellerClient().deliveryMethods.calculators(),
  })

  const { data: ruleTypes } = useQuery({
    queryKey: useResourceKey('seller-delivery-rule-types', 'all'),
    queryFn: () => sellerClient().deliveryMethods.ruleTypes(),
  })

  const form = useForm<DeliveryMethodFormValues>({ defaultValues: DEFAULTS })
  const profileId = form.watch('delivery_profile_id')
  const calculatorType = form.watch('calculator_type')
  const rules = form.watch('rules')

  // A zone only means something under its profile, so the picker follows
  // whichever profile is selected rather than listing every zone the
  // marketplace has drawn.
  const { data: zones } = useQuery({
    queryKey: useResourceKey('seller-delivery-zones', profileId || 'none'),
    queryFn: () =>
      sellerClient().deliveryZones.list({ limit: 100, delivery_profile_id: profileId }),
    enabled: !!profileId,
  })

  useEffect(() => {
    if (!method) return
    form.reset({
      name: method.name,
      admin_name: method.admin_name ?? '',
      storefront_visible: method.storefront_visible,
      delivery_profile_id: method.delivery_profile_id ?? '',
      delivery_zone_id: method.delivery_zone_id ?? '',
      calculator_type: method.calculator_type ?? '',
      calculator_preferences: method.calculator_preferences ?? {},
      rules: (method.rules ?? []).map((rule) => ({
        id: rule.id,
        type: rule.type,
        preferences: rule.preferences ?? {},
      })),
    })
  }, [method, form])

  // A new method opens on the marketplace's default profile, so a seller who
  // ships ordinary parcels never has to make the choice.
  useEffect(() => {
    if (methodId || form.getValues('delivery_profile_id')) return
    const fallback = profiles.find((profile) => profile.default) ?? profiles[0]
    if (fallback) form.setValue('delivery_profile_id', fallback.id)
  }, [profiles, methodId, form])

  // And on a flat rate, which is what almost every seller charges. Leaving
  // the picker blank would show an empty Pricing box while the server
  // quietly created the method free.
  useEffect(() => {
    if (methodId || form.getValues('calculator_type')) return
    const flatRate = calculators?.data.find((calculator) => calculator.type.endsWith('::FlatRate'))
    if (!flatRate) return

    form.setValue('calculator_type', flatRate.type)
    form.setValue(
      'calculator_preferences',
      defaultPreferences(renderableSchema(flatRate.preference_schema)),
    )
  }, [calculators, methodId, form])

  const calculatorSchema = renderableSchema(
    calculators?.data.find((calculator) => calculator.type === calculatorType)?.preference_schema,
  )

  const save = useMutation({
    mutationFn: (values: DeliveryMethodFormValues) => {
      const params = {
        name: values.name,
        admin_name: values.admin_name || null,
        storefront_visible: values.storefront_visible,
        delivery_profile_id: values.delivery_profile_id || undefined,
        delivery_zone_id: values.delivery_zone_id || null,
        ...(values.calculator_type ? { calculator_type: values.calculator_type } : {}),
        calculator_preferences: values.calculator_preferences,
        // The array replaces the whole set: a rule dropped here is deleted,
        // which is why every surviving row is re-sent with its id.
        rules: values.rules.map((rule) => ({
          ...(rule.id ? { id: rule.id } : {}),
          type: rule.type,
          preferences: rule.preferences,
        })),
      }

      return methodId
        ? sellerClient().deliveryMethods.update(methodId, params)
        : sellerClient().deliveryMethods.create(params)
    },
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('delivery_methods.messages.saved') })
      onSaved()
      onClose()
    },
    // The sheet stays open on failure — closing it would discard what the
    // seller filled in along with the error explaining why it did not save.
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const { errors } = form.formState

  function addRule(type: string) {
    const schema = renderableSchema(
      ruleTypes?.data.find((rule) => rule.type === type)?.preference_schema,
    )
    form.setValue('rules', [...rules, { type, preferences: defaultPreferences(schema) }])
  }

  function removeRule(index: number) {
    form.setValue(
      'rules',
      rules.filter((_, position) => position !== index),
    )
  }

  const unusedRuleTypes = (ruleTypes?.data ?? []).filter(
    (ruleType) => !rules.some((rule) => rule.type === ruleType.type),
  )

  return (
    <Sheet open onOpenChange={(next) => !next && onClose()}>
      <SheetContent className="data-[side=right]:max-w-[720px]">
        <SheetHeader>
          <SheetTitle>{method?.name ?? t('delivery_methods.sheet.new_title')}</SheetTitle>
          <SheetDescription>{t('delivery_methods.sheet.description')}</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={form.handleSubmit((values) => save.mutateAsync(values).catch(() => undefined))}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-6 overflow-y-auto p-4">
            <div className="flex flex-col gap-4">
              <Field>
                <FieldLabel htmlFor="delivery-method-name">
                  {t('delivery_methods.fields.name')}
                </FieldLabel>
                <Input
                  id="delivery-method-name"
                  autoFocus
                  aria-invalid={!!errors.name || undefined}
                  {...form.register('name', { required: true })}
                />
                <FieldError errors={[errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="delivery-method-admin-name">
                  {t('delivery_methods.fields.admin_name')}
                </FieldLabel>
                <Input id="delivery-method-admin-name" {...form.register('admin_name')} />
              </Field>

              <Field orientation="horizontal">
                <FieldLabel htmlFor="delivery-method-visible">
                  {t('delivery_methods.fields.storefront_visible')}
                </FieldLabel>
                <Controller
                  control={form.control}
                  name="storefront_visible"
                  render={({ field }) => (
                    <Switch
                      id="delivery-method-visible"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  )}
                />
              </Field>
            </div>

            <Card>
              <CardHeader>
                <CardTitle>{t('delivery_methods.sections.goods')}</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-4">
                <Field>
                  <FieldLabel htmlFor="delivery-method-profile">
                    {t('delivery_methods.fields.delivery_profile')}
                  </FieldLabel>
                  <Controller
                    control={form.control}
                    name="delivery_profile_id"
                    render={({ field }) => (
                      <Select
                        value={field.value}
                        onValueChange={(next) => {
                          field.onChange(next)
                          // The zone must sit under the method's profile, so
                          // one chosen under the old profile cannot survive
                          // the change.
                          form.setValue('delivery_zone_id', '')
                        }}
                      >
                        <SelectTrigger id="delivery-method-profile">
                          <SelectValue>
                            {(value) =>
                              profiles.find((profile) => profile.id === value)?.name ??
                              (value as string)
                            }
                          </SelectValue>
                        </SelectTrigger>
                        <SelectContent>
                          {profiles.map((profile) => (
                            <SelectItem key={profile.id} value={profile.id}>
                              {profile.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </Field>

                <Field>
                  <FieldLabel htmlFor="delivery-method-zone">
                    {t('delivery_methods.fields.delivery_zone')}
                  </FieldLabel>
                  <Controller
                    control={form.control}
                    name="delivery_zone_id"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger id="delivery-method-zone">
                          <SelectValue placeholder={t('delivery_methods.zone.everywhere')}>
                            {(value) =>
                              zones?.data.find((zone) => zone.id === value)?.name ??
                              t('delivery_methods.zone.everywhere')
                            }
                          </SelectValue>
                        </SelectTrigger>
                        <SelectContent>
                          {zones?.data.map((zone) => (
                            <SelectItem key={zone.id} value={zone.id}>
                              {zone.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </Field>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>{t('delivery_methods.sections.price')}</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-4">
                <Field>
                  <FieldLabel htmlFor="delivery-method-calculator">
                    {t('delivery_methods.fields.calculator')}
                  </FieldLabel>
                  <Controller
                    control={form.control}
                    name="calculator_type"
                    render={({ field }) => (
                      <Select
                        value={field.value}
                        onValueChange={(next) => {
                          field.onChange(next)
                          const schema =
                            calculators?.data.find((calculator) => calculator.type === next)
                              ?.preference_schema ?? []
                          form.setValue('calculator_preferences', defaultPreferences(schema))
                        }}
                      >
                        <SelectTrigger id="delivery-method-calculator">
                          <SelectValue>
                            {(value) =>
                              calculators?.data.find((calculator) => calculator.type === value)
                                ?.name ?? (value as string)
                            }
                          </SelectValue>
                        </SelectTrigger>
                        <SelectContent>
                          {calculators?.data.map((calculator) => (
                            <SelectItem key={calculator.type} value={calculator.type}>
                              {calculator.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </Field>

                <Controller
                  control={form.control}
                  name="calculator_preferences"
                  render={({ field }) => (
                    <PreferencesForm
                      schema={calculatorSchema}
                      values={field.value}
                      onChange={field.onChange}
                      currencyOptions={currencyOptions}
                    />
                  )}
                />
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>{t('delivery_methods.sections.conditions')}</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-4">
                <p className="text-muted-foreground text-sm">
                  {t('delivery_methods.conditions.description')}
                </p>

                {rules.map((rule, index) => {
                  const definition = ruleTypes?.data.find((type) => type.type === rule.type)

                  return (
                    <div
                      key={rule.id ?? `${rule.type}-${index}`}
                      className="flex flex-col gap-3 rounded-md border border-border p-3"
                    >
                      <div className="flex items-center justify-between gap-4">
                        <div className="flex flex-col">
                          <span className="font-medium text-sm">
                            {definition?.name ?? rule.type}
                          </span>
                          {definition?.description && (
                            <span className="text-muted-foreground text-xs">
                              {definition.description}
                            </span>
                          )}
                        </div>
                        <Button
                          type="button"
                          size="sm"
                          variant="ghost"
                          onClick={() => removeRule(index)}
                          aria-label={t('delivery_methods.conditions.remove')}
                        >
                          <TrashIcon className="size-4" />
                        </Button>
                      </div>

                      <PreferencesForm
                        schema={renderableSchema(definition?.preference_schema)}
                        currencyOptions={currencyOptions}
                        values={rule.preferences}
                        onChange={(next) =>
                          form.setValue(
                            'rules',
                            rules.map((row, position) =>
                              position === index ? { ...row, preferences: next } : row,
                            ),
                          )
                        }
                      />
                    </div>
                  )
                })}

                {unusedRuleTypes.length > 0 && (
                  <Select value="" onValueChange={addRule}>
                    <SelectTrigger>
                      <SelectValue placeholder={t('delivery_methods.conditions.add')}>
                        {() => t('delivery_methods.conditions.add')}
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent>
                      {unusedRuleTypes.map((ruleType) => (
                        <SelectItem key={ruleType.type} value={ruleType.type}>
                          {ruleType.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </CardContent>
            </Card>
          </div>
          <SheetFooter>
            <Button type="button" variant="outline" onClick={onClose} disabled={save.isPending}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? t('common.saving') : t('common.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

/**
 * The fields of a preference schema the shared form can render.
 *
 * Drops `hash`-typed preferences — today the flat-rate calculator's
 * per-currency `amounts` map, which the operator edits through a dedicated
 * multi-currency control and the generic form would show as the hash itself
 * in a text box. A seller quotes in the store's currency, so `amount` and
 * `currency` are the whole question.
 */
function renderableSchema(
  schema: DeliveryPreferenceField[] | undefined,
): DeliveryPreferenceField[] {
  return (schema ?? []).filter((field) => field.type !== 'hash')
}
