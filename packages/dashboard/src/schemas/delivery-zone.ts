import { z } from 'zod/v4'

export const MEMBER_TYPES = ['country', 'state', 'postal_code'] as const

export const deliveryZoneMemberSchema = z.object({
  member_type: z.enum(MEMBER_TYPES),
  country_iso: z.string().optional(),
  state_code: z.string().optional(),
  postal_code_prefix: z.string().optional(),
  postal_code_from: z.string().optional(),
  postal_code_to: z.string().optional(),
})

export const deliveryZoneFormSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
  members: z.array(deliveryZoneMemberSchema),
})

export type DeliveryZoneMemberValues = z.infer<typeof deliveryZoneMemberSchema>
export type DeliveryZoneFormValues = z.infer<typeof deliveryZoneFormSchema>

export const DELIVERY_ZONE_DEFAULTS: DeliveryZoneFormValues = {
  name: '',
  description: '',
  members: [],
}

/**
 * A zone belongs to the profile it was created in, and to one origin group
 * within it; both ids are only sent on create, since a zone never moves
 * between profiles or groups.
 */
export function deliveryZoneValuesToParams(
  values: DeliveryZoneFormValues,
  deliveryProfileId?: string,
  deliveryOriginGroupId?: string,
) {
  return {
    name: values.name,
    description: values.description || null,
    ...(deliveryProfileId ? { delivery_profile_id: deliveryProfileId } : {}),
    ...(deliveryOriginGroupId ? { delivery_origin_group_id: deliveryOriginGroupId } : {}),
    members: values.members.map((member) => ({
      member_type: member.member_type,
      ...(member.country_iso ? { country_iso: member.country_iso } : {}),
      ...(member.state_code ? { state_code: member.state_code } : {}),
      ...(member.postal_code_prefix ? { postal_code_prefix: member.postal_code_prefix } : {}),
      ...(member.postal_code_from ? { postal_code_from: member.postal_code_from } : {}),
      ...(member.postal_code_to ? { postal_code_to: member.postal_code_to } : {}),
    })),
  }
}
