import type { Category } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

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
    ...IMAGE_DEFAULTS,
  }
}

/** Map the form to the create/update API params (drops frontend-only fields). */
export function categoryToParams(values: CategoryFormValues) {
  return {
    name: values.name,
    parent_id: values.parent_id ?? undefined,
    description: values.description,
    permalink: values.permalink,
    meta_title: values.meta_title,
    meta_description: values.meta_description,
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
