/**
 * The form fields backing one image: a freshly direct-uploaded blob
 * (`<name>_signed_id`), a transient object URL for the just-picked file
 * (`<name>_preview_url`), and a flag marking the persisted attachment for
 * removal (`<name>_cleared`). Together they form the three-state machine the
 * API expects.
 */
export type ImageFieldsFor<Name extends string> = {
  [K in `${Name}_signed_id` | `${Name}_preview_url`]: string | null
} & { [K in `${Name}_cleared`]: boolean }

/** Defaults for one attachment's image triple. */
export function imageTripleDefaults<Name extends string>(kind: Name): ImageFieldsFor<Name> {
  return {
    [`${kind}_signed_id`]: null,
    [`${kind}_preview_url`]: null,
    [`${kind}_cleared`]: false,
  } as ImageFieldsFor<Name>
}

/**
 * Three-state mapping: a fresh upload sends the signed_id, an explicit clear
 * sends null (purges the attachment), and an untouched field is omitted.
 */
export function attachmentImageParam<Key extends string>(
  key: Key,
  signedId: string | null,
  cleared: boolean,
): Partial<Record<Key, string | null>> {
  if (signedId) return { [key]: signedId } as Partial<Record<Key, string | null>>
  if (cleared) return { [key]: null } as Partial<Record<Key, string | null>>
  return {}
}
