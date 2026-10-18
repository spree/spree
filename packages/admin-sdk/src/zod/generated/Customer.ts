// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Customer from '../../types/generated/Customer';
import { AddressSchema } from './Address';
import { CompanySchema } from './Company';
import { CustomerGroupSchema } from './CustomerGroup';
import { NewsletterSubscriberSchema } from './NewsletterSubscriber';
import { OrderSchema } from './Order';
import { StoreCreditSchema } from './StoreCredit';

export const CustomerSchema = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  phone: z.string().nullable(),
  accepts_email_marketing: z.boolean(),
  email_marketing_consent_updated_at: z.string().nullable(),
  full_name: z.string(),
  available_store_credit_total: z.string(),
  addresses: z.array(AddressSchema).optional(),
  default_billing_address: AddressSchema.nullable().optional(),
  default_shipping_address: AddressSchema.nullable().optional(),
  newsletter_subscriber: NewsletterSubscriberSchema.nullable().optional(),
  get customer_groups() { return z.array(CustomerGroupSchema).optional(); },
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
  last_order_completed_at: z.string().nullable(),
  get orders() { return z.array(OrderSchema).optional(); },
  get store_credits() { return z.array(StoreCreditSchema).optional(); },
  customer_group_ids: z.array(z.string()),
  get companies() { return z.array(CompanySchema).optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<Customer['id']>;
  email: z.ZodType<Customer['email']>;
  first_name: z.ZodType<Customer['first_name']>;
  last_name: z.ZodType<Customer['last_name']>;
  phone: z.ZodType<Customer['phone']>;
  accepts_email_marketing: z.ZodType<Customer['accepts_email_marketing']>;
  email_marketing_consent_updated_at: z.ZodType<Customer['email_marketing_consent_updated_at']>;
  full_name: z.ZodType<Customer['full_name']>;
  available_store_credit_total: z.ZodType<Customer['available_store_credit_total']>;
  addresses: z.ZodOptional<z.ZodType<Exclude<Customer['addresses'], undefined>>>;
  default_billing_address: z.ZodOptional<z.ZodType<Exclude<Customer['default_billing_address'], undefined>>>;
  default_shipping_address: z.ZodOptional<z.ZodType<Exclude<Customer['default_shipping_address'], undefined>>>;
  newsletter_subscriber: z.ZodOptional<z.ZodType<Exclude<Customer['newsletter_subscriber'], undefined>>>;
  customer_groups: z.ZodOptional<z.ZodType<Exclude<Customer['customer_groups'], undefined>>>;
  failed_attempts: z.ZodType<Customer['failed_attempts']>;
  metadata: z.ZodType<Customer['metadata']>;
  email_marketing_consent_source: z.ZodType<Customer['email_marketing_consent_source']>;
  created_at: z.ZodType<Customer['created_at']>;
  updated_at: z.ZodType<Customer['updated_at']>;
  anonymized_at: z.ZodType<Customer['anonymized_at']>;
  anonymized: z.ZodType<Customer['anonymized']>;
  tags: z.ZodType<Customer['tags']>;
  internal_note: z.ZodType<Customer['internal_note']>;
  internal_note_html: z.ZodType<Customer['internal_note_html']>;
  default_billing_address_id: z.ZodType<Customer['default_billing_address_id']>;
  default_shipping_address_id: z.ZodType<Customer['default_shipping_address_id']>;
  orders_count: z.ZodType<Customer['orders_count']>;
  total_spent: z.ZodType<Customer['total_spent']>;
  last_order_completed_at: z.ZodType<Customer['last_order_completed_at']>;
  orders: z.ZodOptional<z.ZodType<Exclude<Customer['orders'], undefined>>>;
  store_credits: z.ZodOptional<z.ZodType<Exclude<Customer['store_credits'], undefined>>>;
  customer_group_ids: z.ZodType<Customer['customer_group_ids']>;
  companies: z.ZodOptional<z.ZodType<Exclude<Customer['companies'], undefined>>>;
}>;

export type { Customer };
