// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';

export const CustomerSchema = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  phone: z.string().nullable(),
  accepts_email_marketing: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  addresses: z.array(AddressSchema),
  default_billing_address: AddressSchema.nullable(),
  default_shipping_address: AddressSchema.nullable(),
});

export type Customer = z.infer<typeof CustomerSchema>;
