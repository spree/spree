// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreSchema = z.object({
  id: z.string(),
  name: z.string(),
  seo_title: z.string().nullable(),
  meta_description: z.string().nullable(),
  meta_keywords: z.string().nullable(),
  facebook: z.string().nullable(),
  twitter: z.string().nullable(),
  instagram: z.string().nullable(),
  customer_support_email: z.string().nullable(),
  mail_from_address: z.string().nullable(),
  logo_url: z.string().nullable(),
});

export type Store = z.infer<typeof StoreSchema>;
