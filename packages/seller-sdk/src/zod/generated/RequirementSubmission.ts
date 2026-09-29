// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const RequirementSubmissionSchema = z.object({
  id: z.string(),
  status: z.string(),
  note: z.string().nullable(),
  review_note: z.string().nullable(),
  reference: z.string().nullable(),
  reviewed_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  file_url: z.string().nullable(),
  file_name: z.string().nullable(),
});

export type RequirementSubmission = z.infer<typeof RequirementSubmissionSchema>;
