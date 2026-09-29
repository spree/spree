// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomerSchema } from './Customer';

export const CustomerGroupSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  customers_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  customers: z.array(z.lazy(() => CustomerSchema)).optional(),
});

export type CustomerGroup = z.infer<typeof CustomerGroupSchema>;
