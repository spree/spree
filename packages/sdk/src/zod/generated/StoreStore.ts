// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StorePaymentMethodSchema } from './StorePaymentMethod';

export const StoreStoreSchema = z.object({
  id: z.string(),
  name: z.string(),
  url: z.string(),
  meta_description: z.string().nullable(),
  meta_keywords: z.string().nullable(),
  seo_title: z.string().nullable(),
  default_currency: z.string(),
  code: z.string(),
  default: z.boolean(),
  facebook: z.string().nullable(),
  twitter: z.string().nullable(),
  instagram: z.string().nullable(),
  customer_support_email: z.string().nullable(),
  default_locale: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  default_country_iso: z.string().nullable(),
  supported_currencies: z.array(z.string()),
  favicon_image_url: z.string().nullable(),
  logo_image_url: z.string().nullable(),
  social_image_url: z.string().nullable(),
  supported_locales: z.array(z.string()),
  payment_methods: z.array(StorePaymentMethodSchema),
});

export type StoreStore = z.infer<typeof StoreStoreSchema>;
