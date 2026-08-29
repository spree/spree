import {
  PageHeader,
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
  RichTextEditor,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  toastManager,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import type { Policy } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import '../tables/policies'

interface PolicyFormValues {
  name: string
  body: string
}

/**
 * The seller's own legal documents.
 *
 * A seller starts with none — what they are expected to publish is the
 * marketplace's decision, so the outstanding requirements are surfaced here
 * with a one-click create that carries the required name through. That name
 * is what the onboarding check matches on, which is why it is never typed by
 * hand when it comes from a requirement.
 */
export function PoliciesPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const confirm = useConfirm()
  const queryClient = useQueryClient()

  const [editingId, setEditingId] = useState<string | null>(null)
  const [creatingName, setCreatingName] = useState<string | null>(null)

  // What the marketplace asks for, so the page can name what is still missing
  // rather than leaving the seller to guess from the onboarding screen.
  const onboarding = useQuery({
    queryKey: ['seller', sellerId, 'onboarding'],
    queryFn: () => sellerClient().onboarding.get(),
  })

  // One requirement row per document, so an outstanding line is simply an
  // incomplete policy requirement. Deduped by name in case a marketplace
  // configured the same document twice — the seller owes it once.
  const outstanding = Array.from(
    new Map(
      (onboarding.data?.requirements ?? [])
        .filter((requirement) => requirement.status !== 'complete')
        .map((requirement) => requirement.required_policy_name)
        .filter((name): name is string => !!name)
        .map((name) => [name, name]),
    ).values(),
  )

  // Built through the same tenant-scoped helper `ResourceTable` uses, so the
  // list this page renders and the keys it invalidates are the same keys.
  const buildKey = useResourceKeyBuilder()

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: buildKey('seller-policies') })
    // A published policy can satisfy an onboarding requirement, so the
    // checklist is no longer what it was.
    queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
  }

  const deleteMutation = useMutation({
    mutationFn: (id: string) => sellerClient().policies.delete(id),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('policies.messages.deleted') })
      invalidate()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  useRowClickBridge('data-policy-id', setEditingId)

  async function handleDelete(policy: Policy) {
    const ok = await confirm({
      title: t('policies.delete_confirm.title'),
      message: t('policies.delete_confirm.message', { name: policy.name }),
      variant: 'destructive',
      confirmLabel: t('common.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(policy.id).catch(() => undefined)
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title={t('policies.title')} subtitle={t('policies.description')} />

      {outstanding.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>{t('policies.required.title')}</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            <p className="text-muted-foreground text-sm">{t('policies.required.description')}</p>
            <ul className="flex flex-col gap-2">
              {outstanding.map((name) => (
                <li
                  key={name}
                  className="flex items-center justify-between gap-4 rounded-md border border-border px-3 py-2"
                >
                  <span className="font-medium text-sm">{name}</span>
                  <Button size="sm" variant="outline" onClick={() => setCreatingName(name)}>
                    {t('policies.required.write')}
                  </Button>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      )}

      <ResourceTable<Policy>
        tableKey="seller-policies"
        queryKey="seller-policies"
        queryFn={(params) => sellerClient().policies.list(params)}
        searchParams={search}
        rowActions={(policy) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => setEditingId(policy.id) },
              {
                key: 'delete',
                destructive: true,
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(policy),
              },
            ]}
          />
        )}
        actions={
          <Button size="sm" onClick={() => setCreatingName('')}>
            <PlusIcon className="size-4" />
            {t('policies.add')}
          </Button>
        }
      />

      {creatingName !== null && (
        <PolicySheet
          presetName={creatingName}
          onSaved={invalidate}
          onClose={() => setCreatingName(null)}
        />
      )}
      {editingId && (
        <PolicySheet policyId={editingId} onSaved={invalidate} onClose={() => setEditingId(null)} />
      )}
    </div>
  )
}

function PolicySheet({
  policyId,
  presetName = '',
  onSaved,
  onClose,
}: {
  policyId?: string
  presetName?: string
  onSaved: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()

  // Fetched rather than passed down: the row the table rendered carries the
  // list payload, and editing needs the record itself.
  const { data: policy } = useQuery({
    // Seller-scoped like every other key here: an unscoped one would serve
    // one seller's policy body to the next after a seller switch.
    queryKey: useResourceKey('seller-policies', policyId ?? 'new'),
    queryFn: () => sellerClient().policies.get(policyId as string),
    enabled: !!policyId,
  })

  const form = useForm<PolicyFormValues>({
    defaultValues: { name: presetName, body: '' },
  })

  useEffect(() => {
    if (policy) form.reset({ name: policy.name, body: policy.body_html ?? '' })
  }, [policy, form])

  const save = useMutation({
    mutationFn: (values: PolicyFormValues) =>
      policyId
        ? sellerClient().policies.update(policyId, values)
        : sellerClient().policies.create(values),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('policies.messages.saved') })
      onSaved()
      onClose()
    },
    // The sheet stays open on failure — closing it would discard what the
    // seller wrote along with the error that explains why it did not save.
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const { errors } = form.formState

  return (
    <Sheet open onOpenChange={(next) => !next && onClose()}>
      <SheetContent className="data-[side=right]:max-w-[860px]">
        <SheetHeader>
          <SheetTitle>{policy?.name ?? t('policies.sheet.new_title')}</SheetTitle>
          <SheetDescription>{t('policies.sheet.description')}</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={form.handleSubmit((values) => save.mutateAsync(values).catch(() => undefined))}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <Field>
              <FieldLabel htmlFor="policy-name">{t('policies.fields.name')}</FieldLabel>
              <Input
                id="policy-name"
                autoFocus
                aria-invalid={!!errors.name || undefined}
                {...form.register('name', { required: true })}
              />
              <FieldError errors={[errors.name]} />
            </Field>

            <Field>
              <FieldLabel htmlFor="policy-body">{t('policies.fields.body')}</FieldLabel>
              <Controller
                control={form.control}
                name="body"
                render={({ field }) => (
                  <RichTextEditor
                    id="policy-body"
                    ariaLabel={t('policies.fields.body')}
                    value={field.value}
                    onChange={field.onChange}
                  />
                )}
              />
            </Field>
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
