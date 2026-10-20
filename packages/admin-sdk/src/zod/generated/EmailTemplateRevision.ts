// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';

export const EmailTemplateRevisionSchema = z.object({
  id: z.string(),
  subject: z.string().nullable(),
  body: z.string(),
  created_at: z.string(),
  published_by_id: z.string().nullable(),
  published_by_type: z.string().nullable(),
  published_by: ActorSchema.optional(),
});

export type EmailTemplateRevision = z.infer<typeof EmailTemplateRevisionSchema>;
