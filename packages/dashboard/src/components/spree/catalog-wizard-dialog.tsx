import { zodResolver } from '@hookform/resolvers/zod'
import type { Product } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Badge,
  Button,
  cn,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Pagination,
  SearchInput,
  Textarea,
  Thumbnail,
  toastManager,
  WizardSteps,
} from '@spree/dashboard-ui'
import { CheckIcon, InfoIcon, PackageIcon, PlusIcon, XIcon } from 'lucide-react'
import { useDeferredValue, useEffect, useMemo, useState } from 'react'
import { type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCreateCatalog } from '../../hooks/use-catalogs'
import { useProducts } from '../../hooks/use-products'
import {
  CATALOG_DEFAULTS,
  type CatalogFormValues,
  catalogFormSchema,
  catalogValuesToParams,
} from '../../schemas/catalog'
import { CatalogAudienceFields } from './catalog-audience-fields'
import { CatalogPricingFields } from './catalog-pricing-fields'

const STEP_KEYS = ['details', 'audience', 'products', 'pricing', 'review'] as const
type StepKey = (typeof STEP_KEYS)[number]

/** The fields each step owns, so Next judges only what it asked for. */
const STEP_FIELDS: Partial<Record<StepKey, (keyof CatalogFormValues)[]>> = {
  details: ['name', 'description'],
  pricing: ['adjustment_magnitude', 'minimum_quantity'],
}

/**
 * Standing up a whole agreement in one pass: what it is, who it is for, what
 * it sells, what that costs, then a look at the lot before it exists
 * (docs/plans/6.0-catalog-agreement-rework.md).
 *
 * A full-window dialog rather than a route, matching the import wizard: this
 * is going deeper into the catalogs page, not leaving it, so the list behind
 * keeps its state and closing puts the merchant back where they were.
 *
 * Nothing is written until Create. The assortment is staged here and attached
 * immediately after the catalog exists — product membership needs a saved
 * parent, which is a fact about the write, not a reason to ask for the
 * products on a different screen.
 */
export function CatalogWizardDialog({
  open,
  onOpenChange,
  onCreated,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Where to go once the catalog exists — its agreement editor. */
  onCreated: (catalogId: string) => void
}) {
  const { t } = useTranslation()

  return (
    <Dialog open={open} onOpenChange={onOpenChange} modal>
      <DialogContent
        // Edge-to-edge minus a gutter, like the import wizard and the bulk
        // price editor — every inset/translate/max is overridden.
        className="!inset-3 !w-auto !max-w-none !translate-x-0 !translate-y-0 flex flex-col p-0"
        style={{ maxHeight: 'none' }}
        showCloseButton={false}
      >
        <DialogHeader className="flex flex-row items-center justify-between gap-3 space-y-0 border-b p-3">
          <DialogTitle>{t('admin.catalogs.wizard.title')}</DialogTitle>
          <Button
            type="button"
            size="icon-sm"
            variant="ghost"
            onClick={() => onOpenChange(false)}
            aria-label={t('admin.actions.close')}
          >
            <XIcon />
          </Button>
        </DialogHeader>
        {open && <CatalogWizard onOpenChange={onOpenChange} onCreated={onCreated} />}
      </DialogContent>
    </Dialog>
  )
}

function CatalogWizard({
  onOpenChange,
  onCreated,
}: {
  onOpenChange: (open: boolean) => void
  onCreated: (catalogId: string) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCatalog()
  const [step, setStep] = useState<StepKey>('details')
  const [products, setProducts] = useState<Product[]>([])

  const form = useForm<CatalogFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(catalogFormSchema) as any,
    defaultValues: CATALOG_DEFAULTS,
  })

  const stepIndex = STEP_KEYS.indexOf(step)
  const isLastStep = stepIndex === STEP_KEYS.length - 1
  const audienceCount = (form.watch('assignments') ?? []).filter((entry) => !entry.removed).length

  const steps = STEP_KEYS.map((key) => ({
    key,
    label: t(`admin.catalogs.wizard.steps.${key}`),
  }))

  // Only this step's own fields. A refusal is stated at the top as well as on
  // the field: Next going quiet is the one outcome a merchant cannot act on.
  async function goNext() {
    const fields = STEP_FIELDS[step]
    if (fields && !(await form.trigger(fields))) {
      form.setError('root', { message: t('admin.catalogs.wizard.fix_this_step') })
      return
    }

    form.clearErrors('root')
    setStep(STEP_KEYS[stepIndex + 1])
  }

  async function handleCreate(values: CatalogFormValues) {
    // The only way to create is pressing Create on the last step. Anything
    // else reaching submit — a stray Enter, a button the DOM reused across
    // the Next/Create swap — is refused rather than quietly making a catalog
    // the merchant has not finished describing.
    if (!isLastStep) return

    try {
      const catalog = await createMutation.mutateAsync(catalogValuesToParams(values))

      // The catalog exists from here on, so a failure to attach products is
      // reported rather than rolled back — the merchant lands on the page
      // where they can add them, instead of losing the agreement too.
      if (products.length > 0) {
        try {
          await adminClient.catalogs.products.create(
            catalog.id,
            products.map((product) => product.id),
          )
        } catch {
          toastManager.add({
            type: 'error',
            title: t('admin.catalogs.wizard.products_failed'),
          })
        }
      }

      onOpenChange(false)
      onCreated(catalog.id)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <form
      onSubmit={form.handleSubmit(handleCreate, () =>
        form.setError('root', { message: t('admin.catalogs.wizard.fix_this_step') }),
      )}
      onKeyDown={(event) => {
        // Only a single-line text field. Enter on a button is how a keyboard
        // user presses it, and a textarea needs it for a new line.
        const onTextInput =
          event.target instanceof HTMLInputElement && event.target.type !== 'checkbox'
        if (event.key === 'Enter' && !isLastStep && onTextInput) event.preventDefault()
      }}
      className="flex min-h-0 flex-1 flex-col"
    >
      <div className="border-b border-border-subtle px-6 py-4">
        <WizardSteps
          steps={steps}
          current={step}
          onStepSelect={(key: string) => setStep(key as StepKey)}
        />
      </div>

      <DialogBody className="flex-1 overflow-y-auto p-6">
        {/* The Products step is two columns and wants the room; the others
            are a form, which reads badly stretched across a wide window. */}
        <div
          className={cn(
            'mx-auto flex w-full flex-col gap-6',
            step === 'products' ? 'max-w-5xl' : 'max-w-2xl',
          )}
        >
          <div>
            <h2 className="font-medium text-lg">{t(`admin.catalogs.wizard.steps.${step}`)}</h2>
            <p className="text-muted-foreground text-sm">
              {t(`admin.catalogs.wizard.help.${step}`)}
            </p>
          </div>

          {form.formState.errors.root?.message && (
            <p
              className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
              role="alert"
            >
              {form.formState.errors.root.message}
            </p>
          )}

          {step === 'details' && <DetailsStep form={form} />}
          {step === 'audience' && (
            <>
              <CatalogAudienceFields form={form} canEdit inlineAssign />
              {/* Both empty states are legitimate — a catalog with no audience
                  and one with no assortment each mean something specific — so
                  neither blocks. What they mean is said here rather than
                  discovered later. */}
              {audienceCount === 0 && (
                <p className="rounded-md bg-muted px-3 py-2 text-muted-foreground text-sm">
                  {t('admin.catalogs.wizard.audience_none_warning')}
                </p>
              )}
            </>
          )}
          {step === 'products' && (
            <>
              <ProductsStep products={products} onChange={setProducts} />
              {products.length === 0 && (
                <p className="rounded-md bg-muted px-3 py-2 text-muted-foreground text-sm">
                  {t('admin.catalogs.wizard.products_none_warning')}
                </p>
              )}
            </>
          )}
          {step === 'pricing' && (
            <FieldGroup>
              <CatalogPricingFields form={form} canEdit />
            </FieldGroup>
          )}
          {step === 'review' && (
            <>
              <ReviewStep form={form} products={products} />
              {/* Creating and going live are separate acts, so the merchant is
                  told which one Create performs. */}
              <Alert variant="info">
                <InfoIcon />
                <AlertDescription>{t('admin.catalogs.wizard.review.inactive')}</AlertDescription>
              </Alert>
            </>
          )}
        </div>
      </DialogBody>

      {/* Back sits opposite the forward action rather than beside it, so the
          footer's default end-justification is overridden — everything else
          about it (border, ground, padding) is the shared one. It stays a row
          at every width too: stacked, "Back" would sit above "Next", which
          reads as the order to press them in. */}
      <DialogFooter className="flex-row justify-between sm:justify-between">
        <Button
          type="button"
          variant="outline"
          disabled={stepIndex === 0}
          onClick={() => setStep(STEP_KEYS[stepIndex - 1])}
        >
          {t('admin.actions.back')}
        </Button>

        {/* Keyed apart so React swaps the element instead of mutating one in
            place: reusing the node means the click that lands on Next
            resolves against a button that has just become the submit, and the
            catalog is created a step early without the merchant pressing
            Create. */}
        {isLastStep ? (
          <Button key="create" type="submit" disabled={form.formState.isSubmitting}>
            {form.formState.isSubmitting
              ? t('admin.actions.creating')
              : t('admin.catalogs.create_label')}
          </Button>
        ) : (
          <Button key="next" type="button" onClick={goNext}>
            {t('admin.common.next')}
          </Button>
        )}
      </DialogFooter>
    </form>
  )
}

function DetailsStep({ form }: { form: UseFormReturn<CatalogFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState

  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor="catalog-name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="catalog-name"
          autoFocus
          placeholder={t('admin.fields.catalog.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="catalog-description">
          {t('admin.fields.catalog.description.label')}
        </FieldLabel>
        <Textarea
          id="catalog-description"
          rows={3}
          placeholder={t('admin.fields.catalog.description.placeholder')}
          {...form.register('description')}
        />
        <FieldDescription>{t('admin.fields.catalog.description.help')}</FieldDescription>
      </Field>
    </FieldGroup>
  )
}

/**
 * The assortment, staged, as two columns: what the agreement covers on the
 * left, everything else on the right. Built in place rather than behind a
 * picker sheet — this step exists to assemble a list, and a sheet sliding
 * over the wizard covers the very list being assembled.
 *
 * An empty catalog is legitimate — it prices without restricting what anyone
 * sees — so this step never blocks; it says what leaving it empty means.
 */
function ProductsStep({
  products,
  onChange,
}: {
  products: Product[]
  onChange: (products: Product[]) => void
}) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const deferredSearch = useDeferredValue(search)

  const { data, isLoading } = useProducts({ page, limit: 10, search: deferredSearch, sort: 'name' })
  const chosen = useMemo(() => new Set(products.map((product) => product.id)), [products])

  // Typing filters a list whose page numbers no longer mean anything.
  // biome-ignore lint/correctness/useExhaustiveDependencies: resetting the page is the point
  useEffect(() => {
    setPage(1)
  }, [deferredSearch])

  return (
    <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
      <section className="flex min-w-0 flex-col gap-2">
        <h3 className="font-medium text-sm">
          {t('admin.catalogs.wizard.products.chosen_title')}
          <span className="ml-2 font-normal text-muted-foreground">{products.length}</span>
        </h3>

        {products.length === 0 ? (
          <Empty className="min-h-64 border">
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <PackageIcon />
              </EmptyMedia>
              <EmptyTitle>{t('admin.catalogs.wizard.products.empty')}</EmptyTitle>
              <EmptyDescription>
                {t('admin.catalogs.wizard.products.empty_description')}
              </EmptyDescription>
            </EmptyHeader>
          </Empty>
        ) : (
          <div className="flex max-h-96 flex-col divide-y overflow-y-auto rounded-md border">
            {products.map((product) => (
              <div key={product.id} className="flex items-center gap-3 p-2">
                <Thumbnail
                  src={product.thumbnail_url}
                  alt={product.name ?? ''}
                  className="size-8"
                />
                <span className="min-w-0 flex-1 truncate text-sm">{product.name}</span>
                <Button
                  variant="ghost"
                  size="icon-xs"
                  type="button"
                  onClick={() => onChange(products.filter((row) => row.id !== product.id))}
                  aria-label={t('admin.catalogs.wizard.products.remove', { name: product.name })}
                >
                  <XIcon className="size-4" />
                </Button>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="flex min-w-0 flex-col gap-2">
        <h3 className="font-medium text-sm">{t('admin.catalogs.wizard.products.all_title')}</h3>

        <SearchInput
          value={search}
          onValueChange={setSearch}
          placeholder={t('admin.catalogs.products.search_placeholder')}
        />

        <div className="flex max-h-96 flex-col divide-y overflow-y-auto rounded-md border">
          {isLoading && (
            <p className="p-4 text-center text-muted-foreground text-sm">
              {t('admin.common.loading')}
            </p>
          )}
          {!isLoading && (data?.data.length ?? 0) === 0 && (
            <p className="p-4 text-center text-muted-foreground text-sm">
              {t('admin.common.no_results')}
            </p>
          )}
          {data?.data.map((product) => {
            const added = chosen.has(product.id)

            return (
              <div key={product.id} className="flex items-center gap-3 p-2">
                <Thumbnail
                  src={product.thumbnail_url}
                  alt={product.name ?? ''}
                  className="size-8"
                />
                <span className="min-w-0 flex-1 truncate text-sm">{product.name}</span>
                {/* An added row stays visible and disabled rather than
                    disappearing: a list that reshuffles as you click it is
                    hard to work down. */}
                <Button
                  variant="ghost"
                  size="icon-xs"
                  type="button"
                  disabled={added}
                  onClick={() => onChange([...products, product])}
                  aria-label={t('admin.catalogs.wizard.products.add', { name: product.name })}
                >
                  {added ? <CheckIcon className="size-4" /> : <PlusIcon className="size-4" />}
                </Button>
              </div>
            )
          })}
        </div>

        {data?.meta && <Pagination meta={data.meta} onPageChange={setPage} />}
      </section>
    </div>
  )
}

function ReviewStep({
  form,
  products,
}: {
  form: UseFormReturn<CatalogFormValues>
  products: Product[]
}) {
  const { t } = useTranslation()
  const values = form.watch()
  const audiences = values.assignments.filter((entry) => !entry.removed)

  return (
    <dl className="grid grid-cols-[10rem_1fr] gap-y-3 text-sm">
      <dt className="text-muted-foreground">{t('admin.fields.name.label')}</dt>
      <dd>{values.name}</dd>

      {values.description?.trim() && (
        <>
          <dt className="text-muted-foreground">{t('admin.fields.catalog.description.label')}</dt>
          <dd className="whitespace-pre-wrap">{values.description}</dd>
        </>
      )}

      <dt className="text-muted-foreground">{t('admin.catalogs.assignments.title')}</dt>
      <dd>
        {audiences.length === 0 ? (
          <span className="text-muted-foreground">
            {t('admin.catalogs.wizard.review.everyone')}
          </span>
        ) : (
          <span className="flex flex-wrap gap-1">
            {audiences.map((entry) => (
              <Badge key={`${entry.assignable_type}-${entry.assignable_id}`} variant="outline">
                {entry.assignable_name ?? entry.assignable_id}
              </Badge>
            ))}
          </span>
        )}
      </dd>

      <dt className="text-muted-foreground">{t('admin.catalogs.products.title')}</dt>
      <dd>
        {products.length === 0 ? (
          <span className="text-muted-foreground">
            {t('admin.catalogs.wizard.review.everything')}
          </span>
        ) : (
          t('admin.catalogs.wizard.products.count', { count: products.length })
        )}
      </dd>

      <dt className="text-muted-foreground">{t('admin.catalogs.detail.pricing')}</dt>
      <dd>{t(`admin.fields.catalog.pricing_mode.${values.pricing_mode}`)}</dd>
    </dl>
  )
}
