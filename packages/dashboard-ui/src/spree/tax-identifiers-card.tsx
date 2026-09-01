import { useEffect, useState } from 'react'
import { Controller, type UseFormSetError, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
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
} from '../index'
import { BadgeCheckIcon, EllipsisVerticalIcon, PencilIcon, PlusIcon, TrashIcon } from './icons'

/** One selectable registration kind. */
interface KindOption {
  value: string
  label: string
}

/**
 * A registration as the API returns it. Declared here rather than imported
 * from an SDK: this package is headless, and the admin and seller SDKs
 * describe the same row.
 */
export interface TaxIdentifier {
  id: string
  kind: string
  value: string
  validation_status?: string | null
  validated_at?: string | null
  validatable?: boolean
}

export interface TaxIdentifierParams {
  kind: string
  value: string
}

interface TaxIdentifierFormValues {
  kind: string
  value: string
}

const TAX_IDENTIFIER_DEFAULTS: TaxIdentifierFormValues = { kind: '', value: '' }

/**
 * The registration kinds Spree ships strings for. Any string is accepted by
 * the API — what a kind means is decided by whichever validator is registered
 * for it — so the merchant can type their own.
 */
export const TAX_IDENTIFIER_KINDS = ['eu_vat', 'gb_vat', 'ch_vat', 'au_abn', 'us_ein'] as const

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
  /**
   * Routes a rejected save onto the form. Supplied by the host because it is
   * the host's SDK that defines what a validation error looks like; returning
   * false means "not mine", and the error is rethrown.
   */
  mapErrors: (error: unknown, setError: UseFormSetError<TaxIdentifierFormValues>) => boolean
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
          mapErrors={mutations.mapErrors}
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
          mapErrors={mutations.mapErrors}
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
  mapErrors,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  identifier?: TaxIdentifier
  onSubmit: (params: TaxIdentifierParams) => Promise<unknown>
  mapErrors: (error: unknown, setError: UseFormSetError<TaxIdentifierFormValues>) => boolean
}) {
  const { t } = useTranslation()
  const form = useForm<TaxIdentifierFormValues>({ defaultValues: TAX_IDENTIFIER_DEFAULTS })

  useEffect(() => {
    if (open) {
      form.reset(
        identifier ? { kind: identifier.kind, value: identifier.value } : TAX_IDENTIFIER_DEFAULTS,
      )
    }
  }, [open, identifier, form])

  async function handleSubmit(values: TaxIdentifierFormValues) {
    try {
      await onSubmit({ kind: values.kind, value: values.value })
      onOpenChange(false)
    } catch (err) {
      // The host maps its own SDK's errors: this package knows nothing about
      // either SDK, and a thrown error it cannot read is the host's to report.
      if (!mapErrors(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState
  // The mapper always seeds `root` with the server's summary, as a safety net
  // for errors whose field is not on screen. Here both fields are, so showing
  // it as well repeats the same sentence twice in one small form.
  const rootIsRepeated = Boolean(errors.kind || errors.value)

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
              {errors.root?.message && !rootIsRepeated && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}
              <Field>
                <FieldLabel htmlFor="tax-identifier-kind">
                  {t('admin.fields.tax_identifier.kind.label')}
                </FieldLabel>
                {/* The list seeds the picker rather than closing it: any string
                    is a valid kind, and only the validator registered for one
                    decides what it means. */}
                <Controller
                  name="kind"
                  control={form.control}
                  rules={{ required: t('admin.fields.tax_identifier.kind.required') }}
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
                        // The list seeds the picker rather than closing it, so
                        // a kind matching no item has to be read from the input
                        // itself. Only genuine typing: picking an option also
                        // rewrites the input, to the label rather than the key.
                        onInputValueChange={(input: string, details: { reason?: string }) => {
                          if (details.reason === 'input-change') field.onChange(input)
                        }}
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
                  {...form.register('value', {
                    required: t('admin.fields.tax_identifier.value.required'),
                  })}
                />
                <FieldError errors={[errors.value]} />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
