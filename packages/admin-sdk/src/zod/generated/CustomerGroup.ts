// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type CustomerGroup from '../../types/generated/CustomerGroup';
import { CustomerSchema } from './Customer';

export const CustomerGroupSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  customers_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  get customers() { return z.array(CustomerSchema).optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<CustomerGroup['id']>;
  name: z.ZodType<CustomerGroup['name']>;
  description: z.ZodType<CustomerGroup['description']>;
  customers_count: z.ZodType<CustomerGroup['customers_count']>;
  created_at: z.ZodType<CustomerGroup['created_at']>;
  updated_at: z.ZodType<CustomerGroup['updated_at']>;
  customers: z.ZodOptional<z.ZodType<Exclude<CustomerGroup['customers'], undefined>>>;
}>;

export type { CustomerGroup };
