import { zodResolver } from '@hookform/resolvers/zod'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Checkbox,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  ResourceLayout,
  Textarea,
  WizardSteps,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CatalogAudienceFields } from '../../../../../components/spree/catalog-audience-fields'
import { CatalogPricingFields } from '../../../../../components/spree/catalog-pricing-fields'
import { useCreateCatalog } from '../../../../../hooks/use-catalogs'
import {
  CATALOG_DEFAULTS,
  type CatalogFormValues,
  catalogFormSchema,
  catalogValuesToParams,
} from '../../../../../schemas/catalog'

/**
 * Standing up a new agreement, in steps: what it is, who it is for, what it
 * charges, then a look at the whole thing before it exists.
 *
 * Nothing is written until Create — a merchant who abandons halfway leaves
 * nothing behind, the same staged-until-Save model the agreement editor uses
 * (docs/plans/6.0-catalog-agreement-rework.md).
 *
 * The assortment is deliberately not a step: product membership is written
 * through the catalog's own nested endpoints, so it needs a saved catalog to
 * hang off — and a first catalog is more usefully curated on the editor this
 * lands on.
 */
export const Route = createFileRoute('/_authenticated/$storeId/products/catalogs/new')({
  component: NewCatalogPage,
})

const STEP_KEYS = ['details', 'audience', 'pricing', 'review'] as const
type StepKey = (typeof STEP_KEYS)[number]

/** Which fields each step is answerable for, so Next validates only its own. */
const STEP_FIELDS: Record<StepKey, (keyof CatalogFormValues)[]> = {
  details: ['name', 'description'],
  audience: [],
  pricing: ['adjustment_magnitude', 'minimum_quantity'],
  review: [],
}

function NewCatalogPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreateCatalog()
  const [step, setStep] = useState<StepKey>('details')

  const form = useForm<CatalogFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(catalogFormSchema) as any,
    defaultValues: CATALOG_DEFAULTS,
  })

  const stepIndex = STEP_KEYS.indexOf(step)
  const isLastStep = stepIndex === STEP_KEYS.length - 1

  const steps = STEP_KEYS.map((key) => ({
    key,
    label: t(`admin.catalogs.wizard.steps.${key}`),
  }))

  // Only this step's fields: judging a later step's would block Next over a
  // question the merchant has not been asked yet.
  //
  // A refusal is stated at the top of the step as well as on the field. Next
  // going quiet is the one outcome a merchant cannot act on, and the field's
  // own message can be below the fold on a long step.
  async function goNext() {
    const fields = STEP_FIELDS[step]
    if (fields.length > 0 && !(await form.trigger(fields))) {
      form.setError('root', { message: t('admin.catalogs.wizard.fix_this_step') })
      return
    }

    form.clearErrors('root')
    setStep(STEP_KEYS[stepIndex + 1])
  }

  async function handleCreate(values: CatalogFormValues) {
    try {
      const catalog = await createMutation.mutateAsync(catalogValuesToParams(values))
      navigate({
        to: '/$storeId/products/catalogs/$catalogId',
        params: { storeId, catalogId: catalog.id },
      })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  // Stepping back and clearing a field can make Create fail validation on a
  // step that is no longer on screen. Without this the button would do nothing
  // at all, with the reason two steps away.
  function reportInvalid() {
    form.setError('root', { message: t('admin.catalogs.wizard.review.fix_earlier_steps') })
  }

  return (
    // Enter is swallowed until the last step. A form whose only blocking
    // control is one text input submits on Enter, which from step one would
    // create the catalog without the merchant ever seeing Audience, Pricing
    // or Review — the opposite of the contract this flow makes.
    <form
      onSubmit={form.handleSubmit(handleCreate, reportInvalid)}
      onKeyDown={(event) => {
        // Only a single-line text field. Enter on a button is how a keyboard
        // user presses it — including inside the audience dialog this form
        // encloses — and a textarea needs it for a new line.
        const onTextInput =
          event.target instanceof HTMLInputElement && event.target.type !== 'checkbox'
        if (event.key === 'Enter' && !isLastStep && onTextInput) {
          event.preventDefault()
        }
      }}
    >
      <ResourceLayout
        header={<PageHeader title={t('admin.catalogs.wizard.title')} backTo="products/catalogs" />}
        main={
          <>
            <WizardSteps
              steps={steps}
              current={step}
              onStepSelect={(key) => setStep(key as StepKey)}
            />

            {form.formState.errors.root?.message && (
              <p
                className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
                role="alert"
              >
                {form.formState.errors.root.message}
              </p>
            )}

            <Card>
              <CardHeader>
                <CardTitle>{t(`admin.catalogs.wizard.steps.${step}`)}</CardTitle>
                <CardDescription>{t(`admin.catalogs.wizard.help.${step}`)}</CardDescription>
              </CardHeader>
              <CardContent>
                {step === 'details' && <DetailsStep form={form} />}
                {step === 'audience' && <CatalogAudienceFields form={form} canEdit />}
                {step === 'pricing' && (
                  <FieldGroup>
                    <CatalogPricingFields form={form} canEdit />
                  </FieldGroup>
                )}
                {step === 'review' && <ReviewStep form={form} />}
              </CardContent>
            </Card>

            <div className="flex justify-between">
              <Button
                type="button"
                variant="outline"
                disabled={stepIndex === 0}
                onClick={() => setStep(STEP_KEYS[stepIndex - 1])}
              >
                {t('admin.actions.back')}
              </Button>

              {isLastStep ? (
                <Button type="submit" disabled={form.formState.isSubmitting}>
                  {form.formState.isSubmitting
                    ? t('admin.actions.creating')
                    : t('admin.catalogs.create_label')}
                </Button>
              ) : (
                <Button type="button" onClick={goNext}>
                  {t('admin.common.next')}
                </Button>
              )}
            </div>
          </>
        }
      />
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

      <Controller
        control={form.control}
        name="active"
        render={({ field }) => (
          <label htmlFor="catalog-active" className="flex items-center gap-2 text-sm">
            <Checkbox id="catalog-active" checked={field.value} onCheckedChange={field.onChange} />
            {t('admin.fields.active.label')}
          </label>
        )}
      />
    </FieldGroup>
  )
}

/**
 * The whole agreement in one place before it exists. Read-only by design:
 * corrections go back to the step that owns them, so there is one place each
 * answer is given.
 */
function ReviewStep({ form }: { form: UseFormReturn<CatalogFormValues> }) {
  const { t } = useTranslation()
  const values = form.watch()

  const pricing = t(`admin.fields.catalog.pricing_mode.${values.pricing_mode}`)
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
          audiences.map((entry) => entry.assignable_name ?? entry.assignable_id).join(', ')
        )}
      </dd>

      <dt className="text-muted-foreground">{t('admin.catalogs.detail.pricing')}</dt>
      <dd>{pricing}</dd>

      <dt className="text-muted-foreground">{t('admin.fields.active.label')}</dt>
      <dd>{values.active ? t('admin.common.yes') : t('admin.common.no')}</dd>
    </dl>
  )
}
