// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductSubmissionSchema = z.object({
  id: z.string(),
  status: z.string(),
  review_note: z.string().nullable(),
  reviewed_at: z.string().nullable(),
  created_at: z.string(),
  product_id: z.string(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  updated_at: z.string(),
  submitted_by_id: z.string().nullable(),
  reviewed_by_id: z.string().nullable(),
  reviewed_by_name: z.string().nullable(),
  auto_approved: z.boolean(),
});

export type ProductSubmission = z.infer<typeof ProductSubmissionSchema>;
