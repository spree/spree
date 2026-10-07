// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SellerRequirementSubmissionSchema = z.object({
  id: z.string(),
  status: z.string(),
  note: z.string().nullable(),
  review_note: z.string().nullable(),
  reference: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  reviewed_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  seller_id: z.string(),
  requirement_id: z.string(),
  requirement_name: z.string(),
  file_url: z.string().nullable(),
  file_name: z.string().nullable(),
});

export type SellerRequirementSubmission = z.infer<typeof SellerRequirementSubmissionSchema>;
