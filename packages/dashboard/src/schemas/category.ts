import type { Category } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'
import { customFieldFormSchema } from './product'

// Each image field is a small state machine: untouched (omit on save),
// uploaded (send signed_id), or cleared (send null to purge). `*_signed_id`
// carries a freshly direct-uploaded blob; `*_preview_url` is a transient
// object URL for the just-picked file; `*_cleared` flags a removal of the
// persisted attachment.
const imageFields = {
  image_signed_id: z.string().nullable(),
  image_preview_url: z.string().nullable(),
  image_cleared: z.boolean(),
  square_image_signed_id: z.string().nullable(),
  square_image_preview_url: z.string().nullable(),
  square_image_cleared: z.boolean(),
}

export const categoryFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  /** Prefixed parent category id; null = top-level category. */
  parent_id: z.string().nullable(),
  description: z.string(),
  permalink: z.string(),
  meta_title: z.string(),
  meta_description: z.string(),
  // Inline custom field values keyed by definition id, upserted server-side via
  // Spree::Metafields#custom_fields= (the categories controller permits them).
  // Persisted with the rest of the category on the page's Save button.
  custom_fields: z.array(customFieldFormSchema).optional(),
  ...imageFields,
})

export type CategoryFormValues = z.infer<typeof categoryFormSchema>

const IMAGE_DEFAULTS = {
  image_signed_id: null,
  image_preview_url: null,
  image_cleared: false,
  square_image_signed_id: null,
  square_image_preview_url: null,
  square_image_cleared: false,
} satisfies Partial<CategoryFormValues>

export const CATEGORY_DEFAULTS: CategoryFormValues = {
  name: '',
  parent_id: null,
  description: '',
  permalink: '',
  meta_title: '',
  meta_description: '',
  custom_fields: [],
  ...IMAGE_DEFAULTS,
}

/** Hydrate the form from an API category row. */
export function categoryToForm(category: Category): CategoryFormValues {
  return {
    name: category.name ?? '',
    parent_id: category.parent_id ?? null,
    description: category.description_html ?? '',
    permalink: category.permalink ?? '',
    meta_title: category.meta_title ?? '',
    meta_description: category.meta_description ?? '',
    custom_fields:
      category.custom_fields?.map((cf) => ({
        id: cf.id,
        custom_field_definition_id: cf.custom_field_definition_id,
        value: cf.value,
      })) ?? [],
    ...IMAGE_DEFAULTS,
  }
}

/** Map the form to the create/update API params (drops frontend-only fields). */
export function categoryToParams(values: CategoryFormValues) {
  return {
    name: values.name,
    // null keeps an existing child category at the top level on update; create
    // treats null/undefined the same (no parent).
    parent_id: values.parent_id,
    description: values.description,
    permalink: values.permalink,
    meta_title: values.meta_title,
    meta_description: values.meta_description,
    // Only ship when present — the model setter no-ops on blank, and an empty
    // array is noise. Upsert semantics mean untouched definitions stay as-is.
    ...(values.custom_fields && values.custom_fields.length > 0
      ? { custom_fields: values.custom_fields }
      : {}),
    ...imageParam('image', values.image_signed_id, values.image_cleared),
    ...imageParam('square_image', values.square_image_signed_id, values.square_image_cleared),
  }
}

// Three-state mapping: a fresh upload sends the signed_id, an explicit clear
// sends null (purges the attachment), and an untouched field is omitted.
function imageParam(key: 'image' | 'square_image', signedId: string | null, cleared: boolean) {
  if (signedId) return { [key]: signedId }
  if (cleared) return { [key]: null }
  return {}
}
