import type { CustomFieldOwnerType } from '@spree/admin-sdk'
import type { MediaFormValues, SheetSaveHandler, VariantFormValues } from '@spree/dashboard-core'
import { registerSlot } from '@spree/dashboard-core'
import { useEffect } from 'react'
import { DraftCustomFieldsCard, useCustomFieldsDraft } from './custom-fields-inline'

type OnSave = (handler: SheetSaveHandler) => () => void

/**
 * Editable like the rest of the sheet, kept by its Done and dropped by its
 * Cancel. The values are a different record from the product, so they save on
 * Done rather than waiting for the product's Save.
 */
function SheetCustomFields({
  ownerType,
  ownerId,
  onSave,
}: {
  ownerType: CustomFieldOwnerType
  ownerId: string
  onSave: OnSave
}) {
  const draft = useCustomFieldsDraft(ownerType, ownerId)
  const { save } = draft

  useEffect(() => onSave(save), [onSave, save])

  return <DraftCustomFieldsCard draft={draft} hideWhenEmpty />
}

function VariantSheetCustomFields({
  variant,
  onSave,
}: {
  variant: VariantFormValues
  onSave: OnSave
}) {
  return <SheetCustomFields ownerType="variant" ownerId={variant.id ?? ''} onSave={onSave} />
}

function MediaSheetCustomFields({ media, onSave }: { media: MediaFormValues; onSave: OnSave }) {
  return <SheetCustomFields ownerType="media" ownerId={media.id ?? ''} onSave={onSave} />
}

/**
 * Custom fields inside the product page's variant and media sheets. Those
 * sheets live in `@spree/dashboard-core`, which cannot import the card, so it
 * arrives through their slots. Imported once for its side effects from the
 * product page. Only saved rows have an id to hang values on.
 */
registerSlot<{ variant: VariantFormValues; onSave: OnSave }>('product.variant.form_fields', {
  id: 'custom-fields',
  if: ({ variant }) => !!variant.id,
  component: VariantSheetCustomFields,
})

registerSlot<{ media: MediaFormValues; onSave: OnSave }>('product.media.form_fields', {
  id: 'custom-fields',
  if: ({ media }) => !!media.id,
  component: MediaSheetCustomFields,
})
