// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { FileUploadTargetSchema } from './FileUploadTarget';

export const FileUploadSchema = z.object({
  signed_id: z.string(),
  filename: z.string(),
  content_type: z.string(),
  byte_size: z.number(),
  visibility: z.string(),
  expires_at: z.string(),
  upload: FileUploadTargetSchema.nullable(),
});

export type FileUpload = z.infer<typeof FileUploadSchema>;
