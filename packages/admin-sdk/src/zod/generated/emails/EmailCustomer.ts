// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailAddressSchema } from './EmailAddress';
import { EmailCustomerGroupSchema } from './EmailCustomerGroup';
import { EmailNewsletterSubscriberSchema } from './EmailNewsletterSubscriber';

export const EmailCustomerSchema = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  phone: z.string().nullable(),
  accepts_email_marketing: z.boolean(),
  email_marketing_consent_updated_at: z.string().nullable(),
  full_name: z.string(),
  available_store_credit_total: z.string(),
  addresses: z.array(EmailAddressSchema),
  default_billing_address: EmailAddressSchema.nullable(),
  default_shipping_address: EmailAddressSchema.nullable(),
  newsletter_subscriber: EmailNewsletterSubscriberSchema.nullable(),
  customer_groups: z.array(EmailCustomerGroupSchema),
});

export type EmailCustomer = z.infer<typeof EmailCustomerSchema>;
