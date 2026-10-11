// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  type: z.string(),
  session_required: z.boolean(),
  source_required: z.boolean(),
  metadata: z.record(z.string(), z.unknown()),
  active: z.boolean(),
  auto_capture: z.boolean().nullable(),
  capture_method: z.string().nullable(),
  resolved_capture_method: z.string(),
  storefront_visible: z.boolean(),
  position: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  logo_url: z.string().nullable(),
  docs_url: z.string().nullable(),
  third_party: z.boolean(),
});

export type PaymentMethod = z.infer<typeof PaymentMethodSchema>;
