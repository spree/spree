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
  preference_schema: z.array(z.object({ key: z.string(), type: z.string(), default: z.unknown(), choices: z.array(z.string()).optional() })),
  product_ids: z.array(z.string()).nullable(),
  category_ids: z.array(z.string()).nullable(),
  customer_ids: z.array(z.string()).nullable(),
  option_value_ids: z.array(z.string()).nullable(),
  products: z.array(ProductSchema).optional(),
  categories: z.array(z.lazy(() => CategorySchema)).optional(),
  customers: z.array(z.lazy(() => CustomerSchema)).optional(),
  customer_groups: z.array(z.lazy(() => CustomerGroupSchema)).optional(),
  countries: z.array(z.lazy(() => CountrySchema)).optional(),
  channels: z.array(ChannelSchema).optional(),
  markets: z.array(z.lazy(() => MarketSchema)).optional(),
  option_values: z.array(z.lazy(() => OptionValueSchema)).optional(),
});

export type PromotionRule = z.infer<typeof PromotionRuleSchema>;
