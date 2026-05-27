import type { CustomFieldOwnerType } from '@spree/admin-sdk'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { PencilIcon, TagIcon } from 'lucide-react'
import { Fragment, useState } from 'react'
import { useCustomFieldDefinitions, useCustomFields } from '@/hooks/use-custom-fields'
import { CustomFieldsDrawer } from './custom-fields-drawer'

interface CustomFieldsCardProps {
  ownerType: CustomFieldOwnerType
  ownerId: string
  /** Plural display label, e.g. "products". */
  resourceLabel: string
}

export function CustomFieldsCard({ ownerType, ownerId, resourceLabel }: CustomFieldsCardProps) {
  const [open, setOpen] = useState(false)
  const { data: definitionsResp, isLoading: defsLoading } = useCustomFieldDefinitions(ownerType)
  const { data: valuesResp, isLoading: valsLoading } = useCustomFields(ownerType, ownerId)

  const definitions = definitionsResp?.data ?? []
  const values = valuesResp?.data ?? []
  const valueByDefinition = new Map(values.map((v) => [v.custom_field_definition_id, v]))
  const isLoading = defsLoading || valsLoading

  const setCount = definitions.filter((d) => {
    const v = valueByDefinition.get(d.id)?.value
    return v !== null && v !== undefined && v !== ''
  }).length

  return (
    <>
      <Card>
        <CardHeader className="flex flex-row items-center justify-between gap-2 space-y-0">
          <CardTitle>Custom fields</CardTitle>
          <Button type="button" variant="outline" size="sm" onClick={() => setOpen(true)}>
            <PencilIcon className="size-4" />
            {definitions.length === 0 ? 'Set up' : 'Edit'}
          </Button>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex flex-col gap-2">
              <Skeleton className="h-4 w-3/4" />
              <Skeleton className="h-4 w-1/2" />
            </div>
          ) : definitions.length === 0 ? (
            <Empty className="border-0 p-0">
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <TagIcon />
                </EmptyMedia>
                <EmptyTitle>No custom fields yet</EmptyTitle>
                <EmptyDescription>
                  Track structured details like material, fit, or care instructions.
                </EmptyDescription>
              </EmptyHeader>
            </Empty>
          ) : (
            <div className="flex flex-col gap-3">
              <dl className="grid grid-cols-[minmax(160px,1fr)_2fr] gap-x-4 gap-y-2 text-sm">
                {definitions.map((def) => {
                  const value = valueByDefinition.get(def.id)?.value
                  return (
                    <Fragment key={def.id}>
                      <dt className="flex flex-col">
                        <span className="font-medium">{def.label}</span>
                        <code className="text-xs text-muted-foreground">
                          {def.namespace}.{def.key}
                        </code>
                      </dt>
                      <dd className="text-foreground/90 break-words">
                        {formatValue(value, def.field_type)}
                      </dd>
                    </Fragment>
                  )
                })}
              </dl>
              {setCount < definitions.length && (
                <p className="text-xs text-muted-foreground border-t pt-2">
                  {definitions.length - setCount} of {definitions.length} not yet set
                </p>
              )}
            </div>
          )}
        </CardContent>
      </Card>

      <CustomFieldsDrawer
        open={open}
        onOpenChange={setOpen}
        ownerType={ownerType}
        ownerId={ownerId}
        resourceLabel={resourceLabel}
      />
    </>
  )
}

function formatValue(value: unknown, fieldType: string): string {
  if (value === null || value === undefined || value === '') return '—'
  if (fieldType === 'boolean') return value ? 'Yes' : 'No'
  if (fieldType === 'rich_text' && typeof value === 'string') {
    // Plain-text preview of HTML for the summary row. DOMParser handles
    // nested/malformed tags correctly — a single-pass regex strip can leak
    // tags via patterns like `<scr<script>ipt>` (CodeQL js/incomplete-multi-character-sanitization).
    const text = new DOMParser().parseFromString(value, 'text/html').body.textContent ?? ''
    return text.trim() || '—'
  }
  if (fieldType === 'json') return typeof value === 'string' ? value : JSON.stringify(value)
  return String(value)
}
