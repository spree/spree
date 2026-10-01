// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailStoreSchema = z.object({
  id: z.string(),
  name: z.string(),
  address: z.string().nullable(),
  mail_from_address: z.string(),
  default_currency: z.string(),
  default_locale: z.string(),
  url: z.string(),
  support_email: z.string(),
  logo_url: z.string().nullable(),
  logo_width: z.number().nullable(),
  branding: z.object({ background_color: z.string(), card_color: z.string(), text_color: z.string(), heading_color: z.string(), accent_color: z.string().nullable(), link_color: z.string(), button_color: z.string(), button_text_color: z.string(), button_border: z.string(), font: z.string(), font_family: z.string(), heading_font_family: z.string(), font_url: z.string().nullable() }),
});

export type EmailStore = z.infer<typeof EmailStoreSchema>;
