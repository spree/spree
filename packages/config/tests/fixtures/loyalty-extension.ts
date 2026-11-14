import { z } from 'zod'
import { defineSection } from '../../src/index'

interface LoyaltyTier {
  code: string
  name?: string
  points?: number
  customer_group?: string
}

export default defineSection<LoyaltyTier>({
  name: 'loyalty_tiers',
  scope: 'write_loyalty',
  key: 'code',
  attributes: ['code', 'name', 'points'],
  schema: z
    .object({
      code: z.string().min(1),
      name: z.string().optional(),
      points: z.number().int().default(0),
      customer_group: z.string().optional(),
    })
    .strict(),
  references: (tiers) => ({
    customer_groups: tiers.flatMap((tier) => tier.customer_group ?? []),
  }),
  async desired(entry, ctx, path) {
    return {
      code: entry.code,
      name: entry.name,
      points: entry.points,
      ...(entry.customer_group
        ? { customer_group_id: await ctx.ref('customer_groups', entry.customer_group, path) }
        : {}),
    }
  },
})
