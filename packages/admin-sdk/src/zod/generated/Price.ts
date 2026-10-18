// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Price from '../../types/generated/Price';
import { VariantSchema } from './Variant';

export const PriceSchema = z.object({
  id: z.string(),
  currency: z.string().nullable(),
  amount: z.string().nullable(),
  compare_at_amount: z.string().nullable(),
  price_list_id: z.string().nullable(),
  min_quantity: z.number(),
  variant_id: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  get variant() { return VariantSchema.optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<Price['id']>;
  currency: z.ZodType<Price['currency']>;
  amount: z.ZodType<Price['amount']>;
  compare_at_amount: z.ZodType<Price['compare_at_amount']>;
  price_list_id: z.ZodType<Price['price_list_id']>;
  min_quantity: z.ZodType<Price['min_quantity']>;
  variant_id: z.ZodType<Price['variant_id']>;
  created_at: z.ZodType<Price['created_at']>;
  updated_at: z.ZodType<Price['updated_at']>;
  variant: z.ZodOptional<z.ZodType<Exclude<Price['variant'], undefined>>>;
}>;

export type { Price };
