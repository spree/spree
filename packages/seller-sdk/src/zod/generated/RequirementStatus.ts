// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { RequirementCustomFieldSchema } from './RequirementCustomField';
import { RequirementSubmissionSchema } from './RequirementSubmission';

export const RequirementStatusSchema = z.object({
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
  accepts_submissions: z.boolean(),
  requires_file: z.boolean(),
  accepted_content_types: z.array(z.string()),
  required_policy_name: z.string().nullable(),
  terms_html: z.string().nullable(),
  submission: RequirementSubmissionSchema.optional(),
  custom_fields: z.array(RequirementCustomFieldSchema).optional(),
});

export type RequirementStatus = z.infer<typeof RequirementStatusSchema>;
