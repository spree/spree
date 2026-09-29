// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { CompanySchema } from './Company';
import { CustomerGroupSchema } from './CustomerGroup';
import { NewsletterSubscriberSchema } from './NewsletterSubscriber';
import { OrderSchema } from './Order';
import { StoreCreditSchema } from './StoreCredit';

export const CustomerSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  phone: z.string().nullable(),
  accepts_email_marketing: z.boolean(),
  email_marketing_consent_updated_at: z.string().nullable(),
  full_name: z.string(),
  available_store_credit_total: z.string(),
  display_available_store_credit_total: z.string(),
  addresses: z.array(AddressSchema).optional(),
  default_billing_address: AddressSchema.nullable().optional(),
  default_shipping_address: AddressSchema.nullable().optional(),
  newsletter_subscriber: NewsletterSubscriberSchema.nullable().optional(),
  customer_groups: z.array(z.lazy(() => CustomerGroupSchema)).optional(),
  failed_attempts: z.number(),
  metadata: z.record(z.string(), z.unknown()),
  email_marketing_consent_source: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  anonymized_at: z.string().nullable(),
  anonymized: z.boolean(),
  tags: z.array(z.string()),
  internal_note: z.string().nullable(),
  internal_note_html: z.string().nullable(),
  default_billing_address_id: z.string().nullable(),
  default_shipping_address_id: z.string().nullable(),
  orders_count: z.number(),
  total_spent: z.string(),
  display_total_spent: z.string(),
  last_order_completed_at: z.string().nullable(),
  orders: z.array(z.lazy(() => OrderSchema)).optional(),
  store_credits: z.array(z.lazy(() => StoreCreditSchema)).optional(),
  customer_group_ids: z.array(z.string()),
  companies: z.array(z.lazy(() => CompanySchema)).optional(),
});

export type Customer = z.infer<typeof CustomerSchema>;
