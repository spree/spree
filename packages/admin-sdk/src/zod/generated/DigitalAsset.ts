// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DigitalAssetSchema = z.object({
  id: z.string(),
  variant_id: z.string().nullable(),
  filename: z.string().nullable(),
  content_type: z.string().nullable(),
  authorized_clicks: z.number().nullable(),
  authorized_days: z.number().nullable(),
  byte_size: z.number().nullable(),
  provider_type: z.string().nullable(),
  provider_settings: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  provider_name: z.string(),
  download_url: z.string().nullable(),
  effective_authorized_clicks: z.number(),
  effective_authorized_days: z.number(),
});

export type DigitalAsset = z.infer<typeof DigitalAssetSchema>;
