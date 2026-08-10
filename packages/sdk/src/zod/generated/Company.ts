// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CompanySchema = z.object({
  id: z.string(),
  name: z.string(),
  external_id: z.string().nullable(),
});

export type Company = z.infer<typeof CompanySchema>;
