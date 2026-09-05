import { z } from 'zod'

/**
 * What a label bought outside Spree needs recording against a parcel.
 *
 * The carrier is free text: a forwarder's own name is as real a carrier as a
 * registered one, and an empty value asks the server to detect one from the
 * number.
 */
export const labelUploadFormSchema = z.object({
  // Trimmed before the length check: every consumer trims before sending, so
  // validating the raw value would let a field of spaces pass and submit
  // blank.
  tracking_number: z.string().trim().min(1),
  carrier: z.string(),
  cost: z.string(),
})

export type LabelUploadFormValues = z.infer<typeof labelUploadFormSchema>

/** What a carrier label plausibly arrives as — mirrors the server allowlist. */
export const LABEL_ACCEPT = 'application/pdf,image/png,text/plain'
