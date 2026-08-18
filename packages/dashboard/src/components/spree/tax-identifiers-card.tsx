import { zodResolver } from '@hookform/resolvers/zod'
import type { TaxIdentifier, TaxIdentifierParams } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RelativeTime,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import { BadgeCheckIcon, EllipsisVerticalIcon, PencilIcon, PlusIcon, TrashIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  TAX_IDENTIFIER_DEFAULTS,
  TAX_IDENTIFIER_KINDS,
  type TaxIdentifierFormValues,
  taxIdentifierFormSchema,
  taxIdentifierValuesToParams,
} from '../../schemas/company'

/** One selectable registration kind. */
interface KindOption {
  value: string
  label: string
}

/**
 * Mutations differ by owner (a company's registrations hang off the company,
 * a customer's off the customer) while the panel itself does not — so the
 * owner supplies them and this stays one component.
 */
export interface TaxIdentifierMutations {
  create: (params: TaxIdentifierParams) => Promise<unknown>
  update: (id: string, params: TaxIdentifierParams) => Promise<unknown>
  remove: (id: string) => Promise<unknown>
  validate: (id: string) => Promise<unknown>
  isValidating?: boolean
}

/**
 * The buyer's VAT or business number. What makes EU B2B reverse charge
 * possible, so the verdict matters as much as the number: a row nothing can
 * check reads as such rather than as merely unverified.
 */
export function TaxIdentifiersCard({
  identifiers,
  isLoading,
  mutations,
  canEdit,
}: {
  identifiers: TaxIdentifier[]
  isLoading?: boolean
  mutations: TaxIdentifierMutations
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const [addOpen, setAddOpen] = useState(false)
  const [editing, setEditing] = useState<TaxIdentifier | null>(null)

  async function handleDelete(identifier: TaxIdentifier) {
    const ok = await confirm({
      title: t('admin.tax_identifiers.delete_confirm.title'),
      message: t('admin.tax_identifiers.delete_confirm.message', { value: identifier.value }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await mutations.remove(identifier.id).catch(() => undefined)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.tax_identifiers.title')}
          {identifiers.length > 0 && <Badge variant="outline">{identifiers.length}</Badge>}
        </CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.tax_identifiers.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      {isLoading ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        </CardContent>
      ) : identifiers.length === 0 ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.tax_identifiers.empty')}</p>
        </CardContent>
      ) : (
        <CardContent className="flex flex-col gap-3">
          {identifiers.map((identifier) => (
            <div
              key={identifier.id}
              className="flex items-start justify-between gap-3 rounded-md border p-3"
            >
              <div className="flex min-w-0 flex-col gap-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-medium text-sm">{identifier.value}</span>
                  <Badge variant="outline">
                    {t(`admin.tax_identifiers.kinds.${identifier.kind}`, {
                      defaultValue: identifier.kind,
                    })}
                  </Badge>
                  {identifier.validation_status ? (
                    <StatusBadge
                      status={identifier.validation_status}
                      label={t(
                        `admin.tax_identifiers.validation_status.${identifier.validation_status}`,
                        { defaultValue: identifier.validation_status },
                      )}
                    />
                  ) : (
                    <Badge variant="secondary">
                      {t('admin.tax_identifiers.validation_status.not_checked')}
                    </Badge>
                  )}
                </div>
                {identifier.validated_at && (
                  <span className="text-muted-foreground text-xs">
                    <RelativeTime
                      iso={identifier.validated_at}
                      prefix={t('admin.tax_identifiers.checked_prefix')}
                    />
                  </span>
                )}
                {!identifier.validatable && (
                  <span className="text-muted-foreground text-xs">
                    {t('admin.tax_identifiers.not_validatable')}
                  </span>
                )}
              </div>

              {canEdit && (
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon-xs">
                      <EllipsisVerticalIcon className="size-4" />
                      <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem
                      disabled={!identifier.validatable || mutations.isValidating}
                      onClick={() => mutations.validate(identifier.id).catch(() => undefined)}
                    >
                      <BadgeCheckIcon className="size-4" />
                      {t('admin.tax_identifiers.validate_action')}
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={() => setEditing(identifier)}>
                      <PencilIcon className="size-4" />
                      {t('admin.actions.edit')}
                    </DropdownMenuItem>
                    <DropdownMenuItem
                      className="text-destructive focus:text-destructive"
                      onClick={() => handleDelete(identifier)}
                    >
                      <TrashIcon className="size-4" />
                      {t('admin.actions.delete')}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              )}
            </div>
          ))}
        </CardContent>
      )}

      {addOpen && (
        <TaxIdentifierSheet
          open
          onOpenChange={setAddOpen}
          onSubmit={(params) => mutations.create(params)}
        />
      )}
      {editing && (
        <TaxIdentifierSheet
          open
          identifier={editing}
          onOpenChange={(next) => {
            if (!next) setEditing(null)
          }}
          onSubmit={(params) => mutations.update(editing.id, params)}
        />
      )}
    </Card>
  )
}

function TaxIdentifierSheet({
  open,
  onOpenChange,
  identifier,
  onSubmit,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  identifier?: TaxIdentifier
  onSubmit: (params: TaxIdentifierParams) => Promise<unknown>
}) {
  const { t } = useTranslation()
  const form = useForm<TaxIdentifierFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(taxIdentifierFormSchema) as any,
    defaultValues: TAX_IDENTIFIER_DEFAULTS,
  })

  useEffect(() => {
    if (open) {
      form.reset(
        identifier ? { kind: identifier.kind, value: identifier.value } : TAX_IDENTIFIER_DEFAULTS,
      )
    }
  }, [open, identifier, form])

  async function handleSubmit(values: TaxIdentifierFormValues) {
    try {
      await onSubmit(taxIdentifierValuesToParams(values))
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {identifier
              ? t('admin.tax_identifiers.edit_title')
              : t('admin.tax_identifiers.add_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.tax_identifiers.dialog_description')}</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            // This sheet can be rendered inside another form; stopping the
            // bubbled submit keeps the outer form from also submitting.
            form.handleSubmit(handleSubmit)(event)
            event.stopPropagation()
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}
              <Field>
                <FieldLabel htmlFor="tax-identifier-kind">
                  {t('admin.fields.tax_identifier.kind.label')}
                </FieldLabel>
                {/* A constrained list, not free text: the kind has to match the
                    key its validator is registered under, and a typo would be
                    stored and used as entered rather than rejected. */}
                <Controller
                  name="kind"
                  control={form.control}
                  render={({ field }) => {
                    // Combobox rather than Select: this card renders inside a
                    // page card, and Base UI's Select popup does not survive
                    // that portal nesting (the country picker below is a
                    // Combobox for the same reason).
                    const kindOptions = TAX_IDENTIFIER_KINDS.map((kind) => ({
                      value: kind,
                      label: t(`admin.tax_identifiers.kinds.${kind}`, { defaultValue: kind }),
                    }))
                    const selected = kindOptions.find((o) => o.value === field.value) ?? null
                    return (
                      <Combobox
                        items={kindOptions}
                        value={selected}
                        onValueChange={(option: KindOption | null) =>
                          field.onChange(option?.value ?? '')
                        }
                        itemToStringLabel={(option: KindOption | null) => option?.label ?? ''}
                        itemToStringValue={(option: KindOption | null) => option?.value ?? ''}
                      >
                        <ComboboxInput
                          id="tax-identifier-kind"
                          placeholder={t('admin.tax_identifiers.select_kind')}
                        />
                        <ComboboxContent>
                          <ComboboxEmpty>{t('admin.common.no_results')}</ComboboxEmpty>
                          <ComboboxList>
                            {(option: KindOption) => (
                              <ComboboxItem key={option.value} value={option}>
                                {option.label}
                              </ComboboxItem>
                            )}
                          </ComboboxList>
                        </ComboboxContent>
                      </Combobox>
                    )
                  }}
                />
                <FieldDescription>{t('admin.fields.tax_identifier.kind.help')}</FieldDescription>
                <FieldError errors={[errors.kind]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="tax-identifier-value">
                  {t('admin.fields.tax_identifier.value.label')}
                </FieldLabel>
                <Input
                  id="tax-identifier-value"
                  placeholder={t('admin.fields.tax_identifier.value.placeholder')}
                  aria-invalid={!!errors.value || undefined}
                  {...form.register('value')}
                />
                <FieldError errors={[errors.value]} />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
