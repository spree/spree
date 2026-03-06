// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminOptionValueSchema = z.object({
  id: z.string(),
  option_type_id: z.string(),
  name: z.string(),
  presentation: z.string(),
  position: z.number(),
  option_type_name: z.string(),
  option_type_presentation: z.string(),
});

export type AdminOptionValue = z.infer<typeof AdminOptionValueSchema>;
