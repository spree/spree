// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { PolicySchema } from './Policy';
import { SellerRequirementSubmissionSchema } from './SellerRequirementSubmission';

export const SellerRequirementStatusSchema = z.object({
  id: z.string(),
  kind: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  required: z.boolean(),
  position: z.number(),
  status: z.string(),
  action_url: z.string().nullable(),
  blocker: z.object({ state: z.string(), message: z.string().nullable() }).nullable(),
  blocking: z.boolean(),
  required_policy_name: z.string().nullable(),
  submission: SellerRequirementSubmissionSchema.optional(),
  published_policy: PolicySchema.optional(),
});

export type SellerRequirementStatus = z.infer<typeof SellerRequirementStatusSchema>;
