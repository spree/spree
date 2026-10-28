// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomFieldSchema } from './CustomField';

export const PaymentMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  type: z.string(),
  session_required: z.boolean(),
  source_required: z.boolean(),
  custom_fields: z.array(CustomFieldSchema).optional(),
});

export type PaymentMethod = z.infer<typeof PaymentMethodSchema>;
