// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DiagnosticsSchema = z.object({
  spree_version: z.string(),
  sections: z.array(z.object({ key: z.string(), title: z.string(), rows: z.array(z.object({ label: z.string(), value: z.string() })) })),
  errors: z.array(z.object({ error_class: z.string(), source: z.string().nullable(), frames: z.array(z.string()), request_id: z.string().nullable(), count: z.number(), first_seen_at: z.string(), last_seen_at: z.string() })),
  generated_at: z.string(),
  markdown: z.string(),
  issue_url: z.string(),
  issue_prefilled: z.boolean(),
});

export type Diagnostics = z.infer<typeof DiagnosticsSchema>;
