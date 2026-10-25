// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailTemplatePreviewSchema = z.object({
  id: z.string().nullable(),
  subject: z.string(),
  html: z.string(),
  text: z.string(),
  email_key: z.string(),
  variables: z.record(z.string(), z.unknown()),
});

export type EmailTemplatePreview = z.infer<typeof EmailTemplatePreviewSchema>;
