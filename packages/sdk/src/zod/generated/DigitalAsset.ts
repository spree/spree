// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DigitalAssetSchema = z.object({
  id: z.string(),
  variant_id: z.string().nullable(),
  filename: z.string().nullable(),
  content_type: z.string().nullable(),
});

export type DigitalAsset = z.infer<typeof DigitalAssetSchema>;
