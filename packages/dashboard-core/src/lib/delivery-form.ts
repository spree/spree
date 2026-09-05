import { z } from 'zod'

/**
 * One consignment's editable fields.
 *
 * The carrier is free text: a forwarder's own name is as valid as a
 * registered carrier, and an empty value asks the server to detect one from
 * the number.
 */
export const deliveryFormSchema = z.object({
  tracking_number: z.string().min(1),
  carrier: z.string(),
})

export type DeliveryFormValues = z.infer<typeof deliveryFormSchema>
