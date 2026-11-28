import { z } from 'zod/v4'

/**
 * The channels a category or collection is published on — a sync set
 * server-side, so a channel left out is unpublished. Null on a new record
 * until the Publishing card seeds it, so a create that never loaded channels
 * still publishes everywhere (the server's default).
 */
export const publicationsFormSchema = z
  .array(
    z.object({
      channel_id: z.string(),
      published_at: z.string().nullable(),
      unpublished_at: z.string().nullable(),
    }),
  )
  .nullable()

type PublicationFormValue = NonNullable<z.infer<typeof publicationsFormSchema>>[number]

/** Hydrate the publications set from a record's expanded `publications`. */
export function publicationsToForm(publications?: readonly PublicationFormValue[] | null) {
  return (
    publications?.map((publication) => ({
      channel_id: publication.channel_id,
      published_at: publication.published_at,
      unpublished_at: publication.unpublished_at,
    })) ?? []
  )
}

/** The `publications` param, left out while the set is still unseeded. */
export function publicationsParam(publications: z.infer<typeof publicationsFormSchema>) {
  return publications ? { publications } : {}
}
