// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailTemplateDraftSchema } from './EmailTemplateDraft';

export const EmailTemplateSchema = z.object({
  id: z.string(),
  key: z.string(),
  subject: z.string().nullable(),
  body: z.string(),
  language: z.string(),
  customized_languages: z.array(z.string()),
  kind: z.string(),
  customized: z.boolean(),
  published_at: z.string().nullable(),
  default_subject: z.string().nullable(),
  default_body: z.string(),
  published_language: z.string().nullable(),
  default_changed: z.boolean(),
  base_subject: z.string().nullable(),
  base_body: z.string().nullable(),
  draft: EmailTemplateDraftSchema.nullable(),
});

export type EmailTemplate = z.infer<typeof EmailTemplateSchema>;
