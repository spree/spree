// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentMethodTypeSchema = z.object({
  type: z.string(),
  label: z.string(),
  description: z.string().nullable(),
  schema: z.any(),
  superseded: z.boolean().optional(),
  logo_url: z.string().nullable(),
  docs_url: z.string().nullable(),
  third_party: z.boolean(),
  installed: z.boolean(),
});

export type PaymentMethodType = z.infer<typeof PaymentMethodTypeSchema>;
