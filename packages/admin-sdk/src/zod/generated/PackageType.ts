// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PackageTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  kind: z.string(),
  length: z.string().nullable(),
  width: z.string().nullable(),
  height: z.string().nullable(),
  weight: z.string().nullable(),
  max_weight: z.string().nullable(),
  default: z.boolean(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  dimensions_unit: z.string(),
  weight_unit: z.string(),
  volume: z.string().nullable(),
  seller_id: z.string().nullable(),
  seller_name: z.string().nullable(),
});

export type PackageType = z.infer<typeof PackageTypeSchema>;
