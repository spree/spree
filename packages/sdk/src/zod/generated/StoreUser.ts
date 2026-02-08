// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreAddressSchema } from './StoreAddress';

export const StoreUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  addresses: z.array(StoreAddressSchema),
  default_billing_address: StoreAddressSchema,
  default_shipping_address: StoreAddressSchema,
});

export type StoreUser = z.infer<typeof StoreUserSchema>;
