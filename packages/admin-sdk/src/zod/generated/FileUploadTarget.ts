// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FileUploadTargetSchema = z.object({
  method: z.string(),
  url: z.string(),
  headers: z.record(z.string(), z.string()),
});

export type FileUploadTarget = z.infer<typeof FileUploadTargetSchema>;
