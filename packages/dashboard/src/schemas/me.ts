import { z } from 'zod/v4'

// Profile form for the signed-in admin (PATCH /me). All fields optional —
// mirrors the Rails admin profile, which doesn't require first/last name.
// The admin-UI language options are NOT listed here: they're derived at render
// time from the dashboard's shipped locale bundles (see getAvailableUiLocales),
// which is what the SPA can actually display — not a backend list.
export const meFormSchema = z.object({
  first_name: z.string().nullable().optional(),
  last_name: z.string().nullable().optional(),
  selected_locale: z.string().nullable().optional(),
})

export type MeFormValues = z.infer<typeof meFormSchema>
