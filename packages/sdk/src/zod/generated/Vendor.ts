// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const VendorSchema = z.object({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  about: z.string(),
  about_html: z.string(),
  logo_url: z.string().nullable(),
  square_logo_url: z.string().nullable(),
  cover_photo_url: z.string().nullable(),
});

export type Vendor = z.infer<typeof VendorSchema>;
