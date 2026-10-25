// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';

export const EmailTemplateDraftSchema = z.object({
  id: z.string(),
  subject: z.string().nullable(),
  body: z.string(),
  lock_version: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  updated_by_id: z.string().nullable(),
  updated_by_type: z.string().nullable(),
  updated_by: ActorSchema.optional(),
});

export type EmailTemplateDraft = z.infer<typeof EmailTemplateDraftSchema>;
