// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OrderDocumentSchema = z.object({
  id: z.string(),
  label: z.string(),
  uploaded_by_customer: z.boolean(),
  file_filename: z.string().nullable(),
  file_byte_size: z.number().nullable(),
  file_content_type: z.string().nullable(),
  download_url: z.string().nullable(),
  customer_visible: z.boolean(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  order_id: z.string(),
});

export type OrderDocument = z.infer<typeof OrderDocumentSchema>;
