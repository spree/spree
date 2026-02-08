// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminOrderSchema } from './AdminOrder';
import { StoreAddressSchema } from './StoreAddress';

export const AdminUserSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  addresses: z.array(StoreAddressSchema),
  default_billing_address: StoreAddressSchema,
  default_shipping_address: StoreAddressSchema,
  phone: z.string().nullable(),
  login: z.string().nullable(),
  accepts_email_marketing: z.boolean(),
  last_sign_in_at: z.string().nullable(),
  current_sign_in_at: z.string().nullable(),
  sign_in_count: z.number(),
  failed_attempts: z.number(),
  last_sign_in_ip: z.string().nullable(),
  current_sign_in_ip: z.string().nullable(),
  orders: z.array(z.lazy(() => AdminOrderSchema)).optional(),
});

export type AdminUser = z.infer<typeof AdminUserSchema>;
