// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CategorySchema } from './Category';
import { ChannelSchema } from './Channel';
import { CountrySchema } from './Country';
import { CustomerSchema } from './Customer';
import { CustomerGroupSchema } from './CustomerGroup';
import { MarketSchema } from './Market';
import { OptionValueSchema } from './OptionValue';
import { ProductSchema } from './Product';

export const PromotionRuleSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string(),
  promotion_id: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  product_ids: z.array(z.string()).nullable(),
  category_ids: z.array(z.string()).nullable(),
  customer_ids: z.array(z.string()).nullable(),
  option_value_ids: z.array(z.string()).nullable(),
  products: z.array(ProductSchema).optional(),
  get categories() { return z.array(CategorySchema).optional(); },
  get customers() { return z.array(CustomerSchema).optional(); },
  get customer_groups() { return z.array(CustomerGroupSchema).optional(); },
  get countries() { return z.array(CountrySchema).optional(); },
  channels: z.array(ChannelSchema).optional(),
  get markets() { return z.array(MarketSchema).optional(); },
  get option_values() { return z.array(OptionValueSchema).optional(); },
});

export type PromotionRule = z.infer<typeof PromotionRuleSchema>;
