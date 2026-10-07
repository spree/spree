// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductSubmissionSchema = z.object({
  id: z.string(),
  status: z.string(),
  review_note: z.string().nullable(),
  reviewed_at: z.string().nullable(),
  created_at: z.string(),
  product_id: z.string(),
});

export type ProductSubmission = z.infer<typeof ProductSubmissionSchema>;
