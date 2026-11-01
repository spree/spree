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
});

export type OrderDocument = z.infer<typeof OrderDocumentSchema>;
