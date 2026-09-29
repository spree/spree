// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ChannelSchema } from './Channel';
import { CustomerSchema } from './Customer';
import { CustomerGroupSchema } from './CustomerGroup';
import { MarketSchema } from './Market';

export const PriceRuleSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string(),
  price_list_id: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  preference_schema: z.array(z.object({ key: z.string(), type: z.string(), default: z.unknown() })),
  markets: z.array(z.lazy(() => MarketSchema)).optional(),
  customer_groups: z.array(z.lazy(() => CustomerGroupSchema)).optional(),
  channels: z.array(ChannelSchema).optional(),
  customers: z.array(z.lazy(() => CustomerSchema)).optional(),
});

export type PriceRule = z.infer<typeof PriceRuleSchema>;
