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
  get markets() { return z.array(MarketSchema).optional(); },
  get customer_groups() { return z.array(CustomerGroupSchema).optional(); },
  channels: z.array(ChannelSchema).optional(),
  get customers() { return z.array(CustomerSchema).optional(); },
});

export type PriceRule = z.infer<typeof PriceRuleSchema>;
